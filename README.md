# oracle-toolkit

Enterprise Toolkit for deploying, managing, and migrating Oracle Databases on Google Cloud.

Supports usage with:

- **[Google Compute Engine (GCE)](https://cloud.google.com/products/compute)** (IaaS):
  - Self-managed Oracle Database (11g, 12c, 19c, 21c, 23ai, Free Edition) in Single Instance and Data Guard Standby configurations.
  - Multi-tier storage backends: Hyperdisk Balanced, Hyperdisk Extreme, Hyperdisk Throughput, Hyperdisk Storage Pools, and Google Cloud NetApp Volumes (GCNV) iSCSI multipath LUNs.
  - Automated host provisioning, HugePages, kernel tuning, ASM (ASMUDEV / ASMLIB) / XFS, and DBCA database creation via Ansible.
- **[Bare Metal Solution (BMS)](https://cloud.google.com/bare-metal)** (Bare Metal IaaS):
  - Certified regional bare metal Linux hardware with sub-millisecond interconnect latency to GCP VPC.
  - High-performance multi-node Oracle Real Application Clusters (RAC) and physical Data Guard.
  - Native Cloud Storage (GCS) integration for high-speed backup, staging, and media libraries.
- **[Oracle Database@Google Cloud (ODB@GCP)](https://cloud.google.com/oracle-database-at-google-cloud)** (Co-located DBaaS):
  - **Exadata Database Service on Dedicated Infrastructure (ExaCS)**: Dedicated compute servers (min 2) and intelligent storage servers (min 3) running on `Exadata.X11M` hardware co-located inside Google Cloud data centers.
  - **Exadata Database Service with Exascale (ExaDB-D Exascale)**: Next-generation Exadata architecture featuring virtualized intelligent storage pools, decoupled granular online ECPU and storage auto-scaling, low-capacity starter footprints, and instantaneous thin clones.
  - **Autonomous Database Serverless (ADB-S)**: Fully managed, self-driving Oracle database with automated patching, indexing, and tuning, auto-scaling ECPUs, support for `OLTP` (ATP) and `DW` (ADW) workloads, and secure private endpoints over **TCPS port 1522** (mTLS).
  - **Base Database Service (DBCS / DB System)**: Virtual Machine DB System with ECPU compute model, customizable block storage, and unified auditing.
  - **ODB Peered Networking**: Native `google_oracle_database_odb_network` peered directly with Google Cloud VPC, featuring dedicated delegated subnets (`CLIENT_SUBNET` for application & SCAN listener traffic, `BACKUP_SUBNET` for RMAN & Data Guard redo transport).
- **Oracle Zero Downtime Migration (ZDM) & GoldenGate 23ai**:
  - **Physical Online Migration**: RMAN block-level backup to GCS + active Data Guard physical standby synchronization (< 5 min cutover window).
  - **Physical Offline Migration**: Direct RMAN backup restore and transport.
  - **Logical Online Migration**: Schema instantiation via parallel Data Pump export/import + real-time Change Data Capture (CDC) via Oracle GoldenGate 23ai Microservices Hub (zero downtime).
  - **Logical Offline Migration**: Parallel Data Pump export to GCS + `DBMS_CLOUD` import.
  - **Security & Automation**: Passwordless PKCS12 auto-login wallets (`orapki`/`mkstore`), non-root `zdmuser` execution, and Private Google Access.
  - **Runtime Orchestrators**: Dedicated Compute Engine VM (`zdm_node`) or containerized Kubernetes Pod on GKE (`zdm_container`).

---

## Architecture & Documentation

- [AI Agent Plugin & Gemini Marketplace Setup FAQ](docs/agent_skills_marketplace_faq.md)
- [Exadata Cloud Service & Exascale Architecture](docs/exacs_exascale_architecture.md)
- [Autonomous Database Serverless (ADB-S) Architecture](docs/adb_s_architecture.md)
- [Zero Downtime Migration (ZDM) Playbook](docs/zdm_migration_playbook.md)
- [Architecture Blueprints & Network Design](docs/migration/architecture_blueprints.md)
- [Migration Assessment & Execution Checklist](docs/migration/Migration_CheckList.md)
- [GCP Best Practices & Wallet Security FAQ](docs/migration/best_practices_faq.md)
- [GoldenGate 23ai Artifact Registry Publishing](docs/migration/goldengate_image_gcp_registry.md)
- [User Guide (GCE/BMS)](docs/user-guide.md)

---

## Quick Starts

### 1. Deploying Target Oracle Database@Google Cloud (ExaCS / Exascale / ADB-S)

Navigate to the appropriate environment blueprint:
```bash
# Example: Deploy Exadata Cloud Service / Exascale
cd terraform/environments/oracle_db_gcp_exacs
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform apply
```

```bash
# Example: Deploy Autonomous Database Serverless
cd terraform/environments/oracle_db_gcp_adbs
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform apply
```

### 2. Zero Downtime Migration (ZDM) Toolchain

1. **Pre-validate GCP APIs and permissions**:
   ```bash
   ./scripts/migration/pre_validate.sh
   ```
2. **Launch the interactive Migration Wizard**:
   ```bash
   ./scripts/migration/wizard.sh
   ```
3. **Generate passwordless auto-login wallets** (`orapki` / `mkstore`):
   ```bash
   ./scripts/migration/create_zdm_wallets.sh
   ```
4. **Publish GoldenGate 23ai Microservices image** to Artifact Registry:
   ```bash
   ./scripts/migration/publish_goldengate_image.sh
   ```
5. **Deploy the ZDM Migration Infrastructure**:
   ```bash
   cd terraform/environments/gce # Or terraform/environments/gke
   terraform init && terraform apply
   ```

---

## Quick Start: Self-Managed Oracle on GCE VM

1. Create a Google Cloud VM to act as a [control node](/docs/user-guide.md#control-node-requirements); it should be on a VPC network that has SSH access to the database host.
1. Create a Google Cloud VM to act as the database host. Add additional disks named `oracle_home`, `data`, and `reco` for the oracle_home, database data, and recovery area, respectively.
1. [Extract the toolkit code](/docs/user-guide.md#installing-the-toolkit) on the control node.
1. Create a Cloud Storage bucket to host Oracle software images.
     ```bash
     gcloud storage buckets create --uniform-bucket-level-access gs://installation-media-1234
     ```
1. [Download software](/docs/user-guide.md#downloading-and-staging-the-oracle-software) from Oracle and populate the bucket. Use [check-swlib.sh](/docs/user-guide.md#validating-media) to determine which files are required for your Oracle version.

1. On the control node, create an SSH key `~/.ssh/db1`.
1. On the database host, create a user `ansible` with sudo privileges. Add the SSH public key from the previous step into a `~ansible/.ssh/authorized_keys` file.
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
     }
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

Full documentation is available in the [user guide](/docs/user-guide.md).

---

## Destructive cleanup

An Ansible role and playbook performs a [destructive brute-force removal](/docs/user-guide.md#destructive-cleanup) of Oracle software and configuration. It does not remove other host prerequisites.

Run the destructive brute-force Oracle software removal with `cleanup-oracle.sh` or `ansible-playbook brute-cleanup.yml`.

---

## Contributing to the project

Contributions and pull requests are welcome. See [docs/contributing.md](docs/contributing.md) and [docs/code-of-conduct.md](docs/code-of-conduct.md) for details.

## The fine print

This product is [licensed](LICENSE) under the Apache 2 license. This is not an officially supported Google project.

