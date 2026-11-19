# Oracle Database Migration to Google Cloud: Checklist & FAQ

This document serves as an architectural blueprint, migration checklist, and FAQ for migrating Oracle databases to Google Cloud Platform (GCP)—specifically targeting **Google Cloud Bare Metal Solution (BMS)**, **Compute Engine VMs (GCE)**, and **Oracle Database@Google Cloud** (colocated Exadata Cloud Infrastructure).

---

## 🗺️ Architectural Decision Tree

Use this decision tree to identify the optimal migration methodology based on your target cloud platform, source operating system endianness, database size, and downtime constraints.

![Oracle Database Migration Decision Tree](http://llm4sre-summarizer.corp.google.com/img/tmp/352853e5)

---

## 📋 Comprehensive Migration Checklist

### Phase 1: Assessment & Discovery
- [ ] **Run Database Migration Assessment (DMA):** Execute the DMA collector tool on the source database to discover inventory, features in use, schemas, and resource usage characteristics (CPU cores, RAM, active IOPS).
- [ ] **Verify Source Platform Endianness:** Check the operating system of the source Oracle server:
  - **Big-Endian:** IBM AIX, HP-UX, Solaris SPARC (requires cross-platform/cross-endian migration methods like XTTS or GoldenGate).
  - **Little-Endian:** Red Hat Enterprise Linux (RHEL), Oracle Linux, Windows (supports native physical replication like Data Guard).
- [ ] **Catalog Features and Options:** List all advanced options in use, including RAC (Real Application Clusters), Partitioning, Spatial & Graph, Advanced Compression, and TDE (Transparent Data Encryption).
- [ ] **Determine Downtime Windows (SLA):** Establish the maximum allowable downtime for the business cutover:
  - **Near-Zero Downtime (Minutes):** Requires online replication methods (Data Guard, Active Data Guard, GoldenGate, ZDM Logical/Physical Online).
  - **Allows Downtime (Hours):** Allows offline backup/restore or export/import methods (RMAN Transport, Data Pump Conventional, ZDM Offline).

### Phase 2: Cloud Foundation & Network Sizing
- [ ] **Size Target Infrastructure:** Size your target CPU, memory, and storage based on DMA right-sizing recommendations. Decide between BMS (for RAC or native bare metal performance) and Oracle Database@Google Cloud (for Exadata co-location).
- [ ] **Configure Cloud Interconnect:** Establish a redundant Google Cloud Interconnect (Partner or Dedicated) with high bandwidth and latency below 2ms to handle both physical replication traffic and application latency.
- [ ] **Deploy GCS Buckets:** Set up Google Cloud Storage (GCS) buckets with standard or coldline storage tiers to stage backup sets and export files. Install the Google Cloud SDK or `gsutil` on the source/gateway nodes.
- [ ] **Review Security & KMS Controls:** Ensure target networks adhere to strict residency and compliance rules. Configure Oracle TDE (Transparent Data Encryption) and integrate with Google Cloud KMS or OCI KMS if using Oracle Database@Google Cloud.

### Phase 3: Migration Execution & Dry Runs
- [ ] **Establish a Disaster Recovery (DR) Pilot:** Begin by configuring Google Cloud as a passive DR environment. This is a low-risk, phased approach to validate network latency, synchronization performance, and standard operating procedures before the final cutover.
- [ ] **Choose and Setup Automated Orchestration:**
  - For BMS, leverage **WaveRunner** to automate deployment, cluster software installation, parameter configuration, and dynamic scaling using Ansible and Terraform.
  - For Oracle Database@Google Cloud, prepare **Zero Downtime Migration (ZDM)** configuration files and connectivity keys.
- [ ] **Perform Dry-Run Migration:** Execute a mock migration with real data to benchmark initial replication synchronization speeds and measure tablespace transport conversion rates.
- [ ] **Conduct Data Integrity Verification:** Run checksum validation (e.g., RMAN verification or Data Pump schema comparison) to ensure zero block corruption or logical loss.

### Phase 4: Cutover & Go-Live
- [ ] **Perform Dry-Run Failover / Switchover Testing:** Test the application failover path and measure DNS propagation delay.
- [ ] **Execute Final Synchronization:** Apply the final incremental backup (for XTTS) or complete the physical switchover (for Data Guard) within the designated maintenance window.
- [ ] **Run Post-Migration Sanity Checks:** Run database and application-level sanity scripts, verify user accounts and object permissions, and check database optimizer statistics.
- [ ] **Activate Fallback Strategy:** Establish a reverse-replication pipeline (using GoldenGate or active standby) back to the on-premises source for at least 24 to 72 hours in case of a critical rollback scenario.

---

## ❓ Frequently Asked Questions (FAQ)

### General Questions

#### Q1: What are the main differences between Bare Metal Solution (BMS) and Oracle Database@Google Cloud?
*   **Bare Metal Solution (BMS):** A dedicated, regional hardware offering hosted in collocated facilities with sub-millisecond latency to GCP. It runs on physical Linux servers, allowing you to run native Oracle workloads including Real Application Clusters (RAC), physical Data Guard, and standard RMAN backups while reusing existing on-premises licenses.
*   **Oracle Database@Google Cloud:** A joint offering between Google and Oracle. Exadata Database Service and Autonomous Database run on OCI-engineered systems inside Google Cloud's data centers, co-located natively within the same VPC. This represents a fully co-managed or fully managed Exadata-powered cloud service.

#### Q2: What is the Database Migration Assessment (DMA)?
The **Database Migration Assessment (DMA)** (formerly known as project Optimus Prime) is a Google-funded engagement tool. It collects current database configuration and resource metrics from your on-premises databases to recommend the best sizing, compatibility, and target architecture on GCP. It outputs a comprehensive workload assessment report for both homogeneous (BMS) and heterogeneous (modernizing to PostgreSQL or Spanner) migration targets.

---

### Migration Tool Questions

#### Q3: What is Zero Downtime Migration (ZDM) and when should it be used?
**ZDM** is Oracle’s official tool to automate and simplify migrations to Exadata and cloud environments. It supports both **Online** (near-zero downtime) and **Offline** (with maintenance window) migrations:
*   **Physical Online:** Best for same-platform migrations, utilizing physical block backups (RMAN) and physical replication (Data Guard) to synchronize databases with minimal downtime.
*   **Logical Online:** Best for cross-platform or cross-version migrations, employing Data Pump to instantiate the schema and GoldenGate to continuously replicate change data capture streamzs.

#### Q4: How does XTTS (Cross-Platform Transportable Tablespaces) work for AIX-to-Linux migrations?
Because AIX uses a Big-Endian byte order and GCP Linux uses Little-Endian, you cannot simply copy a physical database. **XTTS v4** with incremental backups allows migrating very large databases by:
1. Transferring the metadata (exporting/importing database schemas via Data Pump).
2. Transferring the physical datafiles and executing an `RMAN CONVERT` command to translate the byte ordering from Big-Endian to Little-Endian.
3. Continually applying incremental physical backups to keep the target in sync, ensuring the final cutover window only requires copying the changes since the last incremental run.

#### Q5: Can I upgrade my Oracle database during a Data Guard physical migration?
No. **Oracle Data Guard** is a physical replication tool requiring block-for-block structural identity between the primary and standby databases. You cannot use Data Guard to migrate while upgrading major database versions (e.g., Oracle 11g directly to 19c) in a single step. For migrations requiring simultaneous version upgrades, logical migration methods such as **Data Pump**, **Oracle GoldenGate**, or **ZDM Logical** must be utilized.

#### Q6: How can Google Cloud Storage (GCS) speed up RMAN-based migrations?
BMS target servers and Compute Engine VMs can be directly connected to high-performance GCS buckets via the Google Cloud SDK and gsutil. During RMAN-based migrations, you can write RMAN backup sets directly to Cloud Storage or utilize the Google Cloud Storage Transfer Service to stage large physical database backups. This avoids the need to purchase large local intermediate disk drives and speeds up physical restores.
