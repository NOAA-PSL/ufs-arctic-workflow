#!/bin/bash
set -e -o pipefail

if [[ "$VERBOSE" == "true" ]]; then
    set -x
fi

rm -rf atm
rm -rf ocn
rm -rf ice
rm -rf intercom
