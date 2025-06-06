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
  echo "No secret provided." >&2
  echo "Usage: $0 <secret_path1> <secret_path2> ..." >&2
  exit 1
fi

valid_secret_path_regex='^projects/[^/]+/secrets/[^/]+/versions/[^/]+$'
for secret_path in "$@"; do
  if [[ ! "$secret_path" =~ $valid_secret_path_regex ]]; then
    echo "Error: '$secret_path' is not a valid secret path." >&2
    echo "Expected format: projects/<project>/secrets/<secret_name>/versions/<version>" >&2
    exit 1
  fi
done

declare -a passwords=()
for secret in "$@"; do
  secret_value="$(gcloud --quiet secrets versions access "${secret_path}")"
  if [[ -z "$secret_value" ]]; then
    # gcloud prints errors to stderr
    exit 1
  fi
  passwords+=("$secret_value")
done

# Only reached if ALL secrets were fetched successfully
for password in "${passwords[@]}"; do
  echo "$password"
done
