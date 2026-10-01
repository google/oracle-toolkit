#!/bin/bash
set -e

echo "=== Starting Terraform Code Validation ==="

ENV_DIRS=(
  "terraform/environments/gce"
  "terraform/environments/gke"
  "terraform/environments/oracle_db_gcp_exacs"
  "terraform/environments/oracle_db_gcp_adbs"
  "terraform/environments/oracle_db_gcp_dbcs"
)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

for env in "${ENV_DIRS[@]}"; do
  echo "--------------------------------------------------"
  echo "Validating environment: $env"
  echo "--------------------------------------------------"
  cd "$ROOT_DIR/$env"
  
  # Initialize Terraform in read-only / no-backend mode
  terraform init -backend=false
  
  # Run validation check
  terraform validate
  
  echo "  [✓] $env is valid."
done

echo "=================================================="
echo "=== All Terraform environments validated successfully! ==="
echo "=================================================="
