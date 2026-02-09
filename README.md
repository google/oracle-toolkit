# oracle-toolkit

Toolkit for managing Oracle databases on Google Cloud.

Supports usage with:

- [Bare Metal Solution](https://cloud.google.com/bare-metal)
- [Google Compute Engine](https://cloud.google.com/products/compute)

## Quick Start

1. Create a Google Cloud VM to act as a [control node](/docs/user-guide.md#control-node-requirements); it should be on a VPC network that has SSH access to the database host.
1. Create a Google Cloud VM to act as the database host. Add aditional disks named `oracle_home`, `data`, and `reco` for the oracle_home, database data, and recovery area, respectively.
1. [Extract the toolkit code](/docs/user-guide.md#installing-the-toolkit) on the control node.
1. Create a Cloud Storage bucket to host Oracle software images.
     ```bash
     gcloud storage buckets create --uniform-bucket-level-access gs://installation-media-1234
     ```
1. [Download software](/docs/user-guide.md#downloading-and-staging-the-oracle-software) from Oracle and populate the bucket. Use [check-swlib.sh](/docs/user-guide.md#validating-media) to determine which files are required for your Oracle version.

1. On the control node, create a SSH key `~/.ssh/db1`
1. On the database host, create a user `ansible` with sudo privileges.  Add the SSH public key from the previous step into a `~ansible/.ssh/authorized_keys` file.
1. Create a JSON file `db1_mounts.json` with disk mounts:
   ```json
   [
     {
       "purpose": "software",
       "blk_device": "/dev/disk/by-id/google-oraclehome",
       "name": "u01",
       "fstype": "xfs",
       "mount_point": "/u01",
       "mount_opts": "nofail"
     },
     {
       "purpose": "data",
       "blk_device": "/dev/disk/by-id/google-data",
       "name": "u02",
       "fstype": "xfs",
       "mount_point": "/u02",
       "mount_opts": "nofail"
     },
     {
       "purpose": "reco",
       "blk_device": "/dev/disk/by-id/google-reco",
       "name": "u03",
       "fstype": "xfs",
       "mount_point": "/u03",
       "mount_opts": "nofail"
     },
   ]
   ```
1. Execute `install-oracle.sh`, substituting the correct IP address for the database VM:
   ```bash
   bash install-oracle.sh \
   --ora-swlib-bucket gs://installation-media-1234 \
   --instance-ssh-user ansible \
   --instance-ssh-key ~/.ssh/id_rsa \
   --backup-dest /u03/backups \
   --ora-swlib-path /u01/oracle_install \
   --ora-version 19 \
   --ora-release latest \
   --ora-swlib-type gcs \
   --ora-data-mounts db1_mounts.json \
   --ora-data-destination /u02/oradata \
   --ora-reco-destination /u03/fast_recovery_area \
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
