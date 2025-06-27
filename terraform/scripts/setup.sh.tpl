#!/bin/bash

set -Eeuo pipefail

control_node_name="$(curl -s http://metadata.google.internal/computeMetadata/v1/instance/name -H 'Metadata-Flavor: Google')"
# The zone value from the metadata server is in the format 'projects/PROJECT_NUMBER/zones/ZONE'. 
# extracting the last part
control_node_zone_full="$(curl -s http://metadata.google.internal/computeMetadata/v1/instance/zone -H 'Metadata-Flavor: Google')"
control_node_zone="$(basename "$control_node_zone_full")"
control_node_project_id="$(curl -s http://metadata.google.internal/computeMetadata/v1/project/project-id -H 'Metadata-Flavor: Google')"
  
cleanup() {
  # https://cloud.google.com/compute/docs/troubleshooting/troubleshoot-os-login#invalid_argument
  echo "Deleting the public SSH key from the control node's service account OS Login profile to prevent exceeding the 32KiB limit"
  if ! gcloud --quiet compute os-login ssh-keys remove --key-file=/root/.ssh/google_compute_engine.pub; then
    echo "WARNING: Failed to remove SSH key. Continuing with instance deletion."
  fi
  echo "Deleting '$control_node_name' GCE instance in zone '$control_node_zone' in project '$control_node_project_id'..."
  gcloud --quiet compute instances delete "$control_node_name" --zone="$control_node_zone" --project="$control_node_project_id"
}

trap cleanup EXIT

DEST_DIR="/oracle-toolkit"

apt-get update
apt-get install -y ansible python3-jmespath unzip python3-google-auth

echo "Triggering SSH key creation via OS Login by running a one-time gcloud compute ssh command."
echo "This ensures that a persistent SSH key pair is created and associated with your Google Account."
echo "The private auto-generated ssh key (~/.ssh/google_compute_engine) will be used by Ansible to connect to the VM and run playbooks remotely."
echo "Command:"
echo "gcloud compute ssh '${instance_name}' --zone='${instance_zone}' --internal-ip --quiet --command whoami"

timeout 2m bash -c 'until gcloud compute ssh "${instance_name}" --zone="${instance_zone}" --internal-ip --quiet --command whoami; do
  echo "Waiting for SSH to become available on '${instance_name}'..."
  sleep 5
done' || {
  echo "ERROR: Timed out waiting for SSH"
  exit 1
}

control_node_sa="$(curl -s http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/email -H 'Metadata-Flavor: Google')"
echo "Downloading '${gcs_source}' to /tmp"
if ! gsutil cp "${gcs_source}" /tmp/; then
  echo "ERROR: Failed to download '${gcs_source}'. Make sure the file exists and that the service account '$control_node_sa' has 'roles/storage.objectViewer' role on the bucket."
  exit 1
fi
zip_file="$(basename "${gcs_source}")"
mkdir -p "$DEST_DIR"
echo "Extracting files from '$zip_file' to '$DEST_DIR'"
unzip -o "/tmp/$zip_file" -d "$DEST_DIR"

ssh_user="$(gcloud compute os-login describe-profile --format='value(posixAccounts[0].username)')"
if [[ -z "$ssh_user" ]]; then
  echo "ERROR: Failed to extract the POSIX username. This may be due to OS Login not being enabled or missing IAM permissions."
  exit 1
fi

cd "$DEST_DIR"

# Enable logging of Ansible tasks in JSON format to Google Cloud Logging
cat <<EOF >> ./ansible.cfg
callback_plugins = ./tools/callback_plugins

[cloud_logging]
project = $control_node_project_id
ignore_gcp_api_errors = false
enable_async_logging = true
EOF

export "DEPLOYMENT_NAME=${deployment_name}"

bash install-oracle.sh \
--instance-ssh-user "$ssh_user" \
--instance-ssh-key /root/.ssh/google_compute_engine \
%{ if ip_addr != "" }--instance-ip-addr "${ip_addr}" %{ endif } \
%{ if asm_disk_config != "" }--ora-asm-disks-json '${asm_disk_config}' %{ endif } \
%{ if data_mounts_config != "" }--ora-data-mounts-json '${data_mounts_config}' %{ endif } \
%{ if swap_blk_device != "" }--swap-blk-device "${swap_blk_device}" %{ endif } \
%{ if ora_swlib_bucket != "" }--ora-swlib-bucket "${ora_swlib_bucket}" %{ endif } \
%{ if ora_version != "" }--ora-version "${ora_version}" %{ endif } \
%{ if ora_backup_dest != "" }--backup-dest "${ora_backup_dest}" %{ endif } \
%{ if ora_db_name != "" }--ora-db-name "${ora_db_name}" %{ endif } \
%{ if ora_db_container != "" }--ora-db-container "${ora_db_container}" %{ endif } \
%{ if ntp_pref != "" }--ntp-pref "${ntp_pref}" %{ endif } \
%{ if ora_release != "" }--ora-release "${ora_release}" %{ endif } \
%{ if ora_edition != "" }--ora-edition "${ora_edition}" %{ endif } \
%{ if ora_listener_port != "" }--ora-listener-port "${ora_listener_port}" %{ endif } \
%{ if ora_redo_log_size != "" }--ora-redo-log-size "${ora_redo_log_size}" %{ endif } \
%{ if skip_database_config }--skip-database-config %{ endif } \
%{ if install_workload_agent }--install-workload-agent %{ endif } \
%{ if oracle_metrics_secret != "" }--oracle-metrics-secret "${oracle_metrics_secret}" %{ endif } \
%{ if db_password_secret != "" }--db-password-secret "${db_password_secret}" %{ endif }
