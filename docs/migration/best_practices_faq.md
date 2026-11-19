# Oracle ZDM Migration to GCP: Best Practices, Configurations, and FAQ

This document outlines architectural best practices, configuration settings, and FAQs for running Oracle Zero Downtime Migration (ZDM) on Google Cloud Platform.

---

## 1. Google Cloud Platform Best Practices

### Network & Security Architecture
* **Private Google Access:** Enable Private Google Access on the VPC subnets hosting the ZDM node and database instances. This allows nodes without public IPs to communicate with Google APIs and services (such as GCS buckets) privately over Google's internal network.
* **Identity-Aware Proxy (IAP):** Avoid assigning public IP addresses to the ZDM Service Node. Access the VM securely using SSH over Cloud IAP:
  ```bash
  gcloud compute ssh zdm-service-node --zone=<ZONE> --tunnel-through-iap
  ```
* **Firewall Isolation:** Apply strict target tags (`zdm-node`, `oracle-source-db`, `oracle-target-db`) to limit traffic. Ensure only the ZDM node can initiate SSH (port 22) connections to the DB servers, and restrict port 1521 (SQL*Net) traffic to the migrating nodes.

### Compute VM & Storage Sizing
* **Compute Sizing:** Allocate at least 4 vCPUs and 16 GB of RAM (e.g., GCP `e2-standard-4` or `n2-standard-4`) for the ZDM node. This ensures smooth log aggregation and execution of parallel target checks.
* **Disk Configuration:** Provision at least 100 GB of SSD persistent disk (`pd-ssd` or `pd-balanced`) for the ZDM base (`ZDM_BASE`) directory. Large migrations generate substantial trace and log files.
* **GCS Bucket Location:** Co-locate the GCS bucket in the same region as the target database to eliminate cross-region egress costs and maximize write/read throughput during backups.
* **Storage Lifecycle Rules:** Apply Object Lifecycle Management to the GCS bucket. Set a rule to delete backup files and Data Pump logs after 14 or 30 days to avoid accumulating storage costs.

### GCE Target DB Machine Shapes & Storage IOPS/Throughput

When sizing Google Compute Engine target instances for high-demand Oracle databases, leverage Google Cloud's high-performance machine families and Hyperdisk storage types:

| Machine Family | Storage Type | Max Provisioned IOPS | Max Throughput (MB/s) | Target Oracle Workload |
|:---|:---|:---:|:---:|:---|
| **C4** | Hyperdisk Extreme | 500,000 | 10,000 | Ultra-high IOPS OLTP databases |
| **M4N** | Hyperdisk Extreme | 500,000 | 12,500 | Maximum memory & high-throughput enterprise databases |
| **M4N** | Hyperdisk Balanced | 160,000 | 2,400 | High-capacity, balanced enterprise Oracle DB workloads |

---

## 2. Oracle ZDM Settings & Configurations

### Secure Password Management (Oracle Wallet)
Never store plaintext passwords in ZDM response files or command-line arguments. Secure them using Oracle Secret Store (Wallets) on the ZDM host.

#### Creating the Wallets
Create auto-login wallets for the database users:
```bash
# Create directory structures
mkdir -p $ZDM_BASE/wallets/src_sys
mkdir -p $ZDM_BASE/wallets/tgt_sys

# Create wallets
$ZDM_HOME/bin/orapki wallet create -wallet $ZDM_BASE/wallets/src_sys -auto_login_only
$ZDM_HOME/bin/orapki wallet create -wallet $ZDM_BASE/wallets/tgt_sys -auto_login_only
```

#### Storing Credentials
Add credentials to the wallets using `mkstore`:
```bash
# Store source database SYS password
$ZDM_HOME/bin/mkstore -wrl $ZDM_BASE/wallets/src_sys -createCredential store sysuser

# Store target database SYS password
$ZDM_HOME/bin/mkstore -wrl $ZDM_BASE/wallets/tgt_sys -createCredential store sysuser
```

#### Configuring the Response File
Reference the wallets in your `.rsp` migration configuration file:
* **Physical Migration Response File:**
  ```properties
  -sourcesyswallet /u01/zdm/zdmbase/wallets/src_sys
  -targetsyswallet /u01/zdm/zdmbase/wallets/tgt_sys
  ```
* **Logical Migration Response File:**
  ```properties
  WALLET_SOURCEADMIN=/u01/zdm/zdmbase/wallets/src_sys
  WALLET_TARGETADMIN=/u01/zdm/zdmbase/wallets/tgt_sys
  ```

### Data Guard Replication Tuning (Physical Migration)
When migrating over peered networks, optimize SQL*Net traffic:
* **Session Data Unit (SDU):** Set SDU to `32768` (32K) in `tnsnames.ora` and `sqlnet.ora` on both source and target to reduce network packet overhead.
* **Compression:** Enable Data Guard compression to decrease transit bandwidth usage:
  ```properties
  DATAGUARD_COMPRESSION=TRUE
  ```

---

## 3. Useful FAQ

### Q: Can Oracle ZDM run inside GKE containers?
**A:** Yes. Although Oracle only provides a ZIP installer for Linux x86-64, you can build a Docker image based on `oraclelinux:8` containing all ZDM prerequisites. In GKE, you run this container as a single-replica pod with a Persistent Volume Claim (`PVC`) for `$ZDM_BASE` (persisting logs and wallets). Map a GCP Service Account to GKE using **Workload Identity** to grant the container access to GCS without using static keys.

### Q: How does ZDM interface with Google Cloud Storage?
**A:** ZDM transfers files to cloud buckets in two ways:
1. **Logical Migration:** Data Pump dump files are uploaded directly to the GCS bucket using the ZDM service account credentials (managed via Workload Identity or VM scopes).
2. **Physical Migration:** ZDM can back up the database to a shared NFS directory (which can be backed by a GCP Filestore instance or mounted GCS bucket using `gcsfuse`) or use the RMAN Backup Cloud Service module configured with an S3-compatible endpoint pointing to GCS.

### Q: If a migration job fails, do I have to restart from scratch?
**A:** No. ZDM jobs are fully stateful and divided into operational steps (phases). If a phase fails (e.g., due to space limits or network blips):
1. Find the failed phase and error details:
   ```bash
   zdmcli query job -job <JOB_ID>
   ```
2. Resolve the underlying issue on the source or target database.
3. Resume the job from the exact point of failure:
   ```bash
   zdmcli resume job -job <JOB_ID>
   ```

### Q: Does ZDM support migrations between different database versions?
**A:** 
- **Logical Migrations (Data Pump + GoldenGate):** Yes, they support cross-version and cross-platform migrations (e.g., migrating from 11.2.0.4 on-premises to 19c or 23ai on Google Cloud).
- **Physical Migrations (Data Guard):** No, they require version parity. The target database version must be the same major version as the source (e.g., 19c to 19c).
