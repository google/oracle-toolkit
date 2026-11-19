#!/bin/bash
# Master Pre-checks and Validation Test Suite
# Runs static code validation and cloud pre-checks.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "=========================================================="
echo "      Oracle Toolkit & Migration Pre-checks Suite         "
echo "=========================================================="

echo ""
echo "[Step 1/2] Running GCP Foundation & API Pre-validation..."
"$ROOT_DIR/scripts/migration/pre_validate.sh"

echo ""
echo "[Step 2/2] Running Terraform Code Validation across Environments..."
if command -v terraform &>/dev/null; then
  "$ROOT_DIR/tests/run_tf_validation.sh"
else
  echo "⚠️ 'terraform' command not found in PATH. Skipping Terraform HCL plan dry-run."
fi

echo ""
echo "=========================================================="
echo "✓ Pre-checks & Validation completed successfully."
echo "=========================================================="
