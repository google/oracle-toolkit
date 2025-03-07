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

  ##############################################################################
  ## OPTIONAL SETTINGS
  ##   - default values will be determined/calculated
  ##############################################################################
  # metadata_startup_script = "STARTUP_SCRIPT" # example: gs://BUCKET/SCRIPT.sh
  # network_tags            = "NETWORK_TAGS"   # example: ["oracle", "ssh"]

  # Full list of parameters can be found here https://google.github.io/oracle-toolkit/user-guide.html#parameters
  # The example below will install Oracle 19c, using the Oracle software stored in a GCS bucket, and will configure the backup destination to be RECO diskgroup.
  extra_ansible_vars = [
    "--ora-swlib-bucket BUCKET", # gcs bucket where the Oracle software is stored, example: gs://my-oracle-software/19c 
    "--ora-version 19",
    "--backup-dest +RECO"
  ]
}
