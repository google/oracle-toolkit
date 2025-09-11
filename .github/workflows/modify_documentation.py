import yaml
import sys, os
import re
import pathlib

def load_yaml(file_path):
    """Loads a YAML file and returns its content."""
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

def load_md(file_path):
    """Loads a Markdown file and returns its content as a list of lines."""
    try:
        # Open and read the Markdown file into a list of lines
        with open(file_path, 'r') as file:
            content = file.readlines()
        print("Markdown file loaded successfully.\n\n")
        return content
    except FileNotFoundError:
        # Handle case where the file does not exist
        print(f"Error: '{file_path}' not found.\n\n")
        sys.exit(1)

def save_md(file_path, content):
    """Saves the given content to a Markdown file."""
    with open(file_path, 'w') as file:
        file.write(content)
    print("Markdown file saved successfully.\n\n")

def gi_software_insert_docs(gi_software, overrides, documentation):
    """Inserts GI software information into the documentation's HTML table."""
    # Iterate over each GI software entry from the YAML data
    for each_patch in gi_software:
        version = each_patch['version']
        file_names = []
        # Collect all file names and alternate names
        for file in each_patch['files']:
            file_names.append(file['name'])
            file_names.append(file['alt_name'])
        
        # Use override values from YAML if they exist, otherwise use defaults
        try:
            if overrides['category'] != "":
                category = overrides['category']
            else:
                category = "Base - eDelivery or OTN"
        except:
            category = "Base - eDelivery or OTN"
        
        try:
            if overrides['software_piece'] != "":
                software_piece = overrides['software_piece']
            else:
                software_piece = "Oracle Database {0} for Linux x86-64".format(version)
        except:
            software_piece = "Oracle Database {0} for Linux x86-64".format(version)
        
        try:
            if overrides['file_name'] != "":
                files = overrides['file_name']
            else:
                files = "{0} or {1}".format(file_names[0], file_names[1])
        except:
            files = "{0} or {1}".format(file_names[0], file_names[1])

        # Format the new HTML table row
        table_row = """<tr>\n<td></td>\n<td>{category}</td>\n<td>{software_piece}</td>\n<td>{files}</td>\n</tr>\n""". format(
            category=category,
            software_piece=software_piece,
            files=files
        )
        table_found = False
        section_found = False
        # Iterate through the documentation lines to find the insertion point
        for idx, line in enumerate(documentation):
            if table_found and section_found:
                try:
                    # Check if the line is a table row with a version
                    if len(line.split(">")) == 3:
                        version_text = line.split(">")[1].split("<")[0]
                        # Check if the text is a valid version number
                        if re.match(r'^[0-9.]+$', version_text):
                            # Insert the new row before an existing row with a lower version number
                            if version_text != version and version_text < version:
                                documentation.insert(idx - 1 , table_row)
                                print("Inserted row: {0} at line {1} in documentation.\n".format(table_row, idx))
                                break
                except IndexError:
                    continue
            # Find the target section header
            if line.strip() == "#### Required Oracle Software - Download Summary":
                section_found = True
            # Find the table within the target section
            if section_found and line.strip() == "<table>":
                table_found = True

    return documentation        

def gi_interim_insert_patch(gi_interim_patches, overrides, documentation):
    """Inserts GI interim patch information into the documentation's HTML table."""
    # Iterate over each GI interim patch entry
    for each_patch in gi_interim_patches:
        version = each_patch['version']
        patchfile = each_patch['files'][0]['name']
        
        # Use override values from YAML if they exist, otherwise use defaults
        try:
            if overrides['category'] != "":
                category = overrides['category']
            else:
                category = ""
        except:
            category = ""
        
        try:
            if overrides['software_piece'] != "":
                software_piece = overrides['software_piece']
            else:
                software_piece = "GI Interim Patch"
        except:
            software_piece = "GI Interim Patch"
        
        try:
            if overrides['file_name'] != "":
                files = overrides['file_name']
            else:
                files = patchfile
        except:
            files = patchfile

        # Format the new HTML table row
        table_row = """<tr>\n<td></td>\n<td>{category}</td>\n<td>{software_piece}</td>\n<td>{files}</td>\n</tr>\n""". format(
            category=category,
            software_piece=software_piece,
            files=files
        )
        table_found = False
        section_found = False
        base_found = False # This variable is declared but not used
        # Iterate through the documentation lines to find the insertion point
        for idx, line in enumerate(documentation):

            if section_found and table_found:
                try:
                    # Check if the line is a table row with a version
                    if len(line.split(">")) == 3:
                        version_text = line.split(">")[1].split("<")[0]
                        # Check if the text is a valid version number
                        if re.match(r'^[0-9.]+$', version_text):
                            # Insert the new row before an existing row with a lower version number
                            if version_text != version and version_text < version:
                                documentation.insert(idx - 1 , table_row)
                                print("Inserted row: {0} at line {1} in documentation.\n".format(table_row, idx))
                                break
                except IndexError:
                    continue
            
            # Find the target section header
            if line.strip() == "#### Required Oracle Software - Download Summary":
                section_found = True
                
            # Find the table body within the target section
            if section_found and line.strip() == "<tbody>":
                table_found = True
            
            # Stop searching once the end of the table body is reached
            if table_found and line.strip() == "</tbody>":
                break 
        
    return documentation

def gi_patches_insert_docs(gi_patches, overrides, documentation):
    """Inserts GI patch information into the documentation's HTML table."""
    # Iterate over each GI patch entry
    for each_patch in gi_patches:
        version = each_patch['release']
        patchfile = each_patch['patchfile']
        
        # Use override values from YAML if they exist, otherwise use defaults
        try:
            if overrides['category'] != "":
                category = overrides['category']
            else:
                category = "Patch - MOS"
        except:
            category = "Patch - MOS"
        
        try:
            if overrides['software_piece'] != "":
                software_piece = overrides['software_piece']
            else:
                software_piece = "GI Release Update {0}".format(version)
        except:
            software_piece = "GI Release Update {0}".format(version)
        
        try:
            if overrides['file_name'] != "":
                files = overrides['file_name']
            else:
                files = patchfile
        except:
            files = patchfile

        # Format the new HTML table row
        table_row = """<tr>\n<td></td>\n<td>{category}</td>\n<td>{software_piece}</td>\n<td>{files}</td>\n</tr>\n""". format(
            category=category,
            software_piece=software_piece,
            files=files
        )
        table_found = False
        section_found = False
        base_found = False # This variable is declared but not used
        # Iterate through the documentation lines to find the insertion point
        for idx, line in enumerate(documentation):

            if section_found and table_found:
                try:
                    # Check if the line is a table row with a version
                    if len(line.split(">")) == 3:
                        version_text = line.split(">")[1].split("<")[0]
                        # Check if the text is a valid version number
                        if re.match(r'^[0-9.]+$', version_text):
                            # Insert the new row before an existing row with a lower version number
                            if version_text != version and version_text < version:
                                documentation.insert(idx - 1 , table_row)
                                print("Inserted row: {0} at line {1} in documentation.\n".format(table_row, idx))
                                break
                except IndexError:
                    continue
            
            # Find the target section header
            if line.strip() == "#### Required Oracle Software - Download Summary":
                section_found = True
                
            # Find the table body within the target section
            if section_found and line.strip() == "<tbody>":
                table_found = True
            
            # Stop searching once the end of the table body is reached
            if table_found and line.strip() == "</tbody>":
                break 
        
    return documentation

def rdbms_software_insert_docs(rdbms_software, overrides, documentation):
    """Inserts RDBMS software information into the documentation's Markdown table."""
    # Iterate over each RDBMS software entry
    for each_patch in rdbms_software:
        # Process only the "FREE" edition
        if each_patch['edition'] != "FREE":
            print("Skipping patch for edition: {0} as it is not FREE edition.\n\n".format(each_patch['edition']))
            break
        name = each_patch['name'].split("_")[0]
        version = each_patch['version']
        # Separate preinstall and software files
        for file in each_patch['files']:
            if "preinstall" in file['name'].split("-"):
                preinstall_file = file['name']
                continue
            else:
                software_file = file['name']
        
        # Format the new Markdown table row
        table_row = "|   {0}   |    {1}    | `{2}`   | `{3}`  |".format(
            name.strip(),
            version.strip(),
            software_file.strip(),
            preinstall_file.strip()
        )

        table_found = False
        # Iterate through the documentation lines to find the insertion point
        for idx, line in enumerate(documentation):
            if table_found:
                # Insert the new row at the first blank line after the table header
                if line.strip() == "":
                    documentation.insert(idx, table_row + "\n")
                    print("Inserted row: {0} at line {1} in documentation.\n".format(table_row, idx))
                    break
            
            # Find the Markdown table header
            if re.match(r'^\s*\|\s*Product', line.strip()):
                table_found = True

    return documentation

def rdbms_patches_insert_docs(rdbms_patches, overrides, documentation):
    """Inserts RDBMS patch information into the documentation's HTML table."""
    # Iterate over each RDBMS patch entry
    for each_patch in rdbms_patches:
        version = each_patch['release']
        patchfile = each_patch['patchfile']
        
        # Use override values from YAML if they exist, otherwise use defaults
        try:
            if overrides['category'] != "":
                category = overrides['category']
            else:
                category = "Patch - MOS"
        except:
            category = "Patch - MOS"
        
        try:
            if overrides['software_piece'] != "":
                software_piece = overrides['software_piece']
            else:
                software_piece = "Database Release Update {0}".format(version)
        except:
            software_piece = "Database Release Update {0}".format(version)
        
        try:
            if overrides['file_name'] != "":
                files = overrides['file_name']
            else:
                files = patchfile
        except:
            files = patchfile

        # Format the new HTML table row
        table_row = """<tr>\n<td></td>\n<td>{category}</td>\n<td>{software_piece}</td>\n<td>{files}</td>\n</tr>\n""". format(
            category=category,
            software_piece=software_piece,
            files=files
        )
        table_found = False
        section_found = False
        base_found = False # This variable is declared but not used
        # Iterate through the documentation lines to find the insertion point
        for idx, line in enumerate(documentation):

            if section_found and table_found:
                try:
                    # Check if the line is a table row with a version
                    if len(line.split(">")) == 3:
                        version_text = line.split(">")[1].split("<")[0]
                        # Check if the text is a valid version number
                        if re.match(r'^[0-9.]+$', version_text):
                            # Insert the new row before an existing row with a lower version number
                            if version_text != version and version_text < version:
                                documentation.insert(idx - 1 , table_row)
                                print("Inserted row: {0} at line {1} in documentation.\n".format(table_row, idx))
                                break
                except IndexError:
                    continue
            
            # Find the target section header
            if line.strip() == "#### Required Oracle Software - Download Summary":
                section_found = True
                
            # Find the table body within the target section
            if section_found and line.strip() == "<tbody>":
                table_found = True
            
            # Stop searching once the end of the table body is reached
            if table_found and line.strip() == "</tbody>":
                break 
        
    return documentation

def opatch_insert_patch(opatch_patches, overrides, documentation):
    """Inserts OPatch information into the documentation's HTML table."""
    # Iterate over each OPatch entry
    for each_patch in opatch_patches:
        version = each_patch['release']
        patchfile = each_patch['patchfile']
        
        # Use override values from YAML if they exist, otherwise use defaults
        try:
            if overrides['category'] != "":
                category = overrides['category']
            else:
                category = ""
        except:
            category = ""
        
        try:
            if overrides['software_piece'] != "":
                software_piece = overrides['software_piece']
            else:
                software_piece = "OPatch Utility"
        except:
            software_piece = "OPatch Utility"
        
        try:
            if overrides['file_name'] != "":
                files = overrides['file_name']
            else:
                files = patchfile
        except:
            files = patchfile

        # Format the new HTML table row
        table_row = """<tr>\n<td></td>\n<td>{category}</td>\n<td>{software_piece}</td>\n<td>{files}</td>\n</tr>\n\n""". format(
            category=category,
            software_piece=software_piece,
            files=files
        )
        table_found = False
        section_found = False
        base_found = False # This variable is declared but not used
        # Iterate through the documentation lines to find the insertion point
        for idx, line in enumerate(documentation):

            if section_found and table_found:
                try:
                    # Check if the line is a table row with a version
                    if len(line.split(">")) == 3:
                        version_text = line.split(">")[1].split("<")[0]
                        # Check if the text is a valid version number
                        if re.match(r'^[0-9.]+$', version_text):
                            # Insert the new row before an existing row with a lower version number
                            if version_text != version and version_text < version:
                                documentation.insert(idx - 1 , table_row)
                                print("Inserted row: {0} at line {1} in documentation.\n".format(table_row, idx))
                                break
                except IndexError:
                    continue
            
            # Find the target section header
            if line.strip() == "#### Required Oracle Software - Download Summary":
                section_found = True
                
            # Find the table body within the target section
            if section_found and line.strip() == "<tbody>":
                table_found = True
            
            # Stop searching once the end of the table body is reached
            if table_found and line.strip() == "</tbody>":
                break 
        
    return documentation

def main():
    """Main function to drive the documentation update process."""
    # Define paths relative to the script's location
    dir_path = pathlib.Path(__file__).parent.parent.parent
    input_yml = os.path.join(dir_path, 'modify_patchlist.yml')
    doc_path = os.path.join(dir_path, 'docs/user-guide.md')
    
    # Load the documentation and the YAML patch data
    documentation = load_md(doc_path)
    patch_data = load_yaml(input_yml)

    # Check if the documentation update should be skipped
    try:
        if bool(patch_data['documentation_overrides']['skip_docs_update']):
            print("Skipping documentation update as per configuration.\n\n")
            sys.exit(0)
    except:
        print("No skip_docs_update key found in documentation_overrides. Proceeding with documentation update.\n\n")

    # Process GI software if present in the YAML
    try:
        if patch_data.get('gi_software') is not None:
            documentation = gi_software_insert_docs(patch_data['gi_software'], patch_data["documentation_overrides"]['gi_software'], documentation)
    except:
        print("No 'gi_software' key found in the YAML file. Skipping GI software patch insertion.\n\n")

    # Process RDBMS software if present in the YAML
    try:
        if patch_data.get('rdbms_software') is not None:
            documentation = rdbms_software_insert_docs(patch_data['rdbms_software'], patch_data["documentation_overrides"]['rdbms_software'], documentation)
    except:
        print("No 'rdbms_software' key found in the YAML file. Skipping RDBMS software patch insertion.\n\n")

    # Process OPatch patches if present in the YAML
    try:
        if patch_data.get('opatch_patches') is not None:
            documentation = opatch_insert_patch(patch_data['opatch_patches'], patch_data["documentation_overrides"]['opatch_patches'], documentation)
    except:
        print("No 'opatch_patches' key found in the YAML file. Skipping OPatch patches insertion.\n\n")

    # Process GI interim patches if present in the YAML
    try:
        if patch_data.get('gi_interim_patches') is not None:
            documentation = gi_interim_insert_patch(patch_data['gi_interim_patches'], patch_data["documentation_overrides"]['gi_interim_patches'], documentation)
    except:
        print("No 'gi_interim_patches' key found in the YAML file. Skipping GI interim patches insertion.\n\n")

    # Process RDBMS patches if present in the YAML
    try:
        if patch_data.get('rdbms_patches') is not None:
            documentation = rdbms_patches_insert_docs(patch_data['rdbms_patches'], patch_data["documentation_overrides"]['rdbms_patches'], documentation)
    except:
        print("No 'rdbms_patches' key found in the YAML file. Skipping RDBMS patches insertion.\n\n")

    # Process GI patches if present in the YAML
    try:
        if patch_data.get('gi_patches') is not None:
            documentation = gi_patches_insert_docs(patch_data['gi_patches'], patch_data["documentation_overrides"]['gi_patches'], documentation)
    except:
        print("No 'gi_patches' key found in the YAML file. Skipping GI patches insertion.\n\n")

    # Save the modified documentation
    save_md(doc_path, ''.join(documentation))

# Standard entry point for the script
if __name__ == "__main__":
    main()