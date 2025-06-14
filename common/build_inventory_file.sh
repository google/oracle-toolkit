#!/bin/bash
#
#  build_inventory_file() constructs an Ansible inventory file based on environment variables.
#  This function handles RAC and single-instance setups.
#
#
# Dependencies:
#   - 'jq' command-line JSON processor is required for RAC.
#
#   - The function relies on the following environment variables being set before it is called.
#
# Environment Variables (Input):
#   - CLUSTER_TYPE:           The type of cluster ("RAC", "NONE" or "DG").
#   - INSTANCE_SSH_USER:      SSH user for Ansible connections.
#   - INSTANCE_SSH_KEY:       Path to the SSH private key for Ansible.
#   - INSTANCE_SSH_EXTRA_ARGS: Extra arguments for the SSH connection.
#   - INVENTORY_FILE:         Base name for the inventory file. The function appends suffixes.
#   - ORA_DB_NAME:            Oracle database name, used for naming the inventory file.
#   - INSTANCE_HOSTGROUP_NAME: The name of the host group in the inventory file (e.g., [db]).
#   - CLUSTER_CONFIG:         Path to the JSON cluster configuration file (for RAC).
#   - CLUSTER_CONFIG_JSON:    A string containing the JSON cluster configuration (alternative to CLUSTER_CONFIG).
#   - INSTANCE_HOSTNAME:      Optional hostname for the target server. Defaults to value of INSTANCE_IP_ADDR.
#   - INSTANCE_IP_ADDR:       The IP address of the target server to host the Oracle software and database (for single instance installations).
#   - PRIMARY_IP_ADDR:        The IP address of the primary server to use as source of primary database for Data Guard configuration (for single instance installations).
#
# Output:
#   - Creates an inventory file in the current directory.
#   - On success, it prints the full path of the created inventory file to standard output.
#   - On failure, it prints an error message to standard error and exits the script with a non-zero status code.
#
# Example Usage (in a parent script):
#
#   source ./build_inventory_file.sh
#   export INVENTORY_FILE="inventory"
#   export CLUSTER_TYPE="RAC"
#   # ... (export all other required variables)
#
#   GENERATED_INVENTORY_FILE=$(build_inventory_file)
#   ansible-playbook -i "${GENERATED_INVENTORY_FILE}" my_playbook.yml
#

build_inventory_file() {
  local COMMON_OPTIONS="ansible_ssh_user=${INSTANCE_SSH_USER} ansible_ssh_private_key_file=${INSTANCE_SSH_KEY} ansible_ssh_extra_args=${INSTANCE_SSH_EXTRA_ARGS}"
  
  # Determine the inventory filename suffix based on the cluster type
  local inventory_suffix
  if [[ "${CLUSTER_TYPE}" = "RAC" ]]; then
    inventory_suffix="${ORA_DB_NAME}_${CLUSTER_TYPE}"
  else
    inventory_suffix="${INSTANCE_HOSTNAME}_${ORA_DB_NAME}"
  fi
  local FINAL_INVENTORY_FILE="${INVENTORY_FILE}_${inventory_suffix}"


  # Generate Inventory Content

  if [[ "${CLUSTER_TYPE}" = "RAC" ]]; then
    # For RAC, 'jq' is required. Validate its existence.
    command -v jq >/dev/null 2>&1 || {
      echo >&2 "Error: 'jq' is needed for the RAC feature but was not found. Please install jq."
      return 1
    }

    # Ensure cluster configuration is available, either from a variable or a file.
    local rac_config_json="${CLUSTER_CONFIG_JSON}"
    if [[ -z "${rac_config_json}" ]]; then
      if [[ -f "${CLUSTER_CONFIG}" ]]; then
        rac_config_json=$(<"${CLUSTER_CONFIG}")
      else
        printf "\n\033[1;31m%s\033[m\n\n" "Error: Cluster type is '${CLUSTER_TYPE}', but the configuration file '${CLUSTER_CONFIG}' was not found and --cluster-config-json is empty." >&2
        return 1
      fi
    fi

    # jq filters to extract node details and variables from the JSON config
    local JQF_NODES='.[] | .nodes[] | .node_name + " ansible_ssh_host=" + .host_ip + " vip_name=" + .vip_name + " vip_ip=" + .vip_ip'
    local JQF_VARS='.[] | with_entries(.value = if .value|type != "array" then .value else empty end) | with_entries(select(.value != "")) | to_entries[] | .key + "=" + .value'

    # Build the inventory file for RAC
    {
      echo "[${INSTANCE_HOSTGROUP_NAME}]"
      echo "${rac_config_json}" | jq -rc "${JQF_NODES}" | awk -v opts="${COMMON_OPTIONS}" '{print $0" " opts}'
      echo ""
      echo "[${INSTANCE_HOSTGROUP_NAME}:vars]"
      echo "${rac_config_json}" | jq -rc "${JQF_VARS}"
    } > "${FINAL_INVENTORY_FILE}"

  else # For all non-RAC types
    # Start the inventory file with the main host group
    printf "[%s]\n%s ansible_ssh_host=%s %s\n" \
      "${INSTANCE_HOSTGROUP_NAME}" \
      "${INSTANCE_HOSTNAME}" \
      "${INSTANCE_IP_ADDR}" \
      "${COMMON_OPTIONS}" \
      > "${FINAL_INVENTORY_FILE}"

    # If a primary IP is specified, add a [primary] group
    if [[ -n "${PRIMARY_IP_ADDR}" ]]; then
      printf "\n[primary]\nprimary1 ansible_ssh_host=%s %s\n" \
        "${PRIMARY_IP_ADDR}" \
        "${COMMON_OPTIONS}" \
        >> "${FINAL_INVENTORY_FILE}"
    fi
  fi

  echo "${FINAL_INVENTORY_FILE}"
  return 0
}