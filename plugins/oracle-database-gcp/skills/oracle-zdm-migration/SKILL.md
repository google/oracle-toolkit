---
name: oracle-zdm-migration
description: >-
  Orchestrate zero-downtime database migrations to Oracle Database@Google Cloud (ExaCS, Exascale, ADB-S, DBCS) and GCE.
  Use when the user requests database migration using Oracle Zero Downtime Migration (ZDM) or Oracle GoldenGate 23ai CDC Hub,
  Physical Online (RMAN + Data Guard, < 5 min cutover), Logical Online (parallel Data Pump + GoldenGate 23ai CDC),
  passwordless PKCS12 auto-login wallets (orapki / mkstore), response file generation, or migration pre-flight checks.
---

# Oracle Zero Downtime Migration (ZDM) & GoldenGate 23ai

This skill automates mission-critical Oracle database migrations to **Oracle Database@Google Cloud** (ExaCS, Exascale, ADB-S, DBCS, GCE) using **Oracle Zero Downtime Migration (ZDM)** and **Oracle GoldenGate 23ai**.

---

## 1. Migration Decision Matrix

| Migration Mode | Best Suited For | Downtime Window | Toolchain Required |
| :--- | :--- | :--- | :--- |
| **Physical Online** | Same-platform (Linux to Linux), same version migrations to ExaCS, DBCS, or GCE. | < 5 minutes (Data Guard switchover) | ZDM Service Node + RMAN + Data Guard |
| **Physical Offline** | Same-platform migrations with maintenance window. | Maintenance window | ZDM Service Node + RMAN backup/restore |
| **Logical Online** | Cross-platform (AIX/Solaris to Linux), version upgrades (11g/12c to 19c/23ai), and migrations to **ADB-S**. | < 5 minutes (OGG CDC catch-up) | ZDM Service Node + Data Pump + GoldenGate 23ai |
| **Logical Offline** | Schema-level migrations where source changes are paused. | Maintenance window | ZDM Service Node + Data Pump + GCS + DBMS_CLOUD |

---

## 2. End-to-End Execution Runbook

### Step 1: Pre-validation & Environment Sizing
```bash
# 1. Validate GCP APIs and permissions
./scripts/migration/pre_validate.sh

# 2. Launch the interactive Migration Wizard to generate terraform.tfvars and response files
./scripts/migration/wizard.sh
```

### Step 2: Passwordless Wallet Creation
Generate encrypted auto-login PKCS12 wallets using `orapki` and `mkstore` to eliminate cleartext password storage:
```bash
./scripts/migration/create_zdm_wallets.sh
```

### Step 3: GoldenGate 23ai Image Publishing (For Logical Online)
Mirror the official Oracle GoldenGate 23ai microservices image to GCP Artifact Registry:
```bash
./scripts/migration/publish_goldengate_image.sh
```

### Step 4: Deploy Migration Controller
```bash
# Deploy ZDM Controller on GCE VM (or GKE Pod)
cd terraform/environments/gce
terraform init && terraform apply
```

### Step 5: Run Pre-Flight Connectivity Tests
```bash
# Physical Migration Pre-checks (Port 1521, SSH keys, GCS bucket)
./tests/validate_zdm_physical_prechecks.sh --source-ip 10.10.1.5 --target-ip 10.150.20.10 --gcs-bucket gs://my-zdm-bucket

# Logical Migration Pre-checks (TCPS Port 1522, mTLS wallet, GCS bucket)
./tests/validate_zdm_logical_prechecks.sh --source-ip 10.10.1.5 --target-endpoint adbs-private.odb.gcp.internal --wallet-path /opt/oracle/wallet --gcs-bucket gs://my-zdm-bucket
```

### Step 6: Execute ZDM Evaluation & Live Cutover
```bash
# 1. Dry-run evaluation check (-eval)
zdmcli migrate database -rsp /u01/zdm/zdmbase/zdm_logical.rsp -sourcenode src-host -tgtdbconnection tgt-host:1521/tgtsvc -eval

# 2. Live migration with zero-downtime cutover
zdmcli migrate database -rsp /u01/zdm/zdmbase/zdm_logical.rsp -sourcenode src-host -tgtdbconnection tgt-host:1521/tgtsvc
```
