#!/bin/bash
source presubmit_tests/infra-manager-lib.sh || {
  echo "Error: cannot source common library" >&2
  exit 1
}
instance_name="github-presubmit-26ai-dg-${BUILD_ID}"
deployment_name="presubmit-26ai-dg-${BUILD_ID}"
tfvars_file="./presubmit_tests/26ai-dg.tfvars"
location="us-central1"
setup_vars
apply_deployment
watch_logs
