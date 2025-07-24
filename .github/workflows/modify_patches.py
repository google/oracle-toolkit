import yaml
import sys, os
import re
import pathlib


def load_yaml(file_path):
    try:
        with open(file_path, 'r') as file:
            patch_data = yaml.safe_load(file)
        print("YAML Version Data loaded successfully.\n\n")
        return patch_data
    except FileNotFoundError:
        print(f"Error: '{file_path}' not found.\n\n")
        sys.exit(1)
    except yaml.YAMLError as exc:
        print(f"Error parsing YAML file: {exc}\n\n")
        sys.exit(1)

def software_delete_duplicates(match_lines, output_yml):
    if not match_lines:
        return
    with open(output_yml, 'r') as file:
        lines = file.readlines()

    # For each match_line, find the start and end of the patch, then remove
    # Remove in reverse order to avoid index shifting
    removed_ranges = []
    for match_line in sorted(set(match_lines), reverse=True):
        # Find beginning of gi_software patch
        start = None
        for find_range in range(0, 10):
            idx = match_line - find_range
            if idx < 0:
                break
            if re.match(r'^  - name:', lines[idx]):
                start = idx
                break

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

    # Remove all ranges in reverse order
    for start, end in sorted(removed_ranges, reverse=True):
        del lines[start:end]

    with open(output_yml, 'w') as file:
        file.writelines(lines)

def patch_delete_duplicates(match_lines, output_yml):
    if not match_lines:
        return
    with open(output_yml, 'r') as file:
        lines = file.readlines()

    # For each match_line, find the start and end of the patch, then remove
    # Remove in reverse order to avoid index shifting
    removed_ranges = []
    for match_line in sorted(set(match_lines), reverse=True):
        del lines[match_line]

    with open(output_yml, 'w') as file:
        file.writelines(lines)

def gi_software_search_duplicates(gi_software, output_yml):
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

            if skip:
                if line.strip() == 'gi_software:':
                    skip = False
                continue

            if line.strip() == "":
                break

            if name_match and name_match.group(1).strip() == name:
                print(f"GI software '{name}' already exists at line {idx+1}.\n\n")
                duplicate_indices.append(idx)
                skip_next_line = True
            elif version_match and version_match.group(1).strip() == version:
                print(f"GI software version '{version}' already exists at line {idx+1}.\n\n")
                duplicate_indices.append(idx)
    # Remove duplicates in reverse order to avoid index shifting
    software_delete_duplicates(duplicate_indices, output_yml)

def gi_software_compile_patch(gi_software):
    patches_list = []
    for each_patch in gi_software:
        name = each_patch['name'].strip()
        version = each_patch['version'].strip()
        files = each_patch['files']


        patch = "  - name: {name}\n    version: {version}\n    files:\n".format(
            name=name, 
            version=version
        )

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
    patches_list.reverse() #Reverse the list to maintain order
    return patches_list

def gi_software_insert_patch(gi_software_patches, output_yml):
    read_yml = open(output_yml, 'r')
    lines = read_yml.readlines()
    
    for i, line in enumerate(lines):
        if line.strip() == 'gi_software:':
            for gi_software_patch in gi_software_patches:
                # Insert the patch after the 'gi_software:' line
                lines.insert(i + 1, gi_software_patch + "\n")
            break
    else:
        print("Error: 'gi_software:' not found in the file.\n\n")
        sys.exit(1)

    with open(output_yml, 'w') as file:
        file.writelines(lines)
    print("GI software patch inserted successfully.\n\n")

def gi_interim_search_duplicates(gi_interim_patches, output_yml):
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


            # Match lines for gi_interim_patches name and version
            version_match = re.match(r'^\s*version\s*:\s*(.+)$', line)
            patchnum_match = re.match(r'^\s*patchnum\s*:\s*"?([^"\n]+)"?$', line) 

            if skip:
                if line.strip() == 'gi_interim_patches:':
                    skip = False
                continue

            if line.strip() == "":
                break

            if version_match and version_match.group(1).strip() == version:
                print(f"GI interim patch version '{version}' already exists at line {idx+1}.\n\n")
                duplicate_indices.append(idx)
                skip_next_line = True
                continue

            if patchnum_match and patchnum_match.group(1).strip() == patchnum:
                print(f"GI interim patch '{patchnum}' already exists at line {idx+1}.\n\n")
                duplicate_indices.append(idx)

    # Remove duplicates in reverse order to avoid index shifting
    gi_interim_delete_duplicates(duplicate_indices, output_yml)

def gi_interim_delete_duplicates(match_lines, output_yml):
    if not match_lines:
        return
    with open(output_yml, 'r') as file:
        lines = file.readlines()

    # For each match_line, find the start and end of the patch, then remove
    # Remove in reverse order to avoid index shifting
    removed_ranges = []
    for match_line in sorted(set(match_lines), reverse=True):
        # Find beginning of gi_interim_patches patch
        start = None
        for find_range in range(0, 10):
            idx = match_line - find_range
            if idx < 0:
                break
            if re.match(r'^  - category:', lines[idx]):
                start = idx
                break

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

    # Remove all ranges in reverse order
    for start, end in sorted(removed_ranges, reverse=True):
        del lines[start:end]

    with open(output_yml, 'w') as file:
        file.writelines(lines)

def gi_interim_compile_patch(gi_interim_patches):
    patches_list = []
    for each_patch in gi_interim_patches:
        category = each_patch['category'].strip()
        version = each_patch['version'].strip()
        patchnum = each_patch['patchnum'].strip()
        patchutil = each_patch['patchutil'].strip()
        files = each_patch['files']

        patch = "  - category: \"{0}\"\n    version: {1}\n    patchnum: \"{2}\"\n    patchutil: \"{3}\"\n    files:\n".format(
            category, version, patchnum, patchutil
        )

        for file in files:
            patch += "      - {{ name: \"{0}\", sha256sum: \"{1}\", md5sum: \"{2}\" }}\n".format(
                file['name'].strip(),
                file['sha256sum'].strip(),
                file['md5sum'].strip()
            )
        patches_list.append("\n".join(patch.splitlines()))

    return patches_list

def gi_interim_insert_patch(gi_interim_patches, output_yml):
    read_yml = open(output_yml, 'r')
    lines = read_yml.readlines()
    gi_interim_start = False
    for i, line in enumerate(lines):
        if line.strip() == 'gi_interim_patches:':
            gi_interim_start = True
            
        if gi_interim_start:
            # Insert the patch after the 'gi_interim_patches:' line
            if line.strip() == "":
                for gi_interim_patch in gi_interim_patches:
                    # Insert the patch after the 'gi_interim_patches:' line
                    lines.insert(i, gi_interim_patch + "\n")
                break

    with open(output_yml, 'w') as file:
        file.writelines(lines)
    print("GI interim patches patch inserted successfully.\n\n")

def rdbms_software_search_duplicates(rdbms_software, output_yml):
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

            if skip:
                if line.strip() == 'rdbms_software:':
                    skip = False
                continue

            if line.strip() == "":
                break

            if name_match and name_match.group(1).strip() == name:
                print(f"GI software '{name}' already exists at line {idx+1}.\n\n")
                duplicate_indices.append(idx)
                skip_next_line = True
            elif version_match and version_match.group(1).strip() == version:
                print(f"GI software version '{version}' already exists at line {idx+1}.\n\n")
                duplicate_indices.append(idx)

    # Remove duplicates in reverse order to avoid index shifting
    software_delete_duplicates(duplicate_indices, output_yml)

def rdbms_software_compile_patch(rdbms_software):
    patches_list = []
    for each_patch in rdbms_software:
        name = each_patch['name'].strip()
        version = each_patch['version'].strip()
        edition = each_patch['edition']
        files = each_patch['files']

        if isinstance(edition, list):
            patch = "  - name: {0}\n    version: {1}\n    editions:\n".format(name, version)
            patch += "\n".join(["      - {0}".format(e.strip()) for e in edition])
            patch += "\n    files:"
        else:
            patch = "  - name: {0}\n    version: {1}\n    editions: {2}\n    files:".format(name, version, edition.strip())

        for file in files:
            patch += "\n      - {{ name: \"{0}\", sha256sum: \"{1}\", md5sum: \"{2}\" }}".format(
                file['name'].strip(),
                file['sha256sum'].strip(),
                file['md5sum'].strip()
            )
        patches_list.append("\n".join(patch.splitlines()))
    return patches_list

def rdbms_software_insert_patch(rdbms_software_patches, output_yml):
    read_yml = open(output_yml, 'r')
    lines = read_yml.readlines()
    

    for i, line in enumerate(lines):
        if line.strip() == 'rdbms_software:':
            for rdbms_software_patch in rdbms_software_patches:
                # Insert the patch after the 'rdbms_software:' line
                lines.insert(i + 1, rdbms_software_patch + "\n")
            break
    else:
        print("Error: 'rdbms_software:' not found in the file.\n\n")
        sys.exit(1)

    with open(output_yml, 'w') as file:
        file.writelines(lines)
    print("RDBMS software patch inserted successfully.\n\n")

def opatch_patch_search_duplicates(opatch_patches, output_yml):
    for patch in opatch_patches:
        release = patch['release'].strip()
        patchnum = patch['patchnum'].strip()
        duplicate_indices = []
        skip = True

        with open(output_yml, 'r') as file:
            lines = file.readlines()
            for idx, line in enumerate(lines):
                release_match = re.search(r'release\s*:\s*"?([^",}]+)"?', line)

                if idx==0:
                    skip = True
                    continue

                if skip:
                    if line.strip() == 'opatch_patches:':
                        skip = False
                    continue

                if line.strip()=="":
                    break

                if release_match and release_match.group(1).strip() == release:
                    print(f"OPatch patch with release '{release}' already exists at line {idx}.\n\n")
                    duplicate_indices.append(idx)
                    continue

        patch_delete_duplicates(duplicate_indices, output_yml)

def opatch_patch_compile_patch(opatch_patches):
    patches_list = []
    for patches in opatch_patches:
        patches_list.append("  - {{ category: \"OPatch\", release: \"{0}\", patchnum: \"{1}\", patchfile: \"{2}\", md5sum: \"{3}\" }}\n".format(
            patches['release'].strip(),
            patches['patchnum'].strip(),
            patches['patchfile'].strip(),
            patches['md5sum'].strip()
            )
        )
    return patches_list

def opatch_patch_insert_patch(opatch_patches_patch, output_yml):
    with open(output_yml, 'r') as file:
        lines = file.readlines()

    opatch_start = None
    opatch_end = None

    # Find the start of the opatch_patches patch
    for i, line in enumerate(lines):
        if line.strip() == 'opatch_patches:':
            opatch_start = i
            break

    if opatch_start is None:
        print("Error: 'opatch_patches:' not found in the file.\n\n")
        sys.exit(1)

    # Find the end of the opatch_patches patch
    for j in range(opatch_start + 1, len(lines)):
        if re.match(r'^\S', lines[j]) and not lines[j].strip().startswith('-'):
            opatch_end = j-1
            break
    if opatch_end is None:
        opatch_end = len(lines)

    # Insert at the end of the opatch_patches patch
    insert_pos = opatch_end
    for patch in opatch_patches_patch:
        lines.insert(insert_pos, patch)
        insert_pos += 1

    with open(output_yml, 'w') as file:
        file.writelines(lines)
    print("OPatch patches patch appended successfully.\n\n")

def gi_patch_search_duplicates(gi_patches, output_yml):
    for patch in gi_patches:
        release = patch['release'].strip()
        patchnum = patch['patchnum'].strip()
        duplicate_indices = []
        skip = True

        with open(output_yml, 'r') as file:
            lines = file.readlines()
            for idx, line in enumerate(lines):
                if line.strip().startswith('#'):
                    continue

                if skip:
                    if line.strip() == 'gi_patches:':
                        skip = False
                    continue

                if line.strip()=="":
                    skip = True
                    break
                
                line_yaml = yaml.safe_load(line.strip())

                if line_yaml[0]['release'].strip() == patch['release'].strip():
                    print(f"GI patch with release '{release}' already exists at line {idx}.\n\n")
                    duplicate_indices.append(idx)
                if line_yaml[0]['patchnum'].strip() == patch['patchnum'].strip():
                    print(f"GI patch with patchnum '{patchnum}' already exists at line {idx}.\n\n")
                    duplicate_indices.append(idx)
                    
        patch_delete_duplicates(set(duplicate_indices), output_yml)

def gi_patches_insert_patch(gi_patches, output_yml):
    with open(output_yml, 'r') as file:
        lines = file.readlines()
    gi_patch_start = None
    
    for idx, line in enumerate(lines):
        if line.strip() == 'gi_patches:':
            gi_patch_start = idx + 1
        
        if gi_patch_start is not None and line.strip() == "":
            # Insert the patch after the 'gi_patches:' line
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
            
            line = yaml.safe_load(lines[idx])

            if line != None and line[0]['category'] == patch['category'].strip():
                category_match_found = True

            if line != None and category_match_found and line[0]['base'] == patch['base'].strip():
                category_base_match_found = True
            
            if category_base_match_found and lines[idx].strip() == "" or category_base_match_found and lines[idx].startswith('#') or category_base_match_found and lines[idx].strip() == "":
                # Insert the patch at the current index
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
                category_match_found = False
                category_base_match_found = False
                idx = gi_patch_start
                break

            idx += 1
            if idx == gi_patch_end:
                print("Error: Reached end of gi_patches block without finding a match.\n\n")
                return

        with open(output_yml, 'w') as file:
            file.writelines(lines)
    print("GI patches patch inserted successfully.\n\n")

def rdbms_patch_search_duplicates(rdbms_patches, output_yml):
    for patch in rdbms_patches:
        release = patch['release'].strip()
        patchnum = patch['patchnum'].strip()
        duplicate_indices = []
        skip = True

        with open(output_yml, 'r') as file:
            lines = file.readlines()
            for idx, line in enumerate(lines):
                if line.strip().startswith('#'):
                    continue

                if skip:
                    if line.strip() == 'rdbms_patches:':
                        skip = False
                    continue

                if line.strip()=="":
                    skip = True
                    break
                
                line_yaml = yaml.safe_load(line.strip())

                if line_yaml[0]['category'].strip() == patch['category'] and line_yaml[0]['release'].strip() == patch['release'].strip() or line_yaml[0]['category'].strip() == patch['category'] and line_yaml[0]['patchnum'].strip() == patch['patchnum'].strip():
                    print(f"RDBMS patch with release '{release}' already exists at line {idx}.\n\n")
                    duplicate_indices.append(idx)
                if line_yaml[0]['patchnum'].strip() == patch['patchnum'].strip():
                    print(f"RDBMS patch with patchnum '{patchnum}' already exists at line {idx}.\n\n")
                    duplicate_indices.append(idx)
                    
        patch_delete_duplicates(set(duplicate_indices), output_yml)

def rdbms_patches_insert_patch(rdbms_patches, output_yml):
    with open(output_yml, 'r') as file:
        lines = file.readlines()
    rdbms_patch_start = None
    rdbms_patch_end = None
    
    for idx, line in enumerate(lines):
        if line.strip() == 'rdbms_patches:':
            rdbms_patch_start = idx + 1
        
        if rdbms_patch_start is not None and line.strip() == "":
            # Insert the patch after the 'rdbms_patches:' line
            rdbms_patch_end = idx + 2
            break

        if idx == len(lines) - 1 and rdbms_patch_start is not None:
            # If we reach the end of the file without finding an empty line
            rdbms_patch_end = idx + 1

    if rdbms_patch_start is None or rdbms_patch_end is None:
        print("Error: 'rdbms_patches:' not found in the file or no empty line after it.\n\n")
        sys.exit(1)

    category_match_found = False
    category_base_match_found = False
    idx = rdbms_patch_start

    for patch in rdbms_patches:
        while idx < rdbms_patch_end:
            if category_base_match_found is False and lines[idx].strip() == "":
                print("Error: Empty line found in rdbms_patches block.\n\n")
                return

            if lines[idx].startswith('# -'):
                idx += 1
                continue

            if idx == rdbms_patch_end:
                print("Error: Reached end of rdbms_patches block without finding a match.\n\n")
                return
            
            line = yaml.safe_load(lines[idx])

            if line != None and line[0]['category'] == patch['category'].strip():
                category_match_found = True

            if line != None and category_match_found and line[0]['base'] == patch['base'].strip():
                category_base_match_found = True
            
            if category_base_match_found and lines[idx].strip() == "" or category_base_match_found and lines[idx].startswith('#') or category_base_match_found and lines[idx].strip() == "":
                # Insert the patch at the current index
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
                category_match_found = False
                category_base_match_found = False
                idx = rdbms_patch_start
                break

            idx += 1
            if idx == rdbms_patch_end:
                print("Error: Reached end of rdbms_patches block without finding a match.\n\n")
                return

        with open(output_yml, 'w') as file:
            file.writelines(lines)
    print("RDBMS patches patch inserted successfully.\n\n")


def main():
    # # the root of the git repo
    # dir_path = pathlib.Path(__file__).parent.parent.parent

    # input_yml = dir_path / 'version_upgrade.yaml'
    # output_yml = dir_path / 'roles/common/defaults/main.yml'
    # patch_data = load_yaml(input_yml)

    dir_path = pathlib.Path(__file__).parent.parent.parent
    input_yml = os.path.join(dir_path, 'modify_patchlist.yaml')
    output_yml = os.path.join(dir_path, 'roles/common/defaults/main.yml')
    patch_data = load_yaml(input_yml)

    try:
        yaml.safe_load(open(output_yml, 'r'))
    except yaml.YAMLError as exc:
        print(f"Error parsing YAML file: {exc}\n\n")
        sys.exit(1)

    if patch_data is None:
        print("No patch data found in the YAML file.\n\n")
        sys.exit(1)
    
    if patch_data.get('gi_software') is not None:
        gi_software_search_duplicates(patch_data['gi_software'], output_yml)
        gi_software_insert_patch(gi_software_compile_patch(patch_data['gi_software']), output_yml)

    if patch_data.get('gi_interim_patches') is not None:
        gi_interim_search_duplicates(patch_data['gi_interim_patches'], output_yml)
        gi_interim_insert_patch(gi_interim_compile_patch(patch_data['gi_interim_patches']), output_yml)    

    if patch_data.get('rdbms_software') is not None:
        rdbms_software_search_duplicates(patch_data['rdbms_software'], output_yml)
        rdbms_software_insert_patch(rdbms_software_compile_patch(patch_data['rdbms_software']),output_yml)

    if patch_data.get('opatch_patches') is not None:
        opatch_patch_search_duplicates(patch_data['opatch_patches'], output_yml)
        opatch_patch_insert_patch(opatch_patch_compile_patch(patch_data['opatch_patches']),output_yml)

    if patch_data.get('gi_patches') is not None:
        gi_patch_search_duplicates(patch_data['gi_patches'], output_yml)
        gi_patches_insert_patch(patch_data['gi_patches'], output_yml)

    if patch_data.get('rdbms_patches') is not None:
        rdbms_patch_search_duplicates(patch_data['rdbms_patches'], output_yml)
        rdbms_patches_insert_patch(patch_data['rdbms_patches'], output_yml)

if __name__ == "__main__":
    main()


