#!/bin/bash
set -e

echo "=== Starting ZDM Container Entrypoint ==="

# Populate mounted volume from template if crsdata is empty or missing
if [ -d "/u01/zdm/zdmbase_template" ] && [ ! -d "$ZDM_BASE/crsdata" -o -z "$(ls -A $ZDM_BASE/crsdata 2>/dev/null)" ]; then
  echo "Initializing mounted ZDM_BASE volume from template..."
  cp -r /u01/zdm/zdmbase_template/* "$ZDM_BASE/"
fi

# Map build-time crsdata configuration directory to current pod hostname
CURRENT_HOST=$(hostname)
if [ ! -d "$ZDM_BASE/crsdata/$CURRENT_HOST" ]; then
  BUILD_HOST_DIR=$(ls -d $ZDM_BASE/crsdata/* 2>/dev/null | grep -v "$CURRENT_HOST" | head -n 1)
  if [ -n "$BUILD_HOST_DIR" ] && [ -d "$BUILD_HOST_DIR" ]; then
    echo "Copying ZDM configuration from $BUILD_HOST_DIR to $ZDM_BASE/crsdata/$CURRENT_HOST..."
    cp -r "$BUILD_HOST_DIR" "$ZDM_BASE/crsdata/$CURRENT_HOST"
  fi
fi

# Start the ZDM daemon
echo "Starting ZDM service..."
$ZDM_HOME/bin/zdmservice start

# Give it a few seconds to start up
sleep 5

# Check status
$ZDM_HOME/bin/zdmservice status

echo "ZDM Service is running. Tailing logs to keep container alive..."

# Find the log directory and tail any log files, fallback to tailing /dev/null if none found yet
LOG_DIR="$ZDM_BASE/crsdata/$(hostname)/log"
if [ -d "$LOG_DIR" ]; then
  tail -f "$LOG_DIR"/*.log
else
  # Loop-watch for the directory to appear, then tail it
  echo "Log directory $LOG_DIR not found yet, waiting..."
  for i in {1..10}; do
    if [ -d "$LOG_DIR" ]; then
      tail -f "$LOG_DIR"/*.log
      exit 0
    fi
    sleep 2
  done
  tail -f /dev/null
fi
