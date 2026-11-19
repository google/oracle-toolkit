#!/bin/bash
set -eo pipefail

# Script: publish_goldengate_image.sh
# Description: Downloads/loads Oracle GoldenGate 23ai container image from OCI ObjectStorage, 
#              publishes it to GCP Artifact Registry using local Docker or Cloud Build, 
#              and updates terraform.tfvars.

DEFAULT_URL="https://objectstorage.eu-zurich-1.oraclecloud.com/p/_Rozg2bzsPyKLktcTVOc3jpPI9_h75fsGyMTAqUFFkR2kOa0-TM6lNFUPLZAtvkH/n/zrtpnntkgyvg/b/codina_aistudio/o/ora23ai-2326202.tar"
DEFAULT_REGION="europe-west3"
DEFAULT_REPO="zdm-repo"
DEFAULT_TAG="23.26.2.0.2"
TFVARS_FILE="terraform.tfvars"
BUILDCFG_FILE="$(dirname "$0")/cloudbuild_goldengate.yaml"

# Parse terraform.tfvars if present in current directory
TF_PROJECT=""
TF_REGION=""
TF_OGG_IMAGE=""
if [[ -f "${TFVARS_FILE}" ]]; then
  TF_PROJECT=$(sed -n 's/^[[:space:]]*project_id[[:space:]]*=[[:space:]]*"\(.*\)".*/\1/p' "${TFVARS_FILE}" 2>/dev/null || true)
  TF_REGION=$(sed -n 's/^[[:space:]]*region[[:space:]]*=[[:space:]]*"\(.*\)".*/\1/p' "${TFVARS_FILE}" 2>/dev/null || true)
  TF_OGG_IMAGE=$(sed -n 's/^[[:space:]]*ogg_image[[:space:]]*=[[:space:]]*"\(.*\)".*/\1/p' "${TFVARS_FILE}" 2>/dev/null || true)
fi

usage() {
  local exit_code="${1:-1}"
  cat <<EOF
Usage: $0 [OPTIONS]

Options:
  -p, --project PROJECT_ID   GCP Project ID (default from terraform.tfvars or GCP_PROJECT env)
  -r, --region REGION        GCP Region for Artifact Registry (default from terraform.tfvars or ${DEFAULT_REGION})
  -n, --repo REPO_NAME       Artifact Registry Repository name (default: ${DEFAULT_REPO})
  -u, --url TAR_URL          OCI ObjectStorage URL to GoldenGate tar archive (default: standard 23ai URL)
  -f, --file LOCAL_TAR       Local path to GoldenGate tar image file (bypasses download for local docker build)
  -t, --tag IMAGE_TAG        Target image tag (default: ${DEFAULT_TAG})
  --cloud-build              Force execution via GCP Cloud Build (serverless build, no local Docker required)
  --no-update-tfvars         Do not update terraform.tfvars with published image URI
  -h, --help                 Show this help message

Examples:
  $0                         # Automatically uses project_id and region from terraform.tfvars
  $0 --cloud-build           # Submit build job to GCP Cloud Build
  $0 -p total-vertex-469513-r8
EOF
  exit "${exit_code}"
}

PROJECT_ID="${TF_PROJECT:-${GCP_PROJECT:-}}"
REGION="${TF_REGION:-${DEFAULT_REGION}}"
REPO_NAME="${DEFAULT_REPO}"
TAR_URL="${DEFAULT_URL}"
LOCAL_TAR=""
IMAGE_TAG="${DEFAULT_TAG}"
USE_CLOUD_BUILD=false
UPDATE_TFVARS=true

while [[ $# -gt 0 ]]; do
  case "$1" in
    -p|--project) PROJECT_ID="$2"; shift 2 ;;
    -r|--region) REGION="$2"; shift 2 ;;
    -n|--repo) REPO_NAME="$2"; shift 2 ;;
    -u|--url) TAR_URL="$2"; shift 2 ;;
    -f|--file) LOCAL_TAR="$2"; shift 2 ;;
    -t|--tag) IMAGE_TAG="$2"; shift 2 ;;
    --cloud-build|--cb) USE_CLOUD_BUILD=true; shift 1 ;;
    --no-update-tfvars) UPDATE_TFVARS=false; shift 1 ;;
    -h|--help) usage 0 ;;
    *) echo "Unknown option: $1"; usage 1 ;;
  esac
done

if [[ -z "${PROJECT_ID}" ]]; then
  echo "Error: GCP Project ID is required. Pass -p <PROJECT_ID>, set GCP_PROJECT env, or define project_id in terraform.tfvars."
  usage 1
fi

echo "================================================================="
echo "=== Oracle GoldenGate Image Publisher for GCP Artifact Registry =="
echo "================================================================="
echo "GCP Project ID : ${PROJECT_ID}"
echo "Region         : ${REGION}"
echo "Repository     : ${REPO_NAME}"
echo "Image Tag      : ${IMAGE_TAG}"
echo "OCI Tar URL    : ${TAR_URL}"
echo "================================================================="

# Prerequisite Checks
command -v gcloud >/dev/null 2>&1 || { echo "Error: 'gcloud' CLI is required but not installed."; exit 1; }

if ! command -v docker >/dev/null 2>&1; then
  echo "Notice: Local 'docker' engine is not installed."
  echo "Automatically switching execution mode to GCP Cloud Build."
  USE_CLOUD_BUILD=true
fi

# Ensure Artifact Registry Repository Exists
echo "[1/4] Checking GCP Artifact Registry repository: ${REPO_NAME}..."
if ! gcloud artifacts repositories describe "${REPO_NAME}" --location="${REGION}" --project="${PROJECT_ID}" >/dev/null 2>&1; then
  echo "Repository '${REPO_NAME}' does not exist in region '${REGION}'. Creating..."
  gcloud artifacts repositories create "${REPO_NAME}" \
    --repository-format=docker \
    --location="${REGION}" \
    --project="${PROJECT_ID}" \
    --description="Docker repository for Oracle ZDM & GoldenGate containers"
  echo "Repository '${REPO_NAME}' created successfully."
else
  echo "Repository '${REPO_NAME}' exists."
fi

REGISTRY_HOST="${REGION}-docker.pkg.dev"
TARGET_IMAGE="${REGISTRY_HOST}/${PROJECT_ID}/${REPO_NAME}/goldengate:${IMAGE_TAG}"
TARGET_IMAGE_LATEST="${REGISTRY_HOST}/${PROJECT_ID}/${REPO_NAME}/goldengate:latest"

if [[ "${USE_CLOUD_BUILD}" == true ]]; then
  echo "================================================================="
  echo "=== Submitting Build Job to Google Cloud Build (Serverless) ==="
  echo "================================================================="
  
  if [[ ! -f "${BUILDCFG_FILE}" ]]; then
    echo "Error: Cloud Build configuration file '${BUILDCFG_FILE}' not found."
    exit 1
  fi

  gcloud builds submit . \
    --config="${BUILDCFG_FILE}" \
    --project="${PROJECT_ID}" \
    --region="${REGION}" \
    --substitutions="_LOCATION=${REGION},_REPO_NAME=${REPO_NAME},_TAG=${IMAGE_TAG},_TAR_URL=${TAR_URL}"

else
  # Local Docker Build Execution
  TAR_FILE=""
  CLEANUP_TAR=false

  if [[ -n "${LOCAL_TAR}" ]]; then
    if [[ ! -f "${LOCAL_TAR}" ]]; then
      echo "Error: Specified local tar file '${LOCAL_TAR}' does not exist."
      exit 1
    fi
    TAR_FILE="${LOCAL_TAR}"
    echo "[2/4] Using local GoldenGate archive: ${TAR_FILE}"
  else
    TAR_FILE=$(mktemp /tmp/goldengate-ora23ai-XXXXXX.tar)
    CLEANUP_TAR=true
    echo "[2/4] Downloading GoldenGate container image from OCI ObjectStorage..."
    echo "URL: ${TAR_URL}"
    curl -L -o "${TAR_FILE}" "${TAR_URL}"
    echo "Download completed: $(du -h "${TAR_FILE}" | cut -f1)"
  fi

  echo "[3/4] Loading container image archive into Docker daemon..."
  LOAD_OUTPUT=$(docker load -i "${TAR_FILE}")
  echo "${LOAD_OUTPUT}"

  LOADED_IMAGE=$(echo "${LOAD_OUTPUT}" | grep -oE "Loaded image: [^ ]+" | awk '{print $3}' | head -n1)
  if [[ -z "${LOADED_IMAGE}" ]]; then
    LOADED_IMAGE="localhost/oracle/goldengate:23.26.2.0.2"
  fi

  echo "[4/4] Tagging & Pushing to GCP Artifact Registry..."
  docker tag "${LOADED_IMAGE}" "${TARGET_IMAGE}"
  docker tag "${LOADED_IMAGE}" "${TARGET_IMAGE_LATEST}"

  gcloud auth configure-docker "${REGISTRY_HOST}" --quiet
  docker push "${TARGET_IMAGE}"
  docker push "${TARGET_IMAGE_LATEST}"

  if [[ "${CLEANUP_TAR}" == true && -f "${TAR_FILE}" ]]; then
    rm -f "${TAR_FILE}"
  fi
fi

# Update terraform.tfvars if present and requested
if [[ "${UPDATE_TFVARS}" == true && -f "${TFVARS_FILE}" ]]; then
  echo "Updating ogg_image in ${TFVARS_FILE} to point to published Artifact Registry URI..."
  if grep -q "ogg_image" "${TFVARS_FILE}"; then
    perl -pi -e 's|^\s*ogg_image\s*=.*|ogg_image           = "'"${TARGET_IMAGE}"'"|' "${TFVARS_FILE}"
  else
    echo "ogg_image           = \"${TARGET_IMAGE}\"" >> "${TFVARS_FILE}"
  fi
  echo "Updated ${TFVARS_FILE} successfully."
fi

echo "================================================================="
echo " SUCCESS: Oracle GoldenGate image successfully published!"
echo " Published Image URIs:"
echo "   - ${TARGET_IMAGE}"
echo "   - ${TARGET_IMAGE_LATEST}"
echo "================================================================="
