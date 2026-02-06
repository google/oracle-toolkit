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

# Placeholder values in the form "@value@" will be replaced with actual values by the single-instance-on-gcp.sh script.
gcs_source = "@gcs_source@"
deployment_name = "@deployment_name@"
instance_name = "@instance_name@"

ora_swlib_bucket = "gs://bmaas-testing-oracle-software"
delete_control_node = false
project_id = "gcp-oracle-benchmarks"
vm_service_account = "oracle-vm-runner@gcp-oracle-benchmarks.iam.gserviceaccount.com"
control_node_service_account = "control-node-sa@gcp-oracle-benchmarks.iam.gserviceaccount.com"
install_workload_agent = true
oracle_metrics_secret = "projects/gcp-oracle-benchmarks/secrets/workload-agent-user-password/versions/latest"
db_password_secret = "projects/gcp-oracle-benchmarks/secrets/sys-user-password/versions/latest"
control_node_name_prefix="github-presubmit-dg-control-node"
source_image_family = "oracle-linux-8"
source_image_project = "oracle-linux-cloud"
machine_type = "n4-standard-2"
boot_disk_type = "hyperdisk-balanced"
boot_disk_size_gb = "20"
swap_disk_size_gb = "8"
zone1 = "us-central1-b"
zone2 = "us-central1-c"
subnetwork1 = "projects/gcp-oracle-benchmarks/regions/us-central1/subnetworks/github-presubmit-tests-us-central1"
subnetwork2 = "projects/gcp-oracle-benchmarks/regions/us-central1/subnetworks/github-presubmit-tests-us-central1"
oracle_home_disk = {
  size_gb = 50
}
data_disk = {
  size_gb = 20
}
reco_disk = {
  size_gb = 15
}
ora_version = "19"
ora_release = "latest"
ora_edition = "EE"
ora_backup_dest = "/u03/backup"
ora_db_name = "orcl"
ora_db_domain = "test2.example_domain01.com"
ora_db_container = false
ora_disk_mgmt = "FS"
assign_public_ip = false
enable_ar_repo = true

