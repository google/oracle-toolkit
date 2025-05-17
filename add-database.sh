#!/bin/bash
# Copyright 2020 Google LLC
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

echo Command used:
echo "$0 $@"
echo

#
# Some variables
#
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"

#
# Playbooks
#
PB_CHECK_INSTANCE="check-instance.yml"
PB_CONFIG_DB="config-db.yml"
PB_CONFIG_RAC_DB="config-rac-db.yml"

#
# Verify playbooks exist
#
for PBOOK in "${PB_CHECK_INSTANCE}" "${PB_CONFIG_DB}"; do
  if [[ ! -f "${PBOOK}" ]]; then
    printf "\n\033[1;31m%s\033[m\n\n" "The playbook ${PBOOK} does not exist; cannot continue."
    exit 126
  else
    if [[ -z "${PB_LIST}" ]]; then
      PB_LIST="${PBOOK}"
    else
      PB_LIST="${PB_LIST} ${PBOOK}"
    fi
  fi
done

#
# Inventory file (used to run the playbooks)
#
INVENTORY_DIR="./inventory_files"           # Where to save the inventory files
INVENTORY_FILE="${INVENTORY_DIR}/inventory" # Default, the whole name will be built later using some parameters
INSTANCE_HOSTGROUP_NAME="dbasm"             # Constant used for both SI and RAC installations
#
if [[ ! -d "${INVENTORY_DIR}" ]]; then
  mkdir -p "${INVENTORY_DIR}"
  if [ $? -eq 0 ]; then
    printf "\n\033[1;36m%s\033[m\n\n" "Successfully created the ${INVENTORY_DIR} directory to save the inventory files."
  else
    printf "\n\033[1;31m%s\033[m\n\n" "Unable to create the ${INVENTORY_DIR} directory to save the inventory files; cannot continue."
    exit 123
  fi
fi

#
# Ansible logs directory, the logfile name is created later one
#
LOG_DIR="./logs"
LOG_FILE="${LOG_DIR}/log"
if [[ ! -d "${LOG_DIR}" ]]; then
  mkdir -p "${LOG_DIR}"
  if [ $? -eq 0 ]; then
    printf "\n\033[1;36m%s\033[m\n\n" "Successfully created the ${LOG_DIR} directory to save the ansible logs."
  else
    printf "\n\033[1;31m%s\033[m\n\n" "Unable to create the ${LOG_DIR} directory to save the ansible logs; cannot continue."
    exit 123
  fi
fi

shopt -s nocasematch

# Check if we're using the Mac stock getopt and fail if true
out="$(getopt -T)"
if [ $? != 4 ]; then
  echo -e "Your getopt does not support long parameters, possibly you're on a Mac, if so please install gnu-getopt with brew"
  echo -e "\thttps://brewformulas.org/Gnu-getopt"
  exit
fi

#
# Initialize PB_LIST variable before it's referenced
#
PB_LIST="check-instance.yml config-db.yml"

# Parameter Definitions
ORA_DB_NAME="${ORA_DB_NAME:-ORCL}"
ORA_DB_NAME_PARAM="^[a-zA-Z0-9_$]+$"

ORA_DB_DOMAIN="${ORA_DB_DOMAIN}"
ORA_DB_DOMAIN_PARAM="^[a-zA-Z0-9]*$"

ORA_DB_CHARSET="${ORA_DB_CHARSET:-AL32UTF8}"
ORA_DB_CHARSET_PARAM="^.+$"

ORA_DB_NCHARSET="${ORA_DB_NCHARSET:-AL16UTF16}"
ORA_DB_NCHARSET_PARAM="^.+$"

ORA_DB_CONTAINER="${ORA_DB_CONTAINER:-TRUE}"
ORA_DB_CONTAINER_PARAM="^(TRUE|FALSE)$"

ORA_DB_TYPE="${ORA_DB_TYPE:-MULTIPURPOSE}"
ORA_DB_TYPE_PARAM="MULTIPURPOSE|DATA_WAREHOUSING|OLTP"

ORA_DB_HOME_DIR="${ORA_DB_HOME_DIR}"
ORA_DB_HOME_DIR_PARAM="^/.*"

ORA_PDB_NAME_PREFIX="${ORA_PDB_NAME_PREFIX:-PDB}"
ORA_PDB_NAME_PREFIX_PARAM="^[a-zA-Z0-9]+$"

ORA_PDB_COUNT="${ORA_PDB_COUNT:-1}"
ORA_PDB_COUNT_PARAM="^[0-9]+"

ORA_REDO_LOG_SIZE="${ORA_REDO_LOG_SIZE:-100MB}"
ORA_REDO_LOG_SIZE_PARAM="^[0-9]+MB$"

ORA_LISTENER_NAME="${ORA_LISTENER_NAME:-LISTENER}"
ORA_LISTENER_NAME_PARAM="^[a-zA-Z0-9_]+$"

ORA_LISTENER_PORT="${ORA_LISTENER_PORT:-1521}"
ORA_LISTENER_PORT_PARAM="^[0-9]+$"

ORA_DATA_DESTINATION="${ORA_DATA_DESTINATION:-DATA}"
ORA_DATA_DESTINATION_PARAM="^(\/|\+)?[a-zA-Z0-9]+$"

ORA_RECO_DESTINATION="${ORA_RECO_DESTINATION:-RECO}"
ORA_RECO_DESTINATION_PARAM="^(\/|\+)?[a-zA-Z0-9]+$"

SGA_TARGET="${SGA_TARGET}"
SGA_TARGET_PARAM="^([0-9]+[MG]|[0-9]+%)$"

PGA_AGGREGATE_TARGET="${PGA_AGGREGATE_TARGET}"
PGA_AGGREGATE_TARGET_PARAM="^([0-9]+[MG]|[0-9]+%)$"

MEMORY_PERCENT="${MEMORY_PERCENT}"
MEMORY_PERCENT_PARAM="^[0-9]+$"

INSTANCE_IP_ADDR="${INSTANCE_IP_ADDR}"
INSTANCE_IP_ADDR_PARAM="[a-z0-9][a-z0-9\-\.]*"

PRIMARY_IP_ADDR="${PRIMARY_IP_ADDR}"
PRIMARY_IP_ADDR_PARAM='^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$'

INSTANCE_SSH_USER="${INSTANCE_SSH_USER:-$(whoami)}"
INSTANCE_SSH_USER_PARAM="^[a-z0-9][a-z0-9_\-\.]*$"

INSTANCE_HOSTNAME="${INSTANCE_HOSTNAME:-${INSTANCE_IP_ADDR}}"
INSTANCE_HOSTNAME_PARAM="^[a-z0-9]+$"

INSTANCE_SSH_KEY="${INSTANCE_SSH_KEY:-~/.ssh/id_rsa}"
INSTANCE_SSH_KEY_PARAM="^.+$"

INSTANCE_SSH_EXTRA_ARGS="${INSTANCE_SSH_EXTRA_ARGS:-'-o ServerAliveInterval=60 -o ServerAliveCountMax=3 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o IdentityAgent=no'}"
INSTANCE_SSH_EXTRA_ARGS_PARAM="^.+$"

BACKUP_DEST="${BACKUP_DEST}"
BACKUP_DEST_PARAM="^(\/|\+)?.*$"

BACKUP_REDUNDANCY="${BACKUP_REDUNDANCY:-2}"
BACKUP_REDUNDANCY_PARAM="^[0-9]+$"

ARCHIVE_REDUNDANCY="${ARCHIVE_REDUNDANCY:-2}"
ARCHIVE_REDUNDANCY_PARAM="^[0-9]+$"

ARCHIVE_ONLINE_DAYS="${ARCHIVE_ONLINE_DAYS:-7}"
ARCHIVE_ONLINE_DAYS_PARAM="^[0-9]+$"

BACKUP_LEVEL0_DAYS="${BACKUP_LEVEL0_DAYS:-0}"
BACKUP_LEVEL0_DAYS_PARAM="^[0-6]-?[0-6]?$"

BACKUP_LEVEL1_DAYS="${BACKUP_LEVEL1_DAYS:-1-6}"
BACKUP_LEVEL1_DAYS_PARAM="^[0-6]-?[0-6]?$"

BACKUP_START_HOUR="${BACKUP_START_HOUR:-01}"
BACKUP_START_HOUR_PARAM="^(2[0-3]|[01]?[0-9])$"

BACKUP_START_MIN="${BACKUP_START_MIN:-00}"
BACKUP_START_MIN_PARAM="^[0-5][0-9]$"

ARCHIVE_BACKUP_MIN="${ARCHIVE_BACKUP_MIN:-30}"
ARCHIVE_BACKUP_MIN_PARAM="^[0-5][0-9]$"

BACKUP_SCRIPT_LOCATION="${BACKUP_SCRIPT_LOCATION:-/home/oracle/scripts}"
BACKUP_SCRIPT_LOCATION_PARAM="^/.+$"

BACKUP_LOG_LOCATION="${BACKUP_LOG_LOCATION:-/home/oracle/logs}"
BACKUP_LOG_LOCATION_PARAM="^/.+$"

export ANSIBLE_DISPLAY_SKIPPED_HOSTS=false

###
GETOPT_MANDATORY="instance-ip-addr:"
GETOPT_OPTIONAL="ora-db-name:,ora-db-domain:,ora-db-charset:,ora-db-ncharset:,ora-db-container:,ora-db-type:"
GETOPT_OPTIONAL="$GETOPT_OPTIONAL,ora-db-home-dir:,ora-pdb-name-prefix:,ora-pdb-count:,ora-redo-log-size:"
GETOPT_OPTIONAL="$GETOPT_OPTIONAL,ora-data-destination:,ora-reco-destination:,ora-listener-port:,ora-listener-name:"
GETOPT_OPTIONAL="$GETOPT_OPTIONAL,backup-dest:,backup-redundancy:,archive-redundancy:,archive-online-days:,backup-level0-days:,backup-level1-days:"
GETOPT_OPTIONAL="$GETOPT_OPTIONAL,backup-start-hour:,backup-start-min:,archive-backup-min:,backup-script-location:,backup-log-location:"
GETOPT_OPTIONAL="$GETOPT_OPTIONAL,instance-ssh-user:,instance-ssh-key:,instance-hostname:,instance-ssh-extra-args:"
GETOPT_OPTIONAL="$GETOPT_OPTIONAL,sga-target:,pga-aggregate-target:,memory-percent:"
GETOPT_OPTIONAL="$GETOPT_OPTIONAL,help,validate,check-instance,config-db,debug"
GETOPT_LONG="$GETOPT_MANDATORY,$GETOPT_OPTIONAL"
GETOPT_SHORT="h"

VALIDATE=0

options="$(getopt --longoptions "$GETOPT_LONG" --options "$GETOPT_SHORT" -- "$@")"

[ $? -eq 0 ] || {
  echo "Invalid options provided: $@" >&2
  exit 1
}

eval set -- "$options"

while true; do
  case "$1" in
  --ora-db-name)
    ORA_DB_NAME="$2"
    shift
    ;;
  --ora-db-domain)
    ORA_DB_DOMAIN="$2"
    shift
    ;;
  --ora-db-charset)
    ORA_DB_CHARSET="$2"
    shift
    ;;
  --ora-db-ncharset)
    ORA_DB_NCHARSET="$2"
    shift
    ;;
  --ora-db-container)
    ORA_DB_CONTAINER="$2"
    shift
    ;;
  --ora-db-home-dir)
    ORA_DB_HOME_DIR="$2"
    shift
    ;;
  --ora-db-type)
    ORA_DB_TYPE="$2"
    shift
    ;;
  --ora-pdb-name-prefix)
    ORA_PDB_NAME_PREFIX="$2"
    shift
    ;;
  --ora-pdb-count)
    ORA_PDB_COUNT="$2"
    shift
    ;;
  --ora-redo-log-size)
    ORA_REDO_LOG_SIZE="$2"
    shift
    ;;
  --ora-data-destination)
    ORA_DATA_DESTINATION="$2"
    shift
    ;;
  --ora-reco-destination)
    ORA_RECO_DESTINATION="$2"
    shift
    ;;
  --ora-listener-port)
    ORA_LISTENER_PORT="$2"
    shift
    ;;
  --ora-listener-name)
    ORA_LISTENER_NAME="$2"
    shift
    ;;
  --backup-dest)
    BACKUP_DEST="$2"
    shift
    ;;
  --backup-redundancy)
    BACKUP_REDUNDANCY="$2"
    shift
    ;;
  --archive-redundancy)
    ARCHIVE_REDUNDANCY="$2"
    shift
    ;;
  --archive-online-days)
    ARCHIVE_ONLINE_DAYS="$2"
    shift
    ;;
  --backup-level0-days)
    BACKUP_LEVEL0_DAYS="$2"
    shift
    ;;
  --backup-level1-days)
    BACKUP_LEVEL1_DAYS="$2"
    shift
    ;;
  --backup-start-hour)
    BACKUP_START_HOUR="$2"
    shift
    ;;
  --backup-start-min)
    BACKUP_START_MIN="$2"
    shift
    ;;
  --archive-backup-min)
    ARCHIVE_BACKUP_MIN="$2"
    shift
    ;;
  --backup-script-location)
    BACKUP_SCRIPT_LOCATION="$2"
    shift
    ;;
  --backup-log-location)
    BACKUP_LOG_LOCATION="$2"
    shift
    ;;
  --sga-target)
    SGA_TARGET="$2"
    shift
    ;;
  --pga-aggregate-target)
    PGA_AGGREGATE_TARGET="$2"
    shift
    ;;
  --memory-percent)
    MEMORY_PERCENT="$2"
    shift
    ;;
  --instance-ip-addr)
    INSTANCE_IP_ADDR="$2"
    shift
    ;;
  --instance-ssh-key)
    INSTANCE_SSH_KEY="$2"
    shift
    ;;
  --instance-hostname)
    INSTANCE_HOSTNAME="$2"
    shift
    ;;
  --instance-ssh-user)
    INSTANCE_SSH_USER="$2"
    shift
    ;;
  --instance-ssh-extra-args)
    INSTANCE_SSH_EXTRA_ARGS="$2"
    shift
    ;;
  --check-instance)
    PARAM_PB_CHECK_INSTANCE="${PB_CHECK_INSTANCE}"
    ;;
  --config-db)
    PARAM_PB_CONFIG_DB="${PB_CONFIG_DB}"
    ;;
  --debug)
    export ANSIBLE_DEBUG=1
    export ANSIBLE_DISPLAY_SKIPPED_HOSTS=true
    ;;
  --validate)
    VALIDATE=1
    ;;
  --help | -h)
    echo -e "\tUsage: $(basename $0)" >&2
    echo "${GETOPT_MANDATORY}" | sed 's/,/\n/g' | sed 's/:/ <value>/' | sed 's/\(.\+\)/\t --\1/'
    echo "${GETOPT_OPTIONAL}"  | sed 's/,/\n/g' | sed 's/:/ <value>/' | sed 's/\(.\+\)/\t [ --\1 ]/'
    echo -e "\t -- [parameters sent to ansible]"
    exit 2
    ;;
  --)
    shift
    break
    ;;
  esac
  shift
done

#
# Build the playbook list to execute depending on the command line option if specified
#
# Only modify PB_LIST if specific playbooks are requested via parameters
if [[ -n "${PARAM_PB_CHECK_INSTANCE}" || -n "${PARAM_PB_CONFIG_DB}" ]]; then
  PARAM_PB_LIST=""
  for PARAM in "${PARAM_PB_CHECK_INSTANCE}" "${PARAM_PB_CONFIG_DB}"; do
    if [[ -n "${PARAM}" ]]; then
      PARAM_PB_LIST="${PARAM_PB_LIST} ${PARAM}"
    fi
  done
  if [[ -n "${PARAM_PB_LIST}" ]]; then
    PB_LIST="${PARAM_PB_LIST}"
  fi
fi

# Print the playbooks that will be executed
printf "\n\033[1;36m%s\033[m\n\n" "Will execute the following playbooks: ${PB_LIST}"

#
# Parameter defaults
#
INSTANCE_HOSTNAME="${INSTANCE_HOSTNAME:-$INSTANCE_IP_ADDR}"

#
# Variables verification
#
shopt -s nocasematch

[[ ! "$ORA_DB_NAME" =~ $ORA_DB_NAME_PARAM ]] && {
  echo "Incorrect parameter provided for ora-db-name: $ORA_DB_NAME"
  exit 1
}
[[ ! "$ORA_DB_DOMAIN" =~ $ORA_DB_DOMAIN_PARAM ]] && {
  echo "Incorrect parameter provided for ora-db-domain: $ORA_DB_DOMAIN"
  exit 1
}
[[ ! "$ORA_DB_CHARSET" =~ $ORA_DB_CHARSET_PARAM ]] && {
  echo "Incorrect parameter provided for ora-db-charset: $ORA_DB_CHARSET"
  exit 1
}
[[ ! "$ORA_DB_NCHARSET" =~ $ORA_DB_NCHARSET_PARAM ]] && {
  echo "Incorrect parameter provided for ora-db-ncharset: $ORA_DB_NCHARSET"
  exit 1
}
[[ ! "$ORA_DB_CONTAINER" =~ $ORA_DB_CONTAINER_PARAM ]] && {
  echo "Incorrect parameter provided for ora-db-container: $ORA_DB_CONTAINER"
  exit 1
}
[[ ! "$ORA_DB_TYPE" =~ $ORA_DB_TYPE_PARAM ]] && {
  echo "Incorrect parameter provided for ora-db-type: $ORA_DB_TYPE"
  exit 1
}
[[ -n "$ORA_DB_HOME_DIR" && ! "$ORA_DB_HOME_DIR" =~ $ORA_DB_HOME_DIR_PARAM ]] && {
  echo "Incorrect parameter provided for ora-db-home-dir: $ORA_DB_HOME_DIR"
  exit 1
}
[[ ! "$ORA_PDB_NAME_PREFIX" =~ $ORA_PDB_NAME_PREFIX_PARAM ]] && {
  echo "Incorrect parameter provided for ora-pdb-name-prefix: $ORA_PDB_NAME_PREFIX"
  exit 1
}
[[ ! "$ORA_PDB_COUNT" =~ $ORA_PDB_COUNT_PARAM ]] && {
  echo "Incorrect parameter provided for ora-pdb-count: $ORA_PDB_COUNT"
  exit 1
}
[[ ! "$ORA_REDO_LOG_SIZE" =~ $ORA_REDO_LOG_SIZE_PARAM ]] && {
  echo "Incorrect parameter provided for ora-redo-log-size: $ORA_REDO_LOG_SIZE"
  exit 1
}
[[ ! "$ORA_DATA_DESTINATION" =~ $ORA_DATA_DESTINATION_PARAM ]] && {
  echo "Incorrect parameter provided for ora-data-destination: $ORA_DATA_DESTINATION"
  exit 1
}
[[ ! "$ORA_RECO_DESTINATION" =~ $ORA_RECO_DESTINATION_PARAM ]] && {
  echo "Incorrect parameter provided for ora-reco-destination: $ORA_RECO_DESTINATION"
  exit 1
}
[[ ! "$ORA_LISTENER_PORT" =~ $ORA_LISTENER_PORT_PARAM ]] && {
  echo "Incorrect parameter provided for ora-listener-port: $ORA_LISTENER_PORT"
  exit 1
}
[[ ! "$ORA_LISTENER_NAME" =~ $ORA_LISTENER_NAME_PARAM ]] && {
  echo "Incorrect parameter provided for ora-listener-name: $ORA_LISTENER_NAME"
  exit 1
}
[[ -n "$SGA_TARGET" && ! "$SGA_TARGET" =~ $SGA_TARGET_PARAM ]] && {
  echo "Incorrect parameter provided for sga-target: $SGA_TARGET"
  exit 1
}
[[ -n "$PGA_AGGREGATE_TARGET" && ! "$PGA_AGGREGATE_TARGET" =~ $PGA_AGGREGATE_TARGET_PARAM ]] && {
  echo "Incorrect parameter provided for pga-aggregate-target: $PGA_AGGREGATE_TARGET"
  exit 1
}
[[ -n "$MEMORY_PERCENT" && ! "$MEMORY_PERCENT" =~ $MEMORY_PERCENT_PARAM ]] && {
  echo "Incorrect parameter provided for memory-percent: $MEMORY_PERCENT"
  exit 1
}
[[ ! "$BACKUP_DEST" =~ $BACKUP_DEST_PARAM ]] && [[ "$PB_LIST" =~ "config-db.yml" ]] && {
  echo "Incorrect parameter provided for backup-dest: $BACKUP_DEST"
  exit 1
}
[[ ! "$BACKUP_REDUNDANCY" =~ $BACKUP_REDUNDANCY_PARAM ]] && {
  echo "Incorrect parameter provided for backup-redundancy: $BACKUP_REDUNDANCY"
  exit 1
}
[[ ! "$ARCHIVE_REDUNDANCY" =~ $ARCHIVE_REDUNDANCY_PARAM ]] && {
  echo "Incorrect parameter provided for archive-redundancy: $ARCHIVE_REDUNDANCY"
  exit 1
}
[[ ! "$ARCHIVE_ONLINE_DAYS" =~ $ARCHIVE_ONLINE_DAYS_PARAM ]] && {
  echo "Incorrect parameter provided for archive-online-days: $ARCHIVE_ONLINE_DAYS"
  exit 1
}
[[ ! "$BACKUP_LEVEL0_DAYS" =~ $BACKUP_LEVEL0_DAYS_PARAM ]] && {
  echo "Incorrect parameter provided for backup-level0-days: $BACKUP_LEVEL0_DAYS"
  exit 1
}
[[ ! "$BACKUP_LEVEL1_DAYS" =~ $BACKUP_LEVEL1_DAYS_PARAM ]] && {
  echo "Incorrect parameter provided for backup-level1-days: $BACKUP_LEVEL1_DAYS"
  exit 1
}
[[ ! "$BACKUP_START_HOUR" =~ $BACKUP_START_HOUR_PARAM ]] && {
  echo "Incorrect parameter provided for backup-start-hour: $BACKUP_START_HOUR"
  exit 1
}
[[ ! "$BACKUP_START_MIN" =~ $BACKUP_START_MIN_PARAM ]] && {
  echo "Incorrect parameter provided for backup-start-min: $BACKUP_START_MIN"
  exit 1
}
[[ ! "$ARCHIVE_BACKUP_MIN" =~ $ARCHIVE_BACKUP_MIN_PARAM ]] && {
  echo "Incorrect parameter provided for archive-backup-min: $ARCHIVE_BACKUP_MIN"
  exit 1
}
[[ ! "$BACKUP_SCRIPT_LOCATION" =~ $BACKUP_SCRIPT_LOCATION_PARAM ]] && {
  echo "Incorrect parameter provided for backup-script-location: $BACKUP_SCRIPT_LOCATION"
  exit 1
}
[[ ! "$BACKUP_LOG_LOCATION" =~ $BACKUP_LOG_LOCATION_PARAM ]] && {
  echo "Incorrect parameter provided for backup-log-location: $BACKUP_LOG_LOCATION"
  exit 1
}
[[ ! "$INSTANCE_IP_ADDR" =~ ${INSTANCE_IP_ADDR_PARAM} ]] && {
  echo "Incorrect parameter provided for instance-ip-addr: $INSTANCE_IP_ADDR"
  exit 1
}
[[ ! "$INSTANCE_SSH_USER" =~ $INSTANCE_SSH_USER_PARAM ]] && {
  echo "Incorrect parameter provided for instance-ssh-user: $INSTANCE_SSH_USER"
  exit 1
}
[[ ! "$INSTANCE_SSH_KEY" =~ $INSTANCE_SSH_KEY_PARAM ]] && {
  echo "Incorrect parameter provided for instance-ssh-key: $INSTANCE_SSH_KEY"
  exit 1
}

# Oracle home existence check
if [[ -n "$ORA_DB_HOME_DIR" ]]; then
  printf "\n\033[1;36m%s\033[m\n\n" "Checking Oracle Home directory: $ORA_DB_HOME_DIR"
  
  # Build the inventory file for checking
  INVENTORY_FILE_CHECK="${INVENTORY_FILE}_check_${TIMESTAMP}"
  COMMON_OPTIONS="ansible_ssh_user=${INSTANCE_SSH_USER} ansible_ssh_private_key_file=${INSTANCE_SSH_KEY} ansible_ssh_extra_args=${INSTANCE_SSH_EXTRA_ARGS}"
  
  cat <<EOF >"${INVENTORY_FILE_CHECK}"
[${INSTANCE_HOSTGROUP_NAME}]
${INSTANCE_HOSTNAME} ansible_ssh_host=${INSTANCE_IP_ADDR} ${COMMON_OPTIONS}
EOF

  ANSIBLE_COMMAND="ansible ${INSTANCE_HOSTGROUP_NAME} -i ${INVENTORY_FILE_CHECK} -m stat -a 'path=${ORA_DB_HOME_DIR}'"
  eval "${ANSIBLE_COMMAND}" > /dev/null
  
  if [ $? -ne 0 ]; then
    printf "\n\033[1;31m%s\033[m\n\n" "The specified Oracle Home directory ${ORA_DB_HOME_DIR} does not exist or is not accessible."
    exit 1
  fi
  
  # Validate Oracle binaries
  ANSIBLE_COMMAND="ansible ${INSTANCE_HOSTGROUP_NAME} -i ${INVENTORY_FILE_CHECK} -m stat -a 'path=${ORA_DB_HOME_DIR}/bin/sqlplus'"
  eval "${ANSIBLE_COMMAND}" > /dev/null
  
  if [ $? -ne 0 ]; then
    printf "\n\033[1;31m%s\033[m\n\n" "The specified Oracle Home directory ${ORA_DB_HOME_DIR} does not contain valid Oracle binaries (sqlplus not found)."
    exit 1
  fi
  
  # Check inventory.xml
  ORACLE_INVENTORY_DIR="/etc/oraInst.loc"
  ANSIBLE_COMMAND="ansible ${INSTANCE_HOSTGROUP_NAME} -i ${INVENTORY_FILE_CHECK} -m shell -a 'if [ -f ${ORACLE_INVENTORY_DIR} ]; then cat ${ORACLE_INVENTORY_DIR} | grep inventory_loc | cut -d= -f2; else echo \"/u01/app/oraInventory\"; fi'"
  INVENTORY_LOC=$(eval "${ANSIBLE_COMMAND}" | grep -v "CHANGED" | grep -v "SUCCESS" | grep -v "^$" | tr -d '[:space:]')
  
  if [ -z "$INVENTORY_LOC" ]; then
    printf "\n\033[1;33m%s\033[m\n\n" "Warning: Could not determine Oracle inventory location. Will proceed, but inventory registration should be verified manually."
  else
    ANSIBLE_COMMAND="ansible ${INSTANCE_HOSTGROUP_NAME} -i ${INVENTORY_FILE_CHECK} -m shell -a 'grep -l ${ORA_DB_HOME_DIR} ${INVENTORY_LOC}/ContentsXML/inventory.xml || echo \"NOT_FOUND\"'"
    INVENTORY_RESULT=$(eval "${ANSIBLE_COMMAND}" | grep -v "CHANGED" | grep -v "SUCCESS" | grep -v "^$")
    
    if [[ "$INVENTORY_RESULT" == *"NOT_FOUND"* ]]; then
      printf "\n\033[1;33m%s\033[m\n\n" "Warning: The specified Oracle Home directory ${ORA_DB_HOME_DIR} is not registered in the Oracle inventory."
      printf "\n\033[1;33m%s\033[m\n\n" "This might cause issues. Please verify that this Oracle home was properly installed."
    fi
  fi
  
  # Database existence check
  ANSIBLE_COMMAND="ansible ${INSTANCE_HOSTGROUP_NAME} -i ${INVENTORY_FILE_CHECK} -m shell -a 'ps -ef | grep pmon | grep -i ${ORA_DB_NAME} | grep -v grep || echo \"NOT_RUNNING\"'"
  DB_RUNNING=$(eval "${ANSIBLE_COMMAND}" | grep -v "CHANGED" | grep -v "SUCCESS" | grep -v "^$")
  
  if [[ "$DB_RUNNING" != *"NOT_RUNNING"* ]]; then
    printf "\n\033[1;31m%s\033[m\n\n" "A database process with name ${ORA_DB_NAME} is already running on the target system."
    exit 1
  fi
  
  ANSIBLE_COMMAND="ansible ${INSTANCE_HOSTGROUP_NAME} -i ${INVENTORY_FILE_CHECK} -m shell -a 'grep -i \"${ORA_DB_NAME}:\" /etc/oratab || echo \"NOT_FOUND\"'"
  DB_ORATAB=$(eval "${ANSIBLE_COMMAND}" | grep -v "CHANGED" | grep -v "SUCCESS" | grep -v "^$")
  
  if [[ "$DB_ORATAB" != *"NOT_FOUND"* ]]; then
    printf "\n\033[1;31m%s\033[m\n\n" "A database with name ${ORA_DB_NAME} is already registered in /etc/oratab on the target system."
    exit 1
  fi
  
  # Get Oracle version from specified home - using multiple patterns to handle different version formats
  ANSIBLE_COMMAND="ansible ${INSTANCE_HOSTGROUP_NAME} -i ${INVENTORY_FILE_CHECK} -m shell -a 'export ORACLE_HOME=${ORA_DB_HOME_DIR}; ${ORA_DB_HOME_DIR}/bin/sqlplus -V'"
  SQLPLUS_VERSION_OUTPUT=$(eval "${ANSIBLE_COMMAND}" | grep -v "CHANGED" | grep -v "SUCCESS" | grep -v "^$")
  
  # Try different regex patterns for version extraction
  ORACLE_VERSION=$(echo "$SQLPLUS_VERSION_OUTPUT" | grep -o "[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*" | head -1)
  
  if [[ -z "$ORACLE_VERSION" ]]; then
    # Try alternative pattern for older versions
    ORACLE_VERSION=$(echo "$SQLPLUS_VERSION_OUTPUT" | grep -o "[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*" | head -1)
    
    if [[ -n "$ORACLE_VERSION" ]]; then
      # Convert to 5-part version if needed
      if [[ "$ORACLE_VERSION" == "11.2.0" ]]; then
        ORACLE_VERSION="11.2.0.4.0"
      elif [[ "$ORACLE_VERSION" == "12.1.0" ]]; then
        ORACLE_VERSION="12.1.0.2.0"
      elif [[ "$ORACLE_VERSION" == "12.2.0" ]]; then
        ORACLE_VERSION="12.2.0.1.0"
      elif [[ "$ORACLE_VERSION" == "18.0.0" || "$ORACLE_VERSION" == "18.3.0" ]]; then
        ORACLE_VERSION="18.0.0.0.0"
      elif [[ "$ORACLE_VERSION" == "19.0.0" || "$ORACLE_VERSION" == "19.3.0" ]]; then
        ORACLE_VERSION="19.3.0.0.0"
      else
        # Append missing parts
        ORACLE_VERSION="${ORACLE_VERSION}.0.0"
      fi
    fi
  fi
  
  if [[ -z "$ORACLE_VERSION" ]]; then
    printf "\n\033[1;33m%s\033[m\n\n" "Warning: Could not determine Oracle version from the specified home. Will use default values."
    ORACLE_VERSION="19.3.0.0.0"
  fi
  
  printf "\n\033[1;36m%s\033[m\n\n" "Detected Oracle version: ${ORACLE_VERSION}"
  ORA_VERSION="${ORACLE_VERSION}"
  
  # Clean up temporary inventory file
  rm -f "${INVENTORY_FILE_CHECK}"
fi

# Memory calculations
if [[ -n "$MEMORY_PERCENT" ]]; then
  # Get total memory from target system
  INVENTORY_FILE_MEM="${INVENTORY_FILE}_mem_${TIMESTAMP}"
  COMMON_OPTIONS="ansible_ssh_user=${INSTANCE_SSH_USER} ansible_ssh_private_key_file=${INSTANCE_SSH_KEY} ansible_ssh_extra_args=${INSTANCE_SSH_EXTRA_ARGS}"
  
  cat <<EOF >"${INVENTORY_FILE_MEM}"
[${INSTANCE_HOSTGROUP_NAME}]
${INSTANCE_HOSTNAME} ansible_ssh_host=${INSTANCE_IP_ADDR} ${COMMON_OPTIONS}
EOF

  ANSIBLE_COMMAND="ansible ${INSTANCE_HOSTGROUP_NAME} -i ${INVENTORY_FILE_MEM} -m shell -a 'free -m | grep Mem | awk \"{print \\\$2}\"'"
  TOTAL_MEMORY_MB=$(eval "${ANSIBLE_COMMAND}" | grep -v "CHANGED" | grep -v "SUCCESS" | grep -v "^$" | tr -d '[:space:]')
  
  if [[ -z "$TOTAL_MEMORY_MB" || ! "$TOTAL_MEMORY_MB" =~ ^[0-9]+$ ]]; then
    printf "\n\033[1;33m%s\033[m\n\n" "Warning: Could not determine total memory. Will use default memory settings."
    # Default to 2GB SGA for safety
    SGA_TARGET="2048M"
    PGA_AGGREGATE_TARGET="512M"
  else
    # Calculate SGA_TARGET based on percentage
    SGA_TARGET_MB=$((TOTAL_MEMORY_MB * MEMORY_PERCENT / 100))
    
    # Ensure minimum SGA size (1GB)
    if [ $SGA_TARGET_MB -lt 1024 ]; then
      printf "\n\033[1;33m%s\033[m\n\n" "Warning: Calculated SGA size is less than 1GB. Setting to minimum 1GB."
      SGA_TARGET_MB=1024
    fi
    
    SGA_TARGET="${SGA_TARGET_MB}M"
    
    # Default PGA to 150M or 25% of SGA, whichever is greater
    PGA_DEFAULT_MB=$((SGA_TARGET_MB / 4))
    if [ $PGA_DEFAULT_MB -lt 150 ]; then
      PGA_DEFAULT_MB=150
    fi
    
    if [[ -z "$PGA_AGGREGATE_TARGET" ]]; then
      PGA_AGGREGATE_TARGET="${PGA_DEFAULT_MB}M"
    fi
    
    printf "\n\033[1;36m%s\033[m\n\n" "Memory settings based on ${MEMORY_PERCENT}% of total memory (${TOTAL_MEMORY_MB}MB):"
    printf "\n\033[1;36m%s\033[m\n\n" "SGA_TARGET: ${SGA_TARGET}"
    printf "\n\033[1;36m%s\033[m\n\n" "PGA_AGGREGATE_TARGET: ${PGA_AGGREGATE_TARGET}"
  fi
  
  # Clean up temporary inventory file
  rm -f "${INVENTORY_FILE_MEM}"
elif [[ -z "$SGA_TARGET" && -z "$PGA_AGGREGATE_TARGET" ]]; then
  # No memory settings provided, use sensible defaults
  printf "\n\033[1;33m%s\033[m\n\n" "No memory settings provided. Will use Ansible defaults (45% of total memory for SGA, 150M for PGA)."
fi

#
# Build the inventory file
#
INVENTORY_FILE="${INVENTORY_FILE}_${INSTANCE_HOSTNAME}_${ORA_DB_NAME}_${TIMESTAMP}"
COMMON_OPTIONS="ansible_ssh_user=${INSTANCE_SSH_USER} ansible_ssh_private_key_file=${INSTANCE_SSH_KEY} ansible_ssh_extra_args=${INSTANCE_SSH_EXTRA_ARGS}"

cat <<EOF >"${INVENTORY_FILE}"
[${INSTANCE_HOSTGROUP_NAME}]
${INSTANCE_HOSTNAME} ansible_ssh_host=${INSTANCE_IP_ADDR} ${COMMON_OPTIONS}
EOF

if [[ -f "${INVENTORY_FILE}" ]]; then
  printf "\n\033[1;36m%s\033[m\n\n" "Inventory file for this execution: ${INVENTORY_FILE}."
else
  printf "\n\033[1;31m%s\033[m\n\n" "Cannot find the inventory file ${INVENTORY_FILE}; cannot continue."
  exit 124
fi

#
# Build the logfile for this session
#
LOG_FILE="${LOG_FILE}_${INSTANCE_HOSTNAME}_${ORA_DB_NAME}_${TIMESTAMP}.log"
export ANSIBLE_LOG_PATH=${LOG_FILE}

#
# Trim tailing slashes from variables with paths
#
BACKUP_DEST=${BACKUP_DEST%/}
BACKUP_LOG_LOCATION=${BACKUP_LOG_LOCATION%/}
BACKUP_SCRIPT_LOCATION=${BACKUP_SCRIPT_LOCATION%/}

if [[ -n "$ORA_DB_HOME_DIR" ]]; then
  ORA_DB_HOME_DIR=${ORA_DB_HOME_DIR%/}
fi

# Validate backup destination exists and is writable before proceeding
if [[ -n "${BACKUP_DEST}" ]]; then
  INVENTORY_FILE_BACKUP="${INVENTORY_FILE}_backup_check_${TIMESTAMP}"
  COMMON_OPTIONS="ansible_ssh_user=${INSTANCE_SSH_USER} ansible_ssh_private_key_file=${INSTANCE_SSH_KEY} ansible_ssh_extra_args=${INSTANCE_SSH_EXTRA_ARGS}"
  
  cat <<EOF >"${INVENTORY_FILE_BACKUP}"
[${INSTANCE_HOSTGROUP_NAME}]
${INSTANCE_HOSTNAME} ansible_ssh_host=${INSTANCE_IP_ADDR} ${COMMON_OPTIONS}
EOF

  # Check backup destination
  printf "\n\033[1;36m%s\033[m\n\n" "Checking backup destination: ${BACKUP_DEST}"
  
  # Handle backup destination based on its type
  if [[ "${BACKUP_DEST:0:1}" == "/" ]]; then
    # Filesystem destination
    printf "\n\033[1;36m%s\033[m\n\n" "Filesystem path specified for backup: ${BACKUP_DEST}"
    
    ANSIBLE_COMMAND="ansible ${INSTANCE_HOSTGROUP_NAME} -i ${INVENTORY_FILE_BACKUP} -m shell -a 'if [ -d \"${BACKUP_DEST}\" ]; then echo \"EXISTS\"; else echo \"NOT_EXISTS\"; fi'"
    BACKUP_DIR_CHECK=$(eval "${ANSIBLE_COMMAND}" | grep -v "CHANGED" | grep -v "SUCCESS" | grep -v "^$")
    
    if [[ "${BACKUP_DIR_CHECK}" == *"NOT_EXISTS"* ]]; then
      printf "\n\033[1;33m%s\033[m\n\n" "Warning: Backup destination ${BACKUP_DEST} does not exist. Attempting to create it."
      ANSIBLE_COMMAND="ansible ${INSTANCE_HOSTGROUP_NAME} -i ${INVENTORY_FILE_BACKUP} -m file -a 'path=${BACKUP_DEST} state=directory owner=oracle group=oinstall mode=0755' -b"
      eval "${ANSIBLE_COMMAND}" > /dev/null
      
      if [ $? -ne 0 ]; then
        printf "\n\033[1;31m%s\033[m\n\n" "Failed to create backup destination directory ${BACKUP_DEST}. Please check permissions and path."
        exit 1
      else
        printf "\n\033[1;36m%s\033[m\n\n" "Successfully created backup destination directory ${BACKUP_DEST}."
      fi
    fi
  elif [[ "${BACKUP_DEST:0:1}" == "+" ]]; then
    # ASM destination with + prefix
    printf "\n\033[1;36m%s\033[m\n\n" "ASM disk group specified for backup: ${BACKUP_DEST}"
    
    # Verify the ASM disk group exists
    ANSIBLE_COMMAND="ansible ${INSTANCE_HOSTGROUP_NAME} -i ${INVENTORY_FILE_BACKUP} -m shell -a 'export ORACLE_HOME={{ oracle_home }}; export ORACLE_SID=+ASM; echo \"set heading off\\nset feedback off\\nselect name from v\\\$asm_diskgroup where name=UPPER(\\\"${BACKUP_DEST:1}\\\");\\nexit;\" | $ORACLE_HOME/bin/sqlplus -s / as sysasm || echo \"ASM_NOT_RUNNING\"' -b --become-user=grid"
    DISKGROUP_CHECK=$(eval "${ANSIBLE_COMMAND}" 2>/dev/null | grep -v "CHANGED" | grep -v "SUCCESS" | grep -v "^$" || echo "ASM_ERROR")
    
    if [[ "${DISKGROUP_CHECK}" == *"ASM_NOT_RUNNING"* || "${DISKGROUP_CHECK}" == *"ASM_ERROR"* ]]; then
      printf "\n\033[1;33m%s\033[m\n\n" "Warning: Could not verify ASM disk group ${BACKUP_DEST}. ASM may not be running or not accessible."
      printf "\n\033[1;33m%s\033[m\n\n" "Please ensure the disk group exists before running backups."
    elif [[ -z "${DISKGROUP_CHECK}" ]]; then
      printf "\n\033[1;33m%s\033[m\n\n" "Warning: ASM disk group ${BACKUP_DEST:1} does not appear to exist."
      printf "\n\033[1;33m%s\033[m\n\n" "Please ensure the disk group exists before running backups."
    else
      printf "\n\033[1;36m%s\033[m\n\n" "ASM disk group ${BACKUP_DEST:1} verified."
    fi
  else
    # ASM destination without + prefix
    printf "\n\033[1;36m%s\033[m\n\n" "ASM disk group specified for backup: ${BACKUP_DEST} (will be used as +${BACKUP_DEST})"
    
    # Verify the ASM disk group exists
    ANSIBLE_COMMAND="ansible ${INSTANCE_HOSTGROUP_NAME} -i ${INVENTORY_FILE_BACKUP} -m shell -a 'export ORACLE_HOME={{ oracle_home }}; export ORACLE_SID=+ASM; echo \"set heading off\\nset feedback off\\nselect name from v\\\$asm_diskgroup where name=UPPER(\\\"${BACKUP_DEST}\\\");\\nexit;\" | $ORACLE_HOME/bin/sqlplus -s / as sysasm || echo \"ASM_NOT_RUNNING\"' -b --become-user=grid"
    DISKGROUP_CHECK=$(eval "${ANSIBLE_COMMAND}" 2>/dev/null | grep -v "CHANGED" | grep -v "SUCCESS" | grep -v "^$" || echo "ASM_ERROR")
    
    if [[ "${DISKGROUP_CHECK}" == *"ASM_NOT_RUNNING"* || "${DISKGROUP_CHECK}" == *"ASM_ERROR"* ]]; then
      printf "\n\033[1;33m%s\033[m\n\n" "Warning: Could not verify ASM disk group ${BACKUP_DEST}. ASM may not be running or not accessible."
      printf "\n\033[1;33m%s\033[m\n\n" "Please ensure the disk group exists before running backups."
    elif [[ -z "${DISKGROUP_CHECK}" ]]; then
      printf "\n\033[1;33m%s\033[m\n\n" "Warning: ASM disk group ${BACKUP_DEST} does not appear to exist."
      printf "\n\033[1;33m%s\033[m\n\n" "Please ensure the disk group exists before running backups."
    else
      printf "\n\033[1;36m%s\033[m\n\n" "ASM disk group ${BACKUP_DEST} verified."
    fi
  fi
  
  # Check RECO destination
  printf "\n\033[1;36m%s\033[m\n\n" "Checking recovery area destination: ${ORA_RECO_DESTINATION}"
  
  # Handle recovery area destination based on its type
  if [[ "${ORA_RECO_DESTINATION:0:1}" == "/" ]]; then
    # Filesystem destination
    printf "\n\033[1;36m%s\033[m\n\n" "Filesystem path specified for recovery area: ${ORA_RECO_DESTINATION}"
    
    ANSIBLE_COMMAND="ansible ${INSTANCE_HOSTGROUP_NAME} -i ${INVENTORY_FILE_BACKUP} -m shell -a 'if [ -d \"${ORA_RECO_DESTINATION}\" ]; then echo \"EXISTS\"; else echo \"NOT_EXISTS\"; fi'"
    RECO_DIR_CHECK=$(eval "${ANSIBLE_COMMAND}" | grep -v "CHANGED" | grep -v "SUCCESS" | grep -v "^$")
    
    if [[ "${RECO_DIR_CHECK}" == *"NOT_EXISTS"* ]]; then
      printf "\n\033[1;33m%s\033[m\n\n" "Warning: Recovery area destination ${ORA_RECO_DESTINATION} does not exist. Attempting to create it."
      ANSIBLE_COMMAND="ansible ${INSTANCE_HOSTGROUP_NAME} -i ${INVENTORY_FILE_BACKUP} -m file -a 'path=${ORA_RECO_DESTINATION} state=directory owner=oracle group=oinstall mode=0755' -b"
      eval "${ANSIBLE_COMMAND}" > /dev/null
      
      if [ $? -ne 0 ]; then
        printf "\n\033[1;31m%s\033[m\n\n" "Failed to create recovery area directory ${ORA_RECO_DESTINATION}. Please check permissions and path."
        exit 1
      else
        printf "\n\033[1;36m%s\033[m\n\n" "Successfully created recovery area directory ${ORA_RECO_DESTINATION}."
      fi
    fi
  elif [[ "${ORA_RECO_DESTINATION:0:1}" == "+" ]]; then
    # ASM destination with + prefix
    printf "\n\033[1;36m%s\033[m\n\n" "ASM disk group specified for recovery area: ${ORA_RECO_DESTINATION}"
    
    # Verify the ASM disk group exists
    ANSIBLE_COMMAND="ansible ${INSTANCE_HOSTGROUP_NAME} -i ${INVENTORY_FILE_BACKUP} -m shell -a 'export ORACLE_HOME={{ oracle_home }}; export ORACLE_SID=+ASM; echo \"set heading off\\nset feedback off\\nselect name from v\\\$asm_diskgroup where name=UPPER(\\\"${ORA_RECO_DESTINATION:1}\\\");\\nexit;\" | $ORACLE_HOME/bin/sqlplus -s / as sysasm || echo \"ASM_NOT_RUNNING\"' -b --become-user=grid"
    DISKGROUP_CHECK=$(eval "${ANSIBLE_COMMAND}" 2>/dev/null | grep -v "CHANGED" | grep -v "SUCCESS" | grep -v "^$" || echo "ASM_ERROR")
    
    if [[ "${DISKGROUP_CHECK}" == *"ASM_NOT_RUNNING"* || "${DISKGROUP_CHECK}" == *"ASM_ERROR"* ]]; then
      printf "\n\033[1;33m%s\033[m\n\n" "Warning: Could not verify ASM disk group ${ORA_RECO_DESTINATION}. ASM may not be running or not accessible."
      printf "\n\033[1;33m%s\033[m\n\n" "Please ensure the disk group exists before proceeding."
    elif [[ -z "${DISKGROUP_CHECK}" ]]; then
      printf "\n\033[1;33m%s\033[m\n\n" "Warning: ASM disk group ${ORA_RECO_DESTINATION:1} does not appear to exist."
      printf "\n\033[1;33m%s\033[m\n\n" "Please ensure the disk group exists before proceeding."
    else
      printf "\n\033[1;36m%s\033[m\n\n" "ASM disk group ${ORA_RECO_DESTINATION:1} verified."
    fi
  else
    # ASM destination without + prefix
    printf "\n\033[1;36m%s\033[m\n\n" "ASM disk group specified for recovery area: ${ORA_RECO_DESTINATION} (will be used as +${ORA_RECO_DESTINATION})"
    
    # Verify the ASM disk group exists
    ANSIBLE_COMMAND="ansible ${INSTANCE_HOSTGROUP_NAME} -i ${INVENTORY_FILE_BACKUP} -m shell -a 'export ORACLE_HOME={{ oracle_home }}; export ORACLE_SID=+ASM; echo \"set heading off\\nset feedback off\\nselect name from v\\\$asm_diskgroup where name=UPPER(\\\"${ORA_RECO_DESTINATION}\\\");\\nexit;\" | $ORACLE_HOME/bin/sqlplus -s / as sysasm || echo \"ASM_NOT_RUNNING\"' -b --become-user=grid"
    DISKGROUP_CHECK=$(eval "${ANSIBLE_COMMAND}" 2>/dev/null | grep -v "CHANGED" | grep -v "SUCCESS" | grep -v "^$" || echo "ASM_ERROR")
    
    if [[ "${DISKGROUP_CHECK}" == *"ASM_NOT_RUNNING"* || "${DISKGROUP_CHECK}" == *"ASM_ERROR"* ]]; then
      printf "\n\033[1;33m%s\033[m\n\n" "Warning: Could not verify ASM disk group ${ORA_RECO_DESTINATION}. ASM may not be running or not accessible."
      printf "\n\033[1;33m%s\033[m\n\n" "Please ensure the disk group exists before proceeding."
    elif [[ -z "${DISKGROUP_CHECK}" ]]; then
      printf "\n\033[1;33m%s\033[m\n\n" "Warning: ASM disk group ${ORA_RECO_DESTINATION} does not appear to exist."
      printf "\n\033[1;33m%s\033[m\n\n" "Please ensure the disk group exists before proceeding."
    else
      printf "\n\033[1;36m%s\033[m\n\n" "ASM disk group ${ORA_RECO_DESTINATION} verified."
    fi
  fi
  
  # Check if oracle user can write to the backup destination if it's a filesystem path
  if [[ "${BACKUP_DEST:0:1}" == "/" ]]; then
    ANSIBLE_COMMAND="ansible ${INSTANCE_HOSTGROUP_NAME} -i ${INVENTORY_FILE_BACKUP} -m shell -a 'touch ${BACKUP_DEST}/test_$RANDOM; if [ $? -eq 0 ]; then rm ${BACKUP_DEST}/test_$RANDOM; echo \"WRITABLE\"; else echo \"NOT_WRITABLE\"; fi' -b --become-user=oracle"
    BACKUP_DIR_WRITABLE=$(eval "${ANSIBLE_COMMAND}" | grep -v "CHANGED" | grep -v "SUCCESS" | grep -v "^$")
    
    if [[ "${BACKUP_DIR_WRITABLE}" == *"NOT_WRITABLE"* ]]; then
      printf "\n\033[1;31m%s\033[m\n\n" "Backup destination ${BACKUP_DEST} is not writable by the Oracle user. Please check permissions."
      exit 1
    fi
  fi
  
  # Check if oracle user can write to the RECO destination if it's a filesystem path
  if [[ "${ORA_RECO_DESTINATION:0:1}" == "/" ]]; then
    ANSIBLE_COMMAND="ansible ${INSTANCE_HOSTGROUP_NAME} -i ${INVENTORY_FILE_BACKUP} -m shell -a 'touch ${ORA_RECO_DESTINATION}/test_$RANDOM; if [ $? -eq 0 ]; then rm ${ORA_RECO_DESTINATION}/test_$RANDOM; echo \"WRITABLE\"; else echo \"NOT_WRITABLE\"; fi' -b --become-user=oracle"
    RECO_DIR_WRITABLE=$(eval "${ANSIBLE_COMMAND}" | grep -v "CHANGED" | grep -v "SUCCESS" | grep -v "^$")
    
    if [[ "${RECO_DIR_WRITABLE}" == *"NOT_WRITABLE"* ]]; then
      printf "\n\033[1;31m%s\033[m\n\n" "Recovery area destination ${ORA_RECO_DESTINATION} is not writable by the Oracle user. Please check permissions."
      exit 1
    fi
  fi
  
  # Clean up temporary inventory file
  rm -f "${INVENTORY_FILE_BACKUP}"
fi

# Validate memory settings
if [[ -n "${SGA_TARGET}" ]]; then
  # Extract numeric value and unit
  SGA_SIZE=$(echo "${SGA_TARGET}" | grep -o '[0-9]\+')
  SGA_UNIT=$(echo "${SGA_TARGET}" | grep -o '[MG%]')
  
  # Check if SGA size is too small (less than 500M)
  if [[ "${SGA_UNIT}" == "M" && ${SGA_SIZE} -lt 500 ]]; then
    printf "\n\033[1;33m%s\033[m\n\n" "Warning: SGA_TARGET value ${SGA_TARGET} is very small. Oracle recommends at least 500M for production databases."
  elif [[ "${SGA_UNIT}" == "G" && ${SGA_SIZE} -lt 1 ]]; then
    printf "\n\033[1;33m%s\033[m\n\n" "Warning: SGA_TARGET value ${SGA_TARGET} is very small. Oracle recommends at least 1G for production databases."
  fi
  
  # Convert to GB for calculations - M to GB divide by 1024, G stays as is
  if [[ "${SGA_UNIT}" == "M" ]]; then
    # Calculate with simple bash arithmetic (integer division, less precise but doesn't require bc)
    SGA_SIZE_GB=$(( ${SGA_SIZE} / 1024 ))
    # Add decimal part for better accuracy
    if [[ ${SGA_SIZE} -lt 1024 ]]; then
      SGA_SIZE_GB="0.$(( (${SGA_SIZE} * 100) / 1024 ))"
    fi
  elif [[ "${SGA_UNIT}" == "G" ]]; then
    SGA_SIZE_GB=${SGA_SIZE}
  else
    SGA_SIZE_GB=2 # Default value for percentage or unrecognized units
  fi
fi

if [[ -n "${PGA_AGGREGATE_TARGET}" ]]; then
  # Extract numeric value and unit
  PGA_SIZE=$(echo "${PGA_AGGREGATE_TARGET}" | grep -o '[0-9]\+')
  PGA_UNIT=$(echo "${PGA_AGGREGATE_TARGET}" | grep -o '[MG%]')
  
  # Check if PGA size is too small (less than 150M)
  if [[ "${PGA_UNIT}" == "M" && ${PGA_SIZE} -lt 150 ]]; then
    printf "\n\033[1;33m%s\033[m\n\n" "Warning: PGA_AGGREGATE_TARGET value ${PGA_AGGREGATE_TARGET} is very small. Oracle recommends at least 150M."
  elif [[ "${PGA_UNIT}" == "G" && ${PGA_SIZE} -lt 1 ]]; then
    printf "\n\033[1;33m%s\033[m\n\n" "Warning: PGA_AGGREGATE_TARGET value ${PGA_AGGREGATE_TARGET} is very small."
  fi
  
  # Convert to GB for calculations - M to GB divide by 1024, G stays as is
  if [[ "${PGA_UNIT}" == "M" ]]; then
    # Calculate with simple bash arithmetic (integer division, less precise but doesn't require bc)
    PGA_SIZE_GB=$(( ${PGA_SIZE} / 1024 ))
    # Add decimal part for better accuracy
    if [[ ${PGA_SIZE} -lt 1024 ]]; then
      PGA_SIZE_GB="0.$(( (${PGA_SIZE} * 100) / 1024 ))"
    fi
  elif [[ "${PGA_UNIT}" == "G" ]]; then
    PGA_SIZE_GB=${PGA_SIZE}
  else
    PGA_SIZE_GB="0.5" # Default value for percentage or unrecognized units
  fi
fi

# Calculate total required memory in GB using pure bash
# First, ensure the variables are defined with defaults
SGA_SIZE_GB=${SGA_SIZE_GB:-2}
PGA_SIZE_GB=${PGA_SIZE_GB:-0.5}

# Convert to integers with 2 decimal places (multiply by 100)
SGA_INT=$(echo $SGA_SIZE_GB | awk '{printf "%.0f", $1*100}')
PGA_INT=$(echo $PGA_SIZE_GB | awk '{printf "%.0f", $1*100}')

# Add the integers and convert back to decimal
TOTAL_INT=$((SGA_INT + PGA_INT))
REQUIRED_MEMORY_GB=$(echo $TOTAL_INT | awk '{printf "%.1f", $1/100}')

# Validate memory against target machine early
if [[ -n "${INSTANCE_IP_ADDR}" ]]; then
  INVENTORY_FILE_RAM="${INVENTORY_FILE}_ram_check_${TIMESTAMP}"
  COMMON_OPTIONS="ansible_ssh_user=${INSTANCE_SSH_USER} ansible_ssh_private_key_file=${INSTANCE_SSH_KEY} ansible_ssh_extra_args=${INSTANCE_SSH_EXTRA_ARGS}"
  
  cat <<EOF >"${INVENTORY_FILE_RAM}"
[${INSTANCE_HOSTGROUP_NAME}]
${INSTANCE_HOSTNAME} ansible_ssh_host=${INSTANCE_IP_ADDR} ${COMMON_OPTIONS}
EOF

  printf "\n\033[1;36m%s\033[m\n\n" "Checking available RAM on target system..."
  
  # Check both total and available memory
  ANSIBLE_COMMAND="ansible ${INSTANCE_HOSTGROUP_NAME} -i ${INVENTORY_FILE_RAM} -m shell -a 'free -g | grep Mem | awk \"{print \\\$2, \\\$4}\"'"
  MEMORY_CHECK=$(eval "${ANSIBLE_COMMAND}" | grep -v "CHANGED" | grep -v "SUCCESS" | grep -v "^$")
  
  if [[ -n "${MEMORY_CHECK}" && "${MEMORY_CHECK}" =~ [0-9]+[[:space:]][0-9]+ ]]; then
    TOTAL_MEMORY_GB=$(echo ${MEMORY_CHECK} | awk '{print $1}')
    AVAILABLE_MEMORY_GB=$(echo ${MEMORY_CHECK} | awk '{print $2}')
    
    printf "\n\033[1;36m%s\033[m\n\n" "Memory check results:"
    printf "\n\033[1;36m%s\033[m\n\n" "Total system memory: ${TOTAL_MEMORY_GB}GB"
    printf "\n\033[1;36m%s\033[m\n\n" "Available memory: ${AVAILABLE_MEMORY_GB}GB"
    printf "\n\033[1;36m%s\033[m\n\n" "Required memory (SGA + PGA): ${REQUIRED_MEMORY_GB}GB"
    
    # Check if available memory is sufficient - convert to integer for comparison
    REQUIRED_INT=$(echo $REQUIRED_MEMORY_GB | awk '{printf "%.0f", $1}')
    if (( AVAILABLE_MEMORY_GB < REQUIRED_INT )); then
      printf "\n\033[1;31m%s\033[m\n\n" "ERROR: Not enough available memory on the target system."
      printf "\n\033[1;31m%s\033[m\n\n" "Required memory (SGA + PGA): ${REQUIRED_MEMORY_GB}GB"
      printf "\n\033[1;31m%s\033[m\n\n" "Available memory: ${AVAILABLE_MEMORY_GB}GB"
      printf "\n\033[1;31m%s\033[m\n\n" "Please reduce SGA_TARGET and/or PGA_AGGREGATE_TARGET values to fit within available memory or free up memory on the target system."
      rm -f "${INVENTORY_FILE_RAM}"
      exit 1
    fi
  else
    printf "\n\033[1;33m%s\033[m\n\n" "Warning: Could not determine available memory on target system. Will continue, but may encounter memory issues during database creation."
  fi
  
  # Check for database existence early
  printf "\n\033[1;36m%s\033[m\n\n" "Checking if database ${ORA_DB_NAME} already exists on target system..."
  
  # Check oratab for database
  ANSIBLE_COMMAND="ansible ${INSTANCE_HOSTGROUP_NAME} -i ${INVENTORY_FILE_RAM} -m shell -a 'grep -i \"${ORA_DB_NAME}:\" /etc/oratab || echo \"NOT_FOUND\"'"
  DB_ORATAB=$(eval "${ANSIBLE_COMMAND}" | grep -v "CHANGED" | grep -v "SUCCESS" | grep -v "^$")
  
  # Check for running process
  ANSIBLE_COMMAND="ansible ${INSTANCE_HOSTGROUP_NAME} -i ${INVENTORY_FILE_RAM} -m shell -a 'ps -ef | grep pmon | grep -i ${ORA_DB_NAME} | grep -v grep || echo \"NOT_FOUND\"'"
  DB_RUNNING=$(eval "${ANSIBLE_COMMAND}" | grep -v "CHANGED" | grep -v "SUCCESS" | grep -v "^$")
  
  if [[ "${DB_ORATAB}" != *"NOT_FOUND"* ]]; then
    printf "\n\033[1;31m%s\033[m\n\n" "ERROR: A database with name ${ORA_DB_NAME} is already registered in /etc/oratab on the target system."
    printf "\n\033[1;31m%s\033[m\n\n" "Please choose a different database name or remove the existing database."
    rm -f "${INVENTORY_FILE_RAM}"
    exit 1
  fi
  
  if [[ "${DB_RUNNING}" != *"NOT_FOUND"* ]]; then
    printf "\n\033[1;31m%s\033[m\n\n" "ERROR: A database process with name ${ORA_DB_NAME} is already running on the target system."
    printf "\n\033[1;31m%s\033[m\n\n" "Please choose a different database name or stop the existing database."
    rm -f "${INVENTORY_FILE_RAM}"
    exit 1
  fi
  
  printf "\n\033[1;36m%s\033[m\n\n" "Database existence check passed. No database named ${ORA_DB_NAME} exists on the target system."
  rm -f "${INVENTORY_FILE_RAM}"
fi

# Set appropriate DB container flag for Ansible
if [[ "${ORA_DB_CONTAINER}" == "TRUE" ]]; then
  DB_CONTAINER_FLAG="true"
else
  DB_CONTAINER_FLAG="false"
fi

# Ensure swlib_unzip_path is set - fallback to temp directory if not specified
if [[ -z "${ORA_STAGING}" ]]; then
  ORA_STAGING="/tmp/oracle_swlib"
  printf "\n\033[1;33m%s\033[m\n\n" "Warning: ORA_STAGING not set. Using temporary directory ${ORA_STAGING} for staging files."
  # Create the staging directory if it doesn't exist
  mkdir -p "${ORA_STAGING}" 2>/dev/null
fi

# Export all variables including those for Ansible mappings
export ARCHIVE_BACKUP_MIN
export ARCHIVE_ONLINE_DAYS
export ARCHIVE_REDUNDANCY
export BACKUP_DEST
export BACKUP_LEVEL0_DAYS
export BACKUP_LEVEL1_DAYS
export BACKUP_LOG_LOCATION
export BACKUP_REDUNDANCY
export BACKUP_START_HOUR
export BACKUP_START_MIN
export BACKUP_SCRIPT_LOCATION
export DB_CONTAINER_FLAG
export INSTANCE_IP_ADDR
export ORA_DATA_DESTINATION
export ORA_DB_CHARSET
export ORA_DB_CONTAINER
export ORA_DB_DOMAIN
export ORA_DB_NAME
export ORA_DB_NCHARSET
export ORA_DB_TYPE
export ORA_DB_HOME_DIR
export ORA_LISTENER_NAME
export ORA_LISTENER_PORT
export ORA_PDB_COUNT
export ORA_PDB_NAME_PREFIX
export ORA_RECO_DESTINATION
export ORA_REDO_LOG_SIZE
export ORA_STAGING
export ORA_VERSION
export PB_LIST
export SGA_TARGET
export PGA_AGGREGATE_TARGET
export MEMORY_PERCENT
export CALLING_SCRIPT="add-database.sh"
# Export the standard Ansible variable names for clarity
export container_db="${DB_CONTAINER_FLAG}"
export pdb_prefix="${ORA_PDB_NAME_PREFIX}"
export db_name="${ORA_DB_NAME}"
export db_domain="${ORA_DB_DOMAIN}"
export scripts_dir="${BACKUP_SCRIPT_LOCATION}"
export logs_dir="${BACKUP_LOG_LOCATION}"
export swlib_unzip_path="${ORA_STAGING}"

# CREATE_LISTENER will be determined by playbook based on whether a listener exists
# We don't set it here, allowing the playbook to decide whether to create one or not
export CREATE_LISTENER=auto

# Always create database
export CREATE_DB=true

echo -e "Running with parameters from command line or environment variables:\n"
set | grep -E '^(ORA_|BACKUP_|ARCHIVE_|INSTANCE_|PB_|ANSIBLE_|CREATE_|SGA_|PGA_|MEMORY_)' | grep -v '_PARAM='
echo

# Display a validation summary before proceeding
printf "\n\033[1;36m%s\033[m\n" "======= PRE-FLIGHT VALIDATION SUMMARY ======="
printf "\033[1;36m%s\033[m\n" "Database Name: ${ORA_DB_NAME}"
printf "\033[1;36m%s\033[m\n" "Target System: ${INSTANCE_IP_ADDR} (${INSTANCE_HOSTNAME})"

if [[ -n "$ORA_DB_HOME_DIR" ]]; then
  printf "\033[1;36m%s\033[m\n" "Oracle Home: ${ORA_DB_HOME_DIR}"
else
  printf "\033[1;33m%s\033[m\n" "Oracle Home: Auto-detect (will be determined during execution)"
fi

printf "\033[1;36m%s\033[m\n" "Memory Settings:"
printf "\033[1;36m%s\033[m\n" "  - SGA Target: ${SGA_TARGET}"
printf "\033[1;36m%s\033[m\n" "  - PGA Aggregate Target: ${PGA_AGGREGATE_TARGET}"
printf "\033[1;36m%s\033[m\n" "  - Required Memory: ${REQUIRED_MEMORY_GB}GB"

printf "\033[1;36m%s\033[m\n" "Container Database: ${ORA_DB_CONTAINER}"
if [[ "${ORA_DB_CONTAINER}" == "TRUE" ]]; then
  printf "\033[1;36m%s\033[m\n" "  - PDB Count: ${ORA_PDB_COUNT}"
  printf "\033[1;36m%s\033[m\n" "  - PDB Prefix: ${ORA_PDB_NAME_PREFIX}"
fi

if [[ -n "${BACKUP_DEST}" ]]; then
  printf "\033[1;36m%s\033[m\n" "Backup Configuration:"
  printf "\033[1;36m%s\033[m\n" "  - Backup Destination: ${BACKUP_DEST}"
  printf "\033[1;36m%s\033[m\n" "  - Backup Redundancy: ${BACKUP_REDUNDANCY}"
  printf "\033[1;36m%s\033[m\n" "  - Archive Redundancy: ${ARCHIVE_REDUNDANCY}"
fi

printf "\033[1;36m%s\033[m\n\n" "============================================="

ANSIBLE_PARAMS="-i ${INVENTORY_FILE} ${ANSIBLE_PARAMS}"
ANSIBLE_CMDLINE_PARAMS="${*}"

# Build extra parameters with proper escaping
build_extra_param() {
  local param_name="$1"
  local param_value="$2"
  
  if [[ -n "$param_value" ]]; then
    # Properly escape the value for Ansible
    param_value=$(printf '%s' "$param_value" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')
    echo "-e $param_name=\"$param_value\""
  else
    echo ""
  fi
}

# Reset the extra params
ANSIBLE_EXTRA_PARAMS=""

# Add all required parameters with proper escaping
if [[ -n "$ORA_DB_HOME_DIR" ]]; then
  ANSIBLE_EXTRA_PARAMS="${ANSIBLE_EXTRA_PARAMS} $(build_extra_param "oracle_home" "${ORA_DB_HOME_DIR}")"
fi

if [[ -n "$SGA_TARGET" ]]; then
  ANSIBLE_EXTRA_PARAMS="${ANSIBLE_EXTRA_PARAMS} $(build_extra_param "sga_target" "${SGA_TARGET}")"
fi

if [[ -n "$PGA_AGGREGATE_TARGET" ]]; then
  ANSIBLE_EXTRA_PARAMS="${ANSIBLE_EXTRA_PARAMS} $(build_extra_param "pga_aggtar" "${PGA_AGGREGATE_TARGET}")"
fi

if [[ -n "$MEMORY_PERCENT" ]]; then
  ANSIBLE_EXTRA_PARAMS="${ANSIBLE_EXTRA_PARAMS} $(build_extra_param "memory_pct" "${MEMORY_PERCENT}")"
fi

# Add container database flag
ANSIBLE_EXTRA_PARAMS="${ANSIBLE_EXTRA_PARAMS} $(build_extra_param "db_container_flag" "${DB_CONTAINER_FLAG}")"

# Add database name and domain
ANSIBLE_EXTRA_PARAMS="${ANSIBLE_EXTRA_PARAMS} $(build_extra_param "db_name" "${ORA_DB_NAME}")"
ANSIBLE_EXTRA_PARAMS="${ANSIBLE_EXTRA_PARAMS} $(build_extra_param "db_domain" "${ORA_DB_DOMAIN}")"

# Add backup directories
if [[ -n "$BACKUP_SCRIPT_LOCATION" ]]; then
  ANSIBLE_EXTRA_PARAMS="${ANSIBLE_EXTRA_PARAMS} $(build_extra_param "scripts_dir" "${BACKUP_SCRIPT_LOCATION}")"
fi

if [[ -n "$BACKUP_LOG_LOCATION" ]]; then
  ANSIBLE_EXTRA_PARAMS="${ANSIBLE_EXTRA_PARAMS} $(build_extra_param "logs_dir" "${BACKUP_LOG_LOCATION}")"
fi

# Add software library path
ANSIBLE_EXTRA_PARAMS="${ANSIBLE_EXTRA_PARAMS} $(build_extra_param "swlib_unzip_path" "${ORA_STAGING}")"

echo "Ansible params: ${ANSIBLE_EXTRA_PARAMS}"

if [ $VALIDATE -eq 1 ]; then
  echo "Exiting because of --validate"
  exit
fi

export ANSIBLE_NOCOWS=1

ANSIBLE_PLAYBOOK="ansible-playbook"
if ! type ansible-playbook >/dev/null 2>&1; then
  echo "Ansible executable not found in path"
  exit 3
else
  echo "Found Ansible: $(type ansible-playbook)"
fi

# exit on any error from the following scripts
set -e

for PLAYBOOK in ${PB_LIST}; do
  ANSIBLE_COMMAND="${ANSIBLE_PLAYBOOK} ${ANSIBLE_PARAMS} ${ANSIBLE_CMDLINE_PARAMS} ${ANSIBLE_EXTRA_PARAMS} ${PLAYBOOK}"
  echo
  echo "Running Ansible playbook: ${ANSIBLE_COMMAND}"
  eval "${ANSIBLE_COMMAND}"
done

#
# Function to cleanup all temporary files
#
cleanup_temp_files() {
  # Store any temporary inventory files created during the run
  local temp_files=()
  temp_files+=("${INVENTORY_FILE_CHECK:-}")
  temp_files+=("${INVENTORY_FILE_MEM:-}")
  temp_files+=("${INVENTORY_FILE_BACKUP:-}")
  temp_files+=("${INVENTORY_FILE_RAM:-}")
  
  # Clean up temporary files
  for file in "${temp_files[@]}"; do
    if [[ -n "${file}" && -f "${file}" ]]; then
      rm -f "${file}"
    fi
  done
  
  # Also clean up any temporary files that match our naming pattern
  # This ensures we don't leave any files behind even if the script is interrupted
  find "${INVENTORY_DIR}" -name "inventory_*_${TIMESTAMP}*" -type f -delete 2>/dev/null || true
}

#
# Run cleanup before exit
#
cleanup_temp_files

#
# Show the files used by this session
#
printf "\n\033[1;36m%s\033[m\n" "Files used by this session:"
for FILE in "${INVENTORY_FILE}" "${LOG_FILE}"; do
  if [[ -f "${FILE}" ]]; then
    printf "\t\033[1;36m- %s\033[m\n" "${FILE}"
  fi
done
printf "\n"

exit 0