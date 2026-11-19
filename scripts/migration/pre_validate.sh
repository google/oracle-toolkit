#!/bin/bash
set -e

echo "=== GCP Migration Environment Pre-validation ==="

# 1. Check Authentication Status
echo "Checking gcloud authentication..."
ACTIVE_ACCOUNT=$(gcloud config get-value core/account 2>/dev/null)

if [ -z "$ACTIVE_ACCOUNT" ]; then
  echo "No active gcloud account detected. Initiating login..."
  gcloud auth login
  gcloud auth application-default login
else
  echo "Active account: $ACTIVE_ACCOUNT"
  # Refresh token to verify session validity
  if ! gcloud auth print-access-token &>/dev/null; then
    echo "Active session has expired. Re-authenticating..."
    gcloud auth login
    gcloud auth application-default login
  else
    echo "Authentication token is valid."
  fi
fi

# 2. Check and Enable Required APIs
REQUIRED_APIS=(
  "compute.googleapis.com"
  "storage.googleapis.com"
  "container.googleapis.com"
  "secretmanager.googleapis.com"
  "iam.googleapis.com"
)

echo "Verifying GCP APIs..."
ENABLED_APIS=$(gcloud services list --enabled --format="value(config.name)")

for api in "${REQUIRED_APIS[@]}"; do
  if echo "$ENABLED_APIS" | grep -q "^$api$"; then
    echo "  [✓] $api is enabled."
  else
    echo "  [ ] $api is NOT enabled. Enabling..."
    gcloud services enable "$api"
  fi
done

echo "=== Pre-validation Completed Successfully ==="
