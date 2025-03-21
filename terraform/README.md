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
- High-availability configurations for database and application clusters

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

This infrastructure is modular and customizable, allowing you to tailor it to specific application needs or organizational requirements.

---

## Pre-requisites

To use this Terraform and Ansible integration, ensure you have the following tools installed:

- **Google Cloud SDK** - [Installation Guide](https://cloud.google.com/sdk/docs/install)
- **Terraform** - [Installation Guide](https://learn.hashicorp.com/tutorials/terraform/install-cli)
- **Ansible** - [Installation Guide](https://docs.ansible.com/ansible/latest/installation_guide/index.html)
- **jq** - JSON processor required for handling playbook variables - [Installation Guide](https://stedolan.github.io/jq/download/)
- **JMESPath** - [Installation Guide](https://pypi.org/project/jmespath/)

Additionally, you will need:

- A **Google Cloud project** with billing enabled
- A **Service Account** with appropriate IAM roles for Compute Engine and Storage management
- The following **IAM roles** added to the **Service Account** running **Terraform**:`roles/compute.instanceAdmin`, `roles/storage.objectAdmin`
- A writeable [cloud storage bucket](https://cloud.google.com/storage/docs/creating-buckets) to store terraform state in

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
    ├── main.tf                     # Main Terraform configuration
    └── modules/
        └── oracle_toolkit_module/
            ├── main.tf             # Ansible integration module
            └── variables.tf        # Module variables
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

   Copy `terraform/main.tf.example` to `terraform/main.tf` and define your deployment settings. Add as many ASM disks you require in the `asm_disks` and `fs_disks` sections.

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

This will:

- Create a VM on Google Cloud with the specified configuration
- Apply the SSH public key to the VM
- Use Ansible playbooks to configure the instance

5. Verify Ansible Execution

   Once deployment is complete, verify the output to check if Ansible playbooks ran successfully:

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

## Troubleshooting

### Common Issues
1. No Such File or Directory

- Make sure `working_dir = "${path.root}"` is set in the provisioner block.

2. JSON Parsing Errors

- Ensure jq is installed and working:

```bash
jq --version
```
