#!/bin/bash

# This script attempts to fetch Oracle database passwords from the given secret path(s).
# The expected format for each secret path is:
#   projects/<project>/secrets/<secret_name>/versions/<version>
#
# This script is not intended to be executed manually, but instead is designed to run as part of the
# `roles/db-create/tasks/main.yml` Ansible playbook.
#
# Usage context: The fetched passwords are piped to the input of dbca, like so:
#   fetch_db_passwords.sh projects/<project>/secrets/<secret_name>/versions/<version> | dbca ...
#
# To prevent any error messages from being misinterpreted as passwords, all error messages are printed to stderr.
#
# The script either prints all fetched secret values to stdout or none at all.


if [[ $# -eq 0 ]]; then
  echo "No secret paths provided." >&2
  echo "Usage: $0 <secret_path1> <secret_path2> ..." >&2
  exit 1
fi

valid_secret_path_regex='^projects/[^/]+/secrets/[^/]+/versions/[^/]+$'
for secret_path in "$@"; do
  if [[ ! $secret_path =~ $valid_secret_path_regex ]]; then
    echo "Error: '$secret_path' is not a valid secret path." >&2
    echo "Expected format: projects/<project>/secrets/<secret_name>/versions/<version>" >&2
    exit 1
  fi
done


fetch_access_token() {
  access_token_json="$(curl -sS -H "Metadata-Flavor: Google" "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token")"
  if [[ -z "$access_token_json" ]]; then
    echo "curl failed to fetch access token" >&2
    return 1
  fi

  access_token="$(echo "$access_token_json" | jq -r '.access_token')"
  if [[ -z "$access_token" || "$access_token" == "null" ]]; then
    echo "Failed to extract access token from JSON response" >&2
    return 1
  fi

  echo "$access_token"
}

BASE_URL="https://secretmanager.googleapis.com/v1"

fetch_secret() {
  local url="$BASE_URL/$1:access"
  local token="$2"
  local json

  json="$(curl -sS -H "Authorization: Bearer $token" "$url")"
  if [[ -z "$json" ]]; then
    echo "curl failed to retrieve secret from $url" >&2
    return 1
  fi

  if echo "$json" | jq -e '.error' > /dev/null; then
    echo "Metadata server returned an error for $url" >&2
    echo "HTTP response: $json" >&2
    return 1
  fi

  local encoded
  encoded="$(echo "$json" | jq -er '.payload.data')"
  if [[ -z "$encoded" || "$encoded" == "null"  ]]; then
    echo "jq failed to extract .payload.data from $url" >&2
    return 1
  fi

  local decoded
  decoded="$(echo "$encoded" | base64 --decode 2>/dev/null)"
  if [[ -z "$decoded" ]]; then
    echo "base64 decode failed for $url" >&2
    return 1
  fi

  echo "$decoded"
}


declare -a passwords=()

access_token="$(fetch_access_token)"

for secret_path in "$@"; do
  secret_value="$(fetch_secret "$secret_path" "$access_token")"
  if [[ -z "$secret_value" ]]; then
    # fetch_secret prints errors to stderr
    exit 1
  fi
  passwords+=("$secret_value")
done

# Only reached if ALL secrets were fetched successfully
for password in "${passwords[@]}"; do
  echo "$password"
done