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


gcs_bucket="gs://oracle-toolkit-presubmit-artifacts"
# Append BUILD_ID to the file name to ensure each presubmit test gets a unique copy.
# This prevents one test from deleting the file while it's still in use by another concurrently running test.
# For available Prow-injected environment variables, see:
# https://docs.prow.k8s.io/docs/jobs/#job-environment-variables
toolkit_zip_file_name="oracle-toolkit-${BUILD_ID}.zip"
tfvars_file="./presubmit_tests/single-instance.tfvars"
instance_name="github-presubmit-si-${BUILD_ID}"
deployment_name="presubmit-si-${BUILD_ID}"
gcs_source="${gcs_bucket}/${toolkit_zip_file_name}"
deployment_id="projects/gcp-oracle-benchmarks/locations/us-central1/deployments/${deployment_name}"

apk add --no-cache zip jq

echo "Zipping CWD into /tmp/${toolkit_zip_file_name} and uploading to ${gcs_bucket}/..."
zip -r /tmp/${toolkit_zip_file_name} . -x ".git*" -x ".terraform*" -x "terraform*" -x OWNERS > /dev/null
gcloud storage cp /tmp/${toolkit_zip_file_name} "${gcs_bucket}/"

sed -i "s|@deployment_name@|$deployment_name|g" "${tfvars_file}"
sed -i "s|@gcs_source@|$gcs_source|g" "${tfvars_file}"
sed -i "s|@instance_name@|$instance_name|g" "${tfvars_file}"

echo "Applying Infra Manager deployment: ${deployment_id}"

gcloud infra-manager deployments apply "${deployment_id}" \
  --service-account="projects/gcp-oracle-benchmarks/serviceAccounts/infra-manager-deployer@gcp-oracle-benchmarks.iam.gserviceaccount.com" \
  --local-source="./terraform" \
  --inputs-file="${tfvars_file}"

cleanup() {
  echo "Cleaning up: deleting "${gcs_source}" GCS object and ${deployment_id} Infra Manager deployment..."
  if gcloud infra-manager deployments describe "${deployment_id}" >/dev/null 2>&1; then
    gcloud infra-manager deployments delete "${deployment_id}"
  fi
  if gcloud storage objects describe "${gcs_source}" >/dev/null 2>&1; then
    gcloud storage rm "${gcs_source}"
  fi
}

trap cleanup SIGINT SIGTERM EXIT

SLEEP_SECONDS=60
TIMEOUT_SECONDS=7200
START_TIME=$(date +%s)

echo "Waiting up to 2 hours for control node's startup script to complete..."

while true; do
  CURRENT_TIME=$(date +%s)
  ELAPSED=$((CURRENT_TIME - START_TIME))

  if [[ "${ELAPSED}" -ge "${TIMEOUT_SECONDS}" ]]; then
    echo "Timeout reached after 2 hours. No completion log found."
    exit 1
  fi

  result=$(gcloud logging read \
    'resource.type="global" AND log_name="projects/gcp-oracle-benchmarks/logs/Ansible_logs" AND jsonPayload.deployment_name="${deployment_name}" AND jsonPayload.event_type="ANSIBLE_RUNNER_SCRIPT_END"' \
    --order=desc \
    --limit=1 \
    --format=json)

  echo "[DEBUGGING] result=${result}"

  state=$(echo "${result}" | jq -r '.[0].jsonPayload.state // empty')

  echo "[DEBUGGING] state=${state}"

  if [[ "${state}" == "ansible_completed_success" ]]; then
    echo "Control node's startup script completed successfully."
    exit 0
  elif [[ "${state}" == "ansible_completed_failure" ]]; then
    echo "Control node's startup script failed."
    exit 1
  fi

  sleep "${SLEEP_SECONDS}"
done
