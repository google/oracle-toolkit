#!/bin/bash
# Pre-checks script to run on the ZDM VM for Physical Migrations (Data Guard)
# Supports both flags (--source-ip, --target-ip, --gcs-bucket) and positional arguments.

set -e

SOURCE_IP=""
TARGET_IP=""
GCS_BUCKET=""

usage() {
  cat <<HELP_EOF
Usage: $0 [OPTIONS] [SOURCE_IP TARGET_IP GCS_BUCKET]

Options:
  -s, --source-ip IP       Source Oracle Database host IP
  -t, --target-ip IP       Target Oracle Database host IP (ExaCS / DBCS / GCE)
  -b, --gcs-bucket BUCKET  GCS backup staging bucket (gs://...)
  -h, --help               Show this help message

Positional Usage:
  $0 <source_db_ip> <target_db_ip> [gcs_bucket]
HELP_EOF
  exit 1
}

# Parse named flags or positional arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    -s|--source-ip) SOURCE_IP="$2"; shift 2 ;;
    -t|--target-ip) TARGET_IP="$2"; shift 2 ;;
    -b|--gcs-bucket|--bucket) GCS_BUCKET="$2"; shift 2 ;;
    -h|--help) usage ;;
    *)
      if [ -z "$SOURCE_IP" ]; then
        SOURCE_IP="$1"
      elif [ -z "$TARGET_IP" ]; then
        TARGET_IP="$1"
      elif [ -z "$GCS_BUCKET" ]; then
        GCS_BUCKET="$1"
      fi
      shift
      ;;
  esac
done

echo "=========================================================="
echo "=== ZDM Physical Migration Connectivity Pre-checks ==="
echo "=========================================================="

# 1. Verify ZDM Home Environment
if [ -z "$ZDM_HOME" ] || [ -z "$ZDM_BASE" ]; then
  echo "⚠️ WARNING: ZDM_HOME or ZDM_BASE is not defined in current session."
  echo "   Attempting fallback to standard path: /u01/zdm/zdmhome and /u01/zdm/zdmbase"
  export ZDM_HOME="${ZDM_HOME:-/u01/zdm/zdmhome}"
  export ZDM_BASE="${ZDM_BASE:-/u01/zdm/zdmbase}"
fi

if [ -d "$ZDM_HOME" ]; then
  echo "✓ ZDM Environment detected: ZDM_HOME=$ZDM_HOME"
else
  echo "⚠️ ZDM_HOME directory ($ZDM_HOME) not found on local filesystem."
fi

# 2. Check ZDM Service Daemon
if [ -x "$ZDM_HOME/bin/zdmservice" ]; then
  if $ZDM_HOME/bin/zdmservice status | grep -q "active"; then
    echo "✓ ZDM daemon service is active."
  else
    echo "⚠️ WARNING: ZDM Daemon service is not running. Start with: zdmservice start"
  fi
fi

# 3. Check TCP/IP listeners (Port 1521)
if [ -z "$SOURCE_IP" ] || [ -z "$TARGET_IP" ]; then
  echo "⚠️ WARNING: Source/Target IPs not provided. Skipping TCP socket tests."
  echo "   Usage: $0 --source-ip <src_ip> --target-ip <tgt_ip> [--gcs-bucket <bucket>]"
  exit 1
fi

echo "Testing SQL*Net network connectivity on port 1521..."
if timeout 3 bash -c "cat < /dev/tcp/$SOURCE_IP/1521" &>/dev/null; then
  echo "✓ Connection to Source Database ($SOURCE_IP:1521) is OPEN."
else
  echo "❌ ERROR: Cannot reach Source Database on $SOURCE_IP:1521."
  exit 1
fi

if timeout 3 bash -c "cat < /dev/tcp/$TARGET_IP/1521" &>/dev/null; then
  echo "✓ Connection to Target Database ($TARGET_IP:1521) is OPEN."
else
  echo "❌ ERROR: Cannot reach Target Database on $TARGET_IP:1521."
  exit 1
fi

# 4. Verify SSH Connection
echo "Testing passwordless SSH key connections (oracle user)..."
if ssh -o BatchMode=yes -o ConnectTimeout=3 oracle@$SOURCE_IP "echo '✓ Connection successful'" &>/dev/null; then
  echo "✓ Passwordless SSH to Source DB (oracle@$SOURCE_IP) is WORKING."
else
  echo "❌ ERROR: Passwordless SSH connection to oracle@$SOURCE_IP failed."
  exit 1
fi

if ssh -o BatchMode=yes -o ConnectTimeout=3 oracle@$TARGET_IP "echo '✓ Connection successful'" &>/dev/null; then
  echo "✓ Passwordless SSH to Target DB (oracle@$TARGET_IP) is WORKING."
else
  echo "❌ ERROR: Passwordless SSH connection to oracle@$TARGET_IP failed."
  exit 1
fi

# 5. Check GCS Storage Access
if [ -n "$GCS_BUCKET" ]; then
  echo "Testing Cloud Storage access (gsutil)..."
  if gsutil ls "$GCS_BUCKET" &>/dev/null; then
    echo "✓ Cloud Storage bucket access to $GCS_BUCKET is successful."
  else
    echo "❌ ERROR: Cannot access GCS bucket $GCS_BUCKET. Check IAM credentials."
    exit 1
  fi
fi

echo "=========================================================="
echo "✓ All Physical Migration Connectivity Pre-checks Passed!"
echo "=========================================================="
exit 0
