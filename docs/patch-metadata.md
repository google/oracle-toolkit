# A note on patch metadata

The patching code derives the patch metadata from the following blocks in the file `role/common/default/main.yml`:

```yaml
gi_patches:
...
- { category: "RU", base: "19.3.0.0.0", release: "19.9.0.0.201020", patchnum: "31720429", patchfile: "p31720429_190000_Linux-x86-64.zip", patch_subdir: "/31750108", prereq_check: FALSE, method: "opatchauto apply", ocm: FALSE, upgrade: FALSE, md5sum: "tTZDYSasdnt7lrNJ/MYm1g==" }


rdbms_patches:
...
- { category: "RU_Combo", base: "19.3.0.0.0", release: "19.9.0.0.201020", patchnum: "31720429", patchfile: "p31720429_190000_Linux-x86-64.zip", patch_subdir: "/31668882", prereq_check: TRUE, method: "opatch apply", ocm: FALSE, upgrade: TRUE, md5sum: "tTZDYSasdnt7lrNJ/MYm1g==" }
```

These metadata numbers can be taken from consulting appropriate MOS Notes, such as:

- [Assistant: Download Reference for Oracle Database/GI Update, Revision, PSU, SPU(CPU), Bundle Patches, Patchsets and Base Releases (Doc ID 2118136.2)](https://support.oracle.com/epmos/faces/DocContentDisplay?id=2118136.2)
- [Master Note for Database Proactive Patch Program (Doc ID 888.1)](https://support.oracle.com/epmos/faces/DocContentDisplay?id=888.1)
- [Oracle Database 19c Proactive Patch Information (Doc ID 2521164.1)](https://support.oracle.com/epmos/faces/DocContentDisplay?id=2521164.1)
- [Database 18c Proactive Patch Information (Doc ID 2369376.1)](https://support.oracle.com/epmos/faces/DocContentDisplay?id=2369376.1)
- [Database 12.2.0.1 Proactive Patch Information (Doc ID 2285557.1)](https://support.oracle.com/epmos/faces/DocContentDisplay?id=2285557.1)

The md5sum can be determined by listing the file once in a GCS bucket:

```bash
$ gcloud storage ls -L gs://example-bucket/p32578973_190000_Linux-x86-64.zip | grep -i md5
  Hash (MD5):                  YLEOruyjCOdDvUOMBUazNQ==
```

Bearing in mind that the GI RU's patch zipfile contains the patch molecules that go both into the GI_HOME as well as the RDBMS_HOME, the Combo patch of OJVM+GI is self-contained as to the necessary patches needed to patch a given host for a given quarter. For example: the patch zipfile `p31720429_190000_Linux-x86-64.zip` contains the following patch directories:

```
├── 31720429
│   ├── 31668882  <================ this is the OJVM RU for that quarter
│   │   ├── etc
│   │   ├── files
│   │   ├── README.html
│   │   └── README.txt
│   ├── 31750108  <================ this is GI RU for the given quarter
│   │   ├── 31771877
│   │   ├── 31772784
│   │   ├── 31773437
│   │   ├── 31780966
│   │   ├── automation
│   │   ├── bundle.xml
│   │   ├── README.html
│   │   └── README.txt
│   ├── PatchSearch.xml
│   └── README.html
└── PatchSearch.xml

```

Accordingly the `patch_subdir` values can be edited, as noted in the foregoing.

---

**RDBMS only** patches can also be specified. Either just the database release updates by using the category identifier of `DB_RU` or the database and OJVM release update combo patch by specifying the category identifier of `DB_OJVM_RU`.

Examples:

```yaml
rdbms_patches:
...
  - { category: "DB_OJVM_RU", base: "19.3.0.0.0", release: "19.28.0.0.250715", patchnum: "37952354", patchfile: "p37952354_190000_Linux-x86-64.zip", patch_subdir: "/37847857", prereq_check: true, method: "opatch apply", ocm: false, upgrade: true, md5sum: "LRVOEDN3ODtN2WckChrM9w==" }
...
  - { category: "DB_RU", base: "19.3.0.0.0", release: "19.28.0.0.250715", patchnum: "37952354", patchfile: "p37952354_190000_Linux-x86-64.zip", patch_subdir: "/37960098", prereq_check: true, method: "opatch apply", ocm: false, upgrade: true, md5sum: "LRVOEDN3ODtN2WckChrM9w==" }
```

The database RU can be sourced from the DB & OJVM RU combo patch zipfile (as shown in the example above) or from the separate database-only RU download. For example:

```yaml
rdbms_patches:
...
  - { category: "DB_RU", base: "19.3.0.0.0", release: "19.28.0.0.250715", patchnum: "37960098", patchfile: "p37960098_190000_Linux-x86-64.zip", patch_subdir: "/", prereq_check: true, method: "opatch apply", ocm: false, upgrade: true, md5sum: "PipbpAyGobuUR1I/L3PfuQ==" }
```
