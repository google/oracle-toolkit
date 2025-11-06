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
        patch = ""
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
        patch += "\n"
        patches_list.append(patch)
    patches_list.reverse() # Reverse the list to maintain the original order when inserting
    return patches_list

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
            patch += ("      - {{ name: \"{0}\", sha256sum: \"{1}\", md5sum: \"{2}\" }}".format(
                    file['name'].strip(),
                    file['sha256sum'].strip(),
                    file['md5sum'].strip()
                )
            )
        patch += "\n"
        patches_list.append(patch)

    patches_list.reverse() # Reverse the list to maintain the original order when inserting
    return patches_list

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
        patch += "\n"
        patches_list.append(patch)
    patches_list.reverse() # Reverse the list to maintain the original order when inserting
    return patches_list

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
    patches_list.reverse() # Reverse the list to maintain the original order when inserting
    return patches_list

def gi_patch_compile_patch(gi_patches):
    """
    Compiles GI patch data into a list of formatted YAML strings.

    Args:
        gi_patches (list): A list of GI patch data.

    Returns:
        list: A list of formatted YAML strings for GI patches.
    """
    patches_list = []
    for patches in gi_patches:
        # Format each patch as a single-line YAML list item
        patch = "  - {{ category: \"{category}\", base: \"{base}\", release: \"{release}\", patchnum: \"{patchnum}\", patchfile: \"{patchfile}\", patch_subdir: \"{patch_subdir}\", prereq_check: {prereq_check}, method: \"{method}\", ocm: {ocm}, upgrade: {upgrade}, md5sum: \"{md5sum}\" }}\n".format(
                category=patches['category'].strip(),
                base=patches['base'].strip(),
                release=patches['release'].strip(),
                patchnum=patches['patchnum'].strip(),
                patchfile=patches['patchfile'].strip(),
                patch_subdir=patches['patch_subdir'].strip(),
                prereq_check=str(patches['prereq_check']).lower(),
                method=patches['method'].strip(),
                ocm=str(patches['ocm']).lower(),
                upgrade=str(patches['upgrade']).lower(),
                md5sum=patches['md5sum'].strip(),
            )
        patches_list.append(patch)
    patches_list.reverse() # Reverse the list to maintain the original order when inserting
    return patches_list

def rdbms_patches_compile_patch(rdbms_patches):
    """
    Compiles RDBMS patch data into a list of formatted YAML strings.

    Args:
        rdbms_patches (list): A list of RDBMS patch data.

    Returns:
        list: A list of formatted YAML strings for RDBMS patches.
    """
    patches_list = []
    for patches in rdbms_patches:
        # Format each patch as a single-line YAML list item
        patches_list.append("  - {{ category: \"{category}\", base: \"{base}\", release: \"{release}\", patchnum: \"{patchnum}\", patchfile: \"{patchfile}\", patch_subdir: \"{patch_subdir}\", prereq_check: {prereq_check}, method: \"{method}\", ocm: {ocm}, upgrade: {upgrade}, md5sum: \"{md5sum}\" }}\n".format(
                category=patches['category'].strip(),
                base=patches['base'].strip(),
                release=patches['release'].strip(),
                patchnum=patches['patchnum'].strip(),
                patchfile=patches['patchfile'].strip(),
                patch_subdir=patches['patch_subdir'].strip(),
                prereq_check=str(patches['prereq_check']).lower(),
                method=patches['method'].strip(),
                ocm=str(patches['ocm']).lower(),
                upgrade=str(patches['upgrade']).lower(),
                md5sum=patches['md5sum'].strip(),
            )
        )
    patches_list.reverse() # Reverse the list to maintain the original order when inserting
    return patches_list

def insert_patches(patches, search_string, output_yml):
    """
    Inserts patches into the output YAML file after a specified search string.

    Args:
        patches (list): A list of formatted YAML strings for patches.
        search_string (str): The string to search for in the output YAML file.
        output_yml (str): The path to the output YAML file.
    """
    with open(output_yml, 'r') as read_yml:
        lines = read_yml.readlines()
        block_found = False
        try:
            for index, line in enumerate(lines):
                if search_string in line:
                    block_found = True
                if block_found and line.strip() == "" or index == len(lines) - 1 and block_found:
                    if index == len(lines) - 1:
                        lines.append("\n")  # Ensure there's a newline at the end if we're at the last line
                        index += 1
                    for each_patch in patches:
                        lines.insert(index, each_patch)
                    break
        except StopIteration:
            # Handle case where the search string is not found
            print(f"Error: '{search_string}' not found in the file.\n\n")
        

    # Write the updated lines back to the file
    with open(output_yml, 'w') as file:
        file.writelines(lines)
    print(f"Patches inserted successfully after '{search_string}'.\n\n")

def main():
    """
    Main function to orchestrate the patch modification process.
    """
    # Define file paths relative to the script location
    dir_path = pathlib.Path(__file__).parent.parent.parent
    input_yml = os.path.join(dir_path, 'modify_patchlist.yml')
    
    # Load the patch data from the input file
    patch_data = load_yaml(input_yml)

    if patch_data is None:
        print("No patch data found in the YAML file.\n\n")
        sys.exit(1)
    
    # Process GI software patches if they exist
    try: 
        if patch_data.get('gi_software') is not None:
            insert_patches(gi_software_compile_patch(patch_data['gi_software']), "gi_software:", os.path.join(dir_path, 'roles/common/defaults/main/gi_software.yml'))
    except KeyError:
        print("No 'gi_software' key found in the YAML file. Skipping GI software patch insertion.\n\n")

    # Process GI interim patches if they exist
    try:
        if patch_data.get('gi_interim_patches') is not None:
            insert_patches(gi_interim_compile_patch(patch_data['gi_interim_patches']), "gi_interim_patches:", os.path.join(dir_path, 'roles/common/defaults/main/other_patches.yml'))    
    except KeyError:
        print("No 'gi_interim_patches' key found in the YAML file. Skipping GI interim patches patch insertion.\n\n")

    # Process RDBMS software patches if they exist
    try:    
        if patch_data.get('rdbms_software') is not None:
            insert_patches(rdbms_software_compile_patch(patch_data['rdbms_software']), "rdbms_software:", os.path.join(dir_path, 'roles/common/defaults/main/rdbms_software.yml'))
    except KeyError:
        print("No 'rdbms_software' key found in the YAML file. Skipping RDBMS software patch insertion.\n\n")

    # Process OPatch patches if they exist
    try:
        if patch_data.get('opatch_patches') is not None:
            insert_patches(opatch_patch_compile_patch(patch_data['opatch_patches']), "opatch_patches:", os.path.join(dir_path, 'roles/common/defaults/main/other_patches.yml'))
    except KeyError:
        print("No 'opatch_patches' key found in the YAML file. Skipping OPatch patches patch insertion.\n\n")

    # Process GI patches if they exist
    try:
        if patch_data.get('gi_patches') is not None:
          insert_patches(gi_patch_compile_patch(patch_data['gi_patches']), "gi_patches:", os.path.join(dir_path, 'roles/common/defaults/main/gi_patches.yml'))
    except KeyError:
        print("No 'gi_patches' key found in the YAML file. Skipping GI patches patch insertion.\n\n")

    # Process RDBMS patches if they exist
    try:
        if patch_data.get('rdbms_patches') is not None:
            insert_patches(rdbms_patches_compile_patch(patch_data['rdbms_patches']), "rdbms_patches:", os.path.join(dir_path, 'roles/common/defaults/main/rdbms_patches.yml'))
    except KeyError:
        print("No 'rdbms_patches' key found in the YAML file. Skipping RDBMS patches patch insertion.\n\n")
    
if __name__ == "__main__":
    main()
