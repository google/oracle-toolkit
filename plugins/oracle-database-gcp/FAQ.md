# Oracle Database@Google Cloud AI Agent Plugin: Setup & Marketplace FAQ

This guide provides a comprehensive setup manual and FAQ for using the **Oracle Database@Google Cloud & Migration Suite** (`oracle-database-gcp`) plugin within the **AGY / Gemini CLI** and deploying it across organizations via the **Gemini Enterprise Marketplace**.

---

## Table of Contents
1. [Overview & Architecture](#1-overview--architecture)
2. [Using the Plugin in AGY / Gemini CLI](#2-using-the-plugin-in-agy--gemini-cli)
   - [Discovery & Loading Priority](#discovery--loading-priority)
   - [Workspace vs. Global Installation](#workspace-vs-global-installation)
   - [Autonomous Skill Activation](#autonomous-skill-activation)
   - [Invoking Specialized Subagents & Personas](#invoking-specialized-subagents--personas)
3. [Gemini Enterprise Marketplace Setup](#3-gemini-enterprise-marketplace-setup)
   - [Package Anatomy](#package-anatomy)
   - [Publishing to Enterprise Marketplace](#publishing-to-enterprise-marketplace)
   - [Organization-Wide Policy & IAM Governance](#organization-wide-policy--iam-governance)
   - [Security & SAIF Compliance](#security--saif-compliance)
4. [Frequently Asked Questions (FAQ)](#4-frequently-asked-questions-faq)
   - [Q1: How do agents decide between Physical and Logical ZDM migration?](#q1-how-do-agents-decide-between-physical-and-logical-zdm-migration)
   - [Q2: How are sensitive database passwords and wallets handled?](#q2-how-are-sensitive-database-passwords-and-wallets-handled)
   - [Q3: Can the agent run pre-flight evaluations without modifying infrastructure?](#q3-can-the-agent-run-pre-flight-evaluations-without-modifying-infrastructure)
   - [Q4: How do I customize or extend an existing skill?](#q4-how-do-i-customize-or-extend-an-existing-skill)
   - [Q5: How do I troubleshoot agent execution or tool permission errors?](#q5-how-do-i-troubleshoot-agent-execution-or-tool-permission-errors)

---

## 1. Overview & Architecture

The `oracle-database-gcp` plugin packages **7 autonomous AI skills**, **2 expert personas**, and **architectural rules** to automate the end-to-end lifecycle of Oracle databases on Google Cloud:

```
+-----------------------------------------------------------------------------------+
|                        Gemini Enterprise Marketplace / AGY CLI                   |
+-----------------------------------------------------------------------------------+
                                         |
                       +-----------------+-----------------+
                       |                                   |
                       v                                   v
        +-----------------------------+     +-----------------------------+
        |   oracle-cloud-architect    |     |  oracle-migration-engineer  |
        |   (Architecture Persona)    |     |     (Migration Persona)     |
        +-----------------------------+     +-----------------------------+
                       |                                   |
        +--------------+-----------------------------------+--------------+
        |                                                                 |
        v                                                                 v
+-------------------------------+                               +-------------------------------+
|       Deployment Skills       |                               |      Operational Skills       |
| • oracle-exacs-deployment     |                               | • oracle-zdm-migration        |
| • oracle-exascale-deployment  |                               | • oracle-cloud-lifecycle-ops  |
| • oracle-adbs-deployment      |                               +-------------------------------+
| • oracle-dbcs-deployment      |                                               |
| • oracle-gce-iaas-deployment  |                                               v
+-------------------------------+                               +-------------------------------+
                |                                               |     Enforced Best Practices   |
                v                                               | • SDU = 65535                 |
+-------------------------------------------------------------+ | • TCPS Port 1522 (mTLS)       |
|            Google Cloud Platform / ODB@GCP Targets          | | • Auto-login PKCS12 Wallets   |
|  ExaCS X11M | Exascale | ADB-S | DBCS | GCE IaaS | BMS RAC  | | • HugePages & ASM Isolation   |
+-------------------------------------------------------------+ +-------------------------------+
```

---

## 2. Using the Plugin in AGY / Gemini CLI

### Discovery & Loading Priority
AGY and Gemini CLI employ **progressive disclosure**. Skills and agents are discovered in the following order of precedence:
1. **Workspace Project**: `./plugins/oracle-database-gcp/` or `.gemini/plugins/oracle-database-gcp/` within your current repository root.
2. **User Global Config**: `~/.gemini/config/plugins/oracle-database-gcp/` (accessible from any terminal directory).
3. **Built-in System Plugins**.

### Workspace vs. Global Installation

#### Option A: Workspace Integration (Recommended for CI/CD & Project Repos)
The plugin is already embedded inside `plugins/oracle-database-gcp/`. Whenever you open the workspace in AGY or Gemini CLI, all skills and rules load automatically.

#### Option B: Global Machine-Local Installation
To use these skills across any project directory on your workstation:
```bash
# 1. Create global plugins directory
mkdir -p ~/.gemini/config/plugins/

# 2. Copy the plugin to the global configuration
cp -R plugins/oracle-database-gcp ~/.gemini/config/plugins/

# 3. Verify installation
ls -la ~/.gemini/config/plugins/oracle-database-gcp
```

### Autonomous Skill Activation

You do **not** need to manually call skills by filename. Simply state your intent in natural language, and AGY will select and activate the appropriate skill:

| Prompt Example | Triggered Skill | What the Agent Does |
| :--- | :--- | :--- |
| *"Deploy a 2-node Exadata X11M VM cluster with a peered ODB network in europe-west3."* | `oracle-exacs-deployment` | Configures `google_oracle_database_cloud_exadata_infrastructure`, subnets, and runs Terraform apply. |
| *"Architect an elastic Exadata Exascale deployment with 16 ECPUs and thin cloning enabled."* | `oracle-exascale-deployment` | Sizes decoupled ECPU and virtual storage vaults with Redirect-on-Write (RoW) configuration. |
| *"Provision an Autonomous Database Serverless instance for OLTP with auto-scaling."* | `oracle-adbs-deployment` | Deploys ADB-S with TCPS 1522, private mTLS endpoint, and downloads `cwallet.sso`. |
| *"Perform an online zero-downtime migration of my 19c database to ExaCS using Data Guard."* | `oracle-zdm-migration` | Generates response file, creates auto-login wallets, validates TCP 1521, and executes `zdmcli`. |
| *"Run an ORAchk health check and validate the GCS software media bucket."* | `oracle-cloud-lifecycle-ops` | Executes `check-swlib.sh` and runs Autonomous Health Framework diagnostics. |

### Invoking Specialized Subagents & Personas

For complex multi-step workflows, invoke specialized subagents directly using the `invoke_subagent` tool or via the CLI:

#### In Chat / AGY CLI:
```text
@oracle-cloud-architect Review our current VPC topology and generate a production ExaCS Terraform blueprint.
```
```text
@oracle-migration-engineer Execute a pre-flight dry run evaluation (-eval) for logical migration to ADB-S.
```

#### Via `agentapi` CLI:
```bash
# Start an autonomous conversation with the Migration Engineer persona
agentapi new-conversation --profile="oracle-migration-engineer" \
  --title="ZDM 19c Migration to ADB-S" \
  "Perform pre-flight connectivity checks against source 10.10.1.5 and target endpoint adbs-private.odb.gcp.internal"
```

---

## 3. Gemini Enterprise Marketplace Setup

The Gemini Enterprise Marketplace allows cloud administrators to package, curate, and distribute verified AI plugins across enterprise engineering organizations.

### Package Anatomy
To publish to the Enterprise Marketplace, ensure the following directory layout:
```text
oracle-database-gcp/
├── plugin.json                 # Standard runtime descriptor
├── marketplace.json            # Marketplace catalog metadata & taxonomy
├── README.md                   # Enterprise user guide and feature summary
├── rules/                      # Mandatory guardrails & compliance checks
│   └── oracle-gcp-best-practices.md
├── agents/                     # Specialized subagent personas
│   ├── oracle-cloud-architect.json
│   └── oracle-migration-engineer.json
└── skills/                     # Modular execution skills
    ├── oracle-exacs-deployment/SKILL.md
    ├── oracle-exascale-deployment/SKILL.md
    ├── oracle-adbs-deployment/SKILL.md
    ├── oracle-dbcs-deployment/SKILL.md
    ├── oracle-gce-iaas-deployment/SKILL.md
    ├── oracle-zdm-migration/SKILL.md
    └── oracle-cloud-lifecycle-ops/SKILL.md
```

### Publishing to Enterprise Marketplace

1. **Package the Plugin Archive**:
   ```bash
   cd plugins
   zip -r oracle-database-gcp-v1.0.0.zip oracle-database-gcp/ -x "*.DS_Store"
   ```
2. **Register with Enterprise Marketplace Catalog**:
   Publish the plugin artifact to your organization's internal Gemini Marketplace repository or Artifact Registry catalog:
   ```bash
   gcloud artifacts generic upload \
     --project="my-enterprise-admin-project" \
     --location="global" \
     --repository="gemini-marketplace" \
     --package="oracle-database-gcp" \
     --version="1.0.0" \
     --source="oracle-database-gcp-v1.0.0.zip"
   ```

### Organization-Wide Policy & IAM Governance
Administrators can control which teams have access to specific agent capabilities:
* **Database Platform Engineers**: Full access to all 7 skills (`oracle-exacs-deployment`, `oracle-zdm-migration`, etc.).
* **Application Developers**: Restricted to `oracle-adbs-deployment` (read/connect) and `oracle-cloud-lifecycle-ops` (health check only).
* **Enforced Organization Policies**:
  * Constraint: `constraints/gcp.restrictNonCidrSubnets` (enforces approved IP ranges for ODB subnets).
  * Constraint: `constraints/compute.restrictSharedVpcHostProjects` (enforces centralized network peering).

### Security & SAIF Compliance
This plugin adheres to Google's **Secure AI Framework (SAIF)**:
* **Zero Plaintext Secrets**: Passwords are never stored in prompt histories or HCL code; wallets are encrypted via PKCS12 (`cwallet.sso`).
* **Least Privilege**: ZDM execution runs under the unprivileged `zdmuser` service account.
* **Network Isolation**: All database control traffic routes through Private Google Access and peered ODB Networks without public IP exposure.

---

## 4. Frequently Asked Questions (FAQ)

### Q1: How do agents decide between Physical and Logical ZDM migration?
**Answer:** The `oracle-zdm-migration` skill applies the following decision rules:
* **Physical Online** is selected when source and target are both Linux x86-64 on the same Oracle version (e.g. 19c to 19c) migrating to ExaCS, DBCS, or GCE. It utilizes RMAN + Data Guard for sub-5-minute cutover.
* **Logical Online** is selected when upgrading Oracle versions (11g/12c to 19c/23ai), migrating cross-platform (Solaris/AIX to Linux), or migrating to **Autonomous Database Serverless (ADB-S)**. It uses parallel Data Pump + GoldenGate 23ai CDC for zero downtime.

---

### Q2: How are sensitive database passwords and wallets handled?
**Answer:**
1. Passwords for `SYS`, `SYSTEM`, `ADMIN`, and `GGADMIN` are dynamically injected via `orapki` and `mkstore` into encrypted auto-login wallets (`cwallet.sso`).
2. Response files (`zdm_logical.rsp`) reference wallet aliases (e.g. `-srcauth zdmauth -srcargs "walletdir=/u01/zdm/zdmbase/wallets"`) rather than cleartext strings.
3. Wallet directories are restricted to `chmod 700` owned by `zdmuser:oinstall`.

---

### Q3: Can the agent run pre-flight evaluations without modifying infrastructure?
**Answer:** Yes. You can request a dry run:
```bash
# Run all static pre-checks and API validations
./tests/run_all_prechecks.sh

# Run ZDM dry-run evaluation mode
zdmcli migrate database -rsp /u01/zdm/zdmbase/zdm_logical.rsp -sourcenode src-host -tgtdbconnection tgt-host:1521/tgtsvc -eval
```
The `-eval` flag checks SSH connectivity, port reachability (1521/1522), ASM storage headroom, and Data Pump directory privileges without initiating data transfer.

---

### Q4: How do I customize or extend an existing skill?
**Answer:**
1. Navigate to `plugins/oracle-database-gcp/skills/<skill-name>/SKILL.md`.
2. Edit the markdown instructions or append project-specific parameters (e.g. custom corporate naming conventions or KMS encryption keys).
3. Changes in your workspace take effect immediately in your next AGY session without requiring a restart.

---

### Q5: How do I troubleshoot agent execution or tool permission errors?
**Answer:**
1. Run pre-validation to check active GCP credentials:
   ```bash
   ./scripts/migration/pre_validate.sh
   ```
2. If `gcloud` or `terraform` fails with permission errors:
   * Ensure `roles/oracledatabase.admin` and `roles/compute.networkAdmin` are granted to your user/service account.
   * Run `gcloud auth application-default login` to refresh Application Default Credentials (ADC).
3. If ZDM daemon is unreachable:
   * Verify status with `zdmservice status`.
   * Start the daemon with `zdmservice start`.
