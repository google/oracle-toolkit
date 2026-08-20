# Archive Context: GitHub PR 215 (oracle-toolkit)

This branch (`archive/pr-215`) preserves the code from Pull Request #215, which was not merged into the main branch.

- **PR Link:** https://github.com/google/oracle-toolkit/pull/215
- **Title:** Adding backup to gcs using gcsfuse with an auto option.
- **Author:** gmarcospythian
- **Date of Archive:** 2026-08-20

## Context

This branch introduces an `auto` configuration option for `GCS_BACKUP_CONFIG`. When enabled, it automatically sets up backups to a Google Cloud Storage (GCS) bucket by mounting it on the database host using `gcsfuse`.

The implementation includes:
- Automatic installation of `gcsfuse` on RedHat/CentOS families.
- Dynamic creation of a Google Service Account (GSA) named `gcsfuse-<instance_id>`.
- Creation of a GCS bucket named `fusebackup-<instance_id>`.
- Assigning `roles/storage.legacyBucketOwner` to the GSA for the created bucket.
- Generating and downloading a JSON key for the GSA to the host.
- Mounting the GCS bucket via `gcsfuse` using the downloaded key.
- Corresponding cleanup tasks to unmount, delete the bucket, delete the GSA, and clean up local keys and directories.

---

## Value Analysis (Keep vs. Regenerate)

With the advent of advanced AI coding assistants, we evaluated whether this code is worth keeping as a reference or if it could be regenerated from scratch if needed.

### Key Elements Worth Keeping (Reference Value)

While much of the code is boilerplate Ansible/Bash, there are specific details that are highly valuable to preserve:

1.  **GCSFuse Mount Options:**
    The specific mount flags used to configure the GCS bucket for Oracle (e.g., `noexec`, `nodev`, `allow_other`, and proper ownership mapping) are non-trivial and critical for performance and security.
    See changes in `roles/db-backups/tasks/gcsauto.yml` (the `mount` task).

2.  **Propagation Pauses:**
    The playbook includes `pause` tasks (e.g., 15 seconds) to handle GCP's eventual consistency when creating Service Accounts and buckets. A generic code generator would likely omit these, leading to flaky execution.

3.  **Teardown Sequence:**
    The cleanup logic in `roles/db-backups/tasks/gcsautorm.yml` correctly orchestrates the removal of mounted directories, buckets, service accounts, and local keys in the correct order to prevent resource leaks.

### Areas for Improvement (If Re-implementing/Regenerating)

If we were to implement this feature today, we should improve upon this design rather than copying it directly:

1.  **Avoid Downloading Service Account Keys:**
    Downloading JSON keys to the VM is a security risk. A better approach would be to use the VM's attached Service Account and rely on Application Default Credentials (ADC) or VM metadata identity to access the bucket, avoiding the security risk of local key files.

2.  **Declarative Resource Provisioning:**
    The PR uses Ansible `shell` tasks to run `gcloud` commands for creating GCP resources (SAs, buckets). This is imperative and hard to manage. A better approach is to provision these resources declaratively using Terraform before running Ansible.

3.  **Ansible GCP Modules:**
    Instead of raw `gcloud` shell commands, native Ansible modules (from `google.cloud` collection) should be used if Terraform is not an option.

### Summary

**Conclusion:** Keep this branch as a reference for the **specific `gcsfuse` mount configuration** and the **eventual-consistency workarounds (pauses)**, but do **not** reuse the resource provisioning logic (raw `gcloud` in Ansible) or the Service Account key downloading pattern in future implementations.
