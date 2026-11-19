# Oracle DB Migration to GCP: Useful Resources and Links

This document summarizes the reference materials and links for migrating Oracle databases to Google Cloud Platform using Oracle Zero Downtime Migration (ZDM).

---

## 1. Oracle Database@Google Cloud (Multicloud Partnership)
* **Official Partnership Announcement:** [Oracle and Google Cloud Multicloud Partnership](https://www.oracle.com/news/announcement/oracle-and-google-cloud-announce-groundbreaking-multicloud-partnership-2024-06-11/)
* **GCP Product Overview:** [Oracle Database@Google Cloud on Google Cloud Console](https://cloud.google.com/oracle/database/)
* **OCI Product Page:** [Oracle Database@Google Cloud on OCI](https://www.oracle.com/cloud/google/oracle-database-at-google-cloud/)
* **Video Demonstration:** [Introducing Oracle Database@Google Cloud](https://youtu.be/zvyFoz8bmAc?si=uf0K-F5dgDsry0rH)
* **Reference Architecture Hub:** [Oracle DevRel Technology Engineering - Oracle Database@Google](https://github.com/oracle-devrel/technology-engineering/tree/9b0405fe266035ba5544f6f8160cfe339342e174/data-platform/multicloud/oracle-database%40google)

---

## 2. Oracle Zero Downtime Migration (ZDM) Tooling
* **Software Downloads:** [Oracle ZDM Software Downloads Hub](https://www.oracle.com/database/technologies/rac/zdm-downloads.html)
* **ZDM Detailed Installation Guide:** [ZDM Installation Walkthrough](https://macsdata.com/oracle/zdm-installation)
* **ZDM Patching Guidelines:** [ZDM Patching Guide](https://macsdata.com/oracle/zdm-patching)
* **ZDM Passwordless Wallet Setup:** [ZDM Wallet Setup Guide](https://macsdata.com/oracle/zdm-wallet-setup)

---

## 3. Terraform & Migration Templates References
* **OCI Database Migration Reference Architecture:** [OCI DB Migration Terraform Template](https://github.com/oracle-devrel/terraform-oci-arch-db-migration/tree/main)
* **ZDM Deployment Webinars:**
  * [Migrate your Oracle Database using ZDM - YouTube Coaching](https://www.youtube.com/watch?v=SXb7KVZjpV8)
  * [ZDM Logical Online Migration to Autonomous Database on Oracle Database@Google Cloud - YouTube Demo](https://youtu.be/5zdOtUEfa1E?si=FeS6xhRf2nxEWSjA)

---

## 4. Key My Oracle Support (MOS) Notes

* **Doc ID 2343806.1:** Zero Downtime Migration (ZDM) Master Note / FAQ. Access this note on [My Oracle Support](https://support.oracle.com/epmos/faces/DocumentDisplay?id=2343806.1) (login credentials required) for the master compatibility matrix, patching notifications, and release highlights.
* **Doc ID 2577344.1:** Oracle Zero Downtime Migration Logical Migration Best Practices. Contains recommended schema exclusions and tuning parameters.
* **Doc ID 2658835.1:** Oracle Zero Downtime Migration Logical and Physical Troubleshooting Note. Lists common error messages during validation (`-eval`) and steps to fix issues with SSH connections or temp space.

