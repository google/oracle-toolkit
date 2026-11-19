#!/bin/bash
set -e

echo "=== Starting Target Oracle DB VM Post-Install Configuration ==="

# 1. Create Oracle Groups and Users
echo "Creating Oracle system groups and users..."
groupadd -g 54321 oinstall
groupadd -g 54322 dba
groupadd -g 54323 oper
groupadd -g 54324 backupdba
groupadd -g 54325 dgdba
groupadd -g 54326 kmdba
groupadd -g 54327 racdba

useradd -u 54321 -g oinstall -G dba,oper,backupdba,dgdba,kmdba -m -s /bin/bash oracle
mkdir -p /home/oracle/.ssh
chmod 700 /home/oracle/.ssh

# Set temporary password (user should change this on login)
echo "oracle:OracleGceTarget123#" | chpasswd

# 2. Disk Storage Initialization using LVM
echo "Formatting and mounting Oracle Disk Volumes..."

# Wait for disk links to appear in /dev/disk/by-id/
sleep 10

# Initialize and mount /u01 (binaries)
if [ -L "/dev/disk/by-id/google-oracle-u01" ]; then
  pvcreate /dev/disk/by-id/google-oracle-u01
  vgcreate vg_u01 /dev/disk/by-id/google-oracle-u01
  lvcreate -l 100%FREE -n lv_u01 vg_u01
  mkfs.xfs /dev/mapper/vg_u01-lv_u01
  mkdir -p /u01
  mount -o noatime,nodiratime,logbufs=8 /dev/mapper/vg_u01-lv_u01 /u01
  echo "/dev/mapper/vg_u01-lv_u01 /u01 xfs noatime,nodiratime,logbufs=8 0 0" >> /etc/fstab
fi

# Initialize and mount /u02 (datafiles)
if [ -L "/dev/disk/by-id/google-oracle-data" ]; then
  pvcreate /dev/disk/by-id/google-oracle-data
  vgcreate vg_data /dev/disk/by-id/google-oracle-data
  lvcreate -l 100%FREE -n lv_data vg_data
  mkfs.xfs /dev/mapper/vg_data-lv_data
  mkdir -p /u02
  mount -o noatime,nodiratime,logbufs=8 /dev/mapper/vg_data-lv_data /u02
  echo "/dev/mapper/vg_data-lv_data /u02 xfs noatime,nodiratime,logbufs=8 0 0" >> /etc/fstab
fi

# Initialize and mount /u03 (recovery/redo)
if [ -L "/dev/disk/by-id/google-oracle-reco" ]; then
  pvcreate /dev/disk/by-id/google-oracle-reco
  vgcreate vg_reco /dev/disk/by-id/google-oracle-reco
  lvcreate -l 100%FREE -n lv_reco vg_reco
  mkfs.xfs /dev/mapper/vg_reco-lv_reco
  mkdir -p /u03
  mount -o noatime,nodiratime,logbufs=8 /dev/mapper/vg_reco-lv_reco /u03
  echo "/dev/mapper/vg_reco-lv_reco /u03 xfs noatime,nodiratime,logbufs=8 0 0" >> /etc/fstab
fi

# Apply correct ownership
chown -R oracle:oinstall /u01 /u02 /u03
chmod -R 775 /u01 /u02 /u03

# 3. Configure OS Kernel Settings (sysctl.conf)
echo "Applying Oracle Database Kernel Limits..."
cat <<EOF >> /etc/sysctl.conf
# Oracle Database Settings
fs.file-max = 6815744
kernel.sem = 250 32000 100 128
kernel.shmmax = 17179869184
kernel.shmall = 4194304
kernel.shmmni = 4096
panic_on_oops = 1
net.ipv4.ip_local_port_range = 9000 65500
net.core.rmem_default = 262144
net.core.rmem_max = 4194304
net.core.wmem_default = 262144
net.core.wmem_max = 1048576
fs.aio-max-nr = 1048576
vm.swappiness = 1
vm.dirty_background_ratio = 3
vm.dirty_ratio = 80
EOF

sysctl -p

# 4. Configure Resource Security Limits (limits.conf)
echo "Applying User limits..."
cat <<EOF >> /etc/security/limits.conf
oracle   soft   nofile    1024
oracle   hard   nofile    65536
oracle   soft   nproc     2047
oracle   hard   nproc     16384
oracle   soft   stack     10240
oracle   hard   stack     32768
oracle   soft   memlock   134217728
oracle   hard   memlock   134217728
EOF

# 5. Configure HugePages (Recommended 50% of memory for SGA)
echo "Calculating HugePages configurations..."
TOTAL_RAM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
# Setup Hugepages to allocate ~50% of system RAM
PAGE_SIZE_KB=2048
SGA_SIZE_KB=$((TOTAL_RAM_KB * 50 / 100))
HUGEPAGES_COUNT=$((SGA_SIZE_KB / PAGE_SIZE_KB))

echo "vm.nr_hugepages = $HUGEPAGES_COUNT" >> /etc/sysctl.conf
sysctl -p

echo "=== Target Oracle DB VM Configuration Completed ==="
