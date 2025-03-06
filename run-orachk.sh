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

orachk_dir=$(dirname $0)
orachk_env_file=${orachk_dir}/orachk.sh

[[ -f $orachk_env_file ]] || {
    echo
    echo $orachk_env_file not found
    echo
    exit 1
}

. $orachk_env_file

# use of undeclared variables is fatal
set -u

[[ -x $RAT_CRS_HOME ]] || {
    err_exit "cannot execute dir $RAT_CRS_HOME"
}

user_run_as='root'
check_name='dba'
orachk_profile='dba'

#env | sort

if [[ $USER != $user_run_as ]]; then
    echo
    echo Please run as $user_run_as
    echo
    exit 1
fi

orachk_dir=$(dirname $0)
orachk_env_file=${orachk_dir}/orachk.sh

[[ -f $orachk_env_file ]] || {
    echo
    echo $orachk_env_file not found
    echo
    exit
}

. $orachk_env_file

[[ -x $RAT_CRS_HOME ]] || {
    echo cannot execute dir $RAT_CRS_HOME
    exit 1
}

export RAT_OUTPUT=${ORACHK_BASE}/${check_name}
orachk_mkdir $RAT_OUTPUT

chown -R ${ORACLE_OWNER}:${ORACLE_GROUP} $RAT_OUTPUT

# -S does not run checks that require root access
# -s DOES run checks that require root access

declare CMD
CMD="${ORACHK_BASE}/bin/${CHK_EXE_NAME} -s -dbconfig $ORACLE_HOME%$ORACLE_SID -showpass -profile $orachk_profile"
echo "orachk CMD: $CMD"
tmp_file=$(mktemp)
# stdbuf causes each line to be flushed at EOL. Useful when running this script manually
# not so useful for ansible as the output is not visible when run from ansible
exe_cmd "stdbuf -oL $CMD" | tee $tmp_file
grep 'UPLOAD \[if required\]' $tmp_file | awk '{ print $NF }' > /tmp/orachk-zipfile.txt
rm -f $tmp_file

# output will be in ${ORACHK_BASE}/${orahkProfile}/orachk_${HOSTNAME}_${ORACLE_SID}_timestamp.zip
# eg. /opt/oracle.ahf/dba/orachk_jkstill-orachk-19c-patch_ORCL_020425_163615.zip

