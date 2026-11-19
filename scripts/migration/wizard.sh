#!/bin/bash
# Oracle to GCP Migration Configuration Wizard

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "================================================================="
echo "        Oracle Database to GCP Migration Wizard & Generator      "
echo "================================================================="

# Helper function to read input with default value
prompt_var() {
  local var_name=$1
  local prompt_text=$2
  local default_value=$3
  local user_val

  read -p "$prompt_text [$default_value]: " user_val
  if [ -z "$user_val" ]; then
    eval "$var_name=\"$default_value\""
  else
    eval "$var_name=\"$user_val\""
  fi
}

# 1. Select ZDM Running Environment
echo ""
echo "Select ZDM Running Environment:"
echo " 1) GCE Standard VM (Dedicated VM running ZDM in GCP)"
echo " 2) GKE Private Cluster (ZDM running as a Pod in GKE)"
read -p "Choose option [1-2]: " ZDM_ENV_OPT

case $ZDM_ENV_OPT in
  1) TARGET_ENV="gce"; TARGET_DESC="ZDM GCE VM Environment" ;;
  2) TARGET_ENV="gke"; TARGET_DESC="ZDM GKE Pod Environment" ;;
  *) echo "❌ Invalid selection."; exit 1 ;;
esac

# 2. Select Target Database Type
echo ""
echo "Select Target Database Type:"
echo " 1) Co-managed Oracle DB on GCE VM"
echo " 2) Autonomous Database Serverless (ADB-S)"
echo " 3) Exadata Database Service (ExaCS)"
echo " 4) Base Database Service VM (DBCS)"
read -p "Choose option [1-4]: " TARGET_DB_OPT

case $TARGET_DB_OPT in
  1) TARGET_TYPE="gce" ;;
  2) TARGET_TYPE="adb-s" ;;
  3) TARGET_TYPE="exacs" ;;
  4) TARGET_TYPE="dbcs" ;;
  *) echo "❌ Invalid selection."; exit 1 ;;
esac

# 3. Select Migration Method
echo ""
echo "Select Migration Method Type:"
if [ "$TARGET_TYPE" == "adb-s" ]; then
  echo " * Target ADB-S detected. Only Logical Migration is supported."
  METHOD_OPT="logical"
else
  echo " 1) Physical Migration (RMAN block replica / Data Guard standby)"
  echo " 2) Logical Migration (Data Pump schema export / GoldenGate replication)"
  read -p "Choose option [1-2]: " MET_OPT
  if [ "$MET_OPT" -eq 1 ]; then
    METHOD_OPT="physical"
  else
    METHOD_OPT="logical"
  fi
fi

# 4. Select Online vs. Offline
echo ""
echo "Select Synchronization Timing:"
echo " 1) Online Migration (Near-Zero Downtime using live active replica/replication)"
echo " 2) Offline Migration (Downtime maintenance window, copy and restore)"
read -p "Choose option [1-2]: " SYNC_OPT
if [ "$SYNC_OPT" -eq 1 ]; then
  SYNC_MODE="online"
else
  SYNC_MODE="offline"
fi

# Detect current config defaults from gcloud login
GCLOUD_PROJECT=$(gcloud config get-value project 2>/dev/null || true)
GCLOUD_REGION=$(gcloud config get-value compute/region 2>/dev/null || true)
GCLOUD_ZONE=$(gcloud config get-value compute/zone 2>/dev/null || true)

DEFAULT_PROJECT=${GCLOUD_PROJECT:-"my-gcp-project"}
DEFAULT_REGION=${GCLOUD_REGION:-"europe-west3"}
DEFAULT_ZONE=${GCLOUD_ZONE:-"europe-west3-a"}

echo ""
echo "=== Configuring Setup Parameters for $TARGET_DESC ==="
prompt_var "PROJECT_ID" "GCP Project ID" "$DEFAULT_PROJECT"
prompt_var "REGION" "GCP Region" "$DEFAULT_REGION"
while true; do
  prompt_var "ZONE" "GCP Zone" "$DEFAULT_ZONE"
  if [[ "$ZONE" =~ ^"$REGION"- ]]; then
    break
  else
    echo "❌ ERROR: Zone '$ZONE' is not in region '$REGION'."
    echo "   Please select a zone that starts with '$REGION-' (e.g., '${REGION}-a', '${REGION}-b')."
    DEFAULT_ZONE="${REGION}-a"
  fi
done
DEFAULT_BUCKET="my-zdm-migration-bucket-${PROJECT_ID}"
prompt_var "BUCKET_NAME" "GCS Bucket Name (for trail/backups)" "$DEFAULT_BUCKET"
prompt_var "SSH_KEY" "Public SSH Key file path" "$HOME/.ssh/id_rsa.pub"

if [ -f "$SSH_KEY" ]; then
  SSH_KEY_VAL=$(cat "$SSH_KEY")
else
  SSH_KEY_VAL="ssh-rsa MOCK_KEY_REPLACE_ME"
fi

prompt_var "SOURCE_IP" "Source Oracle Database IP" "10.10.1.5"

# Prepare tfvars at the repository root directory
TFVARS_FILE="$ROOT_DIR/terraform/environments/$TARGET_ENV/terraform.tfvars"

cat <<EOF > "$TFVARS_FILE"
# Generated automatically by wizard
project_id          = "$PROJECT_ID"
region              = "$REGION"
zone                = "$ZONE"
bucket_name         = "$BUCKET_NAME"
ssh_public_key      = "$SSH_KEY_VAL"
source_db_ips       = ["$SOURCE_IP"]
target_type         = "$TARGET_TYPE"
deployment_mode     = "$TARGET_ENV"
EOF

# Append GCE-specific running environment values
if [ "$TARGET_ENV" == "gce" ]; then
  if [ "$METHOD_OPT" == "logical" ] && [ "$SYNC_MODE" == "online" ]; then
    prompt_var "INSTALL_DK" "Install Docker on ZDM VM for GoldenGate containers? (true/false)" "true"
  else
    INSTALL_DK="false"
  fi
  cat <<EOF >> "$TFVARS_FILE"
install_docker      = $INSTALL_DK
EOF
fi

# Append GKE-specific running environment values
if [ "$TARGET_ENV" == "gke" ]; then
  PRIV_KEY_FILE="${SSH_KEY%.pub}"
  if [ -f "$PRIV_KEY_FILE" ]; then
    SSH_PRIV_KEY_VAL=$(cat "$PRIV_KEY_FILE")
  else
    SSH_PRIV_KEY_VAL="-----BEGIN OPENSSH PRIVATE KEY-----\nMOCK_KEY_REPLACE_ME\n-----END OPENSSH PRIVATE KEY-----"
  fi

  prompt_var "ZDM_IMAGE" "ZDM GKE Container Image URL" "gcr.io/$PROJECT_ID/zdm-service:latest"
  prompt_var "DEPLOY_GG" "Deploy GoldenGate in GKE? (true/false)" "false"
  
  cat <<EOF >> "$TFVARS_FILE"
zdm_image           = "$ZDM_IMAGE"
deploy_goldengate   = $DEPLOY_GG
ssh_private_key     = <<EOT
$SSH_PRIV_KEY_VAL
EOT
EOF
  if [ "$DEPLOY_GG" == "true" ]; then
    prompt_var "OGG_IMAGE" "GoldenGate Hub Image URL" "${REGION:-europe-west3}-docker.pkg.dev/$PROJECT_ID/oracle-migration/goldengate:23.26.2.0.2"
    cat <<EOF >> "$TFVARS_FILE"
ogg_image           = "$OGG_IMAGE"
EOF
  fi
fi



# Ask target-specific parameters
case $TARGET_TYPE in
  "gce")
    prompt_var "TARGET_IP" "Target Oracle Database VM IP" "10.20.1.10"
    cat <<EOF >> "$TFVARS_FILE"
target_db_ips       = ["$TARGET_IP"]
EOF
    ;;
  "adb-s")
    prompt_var "ADB_ENDPOINT" "Target ADB-S Connection Endpoint (e.g. adb_high)" "adb_high"
    cat <<EOF >> "$TFVARS_FILE"
adb_target_endpoint = "$ADB_ENDPOINT"
EOF
    TARGET_IP="adb-s-endpoint"
    ;;
  "exacs")
    prompt_var "EXACS_IPS" "List of Target ExaCS Node IPs (comma-separated)" "10.152.1.11,10.152.1.12"
    IPS_FORMAT=$(echo "$EXACS_IPS" | sed 's/,/","/g')
    cat <<EOF >> "$TFVARS_FILE"
exacs_target_node_ips = ["$IPS_FORMAT"]
EOF
    TARGET_IP=$(echo "$EXACS_IPS" | cut -d',' -f1)
    ;;
  "dbcs")
    prompt_var "DBCS_IPS" "List of Target DBCS Node IPs (comma-separated)" "10.154.1.5"
    IPS_FORMAT=$(echo "$DBCS_IPS" | sed 's/,/","/g')
    cat <<EOF >> "$TFVARS_FILE"
dbcs_target_db_ips    = ["$IPS_FORMAT"]
EOF
    TARGET_IP=$(echo "$DBCS_IPS" | cut -d',' -f1)
    ;;
esac

# Ask optional Oracle Database@Google Cloud target infrastructure creation
echo ""
echo "=== 🏗️ Oracle Database@Google Cloud Target Infrastructure Orchestration ==="
prompt_var "CREATE_ODB_INFRA" "Provision ODB Network & Subnets automatically via Terraform? (true/false)" "false"

if [ "$CREATE_ODB_INFRA" == "true" ]; then
  prompt_var "ODB_NET_ID" "ODB Network ID" "odb-network"
  prompt_var "ODB_CLIENT_CIDR" "ODB Client Subnet CIDR" "10.150.20.0/24"
  prompt_var "ODB_BACKUP_CIDR" "ODB Backup Subnet CIDR" "10.150.21.0/24"
  
  cat <<EOF >> "$TFVARS_FILE"
create_odb_infrastructure = true
odb_network_id            = "$ODB_NET_ID"
odb_client_subnet_cidr   = "$ODB_CLIENT_CIDR"
odb_backup_subnet_cidr   = "$ODB_BACKUP_CIDR"
EOF
else
  cat <<EOF >> "$TFVARS_FILE"
create_odb_infrastructure = false
EOF
fi

if [ "$TARGET_TYPE" == "dbcs" ]; then
  prompt_var "CREATE_DBCS" "Provision target Base DB System (DBCS) via Terraform? (true/false)" "false"
  if [ "$CREATE_DBCS" == "true" ]; then
    prompt_var "DBCS_ID" "DB System ID" "odb-db-system"
    prompt_var "DB_ADMIN_PW" "SYS/SYSTEM Admin Password" "SecretPassword123#"
    prompt_var "TDE_PW" "TDE Wallet Password" "SecretPassword123#"
    cat <<EOF >> "$TFVARS_FILE"
create_target_dbsystem    = true
db_system_id              = "$DBCS_ID"
db_admin_pw               = "$DB_ADMIN_PW"
tde_pw                    = "$TDE_PW"
EOF
  fi
elif [ "$TARGET_TYPE" == "exacs" ]; then
  prompt_var "CREATE_EXA" "Provision target Exadata Infra & VM Cluster via Terraform? (true/false)" "false"
  if [ "$CREATE_EXA" == "true" ]; then
    prompt_var "EXA_INFRA_ID" "Exadata Infrastructure ID" "exa-infra-1"
    prompt_var "EXA_VMC_ID" "Exadata VM Cluster ID" "exa-vmcluster-1"
    cat <<EOF >> "$TFVARS_FILE"
create_target_exadata     = true
cloud_exadata_infrastructure_id = "$EXA_INFRA_ID"
cloud_vm_cluster_id        = "$EXA_VMC_ID"
EOF
  fi
elif [ "$TARGET_TYPE" == "adb-s" ] || [ "$TARGET_TYPE" == "adb" ]; then
  prompt_var "CREATE_ADB" "Provision target Autonomous Database (ADB-S) via Terraform? (true/false)" "false"
  if [ "$CREATE_ADB" == "true" ]; then
    prompt_var "ADB_ID" "Autonomous Database ID" "odb-adb-1"
    prompt_var "ADB_PW" "ADB Admin Password" "SecretPassword123#"
    cat <<EOF >> "$TFVARS_FILE"
create_target_adb         = true
autonomous_database_id     = "$ADB_ID"
adb_admin_pw               = "$ADB_PW"
EOF
  fi
fi

echo "✓ Created $TFVARS_FILE successfully."

# 5. Generate Migration Execution Script
EXEC_SCRIPT="$ROOT_DIR/terraform/environments/$TARGET_ENV/run_migration.sh"

if [ "$METHOD_OPT" == "physical" ]; then
  RSP_FILE="/u01/zdm/zdmbase/zdm_physical.rsp"
  ZDM_CMD="zdmcli migrate database \\
  -rsp $RSP_FILE \\
  -sourcenode $SOURCE_IP \\
  -sourcesid orcl \\
  -targetnode $TARGET_IP \\
  -tgtdbconnection $TARGET_IP:1521/tgtdbsvc"
else
  RSP_FILE="/u01/zdm/zdmbase/zdm_logical.rsp"
  ZDM_CMD="zdmcli migrate database \\
  -rsp $RSP_FILE \\
  -sourcenode $SOURCE_IP \\
  -sourcesid orcl \\
  -targetnode $TARGET_IP"
fi

if [ "$SYNC_MODE" == "online" ]; then
  ZDM_CMD="$ZDM_CMD \\
  -pauseafter ZDM_CONFIGURE_DG_SRC"
fi

if [ "$TARGET_ENV" == "gke" ]; then
  GKE_DEPLOYMENT_BLOCK=$(cat <<EOF_GKE
# 1. GKE Credentials
echo "Fetching GKE cluster credentials..."
gcloud container clusters get-credentials zdm-gke-cluster --zone "$ZONE" --project "$PROJECT_ID"

# 2. Render and Deploy Kubernetes Manifests
echo "Deploying ZDM workloads inside GKE..."
export PROJECT_ID="$PROJECT_ID"
export ZDM_IMAGE="$ZDM_IMAGE"
export SSH_PRIVATE_KEY_INDENTED="\$(echo "$SSH_PRIV_KEY_VAL" | sed 's/^/    /')"
export SSH_PUBLIC_KEY_INDENTED="\$(echo "$SSH_KEY_VAL" | sed 's/^/    /')"

# Render ZDM workloads manifest
python3 -c "import os, sys; print(os.path.expandvars(sys.stdin.read()))" < "\$ROOT_DIR/terraform/environments/gke/manifests/zdm_workload.yaml.tpl" > "/tmp/zdm_workload.yaml"
kubectl apply -f "/tmp/zdm_workload.yaml"

if [ "$DEPLOY_GG" == "true" ]; then
  echo "Deploying GoldenGate Hub workload inside GKE..."
  export OGG_IMAGE="$OGG_IMAGE"
  python3 -c "import os, sys; print(os.path.expandvars(sys.stdin.read()))" < "\$ROOT_DIR/terraform/environments/gke/manifests/ogg_workload.yaml.tpl" > "/tmp/ogg_workload.yaml"
  kubectl apply -f "/tmp/ogg_workload.yaml"
fi

# 3. Wait for ZDM Pod to be ready
echo "Waiting for ZDM Pod to be in Running status..."
kubectl rollout status deployment/zdm-deployment -n zdm-migration --timeout=300s
EOF_GKE
)
else
  GKE_DEPLOYMENT_BLOCK=""
fi

cat <<EOF > "$EXEC_SCRIPT"
#!/bin/bash
# ZDM Migration Execution command generated by wizard
# Target: $TARGET_TYPE ($METHOD_OPT $SYNC_MODE)

SCRIPT_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="\$(cd "\$SCRIPT_DIR/.." && pwd)"

echo "=== Commencing Oracle ZDM Migration to GCP ==="
echo "Target Platform: $TARGET_TYPE"
echo "Method: $METHOD_OPT | Mode: $SYNC_MODE"

$GKE_DEPLOYMENT_BLOCK

# 1. Run Pre-checks validation
if [ -f "\$ROOT_DIR/tests/validate_zdm_${METHOD_OPT}_prechecks.sh" ]; then
  echo "Running connectivity validations..."
  "\$ROOT_DIR/tests/validate_zdm_${METHOD_OPT}_prechecks.sh" "$SOURCE_IP" "$TARGET_IP" "gs://$BUCKET_NAME"
  if [ \$? -ne 0 ]; then
    echo "❌ Connectivity validations failed. Aborting."
    exit 1
  fi
fi

# 2. Run ZDM migration execution command
echo "Executing ZDM CLI command..."
if [ "$TARGET_ENV" == "gke" ]; then
  ZDM_POD=\$(kubectl get pods -n zdm-migration -l app=zdm-service -o jsonpath="{.items[0].metadata.name}")
  kubectl exec -n zdm-migration -it "\$ZDM_POD" -- $ZDM_CMD
else
  $ZDM_CMD
fi

echo "=== ZDM command submitted successfully ==="
EOF

chmod +x "$EXEC_SCRIPT"
echo "✓ Generated ZDM execution run script at $EXEC_SCRIPT."
echo "================================================================="
echo "Configuration complete. To deploy the infrastructure, run:"
echo "   terraform init && terraform apply"
echo "================================================================="
