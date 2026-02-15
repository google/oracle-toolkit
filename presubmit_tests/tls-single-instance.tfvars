# Copyright 2025 Google LLC
# Licensed under the Apache License, Version 2.0.

# -----------------------------------------------------------------------------
# TLS / SSL Configuration
# -----------------------------------------------------------------------------
enable_tls      = true

# IMPORTANT: Ensure these resources exist in the 'gcp-oracle-benchmarks' project
cas_pool_id     = "projects/gcp-oracle-benchmarks/locations/us-central1/caPools/presubmit-ca-pool"
dns_zone_name   = "presubmit-private-zone"
dns_domain_name = "presubmit.internal."
db_hostname     = "oracle-tls-test"

# -----------------------------------------------------------------------------
# Single Instance Configuration (Zone 2 Empty)
# -----------------------------------------------------------------------------
zone1           = "us-central1-b"
# Leaving zone2 empty forces the Terraform logic to deploy a Single Instance
zone2           = ""
subnetwork1     = "projects/gcp-oracle-benchmarks/regions/us-central1/subnetworks/github-presubmit-tests-us-central1"
subnetwork2     = ""  # Not needed for single instance

# -----------------------------------------------------------------------------
# Standard Presubmit Values (Placeholders & Defaults)
# -----------------------------------------------------------------------------
# Placeholders replaced by the shell script at runtime
gcs_source      = "@gcs_source@"
deployment_name = "@deployment_name@"
instance_name   = "@instance_name@"

ora_swlib_bucket             = "gs://bmaas-testing-oracle-software"
delete_control_node          = false
project_id                   = "gcp-oracle-benchmarks"
vm_service_account           = "oracle-vm-runner@gcp-oracle-benchmarks.iam.gserviceaccount.com"
control_node_service_account = "control-node-sa@gcp-oracle-benchmarks.iam.gserviceaccount.com"
install_workload_agent       = true
oracle_metrics_secret        = "projects/gcp-oracle-benchmarks/secrets/workload-agent-user-password/versions/latest"
db_password_secret           = "projects/gcp-oracle-benchmarks/secrets/sys-user-password/versions/latest"
control_node_name_prefix     = "github-presubmit-tls-control"

source_image_family  = "oracle-linux-8"
source_image_project = "oracle-linux-cloud"
machine_type         = "n4-standard-2"
boot_disk_type       = "hyperdisk-balanced"
boot_disk_size_gb    = "20"
swap_disk_size_gb    = "8"

oracle_home_disk = {
  size_gb = 50
}
data_disk = {
  size_gb = 20
}
reco_disk = {
  size_gb = 15
}

ora_version      = "19"
ora_release      = "latest"
ora_edition      = "EE"
ora_backup_dest  = "/u03/backup"
ora_db_name      = "orcl"
ora_db_domain    = "tls.test.com"
ora_db_container = false
ora_disk_mgmt    = "FS"
