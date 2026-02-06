---
published: True
---

# Oracle Toolkit for GCP: User Guide

## Table of Contents

- [Oracle Toolkit for GCP: User Guide](#oracle-toolkit-for-gcp-user-guide)
  - [Table of Contents](#table-of-contents)
  - [Command quick reference for single instance deployments](#command-quick-reference-for-single-instance-deployments)
  - [Command quick reference for RAC deployments](#command-quick-reference-for-rac-deployments)
  - [Command quick reference for DR deployments](#command-quick-reference-for-dr-deployments)
  - [Command quick reference for Oracle Database Free Edition deployments](#command-quick-reference-for-oracle-database-free-edition-deployments)
  - [Overview](#overview)
    - [Software Stack](#software-stack)
    - [Requirements and Prerequisites](#requirements-and-prerequisites)
      - [Control node requirements](#control-node-requirements)
      - [Target server requirements](#target-server-requirements)
  - [Installing the toolkit](#installing-the-toolkit)
  - [Downloading and staging the Oracle Software](#downloading-and-staging-the-oracle-software)
    - [Downloading the Oracle installation software](#downloading-the-oracle-installation-software)
      - [Downloading Patches from My Oracle Support](#downloading-patches-from-my-oracle-support)
      - [Required Oracle Software - Download Summary](#required-oracle-software---download-summary)
    - [Staging the Oracle installation media](#staging-the-oracle-installation-media)
      - [Cloud Storage bucket](#cloud-storage-bucket)
      - [Cloud Storage FUSE](#cloud-storage-fuse)
      - [NFS share](#nfs-share)
    - [Validating Media](#validating-media)
  - [Prerequisite configuration](#prerequisite-configuration)
    - [Data mount configuration](#data-mount-configuration)
    - [ASM disk group configuration](#asm-disk-group-configuration)
    - [Specifying LVM logical volumes](#specifying-lvm-logical-volumes)
  - [Configuring Installations](#configuring-installations)
    - [Configuration defaults](#configuration-defaults)
    - [Oracle User Directories](#oracle-user-directories)
    - [Database backup configuration](#database-backup-configuration)
    - [Parameters](#parameters)
      - [Target environment parameters](#target-environment-parameters)
      - [Software installation parameters](#software-installation-parameters)
      - [Storage configuration parameters](#storage-configuration-parameters)
      - [Database configuration parameters](#database-configuration-parameters)
      - [RAC configuration parameters](#rac-configuration-parameters)
      - [Backup configuration parameters](#backup-configuration-parameters)
      - [Additional operational parameters](#additional-operational-parameters)
      - [Using tags to run or skip specific parts of the toolkit](#using-tags-to-run-or-skip-specific-parts-of-the-toolkit)
  - [Example Toolkit Execution](#example-toolkit-execution)
  - [Oracle Database Free Edition Specific Details and Changes](#oracle-database-free-edition-specific-details-and-changes)
    - [Free Edition Version Details](#free-edition-version-details)
    - [Sample Invocations for Oracle Database Free Edition](#sample-invocations-for-oracle-database-free-edition)
    - [Example Oracle Toolkit Execution for Free Edition](#example-oracle-toolkit-execution-for-free-edition)
  - [Post installation tasks](#post-installation-tasks)
    - [Validate the Oracle installation with ORAchk](#validate-the-oracle-installation-with-orachk)
    - [Reset passwords](#reset-passwords)
    - [Validate the environment](#validate-the-environment)
      - [Listing Oracle ASM devices](#listing-oracle-asm-devices)
      - [Displaying cluster resource status](#displaying-cluster-resource-status)
      - [Verify an Oracle cluster](#verify-an-oracle-cluster)
      - [Oracle validation utilities](#oracle-validation-utilities)
    - [Patching](#patching)
      - [A note on patch metadata](#a-note-on-patch-metadata)
    - [Patching RAC databases](#patching-rac-databases)
      - [BMS RAC install with latest RU](#bms-rac-install-with-latest-ru)
    - [Data Guard Standby-First Patching](#data-guard-standby-first-patching)
    - [Destructive Cleanup](#destructive-cleanup)

## Command quick reference for single instance deployments

Sample commands for a simple quick-start and basic oracle-toolkit usage for an
Oracle "single instance" database with Grid Infrastructure (and ASM). Refer to
the remainder of this document for additional details and comprehensive
explanations of the toolkit, scripting, options, and usage scenarios. All
commands run from the "control node".

> **NOTE:** If deploying a single-instance database on GCE, refer to the
> [Quickstart: Use Oracle Toolkit for Google Cloud with Compute
> Engine](https://cloud.google.com/oracle/compute/quickstart-oracle-toolkit)
> document for additional information on provisioning GCE infrastructure and
> getting started with this toolkit.

1. Validate media specifying GCS storage bucket and optionally database:

   ```bash
   ./check-swlib.sh --ora-swlib-bucket gs://[cloud-storage-bucket-name] \
    --ora-version 19.3.0.0.0
   ```

1. Validate access to target server (optionally include -i and location of
   private key file):

   ```bash
   ssh ${INSTANCE_SSH_USER:-`whoami`}@${INSTANCE_IP_ADDR} sudo -u root hostname
   ```

1. Review oracle-toolkit parameters:

   ```bash
   ./install-oracle.sh --help
   ```

1. Run an installation:

   ```bash
   ./install-oracle.sh \
   --ora-swlib-bucket gs://[cloud-storage-bucket-name] \
   --backup-dest "+RECO" \
   --ora-swlib-path /u02/swlib/ \
   --ora-swlib-type gcs \
   --instance-ip-addr ${INSTANCE_IP_ADDR}
   ```

## Command quick reference for RAC deployments

Sample installation for an Oracle Real Application Clusters (RAC) installation.
Initial steps similar to those of the Single Instance installation.

1. Validate media specifying Cloud Storage bucket and optionally database
   version:

   ```bash
   ./check-swlib.sh --ora-swlib-bucket gs://[cloud-storage-bucket-name]
   --ora-version 19.3.0.0.0
   ```

1. Validate access to target RAC nodes:

   ```bash
   ssh ${INSTANCE_SSH_USER:-`whoami`}@${INSTANCE_IP_ADDR_NODE_1} sudo -u root hostname
   ssh ${INSTANCE_SSH_USER:-`whoami`}@${INSTANCE_IP_ADDR_NODE_2} sudo -u root hostname
   ```

1. Review optional oracle-toolkit parameters:

   `./install-oracle.sh --help`

1. Create the cluster configuration. You have two options:

   1. Edit the `cluster_config.json` JSON file template that is provided with the toolkit,
and then specify its path using the `--cluster-config` parameter
   1. Pass the cluster configuration JSON as an argument to the `--cluster-config-json` parameter

1. Install the database:

   ```bash
   ./install-oracle.sh \
   --ora-swlib-bucket gs://[cloud-storage-bucket-name] \
   --backup-dest "+RECO" \
   --ora-swlib-path /u02/swlib/ \
   --ora-swlib-type gcs \
   --cluster-type RAC \
   --cluster-config-json '[ { "scan_name": ... } ]'
   ```

## Command quick reference for DR deployments

> **NOTE:** For additional background and further details on implementing Oracle Database Disaster Recovery (DR) using this toolkit, see the complementary document [Oracle Toolkit for Google Cloud - Disaster Recovery Configurations](disaster-recovery-configurations.md).

The primary database must exist before you can create a standby database.

When you create the primary database, omit the `--cluster-type` option or set it to `NONE`. To create the primary database, see [Single Instance Deployments section](#command-quick-reference-for-single-instance-deployments).

To create a standby database, add the following options to the command options that you used to create the primary database:

- `--primary-ip-addr ${PRIMARY_IP_ADDR}`
- `--cluster-type DG`

1. Install a standby database:

   ```bash
   ./install-oracle.sh \
   --ora-swlib-bucket gs://[cloud-storage-bucket-name] \
   --instance-ip-addr ${INSTANCE_IP_ADDR} \
   --ora-swlib-path /u02/swlib/ \
   --backup-dest "+RECO" \
   --ora-swlib-type gcs \
   --primary-ip-addr ${PRIMARY_IP_ADDR} \
   --cluster-type DG
   ```

## Command quick reference for Oracle Database Free Edition deployments

The toolkit supports installing the Oracle Database Free edition, which is downloadable from the Oracle website: [Oracle Database Free Get Started](https://www.oracle.com/database/free/get-started/).

Unlike with other Oracle Database editions, the Free edition is available in [RPM package](https://en.wikipedia.org/wiki/RPM_Package_Manager) format only. Consequently, the associated Enterprise Linux pre-installation and database RPM files must be downloaded and staged in the GCS storage bucket.

1. Validate media specifying GCS storage bucket and specify `FREE` as the database edition:

   ```bash
   ./check-swlib.sh --ora-swlib-bucket gs://[cloud-storage-bucket-name] \
    --ora-edition FREE
   ```

1. Validate access to target server (optionally include -i and location of
   private key file):

   ```bash
   ssh ${INSTANCE_SSH_USER:-`whoami`}@${INSTANCE_IP_ADDR} sudo -u root hostname
   ```

1. Review oracle-toolkit parameters:

   ```bash
   ./install-oracle.sh --help
   ```

1. Run an installation:

   ```bash
   ./install-oracle.sh \
   --ora-edition FREE \
   --ora-swlib-bucket gs://[cloud-storage-bucket-name] \
   --backup-dest [backup-directory] \
   --instance-ip-addr ${INSTANCE_IP_ADDR}
   ```

## Overview

Oracle Toolkit for GCP provides an automated (scripted) mechanism
to help you install Oracle software and configure an initial Oracle database on
Google Cloud virtual machines or Bare Metal Solution servers. You can also use
the toolkit to provision initial Oracle Database Recovery Manager (RMAN) backups
to Google Cloud Storage or another storage system.

This guide is for experienced professional users of Oracle software who are
deploying Oracle Database software and preparing initial Oracle databases on
Google Cloud [Bare Metal Solution](https://cloud.google.com/bare-metal), or on
Google Cloud [Compute Engine](https://cloud.google.com/products/compute) .

The toolkit defines default values for most options, so you can run the toolkit
with only a few specifications. Your configuration options are listed later in
this guide.

For additional information about using this toolkit on GCE virtual machines
(instances) specifically, including details on infrastructure provisioning,
refer to the [Oracle Toolkit for Google Cloud - Compute Engine VM User Guide](compute-vm-user-guide.md).

The toolkit supports the following major releases of Oracle Database and applies
the most recent quarterly patches, also known as Oracle Release Updates or
RUs:

- Oracle 11.2.0.4.0
- Oracle 12.1.0.2.0
- Oracle 12.2.0.1.0
- Oracle 18c
- Oracle 19c
- Oracle 21c
- Oracle 23ai/26ai (currently [Free Edition](#oracle-database-free-edition-specific-details-and-changes))

The toolkit does not include any Oracle software. You must obtain the
appropriate licenses and download the Oracle software on your own. This guide
provides information about where to obtain Oracle software solely for your
convenience.

After downloading the Oracle software, you stage the software in a Cloud Storage
bucket where the toolkit can access it.

### Software Stack

The toolkit customizes the software stack for Oracle Database workloads. Any out
of a number of Oracle Database software releases can be installed. In addition,
the configuration of the software stack includes:

- The Oracle Grid Infrastructure (GI) and Automatic Storage Manager (ASM),
  at the same major release as the database software. (Optional)
- The configuration of Oracle resources, like the database, listener, and
  ASM resources, via
  "[Oracle Restart](https://docs.oracle.com/en/database/oracle/oracle-database/19/admin/configuring-automatic-restart-of-an-oracle-database.html)"
  for single-instance deployments and Oracle Clusterware for RAC deployments.
- The optional separation of OS roles,"role separation," so you can have
  different OS users for the GI and database software.
- The installation of all of the required OS packages that are necessary for
  the Oracle software installation, including common packages, such as ntp,
  bind-utils, unzip, expect, wget, and net-tools.
- The configuration of Linux Huge Pages, usually as a percentage of the
  available memory, and the disabling of Red Hat Transparent Huge Pages (THP),
  as per the recommended Oracle practices.
- The adjustment of Linux kernel settings, as necessary. For more
  information, see the
  [Oracle documentation](https://docs.oracle.com/en/database/oracle/oracle-database/19/ladbi/minimum-parameter-settings-for-installation.html).
- The disabling of the Linux firewall and SELinux, as recommended for Oracle
  database servers.
- The creation of a swap device, as necessary.

You can further customize the environment and host server(s), as needed.

### Requirements and Prerequisites

You need at least two servers to install Oracle software by using the toolkit:

- **Control node**: a virtual or physical machine from which the toolkit is
  executed.
- **Database server(s)**: target where the Oracle software will be installed
  and configured.

A second database server (or node) is required for RAC deployments.

The following diagrams are similar, showing the architecture in both Bare Metal
Solution and Google Cloud virtual machine environments

![Shows workflow from user through control node to staging repository and then
to servers in the Bare Metal Solution environment. A dotted line goes to Cloud
Storage for backups.](oracle-toolkit-bm-architecture.png)

![Shows workflow from user through control node to staging repository and then
to servers in the GCE Solution environment. A dotted line goes to Cloud
Storage for backups.](oracle-toolkit-vm-architecture.png)

#### Control node requirements

The control node can be any server capable of ssh.

The control node must have the following software installed:

- [Ansible](<https://en.wikipedia.org/wiki/Ansible_(software)>)
  version 2.9 or higher.
- If you are using a Cloud Storage bucket to stage your Oracle installation
  media, the [Google Cloud SDK](https://cloud.google.com/sdk/docs).
- Ideally, a mainstream Linux OS.

Depending on the Linux distribution you are using on your control node, you can
install Ansible with `sudo apt-get install ansible`. Your installation command
might be different. You can verify your version of Ansible with ansible
`--version`.

You can use the [Google Cloud Shell](https://cloud.google.com/shell) as your
control node. Cloud Shell provides command-line access to a virtual machine
instance in a terminal window that opens in the web console. The latest version
of Cloud SDK is installed for you.

#### Target server requirements

Prior to running the toolkit, ensure that the control node has SSH access to a
Linux user account on the target server. The user account must have elevated
security privileges, such as granted by "sudo su -", to install and configure
Oracle software. The toolkit creates _Oracle software owners_, such as `oracle`
and `grid`.

The target database server(s) must be running a version of Linux that is
certified for Oracle Database. The toolkit currently supports the following
certified OS versions:

- Red Hat Enterprise Linux (RHEL) 7 and 8 (versions 7.3 and up).
- Oracle Linux (OL) 7 and 8 (versions 7.3 and up).

For more information about Oracle-supported platforms see the Oracle
certification matrix in the "My Oracle Support" (MOS) site (sign in required):
[https://support.oracle.com](https://support.oracle.com).

## Installing the toolkit

The latest version of the toolkit can be downloaded from GitHub:
[https://github.com/google/oracle-toolkit](https://github.com/google/oracle-toolkit)

On the `google/oracle-toolkit` home page in GitHub, download the toolkit to your
control node by clicking the **Clone or Download** button and selecting
**Download zip**.

If you are using the Cloud Shell as your control node, download the tool to your
$HOME directory.

## Downloading and staging the Oracle Software

You must download and stage the Oracle software yourself, in accordance with the
applicable licenses governing such software. The toolkit doesn't contain any
Oracle software. You are responsible for procuring the Oracle software that you
need and for complying with the applicable licenses.

If you are deploying the Oracle Database Free edition, downloading and staging
the software is optional. Doing so may be useful in cases where the database VM
has no direct internet access. Alternatively, the required Free edition RPMs
can be downloaded directly from oracle.com, based on the values set in the
Ansible `rdbms_software` variable. For more information, see the
[Free Edition Version Details](#free-edition-version-details) section.

### Downloading the Oracle installation software

Oracle software is divided into two general categories: **base software** that
you download from the [Oracle Software Delivery
Cloud](https://edelivery.oracle.com/) site (also known as Oracle "eDelivery") or
[Oracle Technology Network](https://www.oracle.com/database/technologies/oracle-database-software-downloads.html)
(also known as OTN), and **patches** that you download from Oracle's [My Oracle
Support](https://support.oracle.com/) (MOS) site.

One key exception: Oracle 11g base software can be downloaded directly from My
Oracle Support. Only Oracle 12c or later base software needs to be downloaded
from Oracle Software Delivery Cloud. Direct links to MOS downloads are provided
below.

Before you download Oracle software and patches, review and acknowledge Oracle's
license terms.

Before using the toolkit, download all the software pieces for your Oracle
release, including the base release, patch sets, the OPatch utility, and any
additional patches listed by Oracle (unless using `--no-patch`, at which
point only the base release is installed).

Do not unzip the downloaded installation files. The toolkit requires the
downloads in their original, compressed-file format.

#### Downloading Patches from My Oracle Support

For convenience, direct links to My Oracle Support (MOS) for applicable patches
are listed in the following section. You need an Oracle Single Sign-on account
that is linked to a valid Oracle Customer Support Identifier (CSI) to download
patches through My Oracle Support.

#### Required Oracle Software - Download Summary

<table>
<thead>
<tr>
<th>Oracle Release</th>
<th>Category - Site</th>
<th>Software Piece</th>
<th>File Name<br>
(From "Oracle eDelivery" or "My Oracle
Support")</th>
</tr>
</thead>
<tbody>
<tr>
<td>21.3.0.0.0</td>
<td>Base - eDelivery or OTN</td>
<td>Oracle Database 21.3.0.0.0 for Linux x86-64</td>
<td>V1011496-01.zip or LINUX.X64_213000_db_home.zip</td>
</tr>
<tr>
<td></td>
<td>Patch - MOS</td>
<td>Database Release Update 21.8.0.0.0</td>
<td>p34527084_210000_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td></td>
<td>Database Release Update 21.9.0.0.0</td>
<td>p34839741_210000_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td></td>
<td>Database Release Update 21.10.0.0.0</td>
<td>p35134934_210000_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td></td>
<td>Database Release Update 21.11.0.0.0</td>
<td>p35428978_210000_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td></td>
<td>Database Release Update 21.12.0.0.0</td>
<td>p35740258_210000_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td></td>
<td>Database Release Update 21.13.0.0.0</td>
<td>p36041222_210000_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td></td>
<td>Database Release Update 21.14.0.0.0</td>
<td>p36352352_210000_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td></td>
<td>Database Release Update 21.15.0.0.0</td>
<td>p36696242_210000_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td></td>
<td>Database Release Update 21.16.0.0.0</td>
<td>p36991631_210000_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td></td>
<td>Database Release Update 21.17.0.0.0</td>
<td>p37350281_210000_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td></td>
<td>Database Release Update 21.18.0.0.0</td>
<td>p37655430_210000_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td>Base - eDelivery or OTN</td>
<td>Oracle Grid Infrastructure 21.3.0.0.0 for Linux x86-64</td>
<td>V1011504-01.zip or LINUX.X64_213000_grid_home.zip</td>
</tr>
<tr>
<td></td>
<td>Patch - MOS</td>
<td>GI Release Update 21.8.0.0.0</td>
<td>p34526142_210000_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td></td>
<td>GI Release Update 21.9.0.0.0</td>
<td>p34838415_210000_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td></td>
<td>GI Release Update 21.10.0.0.0</td>
<td>p35132566_210000_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td></td>
<td>GI Release Update 21.11.0.0.0</td>
<td>p35427907_210000_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td></td>
<td>GI Release Update 21.12.0.0.0</td>
<td>p35738010_210000_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td></td>
<td>GI Release Update 21.13.0.0.0</td>
<td>p36031790_210000_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td></td>
<td>GI Release Update 21.14.0.0.0</td>
<td>p36352207_210000_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td></td>
<td>GI Release Update 21.15.0.0.0</td>
<td>p36696109_210000_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td></td>
<td>GI Release Update 21.16.0.0.0</td>
<td>p36990664_210000_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td></td>
<td>GI Release Update 21.17.0.0.0</td>
<td>p37349593_210000_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td></td>
<td>GI Release Update 21.18.0.0.0</td>
<td>p37642955_210000_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td></td>
<td>OPatch Utility</td>
<td><a href="https://updates.oracle.com/download/6880880.html"> p6880880_210000_Linux-x86-64.zip</a></td>
</tr>
<tr>
<td>19.3.0.0.0</td>
<td>Base - eDelivery or OTN</td>
<td>Oracle Database 19.3.0.0.0 for Linux x86-64</td>
<td>V982063-01.zip or LINUX.X64_193000_db_home.zip</td>
</tr>
<tr>
<td></td>
<td></td>
<td>Oracle Grid Infrastructure 19.3.0.0.0 for Linux x86-64</td>
<td>V982068-01.zip or LINUX.X64_193000_grid_home.zip</td>
</tr>
<tr>
<td></td>
<td>Patch - MOS</TD>
<TD>COMBO OF OJVM RU COMPONENT 19.30.0.0.260120 + GI RU 19.30.0.0.260120</td>
<td>p38658588_190000_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td>Patch - MOS</TD>
<TD>COMBO OF OJVM RU COMPONENT 19.29.0.0.251021 + GI RU 19.29.0.0.251021</td>
<td>p38273558_190000_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td>Patch - MOS</TD>
<TD>COMBO OF OJVM RU COMPONENT 19.28.0.0.250715 + GI RU 19.28.0.0.250715</td>
<td>p37952382_190000_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td>Patch - MOS</TD>
<TD>COMBO OF OJVM RU COMPONENT 19.27.0.0.250415 + GI RU 19.27.0.0.250415</td>
<td>p37591516_190000_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td>Patch - MOS</TD>
<TD>COMBO OF OJVM RU COMPONENT 19.26.0.0.250121 + GI RU 19.26.0.0.250121</td>
<td>p37262208_190000_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td>Patch - MOS</TD>
<TD>COMBO OF OJVM RU COMPONENT 19.25.0.0.241015 + GI RU 19.25.0.0.241015</td>
<td>p36866740_190000_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td>Patch - MOS</TD>
<TD>COMBO OF OJVM RU COMPONENT 19.24.0.0.240716 + GI RU 19.24.0.0.240716</td>
<td>p36522439_190000_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td>Patch - MOS</TD>
<TD>COMBO OF OJVM RU COMPONENT 19.23.0.0.240416 + GI RU 19.23.0.0.240416</td>
<td>p36209493_190000_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td></TD>
<TD>COMBO OF OJVM RU COMPONENT 19.22.0.0.240116 + GI RU 19.22.0.0.240116</td>
<td>p36031453_190000_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td></TD>
<TD>COMBO OF OJVM RU COMPONENT 19.21.0.0.231017 + GI RU 19.21.0.0.231017</td>
<td>p35742441_190000_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td></TD>
<TD>COMBO OF OJVM RU COMPONENT 19.13.0.0.211019 + GI RU 19.13.0.0.211019</td>
<td>p33248471_190000_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td></td>
<td>COMBO OF OJVM RU COMPONENT 19.11.0.0.210420 + GI RU 19.11.0.0.210420</td>
<td>p32578973_190000_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td></td>
<td>COMBO OF OJVM RU COMPONENT 19.10.0.0.210119 + GI RU 19.10.0.0.210119</td>
<td>p32126842_190000_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td></td>
<td>COMBO OF OJVM RU COMPONENT 19.9.0.0.201020 + GI RU 19.9.0.0.201020</td>
<td>p31720429_190000_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td></td>
<td>COMBO OF OJVM RU COMPONENT 19.8.0.0.200714 + GI RU 19.8.0.0.200714</td>
<td>p31326369_190000_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td></td>
<td>COMBO OF OJVM RU COMPONENT 19.7.0.0.200414 + GI RU 19.7.0.0.200414</td>
<td>p30783556_190000_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td></td>
<td>COMBO OF OJVM RU COMPONENT 19.6.0.0.200114 GI RU 19.6.0.0.200114</td>
<td>p30463609_190000_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td></td>
<td>COMBO OF OJVM RU COMPONENT 19.5.0.0.191015 GI RU 19.5.0.0.191015</td>
<td>p30133178_190000_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td></td>
<td>COMBO OF OJVM RU COMPONENT 19.4.0.0.190716 + GI RU 19.4.0.0.190716</td>
<td>p29699097_190000_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td></td>
<td>OPatch Utility </td>
<td><a
href="https://support.oracle.com/epmos/faces/PatchResultsNDetails?releaseId=600000000122912&patchId=6880880&languageId=0&platformId=226">p6880880_190000_Linux-x86-64.zip</a></td>
</tr>
<tr>
<td>18.0.0.0.0</td>
<td>Base - eDelivery</td>
<td>Oracle Database 18.0.0.0.0 for Linux x86-64</td>
<td>V978967-01.zip</td>
</tr>
<tr>
<td></td>
<td></td>
<td>Oracle Grid Infrastructure 18.0.0.0.0 for Linux x86-64</td>
<td>V978971-01.zip</td>
</tr>
<tr>
<td></td>
<td>Patch - MOS</td>
<td>COMBO OF OJVM RU COMPONENT 18.14.0.0.210420 + GI RU 18.14.0.0.210420</td>
<td>p32579024_180000_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td></td>
<td>COMBO OF OJVM RU COMPONENT 18.13.0.0.210119 + GI RU 18.13.0.0.210119</td>
<td>p32126862_180000_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td></td>
<td>COMBO OF OJVM RU COMPONENT 18.12.0.0.201020 + GI RU 18.12.0.0.201020</td>
<td>p31720457_180000_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td></td>
<td>COMBO OF OJVM RU COMPONENT 18.11.0.0.200714 + GI RU 18.11.0.0.200714</td>
<td>p31326376_180000_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td></td>
<td>COMBO OF OJVM RU COMPONENT 18.10.0.0.200414 GI RU 18.10.0.0.200414</td>
<td>p30783607_180000_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td></td>
<td>COMBO OF OJVM RU COMPONENT 18.9.0.0.200114 GI RU 18.9.0.0.200114</td>
<td>p30463635_180000_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td></td>
<td>COMBO OF OJVM RU COMPONENT 18.8.0.0.191015 GI RU 18.8.0.0.191015</td>
<td>p30133246_180000_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td></td>
<td>COMBO OF OJVM RU COMPONENT 18.7.0.0.190716 + GI RU 18.7.0.0.190716</td>
<td>p29699160_180000_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td></td>
<td>COMBO OF OJVM RU COMPONENT 18.6.0.0.190416 + GI RU 18.6.0.0.190416</td>
<td>p29251992_180000_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td></td>
<td>OPatch Utility</td>
<td><a
href="https://support.oracle.com/epmos/faces/PatchResultsNDetails?releaseId=600000000107457&patchId=6880880&languageId=0&platformId=226">p6880880_180000_Linux-x86-64.zip</a></td>
</tr>
<tr>
<td>12.2.0.1.0</td>
<td>Base - eDelivery</td>
<td>Oracle Database 12.2.0.1.0 for Linux x86-64</td>
<td>V839960-01.zip</td>
</tr>
<tr>
<td></td>
<td></td>
<td>Oracle Grid Infrastructure 12.2.0.1.0 for Linux x86-64 for Linux
x86-64</td>
<td>V840012-01.zip</td>
</tr>
<tr>
<td></td>
<td>Patch - MOS</td>
<td>COMBO OF OJVM RU COMPONENT 12.2.0.1.220118 + 12.2.0.1.220118 GIJAN2022RU</td>
<td>p33559966_122010_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td>Patch - MOS</td>
<td>COMBO OF OJVM RU COMPONENT 12.2.0.1.211019 + 12.2.0.1.211019 GIOCT2021RU</td>
<td>p33248546_122010_Linux_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td></td>
<td>COMBO OF OJVM RU COMPONENT 12.2.0.1.210420 + 12.2.0.1.210420 GIAPR2021RU</td>
<td>p32579057_122010_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td></td>
<td>COMBO OF OJVM RU COMPONENT 12.2.0.1.210119 + 12.2.0.1.210119 GIJAN2021RU</td>
<td>p32126883_122010_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td></td>
<td>COMBO OF OJVM RU COMPONENT 12.2.0.1.201020 + 12.2.0.1.201020 GIOCT2020RU</td>
<td>p31720486_122010_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td></td>
<td>COMBO OF OJVM RU COMPONENT 12.2.0.1.200714 + 12.2.0.1.200714 GIJUL2020RU</td>
<td>p31326390_122010_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td></td>
<td>COMBO OF OJVM RU COMPONENT 12.2.0.1.200414 12.2.0.1.200414 GIAPR2020RU</td>
<td>p30783652_122010_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td></td>
<td>COMBO OF OJVM RU COMPONENT 12.2.0.1.200114 12.2.0.1.200114 GIJAN2020RU</td>
<td>p30463673_122010_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td></td>
<td>COMBO OF OJVM RU COMPONENT 12.2.0.1.191015 12.2.0.1.191015 GIOCT2019RU</td>
<td>p30133386_122010_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td></td>
<td>COMBO OF OJVM RU COMPONENT 12.2.0.1.190716 + 12.2.0.1.190716
GIJUL2019RU</td>
<td>p29699173_122010_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td></td>
<td>COMBO OF OJVM RU COMPONENT 12.2.0.1.190416 + 12.2.0.1.190416
GIAPR2019RU</td>
<td>p29252072_122010_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td></td>
<td>ACFS MODULE ORACLEACFS.KO FAILS TO LOAD ON OL7U3 SERVER WITH RHCK (Patch)
patch 25078431 for Linux x86-64</td>
<td><a
href="https://support.oracle.com/epmos/faces/PatchResultsNDetails?releaseId=600000000018520&patchId=25078431&languageId=0&platformId=226">p25078431_122010_Linux-x86-64.zip</a></td>
</tr>
<tr>
<td></td>
<td></td>
<td>OPatch Utility</td>
<td><a
href="https://support.oracle.com/epmos/faces/PatchResultsNDetails?releaseId=600000000063735&patchId=6880880&languageId=0&platformId=226">p6880880_122010_Linux-x86-64.zip</a></td>
</tr>
<tr>
<td>12.1.0.2.0</td>
<td>Base - eDelivery</td>
<td>Oracle Database 12.1.0.2.0 for Linux x86-64</td>
<td>V46095-01_1of2.zip<br>
V46095-01_2of2.zip</td>
</tr>
<tr>
<td></td>
<td></td>
<td>Oracle Database 12c Standard Edition 2 12.1.0.2.0 for Linux x86-64</td>
<td>V77388-01_1of2.zip<br>
V77388-01_2of2.zip</td>
</tr>
<tr>
<td></td>
<td></td>
<td>Oracle Grid Infrastructure 12.1.0.2.0 for Linux x86-64</td>
<td>V46096-01_1of2.zip<br>
V46096-01_2of2.zip</td>
</tr>
<tr>
<td></td>
<td>Patch - MOS</td>
<td>COMBO OF OJVM COMPONENT 12.1.0.2.220719 DB PSU + GIPSU 12.1.0.2.220719</td>
<td>p34163645_121020_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td>Patch - MOS</td>
<td>COMBO OF OJVM COMPONENT 12.1.0.2.220419 DB PSU + GIPSU 12.1.0.2.220419</td>
<td>p33859511_121020_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td>Patch - MOS</td>
<td>COMBO OF OJVM COMPONENT 12.1.0.2.220118 DB PSU + GIPSU 12.1.0.2.220118</td>
<td>p33560011_121020_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td>Patch - MOS</td>
<td>COMBO OF OJVM COMPONENT 12.1.0.2.211019 DB PSU + GIPSU 12.1.0.2.211019</td>
<td>p33248580_121020_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td></td>
<td>COMBO OF OJVM COMPONENT 12.1.0.2.201020 DB PSU + GIPSU 12.1.0.2.201020</td>
<td>p31720761_121020_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td></td>
<td>COMBO OF OJVM COMPONENT 12.1.0.2.200714 DB PSU + GIPSU 12.1.0.2.200714</td>
<td>p31326400_121020_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td></td>
<td>COMBO OF OJVM COMPONENT 12.1.0.2.200414 DB PSU GIPSU 12.1.0.2.200414</td>
<td>p30783882_121020_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td></td>
<td>COMBO OF OJVM COMPONENT 12.1.0.2.200114 DB PSU GIPSU 12.1.0.2.200114</td>
<td>p30463691_121020_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td></td>
<td>COMBO OF OJVM COMPONENT 12.1.0.2.191015 DB PSU GIPSU 12.1.0.2.191015</td>
<td>p30133443_121020_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td></td>
<td>COMBO OF OJVM COMPONENT 12.1.0.2.190716 DB PSU + GIPSU 12.1.0.2.190716</td>
<td>p29699244_121020_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td></td>
<td>COMBO OF OJVM COMPONENT 12.1.0.2.190416 DB PSU + GIPSU 12.1.0.2.190416</td>
<td>p29252164_121020_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td></td>
<td>Combo OJVM PSU 12.1.0.2.190416 and Database Proactive BP 12.1.0.2.190416
patch 29252171 for Linux x86-64</td>
<td><a
href="https://support.oracle.com/epmos/faces/PatchResultsNDetails?releaseId=600000000009300&patchId=29252171&languageId=0&platformId=226">p29252171_121020_Linux-x86-64.zip</a></td>
</tr><tr>
<td></td>
<td></td>
<td>GI PSU 12.1.0.2.190416 patch 29176115 for Linux x86-64</td>
<td><a
href="https://support.oracle.com/epmos/faces/PatchResultsNDetails?releaseId=600000000009300&patchId=29176115&languageId=0&platformId=226">p29176115_121020_Linux-x86-64.zip</a></td>
</tr>
<tr>
<td></td>
<td></td>
<td>OPatch Utility</td>
<td><a
href="https://support.oracle.com/epmos/faces/PatchResultsNDetails?releaseId=80121010&patchId=6880880&languageId=0&platformId=226">p6880880_121010_Linux-x86-64.zip</a></td>
</tr>
<tr>
<td>11.2.0.4</td>
<td>Patch - MOS</td>
<td>11.2.0.4.0 PATCH SET FOR ORACLE DATABASE SERVER - Patch 13390677 for Linux
x86-64</td>
<td><a
href="https://support.oracle.com/epmos/faces/PatchResultsNDetails?releaseId=80112040&patchId=13390677&languageId=0&platformId=226">p13390677_112040_Linux-x86-64_1of7.zip</a><br>
<a
href="https://support.oracle.com/epmos/faces/PatchResultsNDetails?releaseId=80112040&patchId=13390677&languageId=0&platformId=226">p13390677_112040_Linux-x86-64_2of7.zip</a></td>
</tr>
<tr>
<td></td>
<td></td>
<td>11.2.0.4.0 PATCH SET FOR ORACLE DATABASE SERVER - Patch 13390677 for Linux
x86-64</td>
<td><a
href="https://support.oracle.com/epmos/faces/PatchResultsNDetails?releaseId=80112040&patchId=13390677&languageId=0&platformId=226">p13390677_112040_Linux-x86-64_3of7.zip</a></td>
</tr>
<tr>
<td></td>
<td></td>
<td>Combo of OJVM Component 11.2.0.4.201020 DB PSU + GI PSU 11.2.0.4.201020</td>
<td>p31720783_112040_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td></td>
<td>Combo of OJVM Component 11.2.0.4.200714 DB PSU + GI PSU 11.2.0.4.200714</td>
<td>p31326410_112040_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td></td>
<td>COMBO OF 11.2.0.4.200414 OJVM PSU GIPSU 11.2.0.4.200414</td>
<td>p30783890_112040_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td></td>
<td>GRID INFRASTRUCTURE PATCH SET UPDATE 11.2.0.4.200114</td>
<td>p30501155_112040_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td></td>
<td>GRID INFRASTRUCTURE PATCH SET UPDATE 11.2.0.4.191015</td>
<td>p30070097_112040_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td></td>
<td>GRID INFRASTRUCTURE PATCH SET UPDATE 11.2.0.4.190716</td>
<td>p29698727_112040_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td></td>
<td>GRID INFRASTRUCTURE PATCH SET UPDATE 11.2.0.4.190416</td>
<td>p29255947_112040_Linux-x86-64.zip</td>
</tr>
<tr>
<td></td>
<td></td>
<td>Combo OJVM PSU 11.2.0.4.190416 and Database PSU 11.2.0.4.190416 patch
29252186 for Linux x86-64</td>
<td><a
href="https://support.oracle.com/epmos/faces/PatchResultsNDetails?releaseId=80112040&patchId=29252186&languageId=0&platformId=226">p29252186_112040_Linux-x86-64.zip</a></td>
</tr>
<tr>
<td></td>
<td></td>
<td>GI PSU 11.2.0.4.190416 patch 29255947 for Linux x86-64</td>
<td><a
href="https://support.oracle.com/epmos/faces/PatchResultsNDetails?releaseId=80112040&patchId=29255947&languageId=0&platformId=226">p29255947_112040_Linux-x86-64.zip</a></td>
</tr>
<tr>
<td></td>
<td></td>
<td>RC SCRIPTS (/ETC/RC.D/RC.* , /ETC/INIT.D/* ) ON OL7 FOR CLUSTERWARE (Patch)
patch 18370031 for Linux x86-64</td>
<td><a
href="https://support.oracle.com/epmos/faces/PatchResultsNDetails?releaseId=600000000007588&patchId=18370031&languageId=0&platformId=226">p18370031_112040_Linux-x86-64.zip</a></td>
</tr>
<tr>
<td></td>
<td></td>
<td>OPatch Utility</td>
<td><a
href="https://support.oracle.com/epmos/faces/PatchResultsNDetails?releaseId=80112000&patchId=6880880&languageId=0&platformId=226">p6880880_112000_Linux-x86-64.zip</a></td>
</tr>
</tbody>
</table>

If the required software components are not properly downloaded and staged, the
oracle-toolkit will fail.

### Staging the Oracle installation media

You can stage the Oracle installation media in any one of the following
repository types:

- A [Cloud Storage](https://cloud.google.com/storage/docs/introduction) bucket.
- [Cloud Storage FUSE](https://cloud.google.com/storage/docs/gcs-fuse), an open
  source [FUSE](http://fuse.sourceforge.net/) adapter that allows you to mount
  Cloud Storage buckets as file systems on Linux or macOS systems.
- A network NFS share.

#### Cloud Storage bucket

If you stage your installation media in a Cloud Storage bucket, the toolkit
will copy the required files to the software library path location on your
target server using the Google Cloud CLI `gcloud storage` command. Either
directly downloading the files on the target server or by transferring them
through your Ansible Control Node. Consequently, the CLI must be installed on
your Ansible Control Node or the target server. To install, refer to [Install
the gcloud CLI](https://cloud.google.com/sdk/docs/install).

When the `--ora-swlib-type` argument is used and set to `GCSDIRECT`, the
toolkit will directly copy the media from the GCS bucket to the library path
on the target server. This direct copy requires the gcloud utility to be
available and the storage bucket accessible from the target server. This is
often the most performant method for copying media from storage buckets.

If the argument value is `GCSTRANSFER`, the toolkit will instead copy the
media files through your Ansible Control Node. This method also uses the
gcloud command, but runs it from your Ansible Control Node. And still
writes the contents to the software library path on the target server.

When the argument value is `GCS` or is not provided, the toolkit will
determine which method to use. If the gcloud utility is available on the
target server and the GCS bucket is accessible from it, the direct method will
be used. Otherwise, if either condition is not met, the toolkit will revert to
the transfer method.

#### Cloud Storage FUSE

With Cloud Storage FUSE, you can also pass the location of a Cloud Storage
service account json file. This is useful if your control node doesn't have a
proper instance service account. You should also confirm that the service
account scopes allow you to use Cloud Storage.

To create a new service account:

1. Navigate to your Google Cloud Console.
1. Select the **IAM & Admin** tab > **Service accounts**.
1. Click on **Create Service Account** and chose a relevant name.
1. Select a role that provides the permission that you need, such as
   **Storage Admin**.
1. Click on the "Create Key" button, and download the file in JSON format.

You can then pass the file as a parameter to the deployment:

```bash
--ora-swlib-type gcsfuse --ora-swlib-bucket oracle-swlib --ora-swlib-credentials ~/path_to/service_account.json
```

The toolkit uploads the service account to the server so that Cloud Storage FUSE
can use it.

#### NFS share

When you use an NFS share, you specify the NFS mount point on the
`ora-swlib-bucket` parameter:

```bash
--ora-swlib-type nfs --ora-swlib-bucket 192.168.0.250:/my_nfs_export
```

### Validating Media

You can validate that you have correctly staged all of the required installation
files by using the `check-swlib.sh` script, which validates the files based
on name, size, and MD5 message digest. To validate the media, specify the GCS
software bucket where the software is staged and the Oracle software version
that you are installing. The version default is 19.3.0.0.0.

Example of a successful media validation:

```bash
$ ./check-swlib.sh --ora-swlib-bucket gs://oracle-software --ora-version 19.3.0.0.0

Running with parameters from command line or environment variables:

ORA_SWLIB_BUCKET=gs://oracle-software
ORA_VERSION=19.3.0.0.0

Found V982063-01.zip : Oracle Database 19.3.0.0.0 for Linux x86-64
        file size matches (3059705302), md5 matches (1858bd0d281c60f4ddabd87b1c214a4f).

Found V982068-01.zip : Oracle Grid Infrastructure 19.3.0.0.0 for Linux x86-64
        file size matches (2889184573), md5 matches (b7c4c66f801f92d14faa0d791ccda721).

Found p29859737_190000_Linux-x86-64.zip : Oracle 19c DB RU patch 29859737 for Linux x86-64
        file size matches (498214157), md5 matches (3b017f517341df5b35e9fbd90f1f49aa).

Found p29800658_190000_Linux-x86-64.zip : Oracle 19c GI RU patch 29800658 for Linux x86-64
        file size matches (1365811472), md5 matches (13c0041a5ea7eb9fad4725d2136da627).

Found p29699097_190000_Linux-x86-64.zip : COMBO OF OJVM RU COMPONENT 19.4.0.0.190716 + GI RU 19.4.0.0.190716
        file size matches (1986870968), md5 matches (2206c8a2431eb6fa0c4f7dd5aa7a58b2).

Found p30133178_190000_Linux-x86-64.zip : COMBO OF OJVM RU COMPONENT 19.5.0.0.191015 GI RU 19.5.0.0.191015
        file size matches (2004604850), md5 matches (4189caeae850a7c4191fdd3fa4c0af6a).

Found p30463609_190000_Linux-x86-64.zip : COMBO OF OJVM RU COMPONENT 19.6.0.0.200114 GI RU 19.6.0.0.200114
        file size matches (2308492999), md5 matches (0b2f7ae16f623e8d26905ae7ba600b06).

Found p6880880_190000_Linux-x86-64.zip : OPatch Utility
        file size matches (111682884), md5 matches (ad583938cc58d2e0805f3f9c309e7431).
```

Example of a failed media validation:

```bash
$ ./check-swlib.sh --ora-swlib-bucket gs://oracle-software --ora-version 12.2.0.1.0
Running with parameters from command line or environment variables:

ORA_SWLIB_BUCKET=gs://oracle-software
ORA_VERSION=12.2.0.1.0

Found V839960-01.zip : Oracle Database 12.2.0.1.0 for Linux x86-64
        file size matches (3453696911), md5 matches (1841f2ce7709cf909db4c064d80aae79).

Found V840012-01.zip : Oracle Grid Infrastructure 12.2.0.1.0 for Linux x86-64 for Linux x86-64
        file size matches (2994687209), md5 matches (ac1b156334cc5e8f8e5bd7fcdbebff82).

Found p29252035_122010_Linux-x86-64.zip : Combo Of OJVM Update Component 12.2.0.1.190416 + DB Update 12.2.0.1.190416 patch 29252035 for Linux x86-64
        file size matches (514033994), md5 matches (1a645dd57d06795a966a8882cc59243e).

Found p29301687_122010_Linux-x86-64.zip : Grid Infrastructure Release Update 12.2.0.1.190416 patch 29301687 for Linux x86-64
        file size matches (1736326653), md5 matches (1648e66220987dae6ecd757bc9f424ba).

Found p25078431_122010_Linux-x86-64.zip : ACFS MODULE ORACLEACFS.KO FAILS TO LOAD ON OL7U3 SERVER WITH RHCK (Patch) patch 25078431 for Linux x86-64
        file size matches (537299043), md5 matches (84ad563860b583fdd052bca0dcc33939).

Object gs://oracle-software/p29252072_122010_Linux-x86-64.zip COMBO OF OJVM RU COMPONENT 12.2.0.1.190416 + 12.2.0.1.190416 GIAPR2019RU not found: CommandException: One or more URLs matched no objects.

Found p29699173_122010_Linux-x86-64.zip : COMBO OF OJVM RU COMPONENT 12.2.0.1.190716 + 12.2.0.1.190716 GIJUL2019RU
        file size matches (2096740052), md5 matches (d5955b2e975752d3cd164a3e7db9aaaf).

Found p30133386_122010_Linux-x86-64.zip : COMBO OF OJVM RU COMPONENT 12.2.0.1.191015 12.2.0.1.191015 GIOCT2019RU
        file size matches (1925393453), md5 matches (25c30defbcc6e470e574fb3e16abb1d2).

Found p30463673_122010_Linux-x86-64.zip : COMBO OF OJVM RU COMPONENT 12.2.0.1.200114 12.2.0.1.200114 GIJAN2020RU
        file size matches (2135739707), md5 matches (04e26701ecdf04898abe363cdbeaaa40).

Found p6880880_122010_Linux-x86-64.zip : OPatch Utility
        size does not match (remote: 118408624, expected: 111682884), md5 does not match (remote: b8e1367997544ab2790c5bcbe65ca805, expected: ad583938cc58d2e0805f3f9c309e7431).
```

## Prerequisite configuration

Create JSON formatted configurations for the data mount devices and optionally
the ASM disk group. They can be stored in files or passed via CLI parameters.

The [host provisioning tool](host-provisioning.md) can configure newly-provisioned
BMS hosts to run the toolkit installer, including authentication, Internet access,
and local mount points.

### Data mount configuration

In the data mount configuration, you specify disk device attributes for:

- Oracle software installation, which is usually mounted at `/u01`
- Oracle diagnostic destination, which is usually mounted at `/u02`

Specify the block devices (actual devices, not
partitions), the mount point names, the file system types, and the mount options
in valid JSON format.

When you run the toolkit, specify the path to the configuration file by using
the `--ora-data-mounts` command line option. The file path can be relative or
fully qualified. The file name defaults to `data_mounts_config.json`.
Alternatively, pass the file content directly as JSON using `--ora-data-mounts-json` parameter.
If both are present, `--ora-data-mounts-json` takes precedence.

The following example shows a properly formatted JSON data mount configuration file:

```json
[
  {
    "purpose": "software",
    "blk_device": "/dev/mapper/3600a098038314352502b4f782f446138",
    "name": "u01",
    "fstype": "xfs",
    "mount_point": "/u01",
    "mount_opts": "nofail"
  },
  {
    "purpose": "diag",
    "blk_device": "/dev/mapper/3600a098038314352502b4f782f446230",
    "name": "u02",
    "fstype": "xfs",
    "mount_point": "/u02",
    "mount_opts": "nofail"
  }
]
```

### ASM disk group configuration

Installing Grid Infrastructure and using ASM is the default, but is not
mandatory. Whether GI is installed and ASM used is based on the value of the
`--ora-disk-mgmt` command line option.

Specify `ASMLIB` to use the Oracle ASMLib library or `ASMUDEV` to use ASM
with the Linux Udev device manager. `ASMUDEV` is the default.

In the ASM disk group configuration, specify the disk group names, the disk
names, and the associated block devices (the actual devices, not partitions) in a
valid JSON format.

When you run the toolkit, specify the path to the configuration file by using
the `--ora-asm-disks` command line option. The file path can be relative or fully qualified. The file
name defaults to `ask_disk_config.json`. Alternatively, pass the file content directly
as a JSON using `--ora-asm-disks-json` parameter. If both are present,
`--ora-asm-disks-json` takes precedence.

The following example shows a properly formatted JSON ASM disk group configuration file:

```json
[
  {
    "diskgroup": "DATA",
    "disks": [
      { "name": "DATA_1234567538", "blk_device": "/dev/mapper/3600a098038314344382b4f1234567538" },
      { "name": "DATA_123456752D", "blk_device": "/dev/mapper/3600a098038314344382b4f123456752d" },
      { "name": "DATA_1234567541", "blk_device": "/dev/mapper/3600a098038314344382b4f1234567541" },
      { "name": "DATA_1234567542", "blk_device": "/dev/mapper/3600a098038314344382b4f1234567542" },
      { "name": "DATA_1234567543", "blk_device": "/dev/mapper/3600a098038314344382b4f1234567543" },
      { "name": "DATA_1234567544", "blk_device": "/dev/mapper/3600a098038314344382b4f1234567544" }
    ]
  },
  {
    "diskgroup": "RECO",
    "disks": [
      { "name": "RECO_1234567546", "blk_device": "/dev/mapper/3600a098038314344382b4f1234567546" },
      { "name": "RECO_1234567547", "blk_device": "/dev/mapper/3600a098038314344382b4f1234567547" },
      { "name": "RECO_1234567548", "blk_device": "/dev/mapper/3600a098038314344382b4f1234567548" }
    ]
  }
]
```

### Installation using Linux file systems (without Grid Infrastructure and ASM)

Installing and creating databases that use XFS Linux file systems for database
storage is also possible. To use Linux file systems, include the
`--ora-disk-mgmt FS` command line option.

When disk management is set to `FS`, the Grid Infrastrure software is not
installed.

If required, add additional block devices to be formatted and used to the data
mounts JSON. For example:

```json
[
  {
    "purpose": "software",
    "blk_device": "/dev/disk/by-id/google-oracle-disk-1",
    "name": "u01",
    "fstype": "xfs",
    "mount_point": "/u01",
    "mount_opts": "nofail"
  },
  {
    "purpose": "data",
    "blk_device": "/dev/disk/by-id/google-oracle-data-1",
    "name": "u02",
    "fstype": "xfs",
    "mount_point": "/u02",
    "mount_opts": "nofail"
  },
  {
    "purpose": "reco",
    "blk_device": "/dev/disk/by-id/google-oracle-reco-1",
    "name": "u03",
    "fstype": "xfs",
    "mount_point": "/u03",
    "mount_opts": "nofail"
  }
]
```

Other installation script parameters such as `--ora-data-destination`,
`--ora-reco-destination`, or `--backup-dest` can then reference these Linux
mount points.

Example installation command using Linux file systems for all storage:

```bash
./install-oracle.sh \
  --instance-ip-addr ${INSTANCE_IP_ADDR} \
  --ora-version 19 \
  --ora-swlib-bucket gs://[cloud-storage-bucket-name] \
  --ora-disk-mgmt FS \
  --ora-data-mounts data_mounts_config.json \
  --ora-data-destination "/u02/app/oracle/oradata" \
  --ora-reco-destination "/u03/app/oracle/fast_recovery_area" \
  --backup-dest "/u04/app/oracle/backups"
```

### Specifying LVM logical volumes

In addition to the raw devices, you can also specify LVM logical volumes by
using the following format:

`"blk_device": "/dev/mapper/oracle-data"`

## Configuring Installations

You run the toolkit by using the `install-oracle.sh` shell script.

**IMPORTANT**: From the control node, run the toolkit shell scripts by using a
Linux user account that has the necessary SSH permissions and privileges on the
target database server(s).

You need to specify the Cloud Storage bucket that contains the Oracle software
and the backup destination for an initial RMAN backup. Running with the --help
argument displays the list of available options.

Although the toolkit provides defaults for just about everything, in most cases,
you need to customize your installation to some degree. Your customizations can
range from simple items, such as the name of a database or the associated
database edition, to less frequently adjusted items, such as ASM disk groups
configurations. Regardless, the toolkit allows you to specify overrides for most
configuration parameters.

As well as creating the initial database, the toolkit implements and schedules a
simple RMAN backup script. You can adjust the backup parameters either before or
after running the toolkit, as required.

### Configuration defaults

Most parameters have default values, so you only need to specify them when you
need a different value. The parameter values that the toolkit uses are echoed
during execution so you can confirm the configuration.

The complete list of parameters and their values are provided in the [Parameters
section](#parameters).

### Oracle User Directories

The Oracle convention for naming of file system mounts is **_/pm_**, where
**_p_** is a string constant and **_m_** is a unique key, typically a two digit
integer. The standard string constant for Oracle user file system mounts is the
letter "u".

Following this convention, the toolkit creates the following default file system
mounts:

- **/u01** - For Oracle software. For example, /u01/app/oracle/product.

- **/u02** - For other Oracle files, including software staging and, optionally, the
  Oracle Automatic Diagnostic Repository (ADR).

You don't have to use a separate file system, physical device, or logical volume
for the software staging and other purposes. You can use the single file system,
/u01, or whatever you choose to call it, if you want to.

### Database backup configuration

As a part of installation, the toolkit creates an initial RMAN full database
backup, an archived redo log backup, and sets the initial backup schedule based
on your specifications or the default backup values.

The parameters for configuring your backups are described in [Backup
configuration parameters](#backup-configuration-parameters). The following list shows the
default backup configuration implemented by the toolkit:

- Backup scripts are stored in the directory `/home/oracle/scripts`.
- Associated log files are stored in the directory `/home/oracle/logs`.
- Weekly FULL database LEVEL=0 backups are run at 01:00 on Sundays.
- Daily FULL database LEVEL=1 cumulative incremental backups are run at
  01:00, Monday through Friday.
- Hourly archived redo log backups run at 30 minutes past every hour.
- RMAN backups are written to the Fast Recovery Area (FRA).

The toolkit schedules the backups by using the Linux cron utility under the
Oracle software owner user. You can run the backup scripts as necessary.

After installation is complete, you can adjust any of the attributes of the
backup scheme. You can also replace any and all parts of the initial backup
scheme or the backup script with your own scripts or backup tools.

#### gcsfuse backups

You can use Cloud Storage buckets for Oracle rman scripts to write and store backups.

#### Cloud Storage bucket

- A [Cloud Storage](https://cloud.google.com/storage/docs/introduction) bucket.
- [Cloud Storage FUSE](https://cloud.google.com/storage/docs/gcs-fuse), an open
  source [FUSE](http://fuse.sourceforge.net/) adapter that allows you to mount
  Cloud Storage buckets as file systems on Linux or macOS systems.
- Review backup [Cloud Storage bucket options](https://cloud.google.com/storage).

To use a Cloud Storage bucket for your backups, you need to follow the steps below:

- Identify the Compute Engine instance service account. Go to:
  - [Compute Engine VM instances](https://console.cloud.google.com/compute/instances)
  - Select the Oracle Server to configure
  - Identify Service account, for example: abcdefg-compute@developer.gserviceaccount.com
  - Access the Cloud Storage bucket [Cloud Storage](https://console.cloud.google.com/storage/browser)
  - Select the bucket that will store the backups, click on the three dots on the far right of the bucket selected and click Edit access.
  - Click on Add Principal and add the identified Compute Engine VM instance service account from the Oracle Server to configure.
  - In the Role drop down select Storage Legacy Bucket Owner and save.

#### Cloud Storage FUSE

- With Cloud Storage FUSE, you can use the auth service account of the Compute Engine instance to access and mount the Cloud Storage bucket.
- Follow the steps above on Cloud Storage bucket.
- You can verify the auth service account by running the command as the Example below:
  - `gcloud compute ssh gce_vm_instance_name --command="sudo su -c 'gcloud auth list'"`
  - You should see the same account in the auth list as the one used in the Cloud Storage bucket configuration steps.

### Parameters

The following sections document the parameters, organized by installation task
and then by the attribute that you use the parameter to specify.

Most attributes can be specified by using command-line flags.
Command-line commands are presented in lower case letters and are preceded by
two dashes.

Default values for the parameters are shown in bold letters.

#### Target environment parameters

<table>
<thead>
<tr>
<th>Attribute</th>
<th>Parameter options</th>
<th>Range of Values</th>
<th>Notes</th>
</tr>
</thead>
<tbody>
<tr>
<td>Target server IP address</td>
<td><p><pre>
INSTANCE_IP_ADDR
<br>
--instance-ip-addr
</pre></p>
</td>
<td>user defined - no default</td>
<td>The IP address of the target server to host the Oracle software and
database.<br>
Applicable for Oracle "single instance" installations.</td>
</tr>
<tr>
<td>Primary server IP address</td>
<td><p><pre>
PRIMARY_IP_ADDR
<br>
--primary-ip-addr
</pre></p>
</td>
<td>user defined - no default</td>
<td>The IP address of the primary server to use as source of primary database
for Data Guard configuration.<br>
Applicable for Oracle "single instance" installations.</td>
</tr>
<tr>
<td>Target server host name</td>
<td><p><pre>
INSTANCE_HOSTNAME
<br>
--instance-hostname
</pre></p>
</td>
<td>user defined<br>
INSTANCE_IP_ADDR</td>
<td>Optional hostname for the target server. Defaults to value of
INSTANCE_IP_ADDR. Specifying a hostname adds clarity to log and debug
files. </td>
</tr>
<tr>
<td>User on target server </td>
<td><p><pre>
INSTANCE_SSH_USER
<br>
--instance-ssh-user
</pre></p>
</td>
<td>user defined<br>
current user</td>
<td>Remote user with connectivity (including privilege escalation capabilities)
on target server.</td>
</tr>
<tr>
<td>Private key file for ssh connectivity to target server</td>
<td><p><pre>
INSTANCE_SSH_KEY
<br>
--instance-ssh-key
</pre></p>
</td>
<td>user defined<br>
~/.ssh/id_rsa</td>
<td></td>
</tr>
<tr>
<td>Ansible inventory file name</td>
<td><p><pre>
No environment variable
<br>
--inventory-file
</pre></p>
</td>
<td>user defined<br>
oracle-toolkit generated</td>
<td>Optional Ansible inventory file name. If not supplied, the toolkit
generates a filename.</td>
</tr>
</tbody>
</table>

#### Software installation parameters

<table>
<thead>
<tr>
<th>Attribute</th>
<th>Parameters</th>
<th>Parameter Values</th>
<th>Notes</th>
</tr>
</thead>
<tbody>
<tr>
<td>Oracle version</td>
<td><p><pre>
ORA_VERSION
--ora-version
</pre></p>
</td>
<td>19.3.0.0.0<br>
18.0.0.0.0<br>
12.2.0.1.0<br>
12.1.0.2.0<br>
11.2.0.4.0</td>
<td>All mainstream major releases.</td>
</tr>
<tr>
<td>Oracle software release (patch level)</td>
<td><p><pre>
ORA_RELEASE
--ora-release
</pre></p>
</td>
<td>A fully-qualified release number, such as 19.7.0.0.200414<br>
Default: latest</td>
<td>Oracle patch level to apply as part of installation.</td>
</tr>
<tr>
<td>Oracle edition</td>
<td><p><pre>
ORA_EDITION
--ora-edition
</pre></p>
</td>
<td>EE<br>
SE, for 11.2.0.4.0 only<br>
SE2, for 12.1.0.2.0 and above<br>
FREE, for Oracle Database Free</td>
<td>SE or SE2 depending on the Oracle version chosen.</td>
</tr>
<tr>
<td>Software library type</td>
<td><p><pre>
ORA_SWLIB_TYPE
--ora-swlib-type
</pre></p>
</td>
<td>GCS<br>
GCSDIRECT<br>
GCSTRANSFER<br>
GCSFUSE<br>
NFS</td>
<td>Remote storage type acting as a software library where the required
installation media is stored.</td>
</tr>
<tr>
<td>Software library location</td>
<td><p><pre>
ORA_SWLIB_BUCKET
--ora-swlib-bucket
</pre></p></td>
<td>user defined - no default<br>
Example: gs://oracle-software</td>
<td>GCS bucket where the required base software and patches have been
downloaded and staged.<br>
<br>
Only used when ORA_SWLIB_TYPE=GCS|GCSDIRECT|GCSTRANSFER.</td>
</tr>
<tr>
<td>Software library path</td>
<td><p><pre>
ORA_SWLIB_PATH
--ora-swlib-path
</pre></p></td>
<td>user defined<br>
/u01/swlib</td>
<td>Path where the required base software and patches have been downloaded and
staged.<br>
<br>
Not used when ORA_SWLIB_TYPE=GCS|GCSDIRECT|GCSTRANSFER.</td>
</tr>
<tr>
<td>Service account key file</td>
<td><p><pre>
ORA_SWLIB_CREDENTIALS
--ora-swlib-credentials
</pre></p></td>
<td>user defined - no default</td>
<td>Service account key file name. Only used when ORA_SWLIB_TYPE=GCSFUSE.</td>
</tr>
<tr>
<td>Storage configuration</td>
<td><br>
<p><pre>
ORA_DATA_MOUNTS
--ora-data-mounts
</pre></p></td>
<td>user defined<br>
data_mounts_config.json</td>
<td>Properly formatted JSON file providing mount and file system details for
local mounts including installation location for the Oracle software and
the location for Oracle diagnostic (ADR) directories. See <a
href="#data-mount-configuration">Data mount configuration</a>.</td>
</tr>
<tr>
<td>Storage configuration</td>
<td><br>
<p><pre>
ORA_DATA_MOUNTS_JSON
--ora-data-mounts-json
</pre></p></td>
<td>user defined<br>
</td>
<td>Properly formatted JSON providing mount and file system details for
local mounts including installation location for the Oracle software and
the location for Oracle diagnostic (ADR) directories. See <a
href="#data-mount-configuration">Data mount configuration</a>.</td>
</tr>
<tr>
<td>Software unzip location</td>
<td><p><pre>
ORA_STAGING
--ora-staging
</pre></p></td>
<td>user defined<br>
ORA_SWLIB_PATH</td>
<td>Working area for unzipping and staging software and installation
files.<br>
<br>
Should have at least 16GB of available free space.</td>
</tr>
<tr>
<td>Listener Name</td>
<td><p><pre>
ORA_LISTENER_NAME
--ora-listener-name
</pre></p></td>
<td>user defined<br>
LISTENER</td>
<td></td>
</tr>
<tr>
<td>Listener Port</td>
<td><p><pre>
ORA_LISTENER_PORT
--ora-listener-port
</pre></p></td>
<td>user defined<br>
1521</td>
<td></td>
</tr>
<tr>
<td>Preferred NTP server</td>
<td><p><pre>
NTP_PREF
--ntp-pref
</pre></p></td>
<td>user defined - no default</td>
<td>Preferred NTP server to use in /etc/chrony.conf.<br>
<br>
Optional: set only if you need to manually define an NTP server, instead of
relying on the OS defaults.</td>
</tr>
<tr>
<td>Swap device</td>
<td><p><pre>
SWAP_BLK_DEVICE
--swap-blk-device
</pre></p></td>
<td>user defined - no default</td>
<td>Swap device to optionally create.<br>
<br>
Optional: set if you would like a swap partition and swap file created.</td>
</tr>
<tr>
<td>Artifact Registry repository</td>
<td><p><pre>
--ar-repo-url
</pre></p></td>
<td>Empty: don't configure Artifact Registry</td>
<td>Base URL of the registry location.  When provided, the installer configures
the system to use these repositories for `BaseOS` and `AppStream` instead of
public mirrors.<br>
To avoid hangs with default OS configurations, this parameter will also mark
existing YUM repositories as `disabled`.<br>
This parameter has no effect with Red Hat Enterprise Linux, where Google Cloud
already provides a local mirror, and that a remote registry is unnecessary.
Not supported with Free Edition, where all software is fetched directly from
vendor repositories.</td>
</tr>
</tbody>
</table>

#### Storage configuration parameters

<table>
<thead>
<tr>
<th>Attribute</th>
<th>Parameters</th>
<th>Parameter Values</th>
<th>Notes</th>
</tr>
</thead>
<tbody>
<tr>
<td>ASM disk management</td>
<td><p><pre>
ORA_DISK_MGMT
--ora-disk-mgmt
</pre></p></td>
<td>asmlib<br>
asmudev<br>
fs</td>
<td>ASMlib option is applicable to Oracle Linux as RHEL implementation requires
Red Hat support. See MOS Doc ID: 1089399.1</td>
</tr>
<tr>
<td>Grid user role separation</td>
<td><p><pre>
ORA_ROLE_SEPARATION
--ora-role-separation
</pre></p></td>
<td>true<br>
false</td>
<td>Role separation means that the Grid Infrastructure is owned by the OS user
"grid" instead of the OS user "oracle".</td>
</tr>
<tr>
<td>Data file destination (ASM disk group or file system location)</td>
<td><p><pre>
ORA_DATA_DESTINATION
--ora-data-destination
</pre></p></td>
<td>user defined<br>
DATA</td>
<td>Default location for DB files for initial database.</td>
</tr>
<tr>
<td>Recovery area destination (ASM disk group or file system location)</td>
<td><p><pre>
ORA_RECO_DESTINATION
--ora-reco-destination
</pre></p></td>
<td>user defined<br>
RECO</td>
<td>Default location for FRA files for initial database.</td>
</tr>
<tr>
<td>ASM disk group configuration</td>
<td><p><pre>
ORA_ASM_DISKS
--ora-asm-disks
</pre></p></td>
<td>user defined<br>
asm_disk_config.json</td>
<td>Name of an ASM configuration file that contains ASM disk groups definitions in
valid JSON format. See <a href="#asm-disk-group-configuration">ASM disk group configuration</a>.</td>
</tr>
<tr>
<td>ASM disk group configuration</td>
<td><p><pre>
ORA_ASM_DISKS_JSON
--ora-asm-disks-json
</pre></p></td>
<td>user defined<br></td>
<td>ASM disk groups definition in a valid JSON format.
See <a href="#asm-disk-group-configuration">ASM disk group configuration</a>.</td>
</tr>
</tbody>
</table>

#### Database configuration parameters

<table>
<thead>
<tr>
<th>Attribute</th>
<th>Parameters</th>
<th>Parameter Values</th>
<th>Notes</th>
</tr>
</thead>
<tbody>
<tr>
<td>Database name</td>
<td><p><pre>
ORA_DB_NAME
--ora-db-name
</pre></p></td>
<td>user defined<br>
ORCL</td>
<td>Up to 8 characters. Must start with a letter. Other 7 characters can
include alphanumeric characters, underscore, number sign, and
dollar sign</td>
</tr>
<tr>
<td>Database domain</td>
<td><p><pre>
ORA_DB_DOMAIN
--ora-db-domain
</pre></p></td>
<td>user defined<br>
.world</td>
<td>String of name components up to 128 characters long including periods.</td>
</tr>
<tr>
<td>Character set</td>
<td><p><pre>
ORA_DB_CHARSET
--ora-db-charset
</pre></p></td>
<td>user defined<br>
AL32UTF8</td>
<td></td>
</tr>
<tr>
<td>National character set</td>
<td><p><pre>
ORA_DB_NCHARSET
--ora-db-ncharset
</pre></p></td>
<td>user defined<br>
AL16UTF16</td>
<td></td>
</tr>
<tr>
<td>Database compatibility setting</td>
<td><p><pre>
COMPATIBLE_RDBMS
--compatible-rdbms
</pre></p></td>
<td>user defined<br>
Oracle version</td>
<td>Defaults to the value of ORA_VERSION.</td>
</tr>
<tr>
<td>Container database</td>
<td><p><pre>
ORA_DB_CONTAINER
--ora-db-container
</pre></p></td>
<td>true<br>
false</td>
<td>Not applicable for release 11.2.0.4.</td>
</tr>
<tr>
<td>PDB name</td>
<td><p><pre>
ORA_PDB_NAME
--ora-pdb-name-prefix
</pre></p></td>
<td>PDB</td>
<td>Not applicable for release 11.2.0.4.</td>
</tr>
<tr>
<td>PDB count</td>
<td><p><pre>
ORA_PDB_COUNT
--ora-pdb-count
</pre></p></td>
<td>1</td>
<td>If greater than 1, a numeric is appended to each PDB name.<br>
<br>
The PDB count may have Oracle licensing implications.<br>
<br>
Not applicable for release 11.2.0.4.</td>
</tr>
<tr>
<td>Database type</td>
<td><p><pre>
ORA_DB_TYPE
--ora-db-type
</pre></p></td>
<td>MULTIPURPOSE<br>
DATA_WAREHOUSING<br>
OLTP</td>
<td></td>
</tr>
<tr>
<td>Redo log size</td>
<td><p><pre>
ORA_REDO_LOG_SIZE
--ora-redo-log-size
</pre></p></td>
<td>user defined<br>
100MB</td>
<td></td>
</tr>
<tr>
<td>PGA target</td>
<td><p><pre>
ORA_PGA_TARGET_MB
--ora-pga-target-mb
</pre></p></td>
<td>150</td>
<td>Oracle aggregate private memory target</td>
</tr>
<tr>
<td>SGA target</td>
<td><p><pre>
ORA_SGA_TARGET_MB
--ora-sga-target-mb
</pre></p></td>
<td>45% of total memory</td>
<td>Oracle shared memory, backed by a hugepage allocation.</td>
</tr>
</tbody>
</table>

#### RAC configuration parameters

<table>
<thead>
<tr>
<th>Attribute</th>
<th>Parameters</th>
<th>Parameter Values</th>
<th>Notes</th>
</tr>
</thead>
<tbody>
<tr>
<td>Cluster type</td>
<td><p><pre>
CLUSTER_TYPE
--cluster-type
</pre></p></td>
<td>
NONE<br>
RAC<br>
DG
</td>
<td>Specify RAC to provision Real Application Clusters. Use DG for standby installation.
Otherwise, a Single Instance installation is performed.</td>
</tr>
<tr>
<td>Cluster configuration file</td>
<td><p><pre>
CLUSTER_CONFIG
--cluster-config
</pre></p></td>
<td>user defined; defaults to<br>
<pre>cluster_config.json</pre></td>
<td>A file name for the cluster configuration JSON.<br>
Use the file to specify the RAC SCAN listener name, port, IPs, nodes, etc.</td>
</tr>
<tr>
<td>Cluster configuration JSON</td>
<td><p><pre>CLUSTER_CONFIG_JSON
--cluster-config-json
</pre></p></td>
<td>user defined</td>
<td>Cluster configuration JSON. Use it to specify the RAC SCAN listener name, port, IPs, nodes, etc.
on the CLI instead of the CLUSTER_CONFIG file.
</td>
</tr>
</tbody>
</table>

#### Backup configuration parameters

<table>
<thead>
<tr>
<th>Attribute</th>
<th>Parameters</th>
<th>Parameter Values</th>
<th>Notes</th>
</tr>
</thead>
<tbody>
<tr>
<td>RMAN backup destination</td>
<td><p><pre>
BACKUP_DEST
--backup-dest
</pre></p></td>
<td>user defined - no default<br>
Example: +RECO</td>
<td>Disk group name, filesystem  or NFS file share location. Can include formatting options,
such as "/u02/db_backups/ORCL_%I_%T_%s_%p.bak", for example.<br>
<br>
When writing to a non-ASM disk group location, include a valid RMAN format
specification to ensure file name uniqueness, such as the example string
shown above.<br>
<br>
If you are writing to a local file system, the
directory does not have to exist, but initial backups will fail if the
destination is not available or writeable.<br>
<br>
If you are writing to a NFS share, the NFS share directory uid default group is 801 and gid is 809.
The NFS exported filesystem  should be configured with the default IDs or match your ownership customization.
The configuration is done by the storage manager or systems engineer providing the remote filesystem.
The NFS option defaults to nfsv3
<br>
If you are writing to a gcsfuse bucket, the /mnt must be used as parameter.<br>
If you would rather not schedule backups at all, set to an empty string "".
The toolkit will schedule a job to periodically delete accumulated archivelog files.
</td>
</tr>
<tr>
<td>NFS backup configuration</td>
<td><p><pre>
NFS_BACKUP_CONFIG
--nfs-backup-config
</pre></p></td>
<td>user defined - default nfsv3<br>
Example: nfsv3 </td>
<td>The NFS version of the export shared is defined with this option. The values accepted are `nfsv3` or `nfsv4`.
</td>
</tr>
<tr>
<td>NFS backup mount</td>
<td><p><pre>
NFS_BACKUP_MOUNT
--nfs-backup-mount
</pre></p></td>
<td>user defined - no default<br>
Example: remote-nfs-server:/nfs/backup </td>
<td>The nfs remote share expected as [remote-nfs-server-name]:[/remote-share-mount]
</td>
</tr>
<tr>
<td>GCS backup configuration</td>
<td><p><pre>
GCS_BACKUP_CONFIG
--gcs-backup-config
</pre></p></td>
<td>user defined - no default<br>
Example: manual</td>
<td>The manual option requires all the steps from Cloud Storage Bucket and Cloud Storage Fuse for a successful configuration. The manual option requires the --gcs-backup-bucket parameter.</td>
</tr>
<tr>
<td>GCS backup bucket</td>
<td><p><pre>
GCS_BACKUP_BUCKET
--gcs-backup-bucket
</pre></p></td>
<td>user defined - no default<br>
Example:  gs://[cloud-storage-bucket-name] </td>
<td>The bucket name expected as  gs://[cloud-storage-bucket-name].</td>
</tr>
<tr>
<td>GCS backup bucket</td>
<td><p><pre>
GCS_BACKUP_TEMP_PATH
--gcs-backup-temp-path
</pre></p></td>
<td>user defined - /u01/gcsfusetmp <br>
Example:  /u01/gcsfusetmp </td>
<td>The temporary directory used by gcsfuse to write temporarily locally. The directory requires 2GB of free space for every backup channel.</td>
</tr>
<tr>
<td>RMAN full DB backup redundancy</td>
<td><p><pre>
BACKUP_REDUNDANCY
--backup-redundancy
</pre></p></td>
<td>user defined field<br>
2</td>
<td>An integer that specifies the number of full backups to keep.</td>
</tr>
<tr>
<td>RMAN archived redo log backup redundancy</td>
<td><p><pre>
ARCHIVE_REDUNDANCY
--archive-redundancy
</pre></p></td>
<td>user defined field<br>
2</td>
<td>An integer that specifies the number of times to redundantly backup
archived redo logs into an RMAN backup set.</td>
</tr>
<tr>
<td>Archived redo logs online retention days</td>
<td><p><pre>
ARCHIVE_ONLINE_DAYS
--archive-online-days
</pre></p></td>
<td>user defined field<br>
7</td>
<td>Archived redo logs are only deleted from disk when they are older than this
number of days.<br>
<br>
(And have been backed up with the specified redundancy.)</td>
</tr>
<tr>
<td>Day(s) of week for full DB backup (RMAN level=0)</td>
<td><p><pre>
BACKUP_LEVEL0_DAYS
--backup-level0-days
</pre></p></td>
<td>user defined<br>
0</td>
<td>Day(s) of week in cron format to be used for cron creation.</td>
</tr>
<tr>
<td>Day(s) of the week for incremental full DB backup (RMAN level=1)</td>
<td><p><pre>
BACKUP_LEVEL1_DAYS
--backup-level1-days
</pre></p></td>
<td>user defined<br>
1-6</td>
<td>Day(s) of week in cron format to be used for cron creation.</td>
</tr>
<tr>
<td>Start hour for RMAN full DB backups</td>
<td><p><pre>
BACKUP_START_HOUR
--backup-start-hour
</pre></p></td>
<td>user defined<br>
01</td>
<td>Hour in 24hour format.<br>
<br>
Used in cron for RMAN full (level=0 and level=1) backups.</td>
</tr>
<tr>
<td>Start minute for RMAN DB full backups</td>
<td><p><pre>
BACKUP_START_MIN
--backup-start-min
</pre></p></td>
<td>user defined<br>
00</td>
<td>Minute in XX format.<br>
<br>
Used in cron for RMAN full (level=0 and level=1) backups.</td>
</tr>
<tr>
<td>Start minute for archived redo log RMAN backups.</td>
<td><p><pre>
ARCHIVE_BACKUP_MIN
--archive-backup-min
</pre></p></td>
<td>user defined<br>
30</td>
<td>Minute in XX format.<br>
<br>
Used in cron for RMAN full (level=0 and level=1) backups.</td>
</tr>
<tr>
<td>Script location</td>
<td><p><pre>
BACKUP_SCRIPT_LOCATION
--backup-script-location
</pre></p></td>
<td>user defined<br>
/home/oracle/scripts</td>
<td>Location for storing the provided RMAN backup scripts and other provided
database scripts.<br>
<br>
Because only a handful of small text (.sh) files
are provided, the freespace requirements for this directory is
minimal.</td>
</tr>
<tr>
<td>Log file location</td>
<td><p><pre>
BACKUP_LOG_LOCATION
--backup-log-location
</pre></p></td>
<td>user defined<br>
/home/oracle/logs</td>
<td>Location for storing log and output files from the provided RMAN backup
scripts.<br>
<br>
Backup and log files are relatively small and hence the freespace
requirements for this directory is minimal.</td>
</tr>
</tbody>
</table>

#### Additional operational parameters

<table>
<thead>
<tr>
<th>Attribute</th>
<th>Parameters</th>
<th>Parameter Values</th>
<th>Notes</th>
</tr>
</thead>
<tbody>
<tr>
<td>Command help</td>
<td><p><pre>
--help
</pre></p></td>
<td></td>
<td>Display usage and all possible command line arguments.</td>
</tr>
<tr>
<td>Validate parameter definitions</td>
<td><p><pre>
--validate
</pre></p></td>
<td></td>
<td>Validate supplied parameters for such things as conformity to expected
input types and exit. Nothing is installed or changed on the target
server.</td>
</tr>
<tr>
<td></td>
<td><p><pre>
--check-instance
</pre></p></td>
<td></td>
<td>Run the "check-instance.yml" playbook only.</td>
</tr>
<tr>
<td></td>
<td><p><pre>
--prep-host
</pre></p></td>
<td></td>
<td>Run the "prep-host.yml" playbook only.</td>
</tr>
<tr>
<td></td>
<td><p><pre>
--install-sw
</pre></p></td>
<td></td>
<td>Run the "install-sw.yml" playbook only.</td>
</tr>
<tr>
<td></td>
<td><p><pre>
--no-patch
</pre></p></td>
<td></td>
<td>Install the base release, and do not apply patch set updates.  Use in conjunction with <a href="#patching">patching</a> functionality to apply patches post-installation.</td>
</tr>
<tr>
<td></td>
<td><p><pre>
--config-db
</pre></p></td>
<td></td>
<td>Run the "config-db.yml" playbook only.</td>
</tr>
<tr>
<td></td>
<td><p><pre>
--skip-database-config
</pre></p></td>
<td></td>
<td>Run all other playbooks but skip "config-db.yml", so that no database
instance is created.</td>
</tr>
<tr>
<td></td>
<td><p><pre>
--debug
</pre></p></td>
<td></td>
<td>Run with the Ansible debugging flag enabled.  With debugging
enabled, passwords appear in logfiles.</td>
</tr>
<tr>
<td></td>
<td><p><pre>
--db-password-secret
</pre></p></td>
<td></td>
<td>Google Cloud Secret Manager resource path containing the password to be used for both the Oracle SYS and SYSTEM users. Expected format: "projects/your-project/secrets/your-secret-name/versions/your-version</td>
</tr>
<tr>
<td></td>
<td><p><pre>
--install-workload-agent
</pre></p></td>
<td></td>
<td>Whether to install <a href="https://cloud.google.com/compute/docs/instances/agent-for-compute-workloads">Google Cloud Agent for Compute Workloads</a></td>
</tr>
<tr>
<td></td>
<td><p><pre>
--oracle-metrics-secret
</pre></p></td>
<td></td>
<td>Fully qualified name of the Secret Manager secret that stores the Oracle database user's password. This user is specifically configured for the workload-agent to enable metric collection. Expected format: "projects/your-project/secrets/your-secret-name/versions/your-version"</td>
</tr>
<tr>
<td></td>
<td><p><pre>
--data-guard-protection-mode
</pre></p></td>
<td></td>
<td>Specify one of the Data Guard protection modes: "Maximum Performance", "Maximum Availability", or "Maximum Protection".</td>
</tr>
</tbody>
</table>

### Using tags to run or skip specific parts of the toolkit

Tasks in the toolkit are tagged. If required, specific tasks can be run using the --tags option on the command line.

Following is an example of running tasks with oscheck tags from role base-provision in prep-host.yml

```bash
./install-oracle.sh \
--ora-swlib-bucket gs://[cloud-storage-bucket-name] \
--backup-dest "+RECO" \
--ora-swlib-path /u02/swlib/ \
--ora-swlib-type gcs \
--instance-ip-addr ${INSTANCE_IP_ADDR} \
--instance-hostname ${INSTANCE_HOSTNAME} \
-- "--tags oscheck"
```

Example of running tasks with tags validation-scripts from role validation-scripts in config-db.yml

```bash
./install-oracle.sh \
--ora-swlib-bucket gs://[cloud-storage-bucket-name] \
--backup-dest "+RECO" \
--ora-swlib-path /u02/swlib/ \
--ora-swlib-type gcs \
--instance-ip-addr ${INSTANCE_IP_ADDR} \
--instance-hostname ${INSTANCE_HOSTNAME} \
-- "--tags primary-db,validation-scripts"
```

A specific role can also be run using tags. Following is an example of running the base-provision role

```bash
./install-oracle.sh \
--ora-swlib-bucket gs://[cloud-storage-bucket-name] \
--backup-dest "+RECO" \
--ora-swlib-path /u02/swlib/ \
--ora-swlib-type gcs \
--instance-ip-addr ${INSTANCE_IP_ADDR} \
--instance-hostname ${INSTANCE_HOSTNAME} \
-- "--tags base-provision"
```

Tasks can also be skipped using tags. If the toolkit fails while executing a task or a role, the tasks that were completed successfully up to the failure point can be skipped using --skip-tags option. Following is an example of skipping all the tasks defined in base-provision & host-storage roles and executing all other tasks

```bash
./install-oracle.sh \
--ora-swlib-bucket gs://[cloud-storage-bucket-name] \
--backup-dest "+RECO" \
--ora-swlib-path /u02/swlib/ \
--ora-swlib-type gcs \
--instance-ip-addr ${INSTANCE_IP_ADDR} \
--instance-hostname ${INSTANCE_HOSTNAME} \
-- "--skip-tags base-provision,host-storage"
```

### Example Toolkit Execution

In the following example, command-line parameters are used to specify the
following values:

- The IP address of the target instance
- The Oracle release
- The database name

For all other parameters, the default values are accepted.

Note: Unless you specify a hostname on the --instance-hostname command line argument, the target hostname
defaults to the target IP address.

```bash
$ ./install-oracle.sh --ora-swlib-bucket gs://oracle-software --backup-dest +RECO --instance-ip-addr 10.150.0.42 --ora-version 19.3.0.0.0 --ora-db-name PROD1

Inventory file for this execution: ./inventory_files/inventory_10.150.0.42_PROD1.

Running with parameters from command line or environment variables:

ANSIBLE_LOG_PATH=./logs/log_10.150.0.42_PROD1_20200610_160132.log
ARCHIVE_BACKUP_MIN=30
ARCHIVE_ONLINE_DAYS=7
ARCHIVE_REDUNDANCY=2
BACKUP_DEST=+RECO
BACKUP_LEVEL0_DAYS=0
BACKUP_LEVEL1_DAYS=1-6
BACKUP_LOG_LOCATION=/home/oracle/logs
BACKUP_REDUNDANCY=2
BACKUP_SCRIPT_LOCATION=/home/oracle/scripts
BACKUP_START_HOUR=01
BACKUP_START_MIN=00
CLUSTER_CONFIG=cluster_config.json
CLUSTER_TYPE=NONE
INSTANCE_HOSTGROUP_NAME=dbasm
INSTANCE_HOSTNAME=10.150.0.42
INSTANCE_IP_ADDR=10.150.0.42
INSTANCE_SSH_EXTRA_ARGS=''\''-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o IdentityAgent=no'\'''
INSTANCE_SSH_KEY='~/.ssh/id_rsa'
INSTANCE_SSH_USER=janedoe
ORA_ASM_DISKS=asm_disk_config.json
ORA_DATA_DESTINATION=DATA
ORA_DATA_MOUNTS=data_mounts_config.json
ORA_DB_CHARSET=AL32UTF8
ORA_DB_CONTAINER=TRUE
ORA_DB_DOMAIN=world
ORA_DB_NAME=PROD1
ORA_DB_NCHARSET=AL16UTF16
ORA_DB_TYPE=MULTIPURPOSE
ORA_DISK_MGMT=ASMUDEV
ORA_EDITION=EE
ORA_LISTENER_NAME=LISTENER
ORA_LISTENER_PORT=1521
ORA_PDB_COUNT=1
ORA_PDB_NAME_PREFIX=PDB
ORA_RECO_DESTINATION=RECO
ORA_REDO_LOG_SIZE=100MB
ORA_RELEASE=latest
ORA_ROLE_SEPARATION=TRUE
ORA_STAGING=/u01/swlib
ORA_SWLIB_BUCKET=gs://oracle-software
ORA_SWLIB_CREDENTIALS=
ORA_SWLIB_PATH=/u01/swlib
ORA_SWLIB_TYPE='""'
ORA_VERSION=19.3.0.0.0
PB_CHECK_INSTANCE=check-instance.yml
PB_CONFIG_DB=config-db.yml
PB_CONFIG_RAC_DB=config-rac-db.yml
PB_INSTALL_SW=install-sw.yml
PB_LIST='check-instance.yml prep-host.yml install-sw.yml config-db.yml'
PB_PREP_HOST=prep-host.yml
PRIMARY_IP_ADDR=

Ansible params:
Found Ansible at /usr/bin/ansible-playbook

Running Ansible playbook: /usr/bin/ansible-playbook -i ./inventory_files/inventory_10.150.0.42_PROD1 check-instance.yml

PLAY [all] ******************************************************************************************************************************************

TASK [Verify that Ansible on control node meets the version requirements] ***************************************************************************
ok: [10.150.0.42] => {
    "changed": false,
    "msg": "Ansible version is 2.9.9, continuing"
}

TASK [Test connectivity to target instance via ping] ************************************************************************************************
ok: [10.150.0.42]

TASK [Abort if ping module fails] *******************************************************************************************************************
ok: [10.150.0.42] => {
    "changed": false,
    "msg": "The instance has an usable python installation, continuing"
}

TASK [Collect facts from target] ********************************************************************************************************************
ok: [10.150.0.42]

... output truncated for brevity
```

In the following example, command-line arguments are used to specify the Oracle
Standard Edition and to create a non-container database.

```bash
$ ./install-oracle.sh --ora-edition SE2 --ora-db-container false \
 --ora-swlib-bucket gs://oracle-software --backup-dest +RECO \
 --instance-ip-addr 10.150.0.42

Inventory file for this execution: ./inventory_files/inventory_dbserver_ORCL.

Running with parameters from command line or environment variables:

ANSIBLE_LOG_PATH=./logs/log_dbserver_ORCL_20200610_161259.log
ARCHIVE_BACKUP_MIN=30
ARCHIVE_ONLINE_DAYS=7
ARCHIVE_REDUNDANCY=2
BACKUP_DEST=+RECO
BACKUP_LEVEL0_DAYS=0
BACKUP_LEVEL1_DAYS=1-6
BACKUP_LOG_LOCATION=/home/oracle/logs
BACKUP_REDUNDANCY=2
BACKUP_SCRIPT_LOCATION=/home/oracle/scripts
BACKUP_START_HOUR=01
BACKUP_START_MIN=00
CLUSTER_CONFIG=cluster_config.json
CLUSTER_TYPE=NONE
INSTANCE_HOSTGROUP_NAME=dbasm
INSTANCE_HOSTNAME=dbserver
INSTANCE_IP_ADDR=10.150.0.42
INSTANCE_SSH_EXTRA_ARGS=''\''-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o IdentityAgent=no'\'''
INSTANCE_SSH_KEY='~/.ssh/id_rsa'
INSTANCE_SSH_USER=janedoe
ORA_ASM_DISKS=asm_disk_config.json
ORA_DATA_DESTINATION=DATA
ORA_DATA_MOUNTS=data_mounts_config.json
ORA_DB_CHARSET=AL32UTF8
ORA_DB_CONTAINER=false
ORA_DB_DOMAIN=world
ORA_DB_NAME=ORCL
ORA_DB_NCHARSET=AL16UTF16
ORA_DB_TYPE=MULTIPURPOSE
ORA_DISK_MGMT=ASMUDEV
ORA_EDITION=SE2
ORA_LISTENER_NAME=LISTENER
ORA_LISTENER_PORT=1521
ORA_PDB_COUNT=1
ORA_PDB_NAME_PREFIX=PDB
ORA_RECO_DESTINATION=RECO
ORA_REDO_LOG_SIZE=100MB
ORA_RELEASE=latest
ORA_ROLE_SEPARATION=TRUE
ORA_STAGING=/u01/swlib
ORA_SWLIB_BUCKET=gs://oracle-software
ORA_SWLIB_CREDENTIALS=
ORA_SWLIB_PATH=/u01/swlib
ORA_SWLIB_TYPE='""'
ORA_VERSION=19.3.0.0.0
PB_CHECK_INSTANCE=check-instance.yml
PB_CONFIG_DB=config-db.yml
PB_CONFIG_RAC_DB=config-rac-db.yml
PB_INSTALL_SW=install-sw.yml
PB_LIST='check-instance.yml prep-host.yml install-sw.yml config-db.yml'
PB_PREP_HOST=prep-host.yml
PRIMARY_IP_ADDR=

Ansible params:
Found Ansible at /usr/bin/ansible-playbook

Running Ansible playbook: /usr/bin/ansible-playbook -i ./inventory_files/inventory_dbserver_19.3.0.0.0_ORCL   check-instance.yml

PLAY [all] ******************************************************************************************************************************************

TASK [Verify that Ansible on control node meets the version requirements] ***************************************************************************
ok: [dbserver] => {
    "changed": false,
    "msg": "Ansible version is 2.9.9, continuing"
}

TASK [Test connectivity to target instance via ping] ************************************************************************************************
ok: [dbserver]

TASK [Abort if ping module fails] *******************************************************************************************************************
ok: [dbserver] => {
    "changed": false,
    "msg": "The instance has an usable python installation, continuing"
}

TASK [Collect facts from target] ********************************************************************************************************************
ok: [dbserver]

... <output truncated for brevity>
```

The following example shows the error message that is received when an invalid
parameter is specified.

```bash
$ ./install-oracle.sh --ora-version=7.3.4 --ora-swlib-bucket gs://oracle-software --backup-dest +RECO
Incorrect parameter provided for ora-version: 7.3.4
```

## Oracle Database Free Edition Specific Details and Changes

The toolkit supports the installation of the Oracle Database "Free Edition", availble for download from [Oracle Database Free Get Started](https://www.oracle.com/database/free/get-started/).

However, Oracle Database "Free Edition" has a number of differences, including:

1. Does not include Oracle Grid Infrastructure and consequently does not use ASM.
1. Does not support RAC or Data Guard (single-instance only).
1. Only one database/instance can be created per server.
1. Installs via RPM packages only.
1. Requires that the [Oracle Database Preinstallation RPM](https://docs.oracle.com/en/database/oracle/oracle-database/26/ladbi/about-the-oracle-preinstallation-rpm.html) be installed as it is a dependent package.
1. Has CPU, memory, and user-data storage limits – see [Oracle Database Free FAQ – Installation](https://www.oracle.com/database/free/faq/#installation) for details.

Similar to with the other editions, creation of an initial database and implementation of RMAN based backups is possible through this oracle-toolkit for Oracle Database free edition.

### Free Edition Version Details

> NOTE: Beginning with the April 2025 release (23.8), Oracle started using unique filenames for the Free edition, a change from their previous practice of reusing the same RPM filename for new versions.

The toolkit can install _any_ free edition version. This includes both 23ai and 26ai branded versions.

To install a version of **Oracle Database 23ai**, use the command line argument `--ora-version 23`. To install a version of **Oracle AI Database 26ai**, use the command line argument `--ora-version 26`. If the `--ora-version` argument is not provided, then the default will be the latest version of **Oracle AI Database 26ai**.

Which version is actually installed depends on the the actual RPM file in the software library, and possibly the command line switches.

Specific supported versions of Oracle Database 23ai/26ai Free currently includes:

| Product | Specific Version | Software RPM Filename                                   | Preinstall RPM Filename                                   |
| :-----: | :--------------: | :------------------------------------------------------ | :-------------------------------------------------------- |
|  26ai   |   23.26.0.0.0    | `oracle-ai-database-free-26ai-23.26.0-1.el8.x86_64.rpm` | `oracle-ai-database-preinstall-26ai-1.0-1.el8.x86_64.rpm` |
|  23ai   |   23.9.0.25.07   | `oracle-database-free-23ai-23.9-1.el8.x86_64.rpm`       | `oracle-database-preinstall-23ai-1.0-2.el8.x86_64.rpm`    |
|  23ai   |   23.8.0.25.04   | `oracle-database-free-23ai-23.8-1.el8.x86_64.rpm`       | `oracle-database-preinstall-23ai-1.0-2.el8.x86_64.rpm`    |
|  23ai   |   23.7.0.25.01   | `oracle-database-free-23ai-1.0-1.el8.x86_64.rpm`        | `oracle-database-preinstall-23ai-1.0-2.el8.x86_64.rpm`    |
|  23ai   |   23.6.0.24.10   | `oracle-database-free-23ai-1.0-1.el8.x86_64.rpm`        | `oracle-database-preinstall-23ai-1.0-2.el8.x86_64.rpm`    |
|  23ai   |   23.5.0.24.07   | `oracle-database-free-23ai-1.0-1.el8.x86_64.rpm`        | `oracle-database-preinstall-23ai-1.0-2.el8.x86_64.rpm`    |
|  23ai   |   23.4.0.24.05   | `oracle-database-free-23ai-1.0-1.el8.x86_64.rpm`        | `oracle-database-preinstall-23ai-1.0-2.el8.x86_64.rpm`    |
|   23c   |   23.3.0.23.09   | `oracle-database-free-23c-1.0-1.el8.x86_64.rpm`         | `oracle-database-preinstall-23c-1.0-1.el8.x86_64.rpm`     |
|   23c   |    23.2.0.0.0    | `oracle-database-free-23c-1.0-1.el8.x86_64.rpm`         | `oracle-database-preinstall-23c-1.0-1.el8.x86_64.rpm`     |

By default, the toolkit fetches Free edition software directly from oracle.com. It can also be configured to fetch from your own software library, such as when the database VM has no direct Internet access.

To leverage files in your software library, simply include just the file names in the Ansible `rdbms_software` variable in the [roles/common/defaults/main.yml](../roles/common/defaults/main.yml). For example:

```yaml
rdbms_software:
  - name: 26ai_free_23_26
    version: 23.26.0.0.0
    edition: FREE
    os_version: 8
    files:
      - { name: "oracle-ai-database-preinstall-26ai-1.0-1.el8.x86_64.rpm", sha256sum: "050f1c3f3214f5979519147d08661d5670317288bd9a09d0863f3419206158e4", md5sum: "UOPNQ+SCxZpWRbxt61N4NQ=="}
      - { name: "oracle-ai-database-free-26ai-23.26.0-1.el8.x86_64.rpm", sha256sum: "9abff8045b6c213d75198b96f3a85fe3d4e89aa5c9117ad5873c3182786ef254", md5sum: "mMOOzN3dtAYJP59sng/B5A=="}
```

When installing from files staged in your software library, providing the GCS MD5 hash value is required.

If you would rather have the tooling download the software from the Oracle website, simply specify the full URL instead. For example:

```yaml
rdbms_software:
  - name: 26ai_free_23_26
    version: 23.26.0.0.0
    edition: FREE
    os_version: 8
    files:
      - { name: "https://yum.oracle.com/repo/OracleLinux/OL8/appstream/x86_64/getPackage/oracle-ai-database-preinstall-26ai-1.0-1.el8.x86_64.rpm", sha256sum: "050f1c3f3214f5979519147d08661d5670317288bd9a09d0863f3419206158e4", md5sum: ""}
      - { name: "https://download.oracle.com/otn-pub/otn_software/db-free/oracle-ai-database-free-26ai-23.26.0-1.el8.x86_64.rpm", sha256sum: "9abff8045b6c213d75198b96f3a85fe3d4e89aa5c9117ad5873c3182786ef254", md5sum: ""}
```

If installing by URL, refer to [Oracle Database Free Get Started](https://www.oracle.com/database/free/get-started/) to obtain the most recent links and `sha256sum` values.

If no Free Edition version is explicitly defined (via the `--ora-version` command line switch), the toolkit will default to the most recent version.

If a specific version is required, it can be specified using the `--ora-version` command line switch and one of the above listed version values. For example: `--ora-version 23.6.0.24.10` or `--ora-version 23.2.0.0.0`.

#### Free edition specific parameter changes

When using this toolkit to install the free edition, serveral toolkit parameters becomes irrelevant, or are set to specific values – possibly overriding user provided values.

<table>
<thead>
<tr>
<th>Attribute</th>
<th>Parameters</th>
<th>Parameter Values</th>
<th>Notes</th>
</tr>
</thead>
<tbody>
<tr>
<td>Oracle edition</td>
<td><p><pre>
ORA_EDITION
--ora-edition
</pre></p></td>
<td>FREE</td>
<td>Specify "FREE" to install the free edition.</td>
</tr>
<tr>
<td>Oracle version</td>
<td><p><pre>
ORA_VERSION
--ora-version
</pre></p></td>
<td>
23.26.0.0.0<br>
23.9.0.25.07<br>
23.8.0.25.04<br>
23.7.0.25.01<br>
23.6.0.24.10<br>
23.5.0.24.07<br>
23.4.0.24.05<br>
23.3.0.23.09<br>
23.2.0.0.0</td>
<td>Specific version to install.<br>
<br>
Defaults to the latest release.</td>
</tr>
<tr>
<td>Data file destination</td>
<td><p><pre>
ORA_DATA_DESTINATION
--ora-data-destination
</pre></p></td>
<td>user defined file system location</td>
<td>Must be an existing Linux file system location – ASM disk groups are incompatible with the free edition.</td>
</tr>
<tr>
<td>Recovery area destination</td>
<td><p><pre>
ORA_RECO_DESTINATION
--ora-reco-destination
</pre></p></td>
<td>user defined file system location</td>
<td>Must be an existing Linux file system location – ASM disk groups are incompatible with the free edition.</td>
</tr>
<tr>
<td>PDB count</td>
<td><p><pre>
ORA_PDB_COUNT
--ora-pdb-count
</pre></p></td>
<td>user defined integer<br>
<br>1 (default)</td>
<td>If greater than 1, a numeric is appended to each PDB name.<br>
<br>
Maximum value for free edition is 16.</td>
</tr>
<tr>
<td>Database name</td>
<td><p><pre>
ORA_DB_NAME
--ora-db-name
</pre></p></td>
<td>FREE (default)</td>
<td>Defaults to "FREE" when installing free edition.<br>
<br>
User-provided values are ignored.</td>
</tr>
<tr>
<td>Grid user role separation</td>
<td><p><pre>
ORA_ROLE_SEPARATION
--ora-role-separation
</pre></p></td>
<td>FALSE (default)</td>
<td>Grid Infrastructure is not used with free edition and therefore role separation is irrelevant.<br>
<br>
User-provided values are ignored.</td>
</tr>
<tr>
<td>ASM disk management</td>
<td><p><pre>
ORA_DISK_MGMT
--ora-disk-mgmt
</pre></p></td>
<td>ASMUDEV (default)</td>
<td>ASMlib is incompatible with free edition.<br>
<br>
User-provided values are ignored.</td>
</tr>
<tr>
<td>Cluster type</td>
<td><p><pre>
CLUSTER_TYPE
--cluster-type
</pre></p></td>
<td>NONE (default)</td>
<td>Only single instance databases are possible with free edition.<br>
<br>
User-provided values are ignored.</td>
</tr>
</tbody>
</table>

Most other parameters are applicable – there usage described in the previous sections of this document.

### Sample Invocations for Oracle Database Free Edition

In the following sample invocations, the IP address of the target server is referenced as environment variable `INSTANCE_IP_ADDR`.

Check that software is available:

```bash
./check-swlib.sh --ora-swlib-bucket gs://oracle-software --ora-edition FREE
```

Validate parameters only:

```bash
./install-oracle.sh \
  --ora-edition FREE \
  --ora-swlib-bucket gs://oracle-software \
  --backup-dest /u02/backups \
  --validate
```

Run the host (server) preparation steps only:

```bash
./install-oracle.sh \
  --ora-edition FREE \
  --instance-ip-addr ${INSTANCE_IP_ADDR} \
  --ora-swlib-bucket gs://oracle-software \
  --prep-host
```

Run the software install steps only:

```bash
./install-oracle.sh \
  --ora-edition FREE \
  --instance-ip-addr ${INSTANCE_IP_ADDR} \
  --ora-swlib-bucket gs://oracle-software \
  --install-sw
```

Run the database creation steps only:

```bash
./install-oracle.sh \
  --ora-edition FREE \
  --instance-ip-addr ${INSTANCE_IP_ADDR} \
  --ora-swlib-bucket gs://oracle-software \
  --backup-dest /u02/backups \
  --config-db
```

Run the full oracle-toolkit end-to-end:

```bash
./install-oracle.sh \
  --ora-edition FREE \
  --instance-ip-addr ${INSTANCE_IP_ADDR} \
  --ora-swlib-bucket gs://oracle-software \
  --backup-dest /opt/oracle/fast_recovery_area/FREE \
  --ora-pdb-count 2 \
  --ora-pdb-name-prefix FREEPDB
```

### Example Oracle Toolkit Execution for Free Edition

In the following example, environment variables are used to specify the
following values:

- The IP address of the target instance

For all other parameters, command line provided values are used, or default values are accepted.

Note: Unless you specify a hostname on the `INSTANCE_HOSTNAME` environment
variable or the `--instance-hostname` command line argument, the target hostname
defaults to the target IP address.

```bash
$ export INSTANCE_IP_ADDR=10.2.83.197
$ ./install-oracle.sh \
>   --ora-edition FREE \
>   --instance-ip-addr ${INSTANCE_IP_ADDR} \
>   --instance-hostname db-23ai-free \
>   --ora-swlib-bucket gs://oracle-software \
>   --backup-dest /opt/oracle/fast_recovery_area/FREE \
>   --ora-pdb-count 2 \
>   --ora-pdb-name-prefix FREEPDB

Command used:
./install-oracle.sh --ora-edition FREE --instance-ip-addr 10.2.83.197 --instance-hostname db-23ai-free --ora-swlib-bucket gs://oracle-software --backup-dest /opt/oracle/fast_recovery_area/FREE --ora-pdb-count 2 --ora-pdb-name-prefix FREEPDB


Inventory file for this execution: ./inventory_files/inventory_db-23ai-free_FREE.

Running with parameters from command line or environment variables:

ANSIBLE_DISPLAY_SKIPPED_HOSTS=false
ANSIBLE_LOG_PATH=./logs/log_db-23ai-free_FREE_20250131_105534.log
ARCHIVE_BACKUP_MIN=30
ARCHIVE_ONLINE_DAYS=7
ARCHIVE_REDUNDANCY=2
BACKUP_DEST=/opt/oracle/fast_recovery_area/FREE
BACKUP_LEVEL0_DAYS=0
BACKUP_LEVEL1_DAYS=1-6
BACKUP_LOG_LOCATION=/home/oracle/logs
BACKUP_REDUNDANCY=2
BACKUP_SCRIPT_LOCATION=/home/oracle/scripts
BACKUP_START_HOUR=01
BACKUP_START_MIN=00
CLUSTER_CONFIG=cluster_config.json
CLUSTER_TYPE=NONE
INSTANCE_HOSTGROUP_NAME=dbasm
INSTANCE_HOSTNAME=db-23ai-free
INSTANCE_IP_ADDR=10.2.83.197
INSTANCE_SSH_EXTRA_ARGS=''\''-o ServerAliveInterval=60 -o ServerAliveCountMax=3 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o IdentityAgent=no'\'''
INSTANCE_SSH_KEY='~/.ssh/id_rsa'
INSTANCE_SSH_USER=janedoe
ORA_ASM_DISKS=asm_disk_config.json
ORA_DATA_DESTINATION=/u02/oradata
ORA_DATA_MOUNTS=data_mounts_config.json
ORA_DB_CHARSET=AL32UTF8
ORA_DB_CONTAINER=TRUE
ORA_DB_DOMAIN=
ORA_DB_NAME=FREE
ORA_DB_NCHARSET=AL16UTF16
ORA_DB_TYPE=MULTIPURPOSE
ORA_DISK_MGMT=ASMUDEV
ORA_EDITION=FREE
ORA_LISTENER_NAME=LISTENER
ORA_LISTENER_PORT=1521
ORA_PDB_COUNT=2
ORA_PDB_NAME_PREFIX=FREEPDB
ORA_RECO_DESTINATION=/opt/oracle/fast_recovery_area
ORA_REDO_LOG_SIZE=100MB
ORA_RELEASE=latest
ORA_ROLE_SEPARATION=FALSE
ORA_STAGING=/u01/swlib
ORA_SWLIB_BUCKET=gs://oracle-software
ORA_SWLIB_CREDENTIALS=
ORA_SWLIB_PATH=/u01/swlib
ORA_SWLIB_TYPE=GCS
ORA_VERSION=23.0.0.0.0
PB_CHECK_INSTANCE=check-instance.yml
PB_CONFIG_DB=config-db.yml
PB_CONFIG_RAC_DB=config-rac-db.yml
PB_INSTALL_SW=install-sw.yml
PB_LIST='check-instance.yml prep-host.yml install-sw.yml config-db.yml'
PB_PREP_HOST=prep-host.yml
PRIMARY_IP_ADDR=

Ansible params:
Found Ansible: ansible-playbook is /usr/local/bin/ansible-playbook

Running Ansible playbook: ansible-playbook -i ./inventory_files/inventory_db-23ai-free_FREE   check-instance.yml

PLAY [dbasm] *********************************************************************************************************************************

TASK [Verify that Ansible on control node meets the version requirements] ********************************************************************
ok: [db-23ai-free] => {
    "changed": false,
    "msg": "Ansible version is 2.9.27, continuing"
}

TASK [Confirm JSON parsing works] ************************************************************************************************************
ok: [db-23ai-free] => {
    "changed": false,
    "msg": "All assertions passed"
}

TASK [Test connectivity to target instance via ping] *****************************************************************************************
ok: [db-23ai-free]

TASK [Abort if ping module fails] ************************************************************************************************************
ok: [db-23ai-free] => {
    "changed": false,
    "msg": "The instance has an usable python installation, continuing"
}

TASK [Collect facts from target] *************************************************************************************************************
ok: [db-23ai-free]

... output truncated for brevity
```

## Post installation tasks

### Validate the Oracle installation with ORAchk

The orachk utility can be used to validate the Oracle installation.

ORAchk will check for known problems with the Oracle installation and configuration, and provide recommendations for resolving any issues that are found.

To run ORAchk, download the AHF utility from the Oracle support site.

The following Oracle Support Note will provide the download link:

`Autonomous Health Framework (AHF) - Including Trace File Analyzer and Orachk/Exachk (Doc ID 2550798.1)`

ORAchk is a part of the AHF utility. It is not necessary to install the entire AHF utility to run ORAchk.

The `check-oracle.sh` script provided with the toolkit will allow you to install, run and uninstall ORAchk on the target server.

#### Options

ORAchk can be installed on the target server using the following options:

example 1:

```text
./check-oracle.sh \
--ahf-install \
--db-name <your-database-name> \
--instance-ip-addr <your-instance-ip-address|server-name> \
--ahf-location <path-to-ahf-zip-file>
```

example 2:

```text
./check-oracle.sh \
--ahf-install \
--inventory-file <path-to-inventory-file> \
--ahf-location <path-to-ahf-zip-file>
```

Running ORAchk on the target server is similar to the installation process, but the '--ahf-location' option is not required.

example 1:

```text
./check-oracle.sh \
--run-orachk \
--db-name <your-database-name> \
--instance-ip-addr <your-instance-ip-address|server-name>
```

example 2:

```text
./check-oracle.sh \
--run-orachk \
--db-name <your-database-name> \
--inventory-file <path-to-inventory-file>
```

#### The AHF Zip file.

The zip file must be uploaded to a GCS media bucket.

The default 'directory' for this is AHF.

For instance, the file `AHF-LINUX_v25.1.0.zip` would be uploaded to `gs://oracle-software/AHF/AHF-LINUX_v25.1.0.zip`.

#### Install and Run ORAchk

Use the the `check-oracle.sh` script to install and run ORAchk in one command.

```bash
$  ./check-oracle.sh --help
        Usage: check-oracle.sh
         --instance-ip-addr <value>
         [ --extra-vars <value> ]
         [ --ahf-location <value> ]
         [ --db-name <value> ]
         [ --inventory-file <value> ]
         [ --ahf-install ]
         [ --ahf-uninstall ]
         [ --run-orachk ]
         [ --help ]
         [ --debug ]

--ahf-install and --run-orachk may be combined to install and run
--extra-vars is used to pass any number of extra ansible vars
  example:  --extra-vars 'var1=val1 var2=val2'

```

example output:
Note: skipped steps are omitted

```text

./check-oracle.sh --ahf-install \
  --instance-ip-addr 10.2.80.39 \
  --db-name ORCL \
  --ahf-location gs://oracle-software/AHF/AHF-LINUX_v25.1.0.zip

PLAY [ORAchk: uninstall, install or run] ***********************************************************************************************************************************************************************************************************************************
...
PLAY [ORAchk: uninstall, install or run] ***********************************************************************************************************************************************************************************************************************************

TASK [Check for AHF Installation] ******************************************************************************************************************************************************************************************************************************************
ok: [ora-db-server-19c]
...
PLAY RECAP *****************************************************************************************************************************************************************************************************************************************************************
ora-db-server-19c : ok=8    changed=2    unreachable=0    failed=0    skipped=24   rescued=0    ignored=0

```

#### Installing ORAchk

Use the the `check-oracle.sh` script to install ORAchk.

```bash

./check-oracle.sh --ahf-install \
   --inventory-file inventory_files/inventory_ora-db-server-19c_ORCL \
   --ahf-location gs://oracle-software/AHF/AHF-LINUX_v25.1.0.zip

```

example output:
Note: skipped steps are omitted

```text
PLAY [ORAchk: uninstall, install or run] **********************************************************************************************************************************************************************************************

TASK [Create AHF directory] ***********************************************************************************************************************************************************************************************************
ok: [ora-db-server-19c]

...

TASK [Run AHF setup] ******************************************************************************************************************************************************************************************************************
changed: [ora-db-server-19c]

PLAY RECAP ****************************************************************************************************************************************************************************************************************************
ora-db-server-19c   : ok=7    changed=2    unreachable=0    failed=0    skipped=8    rescued=0    ignored=0

```

#### Running ORAchk

```bash
./check-oracle.sh --run-orachk \
  --db-name ORCL \
  --inventory-file inventory_files/inventory_ora-db-server-19c_ORCL
```

example output:
Note: skipped steps are omitted

```text

PLAY [ORAchk: uninstall, install or run] **********************************************************************************************************************************************************************************************

...

TASK [Run ORAchk] *********************************************************************************************************************************************************************************************************************
changed: [ora-db-server-19c]

...

TASK [Display local path of fetched file] *********************************************************************************************************************************************************************************************
ok: [ora-db-server-19c] => {
    "msg": "Fetched file is saved locally at: /tmp/orachk_ora-db-server-19c_ORCL_020525_193642.zip"
}

PLAY RECAP ****************************************************************************************************************************************************************************************************************************
ora-db-server-19c   : ok=6    changed=3    unreachable=0    failed=0    skipped=9    rescued=0    ignored=0

```

As shown in the message, the orachk zip file is saved locally at `/tmp/orachk_ora-db-server-19c_ORCL_020525_193642.zip`.

```text
$ unzip -l /tmp/orachk_ora-db-server-19c_ORCL_020525_193642.zip | head -12
Archive:  /tmp/orachk_ora-db-server-19c_ORCL_020525_193642.zip
  Length      Date    Time    Name
---------  ---------- -----   ----
        0  02-05-2025 19:40   orachk_ora-db-server-19c_ORCL_020525_193642/
        0  02-05-2025 19:40   orachk_ora-db-server-19c_ORCL_020525_193642/.standalone_html_gen/
        0  02-05-2025 19:41   orachk_ora-db-server-19c_ORCL_020525_193642/log/
        0  02-05-2025 19:40   orachk_ora-db-server-19c_ORCL_020525_193642/outfiles/
        0  02-05-2025 19:40   orachk_ora-db-server-19c_ORCL_020525_193642/reports/
        0  02-05-2025 19:40   orachk_ora-db-server-19c_ORCL_020525_193642/scripts/
        0  02-05-2025 19:40   orachk_ora-db-server-19c_ORCL_020525_193642/upload/
   650915  02-05-2025 19:40   orachk_ora-db-server-19c_ORCL_020525_193642/orachk_ora-db-server-19c_ORCL_020525_193642.html
     8959  02-05-2025 19:40   orachk_ora-db-server-19c_ORCL_020525_193642/localcmd.py.shell
```

Unzip the zip file, and open `orachk_ora-db-server-19c_ORCL_020525_193642/orachk_ora-db-server-19c_ORCL_020525_193642.html` in a browser

#### Uninstalling ORAchk

```bash
./check-oracle.sh  --ahf-uninstall \
      --db-name ORCL \
      --oracle-server ora-db-server-19c
```

example output:
Note: skipped steps are omitted

```text
PLAY [ORAchk: uninstall, install or run] **********************************************************************************************************************************************************************************************

TASK [Uninstall AHF] ******************************************************************************************************************************************************************************************************************
changed: [ora-db-server-19c]

PLAY RECAP ****************************************************************************************************************************************************************************************************************************
ora-db-server-19c   : ok=1    changed=1    unreachable=0    failed=0    skipped=14   rescued=0    ignored=0
```

### Reset passwords

The toolkit does not use or store any passwords. At runtime, passwords
for the Oracle SYS and SYSTEM database users are set with strong, unique, and
randomized passwords that are not written to or persisted in any OS files.

Change the passwords immediately after running the toolkit.

To change the passwords, connect to the database by using a SYSDBA
administrative connection and change the passwords by using the SQL Plus
`password` command:

```bash
sqlplus / as sysdba

SQL> password SYSTEM
```

### Validate the environment

After deployment, you can validate your environment using several scripts that
are provided with the toolkit.

#### Listing Oracle ASM devices

You can list the devices that are used by Oracle ASM using the `asm_disks.sh`
script, as shown in the following example:

```bash
$ /home/oracle/scripts/asm_disks.sh
Disk device /dev/sdd1 may be an ASM disk - Disk name: DATA_0000
Disk device /dev/sde1 may be an ASM disk - Disk name: RECO_0000
Disk device /dev/sdf1 may be an ASM disk - Disk name: DEMO_0000
```

#### Displaying cluster resource status

You can generate a report that shows the Oracle Restart cluster resources by
using the `crs_check.sh` script, as shown in the following example:

```bash
$ /home/oracle/scripts/crs_check.sh

***** CRS STATUS *****

Oracle High Availability Services release version on the local node is [18.0.0.0.0]
Oracle High Availability Services version on the local node is [18.0.0.0.0]
CRS-4638: Oracle High Availability Services is online
CRS-4529: Cluster Synchronization Services is online

NAME=ora.DATA.dg
TYPE=ora.diskgroup.type
TARGET=ONLINE
STATE=ONLINE on db-host-1

... output truncated for brevity
```

#### Verify an Oracle cluster

You can verify the integrity of an Oracle cluster by using the
`cluvfy_checks.sh` script to run the Oracle Cluster Verify utility.

#### Oracle validation utilities

For a more comprehensive validation, use the utilities provided by Oracle
Support, which are available for download from My Oracle Support:

- [Autonomous Health Framework (AHF) - Including TFA and ORAchk/EXAChk (Doc ID 2550798.1)](https://support.oracle.com/epmos/faces/DocContentDisplay?id=2550798.1)

Oracle's Autonomous Health Framework (AHF) includes utilities such as Trace File
Analyzer (TFA). TFA provides options such as `tfactl summary`, which gives
a complete environment overview. AHF also includes a copy of ORAchk. Refer to
the Oracle documentation for more information.

The following example shows the use of the Oracle Cluster Verify utility:

```bash
$ /home/oracle/scripts/cluvfy_checks.sh

Verifying Oracle Restart Integrity ...PASSED

Verification of Oracle Restart integrity was successful.

CVU operation performed:      Oracle Restart integrity
Date:                         Jul 15, 2019 11:26:15 PM
CVU home:                     /u01/app/18.0.0/grid/
User:                         oracle

Verifying Physical Memory ...
  Node Name     Available                 Required                  Status
  ------------  ------------------------  ------------------------  ----------
  dbserver      14.5286GB (1.523434E7KB)  8GB (8388608.0KB)         passed
Verifying Physical Memory ...PASSED

... output truncated for brevity

Verifying Users With Same UID: 0 ...PASSED
Verifying Root user consistency ...
  Node Name                             Status
  ------------------------------------  ------------------------
  dbserver                              passed
Verifying Root user consistency ...PASSED

Verification of system requirement was successful.

CVU operation performed:      system requirement
Date:                         Jul 15, 2019 11:26:26 PM
CVU home:                     /u01/app/18.0.0/grid/
User:                         oracle
```

### Patching

You can apply Oracle Release Update (RU) or Patch Set Update (PSU) patches to
both the Grid Infrastructure and Database homes by using the
`apply-patch.sh` script of the toolkit.

By default, `install-oracle.sh` updates to the latest available patch. To
apply a specific patch instead, use the `--no-patch` option in `install-oracle.sh`
to skip patching at installation time. After installation is complete, execute
`apply-patch.sh` with the `--ora-release` option. Specify the full release name including
timestamp; a list of release names is available in [roles/common/defaults/main.yml](https://github.com/google/oracle-toolkit/tree/master/roles/common/defaults/main.yml)
under `gi-patches` and `rdbms-patches`.

A digest of the required patch files, including checksum hashes is provided in
the file `roles/common/defaults/main.yml`.

To apply patches, you need to specify the location of the software library. You
can optionally specify the base database version, the release to patch to, the
database name, the staging location, and other optional parameters.

Example:

```bash
$ ./apply-patch.sh --help
        Usage: apply-patch.sh
         --ora-swlib-bucket <value>
         --inventory-file <value>
         [ --ora-version <value> ]
         [ --ora-release <value> ]
         [ --ora-swlib-path <value> ]
         [ --ora-staging <value> ]
         [ --ora-db-name <value> ]
         [ --help ]
         [ --validate ]
         -- [parameters sent to ansible]

$ ./apply-patch.sh \
  --ora-swlib-bucket gs://oracle-software \
  --ora-swlib-path /u02/oracle_install \
  --ora-staging /u02/oracle_install \
  --ora-version 19.3.0.0.0 \
  --ora-release 19.25.0.0.241015 \
    --inventory-file inventory_files/inventory_toolkit-db2_ORCL

Running with parameters from command line or environment variables:

ORA_DB_NAME=ORCL
ORA_RELEASE=19.25.0.0.241015
ORA_STAGING=/u02/oracle_install
ORA_SWLIB_BUCKET=gs://oracle-software
ORA_SWLIB_PATH=/u02/oracle_install
ORA_VERSION=19.3.0.0.0

Ansible params: -i inventory_files/inventory_toolkit-db2_ORCL
Found Ansible at /usr/bin/ansible-playbook
Running Ansible playbook: /usr/bin/ansible-playbook -i inventory_files/inventory_toolkit-db2_ORCL   patch.yml

PLAY [OPatch Restart patch] ****************************************************

TASK [Gathering Facts] *********************************************************
ok: [toolkit-db2]

TASK [Verify Ansible meets the version requirements] ********************************************************************************
ok: [toolkit-db2] => {
    "changed": false,
    "msg": "Ansible version is 2.9.6, continuing"
}

TASK [patch : Update OPatch in GRID_HOME]

... output truncated for brevity
```

#### A note on patch metadata

See [patch-metadata.md](./patch-metadata.md) for details on
updating quarterly Release Update metadata.

### Patching RAC databases

The patching process for RAC databases is based on applying the OJVM+GI RU
"combo patches", which contain all necessary Release Update (RU) patches for
both the GI and RDBMS homes, as well as the Oracle Java Virtual Machine (OJVM)
database patches.

All GI patching is implemented using the `opatchauto` utility run by the root
user from the GI home and, therefore, if the GI and RDBMS homes are of the same
major release, patches both the GI and RDBMS homes in a single step.

By default, if RAC GI and RDBMS homes are of the same base release, the
**install-oracle.sh** script applies the latest RU/PSU patch to both.

You can skip all RU/PSU patching steps and install only the base software by
specifying the command line option `--no-patch`. You can then apply patches
separately later, either manually or by using the toolkit.

Alternatively, you can apply RAC GI and RDBMS patches independently from the
base software installations by using the script `apply-patch.sh`. This script
also allows you apply patches with more granularity.

The list of RU/PSU patches to apply are defined by the `gi_patches` and
`rdbms_patches` variables. By default, both are specified in the
`roles/common/defaults/main.yml` Ansible file. For each major Oracle release,
you can specify multiple versions from the various quarterly releases When you
install by using `install-oracle.sh`, the toolkit uses the most recent patch
version.

When creating a database, if the RDBMS home software is no longer at the base
release because it was patched during installation, the toolkit uses the Oracle
`datapatch` utility to apply patches at the database level, which is known as _SQL
level patching_.

#### BMS RAC install with latest RU

The following example RAC installation command applies the PSU/RU patches, which
is the default behavior:

```bash
./install-oracle.sh \
  --ora-swlib-bucket gs://oracle-software \
  --instance-ssh-key '~/.ssh/id_rsa' \
  --instance-ssh-user dba-user \
  --ora-swlib-path /u01/oracle_install \
  --ora-staging /u01/oracle_install \
  --backup-dest "+DATA" \
  --ora-version 19.3.0.0.0 \
  --ora-swlib-type gcs \
  --compatible-rdbms "11.2.0.4.0" \
  --ora-asm-disks asm_disk_config.json \
  --ora-data-mounts data_mounts_config.json \
  --cluster-type RAC \
  --cluster-config cluster_config.json \
  --ora-reco-destination DATA \
  --ora-db-name ORCL
```

If you do not specify a value on the `--compatible-rdbms` parameter, the
RDBMS compatibility of the ASM disk group is set to the major version level
that is defined on the `--ora-version` parameter.

To patch RAC databases, the toolkit performs the following actions:

1. Stops the RAC databases in their homes by using the "stop home" option
   from the first node.
1. Stops TFA.
1. Kills the `asmcmd` daemon processes.
1. Executes `opatchauto apply`, patching both nodes.
1. Restarts the services, including `start home`.
1. On the first node only, runs the `datapatch` utility over several
   iterations to resolve any PDB invalid states.

Regardless of which script is used, the specifics about which patch files to
use, such as the file names of the source media, patch paths, and the software
versions, are taken from the `gi_patches` and `rdbms_patches`
variables. The defaults for these variables are defined in the
`roles/common/defaults/main.yml` Ansible file. You can override the default
values or specify patches that are not included in the
`roles/common/defaults/main.yml` file in a properly structured JSON file that
you reference on the `--extra-vars` Ansible argument.

The following example shows a YAML file that contains patch specifications for
both the GI and RDBMS software:

```yaml
gi_patches:
  - {
      category: "RU",
      base: "19.3.0.0.0",
      release: "19.7.0.0.200414",
      patchnum: "30783556",
      patchfile: "p30783556_190000_Linux-x86-64.zip",
      patch_subdir: "/30899722",
      prereq_check: FALSE,
      method: "opatchauto apply",
      ocm: FALSE,
      upgrade: FALSE,
    }

rdbms_patches:
  - {
      category: "RU_Combo",
      base: "19.3.0.0.0",
      release: "19.7.0.0.200414",
      patchnum: "30783556",
      patchfile: "p30783556_190000_Linux-x86-64.zip",
      patch_subdir: "/30805684",
      prereq_check: TRUE,
      method: "opatch apply",
      ocm: FALSE,
      upgrade: TRUE,
    }
```

The following example shows the specification of the YAML file by using the
**--extra-vars** Ansible parameter:

```bash
./install-oracle.sh \
  --ora-swlib-bucket gs://oracle-software \
  --instance-ssh-key '~/.ssh/id_rsa' \
  --instance-ssh-user dba-user \
  --ora-swlib-path /u01/oracle_install \
  --ora-staging /u01/oracle_install \
  --backup-dest "+DATA" \
  --ora-version 19.3.0.0.0 \
  --ora-swlib-type gcs \
  --compatible-rdbms "11.2.0.4.0" \
  --ora-asm-disks asm_disk_config.json \
  --ora-data-mounts data_mounts_config.json \
  --cluster-type RAC \
  --cluster-config cluster_config.json \
  --ora-reco-destination DATA \
  --ora-db-name ORCL \
  -- "--extra-vars @patches.yaml"
```

Note: you can use the `--extra-vars` Ansible parameter to specify other things
besides a JSON file that contains patch details, such as specifying other
optional or ad-hoc Ansible run-time parameters.

To apply additional granularity for patches when you use the `apply-patch.sh`
script use the `--ora-version` and `--ora-release` parameters to specify a
major Oracle version and a specific patch release level, respectively.

For example:

```bash
./apply-patch.sh \
  --ora-swlib-bucket gs://oracle-software \
  --inventory-file inventory_files/inventory_ORCL_RAC \
  --ora-version 19.3.0.0.0 \
  --ora-release 19.7.0.0.200414 \
  --ora-swlib-path /u01/oracle_install \
  --ora-staging /u01/oracle_install \
  --ora-db-name ORCL
  -- "--extra-vars @patches.yaml"
```

### Data Guard Standby-First Patching

This toolkit supports reduced downtime patching using the standby-first
approach. For full details see [Patching Oracle Database with Standby
First Patching](https://docs.oracle.com/en/database/oracle/oracle-database/26/sbydb/upgrading-patching-downgrading-oracle-data-guard-configuration.html#GUID-A5226768-DB6B-4714-BB9A-0A3EF17A01C8).

Non-rolling patching of a Data Guard configuration is also possible and
usually involves first patching the STANDBY database.  Use the `apply-patch.sh`
script - no special customizations are required. The toolkit will recognize
that it's patching a STANDBY database and consequently will only apply the
Oracle Home (file) patches using OPatch. And will not apply the SQL or catalog
patch using `datapatch`.

Example command:

```bash
./apply-patch.sh \
  --inventory-file inventory_files/inventory_standby-ORCL \
  --ora-version 19 \
  --ora-swlib-bucket gs://oracle-software
```

Then similarly, patch the PRIMARY database:

```bash
./apply-patch.sh \
  --inventory-file inventory_files/inventory_primary-ORCL \
  --ora-version 19 \
  --ora-swlib-bucket gs://oracle-software
```

Patching the PRIMARY will take longer as both the Oracle Home updates and
catalog SQL updates will be applied during the single patch-window.

To reduce the overall patching downtime, the Data Guard standby-first apporach
can be used. The steps involved can be summarized as:

1. Patch the STANDBY - the toolkit will recognize that the database is not open and will only apply Oracle Home file patches.
2. Perform a Data Guard role transition/reversal (i.e. a graceful switchover).
3. Patch the new STANDBY (old PRIMARY) - again only Oracle Home file patches will be applied.
4. Patch the PRIMARY - this time only catalog SQL updates are applied (via `datapatch`) and the changes are replicated from the PRIMARY to the STANDBY.

The first and third step can be run using `apply-patch.sh` and commands similar
to those shown above. And while the same command can also be used for the
final step, leveraging the toolkit's Ansible tags can expidite the final
step by skipping many tasks not related to catalog SQL patching.

Specifically, leverage Ansible tags in a command similar to the following:

```bash
./apply-patch.sh \
  --inventory-file inventory_files/inventory_NEW_standby-ORCL \
  --ora-version 19 \
  --ora-swlib-bucket gs://oracle-software \
  -- "--tags opatch_restart,oracle-rel,patch-rdbms"
```

> NOTE: substitute tag `opatch_restart` with `rac-opatch` etc, as required.

### Destructive Cleanup

If you need to uninstall the Oracle software, the Oracle software includes
uninstallation options, which are the recommended way to uninstall Oracle
software.

If necessary, you can use the script `cleanup-oracle.sh` to perform a
destructive or a brute-force clean-up of Oracle databases, services, and
software from a specified target database server. A brute-force clean-up takes
the following actions:

- Kills all running Oracle services.
- Deconfigures the Oracle Restart software.
- Removes Oracle related directories and files.
- Removes Oracle software owner users and groups.
- Re-initializes ASM storage devices and uninstalls ASMlib if installed.

**Important**: a destructive cleanup permanently deletes the databases and any data they
contain. Any backups that are stored local to the server are also deleted. Backups
stored in Cloud Storage, Cloud Storage FUSE, or NFS devices are not affected by a
destructive cleanup.

**Recommendation**: provide a value for the role separation parameter, which
defaults to `TRUE`. On the `--inventory-file` parameter, specify the location
of the inventory file:

```bash
$ ./cleanup-oracle.sh --help
        Usage: cleanup-oracle.sh
          --ora-version <value>
          --inventory-file <value>
          --yes-i-am-sure
          [ --ora-role-separation <value> ]
          [ --ora-disk-mgmt <value> ]
          [ --ora-swlib-path <value> ]
          [ --ora-staging <value> ]
          [ --ora-asm-disks <value> ]
          [ --ora-data-mounts <value> ]
          [ --gcs-backup-path <value> ]
          [ --help ]
```

Sample usage:

```bash
$ ./cleanup-oracle.sh --ora-version 19 \
--inventory-file ./inventory_files/inventory_oracledb1_ORCL \
--yes-i-am-sure \
--ora-disk-mgmt udev \
--ora-swlib-path /u02/oracle_install \
--ora-staging /u02/oracle_install \
--ora-asm-disks asm_disk_config.json \
--ora-data-mounts data_mounts_config.json \
--gcs-backup-path /mnt/gcsfuse

Running with parameters from command line or environment variables:

INVENTORY_FILE=./inventory_files/inventory_oracledb1_ORCL
ORA_ASM_DISKS=asm_disk_config.json
ORA_DATA_MOUNTS=data_mounts_config.json
ORA_DISK_MGMT=udev
ORA_ROLE_SEPARATION=TRUE
ORA_STAGING=/u02/oracle_install
ORA_SWLIB_PATH=/u02/oracle_install
ORA_VERSION=19.3.0.0.0
GCS_BACKUP_PATH=/mnt/gcsfuse

Ansible params:
Found Ansible at /usr/bin/ansible-playbook

Running Ansible playbook: /usr/bin/ansible-playbook -i ./inventory_files/inventory_oracledb1_ORCL  brute-cleanup.yml

PLAY [all] ************************************************************************************
... output truncated for brevity
```
