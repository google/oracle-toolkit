# oracle-toolkit

Toolkit for managing Oracle databases on Google Cloud.

Supports usage with:

- [Bare Metal Solution](https://cloud.google.com/bare-metal)
- [Google Compute Engine](https://cloud.google.com/products/compute)

## Quick Start

1. Create a Google Cloud VM to act as a [control node](/docs/user-guide.md#control-node-requirements); it should be on a VPC network that has SSH access to the database hosts.
1. [Extract the toolkit code](/docs/user-guide.md#installing-the-toolkit) on the control node.
1. Create a Cloud Storage bucket to host Oracle software images.
     ```bash
     gsutil mb -b on gs://installation-media-1234
     ```
1. [Download software](/docs/user-guide.md#downloading-and-staging-the-oracle-software) from Oracle and populate the bucket. Use [check-swlib.sh](/docs/user-guide.md#validating-media) to determine which files are required for your Oracle version.

1. Create an SSH key, and populate to an Ansible user on each database host.
1. Create a JSON file `db1_asm.json` with ASM disk devices:
   ```json
   [
     {
       "diskgroup": "DATA",
       "disks": [
         {
           "name": "DATA_1",
           "blk_device": "/dev/mapper/3600a098038314352502b4f782f446155"
         }
       ]
     },
     {
       "diskgroup": "RECO",
       "disks": [
         {
           "name": "RECO_1",
           "blk_device": "/dev/mapper/3600a098038314352502b4f782f446162"
         }
       ]
     }
   ]
   ```
1. Create a JSON file `db1_mounts.json` with disk mounts:
   ```json
   [
     {
       "purpose": "software",
       "blk_device": "/dev/mapper/3600a098038314352502b4f782f446161",
       "name": "u01",
       "fstype": "xfs",
       "mount_point": "/u01",
       "mount_opts": "nofail"
     }
   ]
   ```
1. Execute `install-oracle.sh`:
   ```bash
   bash install-oracle.sh \
   --ora-swlib-bucket gs://installation-media-1234 \
   --instance-ssh-user ansible \
   --instance-ssh-key ~/.ssh/id_rsa \
   --backup-dest /u01/rman \
   --ora-swlib-path /u01/oracle_install \
   --ora-version 19 \
   --ora-swlib-type gcs \
   --ora-asm-disks db1_asm.json \
   --ora-data-mounts db1_mounts.json \
   --ora-data-destination DATA \
   --ora-reco-destination RECO \
   --ora-db-name orcl \
   --instance-ip-addr 172.16.1.1
   ```

Full documentation is available in the [user guide](/docs/user-guide.md)

## Destructive cleanup

An Ansible role and playbook performs a [destructive brute-force removal](/docs/user-guide.md#destructive-cleanup) of Oracle software and configuration. It does not remove other host prerequisites.

Run the destructive brute-force Oracle software removal with `cleanup-oracle.sh` or `ansible-playbook brute-cleanup.yml`

## Contributing to the project

Contributions and pull requests are welcome. See [docs/contributing.md](docs/contributing.md) and [docs/code-of-conduct.md](docs/code-of-conduct.md) for details.

## The fine print

This product is [licensed](LICENSE) under the Apache 2 license. This is not an officially supported Google project
