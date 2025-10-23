#!/usr/bin/python3
"""
gen_patch_metadata.py is a helper script for toolkit maintainers to add
metadata for new Oracle patch bundles.

This script can be run directly to generate new patch metadata, or
imported as a module (e.g., by unit tests) to use its parsing functions.
"""

import argparse
import base64
import getpass
import hashlib
import logging
import os
import re
import shutil
import typing
import urllib.parse
import zipfile

# Import third-party libraries
try:
    import bs4
    import requests
except ImportError:
    print("Error: Missing required libraries. Please run:")
    print("pip install beautifulsoup4 requests lxml")
    exit(1)

# --- Constants ---

# Use a standard browser User-Agent to appear as a regular user to MOS.
USER_AGENT = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.36'

# MOS login and search URLs.
LOGIN_FORM = 'https://updates.oracle.com/Orion/SavedSearches/switch_to_simple'
SEARCH_FORM = 'https://updates.oracle.com/Orion/SimpleSearch/process_form?search_type=patch&patch_number=%d&plat_lang=226P'

# Regex to find the download link on the patch search results page.
DOWNLOAD_URL_RE = r'https://updates.oracle.com/Orion/Download/process_form[^\"]*'

# Patch number for the generic OPatch utility.
OPATCH_PATCHNUM = 6880880

# --- MOS Interaction Functions ---

def get_patch_auth(s: requests.Session) -> None:
    """
    Authenticates the requests.Session against the MOS login form.
    This is a "pre-flight" check to establish an authenticated session.
    """
    r = s.get(LOGIN_FORM, allow_redirects=False)
    if 'location' in r.headers:
        # Perform the two-step login redirect to get the auth cookies.
        r = s.get(r.headers['Location'])
    assert r.status_code == 200, f'Got HTTP {r.status_code} on auth attempt'

def get_patch_url(s: requests.Session, patchnum: int) -> typing.List[str]:
    """
    Finds all available download URLs for a specific patch number.
    """
    search_url = SEARCH_FORM % patchnum
    r = s.get(search_url, allow_redirects=False)
    if 'location' in r.headers:
        # Handle redirects, which can happen post-login
        r = s.get(r.headers['Location'])

    assert r.status_code == 200, f'Got HTTP {r.status_code} retrieving {search_url}'
    
    urls = re.findall(DOWNLOAD_URL_RE, str(r.content))
    assert urls, f'Could not find any download URLs for patch {patchnum}. Is it correct?'
    return urls

def download_patch(s: requests.Session, url: str, patch_file: str) -> None:
    """
    Downloads a given URL to a local file, streaming the response.
    """
    logging.info(f'Downloading {patch_file} from {url}')
    # Use a retry adapter for network resilience
    s.mount(url, requests.adapters.HTTPAdapter(max_retries=3))
    
    try:
        with s.get(url, stream=True) as r:
            r.raise_for_status() # Raise an exception for bad HTTP status
            with open(patch_file, 'wb') as f:
                shutil.copyfileobj(r.raw, f)
        logging.info(f'Successfully downloaded {patch_file}')
    except requests.exceptions.RequestException as e:
        logging.error(f"Failed to download {url}: {e}")
        # Clean up partial file on failure
        if os.path.exists(patch_file):
            os.remove(patch_file)
        raise

# --- Patch Parsing Helper Functions ---

def _parse_patch_xml(z: zipfile.ZipFile) -> typing.Tuple[str, str, str]:
    """
    Parses PatchSearch.xml to get base release, patch release, and abstract.
    """
    try:
        with z.open('PatchSearch.xml') as f:
            content = f.read()
            
            # Use html.parser as a fallback for potentially malformed XML
            try:
                c = bs4.BeautifulSoup(content, 'xml')
            except Exception:
                c = bs4.BeautifulSoup(content, 'html.parser')

            abstract_tag = c.find('abstract')
            if not abstract_tag:
                raise ValueError("Tag 'abstract' not found in PatchSearch.xml.")
            abstract = abstract_tag.get_text()

            # Extract full patch release (e.g., 19.17.0.0.221018) from abstract
            patch_release_match = re.search(r' (\d+\.\d+\.\d+\.\d+\.\d+) ', abstract)
            if not patch_release_match:
                # Fallback for 21c+ patches that might not have the 5-part version
                patch_release_match = re.search(r' (\d+\.\d+\.\d+\.\d+) ', abstract)
                if not patch_release_match:
                    raise ValueError("Could not extract patch release version from abstract.")
            patch_release = patch_release_match.group(1)

            # Extract base release (e.g., 19.0.0.0.0)
            release_tag = c.find('release')
            if not release_tag or 'name' not in release_tag.attrs:
                raise ValueError("Tag 'release' or 'name' attribute not found.")
            release = release_tag['name']
            
            return release, patch_release, abstract
            
    except KeyError:
        raise FileNotFoundError("'PatchSearch.xml' not found in zip file.")
    except Exception as e:
        raise ValueError(f"Error parsing PatchSearch.xml: {e}")

def _find_patch_subdirs(z: zipfile.ZipFile, patchnum: int) -> typing.Set[str]:
    """
    Finds the set of numeric subdirectories inside the main patch directory.
    (e.g., "34449117/34411846/" -> "34411846")
    """
    found_subdirs = set()
    # Match patchnum/12345/
    subdir_pattern = re.compile(fr'^{patchnum}/(\d+)/')
    
    for item in z.namelist():
        match = subdir_pattern.match(item)
        if match:
            found_subdirs.add(match.group(1))
            
    logging.info(f"Found numeric subdirectories: {found_subdirs}")
    return found_subdirs

def _read_and_decode_readme(z: zipfile.ZipFile, readme_path: str) -> str:
    """
    Reads a file from a zip and attempts to decode it using common encodings.
    """
    try:
        with z.open(readme_path) as f:
            content = f.read()
            for encoding in ['utf-8', 'latin-1', 'cp1252']:
                try:
                    return content.decode(encoding)
                except UnicodeDecodeError:
                    continue
        logging.warning(f"Could not decode {readme_path} with any known encoding.")
    except Exception as e:
        logging.warning(f"Error reading {readme_path} from zip: {e}")
    return ""

def _extract_text_from_readme(decoded_content: str, is_html: bool) -> str:
    """
    Extracts searchable, lower-case text from README content.
    If HTML, it combines text from both the <title> and <body>.
    """
    search_text = decoded_content.lower()
    if is_html:
        try:
            # *** Use 'lxml' for parsing HTML ***
            soup = bs4.BeautifulSoup(decoded_content, 'lxml')
            title_text = soup.find('title').get_text().lower().strip() if soup.find('title') else ""
            body_text = soup.get_text().lower()
            search_text = title_text + " " + body_text # Combine for better matching
        except Exception as e:
            logging.warning(f"Error parsing HTML README: {e}")
            pass # Fallback to using the raw decoded content
    return search_text.strip()

def parse_patch(patch_file: str, patchnum: int) -> typing.Tuple[str, str, str, str, str]:
    """
    Parses patch metadata: release info, abstract, and component subdirectories.
    
    This function is robust:
    - It reads `PatchSearch.xml` for definitive release info.
    - It finds *all* component subdirs (e.g., GI, DB, OJVM).
    - It analyzes `README.html` and `README.txt` files to identify
      which subdir is for OJVM and which is for the "Other" component (GI or DB).
      
    Returns:
        (release, patch_release, ojvm_subdir, other_subdir, abstract)
    """
    if not zipfile.is_zipfile(patch_file):
        raise ValueError(f"File '{patch_file}' is not a valid zip file.")

    with zipfile.ZipFile(patch_file, 'r') as z:
        
        # --- 1. Get Base Info from PatchSearch.xml ---
        release, patch_release, abstract = _parse_patch_xml(z)
        logging.info(f'Abstract: {abstract}')

        # --- 2. Find all numeric subdirectories ---
        found_subdirs = _find_patch_subdirs(z, patchnum)
        
        # Handle 21c+ single-component RUs which don't have numbered subdirs
        if not found_subdirs and release.startswith('21'):
             logging.info("Found 0 subdirs, assuming 21c-style patch with root subdir '/'")
             # Return root for both, test logic will validate against YAML
             return release, patch_release, "/", "/", abstract

        if len(found_subdirs) != 2:
            raise ValueError(
                f"Expected exactly 2 numeric subdirectories under '{patchnum}/', "
                f"but found {len(found_subdirs)}: {found_subdirs}. Cannot proceed."
            )
        
        # --- 3. Identify OJVM vs. Other component using README analysis ---
        readme_analysis = {} # Stores analysis results for each subdir
        subdir_list = list(found_subdirs)

        for subdir_num in subdir_list:
            analysis = {'is_likely_ojvm': False, 'is_likely_other': False}
            
            # Find README.html or README.txt
            readme_path = next((f'{patchnum}/{subdir_num}/README.{ext}' for ext in ['html', 'txt']
                                if f'{patchnum}/{subdir_num}/README.{ext}' in z.namelist()), None)
            
            if not readme_path:
                logging.warning(f"No README found for subdir {subdir_num}")
                readme_analysis[subdir_num] = analysis
                continue

            # Read, decode, and extract text from the README
            decoded_content = _read_and_decode_readme(z, readme_path)
            if not decoded_content:
                readme_analysis[subdir_num] = analysis
                continue
                
            search_text = _extract_text_from_readme(
                decoded_content, 
                is_html=readme_path.lower().endswith('.html')
            )
            if not search_text:
                readme_analysis[subdir_num] = analysis
                continue

            # Check for identifying keywords
            has_ojvm_kw = 'javavm' in search_text or 'ojvm' in search_text
            has_other_kw = any(kw in search_text for kw in 
                ['database', 'rdbms', 'db ru', 'gi ', 'grid infrastructure', 'gi release update'])

            # Only flag as "likely" if keywords are NOT ambiguous
            if has_ojvm_kw and not has_other_kw:
                analysis['is_likely_ojvm'] = True
            if has_other_kw and not has_ojvm_kw:
                analysis['is_likely_other'] = True
                
            readme_analysis[subdir_num] = analysis
            logging.debug(f"Analysis for {subdir_num}: {analysis}")

        # --- 4. Assign subdirs based on analysis ---
        ojvm_subdir, other_subdir = None, None
        clear_ojvm = [sd for sd, data in readme_analysis.items() if data['is_likely_ojvm']]
        clear_other = [sd for sd, data in readme_analysis.items() if data['is_likely_other']]

        if len(clear_ojvm) == 1:
            # Clearly identified OJVM
            ojvm_subdir = clear_ojvm[0]
            other_subdir = next(s for s in subdir_list if s != ojvm_subdir)
            logging.info(f"Assigned OJVM subdir based on clear keywords: /{ojvm_subdir}")
        elif len(clear_other) == 1:
            # Clearly identified Other (GI/DB)
            other_subdir = clear_other[0]
            ojvm_subdir = next(s for s in subdir_list if s != other_subdir)
            logging.info(f"Assigned 'Other' subdir based on clear keywords: /{other_subdir}")
        else:
            # Ambiguous! Log an error and guess. The user MUST verify.
            ojvm_subdir = subdir_list[0] # GUESS: Assign first as OJVM
            other_subdir = subdir_list[1] # GUESS: Assign second as Other
            logging.error("README analysis was ambiguous for both subdirectories.")
            logging.warning(
                f"GUESSING: Assigning /{ojvm_subdir} as OJVM and /{other_subdir} as Other. "
                "PLEASE VERIFY MANUALLY!"
            )
        
        # *** FIX: Return subdir with leading slash, as expected in YAML ***
        return release, patch_release, f"/{ojvm_subdir}", f"/{other_subdir}", abstract

# --- OPatch Download Function ---

def download_opatch(s: requests.Session, base_release: str) -> str:
    """
    Downloads the latest OPatch utility for a given base release.
    
    Returns:
        The filename of the downloaded OPatch zip.
    """
    logging.info(f'Downloading OPatch (Patch {OPATCH_PATCHNUM}) for release {base_release}')
    op_urls = get_patch_url(s, OPATCH_PATCHNUM)
    
    release_major = base_release.split('.')[0] # e.g., "19" from "19.3.0.0.0"
    op_patch_url = None
    platform_str = "Linux-x86-64"

    # Define patterns to find the *correct* OPatch for our DB release
    patterns = [
        # Most specific: p6880880_190000_Linux-x86-64.zip
        re.compile(fr'p{OPATCH_PATCHNUM}_{release_major}0000_{platform_str}\.zip', re.IGNORECASE),
        # Generic release + platform: ...release=19...Linux-x86-64...
        re.compile(fr'release={release_major}.*{platform_str}', re.IGNORECASE),
        re.compile(fr'{platform_str}.*release={release_major}', re.IGNORECASE)
    ]

    # Try to find a specific match first
    specific_matches = [k for k in op_urls for pattern in patterns if pattern.search(k)]
    if specific_matches:
        op_patch_url = specific_matches[0]
        logging.info(f"Found specific OPatch URL: {op_patch_url}")
    else:
        # Fallback: Find *any* Linux-x86-64 OPatch URL if specific one fails
        logging.warning(f"Specific OPatch for release {release_major} not found. "
                        f"Trying generic {platform_str} fallback.")
        generic_matches = [k for k in op_urls if platform_str.lower() in k.lower()]
        if generic_matches:
            op_patch_url = generic_matches[0]
            logging.info(f"Found generic OPatch URL: {op_patch_url}")
            
    assert op_patch_url, f'Could not find any suitable OPatch URL ({platform_str}) in {op_urls}'

    # Extract the filename from the download URL's query parameters
    op_patch_file_match = re.search(r'patch_file=([^&]+)', op_patch_url)
    if not op_patch_file_match:
        raise ValueError(f"Could not extract OPatch filename from URL: {op_patch_url}")
    op_patch_file = op_patch_file_match.group(1)

    # Download OPatch, skipping if a reasonably-sized file already exists
    min_opatch_size_mb = 50
    min_opatch_size_bytes = min_opatch_size_mb * 1024 * 1024
    
    if os.path.exists(op_patch_file) and os.path.getsize(op_patch_file) > min_opatch_size_bytes:
        logging.info(f"Using local copy of OPatch file {op_patch_file}")
    else:
        download_patch(s, op_patch_url, op_patch_file)

    # Final size check
    opatch_size = os.path.getsize(op_patch_file)
    assert opatch_size > min_opatch_size_bytes, (
        f'OPatch file {op_patch_file} is only {opatch_size} bytes; looks too small'
    )
    
    return op_patch_file

# --- Main Execution Block ---

def main():
    """
    Main function to run the script from the command line.
    """
    # 1. --- Argument Parsing ---
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--patch', type=int, help='The main combo patch number to download and parse.', required=True)
    ap.add_argument('--mosuser', type=str, help='My Oracle Support (MOS) username.', required=True)
    ap.add_argument('--debug', help='Enable debug logging.', action='store_true')
    args = ap.parse_args()
    
    logging.basicConfig(
        level=logging.DEBUG if args.debug else logging.INFO,
        format='%(levelname)s: %(message)s'
    )

    patchnum = args.patch
    mosuser = args.mosuser
    try:
        mospwd = getpass.getpass(prompt='MOS Password: ')
    except Exception as e:
        logging.error(f"Could not get password: {e}")
        return

    # 2. --- Setup MOS Session ---
    try:
        s = requests.Session()
        s.headers.update({'User-Agent': USER_AGENT})
        s.auth = (mosuser, mospwd)
        
        get_patch_auth(s) # Authenticate the session
    except Exception as e:
        logging.error(f"Failed to authenticate with MOS: {e}")
        return

    # 3. --- Download Main Patch ---
    try:
        urls = get_patch_url(s, patchnum)
        logging.debug(f'Found download URL(s): {urls}')
        
        patch_file = urllib.parse.parse_qs(urllib.parse.urlparse(urls[0]).query)['patch_file'][0]

        min_patch_size_gb = 2
        min_patch_size_bytes = min_patch_size_gb * 1024 * 1024 * 1024
        
        if os.path.exists(patch_file) and os.path.getsize(patch_file) > min_patch_size_bytes:
            logging.info(f'Using local copy of patch file {patch_file}')
        else:
            download_patch(s, urls[0], patch_file)

        size = os.path.getsize(patch_file)
        assert size > min_patch_size_bytes, (
            f'Output file {patch_file} is only {size} bytes; looks too small'
        )
    except Exception as e:
        logging.error(f"Failed to download main patch {patchnum}: {e}")
        return

    # 4. --- Calculate MD5 Checksum ---
    logging.info(f"Calculating MD5 for {patch_file}...")
    md5 = hashlib.md5()
    with open(patch_file, 'rb') as f:
        while chunk := f.read(1024*1024):
            md5.update(chunk)

    md5_digest = base64.b64encode(md5.digest()).decode('ascii')
    logging.info(f'Calculated MD5 digest: {md5_digest}')

    # 5. --- Parse Patch Contents ---
    try:
        (release, patch_release, ojvm_subdir, other_subdir, abstract) = parse_patch(patch_file, patchnum)
    except Exception as e:
        logging.error(f"Failed to parse patch file {patch_file}: {e}")
        logging.error("This patch may be a single-component patch or have an unexpected structure.")
        return

    base_release = '19.3.0.0.0' if release == '19.0.0.0.0' else release
    
    logging.info(f'--- Patch Analysis Results ---')
    logging.info(f'  Base Release:   {base_release}')
    logging.info(f'  Patch Release:  {patch_release}')
    logging.info(f'  "Other" Subdir: {other_subdir} (This is likely the GI or DB_RU component)')
    logging.info(f'  "OJVM" Subdir:  {ojvm_subdir}')
    logging.info(f'--------------------------------')

    # 6. --- Download OPatch ---
    try:
        op_patch_file = download_opatch(s, base_release)
    except Exception as e:
        logging.error(f"Failed to download OPatch: {e}")
        op_patch_file = "OPATCH_DOWNLOAD_FAILED" # Set placeholder to continue

    # 7. --- Generate Final YAML Output ---
    yaml_output = []
    yaml_output.append(f'\n# === SCRIPT OUTPUT: Copy files and update YAML ===')
    yaml_output.append(f'\n# 1. Copy the following files to your GCS bucket:')
    yaml_output.append(f'# {patch_file} {op_patch_file}')
    
    yaml_output.append(f'\n# 2. Add the following to roles/common/defaults/main/ files:')
    yaml_output.append(f'#    (Review the abstract to make the correct selections!)')
    yaml_output.append(f'#')
    yaml_output.append(f'# Abstract: {abstract}')
    
    yaml_output.append(f'\n# --- SELECTION 1: Choose the NON-OJVM component (GI or DB) ---')
    yaml_output.append(f'# --- This component is in subdir: {other_subdir} ---')
    
    # 1A: GI Patch Option
    yaml_output.append(f'''
# 1A: If this is a GI Patch (RU), add to 'gi_patches.yml':
#   gi_patches:
#     - {{ category: "RU", base: "{base_release}", release: "{patch_release}", patchnum: "{patchnum}", patchfile: "{patch_file}", patch_subdir: "{other_subdir}", prereq_check: FALSE, method: "opatchauto apply", ocm: FALSE, upgrade: FALSE, md5sum: "{md5_digest}" }}''')

    # 1B: DB_RU Patch Option
    yaml_output.append(f'''
# 1B: If this is an RDBMS Patch (DB_RU), add to 'rdbms_patches.yml':
#   rdbms_patches:
#     - {{ category: "DB_RU", base: "{base_release}", release: "{patch_release}", patchnum: "{patchnum}", patchfile: "{patch_file}", patch_subdir: "{other_subdir}", prereq_check: TRUE, method: "opatch apply", ocm: FALSE, upgrade: TRUE, md5sum: "{md5_digest}" }}''')

    yaml_output.append(f'\n# --- SELECTION 2: Choose the OJVM component ---')
    yaml_output.append(f'# --- This component is in subdir: {ojvm_subdir} ---')
    
    # 2A: RU_Combo OJVM Option
    yaml_output.append(f'''
# 2A: If OJVM is from a GI Combo (RU_Combo), add to 'rdbms_patches.yml':
#   rdbms_patches:
#     - {{ category: "RU_Combo", base: "{base_release}", release: "{patch_release}", patchnum: "{patchnum}", patchfile: "{patch_file}", patch_subdir: "{ojvm_subdir}", prereq_check: TRUE, method: "opatch apply", ocm: FALSE, upgrade: TRUE, md5sum: "{md5_digest}" }}''')

    # 2B: DB_OJVM_RU Patch Option
    yaml_output.append(f'''
# 2B: If this is an OJVM + DB RU (DB_OJVM_RU), add to 'rdbms_patches.yml':
#   rdbms_patches:
#     - {{ category: "DB_OJVM_RU", base: "{base_release}", release: "{patch_release}", patchnum: "{patchnum}", patchfile: "{patch_file}", patch_subdir: "{ojvm_subdir}", prereq_check: TRUE, method: "opatch apply", ocm: FALSE, upgrade: TRUE, md5sum: "{md5_digest}" }}
''')
    
    yaml_output.append(f'# === END SCRIPT OUTPUT ===')

    print("\n".join(yaml_output))


# This guard makes the script safely importable
if __name__ == '__main__':
    main()


