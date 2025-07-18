#!/bin/bash
# Copyright 2020 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


# disable globbing
set -f
# password length or 1st parameter
PWLEN="${1:-16}"
# password symbol set or 2nd parameter
PWSYM="${2:-@+~*}"

# must start with alpha
FCHAR="$(cat /dev/urandom | tr -dc [:alpha:] | head -c1)"
# have an uppercase letter
UCHAR="$(cat /dev/urandom | tr -dc [:upper:] | head -c1)"
# have a lowercase letter
LCHAR="$(cat /dev/urandom | tr -dc [:lower:] | head -c1)"
# have a digit
DCHAR="$(cat /dev/urandom | tr -dc [:digit:] | head -c1)"
# have a symbol
SCHAR="$(cat /dev/urandom | tr -dc ${PWSYM} | head -c1)"
# upper, lower, digit, some symbols
RCHAR="$(cat /dev/urandom | tr -dc [:alnum:]${PWSYM} | head -c$((PWLEN - 6)))"
# wrap the symbol into the password
RPASS="$(echo "${UCHAR}${LCHAR}${DCHAR}${SCHAR}${RCHAR}" | fold -c -w1 | shuf | tr -d '\n')"

echo "${FCHAR}${RPASS}${FCHAR}"
