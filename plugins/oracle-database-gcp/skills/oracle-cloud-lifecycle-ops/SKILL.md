---
name: oracle-cloud-lifecycle-ops
description: >-
  Perform health assessments, pre-flight validations, OPatch maintenance, and safe decommissioning for Oracle on GCP.
  Use when the user requests Oracle Autonomous Health Framework (AHF / ORAchk) execution, GCS installation media validation (check-swlib.sh),
  OPatch release updates (apply-patch.sh), or destructive brute-force database and host cleanup (cleanup-oracle.sh / brute-cleanup.yml).
---

# Oracle Cloud Lifecycle Operations, Health & Teardown

This skill covers Day-2 operations, health validation, patch management, and environment teardown for Oracle Databases on Google Cloud.

---

## 1. Health Assessment with Autonomous Health Framework (AHF / ORAchk)

Execute ORAchk to benchmark the host, database parameters, kernel settings, and storage alignment against Oracle Maximum Availability Architecture (MAA) standards:

```bash
# Install and run ORAchk on target database instance
./check-oracle.sh   --instance-ip-addr 10.140.0.10   --ahf-location gs://my-oracle-installation-media-bucket   --ahf-install   --run-orachk
```

---

## 2. Software Media Library Validation

Validate the presence of required Oracle Grid Infrastructure, RDBMS binaries, and Release Updates in GCS buckets before starting deployments:

```bash
./check-swlib.sh   --ora-swlib-bucket gs://my-oracle-installation-media-bucket   --ora-version 19   --ora-release latest   --ora-edition EE   --ora-disk-mgmt ASMUDEV
```

---

## 3. Patch Management & Release Updates

Apply quarterly Release Updates (RUs) and one-off OPatch fixes:

```bash
./apply-patch.sh   --ora-swlib-bucket gs://my-oracle-installation-media-bucket   --instance-ip-addr 10.140.0.10   --instance-ssh-user ansible   --instance-ssh-key ~/.ssh/id_rsa   --ora-version 19   --ora-release 19.23.0.0.0
```

---

## 4. Teardown & Decommissioning

* **Destructive Host Cleanup (GCE / BMS)**:
  Wipe Oracle processes, unmount LVM filesystems, and unbind ASM disks without terminating the underlying VM:
  ```bash
  ./cleanup-oracle.sh     --instance-ip-addr 10.140.0.10     --instance-ssh-user ansible     --instance-ssh-key ~/.ssh/id_rsa     --yes-i-am-sure
  ```
* **Migration Workspace Cleanup**:
  Decommission local ZDM jobs and remove auto-login wallets:
  ```bash
  ./scripts/migration/cleanup_migration.sh
  ```
