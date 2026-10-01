#!/bin/bash
# Google Cloud Infrastructure Manager State Verifier
# This script inspects the status of our ZDM deployments and writes a diagnostic log file.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "=========================================================="
echo "    Google Cloud Infrastructure Manager State Verifier    "
echo "=========================================================="

# 1. Select Deployment
echo "Select the deployment to verify:"
echo " 1) GCE Standard VM Deployment (zdm-gce-migration)"
echo " 2) GKE Private Cluster Deployment (zdm-gke-migration)"
read -p "Choose option [1-2]: " DEP_OPT

case $DEP_OPT in
  1) TARGET_ENV="gce"; DEP_NAME="zdm-gce-migration" ;;
  2) TARGET_ENV="gke"; DEP_NAME="zdm-gke-migration" ;;
  *) echo "❌ Invalid selection."; exit 1 ;;
esac

TFVARS_FILE="$ROOT_DIR/terraform/environments/$TARGET_ENV/terraform.tfvars"
if [ -f "$TFVARS_FILE" ]; then
  PROJECT_ID=$(grep -E '^\s*project_id\s*=' "$TFVARS_FILE" | cut -d'"' -f2)
  REGION=$(grep -E '^\s*region\s*=' "$TFVARS_FILE" | cut -d'"' -f2)
fi

# Fallback to active gcloud config if tfvars doesn't exist
PROJECT_ID=${PROJECT_ID:-$(gcloud config get-value project 2>/dev/null)}
REGION=${REGION:-$(gcloud config get-value compute/region 2>/dev/null)}

if [ -z "$PROJECT_ID" ] || [ -z "$REGION" ]; then
  echo "❌ ERROR: Could not determine Project ID or Region."
  read -p "GCP Project ID: " PROJECT_ID
  read -p "GCP Region: " REGION
fi

# Create logs directory
LOGS_DIR="$ROOT_DIR/logs"
mkdir -p "$LOGS_DIR"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="$LOGS_DIR/verify_${DEP_NAME}_${TIMESTAMP}.log"

echo "Querying Google Cloud Infrastructure Manager for deployment status..."
echo "  Deployment: $DEP_NAME"
echo "  Project   : $PROJECT_ID"
echo "  Region    : $REGION"
echo "  Log File  : $LOG_FILE"
echo ""

{
  echo "=========================================================="
  echo "      Deployment Diagnostic Log: $DEP_NAME"
  echo "      Executed At: $(date)"
  echo "=========================================================="
  echo ""
} > "$LOG_FILE"

# Run describe command and save output
JSON_OUT=$(gcloud infra-manager deployments describe "$DEP_NAME" \
  --project="$PROJECT_ID" \
  --location="$REGION" \
  --format="json" 2>/dev/null || true)

if [ -z "$JSON_OUT" ]; then
  MSG="❌ ERROR: Could not describe deployment. Ensure deployment exists in this project and region."
  echo "$MSG" | tee -a "$LOG_FILE"
  exit 1
fi

# Parse JSON fields
STATE=$(echo "$JSON_OUT" | grep -o '"state": "[^"]*' | head -n 1 | cut -d'"' -f4)
REVISION=$(echo "$JSON_OUT" | grep -o '"latestRevision": "[^"]*' | head -n 1 | cut -d'"' -f4)
LOGS_BUCKET=$(echo "$JSON_OUT" | grep -o '"artifactsGcsBucket": "[^"]*' | head -n 1 | cut -d'"' -f4)
ERR_MSG=$(echo "$JSON_OUT" | grep -o '"errorMessage": "[^"]*' | head -n 1 | cut -d'"' -f4 || true)

{
  echo "State: $STATE"
  echo "Latest Revision: $REVISION"
  echo "Artifacts GCS Bucket: $LOGS_BUCKET"
  if [ -n "$ERR_MSG" ]; then
    echo "Error Details: $ERR_MSG"
  fi
  echo ""
  echo "Detailed metadata JSON:"
  echo "$JSON_OUT"
  echo ""
} >> "$LOG_FILE"

# Output summary to console
echo "----------------------------------------------------------"
echo "Deployment State: $STATE"
echo "Latest Revision : $REVISION"
if [ -n "$ERR_MSG" ]; then
  echo "Error Message   : $ERR_MSG"
fi
echo "----------------------------------------------------------"

# If GCS logs exist, retrieve apply/init log
if [ -n "$LOGS_BUCKET" ] && [ -n "$REVISION" ]; then
  REVISION_ID=$(echo "$REVISION" | awk -F'/' '{print $NF}')
  GCS_LOG_PATH="gs://${LOGS_BUCKET#gs://}/deployments/${DEP_NAME}/revisions/${REVISION_ID}/logs"
  echo "Attempting to retrieve Terraform execution logs from $GCS_LOG_PATH ..."
  
  {
    echo "=========================================================="
    echo "            Terraform Build Execution Logs"
    echo "=========================================================="
  } >> "$LOG_FILE"
  
  # List files inside logs folder
  LOG_FILES=$(gsutil ls "$GCS_LOG_PATH/" 2>/dev/null || true)
  if [ -n "$LOG_FILES" ]; then
    for file in $LOG_FILES; do
      echo "Fetching log: $(basename "$file")"
      {
        echo "--- Log File: $(basename "$file") ---"
        gsutil cat "$file" 2>/dev/null || echo "[Failed to read log content]"
        echo ""
      } >> "$LOG_FILE"
    done
    echo "✓ Logs fetched successfully and written to $LOG_FILE"
  else
    echo "⚠️ No logs found in GCS for this revision." | tee -a "$LOG_FILE"
  fi
fi

echo "=========================================================="
echo "Verification complete. Diagnostic file saved at:"
echo "   $LOG_FILE"
echo "=========================================================="
