#!/usr/bin/python3
"""gen_patch_metadata.py is a helper script for toolkit maintainers to add metadata for upstream patches.
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

import bs4
import requests

USER_AGENT = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.36'
SEARCH_FORM = 'https://updates.oracle.com/Orion/SimpleSearch/process_form?search_type=patch&patch_number=%d&plat_lang=226P'
DOWNLOAD_URL = r'https://updates.oracle.com/Orion/Download/process_form[^\"]*'
LOGIN_FORM = 'https://updates.oracle.com/Orion/SavedSearches/switch_to_simple'

def get_patch_auth(s: requests.models.Request) -> typing.List[str]:
  """Obtains auth for login in order to download patches."""
  r = s.get(LOGIN_FORM, allow_redirects=False)
  if 'location' in r.headers:
   # Do two separate requests to force auth on second request
    r = s.get(r.headers['Location'])
  assert r.status_code == 200, f'Got HTTP code {r.status_code} retrieving {LOGIN_FORM}'
  url = re.findall(LOGIN_FORM, str(r.content))
  return url

def get_patch_url(s: requests.models.Request, patchnum: int) -> typing.List[str]:
  """Retrieves a download URL for a given patch number."""
  r = s.get(SEARCH_FORM % patchnum, allow_redirects=False)
  if 'location' in r.headers:
   # Do two separate requests to force auth on second request
    r = s.get(r.headers['Location'])

  assert r.status_code == 200, f'Got HTTP code {r.status_code} retrieving {SEARCH_FORM}'

  url = re.findall(DOWNLOAD_URL, str(r.content))
  assert url, f'Could not get a download URL from the patch form {SEARCH_FORM}; is the patch number correct?'
  return url


def download_patch(s: requests.models.Request, url: str, patch_file: str) -> None:
  """Downloads a given URL to a local file."""
  logging.info('Downloading %s', url)
  s.mount(url, requests.adapters.HTTPAdapter(max_retries=3))
  with s.get(url, stream=True) as r:
    with open(patch_file, 'wb') as f:
      shutil.copyfileobj(r.raw, f)


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


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--patch', type=int, help='GI Combo OJVM patch number', required=True)
    ap.add_argument('--mosuser', type=str, help='MOS username', required=True)
    ap.add_argument('--debug', help='Debug logging', action=argparse.BooleanOptionalAction)
    args = ap.parse_args()
    logging.basicConfig(level=logging.DEBUG if args.debug else logging.INFO)

    patchnum = args.patch
    mosuser = args.mosuser
    mospwd = getpass.getpass(prompt='MOS Password: ')

    s = requests.Session()
    s.headers.update({'User-Agent': USER_AGENT})
    s.auth = (mosuser, mospwd)

    url = get_patch_auth(s)
    url = get_patch_url(s, patchnum)
    # Yes we ignore multipart patche:ws here.
    logging.debug('Found download URL: %s', url[0])
    patch_file = urllib.parse.parse_qs(urllib.parse.urlparse(url[0]).query)['patch_file'][0]
    logging.debug('url=%s patch_file=%s', url[0], patch_file)
    if os.path.exists(patch_file) and os.path.getsize(patch_file) > 2*1024*1024*1024:
        logging.info('Using local copy of patch file %s', patch_file)
    else:
        download_patch(s, url[0], patch_file)

    size = os.path.getsize(patch_file)
    assert size > 2*1024*1024*1024, f'Output file {patch_file} is only {size} bytes in size;  looks too small'

    md5 = hashlib.md5()
    with open(patch_file, 'rb') as f:
        while chunk := f.read(1024*1024):
            md5.update(chunk)

    md5_digest = base64.b64encode(md5.digest()).decode('ascii')
    logging.debug('Calculated MD5 digest %s', md5_digest)

    # Updated parse_patch call
    (release, patch_release, ojvm_subdir, other_subdir, abstract) = parse_patch(patch_file, patchnum)

    base_release = '19.3.0.0.0' if release == '19.0.0.0.0' else release
    # Updated logging with new variables
    logging.info('Found release = %s base = %s Other subdir = %s OJVM subdir = %s', patch_release, base_release, other_subdir, ojvm_subdir)

    # New OPatch download logic
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
    assert op_patch_url, f'Could not find any suitable OPatch URL ({platform_str}) in {op_urls}'
    
    op_patch_file_match = re.search(r'patch_file=([^&]+)', op_patch_url)
    if not op_patch_file_match: raise ValueError(f"Could not extract OPatch filename from URL: {op_patch_url}")
    op_patch_file = op_patch_file_match.group(1)
    logging.info(f"Target OPatch file: {op_patch_file}")
    
    min_opatch_size_mb = 50 # Using 50MB as a reasonable minimum
    if os.path.exists(op_patch_file) and os.path.getsize(op_patch_file) > min_opatch_size_mb * 1024 * 1024:
            logging.info(f"Using local copy of OPatch file {op_patch_file}")
    else: download_patch(s, op_patch_url, op_patch_file)
    
    opatch_size = os.path.getsize(op_patch_file)
    assert opatch_size > min_opatch_size_mb * 1024 * 1024, f'OPatch file {op_patch_file} is only {opatch_size} bytes; looks too small'

    if not (base_release.startswith('19') or base_release.startswith('18') or base_release.startswith('12.2')):
        logging.warning('Base release %s has not been tested; the results may be incorrect.', base_release)

    # --- MODIFIED OUTPUT LOGIC ---
    yaml_output = []
    yaml_output.append(f'\nPlease copy the following files to your GCS bucket: {patch_file} {op_patch_file}')
    yaml_output.append(f'\nAdd the following to the appropriate sections of roles/common/defaults/main.yml:')
    yaml_output.append(f'\n# IMPORTANT: Review the patch abstract to make your selections.')
    yaml_output.append(f'# Abstract was: {abstract}')
    yaml_output.append(f'\n# --- SELECTION 1: Choose the NON-OJVM component (GI or DB) ---')
    yaml_output.append(f'# --- This component is in subdir: /{other_subdir} ---')

    # Add GI block (commented out)
    yaml_output.append(f'''
# 1A: If this is a GI Patch (RU), uncomment this block for gi_patches:
#   gi_patches:
#     - {{ category: "RU", base: "{base_release}", release: "{patch_release}", patchnum: "{patchnum}", patchfile: "{patch_file}", patch_subdir: "/{other_subdir}", prereq_check: FALSE, method: "opatchauto apply", ocm: FALSE, upgrade: FALSE, md5sum: "{md5_digest}" }}''')

    # Add DB block (commented out)
    yaml_output.append(f'''
# 1B: If this is an RDBMS Patch (DB_RU), uncomment this block for db_patches:
#   db_patches:
#     - {{ category: "DB_RU", base: "{base_release}", release: "{patch_release}", patchnum: "{patchnum}", patchfile: "{patch_file}", patch_subdir: "/{other_subdir}", prereq_check: TRUE, method: "opatch apply", ocm: FALSE, upgrade: TRUE, md5sum: "{md5_digest}" }}''')

    yaml_output.append(f'\n# --- SELECTION 2: Choose the OJVM component ---')
    yaml_output.append(f'# --- This component is in subdir: /{ojvm_subdir} ---')

    # Add OJVM/RDBMS block (RU_Combo)
    yaml_output.append(f'''
# 2A: If this is an OJVM package from a GI Combo (RU_Combo), uncomment this block for rdbms_patches:
#   rdbms_patches:
#     - {{ category: "RU_Combo", base: "{base_release}", release: "{patch_release}", patchnum: "{patchnum}", patchfile: "{patch_file}", patch_subdir: "/{ojvm_subdir}", prereq_check: TRUE, method: "opatch apply", ocm: FALSE, upgrade: TRUE, md5sum: "{md5_digest}" }}''')

    # Add OJVM/RDBMS block (DB_OJVM_RU)
    yaml_output.append(f'''
# 2B: If this is an OJVM + DB RU Update patch (DB_OJVM_RU), uncomment this block for rdbms_patches:
#   rdbms_patches:
#     - {{ category: "DB_OJVM_RU", base: "{base_release}", release: "{patch_release}", patchnum: "{patchnum}", patchfile: "{patch_file}", patch_subdir: "/{ojvm_subdir}", prereq_check: TRUE, method: "opatch apply", ocm: FALSE, upgrade: TRUE, md5sum: "{md5_digest}" }}
''')

    # Print combined YAML
    print("\n".join(yaml_output))
if __name__ == '__main__':
  main()
