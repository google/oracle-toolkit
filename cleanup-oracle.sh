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

GETOPT_LONG="ora-version:,ora-edition:,ora-swlib-path:,ora-staging:,ora-disk-mgmt:,ora-role-separation:,ora-asm-disks:,ora-asm-disks-json:,ora-data-mounts:,ora-data-mounts-json:,cluster-config:,cluster-config-json:,instance-ip-addr:,instance-hostname:,instance-ssh-user:,instance-ssh-key:,instance-ssh-extra-args:,inventory-file:,yes-i-am-sure"

options=$(getopt --longoptions "${GETOPT_LONG}" --options "" --name "$(basename "$0")" -- "$@")
eval set -- "$options"

CUSTOM_INVENTORY_FILE=""
ARE_YOU_SURE=0
declare -A YAML_VARS
ANSIBLE_ARGS=()

while true; do
  case "$1" in
    --inventory-file) CUSTOM_INVENTORY_FILE="$2"; shift 2 ;;
    --yes-i-am-sure) ARE_YOU_SURE=1; shift ;;
    --ora-version) YAML_VARS["ora_version"]="$2"; shift 2 ;;
    --ora-edition) YAML_VARS["ora_edition"]="$2"; shift 2 ;;
    --ora-swlib-path) YAML_VARS["ora_swlib_path"]="$2"; shift 2 ;;
    --ora-staging) YAML_VARS["ora_staging"]="$2"; shift 2 ;;
    --ora-disk-mgmt) YAML_VARS["ora_disk_mgmt"]="$2"; shift 2 ;;
    --ora-role-separation) YAML_VARS["ora_role_separation"]="$2"; shift 2 ;;
    --ora-asm-disks) YAML_VARS["ora_asm_disks"]="$2"; shift 2 ;;
    --ora-asm-disks-json) YAML_VARS["ora_asm_disks_json"]="$2"; shift 2 ;;
    --ora-data-mounts) YAML_VARS["ora_data_mounts"]="$2"; shift 2 ;;
    --ora-data-mounts-json) YAML_VARS["ora_data_mounts_json"]="$2"; shift 2 ;;
    --cluster-config) YAML_VARS["cluster_config"]="$2"; shift 2 ;;
    --cluster-config-json) YAML_VARS["cluster_config_json"]="$2"; shift 2 ;;
    --instance-ip-addr) YAML_VARS["instance_ip_addr"]="$2"; shift 2 ;;
    --instance-hostname) YAML_VARS["instance_hostname"]="$2"; shift 2 ;;
    --instance-ssh-user) YAML_VARS["instance_ssh_user"]="$2"; shift 2 ;;
    --instance-ssh-key) YAML_VARS["instance_ssh_key"]="$2"; shift 2 ;;
    --instance-ssh-extra-args) YAML_VARS["instance_ssh_extra_args"]="$2"; shift 2 ;;
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

PB_BRUTE_CLEANUP="brute-cleanup.yml"

echo "Running playbook: ${PB_BRUTE_CLEANUP}"
ansible-playbook ${INVENTORY_ARG} "${PB_BRUTE_CLEANUP}" "${ANSIBLE_ARGS[@]}"

if [[ -n "${TEMP_CONFIG_FILE}" ]]; then
  rm "${TEMP_CONFIG_FILE}"
fi
