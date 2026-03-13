# Infrastructure Management Tools

The `tools/` folder is intended for helpful tools and scripts that aren't part of the main oracle-toolkit codebase.

## `deploy-infra-manager.sh`

The primary entry point for provisioning fresh Oracle environments using **Google Cloud Infrastructure Manager**. This script handles the packaging of local Ansible roles, staging them in GCS, and triggering the deployment lifecycle.

### Key Features

* **User Isolation:** Automatically appends your username (e.g., `oracle-deploy-marc`) to deployment and resource names to prevent collisions in shared project environments.
* **Predictable Staging:** Packages local roles into a ZIP and stages them at a predictable GCS path: `gs://[BUCKET]/toolkit-[DEPLOYMENT_NAME].zip`.
* **Deep Error Inspection:** Directly extracts resource-level Terraform errors (`tfErrors`) to your terminal, bypassing generic build failure messages.
* **Clean-Slate Semantics:** Enforced "delete-and-recreate" workflow to ensure the VM startup script (Ansible) runs on a fresh instance every time.

### Usage Example

```bash
./tools/deploy-infra-manager.sh \
  --tfvars-file terraform/my_config.tfvars \
  --gcs-bucket gs://my-staging-bucket \
  --service-account infra-manager-sa@my-project.iam.gserviceaccount.com \
  --force

```

### Templating Support

To maximize portability, the deployment script supports **dynamic placeholders** within your `.tfvars` files. When the script runs, it substitutes these tags for live values.

| Placeholder | Substitution Result |
| --- | --- |
| `@gcs_source@` | The full GCS path to the uploaded toolkit ZIP. |
| `@deployment_name@` | The unique ID of the deployment (user-specific). |
| `@instance_name@` | The computed name of the VM instance. |

---

## Troubleshooting (`deploy-infra-manager.sh`)

### Failed Deployments

If the script fails during the `APPLY` phase, look for the **`SPECIFIC TERRAFORM ERRORS DETECTED`** section in your terminal. This shows exactly which resource failed and why (e.g., "Quota exceeded").

### Viewing Runtime Logs

Once the infrastructure reaches the `APPLIED` state, the VM begins its internal setup via Ansible.

1. Click the **Ansible Setup Logs** link printed by the script.
2. Alternatively, navigate to the [Infrastructure Manager Console](https://console.cloud.google.com/infra-manager/deployments) to view deployment details.

---

## `gen_patch_metadata`

`gen_patch_metadata` retrieves patches from My Oracle Support, parses our version and hash information, and prepares `rdbms_patches` and `gi_patches` structures for `roles/common/defaults/main.yml`.

### Sample usage

```bash
$ python3 gen_patch_metadata.py --patch 33567274 --mosuser user@example.com
MOS Password:
INFO:root:Downloading https://updates.oracle.com/Orion/Download/process_form/p33567274_190000_Linux-x86-64.zip?file_id=113789887&aru=24594397&userid=O-mfielding@google.com&email=user@example.com&patch_password=&patch_file=p33567274_190000_Linux-x86-64.zip
INFO:root:Abstract: COMBO OF OJVM RU COMPONENT 19.14.0.0.220118 + GI RU 19.14.0.0.220118
INFO:root:Found release = 19.14.0.0.220118 base = 19.3.0.0.0 GI subdir = 33509923 OJVM subdir = 33561310
INFO:root:Downloading OPatch
INFO:root:Downloading https://updates.oracle.com/Orion/Download/process_form/p6880880_190000_Linux-x86-64.zip?aru=24740828&file_id=112014090&patch_file=p6880880_190000_Linux-x86-64.zip&
Please copy the following files to your GCS bucket: p33567274_190000_Linux-x86-64.zip p6880880_190000_Linux-x86-64.zip
Add the following to the appropriate sections of roles/common/defaults/main.yml:

  gi_patches:
    - { category: "RU", base: "19.3.0.0.0", release: "19.14.0.0.220118", patchnum: "33567274", patchfile: "p33567274_190000_Linux-x86-64.zip", patch_subdir: "/33509923", prereq_check: FALSE, method: "opatchauto apply", ocm: FALSE, upgrade: FALSE, md5sum: "JgJsqbGaGcxEPEP6j79BPQ==" }

  rdbms_patches:
    - { category: "RU_Combo", base: "19.3.0.0.0", release: "19.14.0.0.220118", patchnum: "33567274", patchfile: "p33567274_190000_Linux-x86-64.zip", patch_subdir: "/33561310", prereq_check: TRUE, method: "opatch apply", ocm: FALSE, upgrade: TRUE, md5sum: "JgJsqbGaGcxEPEP6j79BPQ==" }

```

### Known issues

* Only tested against 12.2, 18c, and 19c patches.
* No support for multi-file patches.
