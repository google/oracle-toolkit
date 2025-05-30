#!/bin/bash

set -e

DEST_DIR="/oracle-toolkit"

apt-get install -y ansible python3-jmespath unzip

ssh_user="$(gcloud compute os-login describe-profile --format=json | jq -r '.posixAccounts[].username')"

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
unzip "/tmp/$zip_file" -d "$DEST_DIR"

cd "$DEST_DIR"

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
%{ if oracle_release != "" }--oracle-release "${oracle_release}" %{ endif } \
%{ if ora_edition != "" }--ora-edition "${ora_edition}" %{ endif } \
%{ if ora_listener_port != "" }--ora-listener-port "${ora_listener_port}" %{ endif } \
%{ if ora_redo_log_size != "" }--ora-redo-log-size "${ora_redo_log_size}" %{ endif }

control_node_name="$(curl -s http://metadata.google.internal/computeMetadata/v1/instance/name -H 'Metadata-Flavor: Google')"
control_node_zone="$(curl -s http://metadata.google.internal/computeMetadata/v1/instance/zone -H 'Metadata-Flavor: Google')"
control_node_project_id="$(curl -s http://metadata.google.internal/computeMetadata/v1/project/project-id -H 'Metadata-Flavor: Google')"
echo "Initiating deletion of control node VM '$control_node_name' in zone '$controcontrol_node_zonel_node_name' in project '$control_node_project_id'..."
gcloud --quiet compute instances delete "$control_node_name" --zone="$control_node_zone" --project="$control_node_project_id"

echo "Startup script execution complete"
