#!/bin/bash

: << 'EXPEDITED_TESTING'

When developing playbooks and scripts, it may not be important to run orachk.

What is needed during  development is to have a facsimile that provides the outputs
needed for testing, but takes seconds rather than minutes

Enable this with by adding this parameter to check-oracle.sh:  ' --extra-vars "expedited_testing=true" '

EXPEDITED_TESTING


timestamp=$(date +%Y-%m-%d_%H-%m-%S)

# not really a zip file
testRptFile="/tmp/orachk-quick-test_${timestamp}.zip"

echo "this is a dummy orachk report" > $testRptFile

echo "UPLOAD this file if necessary $testRptFile"
