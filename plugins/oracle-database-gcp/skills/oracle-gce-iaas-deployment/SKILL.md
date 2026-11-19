---
name: oracle-gce-iaas-deployment
description: >-
  Deploy and manage self-managed Oracle Database on Google Compute Engine (GCE) and Bare Metal Solution (BMS).
  Use when the user requests self-managed Oracle installations (11g, 12c, 19c, 21c, 23ai, Free Edition), Single Instance,
  Data Guard Standby, Bare Metal RAC, Hyperdisk storage layouts (Balanced / Extreme / Throughput / Storage Pools),
  Google Cloud NetApp Volumes (GCNV) iSCSI multipath LUNs, ASM (ASMUDEV / ASMLIB) / XFS configurations, or Ansible DBCA automation.
---

# Self-Managed Oracle Database on Compute Engine (GCE) & Bare Metal Solution (BMS)

This skill provides step-by-step automation for deploying and managing self-managed Oracle Database instances on Google Cloud Infrastructure.

---

## 1. Supported Storage Backends & Architectures

* **Hyperdisk Balanced / Throughput / Extreme**: High-performance persistent disks attached to C4, M4N, N2, or N4 GCE machine types.
* **Hyperdisk Storage Pools**: Aggregated IOPS and throughput capacity shared across multiple disks and database VMs.
* **Google Cloud NetApp Volumes (GCNV) iSCSI Multipath**: High-throughput shared storage presented as `/dev/mapper/*` block devices for multi-instance or high-IOPS workloads.
* **Bare Metal Solution (BMS)**: Low-latency physical bare metal infrastructure for multi-node Oracle Real Application Clusters (RAC) and physical Data Guard.

---

## 2. Automated Deployment Workflow via `install-oracle.sh`

The toolkit orchestrates end-to-end host preparation, storage formatting, software installation, patching, and DBCA database creation:

```bash
# Example: Deploy 19c Enterprise Edition with ASM and GCS Backup on GCE VM
bash install-oracle.sh   --ora-swlib-bucket gs://my-oracle-installation-media-bucket   --instance-ssh-user ansible   --instance-ssh-key ~/.ssh/id_rsa   --backup-dest /u03/backups   --ora-swlib-path /u01/oracle_install   --ora-version 19   --ora-release latest   --ora-swlib-type gcs   --ora-data-mounts db1_mounts.json   --ora-data-destination /u02/oradata   --ora-reco-destination /u03/fast_recovery_area   --ora-db-name orcl   --instance-ip-addr 10.140.0.10
```

---

## 3. Storage Mount Definition (`db1_mounts.json`)

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
  }
]
```

---

## 4. Terraform IaaS Provisioning

To provision the underlying GCE VMs, disks, and control node:
```bash
cd terraform
cp terraform.tfvars.xfs.example terraform.tfvars # Or terraform.tfvars.asm.example
terraform init
terraform apply
```
