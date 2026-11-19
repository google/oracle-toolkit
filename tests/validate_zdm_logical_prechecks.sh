#!/bin/bash
# Pre-checks script to run on the ZDM VM for Logical Migrations (Data Pump + GoldenGate)
# Supports both flags (--source-ip, --target-endpoint, --wallet-path, --gcs-bucket) and positional arguments.

set -e

SOURCE_IP=""
TARGET_ENDPOINT=""
WALLET_PATH=""
GCS_BUCKET=""

usage() {
  cat <<HELP_EOF
Usage: $0 [OPTIONS] [SOURCE_IP TARGET_ENDPOINT WALLET_PATH GCS_BUCKET]

Options:
  -s, --source-ip IP          Source Oracle Database host IP
  -t, --target-endpoint HOST  Target Database endpoint/IP (e.g., ADB-S TCPS endpoint or IP)
  -w, --wallet-path PATH      Path to target mTLS connection wallet directory containing cwallet.sso
  -b, --gcs-bucket BUCKET     GCS backup staging bucket (gs://...)
  -h, --help                  Show this help message

Positional Usage:
  $0 <source_db_ip> <target_endpoint> [wallet_path] [gcs_bucket]
HELP_EOF
  exit 1
}

# Parse named flags or positional arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    -s|--source-ip) SOURCE_IP="$2"; shift 2 ;;
    -t|--target-endpoint|--target-ip) TARGET_ENDPOINT="$2"; shift 2 ;;
    -w|--wallet-path|--wallet) WALLET_PATH="$2"; shift 2 ;;
    -b|--gcs-bucket|--bucket) GCS_BUCKET="$2"; shift 2 ;;
    -h|--help) usage ;;
    *)
      if [ -z "$SOURCE_IP" ]; then
        SOURCE_IP="$1"
      elif [ -z "$TARGET_ENDPOINT" ]; then
        TARGET_ENDPOINT="$1"
      elif [ -z "$WALLET_PATH" ]; then
        WALLET_PATH="$1"
      elif [ -z "$GCS_BUCKET" ]; then
        GCS_BUCKET="$1"
      fi
      shift
      ;;
  esac
done

echo "=========================================================="
echo "=== ZDM Logical Migration Connectivity Pre-checks ==="
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

# 3. Check TCP/IP listeners
if [ -z "$SOURCE_IP" ] || [ -z "$TARGET_ENDPOINT" ]; then
  echo "⚠️ WARNING: Source/Target endpoints not provided. Skipping TCP socket tests."
  echo "   Usage: $0 --source-ip <src_ip> --target-endpoint <tgt_endpoint> [--wallet-path <dir>] [--gcs-bucket <bucket>]"
  exit 1
fi

echo "Testing SQL*Net network connectivity on port 1521 to Source DB ($SOURCE_IP)..."
if timeout 3 bash -c "cat < /dev/tcp/$SOURCE_IP/1521" &>/dev/null; then
  echo "✓ Connection to Source Database ($SOURCE_IP:1521) is OPEN."
else
  echo "❌ ERROR: Cannot reach Source Database on $SOURCE_IP:1521."
  exit 1
fi

echo "Testing TCPS network connectivity on port 1522 to Target Endpoint ($TARGET_ENDPOINT)..."
if timeout 3 bash -c "cat < /dev/tcp/$TARGET_ENDPOINT/1522" &>/dev/null; then
  echo "✓ TCPS connection to Target Database ($TARGET_ENDPOINT:1522) is OPEN."
elif timeout 3 bash -c "cat < /dev/tcp/$TARGET_ENDPOINT/1521" &>/dev/null; then
  echo "✓ TCP connection to Target Database ($TARGET_ENDPOINT:1521) is OPEN."
else
  echo "❌ ERROR: Cannot reach Target Database on $TARGET_ENDPOINT port 1522/1521."
  exit 1
fi

# 4. Check target mTLS credentials wallet
if [ -n "$WALLET_PATH" ]; then
  echo "Checking Client Credentials Wallet ($WALLET_PATH)..."
  if [ -f "$WALLET_PATH/cwallet.sso" ]; then
    echo "✓ Target database wallet (cwallet.sso) found in $WALLET_PATH."
  else
    echo "❌ ERROR: Wallet file cwallet.sso not found in directory $WALLET_PATH."
    exit 1
  fi
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
echo "✓ All Logical Migration Connectivity Pre-checks Passed!"
echo "=========================================================="
exit 0
