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

set -e


# Writes a key-value pair to a YAML file. It detects the data types to ensure
# correct interpretation by Ansible when writing to gcp_oracle.yml.
# If the key exists, its value is updated. Otherwise, the key-value pair is appended.
#
# Arguments:
#   $1: The key to write.
#   $2: The value to write.
#   $3: The target YAML file.
write_yaml_value() {
  local key="$1"
  local value="$2"
  local target_file="$3"
  local new_line

  # JSON-like string: write as-is for native YAML structure
  if [[ "${value:0:1}" == "[" || "${value:0:1}" == "{" ]]; then
    new_line="${key}: ${value}"
  # Boolean: write as-is for native boolean type
  elif [[ "${value,,}" == "true" || "${value,,}" == "false" ]]; then
    new_line="${key}: ${value}"
  # Integer: write as-is for native number type
  elif [[ "$value" =~ ^-?[0-9]+$ ]]; then
    new_line="${key}: ${value}"
  # Default to String: quote the value to handle special characters.
  else
    new_line="${key}: \"${value}\""
  fi

  if grep -q "^${key}:" "${target_file}"; then
    # Key exists, replace the line
    sed -i "/^${key}:/c\\${new_line}" "${target_file}"
  else
    # Key does not exist, append to the file
    echo "${new_line}" >> "${target_file}"
  fi
}


GETOPT_MANDATORY="ora-swlib-bucket:"
GETOPT_OPTIONAL="gcs-backup-config:,gcs-backup-bucket:,gcs-backup-temp-path:,nfs-backup-config:,nfs-backup-mount:,backup-dest:,ora-version:,ora-release:"
GETOPT_OPTIONAL="$GETOPT_OPTIONAL,no-patch,ora-edition:,cluster-type:,cluster-config:,cluster-config-json:"
GETOPT_OPTIONAL="$GETOPT_OPTIONAL,ora-staging:,ora-db-name:,ora-db-domain:,ora-db-charset:,ora-disk-mgmt:,ora-role-separation:"
GETOPT_OPTIONAL="$GETOPT_OPTIONAL,ora-data-destination:,ora-data-diskgroup:,ora-reco-destination:,ora-reco-diskgroup:"
GETOPT_OPTIONAL="$GETOPT_OPTIONAL,ora-asm-disks:,ora-asm-disks-json:,ora-data-mounts:,ora-data-mounts-json:,ora-listener-port:,ora-listener-name:"
GETOPT_OPTIONAL="$GETOPT_OPTIONAL,ora-db-ncharset:,ora-db-container:,ora-db-type:,ora-pdb-name-prefix:,ora-pdb-count:,ora-redo-log-size:"
GETOPT_OPTIONAL="$GETOPT_OPTIONAL,ora-pga-target-mb:,ora-sga-target-mb:,ora-db-dg-name:"
GETOPT_OPTIONAL="$GETOPT_OPTIONAL,backup-redundancy:,archive-redundancy:,archive-online-days:,backup-level0-days:,backup-level1-days:"
GETOPT_OPTIONAL="$GETOPT_OPTIONAL,backup-start-hour:,backup-start-min:,archive-backup-min:,backup-script-location:,backup-log-location:"
GETOPT_OPTIONAL="$GETOPT_OPTIONAL,ora-swlib-type:,ora-swlib-path:,ora-swlib-credentials:,instance-ip-addr:,primary-ip-addr:,instance-ssh-user:"
GETOPT_OPTIONAL="$GETOPT_OPTIONAL,instance-ssh-key:,instance-hostname:,ntp-pref:,inventory-file:,compatible-rdbms:,instance-ssh-extra-args:"
GETOPT_OPTIONAL="$GETOPT_OPTIONAL,help,validate,check-instance,prep-host,install-sw,config-db,allow-install-on-vm,skip-database-config,swap-blk-device:"
GETOPT_OPTIONAL="$GETOPT_OPTIONAL,install-workload-agent,oracle-metrics-secret:,db-password-secret:,data-guard-protection-mode:,skip-platform-compatibility"
GETOPT_OPTIONAL="$GETOPT_OPTIONAL,ar-repo-url:"
GETOPT_LONG="$GETOPT_MANDATORY,$GETOPT_OPTIONAL"
GETOPT_SHORT="h"

options=$(getopt --longoptions "${GETOPT_LONG}" --options "$GETOPT_SHORT" --name "$(basename "$0")" -- "$@")
eval set -- "$options"

CUSTOM_INVENTORY_FILE=""
VALIDATE_ONLY=false
HELP_ONLY=false
CHECK_INSTANCE_ONLY=false
PREP_HOST_ONLY=false
INSTALL_SW_ONLY=false
CONFIG_DB_ONLY=false
SKIP_DATABASE_CONFIG=false
declare -A YAML_VARS
ANSIBLE_ARGS=()

while true; do
  case "$1" in
    --inventory-file) CUSTOM_INVENTORY_FILE="$2"; shift 2 ;;
    --validate) VALIDATE_ONLY=true; shift ;;
    --help) HELP_ONLY=true; shift ;;
    --check-instance) CHECK_INSTANCE_ONLY=true; shift ;;
    --prep-host) PREP_HOST_ONLY=true; shift ;;
    --install-sw) INSTALL_SW_ONLY=true; shift ;;
    --no-patch) YAML_VARS["ora_release"]="base"; shift ;;
    --config-db) CONFIG_DB_ONLY=true; shift ;;
    --skip-database-config) SKIP_DATABASE_CONFIG=true; shift ;;
    --ora-version) YAML_VARS["ora_version"]="$2"; shift 2 ;;
    --ora-release) YAML_VARS["ora_release"]="$2"; shift 2 ;;
    --ora-edition) YAML_VARS["ora_edition"]="$2"; shift 2 ;;
    --cluster-type) YAML_VARS["ora_cluster_type"]="$2"; shift 2 ;;
    --ora-swlib-bucket) YAML_VARS["ora_swlib_bucket"]="$2"; shift 2 ;;
    --ora-swlib-type) YAML_VARS["ora_swlib_type"]="$2"; shift 2 ;;
    --ora-swlib-path) YAML_VARS["ora_swlib_path"]="$2"; shift 2 ;;
    --ora-staging) YAML_VARS["ora_staging"]="$2"; shift 2 ;;
    --ora-disk-mgmt) YAML_VARS["ora_disk_mgmt"]="$2"; shift 2 ;;
    --ora-role-separation) YAML_VARS["ora_role_separation"]="$2"; shift 2 ;;
    --ora-data-destination) YAML_VARS["ora_data_destination"]="$2"; shift 2 ;;
    --ora-reco-destination) YAML_VARS["ora_reco_destination"]="$2"; shift 2 ;;
    --ora-asm-disks) YAML_VARS["ora_asm_disks"]="$2"; shift 2 ;;
    --ora-asm-disks-json) YAML_VARS["ora_asm_disks_json"]="$2"; shift 2 ;;
    --ora-data-mounts) YAML_VARS["ora_data_mounts"]="$2"; shift 2 ;;
    --ora-data-mounts-json) YAML_VARS["ora_data_mounts_json"]="$2"; shift 2 ;;
    --cluster-config) YAML_VARS["cluster_config"]="$2"; shift 2 ;;
    --cluster-config-json) YAML_VARS["cluster_config_json"]="$2"; shift 2 ;;
    --swap-blk-device) YAML_VARS["swap_blk_device"]="$2"; shift 2 ;;
    --ora-db-name) YAML_VARS["ora_db_name"]="$2"; shift 2 ;;
    --ora-db-dg-name) YAML_VARS["ora_db_dg_name"]="$2"; shift 2 ;;
    --ora-db-domain) YAML_VARS["ora_db_domain"]="$2"; shift 2 ;;
    --ora-db-charset) YAML_VARS["ora_db_charset"]="$2"; shift 2 ;;
    --ora-db-ncharset) YAML_VARS["ora_db_ncharset"]="$2"; shift 2 ;;
    --ora-db-container) YAML_VARS["ora_db_container"]="$2"; shift 2 ;;
    --ora-db-type) YAML_VARS["ora_db_type"]="$2"; shift 2 ;;
    --ora-pdb-name-prefix) YAML_VARS["ora_pdb_name_prefix"]="$2"; shift 2 ;;
    --ora-pdb-count) YAML_VARS["ora_pdb_count"]="$2"; shift 2 ;;
    --ora-redo-log-size) YAML_VARS["ora_redo_log_size"]="$2"; shift 2 ;;
    --ora-pga-target-mb) YAML_VARS["ora_pga_target_mb"]="$2"; shift 2 ;;
    --ora-sga-target-mb) YAML_VARS["ora_sga_target_mb"]="$2"; shift 2 ;;
    --db-password-secret) YAML_VARS["_db_password_secret"]="$2"; shift 2 ;;
    --ora-listener-name) YAML_VARS["ora_listener_name"]="$2"; shift 2 ;;
    --ora-listener-port) YAML_VARS["ora_listener_port"]="$2"; shift 2 ;;
    --instance-ip-addr) YAML_VARS["instance_ip_addr"]="$2"; shift 2 ;;
    --instance-hostname) YAML_VARS["instance_hostname"]="$2"; shift 2 ;;
    --instance-ssh-user) YAML_VARS["_instance_ssh_user"]="$2"; shift 2 ;;
    --instance-ssh-key) YAML_VARS["_instance_ssh_key"]="$2"; shift 2 ;;
    --primary-ip-addr) YAML_VARS["primary_ip_addr"]="$2"; shift 2 ;;
    --instance-ssh-extra-args) YAML_VARS["instance_ssh_extra_args"]="$2"; shift 2 ;;
    --ntp-pref) YAML_VARS["ntp_pref"]="$2"; shift 2 ;;
    --backup-dest) YAML_VARS["_backup_dest"]="$2"; shift 2 ;;
    --backup-redundancy) YAML_VARS["backup_redundancy"]="$2"; shift 2 ;;
    --archive-redundancy) YAML_VARS["archive_redundancy"]="$2"; shift 2 ;;
    --archive-online-days) YAML_VARS["archive_online_days"]="$2"; shift 2 ;;
    --backup-level0-days) YAML_VARS["backup_level0_days"]="$2"; shift 2 ;;
    --backup-level1-days) YAML_VARS["backup_level1_days"]="$2"; shift 2 ;;
    --backup-start-hour) YAML_VARS["backup_start_hour"]="$2"; shift 2 ;;
    --backup-start-min) YAML_VARS["backup_start_min"]="$2"; shift 2 ;;
    --archive-backup-min) YAML_VARS["archive_backup_min"]="$2"; shift 2 ;;
    --backup-script-location) YAML_VARS["backup_script_location"]="$2"; shift 2 ;;
    --backup-log-location) YAML_VARS["backup_log_location"]="$2"; shift 2 ;;
    --gcs-backup-config) YAML_VARS["gcs_backup_config"]="$2"; shift 2 ;;
    --gcs-backup-bucket) YAML_VARS["gcs_backup_bucket"]="$2"; shift 2 ;;
    --gcs-backup-temp-path) YAML_VARS["gcs_backup_temp_path"]="$2"; shift 2 ;;
    --nfs-backup-config) YAML_VARS["_nfs_backup_config"]="$2"; shift 2 ;;
    --nfs-backup-mount) YAML_VARS["_nfs_backup_mount"]="$2"; shift 2 ;;
    --install-workload-agent) YAML_VARS["_install_workload_agent"]="true"; shift ;;
    --oracle-metrics-secret) YAML_VARS["_oracle_metrics_secret"]="$2"; shift 2 ;;
    --skip-platform-compatibility) YAML_VARS["_skip_platform_compatibility"]="true"; shift ;;
    --compatible-rdbms) YAML_VARS["compatible_rdbms"]="$2"; shift 2 ;;
    --data-guard-protection-mode) YAML_VARS["ora_data_guard_protection_mode"]="$2"; shift 2 ;;
    --ar-repo-url) YAML_VARS["ar_repo_url"]="$2"; shift 2 ;;
    --) shift; ANSIBLE_ARGS+=("$@"); break ;;
    *) echo "Internal error! Unexpected option: $1" >&2; exit 1 ;;
  esac
done

# Read JSON file contents into the YAML_VARS array if the -json variables are not provided.
if [[ -z "${YAML_VARS[ora_asm_disks_json]}" && -n "${YAML_VARS[ora_asm_disks]}" && -f "${YAML_VARS[ora_asm_disks]}" ]]; then
  JSON_CONTENT=$(<"${YAML_VARS[ora_asm_disks]}")
  YAML_VARS["ora_asm_disks_json"]="${JSON_CONTENT}"
  unset YAML_VARS["ora_asm_disks"]
fi
if [[ -z "${YAML_VARS[ora_data_mounts_json]}" && -n "${YAML_VARS[ora_data_mounts]}" && -f "${YAML_VARS[ora_data_mounts]}" ]]; then
  JSON_CONTENT=$(<"${YAML_VARS[ora_data_mounts]}")
  YAML_VARS["ora_data_mounts_json"]="${JSON_CONTENT}"
  unset YAML_VARS["ora_data_mounts"]
fi
if [[ -z "${YAML_VARS[cluster_config_json]}" && -n "${YAML_VARS[cluster_config]}" && -f "${YAML_VARS[cluster_config]}" ]]; then
  JSON_CONTENT=$(<"${YAML_VARS[cluster_config]}")
  YAML_VARS["cluster_config_json"]="${JSON_CONTENT}"
  unset YAML_VARS["cluster_config"]
fi


# If a custom inventory file is provided, use it directly.
if [[ -n "${CUSTOM_INVENTORY_FILE}" ]]; then
  INVENTORY_ARG="-i ${CUSTOM_INVENTORY_FILE}"
  for key in "${!YAML_VARS[@]}"; do
    ANSIBLE_ARGS+=("-e" "${key}='${YAML_VARS[$key]}'")
  done
else
  TEMP_CONFIG_FILE=$(mktemp gcp_oracle.yml.XXXXXX)
  INVENTORY_ARG="-i ${TEMP_CONFIG_FILE}"

  # Default instance_hostname to instance_ip_addr if not provided.
  if [[ -z "${YAML_VARS[instance_hostname]}" && -n "${YAML_VARS[instance_ip_addr]}" ]]; then
    YAML_VARS["instance_hostname"]="${YAML_VARS[instance_ip_addr]}"
  fi

  for key in "${!YAML_VARS[@]}"; do
    write_yaml_value "$key" "${YAML_VARS[$key]}" "$TEMP_CONFIG_FILE"
  done
fi


PB_VALIDATE="validate-config.yml"
PB_CHECK_INSTANCE="check-instance.yml"
PB_PREP_HOST="prep-host.yml"
PB_INSTALL_SW="install-sw.yml"
PB_CONFIG_DB="config-db.yml"
PB_CONFIG_RAC_DB="config-rac-db.yml"
PB_COMPATIBLE="compatibility-tests.yml"


if [ "$HELP_ONLY" = true ]; then
  echo "Usage: $(basename "$0") [OPTIONS]"
  echo ""
  echo "Options:"
  echo "  --help                       Display this help message and exit."
  echo "  --validate                   Run only the validation playbook and exit."
  echo "  --check-instance             Run only the instance check playbook and exit."
  echo "  --prep-host                  Run only the host preparation playbook and exit."
  echo "  --install-sw                 Run only the software installation playbook and exit."
  echo "  --no-patch                   Set Oracle release to 'base' (skip patching)."
  echo "  --config-db                  Run only the database configuration playbook and exit."
  echo "  --skip-database-config       Skip database configuration."
  echo "  --install-workload-agent     Install the workload agent."
  echo "  --ora-version <version>      Oracle version (e.g., 19)."
  echo "  --ora-release <release>      Oracle release (e.g., 19.0.0.0.0)."
  echo "  --ora-edition <edition>      Oracle edition (EE, SE, SE2, FREE)."
  echo "  --cluster-type <type>        Cluster type (NONE, RAC, DG)."
  echo "  --ora-swlib-bucket <bucket>  GCS bucket for Oracle software library."
  echo "  --ora-swlib-type <type>      Software library type (gcs, gcsfuse, nfs, gcsdirect, gcstransfer)."
  echo "  --ora-swlib-path <path>      Local path for Oracle software library."
  echo "  --ora-staging <path>         Staging directory for Oracle software."
  echo "  --ora-disk-mgmt <type>       Disk management type (asmlib, asmudev, udev, fs)."
  echo "  --ora-role-separation <bool> Enable role separation."
  echo "  --ora-data-destination <dest> Data destination (e.g., +DATA or /u02/oradata)."
  echo "  --ora-reco-destination <dest> Recovery destination (e.g., +RECO or /u03/fast_recovery_area)."
  echo "  --ora-asm-disks <file>       JSON file with ASM disk configuration."
  echo "  --ora-asm-disks-json <json>  JSON string with ASM disk configuration."
  echo "  --ora-data-mounts <file>     JSON file with data mounts configuration."
  echo "  --ora-data-mounts-json <json> JSON string with data mounts configuration."
  echo "  --cluster-config <file>      JSON file with cluster configuration."
  echo "  --cluster-config-json <json> JSON string with cluster configuration."
  echo "  --swap-blk-device <device>   Swap block device path."
  echo "  --ora-db-name <name>         Oracle database name."
  echo "  --ora-db-dg-name <name>      Oracle database Data Guard name."
  echo "  --ora-db-domain <domain>     Oracle database domain."
  echo "  --ora-db-charset <charset>   Oracle database character set."
  echo "  --ora-db-ncharset <ncharset> Oracle database national character set."
  echo "  --ora-db-container <true|false>      Enable container database."
  echo "  --ora-db-type <type>         Oracle database type (multipurpose, data_warehousing, oltp)."
  echo "  --ora-pdb-name-prefix <prefix> PDB name prefix."
  echo "  --ora-pdb-count <count>      Number of PDBs."
  echo "  --ora-redo-log-size <size>   Redo log file size (e.g., 100MB)."
  echo "  --ora-pga-target-mb <mb>     PGA target in MB."
  echo "  --ora-sga-target-mb <mb>     SGA target in MB."
  echo "  --db-password-secret <secret> Secret for database password."
  echo "  --ora-listener-name <name>   Oracle listener name."
  echo "  --ora-listener-port <port>   Oracle listener port."
  echo "  --instance-ip-addr <ip>      Instance IP address."
  echo "  --instance-hostname <hostname> Instance hostname."
  echo "  --instance-ssh-user <user>   SSH user for instance."
  echo "  --instance-ssh-key <key>     SSH private key for instance."
  echo "  --primary-ip-addr <ip>       Primary IP address (for Data Guard)."
  echo "  --instance-ssh-extra-args <args> Extra SSH arguments."
  echo "  --ntp-pref <pref>            NTP preference."
  echo "  --backup-dest <dest>         Backup destination."
  echo "  --backup-redundancy <num>    Backup redundancy."
  echo "  --archive-redundancy <num>   Archive redundancy."
  echo "  --archive-online-days <days> Archive online days."
  echo "  --backup-level0-days <days>  Backup level 0 days."
  echo "  --backup-level1-days <days>  Backup level 1 days."
  echo "  --backup-start-hour <hour>   Backup start hour."
  echo "  --backup-start-min <min>     Backup start minute."
  echo "  --archive-backup-min <min>   Archive backup minute."
  echo "  --backup-script-location <path> Backup script location."
  echo "  --backup-log-location <path> Backup log location."
  echo "  --gcs-backup-config <config> GCS backup configuration."
  echo "  --gcs-backup-bucket <bucket> GCS backup bucket."
  echo "  --gcs-backup-temp-path <path> GCS backup temporary path."
  echo "  --nfs-backup-config <config> NFS backup configuration."
  echo "  --nfs-backup-mount <mount>   NFS backup mount."
  echo "  --oracle-metrics-secret <secret> Oracle metrics secret."
  echo "  --skip-platform-compatibility Skip platform compatibility check."
  echo "  --compatible-rdbms <version> Compatible RDBMS version."
  echo "  --data-guard-protection-mode Data Guard protection mode (Maximum Performance, Maximum Availability, Maximum Protection)."
  echo "  --inventory-file <file>      Custom Ansible inventory file."
  echo "  --ar-repo-url <url>          Artifact Registry remote repository base URL."
  exit 0
fi

PB_LIST=""

if [ "$VALIDATE_ONLY" = true ]; then
  PB_LIST="${PB_VALIDATE}"
elif [ "$CHECK_INSTANCE_ONLY" = true ]; then
  PB_LIST="${PB_CHECK_INSTANCE}"
elif [ "$PREP_HOST_ONLY" = true ]; then
  PB_LIST="${PB_PREP_HOST}"
elif [ "$INSTALL_SW_ONLY" = true ]; then
  PB_LIST="${PB_INSTALL_SW}"
elif [ "$CONFIG_DB_ONLY" = true ]; then
  PB_LIST="${PB_CONFIG_DB}"
else
  PB_LIST="${PB_VALIDATE} ${PB_CHECK_INSTANCE} ${PB_PREP_HOST} ${PB_INSTALL_SW} ${PB_PATCH} ${PB_CONFIG_DB} ${PB_COMPATIBLE}"
fi

if [ "$SKIP_DATABASE_CONFIG" = true ]; then
  PB_LIST=${PB_LIST/$PB_CONFIG_DB/}
  PB_LIST=${PB_LIST/$PB_CONFIG_RAC_DB/}
fi



CLUSTER_TYPE="${YAML_VARS[ora_cluster_type]}"
if [[ "${CLUSTER_TYPE}" = "RAC" ]]; then
  PB_LIST=${PB_LIST/$PB_CONFIG_DB/$PB_CONFIG_RAC_DB}
fi

for PLAYBOOK in ${PB_LIST}; do
  echo "Running playbook: ${PLAYBOOK}"
  ansible-playbook ${INVENTORY_ARG} "${PLAYBOOK}" "${ANSIBLE_ARGS[@]}"
done
