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

# used for oracle ORAchk.  install, run and uninstall ORAchk
#
# Check if we're using the Mac stock getopt and fail if true
# shellcheck disable=SC2034
out="$(getopt -T)"
if [ $? != 4 ]; then
    echo -e "Your getopt does not support long parameters, possibly you're on a Mac, if so please install gnu-getopt with brew"
    echo -e "\thttps://brewformulas.org/Gnu-getopt"
    exit 1
fi

export ANSIBLE_EXTRA_VARS=''

export INVENTORY_FILE=''
export AHF_LOCATION=''

export AHF_LOCATION_PARAM='^gs://.+[^/]$'

export ORACLE_SERVER=''
export AHF_DIR='AHF'
export AHF_FILE=''
export AHF_INSTALL=0
export AHF_UNINSTALL=0
export RUN_ORACHK=0

export GETOPT_MANDATORY="instance-ip-addr:"
export GETOPT_OPTIONAL="extra-vars:,ahf-location:,db-name:,inventory-file:,ahf-install,ahf-uninstall,run-orachk,help,debug"

export GETOPT_LONG="$GETOPT_MANDATORY,$GETOPT_OPTIONAL"
export GETOPT_SHORT="h"

options="$(getopt --longoptions "$GETOPT_LONG" --options "$GETOPT_SHORT" -- "$@")"

# shellcheck disable=SC2181
[ $? -eq 0 ] || {
    echo "Invalid options provided: $*" >&2
    exit 1
}

eval set -- "$options"

help () {

    echo -e "\tUsage: $(basename "$0")"
    echo "${GETOPT_MANDATORY}" | sed 's/,/\n/g' | sed 's/:/ <value>/' | sed 's/\(.\+\)/\t --\1/'
    echo "${GETOPT_OPTIONAL}"  | sed 's/,/\n/g' | sed 's/:/ <value>/' | sed 's/\(.\+\)/\t [ --\1 ]/'
    echo
    echo "--ahf-install and --run-orachk may be combined to install and run"
    echo "--extra-vars is used to pass extra ansible vars"
    echo "  example:  --extra-vars "var1=val1 var2=val2 ...""

}

# check if both install and run were specified together
export RUN_ENABLED=0
export INSTALL_ENABLED=0

while true
do

    case "$1" in

        --extra-vars)
            ANSIBLE_EXTRA_VARS="$2"
            ;;

        --ahf-location)
            AHF_LOCATION="$2"
            ;;

        --debug)
            export ANSIBLE_DEBUG=1
            export ANSIBLE_DISPLAY_SKIPPED_HOSTS=true
            ;;

        --help | -h)
            help >&2
            exit 0
            ;;

        --inventory-file)
            INVENTORY_FILE="$2"
            shift;
            ;;

        --db-name)
            ORACLE_SID="$2"
            shift
            ;;

        --instance-ip-addr)
            ORACLE_SERVER="$2"
            shift
            ;;

        --ahf-install)
            : ${ORACLE_SID:='NOOP'}
            AHF_UNINSTALL=1
            AHF_INSTALL=1
            INSTALL_ENABLED=1
            ;;

        --ahf-uninstall)
            ORACLE_SID='NOOP'
            AHF_UNINSTALL=1
            AHF_INSTALL=0
            ;;

        --run-orachk)
            AHF_UNINSTALL=0
            AHF_INSTALL=0
            RUN_ORACHK=1
            RUN_ENABLED=1
            ;;

       --)
           shift
           break
           ;;
   
   esac

   shift

done

# one of install, uninstall or run must be called

[[ $AHF_INSTALL -eq 0 ]] && [[ $AHF_UNINSTALL -eq 0 ]] && [[ $RUN_ORACHK -eq 0 ]] && { help; exit 1; }


[[ -n $ANSIBLE_EXTRA_VARS ]] && {

    if [[ ! "$ANSIBLE_EXTRA_VARS" =~ ^([a-zA-Z_][a-zA-Z0-9_]*=[^[:space:]]+)([[:space:]]+[a-zA-Z_][a-zA-Z0-9_]*=[^[:space:]]+)*$ ]]; then
        echo "Invalid format for --extra-vars"
        echo "the extra vars should be a string of 1 or more name=value pairs separated by a space"
        echo "example: varname1=value varname2=value2 varname3=value3"
        exit 1
    fi

}

[ "$RUN_ENABLED" -eq 1 ] && [ "$INSTALL_ENABLED" -eq 1 ] && {
    AHF_UNINSTALL=1
    AHF_INSTALL=1
    INSTALL_ENABLED=1
}

[[ -z $ORACLE_SID ]] && { echo "please specify --db-name"; echo; help; exit 1; }

# if an ip address is passed for --instance-ip-address, and inventory file is not specified on the cli, check for an inventory file by lookup of target hostname
[[ "$ORACLE_SERVER" =~ ^[[:digit:]]{1,3}[.][[:digit:]]{1,3}[.][[:digit:]]{1,3}[.][[:digit:]]{1,3}$ ]] && [[ -z "$INVENTORY_FILE" ]] && {
    TARGET_HOSTNAME="$( dig +short -x $ORACLE_SERVER | cut -f1 -d\. )"
    TEST_INVENTORY_FILE=inventory_files/inventory_${TARGET_HOSTNAME}_${ORACLE_SID}
    [[ -r $TEST_INVENTORY_FILE ]] && INVENTORY_FILE="$TEST_INVENTORY_FILE"
}

# if the inventory file is specified on the cli, then the --instance-ip-addr or ORACLE_SERVER are not required
if [[ -z $INVENTORY_FILE ]]; then
    [[ -z $ORACLE_SERVER ]] && { echo "please specify --instance-ip-addr"; echo; help; exit 1; }
    INVENTORY_FILE=inventory_files/inventory_${ORACLE_SERVER}_${ORACLE_SID}
fi

[[ -r $INVENTORY_FILE ]] || { 
    echo "cannot read inventory file '$INVENTORY_FILE'"
    echo " please check and --instance-ip-addr"
    echo " and --inventory-file"
    exit 1
}

# fail early if the AFH file format is incorrect and/or the file does not exist.
[[ -n "$AHF_LOCATION" ]] || [[ $AHF_INSTALL -eq 1 ]] && {

    [[ ! "$AHF_LOCATION" =~ $AHF_LOCATION_PARAM ]] && {
        echo "Incorrect parameter provided for AHF_LOCATION: $AHF_LOCATION"
        echo "Example: gs://my-gcs-bucket/ahf/ahf.zip"
        exit 1
    }

    ( gcloud storage ls "$AHF_LOCATION"  >/dev/null 2>&1 ) || {
        echo "--ahf-location file '$AHF_LOCATION' not found"
        exit 1;
    }
}

# Uninstall AHF
[[ $AHF_UNINSTALL -eq 1 ]] && {

    ansible-playbook -i "$INVENTORY_FILE" check-oracle.yml \
        --extra-vars "uninstall_ahf=true $ANSIBLE_EXTRA_VARS"
}

# Install AHF
[[ $AHF_INSTALL -eq 1 ]] && {


    ansible-playbook -i "$INVENTORY_FILE" check-oracle.yml \
        --extra-vars "uninstall_ahf=false AHF_LOCATION=$AHF_LOCATION $ANSIBLE_EXTRA_VARS"
}

# run ORAchk
[[ $RUN_ORACHK -eq 1 ]] && {

    ansible-playbook -i "$INVENTORY_FILE" check-oracle.yml \
        --extra-vars "uninstall_ahf=false run_orachk=true ORACLE_SID=$ORACLE_SID $ANSIBLE_EXTRA_VARS"
}

