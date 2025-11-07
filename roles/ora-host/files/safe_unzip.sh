#!/usr/bin/env bash

# Function to check if there is enough disk space to unzip the file
unzipcheck() {
  local zipfile="$1"
  local targetdir="${2:-.}"
  if [[ -z "$zipfile" ]]; then
    echo "Error: Missing zip file argument (usage: unzipcheck <zipfile> [targetdir])." 1>&2
    return 1
  fi
  local size=$(unzip -l "$zipfile" 2>/dev/null | awk 'NR>3 {s+=$1} END {print s+0}')
  if [[ -z "$size" || "$size" -eq 0 ]]; then
    echo "Error: Could not read uncompressed size from '$zipfile'." 1>&2
    return 1
  fi
  local free=$(df -Pk "$targetdir" | awk 'NR==2 {print $4*1024}')
  local need=$(( size + size / 10 ))  # Safety margin of an additional 10%
  if (( need > free )); then
    echo "Not enough space! Need ~$need bytes, have $free bytes." 1>&2
    return 1
  fi
}

# Process command line arguments to extract file name and target directory
ORIG_ARGS=("$@")
for ((i=0; i<${#ORIG_ARGS[@]}; i++)); do
  ARG="${ORIG_ARGS[i]}"
  NEXT_ARG="${ORIG_ARGS[i+1]}"
  case "$ARG" in
    -d)
      if [[ -n "$NEXT_ARG" ]]; then
        TARGET_DIR="$NEXT_ARG"
        i=$((i+1))
      else
        echo "Error: Missing directory argument after -d." 1>&2
        exit 1
      fi
      ;;
    -*)
      ;;
    *)
      if [[ -z "$ZIP_FILE" ]]; then
        ZIP_FILE="$ARG"
      fi
      ;;
  esac
done

# Run the unzipcheck function and proceed with unzipping if there is enough space
if unzipcheck "$ZIP_FILE" $(dirname "$TARGET_DIR"); then
  echo "Starting unzip..."
  unzip "${ORIG_ARGS[@]}"
else
  echo "Space check failed. Aborting without unzipping." 1>&2
  exit 1
fi
