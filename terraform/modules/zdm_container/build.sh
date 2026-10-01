#!/bin/bash
set -e

# GoldenGate & ZDM Container Build Script
# This script downloads the ZDM software ZIP from a GCS bucket, builds the Docker image, and cleans up.

usage() {
  echo "Usage: $0 -b <gcs_bucket> -z <zdm_zip_file> -t <image_tag>"
  echo "  -b: GCS Bucket name where ZDM installer is stored"
  echo "  -z: ZDM installer ZIP file name (e.g., V1035502-01.zip)"
  echo "  -t: Target Docker image tag (e.g., gcr.io/my-project/zdm-service:latest)"
  exit 1
}

while getopts "b:z:t:" opt; do
  case "$opt" in
    b) BUCKET="$OPTARG" ;;
    z) ZIP_FILE="$OPTARG" ;;
    t) IMAGE_TAG="$OPTARG" ;;
    *) usage ;;
  esac
done

if [ -z "$BUCKET" ] || [ -z "$ZIP_FILE" ] || [ -z "$IMAGE_TAG" ]; then
  usage
fi

echo "=== Packaging Containerized Oracle ZDM ==="
echo "GCS Source: gs://$BUCKET/$ZIP_FILE"
echo "Image Tag : $IMAGE_TAG"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 1. Download ZDM installer ZIP
echo "Downloading ZDM software zip from Google Cloud Storage..."
gsutil cp "gs://$BUCKET/$ZIP_FILE" ./zdminstall.zip

# 2. Build the Docker Image
echo "Building Docker image..."
docker build -t "$IMAGE_TAG" .

# 3. Clean up the downloaded ZIP from the build context
echo "Cleaning up local installation files..."
rm -f ./zdminstall.zip

echo "=== Container Image Built Successfully: $IMAGE_TAG ==="
EOF
