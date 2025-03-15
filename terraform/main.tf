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

module "oracle_toolkit" {
  source = "./modules/oracle_toolkit_module"
  #
  # Fill in the information below
  #
  ##############################################################################
  ## MANDATORY SETTINGS
  ##############################################################################
  # General settings
  region                = "REGION"                # example: us-central1
  zone                  = "ZONE"                  # example: us-central1-b
  project_id            = "PROJECT_ID"            # example: my-project-123
  subnetwork            = "SUBNET"                # example: default
  service_account_email = "SERVICE_ACCOUNT_EMAIL" # example: 123456789-compute@developer.gserviceaccount.com

  # Instance settings
  instance_name        = "INSTANCE_NAME"  # example: oracle-rhel8-example
  instance_count       = "INSTANCE_COUNT" # example: 1
  source_image_family  = "IMAGE_FAMILY"   # example: rhel-8
  source_image_project = "IMAGE_PROJECT"  # example: rhel-cloud
  machine_type         = "MACHINE_TYPE"   # example: n2-standard-4
  os_disk_size         = "OS_DISK_SIZE"   # example: 100
  os_disk_type         = "OS_DISK_TYPE"   # example: pd-balanced

  # Disk settings
  # By default, the list below will create 1 disk for filesystem, 2 disks for ASM and 1 disk for swap, the minimum required for a basic Oracle installation.
  # Feel free to adjust the disk sizes and types to match your requirements.
  # You can add more disks to the list below to create additional disks for ASM or filesystem.
  # fs_disks will be mounted as /u01, /u02, /u03, etc and formatted as XFS
  fs_disks = [
    {
      auto_delete  = true
      boot         = false
      device_name  = "oracle-u01"
      disk_size_gb = 50
      disk_type    = "pd-balanced"
      disk_labels  = { purpose = "software" } # Do not modify this label
    }
  ]

  asm_disks = [
    {
      auto_delete  = true
      boot         = false
      device_name  = "oracle-asm-1"
      disk_size_gb = 50
      disk_type    = "pd-balanced"
      disk_labels  = { diskgroup = "data", purpose = "asm" }
    },
    {
      auto_delete  = true
      boot         = false
      device_name  = "oracle-asm-2"
      disk_size_gb = 50
      disk_type    = "pd-balanced"
      disk_labels  = { diskgroup = "reco", purpose = "asm" }
    },
    # Attributes other than disk_size_gb and disk_type should NOT be modified for the swap disk
    {
      auto_delete  = true
      boot         = false
      device_name  = "swap"
      disk_size_gb = 50
      disk_type    = "pd-balanced"
      disk_labels  = { purpose = "swap" }
    }
  ]

  # Full list of parameters can be found here https://google.github.io/oracle-toolkit/user-guide.html#parameters
  # The example below will install Oracle 19c, using the Oracle software stored in a GCS bucket, and will configure the backup destination to be RECO diskgroup.
  # Mandatory
  ora_swlib_bucket = "BUCKET"      # example: gs://my-bucket/19
  ora_version      = "ORA_VERSION" # example: "19"
  ora_backup_dest  = "BACKUP_DEST" # example: "+RECO"
  # Optional
  ora_db_name       = "DB_NAME"            # example: "test"
  ora_db_container  = "CONTAINER"          # example: false
  ntp_pref          = "NTP_PREF"           # example: "169.254.169.254"
  oracle_release    = "ORA_RELEASE"        # example: "19.7.0.0.200414"
  ora_edition       = "ORA_EDITION"        # example: "EE"
  ora_listener_port = "ORA_LISTERNER_PORT" # example: 1521 
  ora_redo_log_size = "ORA_LOG_SIZE"       # example: "100MB"

  ##############################################################################
  ## OPTIONAL SETTINGS
  ##   - default values will be determined/calculated
  ##############################################################################
  # metadata_startup_script = "STARTUP_SCRIPT" # example: gs://BUCKET/SCRIPT.sh
  # network_tags            = "NETWORK_TAGS"   # example: ["oracle", "ssh"]
}

# Firewall rules
# Custom firewall rules can be added by sourcing Google's firewall module https://github.com/terraform-google-modules/terraform-google-network/tree/v10.0.0/modules/firewall-rules
# example:
# module "oracle_listener" {
#   source       = "terraform-google-modules/network/google//modules/firewall-rules"
#   project_id   = "PROJECT_ID" # example: my-project-123
#   network_name = "VPN_NAME"   # example: default

#   rules = [{
#     name                    = "RULE_NAME" # example: oracle-listener
#     description             = null
#     direction               = "INGRESS"
#     priority                = null
#     destination_ranges      = ["10.0.0.0/8"]
#     source_ranges           = ["0.0.0.0/0"]
#     source_tags             = null
#     source_service_accounts = null
#     target_tags             = null
#     target_service_accounts = null
#     allow = [{
#       protocol = "tcp"
#       ports    = ["1521"]
#     }]
#     deny = []
#     log_config = {
#       metadata = "INCLUDE_ALL_METADATA"
#     }
#   }]
# }
