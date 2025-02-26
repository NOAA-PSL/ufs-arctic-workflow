#!/bin/bash

###
# Script Name: remap_OBCs.sh
# Author: Kristin Barton (UFS Arctic Team)
# Contact: Kristin.Barton@noaa.gov
# Description:
#   This is the driver for the ocean boundary condition remapping steps. 
#   This script is called by the setup script, but can be run in isolation
###

# !!! EDIT srun details if needed
APRUNS=${APRUNS-"srun --mem=0 --ntasks=1 --nodes=1 --ntasks-per-node=1 --cpus-per-task=1 --account=gsienkf"}

INPUT_DIR=${INPUT_DIR-"inputs/"}
FIX_DIR=${FIX_DIR-"fix/${OCNgrid}/"}
OUTPUT_DIR=${OUTPUT_DIR-"intercom/"}

OUT_FILE_PATH_BASE=${OUTPUT_DIR}${OUT_FILE_BASE-"mom6_OBC_"}
WGT_FILE_PATH_BASE=${FIX_DIR}${WGT_FILE_BASE-"rtofs2hgrid_"}
ANG_FILE_PATH_BASE=${FIX_DIR}${ANGLE_FILE_PATH_BASE-"ocean_hgrid_"}
HGD_FILE_PATH_BASE=${FIX_DIR}${ANGLE_FILE_PATH_BASE-"ocean_hgrid_"}
FILE_TAIL=${FILE_TAIL-".nc"}

VRT_FILE_PATH=${FIX_DIR}${VRT_FILE-"ocean_vgrid.nc"}

SSH_VARNAME=${SSH_VARNAME-"ssh"}
SSH_SRC_FILE_PATH=${INPUT_DIR}${SSH_SRC_FILE-"rtofs.f12_global_ssh_obc.nc"}

TMP_VARNAME=${TMP_VARNAME-"pot_temp"}
TMP_VARNAME_OUT=${TMP_VARNAME_OUT-"temp"}
SAL_VARNAME=${SAL_VARNAME-"salinity"}
TS_SRC_FILE_PATH=${INPUT_DIR}${TS_SRC_FILE-"rtofs.f12_global_ts_obc.nc"}

U_VARNAME=${U_VARNAME-"u"}
V_VARNAME=${V_VARNAME-"v"}
UV_SRC_FILE_PATH=${INPUT_DIR}${UV_SRC_FILE-"rtofs.f12_global_uv_obc.nc"}

ANGLE_VARNAME=${ANGLE_VARNAME-"angle_dx"}
ANGLE_SRC_FILE_PATH=${FIX_DIR}${ANGLE_SRC_FILE-"ocean_hgrid.nc"}
CONVERT_ANGLE=${CONVERT_ANGLE-"False"}

DZ_VARNAME=${DZ_VARNAME-"dz"}
TIME_VARNAME=${TIME_VARNAME-"MT"}
TIME_VARNAME_OUT=${TIME_VARNAME_OUT-"time"}

start=1
end=4

##########################
# SSH Variable Remapping #
##########################

echo "Calling remapping script for SSH Variable"
for i in $(seq -f "%03g" $start $end); do
    echo "Interpolating ${i}"
    WGT_FILE_PATH="${WGT_FILE_PATH_BASE}${i}${FILE_TAIL}"
    OUT_FILE_PATH="${OUT_FILE_PATH_BASE}${i}${FILE_TAIL}"

    ${APRUNS} python rtofs_to_mom6.py \
        --var_name $SSH_VARNAME \
        --src_file ${SSH_SRC_FILE_PATH} \
        --wgt_file ${WGT_FILE_PATH} \
        --vrt_file ${VRT_FILE_PATH} \
        --out_file ${OUT_FILE_PATH} \
        --dz_name ${DZ_VARNAME} \
        --time_name ${TIME_VARNAME} \
        --time_name_out ${TIME_VARNAME_OUT}
done
echo ""

##################################
# Temperature Variable Remapping #
##################################

echo "Calling remapping script for Temperature Variable"
for i in $(seq -f "%03g" $start $end); do
    echo "Interpolating ${i}"
    WGT_FILE_PATH="${WGT_FILE_PATH_BASE}${i}${FILE_TAIL}"
    OUT_FILE_PATH="${OUT_FILE_PATH_BASE}${i}${FILE_TAIL}"
    ${APRUNS} python rtofs_to_mom6.py \
        --var_name $TMP_VARNAME \
        --var_name_out $TMP_VARNAME_OUT \
        --src_file ${TS_SRC_FILE_PATH} \
        --wgt_file ${WGT_FILE_PATH} \
        --vrt_file ${VRT_FILE_PATH} \
        --out_file ${OUT_FILE_PATH} \
        --dz_name ${DZ_VARNAME} \
        --time_name ${TIME_VARNAME} \
        --time_name_out ${TIME_VARNAME_OUT}
done
echo ""

###############################
# Salinity Variable Remapping #
###############################

echo "Calling remapping script for Salinity Variable"
for i in $(seq -f "%03g" $start $end); do
    echo "Interpolating ${i}"
    WGT_FILE_PATH="${WGT_FILE_PATH_BASE}${i}${FILE_TAIL}"
    OUT_FILE_PATH="${OUT_FILE_PATH_BASE}${i}${FILE_TAIL}"
    ${APRUNS} python rtofs_to_mom6.py \
        --var_name $SAL_VARNAME \
        --src_file ${TS_SRC_FILE_PATH} \
        --wgt_file ${WGT_FILE_PATH} \
        --vrt_file ${VRT_FILE_PATH} \
        --out_file ${OUT_FILE_PATH} \
        --dz_name ${DZ_VARNAME} \
        --time_name ${TIME_VARNAME} \
        --time_name_out ${TIME_VARNAME_OUT}
done
echo ""

#######################
# UV-Vector Remapping #
#######################

echo "Calling remapping script for U-V vectors"
for i in $(seq -f "%03g" $start $end); do
    echo "Interpolating ${i}"
    WGT_FILE_PATH="${WGT_FILE_PATH_BASE}${i}${FILE_TAIL}"
    OUT_FILE_PATH="${OUT_FILE_PATH_BASE}${i}${FILE_TAIL}"
    ANG_FILE_PATH="${ANG_FILE_PATH_BASE}${i}${FILE_TAIL}"
    ${APRUNS} python rtofs_to_mom6.py \
        --var_name $U_VARNAME $V_VARNAME $ANGLE_VARNAME \
        --src_file ${UV_SRC_FILE_PATH} ${UV_SRC_FILE_PATH} ${ANG_FILE_PATH} \
        --wgt_file ${WGT_FILE_PATH} \
        --vrt_file ${VRT_FILE_PATH} \
        --out_file ${OUT_FILE_PATH} \
        --dz_name ${DZ_VARNAME} \
        --time_name ${TIME_VARNAME} \
        --time_name_out ${TIME_VARNAME_OUT}
#        --convert_angle_to_center ${CONVERT_ANGLE}
done
echo ""

#######################
# Format netcdf files #
#######################

echo "Formatting OBC files"
for i in $(seq -f "%03g" $start $end); do
    echo "Reformatting OBC_${i}"
    HGRID_PATH="${HGD_FILE_PATH_BASE}${i}.nc"
    OBC_PATH="${OUT_FILE_PATH_BASE}${i}.nc"

    ncrename -O -d dz,nz_segment_${i} -d yh,ny_segment_${i} -d xh,nx_segment_${i} -v ssh,ssh_segment_${i} -v temp,temp_segment_${i} -v salinity,salinity_segment_${i} -v u,u_segment_${i} -v v,v_segment_${i} ${OBC_PATH}
#    ncrename -O -d dz,nz_segment_${i} -d yh,ny_segment_${i} -d xh,nx_segment_${i} -v ssh,ssh_segment_${i} ${OBC_PATH}

    ncap2 -O -s "ssh_segment_${i}[${TIME_VARNAME_OUT},nz_segment_${i},ny_segment_${i},nx_segment_${i}] = ssh_segment_${i}(:,:,:);" ${OBC_PATH} ${OBC_PATH}

    ncap2 -O -s "dz_u_segment_${i}[${TIME_VARNAME_OUT},nz_segment_${i},ny_segment_${i},nx_segment_${i}]=dz(:)" ${OBC_PATH} ${OBC_PATH}
    ncap2 -O -s "dz_v_segment_${i}[${TIME_VARNAME_OUT},nz_segment_${i},ny_segment_${i},nx_segment_${i}]=dz(:)" ${OBC_PATH} ${OBC_PATH} 
    ncap2 -O -s "dz_ssh_segment_${i}[${TIME_VARNAME_OUT},nz_segment_${i},ny_segment_${i},nx_segment_${i}]=dz(:)" ${OBC_PATH} ${OBC_PATH}
    ncap2 -O -s "dz_salinity_segment_${i}[${TIME_VARNAME_OUT},nz_segment_${i},ny_segment_${i},nx_segment_${i}]=dz(:)" ${OBC_PATH} ${OBC_PATH}
    ncap2 -O -s "dz_temp_segment_${i}[${TIME_VARNAME_OUT},nz_segment_${i},ny_segment_${i},nx_segment_${i}]=dz(:)" ${OBC_PATH} ${OBC_PATH}

    ncks -O -x -v dz ${OBC_PATH} ${OBC_PATH} > /dev/null 2>&1

    if [ "$i" -eq "001" ] || [ "$i" -eq "002" ]; then
        ncap2 -A -v -s "lon_segment_${i}[nxp]=x(0,:)" ${HGRID_PATH} tmp.nc
        ncap2 -A -v -s "lat_segment_${i}[nxp]=y(0,:)" ${HGRID_PATH} tmp.nc
    fi
    if [ "$i" -eq "003" ] || [ "$i" -eq "004" ]; then
        ncap2 -A -v -s "lon_segment_${i}[nyp]=x(:,0)" ${HGRID_PATH} tmp.nc
        ncap2 -A -v -s "lat_segment_${i}[nyp]=y(:,0)" ${HGRID_PATH} tmp.nc
    fi

    ncrename -d nxp,nx_segment_${i} -d nyp,ny_segment_${i} tmp.nc

    ncap2 -A -v -s "lon_segment_${i}=lon_segment_${i}" tmp.nc ${OBC_PATH}
    ncap2 -A -v -s "lat_segment_${i}=lat_segment_${i}" tmp.nc ${OBC_PATH}

    rm tmp.nc
done

