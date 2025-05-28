#!/bin/bash

set -e

BUCKET_NAME="${bucket_name}"
ARCHIVE_NAME="oracle-toolkit.zip"
DEST_DIR="/oracle-toolkit"

apt-get install -y ansible python3-jmespath unzip

SSH_USER=$(gcloud compute os-login describe-profile --format=json | jq -r '.posixAccounts[].username')

echo "Triggering SSH key creation via OS Login by running a one-time gcloud compute ssh command."
echo "This ensures that a persistent SSH key pair is created and associated with your Google Account."
echo "The private auto-generated ssh key (~/.ssh/google_compute_engine) will be used by Ansible to connect to the VM and run playbooks remotely."
echo "Command:"
echo "gcloud compute ssh ${instance_name} --zone=${instance_zone} --internal-ip --quiet --command whoami"

until gcloud compute ssh ${instance_name} --zone=${instance_zone} --internal-ip --quiet --command whoami; do
  echo "Waiting for SSH to become available on ${instance_name}..."
  sleep 5
done

mkdir -p "$DEST_DIR"
echo "Downloading gs://$BUCKET_NAME/$ARCHIVE_NAME to /tmp"
gsutil cp "gs://$BUCKET_NAME/$ARCHIVE_NAME" /tmp/
echo "Extracting files from /tmp/$ARCHIVE_NAME to $DEST_DIR"
unzip "/tmp/$ARCHIVE_NAME" -d "$DEST_DIR"
rm "/tmp/$ARCHIVE_NAME"

cd "$DEST_DIR"

bash install-oracle.sh \
--instance-ssh-user "$SSH_USER" \
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

CONTROL_NODE_NAME=$(curl -X GET http://metadata.google.internal/computeMetadata/v1/instance/name -H 'Metadata-Flavor: Google')
CONTROL_NODE_ZONE=$(curl -X GET http://metadata.google.internal/computeMetadata/v1/instance/zone -H 'Metadata-Flavor: Google')
echo "Destroying $CONTROL_NODE_NAME control node VM in zone $CONTROL_NODE_ZONE"
gcloud --quiet compute instances delete $CONTROL_NODE_NAME --zone=$CONTROL_NODE_ZONE
