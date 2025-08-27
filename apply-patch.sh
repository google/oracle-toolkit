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

# Check if we're using the Mac stock getopt and fail if true
out="$(getopt -T)"
if [ $? != 4 ]; then
    echo -e "Your getopt does not support long parameters, possibly you're on a Mac, if so please install gnu-getopt with brew"
    echo -e "\thttps://brewformulas.org/Gnu-getopt"
    exit
fi

ORA_VERSION="${ORA_VERSION:-19.3.0.0.0}"
ORA_VERSION_PARAM='^(21\.3\.0\.0\.0|19\.3\.0\.0\.0|18\.0\.0\.0\.0|12\.2\.0\.1\.0|12\.1\.0\.2\.0|11\.2\.0\.4\.0)$'

ORA_RELEASE="${ORA_RELEASE}"
ORA_RELEASE_PARAM=""

ORA_SWLIB_BUCKET="${ORA_SWLIB_BUCKET}"
ORA_SWLIB_BUCKET_PARAM="^gs://.+"

ORA_SWLIB_PATH="${ORA_SWLIB_PATH:-/u01/swlib}"
ORA_SWLIB_PATH_PARAM="^/.*"

ORA_STAGING="${ORA_STAGING:-""}"
ORA_STAGING_PARAM="^/.+$"

ORA_DB_NAME="${ORA_DB_NAME:-ORCL}"
ORA_DB_NAME_PARAM="^[a-zA-Z0-9_$]+$"

#
# The default inventory file
#
INVENTORY_FILE="${INVENTORY_FILE:-./inventory_files/inventory}"

# Suppress displaying hosts if a "when" condition isn't satisfied, to reduce overall output file size.
export ANSIBLE_DISPLAY_SKIPPED_HOSTS=false
###
GETOPT_MANDATORY="ora-swlib-bucket:,inventory-file:"
GETOPT_OPTIONAL="ora-version:,ora-release:,ora-swlib-path:,ora-staging:,ora-db-name:"
GETOPT_OPTIONAL="$GETOPT_OPTIONAL,help,validate"
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
    --ora-version)
        ORA_VERSION="$2"
        if [[ "${ORA_VERSION}" = "21" ]]   ; then ORA_VERSION="21.3.0.0.0"; fi
        if [[ "${ORA_VERSION}" = "19" ]]   ; then ORA_VERSION="19.3.0.0.0"; fi
        if [[ "${ORA_VERSION}" = "18" ]]   ; then ORA_VERSION="18.0.0.0.0"; fi
        if [[ "${ORA_VERSION}" = "12" ]]   ; then ORA_VERSION="12.2.0.1.0"; fi
        if [[ "${ORA_VERSION}" = "12.2" ]] ; then ORA_VERSION="12.2.0.1.0"; fi
        if [[ "${ORA_VERSION}" = "12.1" ]] ; then ORA_VERSION="12.1.0.2.0"; fi
        if [[ "${ORA_VERSION}" = "11" ]]   ; then ORA_VERSION="11.2.0.4.0"; fi
        shift
        ;;
    --ora-release)
        ORA_RELEASE="$2"
        shift
        ;;
    --ora-swlib-bucket)
        ORA_SWLIB_BUCKET="$2"
        shift
        ;;
    --ora-swlib-path)
        ORA_SWLIB_PATH="$2"
        shift
        ;;
    --ora-staging)
        ORA_STAGING="$2"
        shift
        ;;
    --inventory-file)
        INVENTORY_FILE="$2"
        shift
        ;;
    --ora-db-name)
        ORA_DB_NAME="$2"
        shift
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
# Parameter defaults
#
[[ "$ORA_STAGING" == "" ]] && {
    ORA_STAGING=$ORA_SWLIB_PATH
}
#
# Variables verification
#
shopt -s nocasematch

[[ ! "$ORA_VERSION" =~ $ORA_VERSION_PARAM ]] && {
    echo "Incorrect parameter provided for ora-version: $ORA_VERSION"
    exit 1
}
[[ ! "$ORA_RELEASE" =~ $ORA_RELEASE_PARAM ]] && {
    echo "Incorrect parameter provided for ora-release: $ORA_RELEASE"
    exit 1
}
[[ ! "$ORA_SWLIB_BUCKET" =~ $ORA_SWLIB_BUCKET_PARAM ]] && {
    echo "Incorrect parameter provided for ora-swlib-bucket: $ORA_SWLIB_BUCKET"
    exit 1
}
[[ ! "$ORA_SWLIB_PATH" =~ $ORA_SWLIB_PATH_PARAM ]] && {
    echo "Incorrect parameter provided for ora-swlib-path: $ORA_SWLIB_PATH"
    exit 1
}
[[ ! "$ORA_STAGING" =~ $ORA_STAGING_PARAM ]] && {
    echo "Incorrect parameter provided for ora-staging: $ORA_STAGING"
    exit 1
}
[[ ! "$ORA_DB_NAME" =~ $ORA_DB_NAME_PARAM ]] && {
    echo "Incorrect parameter provided for ora-db-name: $ORA_DB_NAME"
    exit 1
}

# Mandatory options
if [ "${ORA_SWLIB_BUCKET}" = "" ]; then
    echo "Please specify a GS bucket with --ora-swlib-bucket"
    exit 2
fi
if [[ ! -s ${INVENTORY_FILE} ]]; then
    echo "Please specify the inventory file using --inventory-file <file_name>"
    exit 2
fi

#
# Trim tailing slashes from variables with paths
#
ORA_STAGING=${ORA_STAGING%/}
ORA_SWLIB_BUCKET=${ORA_SWLIB_BUCKET%/}
ORA_SWLIB_PATH=${ORA_SWLIB_PATH%/}

export ORA_DB_NAME
export ORA_STAGING
export ORA_SWLIB_BUCKET
export ORA_SWLIB_PATH
export ORA_VERSION
export ORA_RELEASE

echo -e "Running with parameters from command line or environment variables:\n"
set | grep -E '^(ORA_|BACKUP_|ARCHIVE_)' | grep -v '_PARAM='
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

echo "Running Ansible playbook: ${ANSIBLE_PLAYBOOK} ${ANSIBLE_PARAMS} patch.yml"
${ANSIBLE_PLAYBOOK} ${ANSIBLE_PARAMS} patch.yml

exit 0
