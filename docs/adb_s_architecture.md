# Oracle Database@Google Cloud: Autonomous Database Serverless (ADB-S) Architecture

## 1. Overview
**Autonomous Database Serverless (ADB-S)** on Google Cloud delivers a fully managed Oracle database with automated patching, tuning, backups, and elastic scaling, running directly within GCP data centers.

---

## 2. Key Architectural Characteristics
* **Zero Infrastructure Management**: Automated OS and database patching, maintenance, indexing, and optimizer plan baselining.
* **Elastic Compute & Storage**: Independent auto-scaling of ECPUs (up to 3x base allocation) and storage capacity in TB without application disruption.
* **Workload Optimization**:
  * **`OLTP`**: Autonomous Transaction Processing (ATP) optimized for high-concurrency, low-latency transaction processing.
  * **`DW`**: Autonomous Data Warehouse (ADW) optimized for complex analytical queries and parallel scans.
* **Secure Private Endpoints**: Integrated into the GCP VPC via ODB Network and delegated Client Subnet, communicating over **TCPS port 1522** with mutual TLS (mTLS) client wallets or TLS.

---

## 3. Connecting to ADB-S via mTLS Wallet
1. Provision the ADB-S instance using the Terraform module:
   ```bash
   cd terraform/environments/oracle_db_gcp_adbs
   terraform init && terraform apply
   ```
2. Download the client credential connection wallet (`cwallet.sso` and `tnsnames.ora`).
3. Set `TNS_ADMIN=/path/to/wallet` on client VMs and connect via SQL*Net:
   ```bash
   sqlplus admin/SecretPassword123#@adbs_high
   ```
