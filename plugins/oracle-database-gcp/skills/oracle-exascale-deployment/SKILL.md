---
name: oracle-exascale-deployment
description: >-
  Architect, size, and deploy Exadata Database Service with Exascale (ExaDB-D Exascale) on Oracle Database@Google Cloud.
  Use when the user requests Exascale intelligent storage pool virtualization, independent online ECPU and storage auto-scaling,
  sub-rack entry capacity sizing, multitenant storage vaults, or instant thin snapshot cloning on GCP.
---

# Exadata Database Service with Exascale on Google Cloud

This skill guides the design and provisioning of **Exadata Database Service with Exascale (ExaDB-D with Exascale)** on **Oracle Database@Google Cloud**.

---

## 1. Architectural Advantages of Exascale

Exascale replaces fixed physical 3-storage-server allocations with an elastic multitenant intelligent storage pool:
* **Decoupled Elastic Sizing**: Scale ECPUs and storage capacity (in GB/TB increments) independently without downtime.
* **Low-Capacity Starter Footprint**: Deploy production Exadata power starting from smaller database shapes without requiring a full quarter-rack initial investment.
* **Instantaneous Thin Clones**: Native Redirect-on-Write (RoW) database snapshots and clones created in seconds for Dev/Test and analytics with zero initial storage duplication.
* **Smart Storage Virtualization**: Storage is dynamically sliced from high-performance RDMA-enabled Exadata storage vaults with automated NVMe tiering and Smart Scans.

---

## 2. Configuration & Sizing Guidelines

* **Compute Sizing**:
  * Shape: `Exadata.X11M` Exascale.
  * Granular ECPU allocation starting from low core counts (e.g. 8 ECPUs per VM) up to full scale.
* **Storage Allocation**:
  * Virtual Storage Vault allocation specified in `data_storage_size_tb` (e.g. 1.0 TB to 100+ TB).
  * Storage grows online on demand.
* **Network Peering**:
  * Requires peered `google_oracle_database_odb_network` with delegated `CLIENT_SUBNET` (port 1521) and `BACKUP_SUBNET` (port 1521/1522).

---

## 3. Terraform Deployment Blueprint

Execute deployment via `terraform/environments/oracle_db_gcp_exacs` configured with Exascale parameters:

```hcl
module "exascale_vmcluster" {
  source                          = "../../modules/gcp_exadata_vmcluster"
  location                        = var.region
  exa_infra_project               = var.project_id
  cloud_exadata_infrastructure_id = module.exadata_infrastructure.cloud_exadata_infrastructure_id
  cloud_vm_cluster_id             = "exascale-vmcluster-primary"
  exa_vm_project                  = var.project_id
  vpc_project                     = var.project_id
  odb_network_id                  = module.odb_network.odb_network_id
  odb_client_subnet_id            = module.odb_client_subnet.odb_subnet_id
  odb_backup_subnet_id            = module.odb_backup_subnet.odb_subnet_id
  license_type                    = "BRING_YOUR_OWN_LICENSE"
  ssh_public_keys                 = var.ssh_public_keys
  cpu_core_count                  = 16                  # Granular Exascale core sizing
  memory_size_gb                  = 60
  db_node_storage_size_gb         = 120
  data_storage_size_tb            = 1.5                 # Elastic Exascale storage vault capacity
  gi_version                      = "23.0.0.0"          # Oracle 23ai GI
  hostname_prefix                 = "exascale"
}
```

---

## 4. Operational Best Practices
1. **Redirect-on-Write Clones**: Leverage PDB snapshot copies (`CREATE PLUGGABLE DATABASE clone FROM source SNAPSHOT COPY`) for instantaneous space-efficient testing.
2. **Network MTU Tuning**: Enforce Jumbo Frames (MTU 9000) on GCP VPC interconnects and ensure SQL*Net SDU is set to 65535 (`SDU=65535`) in `tnsnames.ora`.
