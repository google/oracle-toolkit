#!/bin/bash
set -e

echo "=== Starting ZDM Node Setup ==="

# 1. Update OS and Install Prerequisites
echo "Installing prerequisite packages..."
dnf install -y unzip expect glibc-devel libaio libnsl ncurses-compat-libs perl-interpreter

# 2. Create ZDM OS Group and User
if ! getent group zdm >/dev/null; then
  groupadd zdm
  echo "Group 'zdm' created."
fi

if ! getent passwd zdmuser >/dev/null; then
  useradd -g zdm -m -s /bin/bash zdmuser
  echo "User 'zdmuser' created."
fi

# 3. Create ZDM Directories
echo "Creating ZDM directories..."
mkdir -p /u01/zdm/zdmhome
mkdir -p /u01/zdm/zdmbase
mkdir -p /u01/zdm/zdminstall

# 4. Set Environment Variables for zdmuser
echo "Configuring zdmuser environment..."
cat << 'EOF' >> /home/zdmuser/.bashrc

# Oracle ZDM Environment Variables
export ZDM_BASE=/u01/zdm/zdmbase
export ZDM_HOME=/u01/zdm/zdmhome
export PATH=$PATH:$ZDM_HOME/bin
EOF

# Adjust ownership
chown -R zdmuser:zdm /u01/zdm

# 5. Fetch and Install ZDM Software (if bucket and zip are specified)
ZDM_BUCKET="${zdm_software_bucket}"
ZDM_ZIP="${zdm_software_zip}"

if [ -n "$ZDM_BUCKET" ] && [ -n "$ZDM_ZIP" ]; then
  echo "Downloading ZDM software from gs://$ZDM_BUCKET/$ZDM_ZIP ..."
  
  # Run as zdmuser to avoid root-owned files in installer directory
  su - zdmuser -c "gsutil cp gs://$ZDM_BUCKET/$ZDM_ZIP /u01/zdm/zdminstall.zip"
  
  echo "Extracting ZDM installation package..."
  su - zdmuser -c "unzip -q /u01/zdm/zdminstall.zip -d /u01/zdm/zdminstall/"
  
  # Verify if zdminstall.sh exists
  if [ -f "/u01/zdm/zdminstall/zdminstall.sh" ]; then
    echo "Running ZDM installation script..."
    su - zdmuser -c "cd /u01/zdm/zdminstall && ./zdminstall.sh setup oraclehome=\$ZDM_HOME oraclebase=\$ZDM_BASE ziploc=/u01/zdm/zdminstall/zdm_home.zip"
    
    echo "Starting ZDM Service..."
    su - zdmuser -c "\$ZDM_HOME/bin/zdmservice start"
    
    echo "Verifying ZDM Service..."
    su - zdmuser -c "\$ZDM_HOME/bin/zdmservice status"
  else
    echo "ERROR: zdminstall.sh not found inside the ZIP. Manual installation required."
  fi
else
  echo "ZDM software bucket or ZIP not specified. Skipping automated install."
  echo "Please upload ZDM zip to /u01/zdm/zdminstall.zip, extract, and run:"
  echo "  ./zdminstall.sh setup oraclehome=\$ZDM_HOME oraclebase=\$ZDM_BASE ziploc=\$PWD/zdm_home.zip"
fi

# 6. Install Docker (optional, for GoldenGate containers)
INSTALL_DOCKER="${install_docker}"
if [ "$INSTALL_DOCKER" == "true" ]; then
  echo "Installing Docker CE..."
  dnf config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo
  dnf install -y docker-ce docker-ce-cli containerd.io
  systemctl enable --now docker
  usermod -aG docker zdmuser
  echo "Docker CE installed and zdmuser added to docker group."
fi

echo "=== ZDM Node Setup Completed ==="
