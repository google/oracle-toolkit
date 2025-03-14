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
#
# change these as needed
# will also work with exachk

export PATH=/usr/local/bin:$PATH
export ORAENV_ASK=NO
. /usr/local/bin/oraenv 

echo ORACLE_HOME: $ORACLE_HOME

# is this orachk or exachk?
CHK_EXE_NAME=orachk

# If RAC is not installed, just set the CRS home variables to ORACLE_HOME
export CRS_HOME=$ORACLE_HOME
export RAT_CRS_HOME=$ORACLE_HOME

export RAT_TIMEOUT=240
export RAT_ORACLE_HOME=${ORACLE_HOME}

# RAT_DBNAMES not compatible with the orachk -dbconfig option
# using -dbconfig as per SR 3-19938508051
#export RAT_DBNAMES=${ORACLE_SID}

##################################
#### Do not Edit Below here ######
##################################

# the base directory for orachk/exachk
export ORACHK_BASE=/opt/oracle.ahf

export SQLPATH=${PWD}
export ORACLE_PATH=${PWD}

export ORACLE_OWNER=oracle
export ORACLE_GROUP=oinstall

declare TRUE=0
declare FALSE=1
declare dry_run=$FALSE

declare banner_chr='='
declare banner_hdrLen=80
declare banner_pfxLen=5
declare banner_hdr=''
declare banner_pfx=''


for i in $(seq 1  $banner_hdrLen)
do
banner_hdr=${banner_hdr}${banner_chr}
done

for i in $(seq 1  $banner_pfxLen)
do
    banner_pfx=${banner_pfx}${banner_chr}
done


# print a message with a banner
msg () {
    declare msg="$@"

    echo $banner_hdr
    echo "$banner_pfx $msg"
    echo $banner_hdr
    echo
}

# print a message and exits with an error
err_exit () {
    declare err_msg="$@"

    echo >&2
    echo Execution has failed for $err_msg >&2
    echo >&2
    exit 1
}

###########################################
# used to run a command
# if dry_run is set, just print the command
# The Gobal dry_run may not currently be used
###########################################
exe_cmd () {
    declare cmd_to_exe="$@"

    if [[ $dry_run == "$FALSE" ]]; then
        eval "$cmd_to_exe"
    else
        msg "$cmd_to_exe"
    fi
}

# complain if the dir exists and exit with error
chkdir_neg () {
    declare dir_to_chk=$1

    [ -d "$dir_to_chk" -a -r "$dir_to_chk" -a -x "$dir_to_chk" -a -w "$dir_to_chk" ] && {
        err_exit  "'$dir_to_chk' already exists"
    }
}

# complain if the dir does not exist and exit with error
chkdir () {
    declare dir_to_chk=$1

    [ -d "$dir_to_chk" -a -r "$dir_to_chk" -a -x "$dir_to_chk" -a -w "$dir_to_chk" ] || {
        err_exit  "No access to '$dir_to_chk'"
    }
}

###########################################################################
# creates a directory
# if the directory exists, it is moved to a new directory with a timestamp
# the new directory is created
# if the new directory cannot be created, exit with error
###########################################################################
orachk_mkdir () {
    declare dir_to_mk=$1
    [[ -z $dir_to_mk ]] && { err_exit "orachk_mkdir: no directory name passed"; }


    [[ -d $dir_to_mk ]] && {
        # move old dir to dir+timestamp
        declare timestamp=$(date '+%Y-%m-%d_%H-%M-%S');
        declare new_dirname=${dir_to_mk}_${timestamp}

        mv $dir_to_mk $new_dirname

        [[ -d $new_dirname ]] || {
            err_exit "orachk_mkdir failed to 'mv $dir_to_mk $new_dirname'"
        }
    }

    mkdir -p $dir_to_mk;

    [[ -d $dir_to_mk ]] || {
        err_exit "orachk_mkdir failed to 'mkdir $dir_to_mk'"
    }


}

# cursor_sharing=exact set as a workaround where cursor_sharing=force and 'Oracle Transportation Management' is used
# the query 'select ":SYS_B_0" from dual' may hit the limit of 65535 copies due to cursor leaks in OTM

# when this file is sourced, a local login.sql is created that sets the environment for sqlplus as used by orachk

>  ./login.sql echo "SET HEADING ON ECHO OFF TERMOUT ON TAB OFF TRIMOUT ON TRIMS ON NEWPAGE 1 PAGES 32767 LINES 500"
>> ./login.sql echo "SET LONG 20000000 LONGCHUNKSIZE 50000 FEEDBACK OFF VERIFY OFF TIMING OFF SQLPROMPT \"SQL> \" COLSEP '|'"
>> ./login.sql echo "ALTER SESSION SET CURSOR_SHARING=EXACT;"


