import yaml
import sys, os
import re
import pathlib


def load_yaml(file_path):
    """
    Loads a YAML file from the given file path.

    Args:
        file_path (str): The path to the YAML file.

    Returns:
        dict: The parsed YAML data.
    """
    try:
        # Open and read the YAML file
        with open(file_path, 'r') as file:
            patch_data = yaml.safe_load(file)
        print("YAML Version Data loaded successfully.\n\n")
        return patch_data
    except FileNotFoundError:
        # Handle case where the file does not exist
        print(f"Error: '{file_path}' not found.\n\n")
        sys.exit(1)
    except yaml.YAMLError as exc:
        # Handle errors during YAML parsing
        print(f"Error parsing YAML file: {exc}\n\n")
        sys.exit(1)

def software_delete_duplicates(match_lines, output_yml):
    """
    Deletes entire software patch blocks from the output YAML file based on line numbers.
    A software block is identified by a line starting with '  - name:'.

    Args:
        match_lines (list): A list of line numbers where duplicates were found.
        output_yml (str): The path to the output YAML file.
    """
    if not match_lines:
        return
    with open(output_yml, 'r') as file:
        lines = file.readlines()

    # For each match_line, find the start and end of the patch block, then remove it.
    # The process is done in reverse order to avoid index shifting issues.
    removed_ranges = []
    for match_line in sorted(set(match_lines), reverse=True):
        # Find the beginning of the software patch block (a line starting with '- name:')
        start = None
        for find_range in range(0, 10):
            idx = match_line - find_range
            if idx < 0:
                break
            if re.match(r'^  - name:', lines[idx]):
                start = idx
                break

        # Find the end of the software patch block (the line before the next block or end of file)
        end = None
        for find_range in range(1, 20):
            idx = match_line + find_range
            if idx >= len(lines):
                break
            if re.match(r'^  - name:', lines[idx]):
                end = idx
                break
        if end is None:
            end = len(lines)

        if start is not None:
            print(f"Removing software patch from line {start} to {end}.\n\n")
            removed_ranges.append((start, end))
        else:
            print("Error: Could not find the start of the software patch.\n\n")

    # Remove all identified ranges in reverse order to maintain correct indices
    for start, end in sorted(removed_ranges, reverse=True):
        del lines[start:end]

    # Write the modified content back to the file
    with open(output_yml, 'w') as file:
        file.writelines(lines)

def patch_delete_duplicates(match_lines, output_yml):
    """
    Deletes specific lines from the output YAML file.

    Args:
        match_lines (list): A list of line numbers to delete.
        output_yml (str): The path to the output YAML file.
    """
    if not match_lines:
        return
    with open(output_yml, 'r') as file:
        lines = file.readlines()

    # Delete each matched line, iterating in reverse to avoid index shifting.
    for match_line in sorted(set(match_lines), reverse=True):
        del lines[match_line]

    # Write the modified content back to the file
    with open(output_yml, 'w') as file:
        file.writelines(lines)

def gi_software_search_duplicates(gi_software, output_yml):
    """
    Searches for and removes duplicate GI software entries in the output YAML file.

    Args:
        gi_software (list): A list of GI software patch data.
        output_yml (str): The path to the output YAML file.
    """
    duplicate_indices = []
    with open(output_yml, 'r') as file:
        lines = file.readlines()
    for each_patch in gi_software:
        name = each_patch['name'].strip()
        version = each_patch['version'].strip()
        
        for idx, line in enumerate(lines):
            if idx==0:
                skip = True
                skip_next_line = False
                continue

            if skip_next_line:
                skip_next_line = False
                continue

            # Match lines for gi_software name and version
            name_match = re.match(r'^\s*-\s*name\s*:\s*(.+)$', line)
            version_match = re.match(r'^\s*version\s*:\s*(.+)$', line)

            # Skip lines until the 'gi_software:' section is found
            if skip:
                if line.strip() == 'gi_software:':
                    skip = False
                continue

            # Stop searching within this section if an empty line is encountered
            if line.strip() == "":
                break

            # If a name or version matches, mark it as a duplicate
            if name_match and name_match.group(1).strip() == name:
                print(f"GI software '{name}' already exists at line {idx+1}.\n\n")
                duplicate_indices.append(idx)
                skip_next_line = True
            elif version_match and version_match.group(1).strip() == version:
                print(f"GI software version '{version}' already exists at line {idx+1}.\n\n")
                duplicate_indices.append(idx)
    # Remove the identified duplicate software blocks
    software_delete_duplicates(duplicate_indices, output_yml)

def gi_software_compile_patch(gi_software):
    """
    Compiles GI software data into a list of formatted YAML strings.

    Args:
        gi_software (list): A list of GI software patch data.

    Returns:
        list: A list of formatted YAML strings for GI software patches.
    """
    patches_list = []
    for each_patch in gi_software:
        name = each_patch['name'].strip()
        version = each_patch['version'].strip()
        files = each_patch['files']

        # Create the main part of the patch string
        patch = "  - name: {name}\n    version: {version}\n    files:\n".format(
            name=name, 
            version=version
        )

        # Add each file to the patch string
        for file in files:
            patch += """      - {{ name: \"{name}\", sha256sum: \"{sha256}\", md5sum: \"{md5}\",
          alt_name: \"{alt_name}\", alt_sha256sum: \"{alt_sha256}\", alt_md5sum: \"{alt_md5}\" }}""".format(
                name=file['name'].strip(),
                sha256=file['sha256sum'].strip(),
                md5=file['md5sum'].strip(),
                alt_name=file['alt_name'].strip(),
                alt_sha256=file['alt_sha256sum'].strip(),
                alt_md5=file['alt_md5sum'].strip()
            )
        patches_list.append("\n".join(patch.splitlines()))
    patches_list.reverse() # Reverse the list to maintain the original order when inserting
    return patches_list

def gi_software_insert_patch(gi_software_patches, output_yml):
    """
    Inserts compiled GI software patches into the output YAML file.

    Args:
        gi_software_patches (list): A list of formatted YAML strings for GI software patches.
        output_yml (str): The path to the output YAML file.
    """
    read_yml = open(output_yml, 'r')
    lines = read_yml.readlines()
    
    # Find the 'gi_software:' line
    for i, line in enumerate(lines):
        if line.strip() == 'gi_software:':
            # Insert each patch after the 'gi_software:' line
            for gi_software_patch in gi_software_patches:
                lines.insert(i + 1, gi_software_patch + "\n")
            break
    else:
        # Handle case where 'gi_software:' section is not found
        print("Error: 'gi_software:' not found in the file.\n\n")
        sys.exit(1)

    # Write the updated lines back to the file
    with open(output_yml, 'w') as file:
        file.writelines(lines)
    print("GI software patch inserted successfully.\n\n")

def gi_interim_search_duplicates(gi_interim_patches, output_yml):
    """
    Searches for and removes duplicate GI interim patches in the output YAML file.

    Args:
        gi_interim_patches (list): A list of GI interim patch data.
        output_yml (str): The path to the output YAML file.
    """
    duplicate_indices = []
    with open(output_yml, 'r') as file:
        lines = file.readlines()
    for each_patch in gi_interim_patches:
        version = each_patch['version'].strip()
        patchnum = each_patch['patchnum'].strip()

        for idx, line in enumerate(lines):
            if idx==0:
                skip = True
                skip_next_line = False
                continue

            if skip_next_line:
                skip_next_line = False
                continue

            # Match lines for gi_interim_patches version and patchnum
            version_match = re.match(r'^\s*version\s*:\s*(.+)$', line)
            patchnum_match = re.match(r'^\s*patchnum\s*:\s*"?([^"\n]+)"?$', line) 

            # Skip lines until the 'gi_interim_patches:' section is found
            if skip:
                if line.strip() == 'gi_interim_patches:':
                    skip = False
                continue

            # Stop searching within this section if an empty line is encountered
            if line.strip() == "":
                break

            # If a version or patchnum matches, mark it as a duplicate
            if version_match and version_match.group(1).strip() == version:
                print(f"GI interim patch version '{version}' already exists at line {idx+1}.\n\n")
                duplicate_indices.append(idx)
                skip_next_line = True
                continue

            if patchnum_match and patchnum_match.group(1).strip() == patchnum:
                print(f"GI interim patch '{patchnum}' already exists at line {idx+1}.\n\n")
                duplicate_indices.append(idx)

    # Remove the identified duplicate interim patch blocks
    gi_interim_delete_duplicates(duplicate_indices, output_yml)

def gi_interim_delete_duplicates(match_lines, output_yml):
    """
    Deletes entire GI interim patch blocks from the output YAML file based on line numbers.
    A block is identified by a line starting with '  - category:'.

    Args:
        match_lines (list): A list of line numbers where duplicates were found.
        output_yml (str): The path to the output YAML file.
    """
    if not match_lines:
        return
    with open(output_yml, 'r') as file:
        lines = file.readlines()

    # For each match_line, find the start and end of the patch block, then remove it.
    removed_ranges = []
    for match_line in sorted(set(match_lines), reverse=True):
        # Find the beginning of the patch block (a line starting with '- category:')
        start = None
        for find_range in range(0, 10):
            idx = match_line - find_range
            if idx < 0:
                break
            if re.match(r'^  - category:', lines[idx]):
                start = idx
                break

        # Find the end of the patch block (the line before the next block or an empty line)
        end = None
        for find_range in range(1, 20):
            idx = match_line + find_range
            if idx >= len(lines):
                break
            if re.match(r'^  - category:', lines[idx]):
                end = idx
                break
            elif lines[idx].strip() == "":
                end = idx
                break

        if start is not None:
            print(f"Removing GI interim patch from line {start} to {end}.\n\n")
            removed_ranges.append((start, end))
        else:
            print("Error: Could not find the start of the GI interim patch.\n\n")

    # Remove all identified ranges in reverse order
    for start, end in sorted(removed_ranges, reverse=True):
        del lines[start:end]

    # Write the modified content back to the file
    with open(output_yml, 'w') as file:
        file.writelines(lines)

def gi_interim_compile_patch(gi_interim_patches):
    """
    Compiles GI interim patch data into a list of formatted YAML strings.

    Args:
        gi_interim_patches (list): A list of GI interim patch data.

    Returns:
        list: A list of formatted YAML strings for GI interim patches.
    """
    patches_list = []
    for each_patch in gi_interim_patches:
        category = each_patch['category'].strip()
        version = each_patch['version'].strip()
        patchnum = each_patch['patchnum'].strip()
        patchutil = each_patch['patchutil'].strip()
        files = each_patch['files']

        # Create the main part of the patch string
        patch = "  - category: \"{0}\"\n    version: {1}\n    patchnum: \"{2}\"\n    patchutil: \"{3}\"\n    files:\n".format(
            category, version, patchnum, patchutil
        )

        # Add each file to the patch string
        for file in files:
            patch += "      - {{ name: \"{0}\", sha256sum: \"{1}\", md5sum: \"{2}\" }}\n".format(
                file['name'].strip(),
                file['sha256sum'].strip(),
                file['md5sum'].strip()
            )
        patches_list.append("\n".join(patch.splitlines()))

    return patches_list

def gi_interim_insert_patch(gi_interim_patches, output_yml):
    """
    Inserts compiled GI interim patches into the output YAML file.

    Args:
        gi_interim_patches (list): A list of formatted YAML strings for GI interim patches.
        output_yml (str): The path to the output YAML file.
    """
    read_yml = open(output_yml, 'r')
    lines = read_yml.readlines()

    # Find the 'gi_interim_patches:' line
    for i, line in enumerate(lines):
        if line.strip() == 'gi_interim_patches:':
            # Insert each patch after the 'gi_interim_patches:' line
            for gi_interim_patch in gi_interim_patches:
                lines.insert(i+1, gi_interim_patch + "\n")
            break

    # Write the updated lines back to the file
    with open(output_yml, 'w') as file:
        file.writelines(lines)
    print("GI interim patches patch inserted successfully.\n\n")

def rdbms_software_search_duplicates(rdbms_software, output_yml):
    """
    Searches for and removes duplicate RDBMS software entries in the output YAML file.

    Args:
        rdbms_software (list): A list of RDBMS software patch data.
        output_yml (str): The path to the output YAML file.
    """
    duplicate_indices = []
    with open(output_yml, 'r') as file:
        lines = file.readlines()
    for each_patch in rdbms_software:
        name = each_patch['name'].strip()
        version = each_patch['version'].strip()
        
        for idx, line in enumerate(lines):
            if idx==0:
                skip = True
                skip_next_line = False
                continue

            if skip_next_line:
                skip_next_line = False
                continue

            # Match lines for rdbms_software name and version
            name_match = re.match(r'^\s*-\s*name\s*:\s*(.+)$', line)
            version_match = re.match(r'^\s*version\s*:\s*(.+)$', line)

            # Skip lines until the 'rdbms_software:' section is found
            if skip:
                if line.strip() == 'rdbms_software:':
                    skip = False
                continue

            # Stop searching within this section if an empty line is encountered
            if line.strip() == "":
                break

            # If a name or version matches, mark it as a duplicate
            if name_match and name_match.group(1).strip() == name:
                print(f"GI software '{name}' already exists at line {idx+1}.\n\n")
                duplicate_indices.append(idx)
                skip_next_line = True
            elif version_match and version_match.group(1).strip() == version:
                print(f"GI software version '{version}' already exists at line {idx+1}.\n\n")
                duplicate_indices.append(idx)

    # Remove the identified duplicate software blocks
    software_delete_duplicates(duplicate_indices, output_yml)

def rdbms_software_compile_patch(rdbms_software):
    """
    Compiles RDBMS software data into a list of formatted YAML strings.

    Args:
        rdbms_software (list): A list of RDBMS software patch data.

    Returns:
        list: A list of formatted YAML strings for RDBMS software patches.
    """
    patches_list = []
    for each_patch in rdbms_software:
        name = each_patch['name'].strip()
        version = each_patch['version'].strip()
        edition = each_patch['edition']
        files = each_patch['files']

        # Handle both list and single string for 'edition'
        if isinstance(edition, list):
            patch = "  - name: {0}\n    version: {1}\n    edition:\n".format(name, version)
            patch += "\n".join(["      - {0}".format(e.strip()) for e in edition])
            patch += "\n    files:"
        else:
            patch = "  - name: {0}\n    version: {1}\n    edition: {2}\n    files:".format(name, version, edition.strip())

        # Add each file to the patch string
        for file in files:
            patch += "\n      - {{ name: \"{0}\", sha256sum: \"{1}\", md5sum: \"{2}\" }}".format(
                file['name'].strip(),
                file['sha256sum'].strip(),
                file['md5sum'].strip()
            )
        patches_list.append("\n".join(patch.splitlines()))
    return patches_list

def rdbms_software_insert_patch(rdbms_software_patches, output_yml):
    """
    Inserts compiled RDBMS software patches into the output YAML file.

    Args:
        rdbms_software_patches (list): A list of formatted YAML strings for RDBMS software patches.
        output_yml (str): The path to the output YAML file.
    """
    read_yml = open(output_yml, 'r')
    lines = read_yml.readlines()
    
    # Find the 'rdbms_software:' line
    for i, line in enumerate(lines):
        if line.strip() == 'rdbms_software:':
            # Insert each patch after the 'rdbms_software:' line
            for rdbms_software_patch in rdbms_software_patches:
                lines.insert(i + 1, rdbms_software_patch + "\n")
            break
    else:
        # Handle case where 'rdbms_software:' section is not found
        print("Error: 'rdbms_software:' not found in the file.\n\n")
        sys.exit(1)

    # Write the updated lines back to the file
    with open(output_yml, 'w') as file:
        file.writelines(lines)
    print("RDBMS software patch inserted successfully.\n\n")

def opatch_patch_search_duplicates(opatch_patches, output_yml):
    """
    Searches for and removes duplicate OPatch entries in the output YAML file.

    Args:
        opatch_patches (list): A list of OPatch patch data.
        output_yml (str): The path to the output YAML file.
    """
    for patch in opatch_patches:
        release = patch['release'].strip()
        patchnum = patch['patchnum'].strip()
        duplicate_indices = []
        skip = True

        with open(output_yml, 'r') as file:
            lines = file.readlines()
            for idx, line in enumerate(lines):
                # Use regex to find the release value in a line
                release_match = re.search(r'release\s*:\s*"?([^",}]+)"?', line)

                if idx==0:
                    skip = True
                    continue

                # Skip lines until the 'opatch_patches:' section is found
                if skip:
                    if line.strip() == 'opatch_patches:':
                        skip = False
                    continue

                # Stop searching within this section if an empty line is encountered
                if line.strip()=="":
                    break

                # If a release matches, mark the line as a duplicate
                if release_match and release_match.group(1).strip() == release:
                    print(f"OPatch patch with release '{release}' already exists at line {idx}.\n\n")
                    duplicate_indices.append(idx)
                    continue

        # Remove the identified duplicate lines
        patch_delete_duplicates(duplicate_indices, output_yml)

def opatch_patch_compile_patch(opatch_patches):
    """
    Compiles OPatch data into a list of formatted YAML strings.

    Args:
        opatch_patches (list): A list of OPatch patch data.

    Returns:
        list: A list of formatted YAML strings for OPatch patches.
    """
    patches_list = []
    for patches in opatch_patches:
        # Format each patch as a single-line YAML list item
        patches_list.append("  - {{ category: \"OPatch\", release: \"{0}\", patchnum: \"{1}\", patchfile: \"{2}\", md5sum: \"{3}\" }}\n".format(
            patches['release'].strip(),
            patches['patchnum'].strip(),
            patches['patchfile'].strip(),
            patches['md5sum'].strip()
            )
        )
    return patches_list

def opatch_patch_insert_patch(opatch_patches_patch, output_yml):
    """
    Inserts compiled OPatch patches into the output YAML file.

    Args:
        opatch_patches_patch (list): A list of formatted YAML strings for OPatch patches.
        output_yml (str): The path to the output YAML file.
    """
    with open(output_yml, 'r') as file:
        lines = file.readlines()

    opatch_start = None
    opatch_end = None

    # Find the start of the opatch_patches list
    for i, line in enumerate(lines):
        if line.strip() == 'opatch_patches:':
            opatch_start = i
            break

    if opatch_start is None:
        print("Error: 'opatch_patches:' not found in the file.\n\n")
        sys.exit(1)

    # Find the end of the opatch_patches list (the line before the next top-level key)
    for j in range(opatch_start + 1, len(lines)):
        if re.match(r'^\S', lines[j]) and not lines[j].strip().startswith('-'):
            opatch_end = j-1
            break
    if opatch_end is None:
        opatch_end = len(lines)

    # Insert at the end of the opatch_patches list
    insert_pos = opatch_end
    for patch in opatch_patches_patch:
        lines.insert(insert_pos, patch)
        insert_pos += 1

    # Write the updated lines back to the file
    with open(output_yml, 'w') as file:
        file.writelines(lines)
    print("OPatch patches patch appended successfully.\n\n")

def gi_patch_search_duplicates(gi_patches, output_yml):
    """
    Searches for and removes duplicate GI patches in the output YAML file.

    Args:
        gi_patches (list): A list of GI patch data.
        output_yml (str): The path to the output YAML file.
    """
    for patch in gi_patches:
        release = patch['release'].strip()
        patchnum = patch['patchnum'].strip()
        duplicate_indices = []
        skip = True

        with open(output_yml, 'r') as file:
            lines = file.readlines()
            for idx, line in enumerate(lines):
                # Ignore commented lines
                if line.strip().startswith('#'):
                    continue

                # Skip lines until the 'gi_patches:' section is found
                if skip:
                    if line.strip() == 'gi_patches:':
                        skip = False
                    continue

                # Stop searching within this section if an empty line is encountered
                if line.strip()=="":
                    skip = True
                    break
                
                # Parse the line as YAML to check its contents
                line_yaml = yaml.safe_load(line.strip())

                # If release or patchnum matches, mark the line as a duplicate
                if line_yaml[0]['release'].strip() == patch['release'].strip():
                    print(f"GI patch with release '{release}' already exists at line {idx}.\n\n")
                    duplicate_indices.append(idx)
                if line_yaml[0]['patchnum'].strip() == patch['patchnum'].strip():
                    print(f"GI patch with patchnum '{patchnum}' already exists at line {idx}.\n\n")
                    duplicate_indices.append(idx)
                    
        # Remove the identified duplicate lines
        patch_delete_duplicates(set(duplicate_indices), output_yml)

def gi_patches_insert_patch(gi_patches, output_yml):
    """
    Inserts GI patches into the output YAML file, grouped by category and base.

    Args:
        gi_patches (list): A list of GI patch data.
        output_yml (str): The path to the output YAML file.
    """
    with open(output_yml, 'r') as file:
        lines = file.readlines()
    gi_patch_start = None
    
    # Find the start and end of the gi_patches block
    for idx, line in enumerate(lines):
        if line.strip() == 'gi_patches:':
            gi_patch_start = idx + 1
        
        if gi_patch_start is not None and line.strip() == "":
            gi_patch_end = idx + 2
            break

    category_match_found = False
    category_base_match_found = False
    idx = gi_patch_start

    for patch in gi_patches:
        while idx < gi_patch_end:
            if category_base_match_found is False and lines[idx].strip() == "":
                print("Error: Empty line found in gi_patches block.\n\n")
                return

            if lines[idx].startswith('# -'):
                idx += 1
                continue

            if idx == gi_patch_end:
                print("Error: Reached end of gi_patches block without finding a match.\n\n")
                return
            
            # Parse the line as YAML to inspect its properties
            line = yaml.safe_load(lines[idx])

            # Check for matching category
            if line != None and line[0]['category'] == patch['category'].strip():
                category_match_found = True

            # If category matches, check for matching base
            if line != None and category_match_found and line[0]['base'] == patch['base'].strip():
                category_base_match_found = True
            
            # If both category and base match, find the insertion point (end of the sub-group)
            if category_base_match_found and lines[idx].strip() == "" or category_base_match_found and lines[idx].startswith('#') or category_base_match_found and lines[idx].strip() == "":
                # Insert the new patch at the current index
                lines.insert(idx, "  - {{ category: \"{category}\", base: \"{base}\", release: \"{release}\", patchnum: \"{patchnum}\", patchfile: \"{patchfile}\", patch_subdir: \"{patch_subdir}\", prereq_check: {prereq_check}, method: \"{method}\", ocm: {ocm}, upgrade: {upgrade}, md5sum: \"{md5sum}\" }}\n".format(
                        category=patch['category'].strip(),
                        base=patch['base'].strip(),
                        release=patch['release'].strip(),
                        patchnum=patch['patchnum'].strip(),
                        patchfile=patch['patchfile'].strip(),
                        patch_subdir=patch['patch_subdir'].strip(),
                        prereq_check=str(patch['prereq_check']).lower(),
                        method=patch['method'].strip(),
                        ocm=str(patch['ocm']).lower(),
                        upgrade=str(patch['upgrade']).lower(),
                        md5sum=patch['md5sum'].strip(),
                    ))
                print("Inserted GI patch at line {0}.\n\n".format(idx + 1))
                # Reset flags and index for the next patch
                category_match_found = False
                category_base_match_found = False
                idx = gi_patch_start
                break

            idx += 1
            if idx == gi_patch_end:
                print("Error: Reached end of gi_patches block without finding a match.\n\n")
                return

        # Write the updated lines back to the file
        with open(output_yml, 'w') as file:
            file.writelines(lines)
    print("GI patches patch inserted successfully.\n\n")

def rdbms_patch_search_duplicates(rdbms_patches, output_yml):
    """
    Searches for and removes duplicate RDBMS patches in the output YAML file.

    Args:
        rdbms_patches (list): A list of RDBMS patch data.
        output_yml (str): The path to the output YAML file.
    """
    for patch in rdbms_patches:
        release = patch['release'].strip()
        patchnum = patch['patchnum'].strip()
        duplicate_indices = []
        skip = True

        with open(output_yml, 'r') as file:
            lines = file.readlines()
            for idx, line in enumerate(lines):
                # Ignore commented lines
                if line.strip().startswith('#'):
                    continue

                # Skip lines until the 'rdbms_patches:' section is found
                if skip:
                    if line.strip() == 'rdbms_patches:':
                        skip = False
                    continue

                # Stop searching within this section if an empty line is encountered
                if line.strip()=="":
                    skip = True
                    break
                
                # Parse the line as YAML to check its contents
                line_yaml = yaml.safe_load(line.strip())

                # If category and release/patchnum match, mark the line as a duplicate
                if line_yaml[0]['category'].strip() == patch['category'] and line_yaml[0]['release'].strip() == patch['release'].strip() or line_yaml[0]['category'].strip() == patch['category'] and line_yaml[0]['patchnum'].strip() == patch['patchnum'].strip():
                    print(f"RDBMS patch with release '{release}' already exists at line {idx}.\n\n")
                    duplicate_indices.append(idx)
                if line_yaml[0]['patchnum'].strip() == patch['patchnum'].strip():
                    print(f"RDBMS patch with patchnum '{patchnum}' already exists at line {idx}.\n\n")
                    duplicate_indices.append(idx)
                    
        # Remove the identified duplicate lines
        patch_delete_duplicates(set(duplicate_indices), output_yml)

def rdbms_patches_insert_patch(rdbms_patches, output_yml):
    """
    Inserts RDBMS patches into the output YAML file, grouped by category and base.

    Args:
        rdbms_patches (list): A list of RDBMS patch data.
        output_yml (str): The path to the output YAML file.
    """
    with open(output_yml, 'r') as file:
        lines = file.readlines()
    rdbms_patch_start = None
    rdbms_patch_end = None
    
    # Find the start and end of the rdbms_patches block
    for idx, line in enumerate(lines):
        if line.strip() == 'rdbms_patches:':
            rdbms_patch_start = idx + 1
        
        if rdbms_patch_start is not None and line.strip() == "":
            rdbms_patch_end = idx + 2
            break

        if idx == len(lines) - 1 and rdbms_patch_start is not None:
            # If we reach the end of the file, the block ends here
            rdbms_patch_end = idx + 1

    if rdbms_patch_start is None or rdbms_patch_end is None:
        print("Error: 'rdbms_patches:' not found in the file or no empty line after it.\n\n")
        sys.exit(1)

    category_match_found = False
    category_base_match_found = False
    idx = rdbms_patch_start

    for patch in rdbms_patches:
        while idx <= rdbms_patch_end:
            # If we found the right group and reached its end, insert the new patch
            if category_base_match_found and idx == rdbms_patch_end or category_base_match_found and lines[idx].strip() == "" or idx==rdbms_patch_end:
                # Insert the new patch at the current index
                lines.insert(idx, "  - {{ category: \"{category}\", base: \"{base}\", release: \"{release}\", patchnum: \"{patchnum}\", patchfile: \"{patchfile}\", patch_subdir: \"{patch_subdir}\", prereq_check: {prereq_check}, method: \"{method}\", ocm: {ocm}, upgrade: {upgrade}, md5sum: \"{md5sum}\" }}\n".format(
                        category=patch['category'].strip(),
                        base=patch['base'].strip(),
                        release=patch['release'].strip(),
                        patchnum=patch['patchnum'].strip(),
                        patchfile=patch['patchfile'].strip(),
                        patch_subdir=patch['patch_subdir'].strip(),
                        prereq_check=str(patch['prereq_check']).lower(),
                        method=patch['method'].strip(),
                        ocm=str(patch['ocm']).lower(),
                        upgrade=str(patch['upgrade']).lower(),
                        md5sum=patch['md5sum'].strip(),
                    ))
                print("Inserted RDBMS patch at line {0}.\n\n".format(idx + 1))
                # Reset flags and index for the next patch
                category_match_found = False
                category_base_match_found = False
                idx = rdbms_patch_start
                rdbms_patch_end += 1 # Adjust end index because we added a line
                break

            if category_base_match_found is False and lines[idx].strip() == "":
                print("Error: Empty line found in rdbms_patches block.\n\n")
                return

            if lines[idx].startswith('# -'):
                idx += 1
                continue

            if idx == rdbms_patch_end:
                print("Error: Reached end of rdbms_patches block without finding a match.\n\n")
                return
            
            # Parse the line as YAML to inspect its properties
            line = yaml.safe_load(lines[idx])

            # Check for matching category
            if line != None and line[0]['category'] == patch['category'].strip():
                category_match_found = True

            # If category matches, check for matching base
            if line != None and category_match_found and line[0]['base'] == patch['base'].strip():
                category_base_match_found = True
            
            idx += 1

        # Write the updated lines back to the file
        with open(output_yml, 'w') as file:
            file.writelines(lines)
    print("RDBMS patches patch inserted successfully.\n\n")

def comment_after_completed_patch(input_yml):
    """
    Comments out all lines in the input YAML file to prevent re-processing.

    Args:
        input_yml (str): The path to the input YAML file.
    """
    with open(input_yml, 'r') as file:
        lines = file.readlines()

    # Iterate through lines and comment them out, skipping section headers and empty lines
    for i, line in enumerate(lines):
        if line.strip() == 'gi_software:' or line.strip() == 'gi_interim_patches:' or line.strip() == 'rdbms_software:' or line.strip() == 'opatch_patches:' or line.strip() == 'gi_patches:' or line.strip() == 'rdbms_patches:' or line.strip() == 'documentation_overrides:' or line.strip().startswith("skip_docs_update") or line.strip() == '':
            continue
        if line.strip().startswith('#'):
            continue
        else:
            lines[i] = "# " + lines[i]
    # Write the commented lines back to the file
    with open(input_yml, 'w') as file:
        file.writelines(lines)
    print("Comment added after completed patches.\n\n")

def main():
    """
    Main function to orchestrate the patch modification process.
    """
    # Define file paths relative to the script location
    dir_path = pathlib.Path(__file__).parent.parent.parent
    input_yml = os.path.join(dir_path, 'modify_patchlist.yaml')
    output_yml = os.path.join(dir_path, 'roles/common/defaults/main.yml')
    
    # Load the patch data from the input file
    patch_data = load_yaml(input_yml)

    # Validate the output YAML file
    try:
        yaml.safe_load(open(output_yml, 'r'))
    except yaml.YAMLError as exc:
        print(f"Error parsing YAML file: {exc}\n\n")
        sys.exit(1)

    if patch_data is None:
        print("No patch data found in the YAML file.\n\n")
        sys.exit(1)
    
    # Process GI software patches if they exist
    try: 
        if patch_data.get('gi_software') is not None:
            gi_software_search_duplicates(patch_data['gi_software'], output_yml)
            gi_software_insert_patch(gi_software_compile_patch(patch_data['gi_software']), output_yml)
    except KeyError:
        print("No 'gi_software' key found in the YAML file. Skipping GI software patch insertion.\n\n")

    # Process GI interim patches if they exist
    try:
        if patch_data.get('gi_interim_patches') is not None:
            gi_interim_search_duplicates(patch_data['gi_interim_patches'], output_yml)
            gi_interim_insert_patch(gi_interim_compile_patch(patch_data['gi_interim_patches']), output_yml)    
    except KeyError:
        print("No 'gi_interim_patches' key found in the YAML file. Skipping GI interim patches patch insertion.\n\n")

    # Process RDBMS software patches if they exist
    try:    
        if patch_data.get('rdbms_software') is not None:
            rdbms_software_search_duplicates(patch_data['rdbms_software'], output_yml)
            rdbms_software_insert_patch(rdbms_software_compile_patch(patch_data['rdbms_software']),output_yml)
    except KeyError:
        print("No 'rdbms_software' key found in the YAML file. Skipping RDBMS software patch insertion.\n\n")

    # Process OPatch patches if they exist
    try:
        if patch_data.get('opatch_patches') is not None:
            opatch_patch_search_duplicates(patch_data['opatch_patches'], output_yml)
            opatch_patch_insert_patch(opatch_patch_compile_patch(patch_data['opatch_patches']),output_yml)
    except KeyError:
        print("No 'opatch_patches' key found in the YAML file. Skipping OPatch patches patch insertion.\n\n")

    # Process GI patches if they exist
    try:
        if patch_data.get('gi_patches') is not None:
            gi_patch_search_duplicates(patch_data['gi_patches'], output_yml)
            gi_patches_insert_patch(patch_data['gi_patches'], output_yml)
    except KeyError:
        print("No 'gi_patches' key found in the YAML file. Skipping GI patches patch insertion.\n\n")

    # Process RDBMS patches if they exist
    try:
        if patch_data.get('rdbms_patches') is not None:
            rdbms_patch_search_duplicates(patch_data['rdbms_patches'], output_yml)
            rdbms_patches_insert_patch(patch_data['rdbms_patches'], output_yml)
    except KeyError:
        print("No 'rdbms_patches' key found in the YAML file. Skipping RDBMS patches patch insertion.\n\n")

    # Comment out the input file to prevent re-running
    comment_after_completed_patch(input_yml)
    
if __name__ == "__main__":
    main()



