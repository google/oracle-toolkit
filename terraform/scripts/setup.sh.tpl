#!/bin/bash

%{ if false }
# The following is a template-only comment and will not appear in the rendered script:
#
# Since this is a Terraform template file, to output a literal shell variable,
# you must escape the dollar sign. Use a double-dollar-sign to prevent Terraform from interpolating it.
%{ endif }

# Google Cloud Log Entry has a maximum size of 256 KiB.
# We truncate the error message to this size to guarantee the entire log payload is accepted.
readonly MAX_ERROR_SIZE=250000 # leaving 6 KiB margin for other JSON fields

control_node_name="$(curl -fsS http://metadata.google.internal/computeMetadata/v1/instance/name -H 'Metadata-Flavor: Google')" || {
  echo "Error: Failed to retrieve control node's instance name"
  exit 1
}
control_node_vmid="$(curl -fsS http://metadata.google.internal/computeMetadata/v1/instance/id -H 'Metadata-Flavor: Google')" || {
  echo "Error: Failed to retrieve control node's instance ID"
  exit 1
}
control_node_zone_full="$(curl -fsS http://metadata.google.internal/computeMetadata/v1/instance/zone -H 'Metadata-Flavor: Google')" || {
  echo "Error: Failed to retrieve control's node zone"
  exit 1
}
control_node_zone="$(basename "$control_node_zone_full")" || {
  echo "Error: Failed to extract zone name from: $control_node_zone_full"
  exit 1
}
control_node_project_id="$(curl -fsS http://metadata.google.internal/computeMetadata/v1/project/project-id -H 'Metadata-Flavor: Google')" || {
  echo "Error: Failed to retrieve project ID"
  exit 1
}
control_node_sa="$(curl -fsS http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/email -H 'Metadata-Flavor: Google')" || {
  echo "Error: Failed to retrieve service account email"
  exit 1
}

cleanup() {
  if [[ -n "$heartbeat_pid" ]] && kill -0 "$heartbeat_pid" >/dev/null 2>&1; then
    echo "Stopping heartbeat process $heartbeat_pid"
    kill "$heartbeat_pid" >/dev/null 2>&1
    timeout 5s wait "$heartbeat_pid" 2>/dev/null
  fi
  # https://cloud.google.com/compute/docs/troubleshooting/troubleshoot-os-login#invalid_argument
  echo "Deleting public SSH key from the control node's service account OS Login profile to prevent exceeding the 32KiB limit"
  if [[ -f "/root/.ssh/google_compute_engine.pub" ]]; then
    echo "Public SSH key found. Attempting to remove it from OS Login..."
    if ! gcloud --quiet compute os-login ssh-keys remove --key-file=/root/.ssh/google_compute_engine.pub; then
      echo "WARNING: Failed to remove SSH key."
    fi
    echo "Public SSH key has been removed from the control node's service account OS Login profile"
  fi
  %{ if delete_control_node }
  echo "Deleting '$control_node_name' GCE instance in zone '$control_node_zone' in project '$control_node_project_id'..."
  gcloud --quiet compute instances delete "$control_node_name" --zone="$control_node_zone" --project="$control_node_project_id"
  %{ endif }
}

trap cleanup SIGINT SIGTERM EXIT

cloud_log_name="Ansible_logs"
heartbeat_interval=60

send_heartbeat() {
  while true; do
    json_payload=$(jq -n \
    --arg heartbeat "true" \
    --arg state "heartbeat" \
    --arg timestamp "$(date --rfc-3339=seconds)" \
    --arg deployment_name "${deployment_name}" \
    --arg instanceName "$control_node_name" \
    --arg instanceId "$control_node_vmid" \
    --arg zone "$control_node_zone" \
    '{heartbeat: $heartbeat, state: $state, timestamp: $timestamp, deployment_name: $deployment_name, instanceName: $instanceName, instanceId: $instanceId, zone: $zone}')
    gcloud logging write "$cloud_log_name" "$json_payload" --payload-type=json || exit 1
    sleep "$heartbeat_interval"
  done
}

send_ansible_completion_status() {
  exit_code=$1
  if [[ $exit_code -eq 0 ]]; then
    state="ansible_completed_success"
  else
    state="ansible_completed_failure"
  fi

  json_payload=$(jq -n \
  --arg state "$state" \
  --arg event_type "ANSIBLE_RUNNER_SCRIPT_END" \
  --arg timestamp "$(date --rfc-3339=seconds)" \
  --arg deployment_name "${deployment_name}" \
  --arg instanceName "$control_node_name" \
  --arg instanceId "$control_node_vmid" \
  --arg zone "$control_node_zone" \
  '{state: $state, event_type: $event_type, timestamp: $timestamp, deployment_name: $deployment_name, instanceName: $instanceName, instanceId: $instanceId, zone: $zone}')
  echo "Sending a signal to Cloud Logging to indicate Ansible completion status"
  echo "JSON payload to be sent: $json_payload"
  gcloud logging write "$cloud_log_name" "$json_payload" --payload-type=json || exit 1
}

send_startup_script_failure_status() {
  json_payload=$(jq -n \
  --arg state "ansible_start_failure" \
  --arg step_name "bootstrap Ansible scripts" \
  --arg error_message "$1" \
  --arg timestamp "$(date --rfc-3339=seconds)" \
  --arg deployment_name "${deployment_name}" \
  --arg instanceName "$control_node_name" \
  --arg instanceId "$control_node_vmid" \
  --arg zone "$control_node_zone" \
  '{state: $state, step_name: $step_name, error_message: $error_message, timestamp: $timestamp, deployment_name: $deployment_name, instanceName: $instanceName, instanceId: $instanceId, zone: $zone}')
  gcloud logging write "$cloud_log_name" "$json_payload" --payload-type=json || exit 1
}

# Run send_heartbeat in the background. We redirect its output to stderr (>&2)
# to prevent the script from hanging.
# The main script pipes its output to `tee`. If this background process also
# wrote to stdout, it would keep the pipe open, and `tee` would wait
# forever. The main `2>&1` ensures these heartbeat logs are still captured.
send_heartbeat >&2 &
heartbeat_pid=$!

echo "Heartbeat started with PID $heartbeat_pid"


DEST_DIR="/oracle-toolkit"

%{ if !assign_public_ip }
# Use a package mirror accessible via Private Google Access
cat > /etc/apt/sources.list.d/debian-mirror.list <<-EOF
deb https://us-apt.pkg.dev/remote/artifact-registry-apt-cache/remote-debian-bookworm bookworm main contrib non-free non-free-firmware
deb https://us-apt.pkg.dev/remote/artifact-registry-apt-cache/remote-debian-bookworm-updates bookworm-updates main contrib non-free non-free-firmware
deb https://us-apt.pkg.dev/remote/artifact-registry-apt-cache/remote-debian-bookworm-security bookworm-security main contrib non-free non-free-firmware
EOF
%{endif}

export DEBIAN_FRONTEND=noninteractive
apt-get --quiet update || exit 1
apt-get install --quiet --assume-yes ansible python3-jmespath unzip python3-google-auth || exit 1


echo "Downloading ${gcs_source} to /tmp"
if ! gcloud --quiet storage cp "${gcs_source}" /tmp/; then
  error_message="ERROR: Failed to download ${gcs_source}. Make sure the file exists and that the service account $control_node_sa has 'roles/storage.objectViewer' role on the bucket."
  echo "$error_message"
  send_startup_script_failure_status "$error_message"
  exit 1
fi
zip_file="$(basename "${gcs_source}")"
mkdir -p "$DEST_DIR"
echo "Extracting files from $zip_file to $DEST_DIR"
unzip -qq -o "/tmp/$zip_file" -d "$DEST_DIR"

num_nodes="$(echo '${database_vm_nodes_json}' | jq "length")"
echo "num_nodes=$num_nodes"

primary_ip=""
if [[ "$num_nodes" -gt 1 ]]; then
  primary_ip="$(echo '${database_vm_nodes_json}' | jq -r '.[] | select(.role == "primary") | .ip')"
  if [[ -z "$primary_ip" ]]; then
    error_message="ERROR: Could not find a primary node with role 'primary'."
    echo "$error_message"
    send_startup_script_failure_status "$error_message"
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
log_name = $cloud_log_name
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
  echo "gcloud --quiet compute ssh '$node_name' --zone='$node_zone' --internal-ip --command whoami"

  timeout 2m bash -c "until gcloud --quiet compute ssh \"$node_name\" --zone=\"$node_zone\" --internal-ip --command whoami; do
    echo \"Waiting for SSH to become available on '$node_name'...\"
    sleep 5
  done" || {
    error_message="ERROR: SSH timeout from VM $control_node_name to database VM $node_name in $node_zone. This is typically a VPC configuration issue."
    echo "$error_message"
    send_startup_script_failure_status "$error_message"
    exit 1
  }

  ssh_user="$(gcloud --quiet compute os-login describe-profile --format='value(posixAccounts[0].username)')" || {
    error_message="ERROR: Failed to extract the POSIX username. This may be due to OS Login not being enabled or missing IAM permissions."
    echo "$error_message"
    send_startup_script_failure_status "$error_message"
    exit 1
  }

  if [[ -f "/root/.ssh/google_compute_engine.pub" ]]; then
    echo "Setting expiration on SSH key"
    if ! gcloud --quiet compute os-login ssh-keys update --key-file=/root/.ssh/google_compute_engine.pub --ttl=24h; then
      echo "WARNING: Failed to set expiration for SSH key."
    fi
  fi

    echo "Configuring PRIMARY node: $node_name, IP: $node_ip, Zone: $node_zone"
    temp_log=$(mktemp)
    bash install-oracle.sh \
    --cluster-type NONE \
    --instance-ip-addr "$node_ip" \
    --instance-ssh-user "$ssh_user" \
    --instance-ssh-key /root/.ssh/google_compute_engine \
    ${common_flags} 2>&1 | tee "$temp_log" # The common_flags is passed in from terraform/main.tf.
    exit_code="$${PIPESTATUS[0]}"
    # Exit code 52 indicates a failure in the install-oracle.sh script.
    if [[ "$exit_code" -eq 52 ]]; then
      error_message=$(head -c "$MAX_ERROR_SIZE" "$temp_log")
      if [[ $(wc -c < "$temp_log") -gt "$MAX_ERROR_SIZE" ]]; then
        error_message+="... LOG TRUNCATED TO $MAX_ERROR_SIZE BYTES ..."
      fi
      send_startup_script_failure_status "$error_message"
      exit "$exit_code"
    # Any other non-zero exit code is assumed to be a failure in the Ansible playbook.
    elif [[ "$exit_code" -ne 0 ]]; then
      echo "Error: Primary setup failed for $node_name. Exiting."
      send_ansible_completion_status "$exit_code"
      exit "$exit_code"
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
    temp_log=$(mktemp)
    bash install-oracle.sh \
    --cluster-type DG \
    --primary-ip-addr "$primary_ip" \
    --instance-ip-addr "$node_ip" \
    --instance-ssh-user "$ssh_user" \
    --instance-ssh-key /root/.ssh/google_compute_engine \
    ${common_flags} 2>&1 | tee "$temp_log"  # The common_flags is passed in from terraform/main.tf.
    exit_code="$${PIPESTATUS[0]}"
    # Exit code 52 indicates a failure in the install-oracle.sh script.
    if [[ "$exit_code" -eq 52 ]]; then
      error_message="$(head -c "$MAX_ERROR_SIZE" "$temp_log")"
      if [[ $(wc -c < "$temp_log") -gt "$MAX_ERROR_SIZE" ]]; then
        error_message+="... LOG TRUNCATED TO $MAX_ERROR_SIZE BYTES ..."
      fi
      send_startup_script_failure_status "$error_message"
      exit "$exit_code"
    # Any other non-zero exit code is assumed to be a failure in the Ansible playbook.
    elif [[ "$exit_code" -ne 0 ]]; then
      echo "Error: Standby setup failed for $node_name. Exiting."
      send_ansible_completion_status "$exit_code"
      exit "$exit_code"
    fi
  done
fi

send_ansible_completion_status 0
