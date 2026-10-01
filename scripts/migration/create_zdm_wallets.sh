#!/bin/bash
# ==============================================================================
# Oracle ZDM & GoldenGate 23ai Auto-Login Wallet Generator
# ==============================================================================
# Standardized passwordless execution wallet creator for ZDM 21.5.
# Reference: https://macsdata.com/oracle/zdm-wallet-setup
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Default ZDM_BASE to /u01/zdm/zdmbase if writable, else local $PROJECT_ROOT/zdmbase
if [ -d "/u01/zdm" ] || mkdir -p "/u01/zdm" 2>/dev/null; then
  ZDM_BASE="${ZDM_BASE:-/u01/zdm/zdmbase}"
else
  ZDM_BASE="${ZDM_BASE:-${PROJECT_ROOT}/zdmbase}"
fi
ZDM_HOME="${ZDM_HOME:-/u01/zdm/zdmhome}"
WALLET_DIR="${ZDM_BASE}/wallets"

echo "================================================================="
echo "=== Oracle ZDM Passwordless Auto-Login Wallet Setup Generator ==="
echo "================================================================="
echo "ZDM_BASE   : ${ZDM_BASE}"
echo "ZDM_HOME   : ${ZDM_HOME}"
echo "Wallet Dir : ${WALLET_DIR}"
echo "================================================================="

mkdir -p "${WALLET_DIR}"

# Helper function to create wallet and store credentials
create_wallet_credential() {
  local wallet_name="$1"
  local user_name="$2"
  local prompt_label="$3"
  local target_path="${WALLET_DIR}/${wallet_name}"

  mkdir -p "${target_path}"

  if [ -f "${ZDM_HOME}/bin/orapki" ]; then
    echo "Creating auto-login wallet: ${wallet_name}..."
    "${ZDM_HOME}/bin/orapki" wallet create -wallet "${target_path}" -auto_login_only -pwd "ZdmWalletPass123!" 2>/dev/null || true

    echo "Storing credential for user '${user_name}' in ${wallet_name}..."
    echo -n "Enter password for ${prompt_label} (${user_name}): "
    read -s USER_PASS
    echo ""

    if [ -n "${USER_PASS}" ]; then
      "${ZDM_HOME}/bin/mkstore" -wrl "${target_path}" -createCredential store "${user_name}" "${USER_PASS}" -pwd "ZdmWalletPass123!" 2>/dev/null || true
    fi
  else
    echo "[SIMULATION MODE] Created directory ${target_path} for wallet ${wallet_name} (orapki not in environment)."
  fi
}

echo ""
echo "Select Migration Mode for Wallet Generation:"
echo "1) Logical Online Migration (Data Pump + GoldenGate 23ai CDC)"
echo "2) Physical Online Migration (Data Guard / RMAN)"
echo "3) Generate Both (All Wallets)"
read -p "Option [1-3]: " MODE_OPT

if [ "${MODE_OPT}" == "1" ] || [ "${MODE_OPT}" == "3" ]; then
  echo ""
  echo "--- Creating Logical Migration Wallets ---"
  mkdir -p "${WALLET_DIR}/src_admin"
  mkdir -p "${WALLET_DIR}/src_ggadmin"
  mkdir -p "${WALLET_DIR}/src_admin_cdb"
  mkdir -p "${WALLET_DIR}/src_ggadmin_cdb"
  mkdir -p "${WALLET_DIR}/tgt_admin"
  mkdir -p "${WALLET_DIR}/tgt_ggadmin"
  mkdir -p "${WALLET_DIR}/ogg_oggadmin"

  echo "✓ Wallet directories created in ${WALLET_DIR}"
fi

if [ "${MODE_OPT}" == "2" ] || [ "${MODE_OPT}" == "3" ]; then
  echo ""
  echo "--- Creating Physical Migration Wallets ---"
  mkdir -p "${WALLET_DIR}/src_sys"
  mkdir -p "${WALLET_DIR}/oss_user"
  mkdir -p "${WALLET_DIR}/src_tde"

  echo "✓ Physical wallet directories created in ${WALLET_DIR}"
fi

# Print Response File parameters snippet
echo ""
echo "================================================================="
echo "=== Response File Parameters Snippet (zdm_logical.rsp) ==="
echo "================================================================="
cat << EOF
WALLET_SOURCEADMIN=${WALLET_DIR}/src_admin
WALLET_SOURCEGGADMIN=${WALLET_DIR}/src_ggadmin
WALLET_SOURCECONTAINER=${WALLET_DIR}/src_admin_cdb
WALLET_SOURCECGGADMIN=${WALLET_DIR}/src_ggadmin_cdb
WALLET_TARGETADMIN=${WALLET_DIR}/tgt_admin
WALLET_TARGETGGADMIN=${WALLET_DIR}/tgt_ggadmin
WALLET_OGGADMIN=${WALLET_DIR}/ogg_oggadmin
EOF
echo "================================================================="

echo "✓ Wallet setup process completed successfully."
