# Patch Automation User Guide

## How to Add a New Patch

The entire process is driven by a single input file: `modify_patchlist.yaml`.

### Step 1: Edit the Input File

Open the `modify_patchlist.yaml` file located in the root of the repository. This file contains several sections for different types of software and patches.

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

To add a new RDBMS patch, you would add a new entry under the `rdbms_patches` section in `modify_patchlist.yaml`:

```yaml
rdbms_patches:
  - { category: "RU", base: "21.3.0.0.0", release: "21.19.0.0.0", patchnum: "38123456", patchfile: "p38123456_210000_Linux-x86-64.zip", patch_subdir: "/", prereq_check: false, method: "opatch apply", ocm: false, upgrade: false, md5sum: "newMd5SumGoesHere==" }
```

**Important:**

* The automation will automatically detect and remove any older versions of the same patch (based on `release` or `patchnum`) to prevent duplicates.
* Fill in all fields accurately, especially the checksums.

### Step 4: (Optional) Override Documentation Text

The automation will also update the user documentation. It generates default descriptions based on the patch data. If you need to override this default text, you can specify custom values in the `documentation_overrides` section of `modify_patchlist.yaml`.

**Example:**

```yaml
documentation_overrides:
  skip_docs_update: false  # Set to true to skip doc updates entirely

  rdbms_patches:
    category: "Patch - My Oracle Support"
    software_piece: "Custom DB RU 21.19"
    file_name: "p38123456_210000_Linux-x86-64.zip"
```

If you leave these fields blank, the automation will use values based on patch applied.

### Step 5: Commit and Push

Commit and push your changes to the `modify_patchlist.yaml` file.

```bash
git add modify_patchlist.yaml
git commit -m "feat: Add RDBMS RU 21.19.0.0.0"
git push
```

### What Happens Next?

Once you create a PR into master, the Git automation will trigger. It will:

1. Read your new entries from `modify_patchlist.yaml`.
2. Update the main configuration file (`roles/common/defaults/main.yml`) with the new patch data.
3. Update the documentation tables in `docs/user-guide.md`.
4. Comment out the entries you added in `modify_patchlist.yaml` to mark them as processed.
5. Commit all these changes back to your branch automatically.

You will see a new commit on your branch authored by "GitHub Actions" with the message "automation: Update patch files".

---

## Technical Documentation

This section details the internal workings of the automation, its components, and the overall workflow.

### Automation Flow

The automation is executed within a GitHub Actions workflow and follows these steps:

1. **Trigger**: The workflow is triggered by a push to the repository that includes changes to `modify_patchlist.yaml`.
2. **Update Configuration**: The `.github/workflows/modify_patches.py` script is executed.
    * It parses the new, uncommented entries in `modify_patchlist.yaml`.
    * For each entry, it searches `roles/common/defaults/main.yml` for existing duplicates (e.g., by version, name, or patch number).
    * It removes any found duplicates to ensure the configuration remains clean.
    * It formats and inserts the new patch data into the correct list within `roles/common/defaults/main.yml`.
    * After processing all entries, it comments out the processed lines in `modify_patchlist.yaml` to prevent them from being processed again on subsequent runs.
3. **Update Documentation**: The `.github/workflows/modify_documentation.py` script is executed.
    * It also parses the new entries from `modify_patchlist.yaml`.
    * It checks for any documentation overrides provided in the `documentation_overrides` section.
    * It formats the new software/patch information into a new table row (HTML or Markdown, depending on the target table).
    * It intelligently inserts the new row into the correct table in `docs/user-guide.md`, attempting to maintain version-based sorting.
4. **Commit Changes**: The `.github/workflows/commit_patches.bash` script is executed as the final step.
    * It configures git with a default user ("GitHub Actions").
    * It stages all modified files (`roles/common/defaults/main.yml`, `docs/user-guide.md`, and `modify_patchlist.yaml`).
    * It commits the staged changes with a standardized commit message.
    * It pushes the new commit back to the repository, completing the cycle.

### File Breakdown

The automation involves the following key files:

| File Path | Description |
| :--- | :--- |
| `modify_patchlist.yaml` | **Input File.** Users edit this file to add new software or patches. It acts as a temporary manifest for the automation to consume. |
| `roles/common/defaults/main.yml`| **Primary Configuration Target.** This Ansible defaults file is the "source of truth" for software/patch definitions and is automatically updated by the automation. |
| `docs/user-guide.md` | **Documentation Target.** The user guide containing software download tables, which is automatically updated to reflect new additions. |
| `.github/workflows/modify_patches.py`| **Core Logic Script.** Responsible for parsing the input file, handling de-duplication, and updating `roles/common/defaults/main.yml`. It also comments out processed entries in the input file. |
| `.github/workflows/modify_documentation.py` | **Documentation Script.** Responsible for parsing the input file and inserting new entries into the appropriate tables in `docs/user-guide.md`. |
| `.github/workflows/commit_patches.bash` | **Git Commit Script.** A simple shell script that finalizes the automation by committing all the generated file changes back to the repository. |

### Script Details

#### `modify_patches.py`

This script orchestrates the update of the main Ansible configuration file.

* **De-duplication**: Before adding a new patch, the script reads `main.yml` line by line to find entries with a matching `version`, `release`, or `patchnum`. If a match is found, the entire block for the old patch is removed to prevent conflicts and superseded entries.
* **Patch Compilation**: It constructs the new YAML entry as a properly formatted, single-line string to ensure consistent styling.
* **Insertion**: The script locates the correct top-level key (e.g., `gi_patches:`) and inserts the new patch entry at the beginning of the list. This keeps the most recent patches at the top.
* **idempotency**: By commenting out the processed lines in `modify_patchlist.yaml` after a successful run, the script ensures that a re-run of the workflow does not process the same patches again.

#### `modify_documentation.py`

This script handles the automated updates to the user-facing documentation.

* **Data Loading**: It loads the patch data from `modify_patchlist.yaml` and the documentation content from `docs/user-guide.md`.
* **Overrides**: It checks for and applies any user-defined overrides from the `documentation_overrides` section of the input file.
* **Table Insertion**: The script contains logic to find specific tables within the markdown file (e.g., "Required Oracle Software - Download Summary"). It then generates a new table row and inserts it. For tables sorted by version, it attempts to insert the new row in the correct chronological position.
* **File Saving**: After all modifications, it overwrites `docs/user-guide.md` with the updated content.
