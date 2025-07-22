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

def rdbms_software_search_duplicates(rdbms_software, output_yml):
    for item in rdbms_software:
        name = item['name'].strip()
        version = item['version'].strip()
        files = [f['name'].strip() for f in item['files']]
        with open(output_yml, 'r') as file:
            lines = file.readlines()
            for idx, line in enumerate(lines, 1):
                name_match = re.match(r'^\s*-\s*name\s*:\s*(.+)$', line)
                version_match = re.match(r'^\s*version\s*:\s*(.+)$', line)

                if line.strip()=="":
                    break
                    
                if name_match and name_match.group(1).strip() == name:
                    print(f"RDBMS software '{name}' already exists at line {idx}.\n\n")
                    rdbms_software_delete_duplicates(idx, output_yml)
                    break
                if version_match and version_match.group(1).strip() == version:
                    print(f"RDBMS software version '{version}' already exists at line {idx}.\n\n")
                    rdbms_software_delete_duplicates(idx, output_yml)
                    break

def rdbms_software_delete_duplicates(match_line, output_yml):
    with open(output_yml, 'r') as file:
        lines = file.readlines()
    
    # Find beginning of rdbms_software patch
    start = None
    for find_range in range(0, 10):
        if re.match(r'^  - name:', lines[match_line - find_range]):
            start = match_line - find_range
            break

    end = None
    for find_range in range(1, 11):
        if re.match(r'^  - name:', lines[match_line + find_range]):
            end = match_line + find_range
            break
    if end is None:
        end = len(lines)

    print(f"Removing rdbms_software patch from line {start} to {end}.\n\n")
    
    if start is None or end is None:
        print("Error: Could not find the start or end of the rdbms_software patch.\n\n")
        return
    
    # Remove the patch
    del lines[start:end]    
    with open(output_yml, 'w') as file:
        file.writelines(lines)

def rdbms_software_compile_patch(rdbms_software):
    patches_list = []
    for item in rdbms_software:
        name = item['name'].strip()
        version = item['version'].strip()
        edition = item['edition']
        files = item['files']

        if isinstance(edition, list):
            patch = f"  - name: {name}\n    version: {version}\n    editions:\n"
            patch += "\n".join([f"      - {e.strip()}" for e in edition])
            patch += "\n    files:"
        else:
            patch = f"  - name: {name}\n    version: {version}\n    editions: {edition.strip()}\n    files:"

        for file in files:
            patch += f"\n      - {{ name: \"{file['name'].strip()}\", sha256sum: \"{file['sha256sum'].strip()}\", md5sum: \"{file['md5sum'].strip()}\" }}"
        patches_list.append("\n".join(patch.splitlines()))
    return patches_list

def rdbms_software_insert_patch(output_yml, rdbms_software_patches):
    output_yml = open(output_yml, 'r')
    lines = output_yml.readlines()
    

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
        with open(output_yml, 'r') as file:
            lines = file.readlines()
            for idx, line in enumerate(lines):
                release_match = re.search(r'release\s*:\s*"?([^",}]+)"?', line)
                patchnum_match = re.search(r'patchnum\s*:\s*"?([^",}]+)"?', line)

                if line.strip()=="":
                    break

                if release_match and release_match.group(1).strip() == release:
                    print(f"OPatch patch with release '{release}' already exists at line {idx}.\n\n")
                    opatch_patch_delete_duplicates(idx, output_yml)
                    continue

def opatch_patch_delete_duplicates(match_line, output_yml):

def opatch_patch_compile_patch(opatch_patches):
    patches_list = []
    for patch in opatch_patches:
        patch = ""
        patch +=  "  - {{ category: \"OPatch\", release: \"{0}\", patchnum: \"{1}\", patchfile: \"{2}\", md5sum: \"{3}\" }}\n".format(
            patch['release'].strip(),
            patch['patchnum'].strip(),
            patch['patchfile'].strip(),
            patch['md5sum'].strip()
        )
        patches_list.append(patch)
    with open(output_yml, 'r') as file:
        lines = file.readlines()
    
    del lines[match_line]    
    with open(output_yml, 'w') as file:
        file.writelines(lines)  
    return patches_list

def opatch_patch_insert_patch(output_yml, opatch_patches_patch):
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
    rdbms_software_search_duplicates(patch_data['rdbms_software'], './roles/common/defaults/main.yml')

    rdbms_software_insert_patch('./roles/common/defaults/main.yml', rdbms_software_compile_patch(patch_data['rdbms_software']))

    opatch_patch_search_duplicates(patch_data['opatch_patches'], './roles/common/defaults/main.yml')

    opatch_patch_insert_patch('./roles/common/defaults/main.yml', opatch_patch_compile_patch(patch_data['opatch_patches']))

if __name__ == "__main__":
    main()


