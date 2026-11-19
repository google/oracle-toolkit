---
name: oracle-dbcs-deployment
description: >-
  Provision and manage Base Database Service (DBCS / DB System) Virtual Machine instances on Oracle Database@Google Cloud.
  Use when the user requests single-instance or VM-based Oracle databases with ECPU compute, customizable block storage,
  DB home provisioning (19c / 23ai), TDE encryption wallets, and unified auditing on GCP.
---

# Base Database Service (DBCS) on Google Cloud

This skill provides workflows for provisioning and managing **Base Database Service (DBCS / DB System)** on **Oracle Database@Google Cloud**.

---

## 1. Architecture Overview

* **Virtual Machine Compute Model**: Scalable ECPU compute instances provisioned directly inside ODB Network.
* **Storage Options**: Scalable managed block storage (`data_storage_size_gb`).
* **Database Homes & Versions**: Supports Oracle Database 19c and 23ai Enterprise Edition and Standard Edition 2.
* **Security**: Transparent Data Encryption (TDE) wallet password automation and unified auditing enabled by default.

---

## 2. Terraform Deployment Blueprint

Deploy via `terraform/environments/oracle_db_gcp_dbcs`:

```hcl
module "db_system" {
  source                       = "../../modules/gcp_dbsystem"
  db_system_id                 = "dbcs-primary"
  location                     = var.region
  gcp_oracle_zone              = var.zone
  dbsystem_project             = var.project_id
  vpc_project                  = var.project_id
  odb_network_id               = module.odb_network.odb_network_id
  odb_subnet_id                = module.odb_client_subnet.odb_subnet_id
  ssh_public_keys              = var.ssh_public_keys
  ecpu_core_count              = 4
  hostname_prefix              = "dbcsnode"
  data_storage_size_gb         = 256
  shape                        = "odb.standard"
  initial_data_storage_size_gb = 256
  db_edition                   = "ENTERPRISE_EDITION"
  license_type                 = "BRING_YOUR_OWN_LICENSE"
  db_version                   = "19c"
  db_name                      = "ORCL"
  db_unique_name               = "ORCL_GCP"
  admin_pw                     = var.admin_pw
  tde_pw                       = var.tde_pw
  db_id                        = "orcl"
  enable_unified_auditing      = true
  deletion_protection          = true
}
```

---

## 3. Deployment Steps
1. Navigate to `terraform/environments/oracle_db_gcp_dbcs`.
2. Configure `terraform.tfvars` with passwords, SSH keys, and project details.
3. Run `terraform init && terraform apply`.
4. Connect via SSH to the VM node or connect directly to port 1521 listener.
