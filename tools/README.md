# oracle-toolkit tools

The `tools/` folder is intended for helpful tools and scripts that aren't
part of the main oracle-toolkit codebase.

## gen_patch_metadata.py

`gen_patch_metadata.py` is a maintainer script used to add metadata for new Oracle patch bundles.

It has two primary functions:
1.  **Command-Line Tool:** When run directly, it downloads a *new* patch from My Oracle Support (MOS), parses its version and hash information, and generates the YAML snippets required for the toolkit.
2.  **Importable Module:** It provides a `parse_patch` function that can be imported by other scripts (like `test_patch_parser.py`) to validate patch-parsing logic.

### Sample Usage (Adding a New Patch)

This workflow is for **adding a new patch** to the toolkit.

```bash
$ python3 gen_patch_metadata.py --patch 35742441 --mosuser user@example.com
MOS Password:
INFO: Authenticating with MOS...
INFO: Downloading main patch 35742441...
INFO: Downloading p35742441_190000_Linux-x86-64.zip from updates.oracle.com
INFO: Successfully downloaded p35742441_190000_Linux-x86-64.zip
INFO: Calculating MD5 for p35742441_190000_Linux-x86-64.zip...
INFO: Calculated MD5 digest: 83s+HwWwloTKy0+i2s3fLg==
INFO: Abstract: COMBO OF OJVM RU COMPONENT 19.21.0.0.231017 + GI RU 19.21.0.0.231017
INFO: Found numeric subdirectories: {'35648110', '35642822'}
INFO: Assigned 'Other' subdir based on clear keywords: /35642822
INFO: --- Patch Analysis Results ---
INFO:   Base Release:   19.3.0.0.0
INFO:   Patch Release:  19.21.0.0.231017
INFO:   "Other" Subdir: /35642822 (This is likely the GI or DB_RU component)
INFO:   "OJVM" Subdir:  /35648110
INFO: --------------------------------
INFO: Downloading OPatch (Patch 6880880) for release 19.3.0.0.0
INFO: Found specific OPatch URL: ...p6880880_190000_Linux-x86-64.zip...
INFO: Using local copy of OPatch file p6880880_190000_Linux-x86-64.zip

# === SCRIPT OUTPUT: Copy files and update YAML ===

# 1. Copy the following files to your GCS bucket:
# p35742441_190000_Linux-x86-64.zip p6880880_190000_Linux-x86-64.zip

# 2. Add the following to roles/common/defaults/main/ files:
#    (Review the abstract to make the correct selections!)
#
# Abstract: COMBO OF OJVM RU COMPONENT 19.21.0.0.231017 + GI RU 19.21.0.0.231017

# --- SELECTION 1: Choose the NON-OJVM component (GI or DB) ---
# --- This component is in subdir: /35642822 ---

# 1A: If this is a GI Patch (RU), add to 'gi_patches.yml':
#   gi_patches:
#     - { category: "RU", base: "19.3.0.0.0", release: "19.21.0.0.231017", patchnum: "35742441", patchfile: "p35742441_190000_Linux-x86-64.zip", patch_subdir: "/35642822", prereq_check: FALSE, method: "opatchauto apply", ocm: FALSE, upgrade: FALSE, md5sum: "83s+HwWwloTKy0+i2s3fLg==" }

# 1B: If this is an RDBMS Patch (DB_RU), add to 'rdbms_patches.yml':
#   rdbms_patches:
#     - { category: "DB_RU", base: "19.3.0.0.0", release: "19.21.0.0.231017", patchnum: "35742441", patchfile: "p35742441_190000_Linux-x86-64.zip", patch_subdir: "/35642822", prereq_check: TRUE, method: "opatch apply", ocm: FALSE, upgrade: TRUE, md5sum: "83s+HwWwloTKy0+i2s3fLg==" }

# --- SELECTION 2: Choose the OJVM component ---
# --- This component is in subdir: /35648110 ---

# 2A: If OJVM is from a GI Combo (RU_Combo), add to 'rdbms_patches.yml':
#   rdbms_patches:
#     - { category: "RU_Combo", base: "19.3.0.0.0", release: "19.21.0.0.231017", patchnum: "35742441", patchfile: "p35742441_190000_Linux-x86-64.zip", patch_subdir: "/35648110", prereq_check: TRUE, method: "opatch apply", ocm: FALSE, upgrade: TRUE, md5sum: "83s+HwWwloTKy0+i2s3fLg==" }

# 2B: If this is an OJVM + DB RU (DB_OJVM_RU), add to 'rdbms_patches.yml':
#   rdbms_patches:
#     - { category: "DB_OJVM_RU", base: "19.3.0.0.0", release: "19.21.0.0.231017", patchnum: "35742441", patchfile: "p35742441_190000_Linux-x86-64.zip", patch_subdir: "/35648110", prereq_check: TRUE, method: "opatch apply", ocm: FALSE, upgrade: TRUE, md5sum: "83s+HwWwloTKy0+i2s3fLg==" }

# === END SCRIPT OUTPUT ===
```

-----

## test_patch_parser.py (Unit Tests)

`test_patch_parser.py` is a unit test script that validates the parsing logic in `gen_patch_metadata.py`.

### How It Works
It reads *all* patch definitions from the toolkit's `gi_patches.yml` and `rdbms_patches.yml` files. For every 2-component combo patch, it:
1.  Downloads the corresponding `.zip` file from the **`gcp-oracle-software` GCS bucket** (it does **not** use MOS).
2.  Runs the `parse_patch` function on the downloaded file.
3.  Compares the parsed metadata (base release, patch release, and set of subdirectories) against the "ground truth" values from the YAML files.

### How to Run the Unit Tests

1.  Navigate to the `tools/` directory:
    ```bash
    cd oracle-toolkit/tools
    ```

2.  Install all required Python dependencies:
    ```bash
    pip install PyYAML google-cloud-storage beautifulsoup4 requests lxml
    ```

3.  Authenticate with GCS. This is **required** to download the test patches.
    ```bash
    gcloud auth application-default login
    ```

4.  Run the unit test script:
    ```bash
    python3 test_patch_parser.py
    ```

### Understanding the Test Output

* **`OK`**: If the test finishes with `OK`, it means all patch validations passed successfully.
* **`INFO: Skipping ...: Not a 2-component combo patch.`**: This is **normal**. The test is designed to *only* validate 2-component combo patches (common for 19c and earlier). It correctly identifies and skips single-component patches (like 21c+ RUs).
* **`WARNING: Skipping test for obsolete/unavailable patch: ...`**: This is also **normal**. It confirms the test is correctly skipping specific old 12.1.0.2 patches that are no longer available for download.
* **`ERROR: ... ambiguous` / `WARNING: GUESSING...`**: These messages are **expected**. They come from the `gen_patch_metadata.py` parser when its README analysis isn't 100% certain which subdir is OJVM.
    * The unit test is designed to handle this. It uses an `assertSetEqual` check to confirm that the *set* of subdirs found by the parser (e.g., `{"/12345", "/67890"}`) is correct, even if the "guess" for OJVM was wrong.
    * As long as you see `INFO: SUCCESS: ...` after these warnings, the test has passed.

---

## Known Issues

* The MOS download logic in `gen_patch_metadata.py` does not support multi-file patches (it will only download the first file).
* The parser (`parse_patch`) is designed for 2-component combo patches (e.g., 11.2-19c) and is not intended for single-component RUs (e.g., 21c+). The unit test correctly skips these.
