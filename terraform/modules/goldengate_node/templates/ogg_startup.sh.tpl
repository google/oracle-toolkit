#!/bin/bash
set -e

echo "=== Starting GoldenGate Service Node Startup Configuration ==="

# 1. Update OS Package Repositories and Install Prerequisites
echo "Installing prerequisite packages..."
dnf install -y unzip expect glibc-devel libaio libnsl ncurses-compat-libs perl-interpreter openssh-clients

# 2. Create GoldenGate OS User and Group
echo "Creating GoldenGate user and group..."
groupadd ogggroup
useradd -g ogggroup -m -s /bin/bash ogguser

# Create directory structures
mkdir -p /u01/app/goldengate/ogghome
mkdir -p /u01/app/goldengate/oggbase
mkdir -p /u01/app/goldengate/trails

# Initialize local disk if attached
if [ -L "/dev/disk/by-id/google-ogg-disk" ]; then
  echo "Formatting GoldenGate Trails volume..."
  mkfs.xfs /dev/disk/by-id/google-ogg-disk
  mount -o noatime /dev/disk/by-id/google-ogg-disk /u01/app/goldengate
  echo "/dev/disk/by-id/google-ogg-disk /u01/app/goldengate xfs noatime 0 0" >> /etc/fstab
fi

# Set ownership
chown -R ogguser:ogggroup /u01/app/goldengate
chmod -R 775 /u01/app/goldengate

# Add environment variables to ogguser bash profile
cat <<EOF >> /home/ogguser/.bashrc
export OGG_HOME=/u01/app/goldengate/ogghome
export OGG_BASE=/u01/app/goldengate/oggbase
export PATH=\$PATH:\$OGG_HOME/bin
export LD_LIBRARY_PATH=\$OGG_HOME/lib
EOF

echo "=== GoldenGate Service Node Configuration Completed ==="
