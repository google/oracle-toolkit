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

locals {
  # Mode helper
  is_fs              = upper(var.ora_disk_mgmt) == "FS"
  ora_disk_mgmt_flag = upper(var.ora_disk_mgmt)

  # Base disk definitions (do not change device_name values)
  _u01 = {
    auto_delete  = true
    device_name  = "oracle_home"
    disk_size_gb = var.oracle_home_disk.size_gb
    disk_type    = var.oracle_home_disk.type
    disk_labels  = { purpose = "software" }
  }

  # DATA / RECO in ASMUDEV and ASMLIB mode (with disk groups)
  _data_asm = {
    auto_delete  = true
    device_name  = "data"
    disk_size_gb = var.data_disk.size_gb
    disk_type    = var.data_disk.type
    disk_labels  = { diskgroup = "data", purpose = "asm" }
  }
  _reco_asm = {
    auto_delete  = true
    device_name  = "reco"
    disk_size_gb = var.reco_disk.size_gb
    disk_type    = var.reco_disk.type
    disk_labels  = { diskgroup = "reco", purpose = "asm" }
  }

  # DATA / RECO in FS mode
  _data_fs = {
    auto_delete  = true
    device_name  = "data"
    disk_size_gb = var.data_disk.size_gb
    disk_type    = var.data_disk.type
    disk_labels  = { purpose = "data" }
  }
  _reco_fs = {
    auto_delete  = true
    device_name  = "reco"
    disk_size_gb = var.reco_disk.size_gb
    disk_type    = var.reco_disk.type
    disk_labels  = { purpose = "reco" }
  }

  _swap = {
    auto_delete  = true
    device_name  = "swap"
    disk_size_gb = var.swap_disk_size_gb
    disk_type    = var.swap_disk_type
    disk_labels  = { purpose = "swap" }
  }

  # Build lists based on mode
  # Filesystem disks (participate in XFS mounts via data_mounts_config)
  fs_disks = concat(
    [
      local._u01
    ],
    local.is_fs ? [local._data_fs, local._reco_fs] : []
  )

  asm_disks = concat(
    local.is_fs ? [] : [local._data_asm, local._reco_asm],
    [local._swap]
  )

  # DBCA destinations
  data_dest = local.is_fs ? "/u02/oradata" : "DATA"
  reco_dest = local.is_fs ? "/u03/fast_recovery_area" : "RECO"

  # Takes the list of filesystem disks and converts them into a list of objects with the required fields by ansible
  data_mounts_config = [
    for i, d in local.fs_disks : {
      purpose     = d.disk_labels.purpose
      blk_device  = "/dev/disk/by-id/google-${d.device_name}"
      name        = format("u%02d", i + 1)
      fstype      = "xfs"
      mount_point = format("/u%02d", i + 1)
      mount_opts  = "nofail"
    }
  ]

  # Takes the list of asm disks and converts them into a list of objects with the required fields by ansible
  asm_disk_config = [
    for g in distinct([for d in local.asm_disks : d.disk_labels.diskgroup if lookup(d.disk_labels, "diskgroup", null) != null]) : {
      diskgroup = upper(g)
      disks = [
        for d in local.asm_disks : {
          blk_device = "/dev/disk/by-id/google-${d.device_name}"
          name       = d.device_name
        } if lookup(d.disk_labels, "diskgroup", null) == g
      ]
    }
  ]

  # Concatenetes both lists to be passed down to the instance module
  additional_disks = concat(local.fs_disks, local.asm_disks)

  project_id = var.project_id

  subnetwork1_opt = var.subnetwork1 != "" ? var.subnetwork1 : null
  subnetwork2_opt = var.subnetwork2 != "" ? var.subnetwork2 : null

  is_multi_instance = (var.zone1 != "" && var.zone2 != "")

  instances = local.is_multi_instance ? {
    "${var.instance_name}-1" = {
      zone       = var.zone1
      subnetwork = local.subnetwork1_opt
      role       = "primary"
    }
    "${var.instance_name}-2" = {
      zone       = var.zone2
      subnetwork = local.subnetwork2_opt
      role       = "standby"
    }
    } : {
    "${var.instance_name}-1" = {
      zone       = var.zone1
      subnetwork = local.subnetwork1_opt
      role       = "primary"
    }
  }

  deployment_id = var.deployment_name != "" ? var.deployment_name : var.instance_name
  db_tag        = "ora-db-${local.deployment_id}"
  control_tag   = "ora-control-node-${local.deployment_id}"
}

# Resolve parent VPC network from the subnetwork URI
data "google_compute_subnetwork" "subnetwork" {
  count     = local.subnetwork1_opt != null ? 1 : 0
  self_link = "https://www.googleapis.com/compute/v1/${local.subnetwork1_opt}"
}

locals {
  network = local.subnetwork1_opt == null ? "projects/${var.project_id}/global/networks/default" : data.google_compute_subnetwork.subnetwork[0].network
}

data "google_compute_image" "os_image" {
  family  = var.source_image_family
  project = var.source_image_project
}

resource "time_static" "template_suffix" {}

locals {
  template_suffix = formatdate("YYYYMMDDhhmmss", time_static.template_suffix.rfc3339)
}

resource "google_compute_instance_template" "default" {
  name         = "${var.instance_name}-${local.template_suffix}"
  project      = var.project_id
  machine_type = var.machine_type

  network_interface {
    subnetwork = local.subnetwork1_opt
    network    = local.subnetwork1_opt == null ? "projects/${var.project_id}/global/networks/default" : null
  }

  disk {
    boot         = true
    auto_delete  = true
    source_image = data.google_compute_image.os_image.self_link
    disk_type    = var.boot_disk_type
    disk_size_gb = var.boot_disk_size_gb
  }

  dynamic "disk" {
    for_each = local.additional_disks
    content {
      boot         = false
      auto_delete  = disk.value.auto_delete
      device_name  = disk.value.device_name
      disk_size_gb = disk.value.disk_size_gb
      disk_type    = disk.value.disk_type
      labels       = disk.value.disk_labels
    }
  }

  service_account {
    email  = var.vm_service_account
    scopes = ["cloud-platform"]
  }

  metadata = {
    metadata_startup_script = var.metadata_startup_script
    enable-oslogin          = "TRUE"
    
    enable_tls = var.enable_tls
    # We use ternary operators because these resources don't exist if enable_tls is false
    tls_key    = var.enable_tls ? google_secret_manager_secret_version.db_private_key_val[0].name : ""
    tls_cert   = var.enable_tls ? google_secret_manager_secret_version.db_cert_val[0].name : ""
    wallet_pwd = var.enable_tls ? google_secret_manager_secret_version.wallet_pwd_val[0].name : ""
  }

  tags = concat([local.db_tag], var.network_tags)
}

resource "google_compute_instance_from_template" "database_vm" {
  for_each = local.instances

  name                     = each.key
  zone                     = each.value.zone
  project                  = var.project_id
  source_instance_template = google_compute_instance_template.default.self_link

  network_interface {
    # Provide one of: subnetwork (preferred) OR default network
    subnetwork = each.value.subnetwork
    network    = each.value.subnetwork == null ? "projects/${var.project_id}/global/networks/default" : null

    dynamic "access_config" {
      for_each = var.assign_public_ip ? [1] : []
      content {}
    }
  }
}

resource "random_id" "suffix" {
  byte_length = 4
}

locals {
  database_vm_nodes = [
    for vm in google_compute_instance_from_template.database_vm : {
      name = vm.name
      zone = vm.zone
      ip   = vm.network_interface[0].network_ip
      role = local.instances[vm.name].role
    }
  ]

  common_flags = join(" ", compact([
    local.ora_disk_mgmt_flag != "" ? "--ora-disk-mgmt ${local.ora_disk_mgmt_flag}" : "",
    length(local.asm_disk_config) > 0 ? "--ora-asm-disks-json '${jsonencode(local.asm_disk_config)}'" : "",
    length(local.data_mounts_config) > 0 ? "--ora-data-mounts-json '${jsonencode(local.data_mounts_config)}'" : "",
    # Keep DBCA destinations aligned with the computed mode
    "--ora-data-destination ${local.data_dest}",
    "--ora-reco-destination ${local.reco_dest}",
    "--swap-blk-device /dev/disk/by-id/google-swap",
    var.ora_swlib_bucket != "" ? "--ora-swlib-bucket ${var.ora_swlib_bucket}" : "",
    var.ora_version != "" ? "--ora-version ${var.ora_version}" : "",
    var.ora_backup_dest != "" ? "--backup-dest ${var.ora_backup_dest}" : "",
    var.ora_db_name != "" ? "--ora-db-name ${var.ora_db_name}" : "",
    var.ora_db_domain != "" ? "--ora-db-domain ${var.ora_db_domain}" : "",
    var.ora_db_container != "" ? "--ora-db-container ${var.ora_db_container}" : "",
    var.ntp_pref != "" ? "--ntp-pref ${var.ntp_pref}" : "",
    var.ora_release != "" ? "--ora-release ${var.ora_release}" : "",
    var.ora_edition != "" ? "--ora-edition ${var.ora_edition}" : "",
    var.ora_listener_port != "" ? "--ora-listener-port ${var.ora_listener_port}" : "",
    var.ora_redo_log_size != "" ? "--ora-redo-log-size ${var.ora_redo_log_size}" : "",
    var.db_password_secret != "" ? "--db-password-secret ${var.db_password_secret}" : "",
    var.oracle_metrics_secret != "" ? "--oracle-metrics-secret ${var.oracle_metrics_secret}" : "",
    var.install_workload_agent ? "--install-workload-agent" : "",
    var.skip_database_config ? "--skip-database-config" : "",
    var.ora_pga_target_mb != "" ? "--ora-pga-target-mb ${var.ora_pga_target_mb}" : "",
    var.ora_sga_target_mb != "" ? "--ora-sga-target-mb ${var.ora_pga_target_mb}" : "",
    var.data_guard_protection_mode != "" ? "--data-guard-protection-mode '${var.data_guard_protection_mode}'" : "",
    var.enable_tls ? "--enable-tls" : "",
    var.enable_tls ? "--tls-key-secret ${google_secret_manager_secret_version.db_private_key_val[0].name}" : "",
    var.enable_tls ? "--tls-cert-secret ${google_secret_manager_secret_version.db_cert_val[0].name}" : "",
    var.enable_tls ? "--wallet-pwd-secret ${google_secret_manager_secret_version.wallet_pwd_val[0].name}" : ""
  ]))
}

resource "google_compute_instance" "control_node" {
  project      = var.project_id
  name         = "${var.control_node_name_prefix}-${random_id.suffix.hex}"
  machine_type = var.control_node_machine_type
  zone         = var.zone1

  scheduling {
    max_run_duration {
      seconds = 604800
    }
    instance_termination_action = "DELETE"
  }

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }

  network_interface {
    subnetwork         = local.subnetwork1_opt
    network            = local.subnetwork1_opt == null ? "projects/${var.project_id}/global/networks/default" : null
    subnetwork_project = local.subnetwork1_opt != null ? local.project_id : null

    dynamic "access_config" {
      for_each = var.assign_public_ip ? [1] : []
      content {}
    }
  }

  service_account {
    email  = var.control_node_service_account
    scopes = ["cloud-platform"]
  }

  lifecycle {
    # FS/ASMUDEV/ASMLIB-specific guard for backup dest
    precondition {
      condition = (
        (local.is_fs && (var.ora_backup_dest == "" || can(regex("^/.*$", var.ora_backup_dest))))
        ||
        (!local.is_fs && (var.ora_backup_dest == "" || can(regex("^\\+.*$", var.ora_backup_dest)) || can(regex("^/.*$", var.ora_backup_dest))))
      )
      error_message = "FS mode: ora_backup_dest must be an absolute path like '/u03/backup'. ASMUDEV/ASMLIB mode: ora_backup_dest must be an ASMUDEV/ASMLIB diskgroup like '+RECO'."
    }
  }

  metadata_startup_script = templatefile("${path.module}/scripts/setup.sh.tpl", {
    gcs_source             = var.gcs_source
    database_vm_nodes_json = jsonencode(local.database_vm_nodes)
    common_flags           = local.common_flags
    deployment_name        = local.deployment_id
    delete_control_node    = var.delete_control_node
    assign_public_ip       = var.assign_public_ip
    create_firewall        = var.create_firewall
  })

  metadata = {
    enable-oslogin = "TRUE"
  }

  tags = [local.control_tag]

  depends_on = [google_compute_instance_from_template.database_vm]
}

# -----------------------------------------------------------------------------
# TLS Infrastructure & Identity (Phase 1)
# -----------------------------------------------------------------------------

locals {
  # Logic to determine hostname and port based on TLS inputs
  tls_hostname = var.db_hostname != "" ? var.db_hostname : var.instance_name
  listener_port = var.enable_tls && var.ora_listener_port == "1521" ? "2484" : var.ora_listener_port
  
  # Determine the primary IP for DNS registration
  # Assumes single instance or primary node for the DNS record
  primary_ip = [for vm in google_compute_instance_from_template.database_vm : vm.network_interface[0].network_ip if local.instances[vm.name].role == "primary"][0]
}

# 1. Generate Private Key (Locally in Terraform memory, strictly for Secret Manager)
resource "tls_private_key" "oracle_db_key" {
  count     = var.enable_tls ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 2048
}

# 2. Create Certificate Signing Request (CSR)
resource "tls_cert_request" "oracle_db_csr" {
  count           = var.enable_tls ? 1 : 0
  private_key_pem = tls_private_key.oracle_db_key[0].private_key_pem

  subject {
    common_name  = "${local.tls_hostname}.${trimsuffix(var.dns_domain_name, ".")}"
    organization = "Oracle Database Internal"
  }

  dns_names = [
    "${local.tls_hostname}.${trimsuffix(var.dns_domain_name, ".")}"
  ]
}

# 3. Issue Certificate via Google CAS
resource "google_privateca_certificate" "oracle_db_cert" {
  count       = var.enable_tls ? 1 : 0
  pool        = split("/", var.cas_pool_id)[5]
  location    = split("/", var.cas_pool_id)[3]
  project     = var.project_id
  name        = "${var.instance_name}-tls-cert"
  
  pem_csr     = tls_cert_request.oracle_db_csr[0].cert_request_pem
  lifetime    = "31536000s"
}

# 4. Create DNS A Record for Service Discovery
resource "google_dns_record_set" "db_a_record" {
  count        = var.enable_tls ? 1 : 0
  project      = var.project_id
  managed_zone = var.dns_zone_name
  name         = "${local.tls_hostname}.${var.dns_domain_name}"
  type         = "A"
  ttl          = 300
  rrdatas      = [local.primary_ip]
}

# 5. Generate Wallet Password
resource "random_password" "wallet_password" {
  count   = var.enable_tls ? 1 : 0
  length  = 16
  special = true
}

# -----------------------------------------------------------------------------
# Secrets Management (Secure Storage)
# -----------------------------------------------------------------------------

# Secret: Private Key
resource "google_secret_manager_secret" "db_private_key" {
  count     = var.enable_tls ? 1 : 0
  secret_id = "${var.instance_name}-tls-key"
  project   = var.project_id
  
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "db_private_key_val" {
  count       = var.enable_tls ? 1 : 0
  secret      = google_secret_manager_secret.db_private_key[0].id
  secret_data = tls_private_key.oracle_db_key[0].private_key_pem
}

# Secret: Certificate (Public Chain)
resource "google_secret_manager_secret" "db_cert" {
  count     = var.enable_tls ? 1 : 0
  secret_id = "${var.instance_name}-tls-cert"
  project   = var.project_id

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "db_cert_val" {
  count       = var.enable_tls ? 1 : 0
  secret      = google_secret_manager_secret.db_cert[0].id
  # Construct full chain: Leaf Cert + Issuer Chain
  secret_data = "${google_privateca_certificate.oracle_db_cert[0].pem_certificate}\n${join("\n", google_privateca_certificate.oracle_db_cert[0].pem_certificate_chain)}"
}

# Secret: Wallet Password
resource "google_secret_manager_secret" "wallet_pwd" {
  count     = var.enable_tls ? 1 : 0
  secret_id = "${var.instance_name}-wallet-pwd"
  project   = var.project_id

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "wallet_pwd_val" {
  count       = var.enable_tls ? 1 : 0
  secret      = google_secret_manager_secret.wallet_pwd[0].id
  secret_data = random_password.wallet_password[0].result
}

# -----------------------------------------------------------------------------
# IAM & Security Hardening (Task 2)
# -----------------------------------------------------------------------------

# Grant VM Service Account access ONLY to these specific secrets
resource "google_secret_manager_secret_iam_member" "vm_access_key" {
  count     = var.enable_tls ? 1 : 0
  secret_id = google_secret_manager_secret.db_private_key[0].id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${var.vm_service_account}"
}

resource "google_secret_manager_secret_iam_member" "vm_access_cert" {
  count     = var.enable_tls ? 1 : 0
  secret_id = google_secret_manager_secret.db_cert[0].id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${var.vm_service_account}"
}

resource "google_secret_manager_secret_iam_member" "vm_access_pwd" {
  count     = var.enable_tls ? 1 : 0
  secret_id = google_secret_manager_secret.wallet_pwd[0].id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${var.vm_service_account}"
}

# Grant VM Service Account permission to request renewals from the specific CA Pool
# (Scoped via IAM Condition if needed, or binding directly to the pool resource)
resource "google_privateca_ca_pool_iam_member" "vm_ca_requester" {
  count      = var.enable_tls ? 1 : 0
  ca_pool    = var.cas_pool_id
  role       = "roles/privateca.certificateRequester"
  member     = "serviceAccount:${var.vm_service_account}"
}

# This rule is deleted by the startup script upon deployment completion.
resource "google_compute_firewall" "control_ssh" {
  count       = var.create_firewall ? 1 : 0
  name        = "ora-ssh-${google_compute_instance.control_node.name}"
  project     = var.project_id
  network     = local.network
  description = "Temporary rule for deployment ${local.deployment_id}: Allows Control Node SSH access to Database VMs for initial provisioning."

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  allow {
    protocol = "icmp"
  }

  source_tags = [local.control_tag]
  target_tags = [local.db_tag]
}

resource "google_compute_firewall" "db_sync" {
  count       = (local.is_multi_instance && var.create_firewall) ? 1 : 0
  name        = "oracle-${local.deployment_id}-db-sync"
  project     = var.project_id
  network     = local.network
  description = "Deployment ${local.deployment_id}: Allows inter-database communication on the Oracle listener port for Data Guard synchronization."

  allow {
    protocol = "tcp"
    ports    = [var.ora_listener_port]
  }
  allow {
    protocol = "icmp"
  }

  source_tags = [local.db_tag]
  target_tags = [local.db_tag]
}

output "control_node_log_url" {
  description = "Logs Explorer URL with Oracle Toolkit output"
  value       = "https://console.cloud.google.com/logs/query;query=resource.labels.instance_id%3D${urlencode(google_compute_instance.control_node.instance_id)};duration=P30D?project=${urlencode(var.project_id)}"
}

output "database_vm_names" {
  description = "Names of the created database VMs from instance templates"
  value       = [for vm in google_compute_instance_from_template.database_vm : vm.name]
}
