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

# Set calling script name for validation tasks
export CALLING_SCRIPT="cleanup-oracle.sh"

echo Command used:
echo "$0 $@"
echo

GETOPT_MANDATORY="ora-version:,inventory-file:,yes-i-am-sure"
GETOPT_OPTIONAL="ora-edition:,ora-role-separation:,ora-disk-mgmt:,ora-swlib-path:,ora-staging:,ora-asm-disks:,gcs-backup-path:,gcs-backup-temp-path"
GETOPT_OPTIONAL="${GETOPT_OPTIONAL},ora-asm-disks-json:,ora-data-mounts:,ora-data-mounts-json:,help"
GETOPT_LONG="${GETOPT_MANDATORY},${GETOPT_OPTIONAL}"
GETOPT_SHORT="yh"

YESIAMSURE=0
VALIDATE=0
INVENTORY_FILE="${INVENTORY_FILE:-./inventory_files/inventory}"

ORA_VERSION="${ORA_VERSION}"
ORA_VERSION_PARAM='^(23\.[0-9]{1,2}\.[0-9]{1,2}\.[0-9]{1,2}\.[0-9]{1,6}|21\.3\.0\.0\.0|19\.3\.0\.0\.0|18\.0\.0\.0\.0|12\.2\.0\.1\.0|12\.1\.0\.2\.0|11\.2\.0\.4\.0)$'

ORA_EDITION="${ORA_EDITION:-EE}"
ORA_EDITION_PARAM="^(EE|SE|SE2|FREE)$"

ORA_ROLE_SEPARATION="${ORA_ROLE_SEPARATION:-TRUE}"
ORA_ROLE_SEPARATION_PARAM="^(TRUE|FALSE)$"

ORA_DISK_MGMT="${ORA_DISK_MGMT:-UDEV}"
ORA_DISK_MGMT_PARAM="ASMLIB|UDEV"

ORA_SWLIB_PATH="${ORA_SWLIB_PATH:-/u01/swlib}"
ORA_SWLIB_PATH_PARAM="^/.*"

GCS_BACKUP_PATH="${GCS_BACKUP_PATH}"
GCS_BACKUP_PATH_PARAM="^.+[^/]"

GCS_BACKUP_TEMP_PATH="${GCS_BACKUP_TEMP_PATH:-/u01/gcsfusetmp}"
GCS_BACKUP_TEMP_PATH_PARAM="^/.*"

ORA_STAGING="${ORA_STAGING:-""}"
ORA_STAGING_PARAM="^/.+$"

ORA_ASM_DISKS="${ORA_ASM_DISKS:-asm_disk_config.json}"
ORA_ASM_DISKS_PARAM="^.+\.json$"

ORA_ASM_DISKS_JSON="${ORA_ASM_DISKS_JSON}"
ORA_ASM_DISKS_JSON_PARAM="^\[.+diskgroup.+\]$"

ORA_DATA_MOUNTS="${ORA_DATA_MOUNTS:-data_mounts_config.json}"
ORA_DATA_MOUNTS_PARAM="^.+\.json$"

ORA_DATA_MOUNTS_JSON="${ORA_DATA_MOUNTS_JSON}"
ORA_DATA_MOUNTS_JSON_PARAM="^\[.+purpose.+\]$"

options="$(getopt --longoptions "$GETOPT_LONG" --options "$GETOPT_SHORT" -- "$@")"

[ $? -eq 0 ] || {
    echo "Invalid options provided: $@" >&2
    exit 1
}

eval set -- "$options"

while true; do
    case "$1" in
    --yes-i-am-sure | -y)
        YESIAMSURE=1
        ;;
    --ora-version)
        ORA_VERSION="$2"
        if [[ ${ORA_VERSION} = "23" ]]   ; then ORA_VERSION="23.0.0.0.0"; fi
        if [[ ${ORA_VERSION} = "21" ]]   ; then ORA_VERSION="21.3.0.0.0"; fi
        if [[ ${ORA_VERSION} = "19" ]]   ; then ORA_VERSION="19.3.0.0.0"; fi
        if [[ ${ORA_VERSION} = "18" ]]   ; then ORA_VERSION="18.0.0.0.0"; fi
        if [[ ${ORA_VERSION} = "12" ]]   ; then ORA_VERSION="12.2.0.1.0"; fi
        if [[ ${ORA_VERSION} = "12.2" ]] ; then ORA_VERSION="12.2.0.1.0"; fi
        if [[ ${ORA_VERSION} = "12.1" ]] ; then ORA_VERSION="12.1.0.2.0"; fi
        if [[ ${ORA_VERSION} = "11" ]]   ; then ORA_VERSION="11.2.0.4.0"; fi
        shift
        ;;
    --ora-edition)
        ORA_EDITION="$(echo "$2" | tr '[:lower:]' '[:upper:]')"
        shift
        ;;
    --inventory-file)
        INVENTORY_FILE="$2"
        shift
        ;;
    --ora-role-separation)
        ORA_ROLE_SEPARATION="$2"
        shift
        ;;
    --ora-swlib-path)
        ORA_SWLIB_PATH="$2"
        shift
        ;;
    --gcs-backup-path)
        GCS_BACKUP_PATH="$2"
        shift
        ;;
    --gcs-backup-temp-path)
        GCS_BACKUP_TEMP_PATH="$2"
        shift
        ;;
    --ora-staging)
        ORA_STAGING="$2"
        shift
        ;;
    --ora-disk-mgmt)
        ORA_DISK_MGMT="$2"
        shift
        ;;
    --ora-asm-disks)
        ORA_ASM_DISKS="$2"
        shift
        ;;
    --ora-asm-disks-json)
        ORA_ASM_DISKS_JSON="$2"
        shift
        ;;
    --ora-data-mounts)
        ORA_DATA_MOUNTS="$2"
        shift
        ;;
    --ora-data-mounts-json)
        ORA_DATA_MOUNTS_JSON="$2"
        shift
        ;;
    --help | -h)
        echo -e "\tUsage: $(basename $0)" >&2
        echo "${GETOPT_MANDATORY}" | sed 's/,/\n/g' | sed 's/:/ <value>/' | sed 's/\(.\+\)/\t --\1/'
        echo "${GETOPT_OPTIONAL}"  | sed 's/,/\n/g' | sed 's/:/ <value>/' | sed 's/\(.\+\)/\t [ --\1 ]/'
        exit 2
        ;;
    --)
        shift
        break
        ;;
    esac
    shift
done

[[ "$ORA_STAGING" == "" ]] && {
    ORA_STAGING=$ORA_SWLIB_PATH
}

shopt -s nocasematch

# Parameter defaults and changes required for Free Edition
# (including unsupported features such as role_separation)
if [[ "${ORA_EDITION}" = "FREE" ]]; then
    ORA_ROLE_SEPARATION=FALSE
    [[ ! "${ORA_VERSION}" =~ ^23\. ]] && ORA_VERSION="23.0.0.0.0"
fi

# Mandatory options
if [ "${ORA_VERSION}" = "" ]; then
    echo "Please specify the oracle version with --ora-version"
    exit 2
fi

if [[ ! -s ${INVENTORY_FILE} ]]; then
    echo "Please specify the inventory file using --inventory-file <file_name>"
    exit 2
fi

if [ $YESIAMSURE -eq 0 ]; then
    echo "Parameter --yes-i-am-sure needs to be specified for cleanup to run"
    exit 2
fi

[[ ! "$ORA_VERSION" =~ $ORA_VERSION_PARAM ]] && {
    echo "Incorrect parameter provided for ora-version: $ORA_VERSION"
    exit 1
}
[[ ! "$ORA_EDITION" =~ $ORA_EDITION_PARAM ]] && {
    echo "Incorrect parameter provided for ora-edition: $ORA_EDITION"
    exit 1
}
[[ ! "$ORA_ROLE_SEPARATION" =~ $ORA_ROLE_SEPARATION_PARAM ]] && {
    echo "Incorrect parameter provided for ora-role-separation: $ORA_ROLE_SEPARATION"
    exit 1
}
[[ ! "$ORA_SWLIB_PATH" =~ $ORA_SWLIB_PATH_PARAM ]] && {
    echo "Incorrect parameter provided for ora-swlib-path: $ORA_SWLIB_PATH"
    exit 1
}
[[ -n "$GCS_BACKUP_PATH" && ! "$GCS_BACKUP_PATH" =~ $GCS_BACKUP_PATH_PARAM ]] && {
  echo "Incorrect parameter provided for gcs-backup-path: $GCS_BACKUP_PATH"
  exit 1
}
[[ ! "$GCS_BACKUP_TEMP_PATH" =~ $GCS_BACKUP_TEMP_PATH_PARAM ]] && {
  echo "Incorrect parameter provided for gcs-backup-temp-path: $GCS_BACKUP_TEMP_PATH"
  exit 1
}
[[ ! "$ORA_STAGING" =~ $ORA_STAGING_PARAM ]] && {
    echo "Incorrect parameter provided for ora-staging: $ORA_STAGING"
    exit 1
}
[[ ! "$ORA_DISK_MGMT" =~ $ORA_DISK_MGMT_PARAM ]] && {
    echo "Incorrect parameter provided for ora-disk-mgmt: $ORA_DISK_MGMT"
    exit 1
}
[[ ! "$ORA_ASM_DISKS" =~ $ORA_ASM_DISKS_PARAM ]] && {
    echo "Incorrect parameter provided for ora-asm-disks: $ORA_ASM_DISKS"
    exit 1
}
[[ -n "$ORA_ASM_DISKS_JSON" && ! "$ORA_ASM_DISKS_JSON" =~ $ORA_ASM_DISKS_JSON_PARAM ]] && {
    echo "Incorrect parameter provided for ora-asm-disks-json: $ORA_ASM_DISKS_JSON"
    exit 1
}
[[ ! "$ORA_DATA_MOUNTS" =~ $ORA_DATA_MOUNTS_PARAM ]] && {
    echo "Incorrect parameter provided for ora-data-mounts: $ORA_DATA_MOUNTS"
    exit 1
}
[[ -n "$ORA_DATA_MOUNTS_JSON" && ! "$ORA_DATA_MOUNTS_JSON" =~ $ORA_DATA_MOUNTS_JSON_PARAM ]] && {
    echo "Incorrect parameter provided for ora-data-mounts-json: $ORA_DATA_MOUNTS_JSON"
    exit 1
}

ORA_STAGING=${ORA_STAGING%/}
ORA_SWLIB_PATH=${ORA_SWLIB_PATH%/}

export ORA_ROLE_SEPARATION
export ORA_VERSION
export ORA_EDITION
export ORA_DISK_MGMT
export ORA_ASM_DISKS
export ORA_ASM_DISKS_JSON
export ORA_DATA_MOUNTS
export ORA_DATA_MOUNTS_JSON
export ORA_STAGING
export ORA_SWLIB_PATH
export GCS_BACKUP_PATH
export GCS_BACKUP_TEMP_PATH

echo -e "Running with parameters from command line or environment variables:\n"
set | grep -E '^(ORA_|INVENTORY_)' | grep -v '_PARAM='
echo

ANSIBLE_PARAMS="-i ${INVENTORY_FILE}"
ANSIBLE_EXTRA_PARAMS="${*}"

if [[ -n "${ORA_ASM_DISKS_JSON}" ]]; then
  ANSIBLE_EXTRA_PARAMS=${ANSIBLE_EXTRA_PARAMS}" -e '{\"asm_disk_input\": ${ORA_ASM_DISKS_JSON}}'"
fi
if [[ -n "${ORA_DATA_MOUNTS_JSON}" ]]; then
  ANSIBLE_EXTRA_PARAMS=${ANSIBLE_EXTRA_PARAMS}" -e '{\"data_mounts_input\": ${ORA_DATA_MOUNTS_JSON}}'"
fi

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

for PLAYBOOK in brute-cleanup.yml; do
    ANSIBLE_COMMAND="${ANSIBLE_PLAYBOOK} ${ANSIBLE_PARAMS} ${ANSIBLE_EXTRA_PARAMS} ${PLAYBOOK}"
    echo
    echo "Running Ansible playbook: ${ANSIBLE_COMMAND}"
    eval "${ANSIBLE_COMMAND}"
done

exit 0
