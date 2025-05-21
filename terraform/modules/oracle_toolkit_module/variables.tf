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

variable "asm_disks" {
  description = "List of ASM disks"
  type        = list(any)
  default     = []
}

variable "fs_disks" {
  description = "List of filesystem disks"
  type        = list(any)
  default     = []
}

variable "instance_name" {
  description = "The name for the target VM instance."
  type        = string
}

variable "control_node_name" {
  description = "The name for the control node VM."
  type        = string
  default     = "control-node"
}

variable "machine_type" {
  description = "The machine type to be used for the instance (e.g., n4-standard-2)."
  type        = string
}

variable "control_node_machine_type" {
  description = "The machine type to be used for the instance (e.g., n2-standard-2)."
  type        = string
  default     = "e2-medium"
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
  description = "NTP preference. For cloud installs, this must be set to '169.254.169.254'."
  default     = ""

  validation {
    condition     = var.ntp_pref == "" || var.ntp_pref == "169.254.169.254"
    error_message = "For cloud installations, NTP should be set to 169.254.169.254 or left empty."
  }
}

variable "ora_backup_dest" {
  type        = string
  description = "Backup destination for Oracle database. Example: '+RECO' or '/backup/path'. Leave empty if not needed."
  default     = ""

  validation {
    condition     = can(regex("^\\+?[A-Za-z0-9/_-]+$", var.ora_backup_dest))
    error_message = "Invalid backup destination. It must be a valid ASM disk group (e.g., '+RECO') or a valid file path."
  }
}

variable "ora_db_container" {
  type        = string
  default     = ""
  description = "Defines whether the database is a container database (true/false)."
  validation {
    condition     = var.ora_db_container == "" || contains(["true", "false"], lower(var.ora_db_container))
    error_message = "Invalid value for ora_db_container. Must be 'true' or 'false'."
  }
}

variable "ora_db_name" {
  type        = string
  default     = ""
  description = "Database name, must be up to 8 characters."
  validation {
    condition     = var.ora_db_name == "" || can(regex("^[a-zA-Z0-9_]{1,8}$", var.ora_db_name))
    error_message = "Invalid DB name. It must be 1-8 alphanumeric characters or underscores."
  }
}

variable "ora_edition" {
  type        = string
  default     = ""
  description = "Oracle Edition: EE, SE, SE2, or FREE."
  validation {
    condition     = var.ora_edition == "" || contains(["EE", "SE", "SE2", "FREE"], var.ora_edition)
    error_message = "Invalid Oracle edition. Allowed values: EE, SE, SE2, FREE."
  }
}

variable "ora_listener_port" {
  type        = string
  default     = ""
  description = "TCP port for Oracle listener."
  validation {
    condition     = var.ora_listener_port == "" || can(regex("^[0-9]+$", var.ora_listener_port))
    error_message = "Invalid listener port. It must be a numeric value."
  }
}

variable "ora_redo_log_size" {
  type        = string
  default     = ""
  description = "Redo log size, must be a number or include MB/GB (e.g., '100MB', '1GB', '500')."
  validation {
    condition     = var.ora_redo_log_size == "" || can(regex("^(\\d+)(MB|GB)?$", var.ora_redo_log_size))
    error_message = "Invalid redo log size. Specify a number or use MB/GB (e.g., '100MB', '1GB', '500')."
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
  description = "Oracle database version (e.g., 19, 19.3.0.0.0)"
  validation {
    condition     = can(regex("^\\d+(\\.\\d+)*$", var.ora_version))
    error_message = "Invalid Oracle version format. Use a version number like '19' or '19.3.0.0.0'."
  }
}

variable "oracle_release" {
  type        = string
  default     = "latest"
  description = "Oracle release update version (patchlevel)."
  validation {
    condition     = var.oracle_release == "" || var.oracle_release == "latest" || can(regex("^\\d+(\\.\\d+)*$", var.oracle_release))
    error_message = "Invalid Oracle release version. It should be in the format '19.10', '21.3.0.0', etc."
  }
}

variable "os_disk_size" {
  description = "The size (in GB) of the base disk for the instance."
  type        = number
  default     = 50
}

variable "os_disk_type" {
  description = "The type of the base disk for the instance."
  type        = string
}

variable "project_id" {
  description = "The Google Cloud project ID where all resources will be deployed."
  type        = string
}

variable "region" {
  description = "The GCP region where the instance and related resources will be deployed (e.g., us-central1)."
  type        = string
}

variable "vm_service_account" {
  description = "The service account used for managing compute instance permissions."
  type        = string
}

variable "control_node_service_account" {
  description = "The service account used by the control node."
  type        = string
}

variable "source_image_family" {
  description = "value of the image family to be used for the instance."
  type        = string
}

variable "source_image_project" {
  description = "The project where the source image is located."
  type        = string
}

variable "subnetwork" {
  description = "The name of the GCP subnetwork to which the instance will be attached."
  type        = string
  default     = "default"
}

variable "zone" {
  description = "The specific availability zone within the selected GCP region (e.g., us-central1-b)."
  type        = string
}

variable "assign_public_ip" {
  description = "Whether to assign a public IP address to the control node VM. Set to false if the environment already has internet access via a Cloud NAT"
  type        = bool
  default     = true
}
