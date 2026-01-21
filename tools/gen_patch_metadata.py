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

def get_patch_auth(s: requests.Session) -> typing.List[str]:
    """Obtains auth for login in order to download patches."""
    r = s.get(LOGIN_FORM, allow_redirects=False)
    if 'location' in r.headers:
        r = s.get(r.headers['Location'])
    assert r.status_code == 200, f'Got HTTP code {r.status_code} retrieving {LOGIN_FORM}'
    url = re.findall(LOGIN_FORM, str(r.content))
    return url

def get_patch_url(s: requests.Session, patchnum: int) -> typing.List[str]:
    """Retrieves a download URL for a given patch number."""
    r = s.get(SEARCH_FORM % patchnum, allow_redirects=False)
    if 'location' in r.headers:
        r = s.get(r.headers['Location'])
    assert r.status_code == 200, f'Got HTTP code {r.status_code} retrieving {SEARCH_FORM}'
    url = re.findall(DOWNLOAD_URL, str(r.content))
    assert url, f'Could not get a download URL from the patch form {SEARCH_FORM}; is the patch number correct?'
    return url

def download_patch(s: requests.Session, url: str, patch_file: str) -> None:
    """Downloads a given URL to a local file."""
    logging.info('Downloading %s', url)
    s.mount(url, requests.adapters.HTTPAdapter(max_retries=3))
    with s.get(url, stream=True) as r:
        with open(patch_file, 'wb') as f:
            shutil.copyfileobj(r.raw, f)

def get_min_opatch_version(op_patch_file: str) -> str:
    """Extracts numeric version from version.txt in OPatch zip."""
    with zipfile.ZipFile(op_patch_file, 'r') as z:
        try:
            with z.open('OPatch/version.txt') as f:
                content = f.read().decode('utf-8').strip()
                match = re.search(r'(\d+\.\d+\.\d+\.\d+\.\d+)', content)
                return match.group(1) if match else content
        except KeyError:
            logging.warning('Could not find OPatch/version.txt in %s', op_patch_file)
            return "unknown"

def parse_patch(patch_file: str, patchnum: int) -> (str, str, str, str, str, bool):
    """Parses patch metadata and identifies subdirectories."""
    is_gi = False
    with zipfile.ZipFile(patch_file, 'r') as z:
        with z.open('PatchSearch.xml') as f:
            c = bs4.BeautifulSoup(f.read(), 'xml')
            abstract = c.find('abstract').get_text()
            logging.info('Abstract: %s', abstract)
            ver_match = re.search(r'(\d+\.\d+\.\d+\.\d+\.\d+)', abstract)
            patch_release = ver_match.group(1) if ver_match else "unknown"
            release_tag = c.find('release')
            release = release_tag['name'] if release_tag else "unknown"

        gi_subdir, ojvm_subdir, db_subdir = None, None, None
        for fname in z.namelist():
            m = re.search(fr'^{patchnum}/(\d+)/README.html', fname)
            if m:
                subdir_candidate = m.group(1)
                with z.open(fname) as f:
                    c = bs4.BeautifulSoup(f.read(), 'lxml')
                    title = c.find('title').get_text().strip() if c.find('title') else ""
                    if not title:
                        meta_title = c.find('meta', attrs={'name': 'doctitle'})
                        title = meta_title['content'] if meta_title else ""
                    logging.debug('Inspecting subdir %s with title: "%s"', subdir_candidate, title)

                    if any(x in title for x in ['JavaVM', 'OJVM']):
                        ojvm_subdir = subdir_candidate
                    elif any(x in title for x in ['GI ', 'Grid Infrastructure', 'GI Release Update']):
                        gi_subdir = subdir_candidate
                    elif 'Database' in title and ('Release Update' in title or '% product_version %' in title):
                        db_subdir = subdir_candidate

    if gi_subdir or "GI RELEASE UPDATE" in abstract.upper():
        is_gi = True
    # 21c specific structure adjustment: typically flat "/"
    if release.startswith('21'):
        logging.debug('Oracle 21c detected; using flat structure "/"')
        gi_subdir = "" if is_gi else None
        db_subdir = "" if not is_gi else None
        ojvm_subdir = None

    logging.debug('Final selection - GI: %s, DB: %s, OJVM: %s. is_gi: %s', gi_subdir, db_subdir, ojvm_subdir, is_gi)
    return (release, patch_release, ojvm_subdir, gi_subdir, db_subdir, is_gi)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--patch', type=int, help='Patch number', required=True)
    ap.add_argument('--mosuser', type=str, help='MOS username', required=True)
    ap.add_argument('--debug', help='Debug logging', action=argparse.BooleanOptionalAction)
    args = ap.parse_args()
    logging.basicConfig(level=logging.DEBUG if args.debug else logging.INFO)

    s = requests.Session()
    s.headers.update({'User-Agent': USER_AGENT})
    s.auth = (args.mosuser, getpass.getpass(prompt='MOS Password: '))

    url_list = get_patch_url(s, args.patch)
    patch_file = urllib.parse.parse_qs(urllib.parse.urlparse(url_list[0]).query)['patch_file'][0]
    
    if not (os.path.exists(patch_file) and os.path.getsize(patch_file) > 100*1024*1024):
        download_patch(s, url_list[0], patch_file)

    md5 = hashlib.md5()
    with open(patch_file, 'rb') as f:
        while chunk := f.read(1024*1024):
            md5.update(chunk)
    md5_digest = base64.b64encode(md5.digest()).decode('ascii')

    (release_name, patch_release, ojvm_subdir, gi_subdir, db_subdir, is_gi) = parse_patch(patch_file, args.patch)
    
    # Set base releases and flags
    is_21c = release_name.startswith('21')
    if is_21c:
        base_release = '21.3.0.0.0'
        prereq_flag = 'false'
        upgrade_flag = 'false'
    else:
        base_release = '19.3.0.0.0' if release_name == '19.0.0.0.0' else release_name
        prereq_flag = 'true'
        upgrade_flag = 'true'

    op_url = get_patch_url(s, 6880880)
    major_ver = patch_file.split('_')[1][:5]
    op_match = [k for k in op_url if major_ver in k][0]
    op_patch_file = urllib.parse.parse_qs(urllib.parse.urlparse(op_match).query)['patch_file'][0]
    if not os.path.exists(op_patch_file):
        download_patch(s, op_match, op_patch_file)
    min_opatch = get_min_opatch_version(op_patch_file)

    if is_gi:
        print(f"Add to roles/common/defaults/main/gi_patches.yml:")
        print(f'  - {{ category: "RU", base: "{base_release}", release: "{patch_release}", patchnum: "{args.patch}", patchfile: "{patch_file}", patch_subdir: "/{gi_subdir if gi_subdir is not None else ""}", prereq_check: false, method: "opatchauto apply", ocm: false, upgrade: false, md5sum: "{md5_digest}", minimum_opatch: "{min_opatch}" }}')
        if release_name.startswith('19') and ojvm_subdir:
            print(f"\nAdd to roles/common/defaults/main/rdbms_patches.yml:")
            print(f'  - {{ category: "RU_Combo", base: "{base_release}", release: "{patch_release}", patchnum: "{args.patch}", patchfile: "{patch_file}", patch_subdir: "/{ojvm_subdir}", prereq_check: {prereq_flag}, method: "opatch apply", ocm: false, upgrade: {upgrade_flag}, md5sum: "{md5_digest}", minimum_opatch: "{min_opatch}" }}')
    else:
        print(f"Add to roles/common/defaults/main/rdbms_patches.yml:")
        if release_name.startswith('19') and ojvm_subdir:
            print(f'  - {{ category: "DB_OJVM_RU", base: "{base_release}", release: "{patch_release}", patchnum: "{args.patch}", patchfile: "{patch_file}", patch_subdir: "/{ojvm_subdir}", prereq_check: {prereq_flag}, method: "opatch apply", ocm: false, upgrade: {upgrade_flag}, md5sum: "{md5_digest}", minimum_opatch: "{min_opatch}" }}')
        if db_subdir is not None:
            print(f'  - {{ category: "DB_RU", base: "{base_release}", release: "{patch_release}", patchnum: "{args.patch}", patchfile: "{patch_file}", patch_subdir: "/{db_subdir}", prereq_check: {prereq_flag}, method: "opatch apply", ocm: false, upgrade: {upgrade_flag}, md5sum: "{md5_digest}", minimum_opatch: "{min_opatch}" }}')

if __name__ == '__main__':
    main()
