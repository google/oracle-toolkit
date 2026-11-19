# Oracle Zero Downtime Migration (ZDM) Playbook for Google Cloud

## 1. Migration Decision Matrix

| Migration Mode | Best Suited For | Downtime Window | Toolchain Required |
| :--- | :--- | :--- | :--- |
| **Physical Online** | Same-platform (Linux to Linux), same version migrations to ExaCS, DBCS, or GCE. | < 5 minutes (Data Guard switchover) | ZDM Service Node + RMAN + Data Guard |
| **Physical Offline** | Maintenance-window backups where database is stopped during final sync. | Hours (depends on DB size) | ZDM Service Node + RMAN Transport |
| **Logical Online** | Cross-platform (AIX/Solaris to Linux), version upgrades (11g/12c to 19c/23ai), and migrations to **ADB-S**. | < 5 minutes (OGG CDC catch-up) | ZDM Service Node + Data Pump + GoldenGate 23ai |
| **Logical Offline** | Schema-level migrations where source changes are paused. | Maintenance window | ZDM Service Node + Data Pump + GCS + DBMS_CLOUD |

---

## 2. End-to-End Migration Workflow

### Step 1: Pre-requisites & Wallet Generation
Generate encrypted auto-login PKCS12 wallets to avoid plain-text password exposure:
```bash
./scripts/migration/create_zdm_wallets.sh
```

### Step 2: GoldenGate 23ai Image Mirroring (Logical Online Only)
Mirror the official Oracle GoldenGate 23ai microservices image to GCP Artifact Registry:
```bash
./scripts/migration/publish_goldengate_image.sh
```

### Step 3: Provision Migration Infrastructure
Deploy the ZDM controller VM and staging GCS bucket:
```bash
cd terraform/environments/gce
terraform init && terraform apply
```

### Step 4: Run Evaluation Pre-Check (`-eval`)
SSH into the ZDM VM and validate all connectivity and parameters:
```bash
zdmcli migrate database -rsp /u01/zdm/zdmbase/zdm_logical.rsp -sourcenode src-host -tgtdbconnection tgt-host:1521/tgtsvc -eval
```

### Step 5: Execute Migration & Cutover
```bash
zdmcli migrate database -rsp /u01/zdm/zdmbase/zdm_logical.rsp -sourcenode src-host -tgtdbconnection tgt-host:1521/tgtsvc
```
