---
description: Mandatory best practices and architectural constraints for Oracle on Google Cloud.
---

# Oracle Database on Google Cloud: Architectural Rules & Best Practices

When designing, provisioning, or migrating Oracle databases on Google Cloud Platform, you MUST adhere to the following architectural standards:

## 1. Networking & SDU Sizing
* **SQL*Net SDU Tuning**: For high-throughput migrations and data transfer between GCP VPC and ODB@GCP, always configure `DEFAULT_SDU_SIZE=65535` and `SDU=65535` in `sqlnet.ora` and `tnsnames.ora`.
* **Private Google Access**: Always enable Private Google Access on GCP VPC subnets so ZDM and GCE database instances reach GCS storage endpoints over Google internal backbone without traversing the public internet.
* **Autonomous Database Port**: ADB-S private endpoints always communicate over **TCPS port 1522** with mutual TLS (mTLS) client wallets (`cwallet.sso`). Do not use standard TCP port 1521 for secure ADB-S connections.

## 2. Passwordless Auto-Login Wallets
* **Zero Plaintext Passwords**: Never store database administrative passwords in plain text in response files (`zdm_logical.rsp`, `zdm_physical.rsp`).
* **Wallet Automation**: Always utilize `orapki` and `mkstore` to generate auto-login PKCS12 wallets for `src_admin`, `src_ggadmin`, `tgt_admin`, `tgt_ggadmin`, and `ogg_oggadmin`.

## 3. Storage Performance on GCE
* **Linux Kernel HugePages**: Calculate HugePages based on SGA target (`HugePages = (SGA_SIZE / 2MB) + spare`) and ensure `vm.nr_hugepages` is set in `/etc/sysctl.conf`.
* **Separate Filesystem Mounts**: Enforce separation between Oracle software binaries (`/u01`), Database datafiles (`/u02` or `+DATA`), and Fast Recovery Area / Archive Logs (`/u03` or `+RECO`).
