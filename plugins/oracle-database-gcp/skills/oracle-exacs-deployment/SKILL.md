---
name: oracle-exacs-deployment
description: >-
  Architect, size, and deploy Oracle Exadata Database Service on Dedicated Infrastructure (ExaCS) on Oracle Database@Google Cloud.
  Use when the user asks to provision or configure Exadata Infrastructure (X11M), Exadata VM Clusters, ODB Networks,
  peered delegated Client/Backup subnets, ASM disk groups, or RAC clusters on co-located Oracle cloud hardware inside GCP.
---

# Oracle Exadata Database Service on Dedicated Infrastructure (ExaCS)

This skill provides end-to-end guidance for provisioning and configuring **Oracle Exadata Database Service on Dedicated Infrastructure (ExaCS)** on **Oracle Database@Google Cloud (ODB@GCP)**.

---

## 1. Architectural Blueprint & Component Overview

ExaCS co-locates Oracle Exadata hardware directly inside Google Cloud data centers:
* **Exadata Infrastructure (`google_oracle_database_cloud_exadata_infrastructure`)**:
  * Physical compute servers (minimum 2) and high-performance intelligent storage servers (minimum 3).
  * Supported Hardware Shapes: `Exadata.X11M`.
* **Exadata VM Cluster (`google_oracle_database_cloud_vm_cluster`)**:
  * Multi-node RAC virtual cluster running on top of the dedicated Exadata infrastructure.
  * Grid Infrastructure (GI) versions: `19.0.0.0` or `23.0.0.0`.
  * ASM Disk Groups (`+DATA`, `+RECO`) with native flash cache and Smart Scans.
* **ODB Peered Network Topology**:
  * **ODB Network (`google_oracle_database_odb_network`)**: Peered directly with GCP VPC.
  * **Client Delegated Subnet (`google_oracle_database_odb_subnet` with purpose `CLIENT_SUBNET`)**: Dedicated to application and SCAN listener traffic on port 1521/1522.
  * **Backup Delegated Subnet (`google_oracle_database_odb_subnet` with purpose `BACKUP_SUBNET`)**: High-throughput path for RMAN backups, Data Guard standby redo transport, and GCS staging.

---

## 2. Terraform Module Reference

Deploy using the pre-packaged environment blueprint at `terraform/environments/oracle_db_gcp_exacs`:

```hcl
# 1. Peered ODB Network
module "odb_network" {
  source          = "../../modules/gcp_odb_network"
  network_name    = var.vpc_name
  vpc_project     = var.project_id
  odb_network_id  = var.odb_network_id
  location        = var.region
  gcp_oracle_zone = var.zone
}

# 2. Delegated Client & Backup Subnets
module "odb_client_subnet" {
  source            = "../../modules/gcp_odb_subnet"
  odb_subnet_id     = var.odb_client_subnet_id
  location          = var.region
  vpc_project       = var.project_id
  odb_network_id    = module.odb_network.odb_network_id
  subnet_cidr_range = "10.150.20.0/24"
  subnet_purpose    = "CLIENT_SUBNET"
}

module "odb_backup_subnet" {
  source            = "../../modules/gcp_odb_subnet"
  odb_subnet_id     = var.odb_backup_subnet_id
  location          = var.region
  vpc_project       = var.project_id
  odb_network_id    = module.odb_network.odb_network_id
  subnet_cidr_range = "10.150.21.0/24"
  subnet_purpose    = "BACKUP_SUBNET"
}

# 3. Exadata Infrastructure
module "exadata_infrastructure" {
  source                          = "../../modules/gcp_exadata_infra"
  location                        = var.region
  exa_infra_project               = var.project_id
  cloud_exadata_infrastructure_id = "exa-infra-primary"
  gcp_oracle_zone                 = var.zone
  shape                           = "Exadata.X11M"
  compute_count                   = 2
  storage_count                   = 3
  deletion_protection             = true
}

# 4. Exadata VM Cluster
module "exadata_vmcluster" {
  source                          = "../../modules/gcp_exadata_vmcluster"
  location                        = var.region
  exa_infra_project               = var.project_id
  cloud_exadata_infrastructure_id = module.exadata_infrastructure.cloud_exadata_infrastructure_id
  cloud_vm_cluster_id             = "exa-vmcluster-primary"
  exa_vm_project                  = var.project_id
  vpc_project                     = var.project_id
  odb_network_id                  = module.odb_network.odb_network_id
  odb_client_subnet_id            = module.odb_client_subnet.odb_subnet_id
  odb_backup_subnet_id            = module.odb_backup_subnet.odb_subnet_id
  license_type                    = "BRING_YOUR_OWN_LICENSE"
  ssh_public_keys                 = [var.ssh_public_key]
  cpu_core_count                  = 32
  memory_size_gb                  = 60
  db_node_storage_size_gb         = 120
  data_storage_size_tb            = 2.0
  gi_version                      = "19.0.0.0"
  hostname_prefix                 = "exanode"
}
```

---

## 3. Step-by-Step Deployment Runbook

1. **Pre-flight Validation**:
   ```bash
   ./scripts/migration/pre_validate.sh
   ```
2. **Configure Variables**:
   ```bash
   cd terraform/environments/oracle_db_gcp_exacs
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with project_id, region, zone, ssh_public_keys, and compute sizing
   ```
3. **Provision Infrastructure**:
   ```bash
   terraform init
   terraform apply
   ```
4. **Post-Deployment Verification**:
   * Verify SCAN listener resolution from GCP VPC client VMs:
     ```bash
     nslookup exanode-scan.client.odb.gcp.internal
     nc -zv exanode-scan.client.odb.gcp.internal 1521
     ```
   * Connect via SQL*Net using TNS connection string:
     ```sql
     CONNECT system/SecretPassword123#@//exanode-scan.client.odb.gcp.internal:1521/pdb1.gcp.internal
     ```
