#!/bin/bash

# used for oracle ORAchk.  install, run and uninstall ORAchk

# Check if we're using the Mac stock getopt and fail if true
out="$(getopt -T)"
if [ $? != 4 ]; then
    echo -e "Your getopt does not support long parameters, possibly you're on a Mac, if so please install gnu-getopt with brew"
    echo -e "\thttps://brewformulas.org/Gnu-getopt"
    exit 1
fi

# set to 'echo ' to only dislay commands
DEBUG_CMD='echo '
DEBUG_CMD=''

ORA_SWLIB_BUCKET="${ORA_SWLIB_BUCKET}"
ORA_SWLIB_BUCKET_PARAM='^gs://.+[^/]$'

ORACLE_SERVER=''
AHF_DIR='AHF'
AHF_FILE=''
AHF_INSTALL=0
AHF_UNINSTALL=0
RUN_ORACHK=0

GETOPT_MANDATORY="oracle-server:,oracle-sid:"
GETOPT_OPTIONAL="ora-swlib-bucket:,ahf-file:,ahf-dir:,ahf-install,ahf-uninstall,run-orachk,help"

GETOPT_LONG="$GETOPT_MANDATORY,$GETOPT_OPTIONAL"
GETOPT_SHORT="h"

options="$(getopt --longoptions "$GETOPT_LONG" --options "$GETOPT_SHORT" -- "$@")"

[ $? -eq 0 ] || {
    echo "Invalid options provided: $@" >&2
    exit 1
}

eval set -- "$options"

help () {
    echo -e "\tUsage: $(basename $0)"
    echo "${GETOPT_MANDATORY}" | sed 's/,/\n/g' | sed 's/:/ <value>/' | sed 's/\(.\+\)/\t --\1/'
    echo "${GETOPT_OPTIONAL}"  | sed 's/,/\n/g' | sed 's/:/ <value>/' | sed 's/\(.\+\)/\t [ --\1 ]/'
    echo
    echo "--ahf-install and --run-orachk may be combined to install and run"

}

# check if both install and run were specified together
RUN_ENABLED=0
INSTALL_ENABLED=0

while true
do

    case "$1" in

        --ora-swlib-bucket)
           ORA_SWLIB_BUCKET="$2"
           shift
           ;;

        --help | -h)
            help >&2
            exit 0
            ;;

        --ahf-file) 
            AHF_FILE="$2"
            shift
            ;;
 
        --ahf-dir)
            AHF_DIR="$2"
             shift
             ;;

        --oracle-sid)
            ORACLE_SID="$2"
            shift
            ;;

        --oracle-server)
            ORACLE_SERVER="$2"
            shift
            ;;

        --ahf-install)
            AHF_UNINSTALL=1
            AHF_INSTALL=1
            INSTALL_ENABLED=1
            ;;

        --ahf-uninstall)
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

[ "$RUN_ENABLED" -eq 1 -a "$INSTALL_ENABLED" -eq 1 ] && {
    AHF_UNINSTALL=1
    AHF_INSTALL=1
    INSTALL_ENABLED=1
}

[[ -z $ORACLE_SERVER ]] && { echo "please specify --oracle-server"; exit 1; }
[[ -z $ORACLE_SID ]] && { echo "please specify --oracle-sid"; exit 1; }

INVENTORY_FILE=inventory_files/inventory_${ORACLE_SERVER}_${ORACLE_SID}
[[ -r $INVENTORY_FILE ]] || { 
    echo "cannot read inventory file '$INVENTORY_FILE'"
    echo " please check --oracle-sid and --oracle-server"
    exit 1
}

# Uninstall AHF
[[ $AHF_UNINSTALL -eq 1 ]] && {

    $DEBUG_CMD ansible-playbook -i $INVENTORY_FILE check-oracle.yml \
        --extra-vars "uninstall_ahf=true"
}

# Install AHF
[[ $AHF_INSTALL -eq 1 ]] && {

    [[ -z $AHF_DIR ]] && { echo "please specify --ahf-dir"; exit 1; }

    [[ ! "$ORA_SWLIB_BUCKET" =~ $ORA_SWLIB_BUCKET_PARAM ]] && {
        echo "Incorrect parameter provided for ora-swlib-bucket: $ORA_SWLIB_BUCKET"
        echo "Example: gs://my-gcs-bucket"
        exit 1
    }

    ORA_SWLIB_AHF_FILENAME="${ORA_SWLIB_BUCKET}/${AHF_DIR}/${AHF_FILE}"

    $DEBUG_CMD ansible-playbook -i $INVENTORY_FILE check-oracle.yml \
        --extra-vars "uninstall_ahf=false ORA_SWLIB_AHF_FILENAME=$ORA_SWLIB_AHF_FILENAME"
}

# run ORAchk
[[ $RUN_ORACHK -eq 1 ]] && {

    $DEBUG_CMD ansible-playbook -i $INVENTORY_FILE check-oracle.yml \
        --extra-vars "uninstall_ahf=false run_orachk=true ORACLE_SID=$ORACLE_SID"
}


