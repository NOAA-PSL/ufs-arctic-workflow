#!/bin/bash

# --- Atmosphere Resolution Settings ---
case "$ATM_RES" in
  "C185")
    NPX=156
    NPY=126
    BLOCKSIZE=24
    LAYOUT="9,5"
    NODES=6
    NTASKSPN=40
    NTASKS=240
    TIME="3:00:00"
    WRITETASKS=75
    MEDPETBND="0 80"
    ATMPETBND="0 119"
    OCNPETBND="120 199"
    ICEPETBND="200 239"
    ;;
  "C918")
    NPX=726
    NPY=576
    BLOCKSIZE=29
    LAYOUT="25,25"
    NODES=7
    NTASKSPN=120
    NTASKS=840
    TIME="4:00:00"
    WRITETASKS=25
    MEDPETBND="0 239"
    ATMPETBND="0 649"
    OCNPETBND="650 799"
    ICEPETBND="800 839"
    ;;
  *)
    echo "Unsupported ATM_RES: $ATM_RES"
    exit 1
    ;;
esac

# --- Ocean/Ice Resolution Settings ---
#case "$OCN_RES" in
#  "ARC12")
#    NIGLOBAL=540
#    NJGLOBAL=696
#    OCN_DT=120
#    OCN_TASKS=80
#    ICE_TASKS=40
#    TOPO_FILE="patch.ocean_topo.nc"
#    ;;
#  *)
#    echo "Unsupported OCN_RES: $OCN_RES"
#    exit 1
#    ;;
#esac
