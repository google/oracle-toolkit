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

variable "instance_name" {
  description = "The name prefix for the target VM instance."
  type        = string
}

variable "control_node_name_prefix" {
  description = "The name prefix for the control node VM."
  type        = string
  default     = "control-node"
}

variable "delete_control_node" {
  description = "Controls whether the control node deletes itself after deployment. Set to false to preserve the node for debugging purposes."
  type        = bool
  default     = true
}

variable "machine_type" {
  description = "The machine type to be used for the instance (e.g., n4-standard-2)."
  type        = string
  default     = "n4-standard-2"
}

variable "control_node_machine_type" {
  description = "The machine type to be used for the instance (e.g., n2-standard-2)."
  type        = string
  default     = "e2-standard-2"
}

variable "metadata_startup_script" {
  description = "The startup script to be executed on the instance, bootstraps required Ansible binaries."
  type        = string
  default     = null
}

variable "network_tags" {
  description = "List of network tags to apply to the instance template."
  type        = list(string)
  default     = []
}

variable "ntp_pref" {
  type        = string
  description = "NTP preference. For cloud installs, this should be set to '169.254.169.254'."
  default     = "169.254.169.254"

  validation {
    condition     = var.ntp_pref == "" || var.ntp_pref == "169.254.169.254"
    error_message = "For cloud installations, NTP should be set to 169.254.169.254 or left empty."
  }
}

variable "ora_backup_dest" {
  type        = string
  description = "Backup destination for Oracle database. Example: '+RECO' or '/backup/path'. Leave empty if not needed."

  validation {
    condition     = var.ora_backup_dest == "" || can(regex("^\\+?[A-Za-z0-9/_-]+$", var.ora_backup_dest))
    error_message = "Invalid backup destination. It must be a valid ASMUDEV/ASMLIB disk group (e.g., '+RECO') or a valid file path."
  }
}

variable "ora_db_container" {
  type        = string
  default     = "false"
  description = "Defines whether the database is a container database (true/false)."
  validation {
    condition     = var.ora_db_container == "" || contains(["true", "false"], lower(var.ora_db_container))
    error_message = "Invalid value for ora_db_container. Must be 'true' or 'false'."
  }
}

variable "ora_db_name" {
  type        = string
  default     = ""
  description = "The Oracle database name. Must be empty or 1-8 characters, using only letters, numbers, or underscores."
  validation {
    condition     = var.ora_db_name == "" || can(regex("^[a-zA-Z0-9_]{1,8}$", var.ora_db_name))
    error_message = "The ora_db_name must be empty or contain only letters, numbers, and underscores and be between 1 and 8 characters long."
  }
}

variable "ora_db_domain" {
  type        = string
  default     = ""
  description = "The Oracle database domain name. Must be empty or 1-128 characters long, using only letters, or numbers."
  validation {
    condition     = var.ora_db_domain == "" || can(regex("^[A-Za-z][A-Za-z0-9._-]{0,127}$", var.ora_db_domain))
    error_message = "The ora_db_domain must be empty or start with a letter and may only contain letters, digits, underscores, hyphens, periods, and be between 1 and 128 characters long."
  }
}


variable "ora_edition" {
  type        = string
  default     = "EE"
  description = "Oracle Edition: EE, SE, SE2, or FREE."
  validation {
    condition     = var.ora_edition == "" || contains(["EE", "SE", "SE2", "FREE"], var.ora_edition)
    error_message = "Invalid Oracle edition. Allowed values: EE, SE, SE2, FREE."
  }
}

variable "ora_listener_port" {
  type        = string
  default     = "1521"
  description = "TCP port for Oracle listener."
  validation {
    condition     = var.ora_listener_port == "" || can(regex("^[0-9]+$", var.ora_listener_port))
    error_message = "Invalid listener port. It must be a numeric value."
  }
}

variable "ora_redo_log_size" {
  type        = string
  default     = "100MB"
  description = "Redo log size, followed by MB"
  validation {
    condition     = var.ora_redo_log_size == "" || can(regex("^[0-9]+MB$", var.ora_redo_log_size))
    error_message = "Invalid redo log size. Specify a number followed by MB (e.g., '100MB', '1GB', '500')."
  }
}

variable "ora_swlib_bucket" {
  type        = string
  description = "GCS bucket location for Oracle software library"
  validation {
    condition     = can(regex("^gs://[a-z0-9][-a-z0-9.]*[a-z0-9](/.*)?$", var.ora_swlib_bucket))
    error_message = "Invalid bucket format. It must be in the format 'gs://bucket-name' or 'gs://bucket-name/path'."
  }
}

variable "ora_version" {
  type        = string
  default     = "19"
  description = "Oracle database version (e.g., 19, 19.3.0.0.0)"
  validation {
    condition     = can(regex("^\\d+(\\.\\d+)*$", var.ora_version))
    error_message = "Invalid Oracle version format. Use a version number like '19' or '19.3.0.0.0'."
  }
}

variable "ora_release" {
  type        = string
  default     = "latest"
  description = "Oracle release update version (patchlevel)."
  validation {
    condition     = var.ora_release == "" || var.ora_release == "latest" || can(regex("^\\d+(\\.\\d+)*$", var.ora_release))
    error_message = "Invalid Oracle release version. It should be in the format '19.10', '21.3.0.0', etc."
  }
}

variable "boot_disk_size_gb" {
  description = "The size of the boot disk for the database VM."
  type        = number
  default     = 50
  validation {
    condition     = var.boot_disk_size_gb >= 20
    error_message = "boot_disk_size_gb must be at least 20."
  }
}

variable "boot_disk_type" {
  description = "The type of the boot disk for the database VM."
  type        = string
  default     = "hyperdisk-balanced"
}

variable "swap_disk_size_gb" {
  description = "The size of the swap disk for the database VM."
  type        = number
  default     = 50
}

variable "swap_disk_type" {
  description = "The type of the swap disk for the database VM."
  type        = string
  default     = "hyperdisk-balanced"
}

variable "oracle_home_disk" {
  description = "The Oracle binaries (/u01) disk."
  type = object({
    size_gb = optional(number, 100)
    type    = optional(string, "hyperdisk-balanced")
  })
  validation {
    condition     = var.oracle_home_disk.size_gb >= 30
    error_message = "oracle_home_disk.size_gb must be at least 30."
  }
}

variable "data_disk" {
  description = "The Oracle data disk."
  type = object({
    size_gb = optional(number, 100)
    type    = optional(string, "hyperdisk-balanced")
  })
  validation {
    condition     = var.data_disk.size_gb >= 10
    error_message = "data_disk.size_gb must be at least 10."
  }
}

variable "reco_disk" {
  description = "The Oracle fast recovery area disk."
  type = object({
    size_gb = optional(number, 100)
    type    = optional(string, "hyperdisk-balanced")
  })
  validation {
    condition     = var.reco_disk.size_gb >= 15
    error_message = "reco_disk.size_gb must be at least 15."
  }
}

variable "project_id" {
  description = "The Google Cloud project ID where all resources will be deployed."
  type        = string
}

variable "vm_service_account" {
  description = "The service account used for managing compute instance permissions."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9._-]+@[a-z0-9.-]+[.]gserviceaccount[.]com$", var.vm_service_account))
    error_message = "vm_service_account must look like an e-mail address ending in a subdomain of gserviceaccount.com https://cloud.google.com/iam/docs/service-account-types"
  }
}

variable "control_node_service_account" {
  description = "The service account used by the control node."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9._-]+@[a-z0-9.-]+[.]gserviceaccount[.]com$", var.control_node_service_account))
    error_message = "control_node_service_account must look like an e-mail address ending in a subdomain of gserviceaccount.com https://cloud.google.com/iam/docs/service-account-types"
  }
}

variable "source_image_family" {
  description = "value of the image family to be used for the instance."
  type        = string
  default     = "oracle-linux-8"
}

variable "source_image_project" {
  description = "The project where the source image is located."
  type        = string
  default     = "oracle-linux-cloud"
}

variable "assign_public_ip" {
  description = "Whether to assign a public IP address to the control node VM. Set to false if the environment already has internet access via a Cloud NAT."
  type        = bool
  default     = true
}

variable "gcs_source" {
  type        = string
  description = "GCS path to a ZIP file containing the oracle-toolkit. This ZIP will be downloaded and extracted on the control node VM, where its install-oracle.sh script will be executed to provision a new database VM."
  validation {
    condition     = can(regex("^gs://.+\\.zip$", var.gcs_source))
    error_message = "The gcs_source must be a valid GCS path starting with 'gs://' and ending in '.zip'."
  }
}

variable "db_password_secret" {
  description = "Google Cloud Secret Manager resource containing the password to be used for both the Oracle SYS and SYSTEM users"
  type        = string
  default     = ""

  validation {
    condition     = var.db_password_secret == "" || can(regex("^projects/[^/]+/secrets/[^/]+/versions/[^/]+$", var.db_password_secret))
    error_message = "db_password_secret must be in the format: projects/<project>/secrets/<secret_name>/versions/<version>"
  }
}

variable "install_workload_agent" {
  description = "Whether to install workload-agent on the database VM."
  type        = bool
  default     = true
}

variable "oracle_metrics_secret" {
  description = "Fully qualified name of the Secret Manager secret that stores the Oracle database user's password. This user is specifically configured for the workload-agent to enable metric collection."
  type        = string
  default     = ""

  validation {
    condition     = var.oracle_metrics_secret == "" || can(regex("^projects/[^/]+/secrets/[^/]+/versions/[^/]+$", var.oracle_metrics_secret))
    error_message = "oracle_metrics_secret must be in the format: projects/<project>/secrets/<secret_name>/versions/<version>"
  }
}

variable "skip_database_config" {
  description = "Whether to skip database creation, and to simply install the Oracle software; Set to true if planning to migrate an existing database."
  type        = bool
  default     = false
}

variable "zone1" {
  description = "The GCP zone for deploying the instance in single-instance deployments, or for the primary node in multi-instance Data Guard deployments."
  type        = string
  default     = "us-central1-b"
}

variable "zone2" {
  description = "The GCP zone for deploying the secondary node in a multi-instance Data Guard deployment."
  type        = string
  default     = ""
}

variable "subnetwork1" {
  description = "The Resource URI of the GCP subnetwork to attach the instance to. Used for single-instance deployments and for the primary node in multi-instance Data Guard deployments."
  type        = string
  validation {
    condition     = var.subnetwork1 == "" || can(regex("^projects/([a-z0-9-]+)/regions/([a-z0-9-]+)/subnetworks/([a-z0-9-]+)$", var.subnetwork1))
    error_message = "Must be in the format: 'projects/<PROJECT_ID>/regions/<REGION>/subnetworks/<SUBNETWORK_NAME>'."
  }
  default = ""
}

variable "subnetwork2" {
  description = "The Resource URI of the GCP subnetwork to attach the secondary node to in a multi-instance Data Guard deployment."
  type        = string
  validation {
    condition     = var.subnetwork2 == "" || can(regex("^projects/([a-z0-9-]+)/regions/([a-z0-9-]+)/subnetworks/([a-z0-9-]+)$", var.subnetwork2))
    error_message = "Must be in the format: 'projects/<PROJECT_ID>/regions/<REGION>/subnetworks/<SUBNETWORK_NAME>'."
  }
  default = ""
}

variable "ora_pga_target_mb" {
  description = "Oracle session private memory aggregate target, in MB."
  type        = number
  default     = 0
}

variable "ora_sga_target_mb" {
  description = "Oracle shared memory target, in MB."
  type        = number
  default     = 0
}

variable "deployment_name" {
  description = "Name of the deployment provided by WLM"
  type        = string
  default     = ""
}

variable "data_guard_protection_mode" {
  description = "Data Guard protection mode: one of 'Maximum Performance', 'Maximum Availability', or 'Maximum Protection'."
  type        = string
  validation {
    condition     = contains(["Maximum Performance", "Maximum Availability", "Maximum Protection"], var.data_guard_protection_mode)
    error_message = "data_guard_protection_mode must be one of: 'Maximum Performance', 'Maximum Availability', or 'Maximum Protection'."
  }
  default = "Maximum Availability"
}

variable "ora_disk_mgmt" {
  description = "Oracle disk management mode. Enter 'FS' for XFS filesystems or 'ASMUDEV' or 'ASMLIB' for Oracle ASM."
  type        = string
  default     = "FS"
  nullable    = false
  validation {
    condition     = can(regex("^(?i)(FS|ASMUDEV|ASMLIB)$", var.ora_disk_mgmt))
    error_message = "Enter FS (XFS) or ASMUDEV or ASMLIB."
  }
}

variable "create_firewall" {
  description = "Create firewall rules for Ansible SSH and Oracle Data Guard"
  type        = bool
  default     = false
}

variable "enable_ar_repo" {
  description = "Controls whether to create Google Cloud Artifact Registry remote repositories to fetch OS packages."
  type        = bool
  default     = false
}
