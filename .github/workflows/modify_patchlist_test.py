import pytest
from unittest.mock import mock_open
import pprint

# The script to be tested
import modify_patches
import difflib
import os
import pathlib

# --- Test Data ---

# A sample input YAML, mimicking the content of 'modify_patchlist.yml'.
# This data is used to populate the separate output files.
SAMPLE_INPUT_YAML = """
gi_software:
  - name: 21c_gi
    version: 21.3.0.0.0
    files:
      - { name: "V1011504-01.zip", sha256sum: "070D4471BC067B1290BDCEE6B1C1FFF2F21329D2839301E334BCB2A3D12353A3", md5sum: "s/vbdiGtgsvU9AlD7/3Rvg==",
          alt_name: "LINUX.X64_213000_grid_home.zip", alt_sha256sum: "070D4471BC067B1290BDCEE6B1C1FFF2F21329D2839301E334BCB2A3D12353A3", alt_md5sum: "s/vbdiGtgsvU9AlD7/3Rvg==" }

rdbms_software:
  - name: 23ai_free_23_8
    version: 23.8.0.25.04
    edition: FREE
    files:
      - { name: "oracle-database-preinstall-23ai-1.0-2.el8.x86_64.rpm", sha256sum: "4578e6d1cf566e04541e0216b07a0372725726a7c339423ee560255cb918138b", md5sum: "TmjqUT878Owv7NbXGECpTA=="}
      - { name: "oracle-database-free-23ai-23.8-1.el8.x86_64.rpm", sha256sum: "cd0d16939150e6ec5e70999a762a13687bfa99b05c4f310593e7ca3892e1d0ce", md5sum: "hkL/hxeYbB7z5lz+3r3kww=="}

opatch_patches:
  - { category: "OPatch", release: "19.3.0.0.0", patchnum: "6880880", patchfile: "p6880880_190000_Linux-x86-64.zip", md5sum: "" }
  - { category: "OPatch", release: "21.3.0.0.0", patchnum: "6880880", patchfile: "p6880880_210000_Linux-x86-64.zip", md5sum: "" }

gi_interim_patches:
  - category: "HAS_interim_patch"
    version: 12.2.0.1.0
    patchnum: "25078431"
    patchutil: "gridsetup"
    files:
      - { name: "p25078431_122010_Linux-x86-64.zip", sha256sum: "FA056EBD0FE0AD134F2B5C53F0DDF6F6A5DC73C7AE40DAEF18D0629850149525", md5sum: "hK1WOGC1g/3QUryg3MM5OQ==" }

gi_patches:
  - { category: "RU", base: "21.3.0.0.0", release: "21.17.0.0.0", patchnum: "37349593", patchfile: "p37349593_210000_Linux-x86-64.zip", patch_subdir: "/", prereq_check: false, method: "opatchauto apply", ocm: false, upgrade: false, md5sum: "Mt0Bw+IPKqoKh31YkneCrg==" }
  - { category: "RU", base: "21.3.0.0.0", release: "21.18.0.0.0", patchnum: "37642955", patchfile: "p37642955_210000_Linux-x86-64.zip", patch_subdir: "/", prereq_check: false, method: "opatchauto apply", ocm: false, upgrade: false, md5sum: "b8YrXNXis6agqIHny746Xw==" }

rdbms_patches:
  - { category: "RU", base: "21.3.0.0.0", release: "21.17.0.0.0", patchnum: "37350281", patchfile: "p37350281_210000_Linux-x86-64.zip", patch_subdir: "/", prereq_check: false, method: "opatch apply", ocm: false, upgrade: false, md5sum: "dQjBqlXWOumEZU3QAJzD9Q==" }
  - { category: "RU", base: "19.0.0.0.0", release: "19.18.0.0.0", patchnum: "37960098", patchfile: "p37960098_190000_Linux-x86-64.zip", patch_subdir: "/", prereq_check: false, method: "opatch apply", ocm: false, upgrade: false, md5sum: "4GhJvWSOeDMYUIupR0jFZA==" }
"""

# The initial state of the various target YAML files before modification.
GI_SOFTWARE_YAML_BEFORE = "gi_software:\n\n"
RDBMS_SOFTWARE_YAML_BEFORE = "rdbms_software:\n\n"
OTHER_PATCHES_YAML_BEFORE = "opatch_patches:\n\ngi_interim_patches:\n\n"
GI_PATCHES_YAML_BEFORE = "gi_patches:\n\n"
RDBMS_PATCHES_YAML_BEFORE = "rdbms_patches:\n\n"


# The expected final state of the target YAML files after the script has run.
EXPECTED_GI_SOFTWARE_YAML_AFTER = """
gi_software:

  - name: 21c_gi
    version: 21.3.0.0.0
    files:
      - { name: "V1011504-01.zip", sha256sum: "070D4471BC067B1290BDCEE6B1C1FFF2F21329D2839301E334BCB2A3D12353A3", md5sum: "s/vbdiGtgsvU9AlD7/3Rvg==",
          alt_name: "LINUX.X64_213000_grid_home.zip", alt_sha256sum: "070D4471BC067B1290BDCEE6B1C1FFF2F21329D2839301E334BCB2A3D12353A3", alt_md5sum: "s/vbdiGtgsvU9AlD7/3Rvg==" }

"""

EXPECTED_RDBMS_SOFTWARE_YAML_AFTER = """
rdbms_software:

  - name: 23ai_free_23_8
    version: 23.8.0.25.04
    edition: FREE
    files:
      - { name: "oracle-database-preinstall-23ai-1.0-2.el8.x86_64.rpm", sha256sum: "4578e6d1cf566e04541e0216b07a0372725726a7c339423ee560255cb918138b", md5sum: "TmjqUT878Owv7NbXGECpTA==" }
      - { name: "oracle-database-free-23ai-23.8-1.el8.x86_64.rpm", sha256sum: "cd0d16939150e6ec5e70999a762a13687bfa99b05c4f310593e7ca3892e1d0ce", md5sum: "hkL/hxeYbB7z5lz+3r3kww==" }

"""

EXPECTED_OTHER_PATCHES_YAML_AFTER = """
opatch_patches:
  - { category: "OPatch", release: "19.3.0.0.0", patchnum: "6880880", patchfile: "p6880880_190000_Linux-x86-64.zip", md5sum: "" }
  - { category: "OPatch", release: "21.3.0.0.0", patchnum: "6880880", patchfile: "p6880880_210000_Linux-x86-64.zip", md5sum: "" }

gi_interim_patches:

  - category: "HAS_interim_patch"
    version: 12.2.0.1.0
    patchnum: "25078431"
    patchutil: "gridsetup"
    files:
      - { name: "p25078431_122010_Linux-x86-64.zip", sha256sum: "FA056EBD0FE0AD134F2B5C53F0DDF6F6A5DC73C7AE40DAEF18D0629850149525", md5sum: "hK1WOGC1g/3QUryg3MM5OQ==" }

"""

EXPECTED_GI_PATCHES_YAML_AFTER = """
gi_patches:

  - { category: "RU", base: "21.3.0.0.0", release: "21.17.0.0.0", patchnum: "37349593", patchfile: "p37349593_210000_Linux-x86-64.zip", patch_subdir: "/", prereq_check: false, method: "opatchauto apply", ocm: false, upgrade: false, md5sum: "Mt0Bw+IPKqoKh31YkneCrg==" }
  - { category: "RU", base: "21.3.0.0.0", release: "21.18.0.0.0", patchnum: "37642955", patchfile: "p37642955_210000_Linux-x86-64.zip", patch_subdir: "/", prereq_check: false, method: "opatchauto apply", ocm: false, upgrade: false, md5sum: "b8YrXNXis6agqIHny746Xw==" }

"""

EXPECTED_RDBMS_PATCHES_YAML_AFTER = """
rdbms_patches:

  - { category: "RU", base: "21.3.0.0.0", release: "21.17.0.0.0", patchnum: "37350281", patchfile: "p37350281_210000_Linux-x86-64.zip", patch_subdir: "/", prereq_check: false, method: "opatch apply", ocm: false, upgrade: false, md5sum: "dQjBqlXWOumEZU3QAJzD9Q==" }
  - { category: "RU", base: "19.0.0.0.0", release: "19.18.0.0.0", patchnum: "37960098", patchfile: "p37960098_190000_Linux-x86-64.zip", patch_subdir: "/", prereq_check: false, method: "opatch apply", ocm: false, upgrade: false, md5sum: "4GhJvWSOeDMYUIupR0jFZA==" }

"""

def test_modify_patches_main_logic(mocker):
    """
    Tests the main logic of the modify_patches.py script.

    This test is updated to reflect the refactoring of a single output YAML
    into multiple, purpose-specific files. It now simulates and verifies
    the modification of all target files.

    It uses the pytest 'mocker' fixture to replace file system operations, making
    the test self-contained, fast, and independent of actual files.
    """
    # Arrange: Mock file paths and I/O operations.

    # Define mock filenames the script will try to access.
    input_file = 'modify_patchlist.yml'
    gi_software_file = 'roles/common/defaults/gi_software.yml'
    rdbms_software_file = 'roles/common/defaults/rdbms_software.yml'
    other_patches_file = 'roles/common/defaults/other_patches.yml'
    gi_patches_file = 'roles/common/defaults/gi_patches.yml'
    rdbms_patches_file = 'roles/common/defaults/rdbms_patches.yml'

    original_os_path_join = os.path.join

    # Mock path-related functions to return our predefined filenames,
    # isolating the test from the actual directory structure.
    def join_side_effect(*args):
        # The script joins paths like `script_dir`, `..`, `roles`, etc.
        # We only care about the final filename component.
        filename = str(args[-1])
        if 'modify_patchlist.yml' in filename:
            return input_file
        if 'gi_software.yml' in filename:
            return gi_software_file
        if 'rdbms_software.yml' in filename:
            return rdbms_software_file
        if 'other_patches.yml' in filename:
            return other_patches_file
        if 'gi_patches.yml' in filename:
            return gi_patches_file
        if 'rdbms_patches.yml' in filename:
            return rdbms_patches_file
        # --- FIX: Use the saved original function for other calls ---
        return original_os_path_join(*args)

    mocker.patch('modify_patches.os.path.join', side_effect=join_side_effect)
    mocker.patch('modify_patches.pathlib.Path', autospec=True)

    # Create a stateful in-memory file system. This dictionary holds the
    # content of our mock files and is updated by mock write operations.
    file_system_state = {
        input_file: SAMPLE_INPUT_YAML,
        gi_software_file: GI_SOFTWARE_YAML_BEFORE,
        rdbms_software_file: RDBMS_SOFTWARE_YAML_BEFORE,
        other_patches_file: OTHER_PATCHES_YAML_BEFORE,
        gi_patches_file: GI_PATCHES_YAML_BEFORE,
        rdbms_patches_file: RDBMS_PATCHES_YAML_BEFORE,
    }

    # Create a custom side effect for the built-in open() function to simulate I/O.
    def custom_open(filename, mode='r', *args, **kwargs):
        # The filename might be a Path object, convert to string for dict key
        filename_str = str(filename)
        if mode.startswith('r'):
            content = file_system_state.get(filename_str, "")
            return mock_open(read_data=content).return_value
        elif mode.startswith('w'):
            mock_file = mock_open().return_value
            def custom_writelines(lines):
                # .writelines is expected to write a list of strings
                file_system_state[filename_str] = "".join(lines)
            def custom_write(data):
                # .write is expected to write a single string
                file_system_state[filename_str] = data
            mock_file.writelines.side_effect = custom_writelines
            mock_file.write.side_effect = custom_write
            return mock_file
        return mock_open().return_value

    mocker.patch('builtins.open', custom_open)

    # Act: Run the main function of the script.
    modify_patches.main()

    # Assert: Verify the final output for each of the modified files.
    expected_states = {
        gi_software_file: EXPECTED_GI_SOFTWARE_YAML_AFTER,
        rdbms_software_file: EXPECTED_RDBMS_SOFTWARE_YAML_AFTER,
        other_patches_file: EXPECTED_OTHER_PATCHES_YAML_AFTER,
        gi_patches_file: EXPECTED_GI_PATCHES_YAML_AFTER,
        rdbms_patches_file: EXPECTED_RDBMS_PATCHES_YAML_AFTER,
    }

    for filename, expected_content in expected_states.items():
        # Normalize by splitting lines to avoid CRLF/LF issues and stripping whitespace
        actual_lines = file_system_state.get(filename, '').strip().splitlines()
        expected_lines = expected_content.strip().splitlines()

        # Provide a detailed diff on failure for easier debugging
        if actual_lines != expected_lines:
            diff = difflib.unified_diff(
                [line + '\n' for line in expected_lines], # difflib works best with newlines
                [line + '\n' for line in actual_lines],
                fromfile=f'expected_{os.path.basename(filename)}',
                tofile=f'actual_{os.path.basename(filename)}',
            )
            diff_output = ''.join(diff)
            pytest.fail(
                f"The modified YAML for '{filename}' did not match the expected output.\n\n"
                f"Diff:\n{diff_output}"
            )

        assert actual_lines == expected_lines, f"Content mismatch for {filename}"

if __name__ == "__main__":
    pytest.main([__file__])
