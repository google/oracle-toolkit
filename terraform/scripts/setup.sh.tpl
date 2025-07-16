#!/bin/bash

control_node_name="$(curl -s http://metadata.google.internal/computeMetadata/v1/instance/name -H 'Metadata-Flavor: Google')"
# The zone value from the metadata server is in the format 'projects/PROJECT_NUMBER/zones/ZONE'.
# extracting the last part
control_node_zone_full="$(curl -s http://metadata.google.internal/computeMetadata/v1/instance/zone -H 'Metadata-Flavor: Google')"
control_node_zone="$(basename "$control_node_zone_full")"
control_node_project_id="$(curl -s http://metadata.google.internal/computeMetadata/v1/project/project-id -H 'Metadata-Flavor: Google')"

cleanup() {
  if [[ -n "$heartbeat_pid" ]]; then
    echo "Stopping heartbeat process $heartbeat_pid"
    kill -9 "$heartbeat_pid" 2>/dev/null
  fi
  # https://cloud.google.com/compute/docs/troubleshooting/troubleshoot-os-login#invalid_argument
  echo "Deleting the public SSH key from the control node's service account OS Login profile to prevent exceeding the 32KiB limit"
  if ! gcloud --quiet compute os-login ssh-keys remove --key-file=/root/.ssh/google_compute_engine.pub; then
    echo "WARNING: Failed to remove SSH key. Continuing with instance deletion."
  fi
  echo "Deleting '$control_node_name' GCE instance in zone '$control_node_zone' in project '$control_node_project_id'..."
  gcloud --quiet compute instances delete "$control_node_name" --zone="$control_node_zone" --project="$control_node_project_id"
}

trap cleanup EXIT

CLOUD_LOG_NAME="Ansible_logs"
HEARTBEAT_INTERVAL=60

send_heartbeat() {
  while true; do
    timestamp=$(date --rfc-3339=seconds)
    payload=$(cat <<EOF
{
  "heartbeat": "true",
  "state": "heartbeat",
  "timestamp": "$timestamp",
  "deployment_name": "${deployment_name}",
  "instanceName": "$control_node_name",
  "zone": "$control_node_zone"
}
EOF
)
    gcloud logging write "$CLOUD_LOG_NAME" "$payload" --payload-type=json
    sleep "$HEARTBEAT_INTERVAL"
  done
}

send_ansible_completion_status() {
  exit_code=$1
  if [[ $exit_code -eq 0 ]]; then
    state="ansible_completed_success"
  else
    state="ansible_completed_failure"
  fi

  timestamp=$(date --rfc-3339=seconds)
  payload=$(cat <<EOF
{
  "state": "$state",
  "event_type": "ANSIBLE_RUNNER_SCRIPT_END",
  "timestamp": "$timestamp",
  "deployment_name": "${deployment_name}",
  "instanceName": "$control_node_name",
  "zone": "$control_node_zone"
}
EOF
  )
echo "Sending a signal to Cloud Logging to indicate Ansible completion status"
echo "JSON payload to be sent: $payload"
gcloud logging write "$CLOUD_LOG_NAME" "$payload" --payload-type=json
}

send_heartbeat &
heartbeat_pid=$!

echo "Heartbeat started with PID $heartbeat_pid"


DEST_DIR="/oracle-toolkit"

apt-get update
apt-get install -y ansible python3-jmespath unzip python3-google-auth

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

num_nodes="$(echo '${database_vm_nodes_json}' | jq "length")"
echo "num_nodes=$num_nodes"

primary_ip=""
if [[ "$num_nodes" > 1 ]]; then
  primary_ip="$(echo '${database_vm_nodes_json}' | jq -r '.[] | select(.role == "primary") | .ip')"
  if [[ -z "$primary_ip" ]]; then
    echo "ERROR: Could not find a primary node with role 'primary'."
    exit 1
  fi
  echo "PRIMARY_IP: $primary_ip"
fi

cd "$DEST_DIR"

# Enable logging of Ansible tasks in JSON format to Google Cloud Logging
cat <<EOF >> ./ansible.cfg
callback_plugins = ./tools/callback_plugins

[cloud_logging]
project = $control_node_project_id
ignore_gcp_api_errors = false
enable_async_logging = true
log_name = $CLOUD_LOG_NAME
EOF

export DEPLOYMENT_NAME="${deployment_name}"

ssh_user=""
for node in $(echo '${database_vm_nodes_json}' | jq -c '.[] | select(.role == "primary")'); do
  node_name="$(echo "$node" | jq -r '.name')"
  node_ip="$(echo "$node" | jq -r '.ip')"
  node_zone="$(echo "$node" | jq -r '.zone')"

  echo "Triggering SSH key creation via OS Login by running a one-time gcloud compute ssh command."
  echo "This ensures that a persistent SSH key pair is created and associated with your Google Account."
  echo "The private auto-generated ssh key (~/.ssh/google_compute_engine) will be used by Ansible to connect to the VM and run playbooks remotely."
  echo "Command:"
  echo "gcloud compute ssh '$node_name' --zone='$node_zone' --internal-ip --quiet --command whoami"

  timeout 2m bash -c "until gcloud compute ssh \"$node_name\" --zone=\"$node_zone\" --internal-ip --quiet --command whoami; do
    echo \"Waiting for SSH to become available on '$node_name'...\"
    sleep 5
  done" || {
    echo "ERROR: Timed out waiting for SSH"
    exit 1
  }

  ssh_user="$(gcloud compute os-login describe-profile --format='value(posixAccounts[0].username)')"
  if [[ -z "$ssh_user" ]]; then
    echo "ERROR: Failed to extract the POSIX username. This may be due to OS Login not being enabled or missing IAM permissions."
    exit 1
  fi

    echo "Configuring PRIMARY node: $node_name, IP: $node_ip, Zone: $node_zone"
    bash install-oracle.sh \
    --cluster-type NONE \
    --instance-ip-addr "$node_ip" \
    --instance-ssh-user "$ssh_user" \
    --instance-ssh-key /root/.ssh/google_compute_engine \
    ${common_flags}
    
    exit_code=$?

    if [[ $exit_code -ne 0 ]]; then
      echo "Error: Primary setup failed for $node_name. Exiting."
      send_ansible_completion_status $exit_code
      exit 1
    fi
done


if [[ "$num_nodes" -gt 1 ]]; then
  for node in $(echo '${database_vm_nodes_json}' | jq -c '.[] | select(.role == "standby")'); do
    node_name="$(echo "$node" | jq -r '.name')"
    node_ip="$(echo "$node" | jq -r '.ip')"
    node_zone="$(echo "$node" | jq -r '.zone')"

    echo "Verifying primary node is reachable at $primary_ip..."

    if ping -c 3 "$primary_ip"; then
      echo "Primary node is reachable. Proceeding with standby setup."
    else
      echo "Error: Primary node $primary_ip is not reachable. Cannot continue with standby setup."
      send_ansible_completion_status 1
      exit 1
    fi

    echo "Configuring STANDBY node: $node_name, IP: $node_ip, Zone: $node_zone"
    bash install-oracle.sh \
    --cluster-type DG \
    --primary-ip-addr "$primary_ip" \
    --instance-ip-addr "$node_ip" \
    --instance-ssh-user "$ssh_user" \
    --instance-ssh-key /root/.ssh/google_compute_engine \
    ${common_flags}

    exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
      echo "Error: Standby setup failed for $node_name. Exiting."
      send_ansible_completion_status $exit_code
      exit $exit_code
    fi
  done
fi

send_ansible_completion_status 0