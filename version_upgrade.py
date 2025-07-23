import yaml
import sys
import re
from pprint import pprint

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

def main():
    patch_data = load_yaml('version_upgrade.yaml')
    output_yml = "./roles/common/defaults/main.yml"

    gi_software_search_duplicates(patch_data['gi_software'], output_yml)

    gi_software_insert_patch(gi_software_compile_patch(patch_data['gi_software']), './roles/common/defaults/main.yml')

    rdbms_software_search_duplicates(patch_data['rdbms_software'], output_yml)

    rdbms_software_insert_patch(rdbms_software_compile_patch(patch_data['rdbms_software']),output_yml)

    opatch_patch_search_duplicates(patch_data['opatch_patches'], output_yml)

    opatch_patch_insert_patch(opatch_patch_compile_patch(patch_data['opatch_patches']),output_yml)

if __name__ == "__main__":
    main()


