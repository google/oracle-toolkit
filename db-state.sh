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

echo Command used:
echo "$0 $@"
echo

TIMESTAMP="$(date +%Y%m%d_%H%M%S)"

#
# Ansible logs directory, the log file name is created later one
#
LOG_DIR="./logs"
LOG_FILE="${LOG_DIR}/patch"
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

ORA_DB_NAME="${ORA_DB_NAME:-ORCL}"
ORA_DB_NAME_PARAM="^[a-zA-Z0-9_$]+$"

#
# The default inventory file
#
INVENTORY_FILE="${INVENTORY_FILE:-./inventory_files/inventory}"

#
# Build the log file for this session
#
LOG_FILE="${LOG_FILE}_${ORA_DB_NAME}_${TIMESTAMP}.log"
export ANSIBLE_LOG_PATH=${LOG_FILE}

# Suppress displaying hosts if a "when" condition isn't satisfied, to reduce overall output file size.
export ANSIBLE_DISPLAY_SKIPPED_HOSTS=false
###
GETOPT_MANDATORY="inventory-file:"
GETOPT_OPTIONAL="ora-db-name:,start-database,stop-database,enable-backup-mode,disable-backup-mode,enable-autostart,disable-autostart"
GETOPT_OPTIONAL="$GETOPT_OPTIONAL,help,validate"
GETOPT_LONG="$GETOPT_MANDATORY,$GETOPT_OPTIONAL"
GETOPT_SHORT="h"

ORA_BACKUP_MODE=""
ORA_DB_STATE=""
ORA_START_OPTION=""
VALIDATE=0

options="$(getopt --longoptions "$GETOPT_LONG" --options "$GETOPT_SHORT" -- "$@")"

[ $? -eq 0 ] || {
  echo "Invalid options provided: $@" >&2
  exit 1
}

eval set -- "$options"

while true; do
  case "$1" in
  --inventory-file)
    INVENTORY_FILE="$2"
    shift
    ;;
  --ora-db-name)
    ORA_DB_NAME="$2"
    shift
    ;;
  --start-database)
    ORA_DB_STATE=started
    ;;
  --stop-database)
    ORA_DB_STATE=shutdown
    ;;
  --enable-backup-mode)
    ORA_BACKUP_MODE=enabled
    ;;
  --disable-backup-mode)
    ORA_BACKUP_MODE=disabled
    ;;
  --enable-autostart)
    ORA_START_OPTION=automatic
    ;;
  --disable-autostart)
    ORA_START_OPTION=manual
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
# Variables verification
#
[[ ! "$ORA_DB_NAME" =~ $ORA_DB_NAME_PARAM ]] && {
  echo "Incorrect parameter provided for ora-db-name: $ORA_DB_NAME"
  exit 1
}
[[ -n "$ORA_DB_STATE" && "$ORA_DB_STATE" != "started" && "$ORA_DB_STATE" != "shutdown" ]] && {
  echo "Incorrect parameter provided for database state: $ORA_DB_STATE"
  exit 1
}
[[ -n "$ORA_BACKUP_MODE" && "$ORA_BACKUP_MODE" != "enabled" && "$ORA_BACKUP_MODE" != "disabled" ]] && {
  echo "Incorrect parameter provided for backup mode: $ORA_BACKUP_MODE"
  exit 1
}
[[ -n "$ORA_START_OPTION" && "$ORA_START_OPTION" != "automatic" && "$ORA_START_OPTION" != "manual" ]] && {
  echo "Incorrect parameter provided for autostart mode: $ORA_START_OPTION"
  exit 1
}
[[ -z "$ORA_DB_STATE" && -z "$ORA_BACKUP_MODE" && -z "$ORA_START_OPTION" ]] && {
  echo "Please specify at least one action: --start-database, --stop-database, --enable-backup-mode, --disable-backup-mode, --enable-autostart, --disable-autostart"
  exit 1
}

# Mandatory options
if [[ ! -s ${INVENTORY_FILE} ]]; then
  echo "Please specify the inventory file using --inventory-file <file_name>"
  exit 2
fi

export ORA_BACKUP_MODE
export ORA_DB_NAME
export ORA_DB_STATE
export ORA_START_OPTION

echo -e "Running with parameters from command line or environment variables:\n"
set | grep -E '^(ORA_)' | grep -v '_PARAM='
echo

ANSIBLE_PARAMS="-i ${INVENTORY_FILE} "
ANSIBLE_PARAMS="${ANSIBLE_PARAMS} $@"

echo "Ansible params: ${ANSIBLE_PARAMS}"

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

echo "Running Ansible playbook: ${ANSIBLE_PLAYBOOK} ${ANSIBLE_PARAMS} db-state.yml"
${ANSIBLE_PLAYBOOK} ${ANSIBLE_PARAMS} db-state.yml

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
