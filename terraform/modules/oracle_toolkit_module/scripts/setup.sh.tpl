#!/bin/bash

apt-get install -y git ansible python3-jmespath

ssh_user=$(gcloud compute os-login describe-profile --format=json | jq -r '.posixAccounts[].username')

echo "Triggering SSH key creation via OS Login by running a one-time gcloud compute ssh command."
echo "This ensures that a persistent SSH key pair is created and associated with your Google Account."
echo "The private auto-generated ssh key (~/.ssh/google_compute_engine) will be used by Ansible to connect to the VM and run playbooks remotely."
echo "Command:"
echo "gcloud compute ssh ${instance_name} --zone=${instance_zone} --internal-ip --quiet --command whoami"

until gcloud compute ssh ${instance_name} --zone=${instance_zone} --internal-ip --quiet --command whoami; do
  echo "Waiting for SSH to become available on ${instance_name}..."
  sleep 10
done

git clone https://github.com/google/oracle-toolkit.git

cd oracle-toolkit

bash install-oracle.sh \
--instance-ip-addr ${ip_addr} \
--instance-ssh-user $ssh_user \
--instance-ssh-key /root/.ssh/google_compute_engine \
--ora-asm-disks-json '${asm_disk_config}' \
--ora-data-mounts-json '${data_mounts_config}' \
--swap-blk-device ${swap_blk_device} \
--ora-swlib-bucket ${ora_swlib_bucket} \
--ora-version ${ora_version} \
--backup-dest ${ora_backup_dest} \
%{ if ora_db_name != "" }--ora-db-name ${ora_db_name} %{ endif } \
%{ if ora_db_container != "" }--ora-db-container ${ora_db_container} %{ endif } \
%{ if ntp_pref != "" }--ntp-pref ${ntp_pref} %{ endif } \
%{ if oracle_release != "" }--oracle-release ${oracle_release} %{ endif } \
%{ if ora_edition != "" }--ora-edition ${ora_edition} %{ endif } \
%{ if ora_listener_port != "" }--ora-listener-port ${ora_listener_port} %{ endif } \
%{ if ora_redo_log_size != "" }--ora-redo-log-size ${ora_redo_log_size} %{ endif }
