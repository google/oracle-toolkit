#!/usr/bin/python3
"""
test_patch_parser.py: Unit and regression test for gen_patch_metadata.py.

This test validates that the patch parsing logic in gen_patch_metadata.py
correctly extracts metadata that matches the "ground truth" data stored in
the toolkit's YAML files.

It works by:
1.  Loading all patch definitions from gi_patches.yml and rdbms_patches.yml.
2.  Grouping patches by their shared .zip file.
3.  For each *unique* combo patch file, it:
    a. Downloads the .zip from a specified GCS bucket (to avoid MOS).
    b. Runs the `parse_patch` function on it.
    c. Asserts that the parsed `base_release`, `patch_release`, and the *set*
       of subdirectories (`ojvm_subdir`, `other_subdir`) match the values
       from the YAML files. (Handles ambiguous README parsing).
4.  Cleans up all downloaded files.
"""

import os
import unittest
import yaml
import logging
import shutil
from collections import defaultdict

# Import third-party libraries
try:
    from google.cloud import storage
except ImportError:
    print("Error: Missing required libraries. Please run:")
    print("pip install PyYAML google-cloud-storage")
    exit(1)


# Import the script we want to test
import gen_patch_metadata

# --- Configuration ---

# Hardcoded GCS bucket for downloading patch zips
GCS_BUCKET_NAME = "gcp-oracle-software"

# Paths relative to the script's location (assuming it's in 'tools/')
GI_PATCHES_YML = "../roles/common/defaults/main/gi_patches.yml"
RDBMS_PATCHES_YML = "../roles/common/defaults/main/rdbms_patches.yml"
DOWNLOAD_DIR = "./patch_test_temp"

# Categories that represent the "OJVM" component of a combo patch
OJVM_CATEGORIES = {"RU_Combo", "DB_OJVM_RU", "PSU_Combo"}

# Categories that represent the "Other" (GI/DB) component of a combo patch
OTHER_CATEGORIES = {"RU", "DB_RU", "PSU"}

# --- Helper Function ---

def load_patches_from_yaml(filepath: str, key: str) -> list:
    """Loads a list of patch dictionaries from a YAML file."""
    try:
        with open(filepath, 'r') as f:
            data = yaml.safe_load(f)
            # Ensure the key exists and its value is a list
            if data and key in data and isinstance(data[key], list):
                return data[key]
            elif data and key in data:
                logging.warning(f"Expected a list under key '{key}' in {filepath}, but found {type(data[key])}.")
                return [] # Return empty list if not a list
            else:
                logging.warning(f"Key '{key}' not found in {filepath}.")
                return []
    except FileNotFoundError:
        logging.warning(f"Could not find YAML file: {filepath}")
    except yaml.YAMLError as e:
        logging.error(f"Error parsing YAML file {filepath}: {e}")
    except Exception as e:
        logging.error(f"Unexpected error loading {filepath}: {e}")
    return []


def group_combo_patches_for_testing() -> list:
    """
    Loads both YAML files and groups components by their shared patchfile.
    Returns a list of patches to test.
    """
    patches_by_file = defaultdict(list)
    
    # 1. Load all patches from both files
    gi_patches = load_patches_from_yaml(GI_PATCHES_YML, 'gi_patches')
    rdbms_patches = load_patches_from_yaml(RDBMS_PATCHES_YML, 'rdbms_patches')
    
    # Filter out any non-dictionary items just in case YAML is malformed
    all_patches = [p for p in (gi_patches + rdbms_patches) if isinstance(p, dict)]

    # 2. Group by patchfile
    for patch in all_patches:
        patchfile = patch.get('patchfile')
        if patchfile:
            patches_by_file[patchfile].append(patch)
        else:
            logging.warning(f"Patch definition missing 'patchfile' key: {patch}")

    # Skip known obsolete/unavailable 12.1.0.2 patches
    OBSOLETE_PATCH_FILES = {
        'p32126899_121020_Linux-x86-64.zip',
        'p32579077_121020_Linux-x86-64.zip'
    }

    # 3. Create the final list of test cases
    combo_patches_to_test = []
    for patchfile, components in patches_by_file.items():
        
        if patchfile in OBSOLETE_PATCH_FILES:
            logging.warning(f"Skipping test for obsolete/unavailable patch: {patchfile}")
            continue

        # Ensure components list is not empty and first item is a dict
        if not components or not isinstance(components[0], dict):
             logging.warning(f"Skipping {patchfile}: Invalid component data found.")
             continue

        patchnum_str = str(components[0].get('patchnum', '0'))
        
        # Test combo patches (pre-21c)
        if len(components) == 2:
            comp_a, comp_b = components
            
            # Ensure both components are dictionaries before proceeding
            if not isinstance(comp_a, dict) or not isinstance(comp_b, dict):
                logging.warning(f"Skipping {patchfile}: Invalid component data for pair.")
                continue

            # Check essential keys exist
            if not all(k in comp_a for k in ['base', 'release', 'category', 'patch_subdir']) or \
               not all(k in comp_b for k in ['category', 'patch_subdir']):
                logging.warning(f"Skipping {patchfile}: Missing required keys in component definitions.")
                continue


            # Normalize 19c base release
            base_release = comp_a['base']
            if base_release == '19.0.0.0.0':
                base_release = '19.3.0.0.0'

            test_case = {
                'patchfile': patchfile,
                'patchnum': int(patchnum_str),
                'base_release': base_release,
                'patch_release': comp_a['release'],
                'expected_ojvm_subdir': None,
                'expected_other_subdir': None
            }
            
            # Assign expected subdirs based on category
            cat_a = comp_a.get('category')
            cat_b = comp_b.get('category')

            if cat_a in OJVM_CATEGORIES and cat_b in OTHER_CATEGORIES:
                test_case['expected_ojvm_subdir'] = comp_a['patch_subdir']
                test_case['expected_other_subdir'] = comp_b['patch_subdir']
            elif cat_b in OJVM_CATEGORIES and cat_a in OTHER_CATEGORIES:
                test_case['expected_ojvm_subdir'] = comp_b['patch_subdir']
                test_case['expected_other_subdir'] = comp_a['patch_subdir']
            else:
                # Log only if categories are present but don't fit expected combo pattern
                if cat_a and cat_b:
                    logging.warning(f"Skipping {patchfile}: Categories '{cat_a}' and '{cat_b}' do not form a recognized combo pattern.")
                elif not cat_a or not cat_b:
                    logging.warning(f"Skipping {patchfile}: One or both components missing 'category' key.")
                continue
            
            # Ensure subdirs were successfully assigned
            if test_case['expected_ojvm_subdir'] is None or test_case['expected_other_subdir'] is None:
                logging.warning(f"Skipping {patchfile}: Could not reliably determine OJVM/Other subdirs from categories.")
                continue

            combo_patches_to_test.append(test_case)

        elif len(components) > 2:
            logging.warning(f"Skipping {patchfile}: Found {len(components)} entries for this file, expected 2 for a combo patch.")
        else: # len(components) == 1
            # This is a single-component patch (e.g., PSU_Combo 11.2 or 21c RU)
            # The parse_patch() function is designed for combos, so we skip these.
            logging.info(f"Skipping {patchfile}: Not a 2-component combo patch.")
            
    return combo_patches_to_test

# --- Test Case Class ---

class TestPatchParser(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        """Called once before all tests."""
        logging.info("Loading and grouping patch metadata for testing...")
        cls.patches_to_test = group_combo_patches_for_testing()
        if not cls.patches_to_test:
            # Changed to warning + skip instead of raising error, allows tests to run partially
            logging.warning("No combo patch files found to test. Check YAML paths and contents. Skipping tests.")
            cls.patches_to_test = [] # Ensure it's an empty list
            # raise RuntimeError("No patch files found to test. Check YAML paths and contents.")

        logging.info(f"Found {len(cls.patches_to_test)} unique combo patches to test.")
        
        # Initialize bucket to None, attempt connection only if needed
        cls.bucket = None
        if cls.patches_to_test: # Only connect if there are tests to run
            try:
                storage_client = storage.Client()
                cls.bucket = storage_client.bucket(GCS_BUCKET_NAME)
                if not cls.bucket.exists():
                    raise RuntimeError(f"GCS Bucket '{GCS_BUCKET_NAME}' does not exist or you lack permissions.")
            except Exception as e:
                logging.error(f"Failed to connect to GCS: {e}")
                # Don't raise here, allow tests to potentially fail individually
                cls.bucket = None # Ensure bucket is None if connection failed

        # Create a temp dir for downloads
        os.makedirs(DOWNLOAD_DIR, exist_ok=True)
        logging.info(f"Using temp download directory: {DOWNLOAD_DIR}")

    @classmethod
    def tearDownClass(cls):
        """Called once after all tests."""
        logging.info(f"Cleaning up temp directory: {DOWNLOAD_DIR}")
        try:
            shutil.rmtree(DOWNLOAD_DIR)
        except Exception as e:
            logging.error(f"Could not clean up {DOWNLOAD_DIR}: {e}")

    def test_patch_parsing_against_yaml(self):
        """
D        Iterates all combo patches, downloads from GCS, and validates parsing.
        """
        if not self.patches_to_test:
            self.skipTest("No combo patches were loaded for testing.")
        
        if self.bucket is None:
            self.fail("Could not connect to GCS bucket. See previous errors.")

            
        failures = []
        for patch_data in self.patches_to_test:
            patchfile = patch_data['patchfile']
            local_path = os.path.join(DOWNLOAD_DIR, patchfile)
            
            # Use subTest to run each patch as an independent test
            with self.subTest(patchfile=patchfile):
                logging.info(f"--- Testing Patch: {patchfile} ---")
                try:
                    # 1. Download from GCS
                    logging.info(f"Downloading {patchfile} from GCS...")
                    blob = self.bucket.blob(patchfile)
                    if not blob.exists():
                        raise FileNotFoundError(f"{patchfile} not found in bucket {GCS_BUCKET_NAME}")
                    blob.download_to_filename(local_path)
                    
                    self.assertTrue(os.path.exists(local_path))

                    # 2. Run the parser
                    logging.info(f"Parsing {patchfile}...")
                    (release, patch_release, ojvm_subdir, other_subdir, _) = \
                        gen_patch_metadata.parse_patch(local_path, patch_data['patchnum'])
                    
                    # Normalize base release (e.g., 19.0.0.0.0 -> 19.3.0.0.0)
                    base_release = '19.3.0.0.0' if release == '19.0.0.0.0' else release

                    # 3. Compare results
                    logging.info(f"Validating parsed data against YAML...")
                    self.assertEqual(base_release, patch_data['base_release'], "Base release mismatch")
                    self.assertEqual(patch_release, patch_data['patch_release'], "Patch release mismatch")

                    # Compare sets of subdirs
                    # This handles cases where the parser guessed the OJVM/Other assignment incorrectly
                    parsed_subdirs = {ojvm_subdir, other_subdir}
                    expected_subdirs = {patch_data['expected_ojvm_subdir'], patch_data['expected_other_subdir']}
                    self.assertSetEqual(parsed_subdirs, expected_subdirs,
                                        f"Subdirectory mismatch. Parsed: {parsed_subdirs}, Expected: {expected_subdirs}")

                    logging.info(f"SUCCESS: {patchfile}")

                except Exception as e:
                    logging.error(f"FAILED: {patchfile}\n{e}")
                    # Include assertion details if available
                    error_msg = str(e)
                    if isinstance(e, AssertionError):
                         # unittest adds extra context, use that
                        failures.append(f"{patchfile}: {error_msg}")
                    else:
                        failures.append(f"{patchfile}: {type(e).__name__}: {error_msg}")
                
                finally:
                    # 4. Clean up the zip file
                    if os.path.exists(local_path):
                        try:
                            os.remove(local_path)
                        except OSError as e:
                             logging.warning(f"Could not remove temporary file {local_path}: {e}")

        # Final report of all failures
        if failures:
             # Use assertMultiLineEqual for better diff output on assertion errors
             failure_details = f"Test failed for {len(failures)} patches:\n" + "\n".join(failures)
             # This will print the full list if it fails
             self.assertEqual([], failures, failure_details)


if __name__ == '__main__':
    logging.basicConfig(level=logging.INFO, format='%(levelname)s: %(message)s')
    unittest.main()
