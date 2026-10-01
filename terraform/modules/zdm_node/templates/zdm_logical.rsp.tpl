#
# Oracle Zero Downtime Migration (ZDM) Logical Response File Template
#

# Migration parameters
MIGRATION_METHOD=${migration_method} # ONLINE_LOGICAL or OFFLINE_LOGICAL
DATA_TRANSFER_MEDIUM=OSS             # Use Cloud Storage (GCS) as backup transfer medium

# Data Pump tuning parameters
DATAPUMP_PARALLELISM=${datapump_parallelism} # Recommended: target CPU count * 2
DATAPUMP_ENCRYPTION_MODE=ALL                # Secure compliance: encrypt metadata and data
EXCLUDE_SCHEMAS=SYS,SYSTEM,ANONYMOUS,XS$NULL,OUTLN,DBSNMP,APPQOSSYS,OJVMSYS,LBACSYS,DVSYS,WMSYS,ORDDATA,CTXSYS,MDSYS,XDB,WKSYS,WK_TEST,REPADMIN,EXFSYS,SYSMAN,MGMT_VIEW,OWBSYS,OWBSYS_AUDIT,APEX_040200,APEX_030200,APEX_050000,FLOWS_FILES,HTMLDB_SYSTEM

# Target database details
TGT_DB_UNIQUE_NAME=${tgt_db_unique_name}

# Credentials & Secrets (Stored in Wallet on ZDM host)
SRC_DB_PASSWORD_SECRET=src_db_sys_secret
TGT_DB_PASSWORD_SECRET=tgt_db_sys_secret

# GoldenGate Hub parameters (required for ONLINE_LOGICAL only)
ZDM_GOLDENGATE_HOME=${goldengate_home}
ZDM_GOLDENGATE_BASE=${goldengate_base}
ZDM_GOLDENGATE_ADMIN_USER=oggadmin
ZDM_GOLDENGATE_ADMIN_PASSWORD_SECRET=ogg_admin_secret
GOLDENGATE_SRC_PORT=9001
GOLDENGATE_TGT_PORT=9002
