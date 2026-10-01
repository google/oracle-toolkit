---
name: oracle-adbs-deployment
description: >-
  Provision, configure, and manage Oracle Autonomous Database Serverless (ADB-S) on Oracle Database@Google Cloud.
  Use when the user requests Autonomous Transaction Processing (ATP / OLTP), Autonomous Data Warehouse (ADW / DW),
  ECPU autoscaling, storage autoscaling, automated backups, or secure private endpoint configuration over TCPS port 1522 via mTLS connection wallets.
---

# Oracle Autonomous Database Serverless (ADB-S) on Google Cloud

This skill provides comprehensive instructions for deploying and managing **Autonomous Database Serverless (ADB-S)** on **Oracle Database@Google Cloud**.

---

## 1. Core Architecture & Highlights

* **Fully Managed & Self-Driving**: Zero OS administration; automated patching, backups, indexing, and optimizer plan management.
* **Workload Profiles**:
  * **`OLTP`**: Autonomous Transaction Processing (ATP) optimized for high transaction throughput, JSON relational duality, and low latency.
  * **`DW`**: Autonomous Data Warehouse (ADW) optimized for complex analytical aggregations and vectorized processing.
* **Elastic Auto-scaling**: Automatic compute scaling up to 3x base ECPU allocation and automated storage growth without downtime.
* **Security & Private Endpoints**: Private endpoint integration inside `google_oracle_database_odb_network` and delegated `CLIENT_SUBNET` communicating over **TCPS port 1522** with mutual TLS (mTLS) client wallets (`cwallet.sso`).

---

## 2. Terraform Deployment Blueprint

Deploy via `terraform/environments/oracle_db_gcp_adbs`:

```hcl
module "autonomous_database" {
  source                          = "../../modules/gcp_adb"
  autonomous_database_id          = var.autonomous_database_id
  location                        = var.region
  adb_project                     = var.project_id
  vpc_project                     = var.project_id
  odb_network_id                  = module.odb_network.odb_network_id
  odb_subnet_id                   = module.odb_client_subnet.odb_subnet_id
  adb_admin_pw                    = var.adb_admin_password
  ecpu_count                      = 4                   # Base ECPUs
  data_storage_size_tb            = 1                   # Storage in TB
  db_version                      = "19c"               # 19c or 23ai
  workload_type                   = "OLTP"              # OLTP or DW
  db_edition                      = "ENTERPRISE_EDITION"
  license_type                    = "BRING_YOUR_OWN_LICENSE"
  backup_retention_period_days    = 60
  is_auto_scaling_enabled         = true                # Enable compute 3x auto-scaling
  is_storage_auto_scaling_enabled = true                # Enable storage auto-scaling
  deletion_protection             = true
}
```

---

## 3. Client Connection Runbook

1. **Deploy the ADB-S Instance**:
   ```bash
   cd terraform/environments/oracle_db_gcp_adbs
   terraform init && terraform apply
   ```
2. **Download & Stage Connection Wallet**:
   * Retrieve the client connection wallet (`Wallet_<dbname>.zip`) from the Google Cloud Console or OCI interface.
   * Unpack the wallet containing `cwallet.sso`, `tnsnames.ora`, and `sqlnet.ora` to a secure directory (e.g. `/opt/oracle/wallet`).
3. **Configure Environment & Test**:
   ```bash
   export TNS_ADMIN=/opt/oracle/wallet
   # Verify TCPS port 1522 connectivity
   ./tests/validate_zdm_logical_prechecks.sh --target-endpoint adbs-private.odb.gcp.internal --wallet-path /opt/oracle/wallet
   
   # Connect using SQL*Plus / SQLcl
   sqlplus admin/SecretPassword123#@adbs_high
   ```
