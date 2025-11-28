#!/usr/bin/env bash

unzipcheck() {
  local zipfile="$1"
  local targetdir="$2"
  local size
  local free_bytes
  local need

  if [[ -z "$zipfile" ]]; then
    echo "Error: Missing zip file argument." >&2
    return 1
  fi

  if [[ ! -d "$targetdir" ]]; then
    targetdir=$(dirname "$targetdir")
    if [[ ! -d "$targetdir" ]]; then
      echo "Error: Cannot check space. Neither '$targetdir' nor its parent exist." >&2
      return 1
    fi
  fi

  size=$(unzip -l "$zipfile" 2>/dev/null | tail -n 1 | awk '{print $1}')
  if [[ -z "$size" || ! "$size" =~ ^[0-9]+$ || "$size" -eq 0 ]]; then
    echo "Error: Could not read uncompressed size from '$zipfile'." >&2
    return 1
  fi

  free_bytes=$(( $(df -Pk "$targetdir" | awk 'NR==2 {print $4}') * 1024 ))
  need=$(( size + (size / 10) ))  # Safety margin of an additional 10%

  if (( need > free_bytes )); then
    echo "Not enough space! Need ~$need bytes, have $free_bytes bytes." >&2
    return 1
  fi
}

ORIG_ARGS=("$@")
ZIP_FILE=""
TARGET_DIR="."  # Default to current directory

while [[ $# -gt 0 ]]; do
  case "$1" in
    -d)
      if [[ -n "$2" ]]; then
        TARGET_DIR="$2"
        shift 2
      else
        echo "Error: Missing directory argument after -d." >&2
        exit 1
      fi
      ;;
    -*)
      # Ignore other flags (like -o, -q) for the purpose of our check
      shift
      ;;
    *)
      # The first non-flag argument is assumed to be the zip file
      if [[ -z "$ZIP_FILE" ]]; then
        ZIP_FILE="$1"
      fi
      shift
      ;;
  esac
done

if unzipcheck "$ZIP_FILE" "$TARGET_DIR"; then
  echo "Starting unzip..."
  # Pass the original array to preserve flags we ignored (like -o or -q)
  unzip "${ORIG_ARGS[@]}"
else
  echo "Space check failed. Aborting without unzipping." >&2
  exit 1
fi
