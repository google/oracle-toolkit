#!/bin/bash
# Oracle ZDM & GoldenGate Migration Decommissioning and Cleanup Tool

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "=========================================================="
echo "    Oracle Database ZDM & Migration Cleanup Utility       "
echo "=========================================================="
echo "⚠️  WARNING: This tool helps clean up local migration jobs, "
echo "    wallets, and temporary staging artifacts."
echo "=========================================================="

read -p "Are you sure you want to proceed with migration cleanup? (y/N): " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
  echo "Cleanup cancelled."
  exit 0
fi

# 1. Clean local generated response files and wallets
WALLET_DIR="${ZDM_BASE:-/u01/zdm/zdmbase}/wallets"
if [ -d "$WALLET_DIR" ]; then
  read -p "Remove generated migration wallets in $WALLET_DIR? (y/N): " DEL_WALLETS
  if [[ "$DEL_WALLETS" =~ ^[Yy]$ ]]; then
    rm -rf "$WALLET_DIR"
    echo "✓ Wallets removed from $WALLET_DIR."
  fi
fi

# 2. Stop ZDM service if running locally
if [ -x "${ZDM_HOME:-/u01/zdm/zdmhome}/bin/zdmservice" ]; then
  echo "Stopping local ZDM daemon service..."
  "${ZDM_HOME:-/u01/zdm/zdmhome}/bin/zdmservice" stop 2>/dev/null || true
  echo "✓ ZDM daemon service stopped."
fi

# 3. Clean environment specific run scripts
find "$ROOT_DIR/terraform/environments" -name "run_migration.sh" -delete 2>/dev/null || true
echo "✓ Temporary migration execution scripts cleaned."

echo "=========================================================="
echo "✓ Migration cleanup process completed."
echo "  To destroy cloud infrastructure, run 'terraform destroy'"
echo "  inside the corresponding terraform/environments/ directory."
echo "=========================================================="
