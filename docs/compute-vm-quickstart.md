# Quickstart for Using the Oracle Toolkit for Google Cloud on Compute Engine VMs

This document serves as a quickstart guide and reference for using the Oracle Toolkit for Google Cloud on Compute Engine virtual machines. It is an abridged version of the more comprehensive [Oracle Toolkit for Google Cloud - Compute Engine VM User Guide](compute-vm-user-guide.md) and follows a simple, but manual, command based approach.

If instead you would to deploy the infrastructure and run the toolkit using Terraform, please refer to the document [Terraform Infrastructure Provisioning for Oracle Toolkit for GCP Deployments](terraform.md).

## Prerequisite Assumptions

Before using this toolkit, a small number of Google Cloud prerequisites are required. Specifically:

- A [Google Cloud project](https://developers.google.com/workspace/guides/create-project) with billing enabled.
- A [VPC network](https://cloud.google.com/vpc/docs/vpc) for the VMs - using a default (auto mode) network is fine.
- A [Cloud Storage bucket](https://cloud.google.com/storage/docs/buckets) where the required software media can be staged. (Details on the required software can be found in the [Downloading and staging the Oracle Software](user-guide.md#downloading-and-staging-the-oracle-software) section of the main user guide).
- A [Compute Engine default service account](https://cloud.google.com/compute/docs/access/service-accounts#default_service_account) with the **Storage Object Viewer** (`roles/storage.objectViewer`) role on the Cloud Storage bucket.

> **NOTE:** This toolkit allows you to install any addition of Oracle Database including Free edition. When installing Free edition, the storage bucket prerequisites are not mandatory. See the (Oracle Database Free)[#oracle-database-free] section of this document for the quick-start installation command specific to Free edition.

A VM to act as the Ansible [Control Node](https://docs.ansible.com/ansible/2.9/user_guide/basic_concepts.html#control-node) with the JMESpath and Google Cloud CLI utilities installed, and the toolkit downloaded is also required.

For details on creating and configuring the Ansible Control Node see the [Ansible Control Node Provisioning & Setup](compute-vm-user-guide.md#ansible-control-node-provisioning--setup) section of the full [Oracle Toolkit for Google Cloud - Compute Engine VM User Guide](compute-vm-user-guide.md).

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

### Oracle Database Free

Provisioning [Oracle Database Free](https://www.oracle.com/database/free/) edition is even simpler. The installation automatically sources the required RPM files directly from the Oracle website, although you can still download and stage the software if you prefer. Therefore, there's no need to set up or provide the installation script with details of a Google Cloud storage bucket.

Installing the software and setting up an Oracle Database Free database can be as simple as:

```bash
./install-oracle.sh \
  --instance-ip-addr ${INSTANCE_IP_ADDR} \
  --instance-ssh-key "${HOME}/.ssh/id_rsa_oracle_toolkit" \
  --ora-edition FREE \
  --ora-data-mounts-json '[{"purpose":"software","blk_device":"/dev/disk/by-id/google-oracle-disk-1","name":"u01","fstype":"xfs","mount_point":"/u01","mount_opts":"nofail"}]' \
  --backup-dest /u01/app/oracle/fast_recovery_area/FREE
```

For additional details on Oracle Database Free edition installs see the [Oracle Database Free Edition Specific Details and Changes](user-guide.md#oracle-database-free-edition-specific-details-and-changes) section of the main user guide.
