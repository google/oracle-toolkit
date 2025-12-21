# Patch Automation User Guide

## How to Add a New Patch

The entire process is driven by a single input file: `modify_patchlist.yml`.

### Step 1: Edit the Input File

Open the `modify_patchlist.yml` file located in the root of the repository. This file contains several sections for different types of software and patches.

### Step 2: Find the Correct Section

Locate the section corresponding to the type of software or patch you are adding. The available sections are:

* `gi_software`: Oracle Grid Infrastructure base installation media.
* `rdbms_software`: Oracle RDBMS base installation media (e.g., FREE edition RPMs).
* `opatch_patches`: OPatch utility versions.
* `gi_interim_patches`: One-off interim patches for Grid Infrastructure.
* `gi_patches`: Cumulative patches (Release Updates) for Grid Infrastructure.
* `rdbms_patches`: Cumulative patches (Release Updates) for RDBMS.

### Step 3: Add the New Entry

Add your new software or patch information as a new list item under the appropriate section. Ensure your entry follows the existing YAML format for that section.

#### Example: Adding a new RDBMS Release Update

To add a new RDBMS patch, you would add a new entry under the `rdbms_patches` section in `modify_patchlist.yml`:

```yaml
rdbms_patches:
  - { category: "RU", base: "21.3.0.0.0", release: "21.19.0.0.0", patchnum: "38123456", patchfile: "p38123456_210000_Linux-x86-64.zip", patch_subdir: "/", prereq_check: false, method: "opatch apply", ocm: false, upgrade: false, md5sum: "newMd5SumGoesHere==" }
```

### Step 4: (Optional) Override Documentation Text

The automation will also update the user documentation. It generates default descriptions based on the patch data. If you need to override this default text, you can specify custom values in the `documentation_overrides` section of `modify_patchlist.yml`.

**Example:**

```yaml
documentation_overrides:
  skip_docs_update: false  # Set to true to skip doc updates entirely

  rdbms_patches:
    category: "Patch - My Oracle Support"
    software_piece: "Custom DB RU 21.19"
    file_name: "p38123456_210000_Linux-x86-64.zip"
```

If you leave these fields blank, the automation will use default values based on the patch being applied.

### Step 5: Commit and Push

Commit your changes to the `modify_patchlist.yml` file, create a branch, and open a pull request.

```bash
git add modify_patchlist.yml
git commit -m "feat: Add RDBMS RU 21.19.0.0.0"
git push
```

### What Happens Next?

When you open a Pull Request against the `master` branch, the GitHub Actions workflow will trigger automatically. It will:

1. Read your new entries from `modify_patchlist.yml`.
2. Update the Ansible configuration file (`roles/common/defaults/main.yml`) with the new patch data.
3. Update the software download tables in the user documentation (`docs/user-guide.md`).
4. Commit these automated changes directly to your pull request branch.

You will see a new commit on your branch authored by "GitHub Actions" with the message "automation: Update patch files".

**IMPORTANT:** The automation does **not** clear the `modify_patchlist.yml` file. After your PR is merged, you **must manually delete the entries** from `modify_patchlist.yml` as part of your next feature branch. Failure to do so will cause the automation to add the same patches again in a future PR.

---

## Technical Documentation

This section details the internal workings of the automation, its components, and the overall workflow.

### Automation Flow

The automation is executed within a GitHub Actions workflow and follows these steps:

1. **Trigger**: The workflow is triggered when a **pull request is opened against the `master` branch**, or when a user triggers it **manually** via the GitHub Actions UI (`workflow_dispatch`).
2. **Update Configuration**: The `.github/workflows/modify_patches.py` script is executed.
    * It parses the new, uncommented entries in the root `modify_patchlist.yml`.
    * It formats and inserts the new patch data into the correct list within `roles/common/defaults/main.yml`.
3. **Update Documentation**: The `.github/workflows/modify_documentation.py` script is executed.
    * It also parses the new entries from `modify_patchlist.yml`.
    * It checks for any documentation overrides provided in the `documentation_overrides` section.
    * It formats the new software/patch information into a new table row (HTML or Markdown, depending on the target table).
    * It intelligently inserts the new row into the correct table in `docs/user-guide.md`, attempting to maintain version-based sorting.
4. **Commit Changes**: The `stefanzweifel/git-auto-commit-action` action is executed as the final step.
    * It configures git with a default user ("GitHub Actions").
    * It stages all modified files (`roles/common/defaults/main.yml` and `docs/user-guide.md`).
    * It commits the staged changes with a standardized commit message and pushes the new commit back to the source branch of the pull request.

### File Breakdown

The automation involves the following key files:

| File Path                                  | Description                                                                                                                                                    |
| :----------------------------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `.github/workflows/modify_patches.yml`     | **GitHub Actions Workflow.** The main orchestrator that defines the trigger, installs dependencies, runs the Python scripts, and commits the results.                |
| `modify_patchlist.yml`                    | **Input File.** Users edit this file to add new software or patches. It acts as a manifest for the automation to consume. **Content must be manually cleared after a PR is merged.** |
| `roles/common/defaults/main.yml`           | **Primary Configuration Target.** This Ansible defaults file is the "source of truth" for software/patch definitions and is automatically updated by the automation. |
| `docs/user-guide.md`                       | **Documentation Target.** The user guide containing software download tables, which is automatically updated to reflect new additions.                            |
| `.github/workflows/modify_patches.py`      | **Configuration Script.** Responsible for parsing the input file and prepending the new entries to the appropriate lists in `roles/common/defaults/main.yml`.     |
| `.github/workflows/modify_documentation.py`| **Documentation Script.** Responsible for parsing the input file and inserting new entries into the appropriate tables in `docs/user-guide.md`.                   |

### Script Details

#### `modify_patches.py`

This script orchestrates the update of the main Ansible configuration file.

* **Patch Compilation**: It constructs the new YAML entry as a properly formatted string to ensure consistent styling.
* **Insertion**: The script locates the correct top-level key (e.g., `gi_patches:`) and inserts the new patch entries at the beginning of the list, preserving the order from the input file.
* **Idempotency**: **This script is not idempotent.** It does not modify the `modify_patchlist.yml` input file. If the workflow is run again without clearing `modify_patchlist.yml`, it will add duplicate entries to `roles/common/defaults/main.yml`. The process relies on the user to manually clear the input file after a pull request is merged.

#### `modify_documentation.py`

This script handles the automated updates to the user-facing documentation.

* **Data Loading**: It loads the patch data from `modify_patchlist.yml` and the documentation content from `docs/user-guide.md`.
* **Overrides**: It checks for and applies any user-defined overrides from the `documentation_overrides` section of the input file.
* **Table Insertion**: The script contains logic to find specific tables within the markdown file (e.g., "Required Oracle Software - Download Summary"). It then generates a new table row and inserts it. For tables sorted by version, it attempts to insert the new row in the correct chronological position.
* **File Saving**: After all modifications, it overwrites `docs/user-guide.md` with the updated content.
