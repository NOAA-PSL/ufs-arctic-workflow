#!/bin/bash

NAMELIST_FILE="config.in"

if [[ -f "$NAMELIST_FILE" ]]; then
    source "$NAMELIST_FILE"
else
    echo "Namelist file $NAMELIST_FILE not found!"
    exit 1
fi

mkdir -p ${WORKhafs}/intercom/grid/${CASE}
${NLN} ${ATMGRIDdir}/* ${WORKhafs}/intercom/grid/${CASE}/.

./exhafs_atm_ic.sh
./exhafs_atm_lbc.sh
