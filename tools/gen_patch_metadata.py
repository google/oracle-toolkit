#!/usr/bin/python3
"""gen_patch_metadata.py is a helper script for toolkit maintainers to add metadata for upstream patches.
Identifies OJVM and the 'other' component subdir, letting the user choose the final YAML block.
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
import urllib
import zipfile

# Third-party libraries - ensure 'requests' and 'beautifulsoup4' are installed
try:
    import bs4
    import requests
except ImportError as e:
    print(f"Error: Required library not found ({e}). Please install requests and beautifulsoup4.")
    print("pip install requests beautifulsoup4")
    exit(1)


USER_AGENT = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.36'
SEARCH_FORM = 'https://updates.oracle.com/Orion/SimpleSearch/process_form?search_type=patch&patch_number=%d&plat_lang=226P'
DOWNLOAD_URL = r'https://updates.oracle.com/Orion/Download/process_form[^\"]*'
LOGIN_FORM = 'https://updates.oracle.com/Orion/SavedSearches/switch_to_simple'

# --- Network Functions ---

def get_patch_auth(s: requests.Session) -> typing.List[str]:
  """Obtains auth cookies/redirects needed for subsequent requests."""
  try:
    r = s.get(LOGIN_FORM, allow_redirects=False, timeout=60)
    r.raise_for_status()
    if 'location' in r.headers:
      logging.debug(f"Following redirect to {r.headers['location']}")
      r = s.get(r.headers['Location'], timeout=60)
      r.raise_for_status()
    if LOGIN_FORM in r.url or 'login' in r.url.lower():
         logging.debug("Possible redirect back to login, authentication might be required interactively.")
    return re.findall(LOGIN_FORM, r.text)
  except requests.exceptions.RequestException as e:
      logging.error(f"Authentication request failed: {e}")
      raise


def get_patch_url(s: requests.Session, patchnum: int) -> typing.List[str]:
  """Retrieves a download URL for a given patch number."""
  search_url = SEARCH_FORM % patchnum
  try:
    r = s.get(search_url, allow_redirects=True, timeout=60)
    r.raise_for_status()
    urls = re.findall(DOWNLOAD_URL, r.text)
    if not urls:
         content_snippet = r.text[:500].replace('\n', ' ')
         logging.error(f"Could not find download URL pattern in response from {search_url}. Content snippet: {content_snippet}")
         raise ValueError(f'Could not get a download URL from {search_url}; is patch number correct or is login required?')
    return urls
  except requests.exceptions.RequestException as e:
      logging.error(f"Failed to get patch URL for {patchnum}: {e}")
      raise


def download_patch(s: requests.Session, url: str, patch_file: str) -> None:
  """Downloads a given URL to a local file with retry logic."""
  logging.info('Downloading %s to %s', url, patch_file)
  adapter = requests.adapters.HTTPAdapter(max_retries=3)
  s.mount(url.split("://")[0] + "://", adapter)
  try:
      with s.get(url, stream=True, timeout=300) as r:
          r.raise_for_status()
          total_size = int(r.headers.get('content-length', 0))
          logging.debug(f"Download size: {total_size} bytes")
          bytes_downloaded = 0
          with open(patch_file, 'wb') as f:
              for chunk in r.iter_content(chunk_size=8192):
                  if chunk:
                      f.write(chunk)
                      bytes_downloaded += len(chunk)
          logging.info(f"Finished downloading {bytes_downloaded} bytes.")
  except requests.exceptions.RequestException as e:
      logging.error(f"Download failed for {url}: {e}")
      if os.path.exists(patch_file):
          try: os.remove(patch_file); logging.info(f"Removed incomplete download file: {patch_file}")
          except OSError as rm_e: logging.error(f"Failed to remove incomplete file {patch_file}: {rm_e}")
      raise

# --- Parsing Function ---

def parse_patch(patch_file: str, patchnum: int) -> typing.Tuple[str, str, typing.Optional[str], typing.Optional[str], str]:
    """
    Parses patch metadata: release info from XML, identifies OJVM and the 'other' component subdir.
    Relies on README analysis, making a best effort even with ambiguous keywords.
    Returns: (release, patch_release, ojvm_subdir, other_subdir, abstract)
    """
    ojvm_subdir: typing.Optional[str] = None
    other_subdir: typing.Optional[str] = None # Generic placeholder for GI or DB
    release: str = ""
    patch_release: str = ""
    abstract: str = "" # Initialize abstract here

    if not zipfile.is_zipfile(patch_file):
        raise ValueError(f"File '{patch_file}' is not a valid zip file.")

    with zipfile.ZipFile(patch_file, 'r') as z:
        # --- 1. Get Base Info from PatchSearch.xml ---
        try:
            with z.open('PatchSearch.xml') as f:
                content = f.read()
                try: c = bs4.BeautifulSoup(content, 'xml')
                except Exception: c = bs4.BeautifulSoup(content, 'html.parser')

                abstract_tag = c.find('abstract')
                if not abstract_tag: raise ValueError("Tag 'abstract' not found.")
                abstract = abstract_tag.get_text() # Assign abstract here
                logging.info('Abstract: %s', abstract)

                patch_release_match = re.search(r' (\d+\.\d+\.\d+\.\d+\.\d+) ', abstract)
                if not patch_release_match: raise ValueError("Could not extract patch release version.")
                patch_release = patch_release_match.group(1)

                release_tag = c.find('release')
                if not release_tag or 'name' not in release_tag.attrs: raise ValueError("Tag 'release' or 'name' attribute not found.")
                release = release_tag['name']
        except KeyError: raise FileNotFoundError("'PatchSearch.xml' not found in zip.")
        except Exception as e: raise ValueError(f"Error parsing PatchSearch.xml: {e}")

        # --- 2. Find Numeric Subdirectories ---
        subdir_pattern = re.compile(fr'^{patchnum}/(\d+)/')
        found_subdirs = set()
        for item in z.namelist():
            match = subdir_pattern.match(item)
            if match: found_subdirs.add(match.group(1))
        logging.info(f"Found numeric subdirectories: {found_subdirs}")

        if len(found_subdirs) != 2:
             raise ValueError(f"Expected exactly 2 numeric subdirectories under '{patchnum}/', but found {len(found_subdirs)}: {found_subdirs}. Cannot proceed.")

        # --- 3. Identify OJVM vs Other using README Analysis ---
        subdir_list = list(found_subdirs)
        readme_analysis = {} # subdir -> {'is_likely_ojvm': bool, 'is_likely_other': bool}

        for subdir_num in subdir_list:
            readme_analysis[subdir_num] = {'is_likely_ojvm': False, 'is_likely_other': False}
            readme_path = next((f'{patchnum}/{subdir_num}/README.{ext}' for ext in ['html', 'txt']
                                if f'{patchnum}/{subdir_num}/README.{ext}' in z.namelist()), None)
            if not readme_path:
                logging.warning(f"No README found for subdir {subdir_num}")
                continue

            try:
                with z.open(readme_path) as f:
                    content = f.read()
                    decoded_content = ""
                    for encoding in ['utf-8', 'latin-1', 'cp1252']:
                        try: decoded_content = content.decode(encoding); break
                        except UnicodeDecodeError: continue
                    if not decoded_content: continue

                    search_text = decoded_content.lower()
                    if readme_path.lower().endswith('.html'):
                         try:
                              c_sub = bs4.BeautifulSoup(decoded_content, 'lxml')
                              title_tag_sub = c_sub.find('title')
                              title_text = title_tag_sub.get_text().lower().strip() if title_tag_sub else ""
                              body_text = c_sub.get_text().lower()
                              search_text = title_text + " " + body_text # Combine title and body
                         except Exception: pass
                    if not search_text.strip(): continue

                    has_ojvm_kw = 'javavm' in search_text or 'ojvm' in search_text
                    has_other_kw = 'database' in search_text or 'rdbms' in search_text or 'db ru' in search_text or \
                                   'gi ' in search_text or 'grid infrastructure' in search_text or 'gi release update' in search_text

                    if has_ojvm_kw and not has_other_kw: readme_analysis[subdir_num]['is_likely_ojvm'] = True
                    if has_other_kw and not has_ojvm_kw: readme_analysis[subdir_num]['is_likely_other'] = True
                    logging.debug(f"Analysis for {subdir_num}: {readme_analysis[subdir_num]}")

            except Exception as e:
                logging.warning(f"Could not read/parse {readme_path}: {e}")

        # --- 4. Assign based on analysis ---
        clear_ojvm = [sd for sd, data in readme_analysis.items() if data['is_likely_ojvm']]
        clear_other = [sd for sd, data in readme_analysis.items() if data['is_likely_other']]

        if len(clear_ojvm) == 1:
            ojvm_subdir = clear_ojvm[0]
            other_subdir = next(s for s in subdir_list if s != ojvm_subdir)
            logging.info(f"Assigned OJVM subdir based on clear keywords: {ojvm_subdir}")
            logging.info(f"Assigned remaining subdir as 'Other': {other_subdir}")
        elif len(clear_other) == 1:
            other_subdir = clear_other[0]
            ojvm_subdir = next(s for s in subdir_list if s != other_subdir)
            logging.info(f"Assigned 'Other' subdir based on clear keywords: {other_subdir}")
            logging.info(f"Assigned remaining subdir as OJVM: {ojvm_subdir}")
        else:
            logging.error("README analysis was ambiguous for both subdirectories. Cannot reliably assign OJVM vs Other.")
            ojvm_subdir = subdir_list[0] # GUESS: Assign first as OJVM
            other_subdir = subdir_list[1] # GUESS: Assign second as Other
            logging.warning(f"GUESSING: Assigning {ojvm_subdir} as OJVM and {other_subdir} as Other. PLEASE VERIFY!")

    # Final Assertions
    if not ojvm_subdir: raise AssertionError("Failed to assign OJVM component subdirectory.")
    if not other_subdir: raise AssertionError("Failed to assign the 'other' component subdirectory.")

    return release, patch_release, ojvm_subdir, other_subdir, abstract


# --- Main Execution ---

def main():
  ap = argparse.ArgumentParser(description="Generate patch metadata YAML for Oracle GI/DB OJVM Combo Patches.")
  ap.add_argument('--patch', type=int, help='Combo patch number (e.g., 38273545)', required=True)
  ap.add_argument('--mosuser', type=str, help='My Oracle Support username (email)', required=True)
  ap.add_argument('--debug', help='Enable debug logging', action='store_true')
  args = ap.parse_args()

  log_level = logging.DEBUG if args.debug else logging.INFO
  logging.basicConfig(level=log_level, format='%(asctime)s %(levelname)s:%(name)s:%(message)s', datefmt='%Y-%m-%d %H:%M:%S')
  logging.getLogger("urllib3").setLevel(logging.WARNING)

  patchnum = args.patch
  mosuser = args.mosuser
  mospwd = getpass.getpass(prompt='MOS Password: ')

  s = requests.Session()
  s.headers.update({'User-Agent': USER_AGENT})
  s.auth = (mosuser, mospwd)

  try:
    # --- Patch Download ---
    get_patch_auth(s)
    patch_urls = get_patch_url(s, patchnum)
    patch_url = patch_urls[0]
    patch_file_match = re.search(r'patch_file=([^&]+)', patch_url)
    if not patch_file_match: raise ValueError(f"Could not extract patch filename from URL: {patch_url}")
    patch_file = patch_file_match.group(1)
    logging.info(f"Target patch file: {patch_file}")

    min_patch_size_gb = 1.5
    if os.path.exists(patch_file) and os.path.getsize(patch_file) > min_patch_size_gb * 1024 * 1024 * 1024:
      logging.info('Using local copy of patch file %s', patch_file)
    else:
      download_patch(s, patch_url, patch_file)
    size = os.path.getsize(patch_file)
    assert size > min_patch_size_gb * 1024 * 1024 * 1024, f'Patch file {patch_file} is only {size} bytes; looks too small'

    # --- MD5 Calculation ---
    logging.info("Calculating MD5 checksum...")
    md5 = hashlib.md5()
    with open(patch_file, 'rb') as f:
      while chunk := f.read(1 * 1024 * 1024): md5.update(chunk)
    md5_digest = base64.b64encode(md5.digest()).decode('ascii')
    logging.info(f'MD5 Checksum (Base64): {md5_digest}')

    # --- Parse Patch Info ---
    (release, patch_release, ojvm_subdir, other_subdir, abstract) = parse_patch(patch_file, patchnum)
    base_release = '19.3.0.0.0' if release == '19.0.0.0.0' else release
    logging.info('Determined: Release=%s, Patch Release=%s, Base=%s', release, patch_release, base_release)
    logging.info('Determined: OJVM Subdir=%s, Other Subdir=%s', ojvm_subdir, other_subdir)

    # --- OPatch Download ---
    opatch_patchnum = 6880880
    logging.info(f'Downloading OPatch (Patch {opatch_patchnum})')
    op_urls = get_patch_url(s, opatch_patchnum)
    release_major = base_release.split('.')[0]
    op_patch_url = None
    platform_str = "Linux-x86-64"
    patterns = [
        re.compile(fr'p{opatch_patchnum}_{release_major}0000_{platform_str}\.zip', re.IGNORECASE),
        re.compile(fr'release={release_major}.*{platform_str}', re.IGNORECASE),
        re.compile(fr'{platform_str}.*release={release_major}', re.IGNORECASE) ]
    specific_matches = [k for k in op_urls for pattern in patterns if pattern.search(k)]
    if specific_matches: op_patch_url = specific_matches[0]
    else:
        logging.warning(f"Specific OPatch not found. Trying generic {platform_str}.")
        generic_matches = [k for k in op_urls if platform_str.lower() in k.lower()]
        if generic_matches: op_patch_url = generic_matches[0]
        else: raise AssertionError(f'Could not find any suitable OPatch URL ({platform_str}) in {op_urls}')
    op_patch_file_match = re.search(r'patch_file=([^&]+)', op_patch_url)
    if not op_patch_file_match: raise ValueError(f"Could not extract OPatch filename from URL: {op_patch_url}")
    op_patch_file = op_patch_file_match.group(1)
    logging.info(f"Target OPatch file: {op_patch_file}")
    min_opatch_size_mb = 50
    if os.path.exists(op_patch_file) and os.path.getsize(op_patch_file) > min_opatch_size_mb * 1024 * 1024:
         logging.info(f"Using local copy of OPatch file {op_patch_file}")
    else: download_patch(s, op_patch_url, op_patch_file)
    opatch_size = os.path.getsize(op_patch_file)
    assert opatch_size > min_opatch_size_mb * 1024 * 1024, f'OPatch file {op_patch_file} is only {opatch_size} bytes; looks too small'

    # --- Generate YAML Output ---
    yaml_output = []
    yaml_output.append(f'\nPlease copy the following files to your GCS bucket: {patch_file} {op_patch_file}')
    yaml_output.append(f'\nAdd the following to the appropriate sections of roles/common/defaults/main.yml:')
    yaml_output.append(f'\n# IMPORTANT: Review the patch abstract and uncomment EITHER gi_patches OR db_patches below.')
    yaml_output.append(f'# Abstract was: {abstract}')

    # Add GI block (commented out)
    yaml_output.append(f'''
#  gi_patches:
#    - {{ category: "RU", base: "{base_release}", release: "{patch_release}", patchnum: "{patchnum}", patchfile: "{patch_file}", patch_subdir: "/{other_subdir}", prereq_check: FALSE, method: "opatchauto apply", ocm: FALSE, upgrade: FALSE, md5sum: "{md5_digest}" }}''')

    # Add DB block (commented out)
    yaml_output.append(f'''
#  db_patches:
#    - {{ category: "DB_RU", base: "{base_release}", release: "{patch_release}", patchnum: "{patchnum}", patchfile: "{patch_file}", patch_subdir: "/{other_subdir}", prereq_check: TRUE, method: "opatch apply", ocm: FALSE, upgrade: TRUE, md5sum: "{md5_digest}" }}''')

    # Add OJVM/RDBMS block (always present)
    yaml_output.append(f'''
  rdbms_patches: # Contains the OJVM component
    - {{ category: "RU_Combo_OJVM", base: "{base_release}", release: "{patch_release}", patchnum: "{patchnum}", patchfile: "{patch_file}", patch_subdir: "/{ojvm_subdir}", prereq_check: TRUE, method: "opatch apply", ocm: FALSE, upgrade: TRUE, md5sum: "{md5_digest}" }}
''')

    # Print combined YAML
    print("\n".join(yaml_output))

  # --- Centralized Error Handling ---
  except AssertionError as e: logging.error(f"Assertion failed: {e}"); exit(1)
  except FileNotFoundError as e: logging.error(f"File not found error: {e}"); exit(1)
  except ValueError as e: logging.error(f"Data processing error: {e}"); exit(1)
  except requests.exceptions.RequestException as e: logging.error(f"Network request failed: {e}"); exit(1)
  except zipfile.BadZipFile:
      logging.error(f"Error: The file '{patch_file}' is not a valid zip file or is corrupted.")
      if 'patch_file' in locals() and patch_file and os.path.exists(patch_file): os.remove(patch_file)
      exit(1)
  except Exception as e:
      logging.error(f"An unexpected error occurred: {e}", exc_info=args.debug); exit(1)

if __name__ == '__main__':
  main()
