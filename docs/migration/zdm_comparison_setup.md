# Oracle ZDM: Tool Comparison and Software Setup Guide

This document provides a comparison of Oracle database migration methods and outlines the steps to install and patch the Zero Downtime Migration (ZDM) software.

---

## 1. Migration Tools Comparison (ZDM vs. OCI DMS)

Oracle offers two primary tools built on the ZDM engine: Zero Downtime Migration (ZDM) CLI and OCI Database Migration (DMS) managed service.

| Feature / Capability | Zero Downtime Migration (ZDM) CLI | OCI Database Migration (DMS) Service |
|:---|:---:|:---:|
| **Management Model** | User-managed software installation & lifecycle | Fully managed OCI cloud service |
| **User Interface** | Command Line Interface (`zdmcli`) | OCI Console Graphic Interface |
| **Physical Online Migration (Data Guard)** | ✅ Supported | ❌ Not Supported |
| **Physical Offline Migration (RMAN)** | ✅ Supported | ❌ Not Supported |
| **Logical Online Migration (Data Pump + GoldenGate)** | ✅ Supported | ✅ Supported |
| **Logical Offline Migration (Data Pump)** | ✅ Supported | ✅ Supported |
| **Custom User Action Scripts** | ✅ Supported (Pre/Post-phase shell scripts) | ❌ Not Supported |
| **MySQL Database Migration** | ❌ Not Supported | ✅ Supported |
| **CPAT Integration** | ✅ Supported (CLI execution) | ✅ Supported (Interactive report) |

---

## 2. Migration Method Comparison

When planning a database migration to GCP, select the appropriate method based on your target architecture and downtime constraints.

### Physical Migration (Data Guard / RMAN)
* **How it works:** ZDM sets up an Oracle Active Data Guard standby database at the target and synchronizes it with the source. Cutover is a switchover operation.
* **Pros:** Negligible downtime (seconds), low network bandwidth overhead (transmits redo logs instead of full schemas), supports large databases.
* **Cons:** Source and target databases must be on the same version and platform (e.g., Linux to Linux). Requires direct SSH access to both DB operating systems.
* **GCP Targets:** Standard Compute Engine VM, Exadata Database Service (ExaCS), and Base Database Service (DBCS). *Not supported on Autonomous Database.*

### Logical Migration (Data Pump + GoldenGate)
* **How it works:** ZDM performs a schema-level export using Data Pump, copies files to GCS/Object storage, imports schemas to the target, and uses GoldenGate to replicate transaction changes until cutover.
* **Pros:** Supports cross-platform and cross-version migrations (e.g., AIX/Windows to Linux, 11g to 19c/23ai), supports migrating subset of schemas.
* **Cons:** Higher downtime for offline, complex replication configuration for online.
* **GCP Targets:** GCE VM, ExaCS, DBCS, and Autonomous Database Serverless (ADB-S).

---

## 3. ZDM Host OS Prerequisites

The ZDM Service Node VM must run one of the following operating systems:
- **Oracle Linux 7** or **Oracle Linux 8**
- **Red Hat Enterprise Linux 8**

### Required OS Packages
Ensure the following packages are installed on the ZDM VM before running the installer:

* **Oracle Linux 8 / RHEL 8:**
  ```bash
  sudo dnf install -y unzip expect glibc-devel libaio libnsl ncurses-compat-libs perl-interpreter openssh-clients
  ```
* **Oracle Linux 7:**
  ```bash
  sudo yum install -y unzip expect glibc-devel libaio perl-interpreter openssh-clients
  ```

---

## 4. Software Downloads & Official References

* **Oracle ZDM Software Downloads:** [Oracle ZDM Download Page](https://www.oracle.com/database/technologies/rac/zdm-downloads.html)
  * Always download the latest version (e.g., ZDM 21.5.x for modern migrations).
* **My Oracle Support (MOS) Key Documents:**
  * **Doc ID 2343806.1:** Zero Downtime Migration (ZDM) Master Note / FAQ (Critical compatibility checklist)
  * **Doc ID 2577344.1:** ZDM Logical Migration Best Practices (Data Pump schema details)
  * **Doc ID 2658835.1:** Troubleshooting ZDM Migrations (Common execution step errors)

---

## 5. Software Installation & Services

### Detailed Installation Steps
1. **Prepare OS user and group:**
   ```bash
   sudo groupadd zdm
   sudo useradd -g zdm -m -s /bin/bash zdmuser
   ```
2. **Create folder structures:**
   ```bash
   sudo mkdir -p /u01/zdm/zdmhome
   sudo mkdir -p /u01/zdm/zdmbase
   sudo chown -R zdmuser:zdm /u01/zdm
   ```
3. **Configure the zdmuser profile:**
   Append these lines to `/home/zdmuser/.bashrc`:
   ```bash
   export ZDM_BASE=/u01/zdm/zdmbase
   export ZDM_HOME=/u01/zdm/zdmhome
   export PATH=$PATH:$ZDM_HOME/bin
   ```
   Apply the changes: `source /home/zdmuser/.bashrc`.
4. **Download and unzip the installation files:**
   Place the downloaded ZIP (e.g., `V1035502-01.zip` or newest ZDM kit) into `/u01/zdm/` and unzip:
   ```bash
   su - zdmuser
   unzip -q /u01/zdm/V1035502-01.zip -d /u01/zdm/zdminstall/
   ```
5. **Run the installation script:**
   ```bash
   cd /u01/zdm/zdminstall
   ./zdminstall.sh setup oraclehome=$ZDM_HOME oraclebase=$ZDM_BASE ziploc=/u01/zdm/zdminstall/zdm_home.zip
   ```

### Managing the ZDM Daemon
* **Start Service:** `$ZDM_HOME/bin/zdmservice start`
* **Stop Service:** `$ZDM_HOME/bin/zdmservice stop`
* **Status Verification:** `$ZDM_HOME/bin/zdmservice status`
* **Version Verification:** `$ZDM_HOME/bin/zdmcli -build`

---

## 6. Patching the ZDM Software

To update or patch ZDM (e.g., upgrading from 21.5.0 to 21.5.2):
1. Stop the running ZDM daemon service:
   ```bash
   $ZDM_HOME/bin/zdmservice stop
   ```
2. Execute the patching command pointing to the new ZIP archive:
   ```bash
   ./zdminstall.sh patch oraclehome=$ZDM_HOME oraclebase=$ZDM_BASE ziploc=/path/to/zdm_patch.zip
   ```
3. Start the service again and check the version:
   ```bash
   $ZDM_HOME/bin/zdmservice start
   $ZDM_HOME/bin/zdmcli -build
   ```

