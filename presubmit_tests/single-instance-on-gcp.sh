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

apk add --no-cache zip

gcs_bucket="gs://oracle-toolkit-presubmit-artifacts"

# Append PROW_JOB_ID to the file name to ensure each presubmit test gets a unique copy.
# This prevents one test from deleting the file while it's still in use by another concurrently running test.
# For all Prow-injected environment variables, see:
# https://docs.prow.k8s.io/docs/jobs/#job-environment-variables
toolkit_zip_file_name="oracle-toolkit-${PROW_JOB_ID}.zip"
zip -r /tmp/${toolkit_zip_file_name} . -x ".git*" -x ".terraform*" -x "terraform*" -x OWNERS > /dev/null
gcloud storage cp /tmp/${toolkit_zip_file_name} "${gcs_bucket}/"

cd terraform

vm_name="github-presubmit-single-instance-${PROW_JOB_ID}"
deployment_name="${vm_name}"

gcloud infra-manager deployments apply projects/gcp-oracle-benchmarks/locations/us-central1/deployments/"${deployment_name}" \
  --service-account projects/gcp-oracle-benchmarks/serviceAccounts/infra-manager-deployer@gcp-oracle-benchmarks.iam.gserviceaccount.com \
  --local-source="." \
  --input-values="deployment_name=${deployment_name}" \
  --input-values="gcs_source=${gcs_bucket}/${toolkit_zip_file_name}" \
  --input-values="instance_name=${vm_name}"


# 1. Wait for the control-node's startup script to complete
# 2. verify Ansible_log contains "state=ansible_completed_success"
# 3. delete the deployment
# 4. delete "gs://oracle-toolkit-presubmit-artifacts/${toolkit_zip_file_name}" to prevent the GCS bucket from growing indefinitely
