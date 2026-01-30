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

shopt -s nocasematch

# Check if we're using the Mac stock getopt and fail if true
out="$(getopt -T)"
if [ $? != 4 ]; then
    echo -e "Your getopt does not support long parameters, possibly you're on a Mac, if so please install gnu-getopt with brew"
    echo -e "\thttps://brewformulas.org/Gnu-getopt"
    exit 52
fi

ORA_VERSION="${ORA_VERSION:-19.3.0.0.0}"
ORA_VERSION_PARAM='^(23\.[0-9]{1,2}\.[0-9]{1,2}\.[0-9]{1,2}\.[0-9]{1,6}|21\.3\.0\.0\.0|19\.3\.0\.0\.0|18\.0\.0\.0\.0|12\.2\.0\.1\.0|12\.1\.0\.2\.0|11\.2\.0\.4\.0)$'

ORA_RELEASE="${ORA_RELEASE:-latest}"
ORA_RELEASE_PARAM="^(base|latest|[0-9]{,2}\.[0-9]{,2}\.[0-9]{,2}\.[0-9]{,2}\.[0-9]{,6})$"

ORA_EDITION="${ORA_EDITION:-EE}"
ORA_EDITION_PARAM="^(EE|SE|SE2|FREE)$"

ORA_SWLIB_BUCKET="${ORA_SWLIB_BUCKET}"
ORA_SWLIB_BUCKET_PARAM="^gs://"

ORA_DISK_MGMT="${ORA_DISK_MGMT:-ASMUDEV}"
ORA_DISK_MGMT_PARAM="ASMLIB|ASMUDEV|UDEV|FS"

GETOPT_MANDATORY="ora-swlib-bucket:"
GETOPT_OPTIONAL="ora-version:,ora-release:,ora-edition:,ora-disk-mgmt:,no-patch,cluster_type:,help"

GETOPT_LONG="$GETOPT_MANDATORY,$GETOPT_OPTIONAL"
GETOPT_SHORT="h"

options="$(getopt --longoptions "$GETOPT_LONG" --options "$GETOPT_SHORT" -- "$@")"

[ $? -eq 0 ] || {
    echo "Invalid options provided: $@" >&2
    exit 52
}

eval set -- "$options"

while true; do
    case "$1" in
    --ora-version)
        ORA_VERSION="$2"
        if [[ "${ORA_VERSION}" = "26" ]]   ; then ORA_VERSION="23.26.0.0.0"; fi
        if [[ "${ORA_VERSION}" = "23" ]]   ; then ORA_VERSION="23.0.0.0.0"; fi
        if [[ "${ORA_VERSION}" = "21" ]]   ; then ORA_VERSION="21.3.0.0.0"; fi
        if [[ "${ORA_VERSION}" = "19" ]]   ; then ORA_VERSION="19.3.0.0.0"; fi
        if [[ "${ORA_VERSION}" = "18" ]]   ; then ORA_VERSION="18.0.0.0.0"; fi
        if [[ "${ORA_VERSION}" = "12" ]]   ; then ORA_VERSION="12.2.0.1.0"; fi
        if [[ "${ORA_VERSION}" = "12.2" ]] ; then ORA_VERSION="12.2.0.1.0"; fi
        if [[ "${ORA_VERSION}" = "12.1" ]] ; then ORA_VERSION="12.1.0.2.0"; fi
        if [[ "${ORA_VERSION}" = "11" ]]   ; then ORA_VERSION="11.2.0.4.0"; fi
        shift
        ;;
    --no-patch)
        ORA_RELEASE="base"
        ;;
    --ora-release)
        ORA_RELEASE="$2"
        shift
        ;;
    --ora-edition)
        ORA_EDITION="$(echo "$2" | tr '[:lower:]' '[:upper:]')"
        shift
        ;;
    --ora-swlib-bucket)
        ORA_SWLIB_BUCKET="$2"
        shift
        ;;
    --ora-disk-mgmt)
        ORA_DISK_MGMT="$2"
        shift
        ;;
    --help | -h)
        echo -e "\tUsage: $(basename $0)" >&2
        echo "${GETOPT_MANDATORY}" | sed 's/,/\n/g' | sed 's/:/ <value>/' | sed 's/\(.\+\)/\t --\1/'
        echo "${GETOPT_OPTIONAL}"  | sed 's/,/\n/g' | sed 's/:/ <value>/' | sed 's/\(.\+\)/\t [ --\1 ]/'
        exit 52
        ;;
    --)
        shift
        break
        ;;
    esac
    shift
done

[[ ! "$ORA_VERSION" =~ $ORA_VERSION_PARAM ]] && {
    echo "Incorrect parameter provided for ora-version: $ORA_VERSION"
    exit 52
}
[[ ! "$ORA_RELEASE" =~ $ORA_RELEASE_PARAM ]] && {
    echo "Incorrect parameter provided for ora-release: $ORA_RELEASE"
    exit 52
}
[[ ! "$ORA_EDITION" =~ $ORA_EDITION_PARAM ]] && {
    echo "Incorrect parameter provided for ora-edition: $ORA_EDITION"
    exit 52
}
[[ ! "$ORA_SWLIB_BUCKET" =~ $ORA_SWLIB_BUCKET_PARAM ]] && {
    echo "Incorrect parameter provided for ora-swlib-bucket: $ORA_SWLIB_BUCKET"
    echo "Example: gs://my-gcs-bucket"
    exit 52
}
[[ ! "$ORA_DISK_MGMT" =~ $ORA_DISK_MGMT_PARAM ]] && {
    echo "Incorrect parameter provided for ora-disk-mgmt: $ORA_DISK_MGMT"
    exit 52
}

# Oracle Database free edition parameter overrides
if [ "${ORA_EDITION}" = "FREE" ]; then
  ORA_DISK_MGMT=FS
  if [[ -z "${ORA_VERSION}" || "${ORA_VERSION}" != 23.* ]]; then
    ORA_VERSION="23.26.0.0.0"
  fi
fi

# Mandatory options
if [ "${ORA_SWLIB_BUCKET}" = "" ]; then
    echo "Please specify a GS bucket with --ora-swlib-bucket"
    exit 52
fi

# Trim tailing slashes from variables with paths
ORA_SWLIB_BUCKET="${ORA_SWLIB_BUCKET%/}"

export ORA_VERSION ORA_RELEASE ORA_EDITION ORA_SWLIB_BUCKET ORA_DISK_MGMT

echo -e "Running with parameters from command line or environment variables:\n"
set | grep -E '^(ORA_|BACKUP_|ARCHIVE_)' | grep -v '_PARAM='
echo

# Run locally only; the trailing comma indicates a hostname rather than a file.
INVENTORY_FILE="localhost,"

ANSIBLE_PLAYBOOK="ansible-playbook"
if ! type ansible-playbook >/dev/null 2>&1; then
    echo "Ansible executable not found in path"
    exit 52
else
    echo "Found Ansible: $(type ansible-playbook)"
fi

declare -a CMD_ARRAY=("$ANSIBLE_PLAYBOOK" -i "$INVENTORY_FILE")
CMD_ARRAY+=(-e "ora_version=${ORA_VERSION}")
CMD_ARRAY+=(-e "ora_release=${ORA_RELEASE}")
CMD_ARRAY+=(-e "ora_edition=${ORA_EDITION}")
CMD_ARRAY+=(-e "ora_swlib_bucket=${ORA_SWLIB_BUCKET}")
CMD_ARRAY+=(-e "ora_disk_mgmt=${ORA_DISK_MGMT}")
CMD_ARRAY+=("$@")

# Add any passthrough arguments from the script command line
if [[ -n "$ANSIBLE_PARAMS" ]]; then
  echo "Processing ANSIBLE_PARAMS string: [$ANSIBLE_PARAMS]"
  CMD_ARRAY+=(-e "$ANSIBLE_PARAMS")
fi

# exit on any error from the following scripts
set -e

PLAYBOOK="check-swlib.yml"

declare -a CMDLINE=("${CMD_ARRAY[@]}")
CMDLINE+=("${PLAYBOOK}")

printf "Running Ansible playbook: %s\n" "${CMDLINE[*]}"

"${CMDLINE[@]}"
