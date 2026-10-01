#
# Oracle Zero Downtime Migration (ZDM) Physical Response File Template
#

# Migration parameters
MIGRATION_METHOD=${migration_method} # ONLINE_PHYSICAL or OFFLINE_PHYSICAL
DATA_TRANSFER_MEDIUM=OSS             # Use Cloud Storage (GCS) as backup transfer medium
PLATFORM_TYPE=${platform_type}       # DBaaS (DBCS) or ExaCS or OCI

# Source and Target unique names
TGT_DB_UNIQUE_NAME=${tgt_db_unique_name}
SRC_DB_UNIQUE_NAME=${src_db_unique_name}

# Credentials & Secrets (Stored in Wallet on ZDM host)
SRC_DB_PASSWORD_SECRET=src_db_sys_secret
TGT_DB_PASSWORD_SECRET=tgt_db_sys_secret
TDE_KEYSTORE_PASSWORD_SECRET=tde_keystore_secret

# OS users
SRC_TRANSFER_USER=oracle
TGT_TRANSFER_USER=oracle

# Cloud Storage configurations
# ZDM routes backups to GCS via OCI Object Storage wrapper API (using GCP interoperability keys)
HOST_BACKUP_DIRECTORY=/u01/app/oracle/zdm_backups
OPATCH_CHECK=TRUE
SHUTDOWN_SRC_DATABASE=TRUE
EOF_CHECK=TRUE
