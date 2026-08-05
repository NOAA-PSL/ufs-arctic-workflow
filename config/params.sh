#!/bin/bash

# --- Atmosphere Resolution Settings ---
case "$ATM_RES" in
  "C185")
    NPX=156
    NPY=126
    BLOCKSIZE=24
    LAYOUT="9,5"
    WRITETASKS=75
    MEDPETS=80
    ATMPETS=120
    ;;
  "C918")
    NPX=726
    NPY=576
    BLOCKSIZE=29
    LAYOUT="25,25"
    WRITETASKS=25
    MEDPETS=240
    ATMPETBND=650
    ;;
  *)
    echo "Unsupported ATM_RES: $ATM_RES"
    exit 1
    ;;
esac

# --- Ocean/Ice Resolution Settings ---
case "$OCN_RES" in
  "ARC12")
    NIGLOBAL=540
    NJGLOBAL=696
    DTBT=-0.9
    TOPO_FILE="patch.ocean_topog.nc"
    OCNPETS=80
    ICEPETS=40
    ICEBLOCKX=108
    ICEBLOCKY=87
    TIDEDISS="True"
    VARPENSW="True"
    CHL_BLOCK='CHL_FILE = "seawifs-clim-1997-2010.smoothed.nc\nPEN_SW_NBANDS = 3" !'
    ;;
  "ARC0p08")
    NIGLOBAL=1568
    NJGLOBAL=2112
    DTBT=-0.7
    TOPO_FILE="ocean_topog.nc"
    OCNPETS=150
    ICEPETS=96
    ICEBLOCKX=196
    ICEBLOCKY=176
    TIDEDISS="False"
    VARPENSW="False"
    CHL_BLOCK=$'EXP_OPACITY_SCHEME = "SINGLE_EXP"\nPEN_SW_NBANDS = 1\nPEN_SW_FRAC = 0.42\nPEN_SW_SCALE = 15.0\n!CHL_FILE = "seawifs-clim-1997-2010.smoothed.nc" !'
    ;;
  *)
    echo "Unsupported OCN_RES: $OCN_RES"
    exit 1
    ;;
esac

MEDMIN=0
MEDMAX=$((MEDMIN+MEDPETS-1))
ATMMIN=0
ATMMAX=$((ATMMIN+ATMPETS-1))
OCNMIN=$((ATMMAX+1))
OCNMAX=$((OCNMIN+OCNPETS-1))
ICEMIN=$((OCNMAX+1))
ICEMAX=$((ICEMIN+ICEPETS-1))

NTASKSPN=120
NTASKS=$((ATMPETS+OCNPETS+ICEPETS))
NODES=$(( (NTASKS + NTASKSPN - 1) / NTASKSPN ))
