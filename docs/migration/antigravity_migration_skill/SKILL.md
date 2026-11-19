---
name: oracle-zdm-migration
description: Expert skill for provisioning Oracle Zero Downtime Migration (ZDM) nodes, GKE container services, target tuned GCE database VMs, and orchestrating connectivity validation check scripts on GCP.
---

# Antigravity Skill: Oracle Zero Downtime Migration to GCP

Use this skill when the user requests to:
1. Provision Oracle Zero Downtime Migration (ZDM) nodes on Google Cloud.
2. Package or deploy ZDM inside a GKE cluster.
3. Setup high-performance GCE VM target databases configured with Oracle Database parameters (Hugepages, LVM layouts).
4. Run validation tests and pre-check scripts.

---

## 🛠️ Design System & Components

This repository contains modularized infrastructure directories to spin up migration resources:

### 1. Reusable Infrastructure Modules
* **Networking (`modules/networking`):** Sets up VPCs, private subnets, ports `1521` (SQL*Net), `1522` (TCPS for Autonomous), and `22` (SSH) firewalls.
* **Storage (`modules/storage`):** Provisions GCS buckets with uniform access controls and IAM service account bindings.
* **ZDM Node VM (`modules/zdm_node`):** Spins up a tuned OL8 VM running the ZDM daemon process.
* **Target database GCE VM (`modules/oracle_gce_target`):** Sets up OL8 database targets with HugePages, system parameters, and separate LVM striped disks (`/u01` binaries, `/u02` data files, `/u03` redo recovery).
* **ZDM GKE Service (`modules/zdm_container`):** Packages ZDM into Docker container setups and registers PVC storage and K8s secrets.
* **GoldenGate Node (`modules/goldengate_node`):** Provisions GCE instances or GKE pods hosting GoldenGate Microservices for Logical Online replication.

### 2. Environment Frameworks
* **GCE Standard VM (`environments/gce`):** Instantiates networking, ZDM node, GCS storage, and target DB VM.
* **GKE Containerised ZDM (`environments/gke`):** Provisions a private GKE cluster, service accounts with Workload Identity bindings, ZDM daemon container, and optional GoldenGate pods.
* **Oracle Database@Google Cloud (`environments/db_at_gcp`):** Targets Exadata VM clusters, Autonomous Database Serverless, and DBCS VMs connected via low-latency interconnects.

---

## 🚀 Execution Workflow

### Step 1: Pre-validation Check
Before provisioning any resource, instruct the user to execute the authentication and API validation script:
```bash
./scripts/pre_validate.sh
```
This ensures the active user is logged into GCP and enables `compute`, `storage`, `container`, `secretmanager`, and `iam` service APIs.

### Step 2: Running the Wizard
To configure the environment variables and ZDM run scripts dynamically, execute the wizard generator:
```bash
./scripts/wizard.sh
```
This interactive script:
1. Prompts for target platform, migration method, GCS configurations, and IPs.
2. Generates a customized `terraform.tfvars` file under the selected target environment path.
3. Creates a customized `run_migration.sh` execution script.

### Step 3: Deployment
To deploy the target environment infrastructure, select one of the following:
* **Option A (Local CLI):**
  ```bash
  cd environments/<target_env>
  terraform init
  terraform apply
  ```
* **Option B (GCP Infrastructure Manager):**
  If you don't have Terraform locally, run the Infra Manager deploy script to execute cloud-managed deployments:
  ```bash
  ./scripts/deploy_infra_manager.sh
  ```

### Step 4: Run ZDM Verification Checks
Before submitting the migration job, execute the pre-checks on the ZDM host (VM or container pod) to confirm port access:
* **For Physical (Data Guard):**
  ```bash
  ./tests/validate_zdm_physical_prechecks.sh <source_db_ip> <target_db_ip> gs://<bucket_name>
  ```
* **For Logical (Autonomous DB):**
  ```bash
  ./tests/validate_zdm_logical_prechecks.sh <source_db_ip> <target_adb_endpoint> /path/to/wallet gs://<bucket_name>
  ```
* **For Infrastructure Manager Deployments Diagnostics:**
  ```bash
  ./scripts/migration/verify_state.sh
  ```

---

## 📈 ZDM Response File Tuning Best Practices

When ZDM executes migrations, configure templates [`zdm_physical.rsp.tpl`](../../../terraform/modules/zdm_node/templates/zdm_physical.rsp.tpl) and [`zdm_logical.rsp.tpl`](../../../terraform/modules/zdm_node/templates/zdm_logical.rsp.tpl) according to these principles:

### 1. Data Pump Tuning (Logical Migration)
* **Parallelism (`DATAPUMP_PARALLELISM`):** Set to `target_vCPUs * 2`. For example, on a `n2-standard-8` (8 vCPUs) target, set parallelism to `16`.
* **Compression:** Enable Data Pump compression on tables and metadata if network bandwidth is a bottleneck.
* **Encryption (`DATAPUMP_ENCRYPTION_MODE`):** Set to `ALL` to ensure compliance when moving sensitive databases.

### 2. Schema Management
* **Exclusion (`EXCLUDE_SCHEMAS`):** Always exclude system schemas (like `SYS`, `SYSTEM`, `DBSNMP`, `APEX_050000`, etc.) to prevent failures caused by trying to overwrite target database system objects.

### 3. Passwordless Wallet Configuration
* **Plaintext Password Avoidance:** Never write raw database passwords in the response file.
* **Secret Registration:**
  1. Add source/target SYS credentials to the ZDM wallet:
     ```bash
     zdmcli add alias -alias src_db_sys_secret
     zdmcli add alias -alias tgt_db_sys_secret
     ```
  2. Reference the aliases in your response configuration files:
     ```properties
     SRC_DB_PASSWORD_SECRET=src_db_sys_secret
     TGT_DB_PASSWORD_SECRET=tgt_db_sys_secret
     ```
