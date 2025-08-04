#!/bin/bash
set -e -x -o pipefail

###
# Script Name: remap_OBCs.sh
# Author: Kristin Barton (UFS Arctic Team)
# Contact: Kristin.Barton@noaa.gov
# Description:
#   This is the driver for the ocean boundary condition remapping steps. 
#   This script is called by the setup script, but can be run in isolation
###
CDATE=${CDATE:-'2020082512'}
HH=`echo $CDATE | cut -c 9-10`
NHRS=${NHRS:-'6'}
NOCNBDYHRS=${NOCNBDYHRS:-'6'}
FHR=0
FHRI=0

# !!! EDIT srun details if needed
APRUNS=${APRUNS:-"srun --mem=0 --ntasks=1 --nodes=1 --ntasks-per-node=1 --cpus-per-task=1 --account=${SACCT}"}

INPUT_DIR=${OCN_RUN_DIR}/inputs/
OUTPUT_DIR=${OCN_RUN_DIR}/intercom/

OUT_FILE_PATH_BASE=${OUTPUT_DIR}${OUT_FILE_BASE:-"mom6_OBC_"}
WGT_FILE_PATH_BASE=${INPUT_DIR}${WGT_FILE_BASE:-"gefs2arctic"}
DST_ANG_FILE_PATH_BASE=${INPUT_DIR}${ANGLE_FILE_PATH_BASE:-"ocean_hgrid_"}
HGD_FILE_PATH_BASE=${INPUT_DIR}${ANGLE_FILE_PATH_BASE:-"ocean_hgrid_"}
FILE_TAIL=${FILE_TAIL:-".nc"}

SSH_VARNAME=${SSH_VARNAME:-"ssh"}
SSH_SRC_FILE_PATH="${INPUT_DIR}${SSH_SRC_FILE:-"rtofs_global_ssh_ic.nc"}"

TMP_VARNAME=${TMP_VARNAME:-"pot_temp"}
TMP_VARNAME_OUT=${TMP_VARNAME_OUT:-"temp"}
TMP_SRC_FILE_PATH="${INPUT_DIR}${TMP_SRC_FILE:-"rtofs_global_ts_ic.nc"}"

SAL_VARNAME=${SAL_VARNAME:-"salinity"}
SAL_SRC_FILE_PATH="${INPUT_DIR}${SAL_SRC_FILE:-"rtofs_global_ts_ic.nc"}"

U_VARNAME=${U_VARNAME:-"u"}
U_SRC_FILE_PATH="${INPUT_DIR}${U_SRC_FILE:-"rtofs_global_uv_ic.nc"}"

V_VARNAME=${V_VARNAME:-"v"}
V_SRC_FILE_PATH="${INPUT_DIR}${V_SRC_FILE:-"rtofs_global_uv_ic.nc"}"

SRC_ANG_NAME=${SRC_ANG_NAME:-"angle_dx"}
SRC_ANG_FILE_PATH="${INPUT_DIR}${SRC_ANG_FILE:-"ocean_hgrid.nc"}"
SRC_CONVERT_ANG=${SRC_CONVERT_ANG:-"True"}

DST_ANG_NAME=${DST_ANG_NAME:-"angle_dx"}
DST_CONVERT_ANG=${DST_CONVERT_ANG:-"True"}

SRC_VRT_NAME=${SRC_VRT_NAME:-"dz"}
SRC_VRT_FILE_PATH="${INPUT_DIR}${SRC_VRT_FILE:-"ocean_vgrid.nc"}"

DST_VRT_NAME=${DST_VRT_NAME:-"dz"}
DST_VRT_FILE_PATH="${INPUT_DIR}${DST_VRT_FILE:-"ocean_vgrid.nc"}"

TIME_VARNAME=${TIME_VARNAME:-"MT"}
TIME_VARNAME_OUT=${TIME_VARNAME_OUT:-"time"}

start=1
end=4

#while [ $FHR -lt ${NHRS} ]; do
#echo "Doing remapping for time step ${FHR}/${NHRS}"
#NEWDATE=$(${NDATE} +${FHR} $CDATE)
#HH=$(echo $NEWDATE | cut -c9-10)
#echo $NEWDATE
#echo $HH
#echo $FHRI

########################
## UV-Vector Remapping #
########################

echo "Calling remapping script for U-V vectors"
for i in $(seq -f "%03g" $start $end); do
    echo "Interpolating ${i}"
    WGT_FILE_PATH="${WGT_FILE_PATH_BASE}_${i}${FILE_TAIL}"
    OUT_FILE_PATH="${OUT_FILE_PATH_BASE}${i}${FILE_TAIL}"
    DST_ANG_FILE_PATH="${DST_ANG_FILE_PATH_BASE}${i}${FILE_TAIL}"
    ${APRUNS} python rtofs_to_mom6.py \
        --var_name $U_VARNAME $V_VARNAME \
        --src_file ${U_SRC_FILE_PATH} ${V_SRC_FILE_PATH} \
        --src_ang_name ${SRC_ANG_NAME} \
        --src_ang_file ${SRC_ANG_FILE_PATH} \
        --src_ang_supergrid ${SRC_CONVERT_ANG} \
        --dst_ang_name ${DST_ANG_NAME} \
        --dst_ang_file ${DST_ANG_FILE_PATH} \
        --dst_ang_supergrid ${DST_CONVERT_ANG} \
        --wgt_file ${WGT_FILE_PATH} \
        --vrt_file ${DST_VRT_FILE_PATH} \
        --out_file ${OUT_FILE_PATH} \
        --dz_name ${DST_VRT_NAME} \
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
    WGT_FILE_PATH="${WGT_FILE_PATH_BASE}_${i}${FILE_TAIL}"
    OUT_FILE_PATH="${OUT_FILE_PATH_BASE}${i}${FILE_TAIL}"
    ${APRUNS} python rtofs_to_mom6.py \
        --var_name ${TMP_VARNAME} \
        --src_file ${TMP_SRC_FILE_PATH} \
        --wgt_file ${WGT_FILE_PATH} \
        --vrt_file ${DST_VRT_FILE_PATH} \
        --out_file ${OUT_FILE_PATH} \
        --dz_name ${DST_VRT_NAME} \
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
    WGT_FILE_PATH="${WGT_FILE_PATH_BASE}_${i}${FILE_TAIL}"
    OUT_FILE_PATH="${OUT_FILE_PATH_BASE}${i}${FILE_TAIL}"
    ${APRUNS} python rtofs_to_mom6.py \
        --var_name ${SAL_VARNAME} \
        --src_file ${SAL_SRC_FILE_PATH} \
        --wgt_file ${WGT_FILE_PATH} \
        --vrt_file ${DST_VRT_FILE_PATH} \
        --out_file ${OUT_FILE_PATH} \
        --dz_name ${DST_VRT_NAME} \
        --time_name ${TIME_VARNAME} \
        --time_name_out ${TIME_VARNAME_OUT} 
done
echo ""

##########################
# SSH Variable Remapping #
##########################

echo "Calling remapping script for SSH Variable"
for i in $(seq -f "%03g" $start $end); do
    echo "Interpolating ${i}"
    WGT_FILE_PATH="${WGT_FILE_PATH_BASE}_${i}${FILE_TAIL}"
    OUT_FILE_PATH="${OUT_FILE_PATH_BASE}${i}${FILE_TAIL}"

    ${APRUNS} python rtofs_to_mom6.py \
        --var_name ${SSH_VARNAME} \
        --src_file ${SSH_SRC_FILE_PATH} \
        --wgt_file ${WGT_FILE_PATH} \
        --vrt_file ${DST_VRT_FILE_PATH} \
        --out_file ${OUT_FILE_PATH} \
        --dz_name ${DST_VRT_NAME} \
        --time_name ${TIME_VARNAME} \
        --time_name_out ${TIME_VARNAME_OUT} 
done
echo ""

#FHR=$((FHR+NOCNBDYHRS))
#FHRI=$((FHRI+1))
#done # Finish all forecast steps

#######################
# Format netcdf files #
#######################

echo "Formatting OBC files"
for i in $(seq -f "%03g" $start $end); do
    echo "Reformatting OBC_${i}"
    HGRID_PATH="${HGD_FILE_PATH_BASE}${i}.nc"
    OBC_PATH="${OUT_FILE_PATH_BASE}${i}.nc"

    ncrename -O -d ${DST_VRT_NAME},nz_segment_${i} -d yh,ny_segment_${i} -d xh,nx_segment_${i} -v ${SSH_VARNAME},ssh_segment_${i} -v ${TMP_VARNAME},temp_segment_${i} -v ${SAL_VARNAME},salinity_segment_${i} -v ${U_VARNAME},u_segment_${i} -v ${V_VARNAME},v_segment_${i} ${OBC_PATH}
#    ncrename -O -d dz,nz_segment_${i} -d yh,ny_segment_${i} -d xh,nx_segment_${i} -v ssh,ssh_segment_${i} ${OBC_PATH}

#    ncap2 -O -s "ssh_segment_${i}[${TIME_VARNAME_OUT},ny_segment_${i},nx_segment_${i}] = ssh_segment_${i}(:,:,:);" ${OBC_PATH} ${OBC_PATH}

    ncap2 -O -s "dz_u_segment_${i}[${TIME_VARNAME_OUT},nz_segment_${i},ny_segment_${i},nx_segment_${i}]=${DST_VRT_NAME}(:)" ${OBC_PATH} ${OBC_PATH}
    ncap2 -O -s "dz_v_segment_${i}[${TIME_VARNAME_OUT},nz_segment_${i},ny_segment_${i},nx_segment_${i}]=${DST_VRT_NAME}(:)" ${OBC_PATH} ${OBC_PATH} 
    ncap2 -O -s "dz_ssh_segment_${i}[${TIME_VARNAME_OUT},nz_segment_${i},ny_segment_${i},nx_segment_${i}]=${DST_VRT_NAME}(:)" ${OBC_PATH} ${OBC_PATH}
    ncap2 -O -s "dz_salinity_segment_${i}[${TIME_VARNAME_OUT},nz_segment_${i},ny_segment_${i},nx_segment_${i}]=${DST_VRT_NAME}(:)" ${OBC_PATH} ${OBC_PATH}
    ncap2 -O -s "dz_temp_segment_${i}[${TIME_VARNAME_OUT},nz_segment_${i},ny_segment_${i},nx_segment_${i}]=${DST_VRT_NAME}(:)" ${OBC_PATH} ${OBC_PATH}

    ncks -O -x -v ${DST_VRT_NAME} ${OBC_PATH} ${OBC_PATH} > /dev/null 2>&1

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

