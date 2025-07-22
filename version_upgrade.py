import yaml
import sys
import re
from pprint import pprint

def load_yaml(file_path):
    try:
        with open(file_path, 'r') as file:
            version_data = yaml.safe_load(file)
        print("YAML Version Data loaded successfully.\n\n")
        return version_data
    except FileNotFoundError:
        print(f"Error: '{file_path}' not found.\n\n")
        sys.exit(1)
    except yaml.YAMLError as exc:
        print(f"Error parsing YAML file: {exc}\n\n")
        sys.exit(1)

def check_rdbms_exists(rdbms_software, tf_yml):
    for item in rdbms_software:
        name = item['name'].strip()
        version = item['version'].strip()
        files = [f['name'].strip() for f in item['files']]
        with open(tf_yml, 'r') as file:
            lines = file.readlines()
            for idx, line in enumerate(lines, 1):
                name_match = re.match(r'^\s*-\s*name\s*:\s*(.+)$', line)
                version_match = re.match(r'^\s*version\s*:\s*(.+)$', line)

                if name_match and name_match.group(1).strip() == name:
                    print(f"RDBMS software '{name}' already exists at line {idx}.\n\n")
                    remove_existing_rdbms(idx, tf_yml)
                    break
                if version_match and version_match.group(1).strip() == version:
                    print(f"RDBMS software version '{version}' already exists at line {idx}.\n\n")
                    remove_existing_rdbms(idx, tf_yml)
                    break

def remove_existing_rdbms(match_line, tf_yml):
    with open(tf_yml, 'r') as file:
        lines = file.readlines()
    
    # Find beginning of rdbms_software block
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

    print(f"Removing rdbms_software block from line {start} to {end}.\n\n")
    
    if start is None or end is None:
        print("Error: Could not find the start or end of the rdbms_software block.\n\n")
        return
    
    # Remove the block
    del lines[start:end]    
    with open(tf_yml, 'w') as file:
        file.writelines(lines)

def format_rdbms_software_block(rdbms_software):
    block_list = []
    for item in rdbms_software:
        name = item['name'].strip()
        version = item['version'].strip()
        edition = item['edition']
        files = item['files']

        if isinstance(edition, list):
            block = f"  - name: {name}\n    version: {version}\n    editions:\n"
            block += "\n".join([f"      - {e.strip()}" for e in edition])
            block += "\n    files:"
        else:
            block = f"  - name: {name}\n    version: {version}\n    editions: {edition.strip()}\n    files:"

        for file in files:
            block += f"\n      - {{ name: \"{file['name'].strip()}\", sha256sum: \"{file['sha256sum'].strip()}\", md5sum: \"{file['md5sum'].strip()}\" }}"
        block_list.append("\n".join(block.splitlines()))
    return block_list

def insert_rdbms_software_block(tf_yml, rdbms_software_blocks):
    tf_yml = open(tf_yml, 'r')
    lines = tf_yml.readlines()
    

    for i, line in enumerate(lines):
        if line.strip() == 'rdbms_software:':
            for rdbms_software_block in rdbms_software_blocks:
                # Insert the block after the 'rdbms_software:' line
                lines.insert(i + 1, rdbms_software_block + "\n")
            break
    else:
        print("Error: 'rdbms_software:' not found in the file.\n\n")
        sys.exit(1)

    with open('./roles/common/defaults/main.yml', 'w') as file:
        file.writelines(lines)
    print("RDBMS software block inserted successfully.\n\n")

def format_opatch_patches_block(opatch_patches):
    block_list = []
    for patch in opatch_patches:
        block = ""
        block += (
            f"  - {{ category: \"{patch['category'].strip()}\", "
            f"release: \"{patch['release'].strip()}\", "
            f"patchnum: \"{patch['patchnum'].strip()}\", "
            f"patchfile: \"{patch['patchfile'].strip()}\", "
            f"md5sum: \"{patch['md5sum'].strip()}\" }}\n"
        )
        block_list.append(block)
    return block_list

def check_opatch_patches_exists(opatch_patches, tf_yml):
    for patch in opatch_patches:
        release = patch['release'].strip()
        patchnum = patch['patchnum'].strip()
        with open(tf_yml, 'r') as file:
            lines = file.readlines()
            for idx, line in enumerate(lines, 1):
                release_match = re.search(r'release\s*:\s*"?([^",}]+)"?', line)
                patchnum_match = re.search(r'patchnum\s*:\s*"?([^",}]+)"?', line)

                if release_match and release_match.group(1).strip() == release:
                    print(f"OPatch patch with release '{release}' already exists at line {idx}.\n\n")
                    remove_existing_opatch_patches(idx, tf_yml)
                    break

def remove_existing_opatch_patches(match_line, tf_yml):
    with open(tf_yml, 'r') as file:
        lines = file.readlines()
    
    del lines[match_line]    
    with open(tf_yml, 'w') as file:
        file.writelines(lines)  

def insert_opatch_patches_block(tf_yml, opatch_patches_block):
    tf_yml = open(tf_yml, 'r')
    lines = tf_yml.readlines()
    for i, line in enumerate(lines):
        if line.strip() == 'opatch_patches:':
            for opatch_patches_block in opatch_patches_block:
                # Insert the block after the 'opatch_patches:' line
                lines.insert(i + 1, opatch_patches_block)
            break
    else:
        print("Error: 'opatch_patches:' not found in the file.\n\n")
        sys.exit(1)

    with open('./roles/common/defaults/main.yml', 'w') as file:
        file.writelines(lines)
    print("OPatch patches block inserted successfully.\n\n")

def main():
    version_data = load_yaml('version_upgrade.yaml')
    #check_rdbms_exists(version_data['rdbms_software'], './roles/common/defaults/main.yml')

    #insert_rdbms_software_block('./roles/common/defaults/main.yml', format_rdbms_software_block(version_data['rdbms_software']))

    check_opatch_patches_exists(version_data['opatch_patches'], './roles/common/defaults/main.yml')

    insert_opatch_patches_block('./roles/common/defaults/main.yml', format_opatch_patches_block(version_data['opatch_patches']))

if __name__ == "__main__":
    main()


