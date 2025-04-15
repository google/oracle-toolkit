# Quickstart for Using the Oracle Toolkit for Google Cloud on Compute Engine VMs

This document serves as a quickstart guide and simple reference for using the Oracle Toolkit for Google Cloud on Compute Engine Virtual Machines. It is an abridged version of the more comprehensive [Oracle Toolkit for Google Cloud - Compute Engine VM User Guide](compute-vm-user-guide.md).

## Prerequisite Assumptions

This document assumes that you have:

1. Provisioned your Ansible Control Node, installed Ansible and JMESpath on it, and downloaded the toolkit.
1. Setup Google Cloud foundational components such as IAM, networking, Google Cloud Storage buckets with the required media staged, and security aspects.
1. Have either Terraform or the Google Cloud CLI and specifically the **gcloud** utility installed.

If you need additional details to setup any of these prerequisites, refer to Google documentation such as [Google Cloud quickstarts and tutorials](https://cloud.google.com/docs/tutorials) and specifically [Install the gcloud CLI](https://cloud.google.com/sdk/docs/install). And the more detailed [Oracle Toolkit for Google Cloud - Compute Engine VM User Guide](compute-vm-user-guide.md).

## Deploying using the Google Cloud CLI

### Set Supporting Variables

Before beginning, infrastructure locality and networking aspects must be defined and captured (i.e. into shell environment variables for convenience):

```bash
PROJECT_ID="PROJECT_ID"
REGION_ID="REGION"
ZONE_ID="ZONE"
NETWORK_ID="NETWORK"
SUBNET_ID="SUBNET"
NETWORK_TAGS="NETWORK_TAGS"
```

Add additional variables for instance specific characteristics such as the VM shape, name, and OS project and image family. For example if using the [C4 machine series](https://cloud.google.com/compute/docs/general-purpose-machines#c4_series) and the latest Compute Engine [Oracle Linux](https://cloud.google.com/compute/docs/images/os-details#oracle_linux) 8 OS image:

```bash
MACHINE_TYPE="c4-standard-4"
IMAGE_PROJECT="oracle-linux-cloud"
IMAGE_FAMILY="oracle-linux-8"
```

Finally, define variables for the virtual machine name, and the Google Cloud Storage bucket where the required Oracle software is staged:

```bash
VM_NAME="INSTANCE_NAME"
BUCKET_NAME="BUCKET_NAME"
```

Verify that the required software is available in the specified bucket using:

```bash
bash ./check-swlib.sh --ora-swlib-bucket ${BUCKET_NAME}
```

Optionally, add the version you wish to install to the above command using the `--ora-version` argument (or the `--ora-edition FREE` if verifying the media for Free edition).

### Create the Compute VM and Block Storage Devices

Create the Compute Engine VM instance:

```bash
gcloud compute instances create ${VM_NAME} \
  --project=${PROJECT_ID} \
  --zone=${ZONE_ID} \
  --machine-type=${MACHINE_TYPE} \
  --network-interface=network-tier=PREMIUM,stack-type=IPV4_ONLY,subnet=${SUBNET_ID} \
  --tags=${NETWORK_TAGS} \
  --image-project=${IMAGE_PROJECT} \
  --image-family=${IMAGE_FAMILY}
```

Capture the IP address of the newly created instance:

```bash
INSTANCE_IP_ADDR=$(gcloud compute instances describe ${VM_NAME} --project=${PROJECT_ID} --zone=${ZONE_ID} --format="value(networkInterfaces[0].networkIP)")
```

Create and attach the desired cloud block storage devices or "disks". Assuming one 64GB disk for the `/u01` file system, and a 500GB disk for each of the ASM `DATA` and `RECO` disk groups:

```bash
gcloud compute disks create ${VM_NAME}-u01 --size=64 --type=hyperdisk-balanced --project=${PROJECT_ID} --zone=${ZONE_ID}
gcloud compute instances attach-disk ${VM_NAME} --disk=${VM_NAME}-u01 --device-name=oracle-u01 --project=${PROJECT_ID} --zone=${ZONE_ID}
gcloud compute instances set-disk-auto-delete ${VM_NAME} --auto-delete --disk=${VM_NAME}-u01 --project=${PROJECT_ID} --zone=${ZONE_ID}

gcloud compute disks create ${VM_NAME}-asm-data-1 --size=500G --type=hyperdisk-balanced --project=${PROJECT_ID} --zone=${ZONE_ID}
gcloud compute instances attach-disk ${VM_NAME} --disk=${VM_NAME}-asm-data-1 --device-name=oracle-asm-data-1 --project=${PROJECT_ID} --zone=${ZONE_ID}
gcloud compute instances set-disk-auto-delete ${VM_NAME} --auto-delete --disk=${VM_NAME}-asm-data-1 --project=${PROJECT_ID} --zone=${ZONE_ID}

gcloud compute disks create ${VM_NAME}-asm-reco-1 --size=500G --type=hyperdisk-balanced --project=${PROJECT_ID} --zone=${ZONE_ID}
gcloud compute instances attach-disk ${VM_NAME} --disk=${VM_NAME}-asm-reco-1 --device-name=oracle-asm-reco-1 --project=${PROJECT_ID} --zone=${ZONE_ID}
gcloud compute instances set-disk-auto-delete ${VM_NAME} --auto-delete --disk=${VM_NAME}-asm-reco-1 --project=${PROJECT_ID} --zone=${ZONE_ID}
```

> **NOTE:** Additional provisioned IOPS and throughput for disks can be added if required - see [Adding Block Storage Devices](compute-vm-user-guide.md#adding-block-storage-devices) for examples.

### Configure SSH Connectivity

Initial access to a new compute engine VM is easiest using the [cloud compute ssh](https://cloud.google.com/sdk/gcloud/reference/compute/ssh) command. This command handles authenication (including key pair creation and distribution if necessary) and hostname resolution for accessing the new VM. For example:

```bash
gcloud compute ssh ${VM_NAME} --project=${PROJECT_ID} --zone=${ZONE_ID}
```

If using a separate, Ansible dedicated ssh key-pair is desirable, create a new key-pair (using your internal or organizational ssh key standards for properties such as key file names, encryption algorithm used, etc).

Example command:

```bash
install -d -m 0700 "${HOME}/.ssh"
ssh-keygen -q -b 4096 -t rsa -N '' -C 'oracle-toolkit-for-oracle' -f "${HOME}/.ssh/id_rsa_oracle_toolkit"
```

The newly created public key can then be copied to your compute engine VM using the [gcloud compute scp](https://cloud.google.com/sdk/gcloud/reference/compute/scp) command. For example:

```bash
gcloud compute scp "${HOME}/.ssh/id_rsa_oracle_toolkit.pub" ${VM_NAME}:"${HOME}/.ssh/" --project=${PROJECT_ID} --zone=${ZONE_ID}
```

Alternatively, the ssh key can be added to your Google Cloud project metadata, which is then automatically copied to compute engine VMs. For additional information on this option, see [Add SSH keys to VMs](https://cloud.google.com/compute/docs/connect/add-ssh-keys).

### Install the Oracle Software and Create a Database

Using the toolkit, all software installation and configuration, and database instance creation steps can be run from a single command.

While the toolkit allows for many options resulting in various permutations and configurations, getting started (while relying on many default values) can be as simple as:

```bash
bash ./install-oracle.sh \
  --instance-ip-addr ${INSTANCE_IP_ADDR} \
  --instance-ssh-key "${HOME}/.ssh/id_rsa_oracle_toolkit" \
  --ora-version 19 \
  --ora-swlib-bucket gs://${BUCKET_NAME} \
  --ora-swlib-path /u01/oracle_install \
  --ora-data-mounts-json '[{"purpose":"software","blk_device":"/dev/disk/by-id/google-oracle-u01","name":"u01","fstype":"xfs","mount_point":"/u01","mount_opts":"nofail"}]' \
  --ora-asm-disks-json '[{"diskgroup":"DATA","disks":[{"blk_device":"/dev/disk/by-id/google-oracle-asm-data-1","name":"DATA1"}]},{"diskgroup":"RECO","disks":[{"blk_device":"/dev/disk/by-id/google-oracle-asm-reco-1","name":"RECO1"}]}]' \
  --ora-db-name ORCL
```
