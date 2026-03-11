# Terraform Infrastructure Provisioning for Oracle Toolkit for GCP Deployments

You can automate the deployment of Google Cloud infrastructure by using [Terraform](https://www.terraform.io/), an open-source Infrastructure as Code (IaC) tool from Hashicorp, in combination with [Ansible](https://docs.ansible.com/) for configuration management. This approach allows for a consistent, repeatable, and scalable deployment processes.

This guide provides a comprehensive overview of deploying and configuring infrastructure on Google Cloud using pre-defined Terraform modules integrated with the Oracle Toolkit for GCP Ansible playbooks.

---

## Supported Use Cases

This setup supports the deployment of the following configurations:

- Google Compute Engine (GCE) Virtual Machines (VMs)
- Custom OS Images (RHEL, Oracle Linux, Rocky Linux, AlmaLinux)
- Persistent Disks for ASM, Swap, Data, and Log storage
- Network configuration using specified subnets and NAT IPs
- Custom startup scripts for VM initialization (Google Cloud metadata [startup scripts](https://cloud.google.com/compute/docs/instances/startup-scripts/linux))
- Ansible automation for post-provisioning configuration tasks

This approach is particularly suitable for deploying and configuring:

- Oracle databases on RHEL or Oracle Linux
- Two-node Oracle Data Guard deployments, where:

  The user provides:

  - zone1 and subnetwork1 for the primary node
  - zone2 and subnetwork2 for the standby node

  Only 2-node Data Guard setups are currently supported.

---

## What the Terraform Configuration Deploys

The Terraform module deploys the following elements:

- **Compute Engine VMs** with the specified image and machine type
- **OS Images**: RHEL 7/8, Oracle Linux 7/8, Rocky Linux 8, AlmaLinux 8
- **Persistent Disks**:
  - ASM disks (`asm-1`, `asm-2`)
  - Swap disk
  - Optional data disks (`disk-1`, `disk-2`) for application or database storage
- **IAM Service Account** for managing VM access
- **SSH Key Management** using Ansible SSH keys for secure access
- **Custom Metadata Scripts** for VM initialization
- **Ansible Playbooks** to automate post-deployment configurations
- **Firewall Rules** to allow Ansible SSH execution and Data Guard communication
  (if `create_firewall` is set to `true`)
- **Artifact Registry Remote Mirror** to allow OS package updates without
  Internet access (if `enable_ar_repo` is set to `true`)

This infrastructure is modular and customizable, allowing you to tailor it to specific application needs or organizational requirements.

---

## Instance naming convention

For single-instance deployments, the VM will be named using the pattern:
"<instance_name>-1".
Example: If instance_name = "oracle-db", the resulting VM will be oracle-db-1.

For multi-node Oracle Data Guard deployments:

- Primary node: "<instance_name>-1"
- Standby node: "<instance_name>-2"

Example: If instance_name = "oracle-db", the primary VM will be oracle-db-1 and the standby VM will be oracle-db-2.

---

## Pre-requisites

To use this Terraform and Ansible integration, ensure you have the following tools installed:

- **Google Cloud SDK** - [Installation Guide](https://cloud.google.com/sdk/docs/install)
- **Terraform** - [Installation Guide](https://learn.hashicorp.com/tutorials/terraform/install-cli)

### 1. Service Account for the Control Node VM

Grant the service account attached to the control node VM the following IAM roles:

- `roles/compute.osAdminLogin`
  Grants OS Login access with sudo privileges, required by the Ansible playbooks.
- `roles/iam.serviceAccountUser` on the **target VM's service account**
  Allows the control node to impersonate the target service account during SSH sessions.
- `roles/storage.objectViewer` on the bucket specified in var.gcs_source to download the ZIP archive of the oracle-toolkit
- `roles/storage.objectUser` on the Terraform state bucket specified in backend.tf to write Terraform state.
- `roles/compute.instanceAdmin.v1` (or a custom role including compute.instances.delete)
  Required to delete the ephemeral control node VM after the deployment is complete.
- `roles/compute.securityAdmin` (or a custom role including
  `compute.firewalls.*`)
  Allows creation of firewall rules for Ansible SSH access and Oracle Data
  Guard HA, as well as cleanup of firewall rules when the control node is deleted.  (Only if `create_firewall` is set to `true`)
- `roles/logging.logWriter`
  Required to write to Google Cloud Logging.
- `roles/artifactregistry.admin`
  Allows creation of an Artifact Registry remote repository, if `enable_ar_repo`
  is set to `true`.

### 2. Service Account for the database VM

- `roles/secretmanager.secretAccessor` - Grants access to retrieve passwords from Secret Manager. Must be granted in the project containing the secrets either at the project or individual secret level.
- `roles/monitoring.metricWriter` - Required only if the --install-workload-agent and --oracle-metrics-secret flags are set. This allows the Google Cloud Agent for Compute Workloads to write metrics to Cloud Monitoring.
- `roles/compute.viewer` - Required only if the --install-workload-agent and --oracle-metrics-secret flags are set. Needed by the Google Cloud Agent for Compute Workloads.
- `roles/artifactregistry.reader` - Grants access to the AR remote repository,
  if `enable_ar_repo` is set to `true`.

### 3. Terraform State Bucket

Create a Cloud Storage bucket to store Terraform state files.
Authorize the control node service account with read and write access to this bucket.

### 4. Toolkit Source Bucket

Create a Cloud Storage bucket to store the oracle-toolkit ZIP file.

Clone the toolkit repository and prepare the ZIP archive:

```bash
git clone https://github.com/google/oracle-toolkit.git
cd oracle-toolkit
zip -r /tmp/oracle-toolkit.zip . -x "terraform/*" -x ".git/*"
```

Upload the ZIP file to your GCS bucket:

```bash
gcloud storage cp /tmp/oracle-toolkit.zip gs://your-bucket-name/
```

---

## Project Directory Structure

The project directory structure is as follows:

```plaintext
repo-root/
├── install-oracle.sh               # Main deployment script for Ansible
├── check-instance.yml
├── prep-host.yml
├── install-sw.yml
├── config-db.yml
├── config-rac-db.yml
└── terraform/
    ├── backend.tf                  # Backend configuration, from example
    ├── terraform.tfvars            # Variables to set, from example
    ├── main.tf                     # Main Terraform code
    ├── variables.tf                # Variable definition
    └── versions.tf                 # Version dependencies
```

---

## Setup and Deployment Steps

1. Google Cloud Authentication
   Authenticate using the Google Cloud SDK:

```bash
gcloud auth login
gcloud auth application-default login
```

Set your project ID:

```bash
gcloud config set project PROJECT_ID
```

2. Review and Edit Terraform Backend Configuration

   Copy `terraform/backend.tf.example` to `terraform/backend.tf` and define your backend settings for your state file prefix and storage bucket.

3. Review and Edit Terraform Module Configuration

   Copy `terraform/terraform.tfvars.example` to `terraform/terraform.tfvars` and define your deployment settings.

> **NOTE** There is no need to supply the toolkit script parameters `--instance-ip-addr`, `--instance-ssh-user`, and `--instance-ssh-key` - these are automatically added by the Terraform commands.

4. Initialize and Apply Terraform

   Navigate to the terraform directory and initialize Terraform:

```bash
cd terraform
terraform init
```

Review the execution plan:

```bash
terraform plan
```

Deploy the infrastructure:

```bash
terraform apply
```

This process will perform the following steps:

- Provision an ephemeral control node to run deployment and configuration tasks.
- Provision a database VM with the specified configuration to host the Oracle database.
- The control node uses Ansible to connect to the database VM and automate the installation and configuration of the Oracle database.
- After configuration, the ephemeral control node is deleted to minimize resource usage.

5. View startup execution logs
   To view logs from startup script execution on the control node VM, fetch the
   Terraform output variable `control_node_log_url` and paste into a browser
   to open Logs Explorer, filtered to control node output only.

```bash
terraform output control_node_log_url
```

6. Verify Ansible Execution

   Once deployment is complete, review the Ansible output to verify that the playbooks ran successfully:

```plaintext
PLAY [dbasm] *******************************************************************

TASK [Verify that Ansible on control node meets the version requirements] ******
ok: [VM_PUBLIC_IP] => {
    "changed": false,
    "msg": "Ansible version is 2.9.27, continuing"
}

TASK [Test connectivity to target instance via ping] ***************************
ok: [VM_PUBLIC_IP]
```

6. Clean Up Resources

   To destroy all the resources created by Terraform:

```bash
terraform destroy
```

## Ansible Cloud Logging callback plugin

This callback plugin sends Ansible playbook logs to Google Cloud Logging in structured JSON format.

### Setup

To enable the plugin, add the following to your ansible.cfg:

```bash
[defaults]
callback_plugins = ./tools/callback_plugins
```

### Configuration (ansible.cfg)

Under the [cloud_logging] section, you can configure:

```bash
[cloud_logging]
project = your-project                   # Required: GCP project ID
log_name = ansible_cloud_logging         # Optional: defaults to 'ansible_cloud_logging'
ignore_gcp_api_errors = false            # Optional: if true (default), GCP API errors are ignored and do not cause Ansible to fail
print_uuid = true                        # Optional: print UUID for each playbook execution
enable_async_logging = true              # Optional:  If true (default), log messages are queued and sent by a background thread to avoid blocking Ansible execution
```

When enable_async_logging is enabled, logs are queued and sent by a background thread to avoid blocking Ansible execution. Otherwise, logs are sent synchronously.

## Troubleshooting

### Common Issues

1. No Such File or Directory

- Make sure `working_dir = "${path.root}"` is set in the provisioner block.
