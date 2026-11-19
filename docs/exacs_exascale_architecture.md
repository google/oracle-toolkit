# Oracle Database@Google Cloud: Exadata Cloud Service (ExaCS) & Exascale Architecture

## 1. Overview
**Oracle Database@Google Cloud (ODB@GCP)** brings Oracle Exadata Database Service directly into Google Cloud data centers, co-located with native GCP services over an ultra-low-latency private interconnect.

This toolkit provides native Terraform modules for deploying:
1. **Exadata Database Service on Dedicated Infrastructure (ExaCS)**
2. **Exadata Database Service with Exascale (ExaDB-D Exascale)**

---

## 2. Architectural Comparison: ExaCS vs. Exascale

| Architectural Feature | Traditional ExaCS (Dedicated Infrastructure) | Exadata Database Service with Exascale |
| :--- | :--- | :--- |
| **Storage Architecture** | Dedicated physical High-Capacity / Extreme Flash Storage Servers (min 3 servers). | Virtual Intelligent Storage Pools shared across multitenant clusters. |
| **Scaling Granularity** | Step increments of 1 compute server / 1 storage server. | Fully decoupled, granular online scaling of ECPUs and storage capacity (GB/TB). |
| **Entry Footprint** | Fixed quarter-rack minimum hardware requirement. | Low-capacity starter shapes with sub-rack entry costs. |
| **Thin Provisioning & Clones** | ASM-level full allocations. | Native Redirect-on-Write (RoW) instantaneous database clones and thin provisioning. |
| **Shapes** | `Exadata.X11M` | `Exadata.X11M` with Exascale storage architecture. |

---

## 3. Network Topology & Peering

Oracle Database@Google Cloud uses an **ODB Network** (`google_oracle_database_odb_network`) peered directly with your GCP Virtual Private Cloud (VPC):
* **Client Delegated Subnet (`CLIENT_SUBNET`)**: Handles application traffic, Oracle SCAN listeners, and database client connections on TCP port 1521/1522.
* **Backup Delegated Subnet (`BACKUP_SUBNET`)**: Dedicated, isolated high-throughput network path for Oracle RMAN backups, Data Guard standby redo transport, and GCS staging transfers.

```
+-------------------------------------------------------------------------+
| Google Cloud VPC Network (e.g. 10.140.0.0/20)                            |
|  +---------------------------+       +-------------------------------+  |
|  | Application Workload VMs  | <---> | GCS Backup Staging Bucket     |  |
|  +---------------------------+       +-------------------------------+  |
+-------------------------------------------------------------------------+
                                   | (VPC Network Peering)
                                   v
+-------------------------------------------------------------------------+
| Oracle Database@Google Cloud (ODB Network)                              |
|  +-------------------------------------------------------------------+  |
|  | Client Subnet (10.150.20.0/24) -> SCAN Listeners (Port 1521)     |  |
|  +-------------------------------------------------------------------+  |
|  | Backup Subnet (10.150.21.0/24) -> Redo Transport & RMAN Backups  |  |
|  +-------------------------------------------------------------------+  |
|  | Exadata VM Cluster (Compute Nodes + Intelligent Storage Servers)  |  |
|  +-------------------------------------------------------------------+  |
+-------------------------------------------------------------------------+
```

---

## 4. Terraform Deployment

To deploy an Exadata Infrastructure & VM Cluster:
```bash
cd terraform/environments/oracle_db_gcp_exacs
cp terraform.tfvars.example terraform.tfvars
# Adjust variables (project_id, ssh_public_keys, cpu_core_count, data_storage_size_tb)
terraform init
terraform apply
```
