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

# See variables.tf for a full list, and descriptions.

gcs_source = "gs://oracle-toolkit-presubmit-artifacts/oracle-toolkit.zip" # gets overridden by "gcloud infra-manager deployments apply ... --input-values"
ora_swlib_bucket = "gs://bmaas-testing-oracle-software"
project_id = "gcp-oracle-benchmarks"
vm_service_account = "oracle-vm-runner@gcp-oracle-benchmarks.iam.gserviceaccount.com"
control_node_service_account = "control-node-sa@gcp-oracle-benchmarks.iam.gserviceaccount.com"
install_workload_agent = true
oracle_metrics_secret = "projects/gcp-oracle-benchmarks/secrets/workload-agent-user-password/versions/latest"
db_password_secret = "projects/gcp-oracle-benchmarks/secrets/sys-user-password/versions/latest"
instance_name = "github-presubmit-1" # gets overridden by "gcloud infra-manager deployments apply ... --input-values"
source_image_family = "oracle-linux-8"
source_image_project = "oracle-linux-cloud"
machine_type = "n4-standard-2"
boot_disk_type = "hyperdisk-balanced"
boot_disk_size_gb = "50"
swap_disk_size_gb = "50"
deployment_name = "github-presubmit-single-instance"
zone1 = "us-central1-b"
subnetwork1 = "projects/gcp-oracle-benchmarks/regions/us-central1/subnetworks/default"
oracle_home_disk = {
  size_gb = 50
}
data_disk = {
  size_gb = 50
}
reco_disk = {
  size_gb = 50
}
ora_version = "19"
ora_release = "latest"
ora_edition = "EE"
ora_backup_dest = "+RECO"
ora_db_name = "orcl"
ora_db_container = false
ntp_pref = "169.254.169.254"
ora_listener_port = "1521"
ora_redo_log_size = "100MB"
skip_database_config = false
