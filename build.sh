#!/bin/bash
# Copyright 2025 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

ARTIFACT_NAME="oracle-toolkit-infra-manager.zip"
ARTIFACT_DIR="unsigned-release"
ARTIFACT_PATH="${ARTIFACT_DIR}/${ARTIFACT_NAME}"

echo "This is usage_metrics branch"
echo "Starting Oracle Toolkit Terraform Blueprint generation."

echo "Current working directory: $(pwd)"
if [[ "$(pwd)" != *"/oracle-toolkit" ]]; then
 echo "Error: Script is not running from the root of the cloned repository."
 exit 1
fi

if [ ! -d "${ARTIFACT_DIR}" ]; then
  echo "Creating directory: ${ARTIFACT_DIR}"
  mkdir -p "${ARTIFACT_DIR}"
fi
if [ ! -w "${ARTIFACT_DIR}" ]; then
  echo "Error: Directory ${ARTIFACT_DIR} is not writable."
  exit 1
fi

if [ -f "${ARTIFACT_PATH}" ]; then
  echo "Removing existing package: ${ARTIFACT_PATH}"
  rm "${ARTIFACT_PATH}"
fi

echo "Creating the initial ZIP package: ${ARTIFACT_PATH}."
zip -r "${ARTIFACT_PATH}" . -x "${ARTIFACT_DIR}/*" -x "*.git*" -x "*.terraform*" -x "terraform/*"

echo "Adding terraform directory contents to the package root."
cd terraform
zip -r --grow "../${ARTIFACT_PATH}" . -x "*.example" -x "terraform.tfvars"

echo "Oracle Toolkit Terraform Blueprint generation process completed."
