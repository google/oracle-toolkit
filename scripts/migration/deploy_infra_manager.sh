#!/bin/bash
set -e

# Google Cloud Infrastructure Manager Deployment Script
# This script deploys our ZDM migration environments using GCP Infrastructure Manager (Infra Manager).

echo "=========================================================="
echo "      Google Cloud Infrastructure Manager Deployer        "
echo "=========================================================="

# 1. Select Environment
echo "Select ZDM running environment to deploy:"
echo " 1) GCE Standard VM (Dedicated VM running ZDM)"
echo " 2) GKE Private Cluster ZDM Container"
read -p "Choose option [1-2]: " ENV_OPT

case $ENV_OPT in
  1) TARGET_DIR="terraform/environments/gce"; DEP_NAME="zdm-gce-migration" ;;
  2) TARGET_DIR="terraform/environments/gke"; DEP_NAME="zdm-gke-migration" ;;
  *) echo "❌ Invalid selection."; exit 1 ;;
esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Verify tfvars exists
TFVARS_FILE="$ROOT_DIR/$TARGET_DIR/terraform.tfvars"
if [ ! -f "$TFVARS_FILE" ]; then
  echo "⚠️ Configuration variables file ($TFVARS_FILE) not found."
  echo "   Automatically launching setup wizard to configure inputs..."
  "$ROOT_DIR/scripts/migration/wizard.sh"
  
  # Re-verify after wizard runs
  if [ ! -f "$TFVARS_FILE" ]; then
    echo "❌ ERROR: Configuration variables file is still missing. Aborting."
    exit 1
  fi
fi

# Load project ID from tfvars
PROJECT_ID=$(grep -E '^\s*project_id\s*=' "$TFVARS_FILE" | cut -d'"' -f2)
REGION=$(grep -E '^\s*region\s*=' "$TFVARS_FILE" | cut -d'"' -f2)

if [ -z "$PROJECT_ID" ] || [ -z "$REGION" ]; then
  echo "❌ ERROR: Could not parse project_id or region from $TFVARS_FILE."
  exit 1
fi

# Load bucket name and flags from tfvars
BUCKET_NAME=$(grep -E '^\s*bucket_name\s*=' "$TFVARS_FILE" | cut -d'"' -f2)
CREATE_BUCKET=$(grep -E '^\s*create_bucket\s*=' "$TFVARS_FILE" | cut -d'=' -f2 | tr -d '[:space:]' | tr -d '"')
[ -z "$CREATE_BUCKET" ] && CREATE_BUCKET="true"

CREATE_NETWORKING=$(grep -E '^\s*create_networking\s*=' "$TFVARS_FILE" | cut -d'=' -f2 | tr -d '[:space:]' | tr -d '"')
[ -z "$CREATE_NETWORKING" ] && CREATE_NETWORKING="true"

CREATE_SERVICE_ACCOUNTS=$(grep -E '^\s*create_service_accounts\s*=' "$TFVARS_FILE" | cut -d'=' -f2 | tr -d '[:space:]' | tr -d '"')
[ -z "$CREATE_SERVICE_ACCOUNTS" ] && CREATE_SERVICE_ACCOUNTS="true"

if [ "$ENV_OPT" == "1" ]; then
  VPC_NAME="zdm-gce-vpc"
  SAS=("zdm-gce-service-node-sa")
else
  VPC_NAME="zdm-gke-vpc"
  SAS=("zdm-gke-sa" "zdm-gke-node-sa")
fi

echo "Validating resource existence before deploying to Infrastructure Manager..."
CONFLICTS=0

# 1. Check VPC Network
if [ "$CREATE_NETWORKING" == "true" ]; then
  if gcloud compute networks describe "$VPC_NAME" --project="$PROJECT_ID" >/dev/null 2>&1; then
    echo "❌ CONFLICT: VPC Network '$VPC_NAME' already exists in project '$PROJECT_ID'."
    echo "   To reuse this existing VPC, set 'create_networking = false' in your terraform.tfvars."
    CONFLICTS=$((CONFLICTS + 1))
  fi
else
  if ! gcloud compute networks describe "$VPC_NAME" --project="$PROJECT_ID" >/dev/null 2>&1; then
    echo "❌ MISSING RESOURCE: 'create_networking = false' was specified, but VPC Network '$VPC_NAME' does not exist in project '$PROJECT_ID'."
    echo "   To create a new VPC network, set 'create_networking = true' in your terraform.tfvars."
    CONFLICTS=$((CONFLICTS + 1))
  fi
fi

# 2. Check Service Accounts
if [ "$CREATE_SERVICE_ACCOUNTS" == "true" ]; then
  for sa in "${SAS[@]}"; do
    SA_EMAIL="${sa}@${PROJECT_ID}.iam.gserviceaccount.com"
    if gcloud iam service-accounts describe "$SA_EMAIL" --project="$PROJECT_ID" >/dev/null 2>&1; then
      echo "❌ CONFLICT: Service Account '$sa' already exists in project '$PROJECT_ID'."
      echo "   To reuse existing service accounts, set 'create_service_accounts = false' in your terraform.tfvars."
      CONFLICTS=$((CONFLICTS + 1))
      break
    fi
  done
else
  for sa in "${SAS[@]}"; do
    SA_EMAIL="${sa}@${PROJECT_ID}.iam.gserviceaccount.com"
    if ! gcloud iam service-accounts describe "$SA_EMAIL" --project="$PROJECT_ID" >/dev/null 2>&1; then
      echo "❌ MISSING RESOURCE: 'create_service_accounts = false' was specified, but Service Account '$sa' does not exist in project '$PROJECT_ID'."
      echo "   To create new service accounts, set 'create_service_accounts = true' in your terraform.tfvars."
      CONFLICTS=$((CONFLICTS + 1))
      break
    fi
  done
fi

# 3. Check Storage Bucket
if [ -n "$BUCKET_NAME" ]; then
  if [ "$CREATE_BUCKET" == "true" ]; then
    if gcloud storage buckets describe "gs://$BUCKET_NAME" --project="$PROJECT_ID" >/dev/null 2>&1; then
      echo "❌ CONFLICT: Storage Bucket 'gs://$BUCKET_NAME' already exists in project '$PROJECT_ID'."
      echo "   To reuse this existing bucket, set 'create_bucket = false' in your terraform.tfvars."
      CONFLICTS=$((CONFLICTS + 1))
    fi
  else
    if ! gcloud storage buckets describe "gs://$BUCKET_NAME" --project="$PROJECT_ID" >/dev/null 2>&1; then
      echo "❌ MISSING RESOURCE: 'create_bucket = false' was specified, but Storage Bucket 'gs://$BUCKET_NAME' does not exist in project '$PROJECT_ID'."
      echo "   To create a new GCS bucket, set 'create_bucket = true' in your terraform.tfvars."
      CONFLICTS=$((CONFLICTS + 1))
    fi
  fi
fi

if [ $CONFLICTS -gt 0 ]; then
  echo ""
  echo "⚠️ ERROR: $CONFLICTS resource validation issue(s) found. Infrastructure Manager will fail to deploy."
  echo "Please correct the conflicting or missing resources, or update settings in terraform.tfvars."
  exit 1
fi

echo "✓ Resource validation passed. All resource checks cleared."

echo ""
# Get project number to build default compute service account
echo "Retrieving project details..."
PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format="value(projectNumber)" 2>/dev/null || true)

if [ -n "$PROJECT_NUMBER" ]; then
  DEFAULT_SA="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"
  SA_PARAM="projects/$PROJECT_ID/serviceAccounts/$DEFAULT_SA"
  echo "Using default service account: $SA_PARAM"
else
  echo "Could not auto-detect project number. Please specify a service account email for Infrastructure Manager:"
  read -p "Service Account Email: " USER_SA
  SA_PARAM="projects/$PROJECT_ID/serviceAccounts/$USER_SA"
fi

# Parse service account email from resource path
SA_EMAIL=$(echo "$SA_PARAM" | awk -F'/' '{print $NF}')

echo "Checking Infrastructure Manager IAM permissions for $SA_EMAIL..."
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:$SA_EMAIL" \
  --role="roles/config.admin" \
  --condition=None \
  --quiet >/dev/null 2>&1 || {
    echo "⚠️ WARNING: Could not grant 'roles/config.admin' role automatically to $SA_EMAIL."
  }

gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:$SA_EMAIL" \
  --role="roles/editor" \
  --condition=None \
  --quiet >/dev/null 2>&1 || {
    echo "⚠️ WARNING: Could not grant broad 'roles/editor' role automatically. Attempting to grant required granular roles..."
    
    for role in "roles/compute.networkAdmin" "roles/compute.securityAdmin" "roles/iam.serviceAccountAdmin" "roles/container.admin" "roles/resourcemanager.projectIamAdmin"; do
      echo "   Binding granular role: $role..."
      gcloud projects add-iam-policy-binding "$PROJECT_ID" \
        --member="serviceAccount:$SA_EMAIL" \
        --role="$role" \
        --condition=None \
        --quiet >/dev/null 2>&1 || echo "   ⚠️ Failed to grant $role automatically. Please configure manually."
    done
  }

echo "Waiting 15 seconds for IAM permissions to propagate globally..."
sleep 15

echo ""
echo "Deployment Details:"
echo "  Deployment Name : $DEP_NAME"
echo "  Target Directory: $TARGET_DIR"
echo "  Project ID       : $PROJECT_ID"
echo "  Location/Region  : $REGION"
echo "  Service Account  : $SA_PARAM"
echo ""

# Enable Infrastructure Manager API if not active
echo "Enabling Infrastructure Manager API (config.googleapis.com)..."
gcloud services enable config.googleapis.com --project="$PROJECT_ID"

# 2. Trigger Infrastructure Manager Deployment
# --local-source uploads the local config directory files to a transient GCS bucket and deploys from there
echo "Submitting deployment to GCP Infrastructure Manager..."
gcloud infra-manager deployments apply "$DEP_NAME" \
  --project="$PROJECT_ID" \
  --location="$REGION" \
  --service-account="$SA_PARAM" \
  --local-source="$ROOT_DIR" \
  --inputs-file="$TFVARS_FILE"

echo ""
echo "✓ Deployment submitted successfully."
echo "To monitor the deployment status, run:"
echo "  gcloud infra-manager deployments describe $DEP_NAME --location=$REGION --project=$PROJECT_ID"
echo "=========================================================="
