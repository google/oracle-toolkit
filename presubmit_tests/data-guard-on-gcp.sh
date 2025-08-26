#!/bin/bash
# Copyright 2025 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


apk add --no-cache zip curl py3-pip expect || exit 1

gcs_bucket="gs://oracle-toolkit-presubmit-artifacts"
# Append BUILD_ID to the file name to ensure each zip file gets a unique name.
# This prevents one test from deleting the file while it's still in use by another concurrently running test.
# For available Prow-injected environment variables, see:
# https://docs.prow.k8s.io/docs/jobs/#job-environment-variables
toolkit_zip_file_name="oracle-toolkit-${BUILD_ID}.zip"
tfvars_file="./presubmit_tests/data-guard.tfvars"
instance_name="github-presubmit-dg-${BUILD_ID}"
deployment_name="presubmit-dg-${BUILD_ID}"
location="us-central1"
project_id="$(curl -fsS -H "Metadata-Flavor: Google" "http://metadata.google.internal/computeMetadata/v1/project/project-id")" || {
  echo "Error: Failed to retrieve project ID"
  exit 1
}
gcs_source="${gcs_bucket}/${toolkit_zip_file_name}"
deployment_id="projects/${project_id}/locations/${location}/deployments/${deployment_name}"

cleanup() {
  if [[ -n "$tail_pgid_leader" ]]; then
    echo "Killing tail process group with $tail_pgid_leader PGID"
    kill -TERM -"$tail_pgid_leader"
  fi
  echo "Cleaning up: deleting ${gcs_source} GCS object and ${deployment_id} Infra Manager deployment..."
  if gcloud infra-manager deployments describe "${deployment_id}" >/dev/null 2>&1; then
    gcloud --quiet infra-manager deployments delete "${deployment_id}" 
  fi
  if gcloud storage objects describe "${gcs_source}" >/dev/null 2>&1; then
    gcloud --quiet storage rm "${gcs_source}"
  fi
}

trap cleanup SIGINT SIGTERM EXIT

echo "Zipping CWD into /tmp/${toolkit_zip_file_name} and uploading to ${gcs_bucket}/..."
zip -r /tmp/"${toolkit_zip_file_name}" . -x ".git*" -x ".terraform*" -x "terraform*" -x OWNERS > /dev/null
if ! gcloud --quiet storage cp /tmp/"${toolkit_zip_file_name}" "${gcs_bucket}/"; then 
  echo "ERROR: Failed to upload /tmp/"${toolkit_zip_file_name}" to "${gcs_bucket}/". Make sure the service account has write permissions on the bucket."
  exit 1
fi

sed -i "s|@deployment_name@|$deployment_name|g" "${tfvars_file}"
sed -i "s|@gcs_source@|$gcs_source|g" "${tfvars_file}"
sed -i "s|@instance_name@|$instance_name|g" "${tfvars_file}"

echo "Applying Infra Manager deployment: ${deployment_id}"
gcloud infra-manager deployments apply "${deployment_id}" \
  --service-account="projects/${project_id}/serviceAccounts/infra-manager-deployer@${project_id}.iam.gserviceaccount.com" \
  --local-source="./terraform" \
  --inputs-file="${tfvars_file}" || exit 1

# Extract the id of the control node resource
# The format is: projects/<project>/zones/<zone>/instances/control-node-<random-suffix>
control_node_resource_id="$(gcloud infra-manager resources list \
--deployment="${deployment_name}" \
--location="${location}" \
--revision=r-0 \
--filter='terraformInfo.address=google_compute_instance.control_node' \
--format='value(terraformInfo.id)')" || {
  echo "Error: Failed to retrieve control node's resource ID."
  exit 1
}

# Get the instance ID from the instance resource
control_node_instance_id="$(gcloud compute instances describe "${control_node_resource_id}" --format="value(id)")" || {
  echo "Error: Failed to get control node's instance ID."
  exit 1
}

read -r -d '' query <<EOF
resource.type="gce_instance"
log_name="projects/${project_id}/logs/google_metadata_script_runner"
resource.labels.instance_id="${control_node_instance_id}"
EOF
encoded_query="$(python3 -c "import urllib.parse, sys; print(urllib.parse.quote(sys.stdin.read(), safe=''), end='')" <<< "$query")"
duration="PT1H"
console_link="https://console.cloud.google.com/logs/query;query=${encoded_query};duration=${duration}?project=${project_id}"
echo "Link to the control node's startup log:"
echo "${console_link}"

# Stream logs from the startup script execution to stdout in the background
# https://cloud.google.com/logging/docs/reference/tools/gcloud-logging#install_live_tailing
echo "Installing required gcloud alpha components..."
gcloud --quiet components install alpha || exit 1
pip3 install grpcio --break-system-packages || exit 1
echo "Streaming logs from the control node's startup script execution..."
echo

# The 'gcloud alpha logging tail' command may display 'SyntaxWarning: invalid escape sequence' warnings.
# These warnings are harmless and can be safely ignored using PYTHONWARNINGS=ignore.
# 'unbuffer' is used here to avoid delayed and missing logs caused by output buffering in non-interactive session"
# gcloud logging tail has a 1-hour session limit. We run it in a loop to maintain continuous log streaming beyond that limit.
setsid bash <<EOF &
  export CLOUDSDK_PYTHON_SITEPACKAGES=1
  while true; do
    echo "$(date '+%Y-%m-%d %H:%M:%S')    Starting gcloud logging tail session..."
    PYTHONWARNINGS="ignore" unbuffer gcloud alpha logging tail \
    "resource.type=gce_instance AND \
    resource.labels.instance_id=${control_node_instance_id} \
    AND log_name=projects/${project_id}/logs/google_metadata_script_runner" \
    --format='value(timestamp.date(format="%Y-%m-%d %H:%M:%S"), json_payload.message.sub("^startup-script: ", ""))'
    echo "$(date '+%Y-%m-%d %H:%M:%S')     Tail session ended. Restarting..."
  done
EOF

tail_pgid_leader=$!


sleep_seconds=60
timeout_seconds=10800
timeout_hours="$((timeout_seconds / 3600))"
timeout_minutes="$(((timeout_seconds % 3600) / 60))"
start_time="$(date +%s)"

echo "Waiting up to ${timeout_hours} hours and ${timeout_minutes} minutes for control node's startup script to complete..."
echo

while true; do
  current_time="$(date +%s)"
  elapsed="$((current_time - start_time))"

  if [[ "${elapsed}" -ge "${timeout_seconds}" ]]; then
    echo "Timeout reached after ${timeout_hours} hours and ${timeout_minutes} minutes. No completion log found."
    exit 1
  fi

  state="$(gcloud logging read \
    "resource.type=global AND \
    log_name=projects/${project_id}/logs/Ansible_logs AND \
    jsonPayload.deployment_name=${deployment_name} AND \
    jsonPayload.event_type=ANSIBLE_RUNNER_SCRIPT_END" \
    --order=desc \
    --limit=1 \
    --format='value(jsonPayload.state)')"

  if [[ "${state}" == "ansible_completed_success" ]]; then
    echo "Control node's startup script completed successfully."
    exit 0
  elif [[ "${state}" == "ansible_completed_failure" ]]; then
    echo "Control node's startup script failed."
    exit 1
  fi

  sleep "${sleep_seconds}"
done
