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

#
# Create or delete the required devices to be able to use oracle-toolkit on VMs.
# Use the -h option for more information
#
#
# Default values
#
   ZONE="us-east4-b"                         # (-z)       Zone
PROJECT=$(gcloud config get-value project)   # (-p)       Project name
     VM=""                                   # (-v)       Name of the VM
    KEY=""                                   # (-k)       Private key file to get connect
 ACTION="create"                             # (-c or -d) Create or delete the devices
#
# The devices names and sizes we want to create or delete
#
declare -A disks=( [u01]=32GB [u02]=32GB [data]=10GB [reco]=12GB [demo]=10GB [swap]=32GB )
#
# Usage function
#
usage() {
printf "\n\033[1;37m%-8s\033[m\n" "NAME"                  ;
cat << END
        manage_devices_on_vm.sh - Create or delete the required devices on a VM for the Oracle Toolkit to work
END

printf "\n\033[1;37m%-8s\033[m\n" "SYNOPSIS"              ;
cat << END
        $0 [-v] [-k] [-z] [-p] [-c] [-d] [-h]
END

printf "\n\033[1;37m%-8s\033[m\n" "DESCRIPTION"           ;
cat << END
        Some devices are needed to be able to use the Oracle Toolkit on VMs.
        We may also need to delete them.
END

printf "\n\033[1;37m%-8s\033[m\n" "OPTIONS"               ;
cat << END
        -v      Name of the VM; it has to be specified
        -k      The private key file to get connected to the VM; it has to be specified

        -z      Name of the Zone the VM is in (default is "${ZONE}")
        -p      Project name (gcloud config get-value project is used to set the default one; current is "$(gcloud config get-value project)")

        # Options to create or delete the devices -- if both options are specified, create wins not to delete them by mistake
        # If none specified, default is "${ACTION}"
        -c      Create the devices
        -d      Delete the devices

        -h      Shows this help
END

printf "\n\033[1;37m%-8s\033[m\n" "Examples"              ;
cat << END
        # Create the devices on the "toolkit-db4" VM using the "~/privatekeyfile" private key file
        ./manage_devices_on_vm.sh -v toolkit-db4 -k ~/privatekeyfile -c

        # Drop the devices on the "toolkit-db4" VM using the "~/privatekeyfile" private key file
        ./manage_devices_on_vm.sh -v toolkit-db4 -k ~/privatekeyfile -d

END
exit 123
}
#
# Parameters management
#
while getopts "z:v:k:p:cdh" OPT; do
  case "${OPT}" in
  z)    ZONE="${OPTARG}"                              ;;
  p) PROJECT="${OPTARG}"                              ;;
  v)      VM="${OPTARG}"                              ;;
  k)     KEY="${OPTARG}"                              ;;
  d)  ACTION="delete"                                 ;;
  c)  ACTION="create"                                 ;;
  h)  usage                                           ;;
  \?) echo "Invalid option: -$OPTARG" >&2; usage      ;;
  esac
done
#
# Check that we have values for each parameter
#
for PARAMETER in ZONE VM KEY; do
  if [[ -z "${!PARAMETER}" ]]; then
    printf "\n\033[1;31m%s\033[m\n\n" "Please specify a value for $PARAMETER; cannot continue without."
    usage
  fi
done
#
# Verify that the private key file exists
#
if [[ ! -f "${KEY}" ]]; then
  printf "\n\033[1;31m%s\033[m\n\n" "The file ${KEY} does not seem to exist; cannot continue without."
  exit 124
fi
#
#  Create a snapshot before creating the devices
#
gcloud compute disks snapshot "${VM}"                                 \
  --project="${PROJECT}"                                              \
  --snapshot-names="${VM}"-before-installation                        \
  --description="Snapshot of base image prior to any toolkit testing" \
  --zone="${ZONE}"                                                    \
#
#  Create and attach or detach and delete the devices on a target VM
#
for disk in "${!disks[@]}"; do
  if [[ "${ACTION}" = "create" ]]; then
    size="${disks[$disk]}"                      # For a better visibility in the below commands
    gcloud compute disks create "${VM}"-"${disk}" --project="${PROJECT}" --labels=item="${VM}" --zone="${ZONE}" --type=pd-ssd --size="${size}"
    gcloud compute instances attach-disk "${VM}" --mode=rw --zone="${ZONE}" --disk="${VM}"-"${disk}" --device-name="${VM}"-"${disk}"
  else	# Not create so delete
    gcloud compute instances detach-disk "${VM}" --project="${PROJECT}" --zone="${ZONE}" --disk="${VM}"-"${disk}"
    gcloud compute disks delete "${VM}"-"${disk}" --project="${PROJECT}" --zone="${ZONE}" --quiet
  fi
done
