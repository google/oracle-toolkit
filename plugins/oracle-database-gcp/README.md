# Oracle Database@Google Cloud & Migration Suite (Agent Plugin)

Enterprise AI Agent Plugin for Gemini Enterprise Marketplace and Gemini CLI/Antigravity.

This plugin equips Gemini with autonomous agentic skills to architect, deploy, and migrate Oracle Databases on Google Cloud Platform across all supported deployment models.

---

## Included Skills

| Skill | Description | Supported Targets |
| :--- | :--- | :--- |
| **`oracle-exacs-deployment`** | Provisions Exadata Infrastructure (X11M), Exadata VM Clusters, ODB Networks, and subnets. | ExaCS on ODB@GCP |
| **`oracle-exascale-deployment`** | Architect Exadata with Exascale intelligent storage pools, sub-rack shapes, and online autoscaling. | ExaDB-D with Exascale |
| **`oracle-adbs-deployment`** | Provisions Autonomous Database Serverless (ATP/ADW) with ECPU autoscaling and mTLS TCPS 1522. | ADB-S |
| **`oracle-dbcs-deployment`** | Provisions Base Database Service (DBCS) VM instances with ECPU compute models. | DBCS / DB System |
| **`oracle-gce-iaas-deployment`** | Provisions self-managed Oracle on GCE Hyperdisk/GCNV and Bare Metal Solution (BMS RAC). | GCE VM & BMS |
| **`oracle-zdm-migration`** | Orchestrates Physical & Logical Online migrations with sub-5-min cutovers via ZDM & OGG 23ai. | All Targets |
| **`oracle-cloud-lifecycle-ops`** | Manages health assessments (ORAchk), media verification (check-swlib), patching, and cleanup. | Operations & Day-2 |

---

## Included Personas & Agents

* **`oracle-cloud-architect`**: Expert subagent for DBaaS platform selection, capacity planning, and Terraform blueprint generation.
* **`oracle-migration-engineer`**: Expert subagent for Zero Downtime Migration pipelines, wallet management, and live cutovers.

---

## Installation & Marketplace Usage

### Option 1: Automatic Workspace Discovery
This repository contains the plugin under `plugins/oracle-database-gcp/`. Jetski and Gemini CLI automatically discover and load the plugin.

### Option 2: Global Configuration Installation
To make the plugin globally available across all workspaces on your machine:
```bash
mkdir -p ~/.gemini/config/plugins/
cp -R plugins/oracle-database-gcp ~/.gemini/config/plugins/
```
