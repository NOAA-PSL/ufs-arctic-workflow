#!/bin/bash

set -e -x -o pipefail

yyyy=${CDATE:0:4}
mm=${CDATE:4:2}
dd=${CDATE:6:2}
hh=${CDATE:8:2}

#sssss=$((hh*60*60))
sssss=10800

python interp_replay_ice.py \
    --cdate     $CDATE \
    --outdir    $ICE_RUN_DIR/intercom/ \
    --src_grid  $ICE_GRID_DIR/grid/tripole.mx025.nc \
    --src_data  $ICE_GRID_DIR/ics/iced.$yyyy-$mm-$dd-$sssss.nc \
    --dst_grid  $ICE_GRID_DIR/grid/ocean_grid.nc \
    --dst_mask  $ICE_GRID_DIR/grid/kmtu_cice_NEMS_mxarctic.nc
#    --wfile     $ICE_GRID_DIR/
