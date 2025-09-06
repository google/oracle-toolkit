# Oracle Toolkit for Google Cloud - Compute Engine VM User Guide

The Oracle Toolkit for Google Cloud can be used with Google Compute Engine Virtual Machines (also commonly referred to as "instances"). This includes using Oracle Grid Infrastructure (GI) and Automatic Storage Management (ASM), with single-instance databases.

Running this toolkit will require:

1. An Ansible [control node](https://docs.ansible.com/ansible/2.9/user_guide/basic_concepts.html#control-node) - where this toolkit will run.
1. An Oracle Database server (which will be the Ansible [managed node](https://docs.ansible.com/ansible/2.9/user_guide/basic_concepts.html#managed-nodes) or "managed host") where the software will be installed to/configured.
1. A place to source the required Oracle software from. As covered in the main user guide, section [Downloading and staging the Oracle Software](user-guide.md#downloading-and-staging-the-oracle-software).

This document covers these items in more detail, in the context of running the toolkit and database on Google Cloud Compute Engine VMs.

## Things to do in Advance - Prerequisites

Before using this toolkit, a small number of Google Cloud prerequisites are required. Specifically:

- A [Google Cloud project](https://developers.google.com/workspace/guides/create-project) with billing enabled.
- A [VPC network](https://cloud.google.com/vpc/docs/vpc) for the VMs - using a default (auto mode) network is fine.
- A [Cloud Storage bucket](https://cloud.google.com/storage/docs/buckets) where the required software media can be staged. (Details on the required software can be found in the [Downloading and staging the Oracle Software](user-guide.md#downloading-and-staging-the-oracle-software) section of the main user guide).
- A [Compute Engine default service account](https://cloud.google.com/compute/docs/access/service-accounts#default_service_account) with the **Storage Object Viewer** (`roles/storage.objectViewer`) role on the Cloud Storage bucket.

## Benefits of Using Google Cloud Compute VMs

Running Oracle Databases on Google Cloud Engine VMs has many advantages. Including but not limited to:

- General Google Cloud benefits such as a wide variety of regions and zones, predictable costs, consumption based charges, and rapid provisioning/decommissioning of infrastructure.
- Dynamically sizable VM instances: change VM shapes, even for existing VM instances, as required.
- The inherent snapshotting, cloning, and replication benefits of using Google Cloud Persistent Disks and/or Hyperdisks for software and database (ASM) storage.
- Easy to reference block devices from Linux via the Google `/dev/disk/by-id` device aliases

## Initial Requirements

All that's typically required to get started is an Ansible [Control Node](https://docs.ansible.com/ansible/2.9/user_guide/basic_concepts.html#control-node) and the Google Cloud CLI - specifically, the **gcloud** utility. (Or Terraform as an alternative to **glcoud**.)

Usually both pieces of software are on the same computer, but they don't have to be. The Ansible Control Node can be an administrator's physical workstation (i.e. laptop), another cloud VM, or could even be the Google Cloud Cloud Shell. However, due to the somewhat ephemeral nature of Cloud Shell, this option is probably not recommended.

Google Cloud VMs (where the Oracle software will be installed and the databases created) are the Ansible [Managed Nodes](https://docs.ansible.com/ansible/2.9/user_guide/basic_concepts.html#control-node) and can be provisioned using a variety of tools and interfaces including:

1. The Google Cloud Web Console
1. Terraform:
   - Covered in detail in the complementary document [Terraform Infrastructure Provisioning for Oracle Toolkit for Google Cloud](terraform.md)
1. Google Cloud CLI (**gcloud**) commands:
   - This guide will focus on this option as it provides consistency, ease of deployment, and repeatability

Several other options for creating Compute Engines VMs exist and are explained in the [Compute Engine client libraries](https://cloud.google.com/compute/docs/api/libraries) documentation.

### Ansible Control Node Provisioning & Setup

Your Ansible Control Node can be virtually any Ansible supported operating system. However, running from a dedicated Linux virtual machine is recommended.

Install Ansible via typical methods. See the [Installing Ansible](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html) section of the official Ansible documentation for additional details.

> **NOTE:** Ansible version 2.9 or higher is required.

To install Ansible, and the required jmespath package, into a Python virtual environment called `venv` use:

```bash
python3 -m venv venv
source venv/bin/activate

pip3 install --upgrade pip

pip3 install ansible
pip3 list | grep ansible

pip3 install jmespath
pip3 list | grep jmespath
```

> **BACKGROUND:** A Python "virtual environment" is a self-contained directory and isolated Python environment. Allowing you to add packages with less dependency complications, version conflicts, and without changing the system Python environment. This virual environment is "activated" using the `source venv/bin/activate` command - this command must be run for each new shell.

Then download to your Ansible Control Node the Oracle Toolkit for Google Cloud from its source site:

```bash
curl -L -o oracle-toolkit-master.zip https://github.com/google/oracle-toolkit/archive/refs/heads/master.zip && \
  unzip ./oracle-toolkit-master.zip && \
  rm ./oracle-toolkit-master.zip && \
  mv oracle-toolkit-master oracle-toolkit
```

## Compute Engine VM Provisioning

Compute Engine VMs for running Oracle databases can be provisioned using Terraform by following the steps outlined in the [Terraform Infrastructure Provisioning for Oracle Toolkit for Google Cloud](terraform.md) guide.

Alternatively, they can be provisioned quickly and efficiently using the **gcloud** utility from the Google Cloud CLI. Most Google Cloud VM images already have the Google Cloud CLI pre-installed. However if you are using your own custom OS image, you may want to install the **gcloud** utility by following the [Install the gcloud CLI](https://cloud.google.com/sdk/docs/install) instructions.

Before provisioning actual VM instances, fundamentals such as the Google Cloud project, region, zone, network, and subnet should be chosen.

Choose your VM's region and zone based on business requirements such as geography and location, technical requirements such as networking and latency, and cost. Machine and storage costs vary between regions, see the [VM instance pricing](https://cloud.google.com/compute/vm-instance-pricing) for additional information.

If creating networks and subnets for experimental resources, then just using [Auto mode IPv4 ranges](https://cloud.google.com/vpc/docs/subnets#ip-ranges) will suffice. If adding to an existing enterprise VPN then consult with your network architect to choose the most appropriate subnet.

For convenience in future commands, it is easiest to set environment variables:

```bash
PROJECT_ID="PROJECT_ID"
REGION_ID="REGION"
ZONE_ID="ZONE"
NETWORK_ID="NETWORK"
SUBNET_ID="SUBNET"
NETWORK_TAGS="NETWORK_TAGS"
```

### Instance Sizing, Performance Characteristics, and OS Image

Choosing the VM shape is of importance, but also can be adjusted post deployment if required.

Oracle databases usually require multiple CPUs and at least 8GB of memory when running Grid Infrastructure. See the Oracle [Database Installation Guide for Linux - Server Hardware Checklist for Oracle Database Installation](https://docs.oracle.com/en/database/oracle/oracle-database/23/ladbi/server-hardware-checklist-for-oracle-database-installation.html) for specific requirements. Oracle licensing may also require consideration when choosing the VM shape and specifically the number of CPUs or vCPUs.

While Oracle database can run on a wide variety of virtual machine families and types, the C4 series is often used. However, depending on your use case, other families and types may be more suitable for your Oracle database workload. For additional details, see the Google [Machine families resource and comparison guide](https://cloud.google.com/compute/docs/machine-resource).

For convenience, specify your chosen virtual machine type as a variable. For example:

```bash
MACHINE_TYPE="c4-standard-4"
```

Choose an operating system image (either one of the Google Cloud public images, or your own if uploaded and prepared separately). Using Oracle Linux is recommended.

To use the latest Compute Engine [Oracle Linux](https://cloud.google.com/compute/docs/images/os-details#oracle_linux) 8 OS image, set environment variables such as:

```bash
IMAGE_PROJECT="oracle-linux-cloud"
IMAGE_FAMILY="oracle-linux-8"
```

### Database Server (Compute Engine VM) Provisioning

With these prerequisites in place, the VM can be easily configured using the Google Cloud CLI **gcloud** utility.

For example (review command carefully and adjust as required before using):

```bash
VM_NAME="INSTANCE_NAME"

gcloud compute instances create ${VM_NAME} \
  --project=${PROJECT_ID} \
  --zone=${ZONE_ID} \
  --machine-type=${MACHINE_TYPE} \
  --network-interface=network-tier=PREMIUM,stack-type=IPV4_ONLY,subnet=${SUBNET_ID} \
  --tags=${NETWORK_TAGS} \
  --image-project=${IMAGE_PROJECT} \
  --image-family=${IMAGE_FAMILY}
```

Include other optional components such as `--metadata=startup-script-url` if, and as required.

A boot disk size of `64G` is typically sufficient for most installations, however customize this size to a larger value if your use case requires.

After provisioning, consider networking, cloud firewalls, and private vs public IP addresses for the new instance. Ingress from the Ansible Control Node is mandatory and egress to the internet (for package installation), whether directly or indirectly through a Google Cloud Router and NAT Gateway, is typically required.

Opening TCP ingress to the Oracle Listener port **1521** is usually required on database servers. To add to your VPN firewall, use a command similar to (review and customize as required):

```bash
PRIORITY_VALUE=1000
SOURCE_TAGS=app-servers

gcloud compute firewall-rules create oracle-listener \
  --project=${PROJECT_ID} \
  --description="Ingress to the Oracle Listener port" \
  --network=${NETWORK_ID} \
  --direction=INGRESS \
  --priority=${PRIORITY_VALUE} \
  --allow=tcp:1521 \
  --source-tags=${SOURCE_TAGS} \
  --target-tags=oracle
```

If necessary, the assigned IP address, which will be used when running the toolkit, can be obtained from the Google Cloud web console, the VM instance itself, or using the **gcloud** command:

```bash
INSTANCE_IP_ADDR=$(gcloud compute instances describe ${VM_NAME} --project=${PROJECT_ID} --zone=${ZONE_ID} --format="value(networkInterfaces[0].networkIP)")

echo -e ${INSTANCE_IP_ADDR}
```

### Adding Block Storage Devices

Compute Engine block storage devices including Persistent Disks (PD) or Hyperdisks can be added in virtually any size with any performance characteristic. To help decide what is required for your environment, refer to the Google documentation [Choose a disk type](https://cloud.google.com/compute/docs/disks) and [Configure disks to meet performance requirements](https://cloud.google.com/compute/docs/disks/performance).

Block storage devices can be used as additional Linux journald file systems such as `/u01` or for ASM storage. As many disks of whatever shapes and sizes is required can be added.

To create a block storage device, first choose a disk name:

```bash
DISK_NAME="DISK_NAME"
```

Then choose the disk size and performance characteristics (customize as necessary):

```bash
DISK_SIZE=64G
DISK_TYPE=hyperdisk-balanced
DISK_PERFORMANCE="--provisioned-iops=3300 --provisioned-throughput=290"
```

Next, create the cloud disk, add it to the VM instance, and if desired, make the disk auto-delete (customize as necessary):

```bash
gcloud compute disks create ${VM_NAME}-${DISK_NAME} --size=${DISK_SIZE} --type=${DISK_TYPE} ${DISK_PERFORMANCE} --project=${PROJECT_ID} --zone=${ZONE_ID}
gcloud compute instances attach-disk ${VM_NAME} --disk=${VM_NAME}-${DISK_NAME} --device-name=oracle-${DISK_NAME} --project=${PROJECT_ID} --zone=${ZONE_ID}
gcloud compute instances set-disk-auto-delete ${VM_NAME} --auto-delete --disk=${VM_NAME}-${DISK_NAME} --project=${PROJECT_ID} --zone=${ZONE_ID}
```

Repeat as necessary adding as many block storage devices as required.

For example, to add one device `/u01` for the Oracle software (Oracle home), and two more for ASM storage (`DATA` and `RECO` diskgroups):

```bash
for DISK_NAME in "u01" "data" "reco"; do
  gcloud compute disks create ${VM_NAME}-${DISK_NAME} --size=${DISK_SIZE} --type=${DISK_TYPE} ${DISK_PERFORMANCE} --project=${PROJECT_ID} --zone=${ZONE_ID}
  gcloud compute instances attach-disk ${VM_NAME} --disk=${VM_NAME}-${DISK_NAME} --device-name=oracle-${DISK_NAME} --project=${PROJECT_ID} --zone=${ZONE_ID}
  gcloud compute instances set-disk-auto-delete ${VM_NAME} --auto-delete --disk=${VM_NAME}-${DISK_NAME} --project=${PROJECT_ID} --zone=${ZONE_ID}
done
```

### Recoding Block Storage in JSON Format for Toolkit Usage

The Oracle Toolkit for Google Cloud requires block storage (or disk) information in JSON format - provided either via JSON configuration files, or as command line arguments to the installation shell script.

Consequently, after creating each, it's usually convenient to record their metadata and property as a JSON object.

> **NOTE:** the [jq](https://jqlang.org/) command line utility (for processing and manipulating JSON content) is beneficial and is not included in most Linux distributions by default but can be easily installed using `sudo apt update && sudo apt install -y jq or `sudo yum install -y jq` depending on your Linux family.

For example, for ASM disks:

```bash
DISK_JSON_OBJECT=$(echo '
{
  "diskgroup": "DATA",
  "disks": [
    {
      "blk_device": "/dev/disk/by-id/google-oracle-'${DISK_NAME}'",
      "name": "'${DISK_NAME}'"
    }
  ]
}' | jq -r -c '.') && echo "${DISK_JSON_OBJECT}"
```

Then add the contents of `$DISK_JSON_OBJECT` to your `asm_disk_config.json` or `data_mounts_config.json`, back in pretty format using: `echo ${DISK_JSON_OBJECT} | jq -r '.'` or use in your `--ora-data-mounts-json` or `--ora-asm-disks-json` command line arguments in the existing compact format.

### Automating for Efficiency

If desired, the above provided **gcloud** utility steps and commands can easily be combined into a shell script, perhaps including some aspects such as the _`VM_NAME`_ as input arguments, and then run programmatically for ease of use and to provide reliable and consistent results.

## Running the Toolkit

### SSH Key Exchange

Before the toolkit can be used, ssh connectivity must be established with an ssh key exchange. An existing, or new (and perhaps toolkit dedicated) ssh key pair can be used.

Initial access to a new compute engine VM is easiest using the [cloud compute ssh](https://cloud.google.com/sdk/gcloud/reference/compute/ssh) command. This command handles authenication (including key pair creation and distribution if necessary) and hostname resolution for accessing the new VM. For example:

```bash
gcloud compute ssh ${VM_NAME} --project=${PROJECT_ID} --zone=${ZONE_ID}
```

If required, create a new and Ansible dedicated ssh key pair using your internal standards (i.e. for encryption algorithm, comment standards, etc). Example command to create a new key-pair for usage with this toolkit using common settings:

```bash
install -d -m 0700 "${HOME}/.ssh"
ssh-keygen -q -b 4096 -t rsa -N '' -C 'oracle-toolkit-for-oracle' -f "${HOME}/.ssh/id_rsa_oracle_toolkit"
```

The newly created public key can then be copied to your compute engine VM using the [gcloud compute scp](https://cloud.google.com/sdk/gcloud/reference/compute/scp) command. For example:

```bash
gcloud compute scp "${HOME}/.ssh/id_rsa_oracle_toolkit.pub" ${VM_NAME}:"${HOME}/.ssh/" --project=${PROJECT_ID} --zone=${ZONE_ID}
```

Or, if appropriate in your environment, use Google Cloud metadata-based SSH keys - see the [Add SSH keys to VMs](https://cloud.google.com/compute/docs/connect/add-ssh-keys) documentation for additional details.

### Toolkit Execution

Overall, running the toolkit against a Google Compute Engine VM instance is really no different to running against a BMS physical or virtualized server. Assuming that the required block storage disk details have been properly specified in the required JSON configuration files and using the `--ora-data-mounts` and `--ora-asm-disks`, or are specified as command line arguments using the `--ora-data-mounts-json` and `--ora-asm-disks-json` arguments.

Also, ensure that the required software media has been properly staged as per the User Guide section [Staging the Oracle installation media](user-guide.md#staging-the-oracle-installation-media).

Define a variable for the bucket location and verify with:

```bash
BUCKET_NAME="BUCKET_NAME"

bash ./check-swlib.sh --ora-swlib-bucket ${BUCKET_NAME}
```

Optionally, add the version you wish to install to the above command using the `--ora-version` argument (or the `--ora-edition FREE` if verifying the media for Free edition).

While the toolkit is compatible with GI and ASM, the quickest and easiest start is usually to deploy Free Edition for familiarity with the toolkit and it's operation. Then complement with full EE or SE2 installations.

Free edition installs will, by default, source the required RPM files directly from the Oracle website - it is not mandatory to download and stage the software in advance for this edition.

For example, the simplest command to create a Free Edition database:

```bash
bash ./install-oracle.sh \
  --instance-ip-addr ${INSTANCE_IP_ADDR} \
  --instance-ssh-key "${HOME}/.ssh/id_rsa_oracle_toolkit" \
  --ora-edition free \
  --ora-data-mounts-json '[{"purpose":"software","blk_device":"/dev/disk/by-id/google-oracle-u01","name":"u01","fstype":"xfs","mount_point":"/u01","mount_opts":"nofail"}]' \
  --backup-dest /opt/oracle/fast_recovery_area/FREE
```

Or to create an Enterprise Edition database:

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

### Cleanup

The one key difference from BMS is that Compute Engine VMs can be destroyed quickly and easily in a variety of ways, including using **gcloud**. For example:

```bash
gcloud compute instances delete ${VM_NAME} --project=${PROJECT_ID} --zone=${ZONE_ID}
```

Since the block storage devices ("disks") were added using the `set-disk-auto-delete` they will automatically be removed when the VM is deleted. If you did not use this option when creating the disks, you will need to remove them manually.

## Integration with Other Google Cloud Services

### Monitoring and Logging

Oracle databases on Compute Engine VMs are "self-managed" and therefore have no _automatically integrated_ connections to other Google Cloud services such as the Logging or Monitoring services. (Automatic integration is included with other, "fully-managed" services such as the Exadata and ADM offerings through the [Oracle on Google Cloud](https://cloud.google.com/solutions/oracle).)

However, when running in Compute Engine VMs, some integration options are available including using the Google Cloud Ops Agent to collect Oracle Database metrics and log data for use in Google Cloud Metrics Explorer and Logs Explorer. For setup and configuration details, refer to the [Oracle Database](https://cloud.google.com/logging/docs/agent/ops-agent/third-party/oracledb) documentation for Google Cloud Observability integration with third party apps. This toolkit does not automatically setup this component.

Additionally, the [Google Cloud Agent for Compute Workloads](https://github.com/GoogleCloudPlatform/workloadagent) can be used.

### Backups

This toolkit includes some initial RMAN backup scripts which can be used to write both FULL DATABASE and ARCHIVELOG RMAN backups to various destinations including local file system storage, an ASM disk group, or even a Google Cloud Storage (GCS) bucket. For backup script setup, refer to the main [user guide](user-guide.md#database-backup-configuration).
