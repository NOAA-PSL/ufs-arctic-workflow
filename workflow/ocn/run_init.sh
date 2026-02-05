#!/bin/sh

###
# Script Name: setup_init.sh
# Original Script: exhafs_ocn_prep.sh
# Original Script Authors: NECP/EMC Hurricane Project Team and UFS Hurricane Application Team
# Modified by: Kristin Barton (UFS Arctic Team)
# Contact: Kristin.Barton@noaa.gov
# Description:
#    This has been modified to prepare inputs for MOM6 Arctic grid, including initial conditions,
#    lateral boundary conditions, and data atmosphere forcing.
###

set -e -o pipefail
if [[ "$VERBOSE" == true ]]; then
    set -x
fi

# ----------------------------------------------------------------------------------- #
#                                  Environment Setup                                  #
# ----------------------------------------------------------------------------------- #

# EDIT THIS SECTION AS NEEDED
# These variables are normally set by the run namelist parameters

CDATE=${CDATE}
NHRS=${NHRS}
NOCNBDYHRS=${NOCNBDYHRS}
OCNINTYPE=${OCNINTYPE}
NLN=${NLN}

export APRUNS=${APRUNS}

export OCN_SCRIPT_DIR=${OCN_SCRIPT_DIR}
export OCN_RUN_DIR=${OCN_RUN_DIR}
export OCN_SRC_GRID_NAME=${OCN_SRC_GRID_NAME}
export OCN_DST_GRID_NAME=${OCN_DST_GRID_NAME}
export OCN_SRC_GRID_DIR=${OCN_SRC_GRID_DIR}
export OCN_DST_GRID_DIR=${OCN_DST_GRID_DIR}
export OCN_SRC_DIR=${OCN_SRC_DIR}

COMINrtofs=${COMINrtofs}
COMINgfs=${COMINgfs}
COMINgefs=${COMINgefs}

HAFSdir=${HAFSdir}
FIXhafs=${FIXhafs}
PARMhafs=${PARMhafs}
EXEChafs=${EXEChafs}
USHhafs=${USHhafs}
MODhafs=${MODhafs}

# The rest of the parameters below are set automatically
ymd=`echo $CDATE | cut -c 1-8`
hour=`echo $CDATE | cut -c 9-10`

if [ "${hour}" == "00" ]; then
  type=${type:-n}
else
  type=${type:-f}
fi

# Make the intercom dir
mkdir -p ${OCN_RUN_DIR}/intercom/
mkdir -p ${OCN_RUN_DIR}/inputs/

# Retrive the regridding weights and ocean grid files
mkdir -p ${OCN_RUN_DIR}/inputs/
${NLN} ${OCN_DST_GRID_DIR}/* ${OCN_RUN_DIR}/inputs/.
${NLN} ${OCN_SRC_GRID_DIR}/* ${OCN_RUN_DIR}/inputs/.
${NLN} ${OCN_SCRIPT_DIR}/inputs/* ${OCN_RUN_DIR}/inputs/.

if [ $OCNINTYPE == 'gefs' ]; then
    export WGT_FILE_BASE=${OCN_WGT_FILE_BASE}
    ICFILENAME="${OCN_RUN_DIR}/inputs/Ct.mx025_SCRIP_masked.nc"
    BCFILENAME="${OCN_RUN_DIR}/inputs/Ct.mx025_SCRIP.nc"
    METHOD="neareststod"
    #METHOD="bilinear"
    ${NLN} ${OCN_SRC_DIR}/*.nc ${OCN_RUN_DIR}/inputs/.
fi


# ----------------------------------------------------------------------------------- #
#                                     IC Setup                                        #
# ----------------------------------------------------------------------------------- #

echo ""
echo "Generating ocean IC files"

cd ${OCN_RUN_DIR}/inputs/

if [ $OCNINTYPE == 'rtofs' ]; then
    # Names of output files and Hycom Utilities inputs
    outnc_2d=global_ssh_ic.nc
    outnc_ts=global_ts_ic.nc
    outnc_uv=global_uv_ic.nc
    export CDF038=rtofs_${outnc_2d}
    export CDF034=rtofs_${outnc_ts}
    export CDF033=rtofs_${outnc_uv}
    
    # Link global RTOFS depth and grid files
    ${NLN} ${FIXhafs}/fix_mom6/fix_gofs/depth_GLBb0.08_09m11ob.a regional.depth.a
    ${NLN} ${FIXhafs}/fix_mom6/fix_gofs/depth_GLBb0.08_09m11ob.b regional.depth.b
    ${NLN} ${FIXhafs}/fix_hycom/rtofs_glo.navy_0.08.regional.grid.a regional.grid.a
    ${NLN} ${FIXhafs}/fix_hycom/rtofs_glo.navy_0.08.regional.grid.b regional.grid.b
    
    # Link global RTOFS analysis or forecast files
    if [ -e ${COMINrtofs}/rtofs.$ymd/rtofs_glo.t00z.${type}${hour}.archv.a ]; then
      ${NLN} ${COMINrtofs}/rtofs.$ymd/rtofs_glo.t00z.${type}${hour}.archv.a archv_in.a
    elif [ -e ${COMINrtofs}/rtofs.$ymd/rtofs_glo.t00z.${type}${hour}.archv.a.tgz ]; then
      tar -xpvzf ${COMINrtofs}/rtofs.$ymd/rtofs_glo.t00z.${type}${hour}.archv.a.tgz
      ${NLN} rtofs_glo.t00z.${type}${hour}.archv.a archv_in.a
    else
      echo "FATAL ERROR: ${COMINrtofs}/rtofs.$ymd/rtofs_glo.t00z.${type}${hour}.archv.a does not exist."
      echo "FATAL ERROR: ${COMINrtofs}/rtofs.$ymd/rtofs_glo.t00z.${type}${hour}.archv.a.tgz does not exist either."
      echo "FATAL ERROR: Cannot generate MOM6 IC. Exiting"
      exit 1
    fi
    if [ -e ${COMINrtofs}/rtofs.$ymd/rtofs_glo.t00z.${type}${hour}.archv.b ]; then
      ${NLN} ${COMINrtofs}/rtofs.$ymd/rtofs_glo.t00z.${type}${hour}.archv.b archv_in.b
    else
      echo "FATAL ERROR: ${COMINrtofs}/rtofs.$ymd/rtofs_glo.t00z.${type}${hour}.archv.b does not exist."
      echo "FATAL ERROR: Cannot generate MOM6 IC. Exiting"
      exit 1
    fi
    
    # run HYCOM-tools executables to produce IC netcdf files
    ${APRUNS} ${EXEChafs}/hafs_hycom_utils_archv2ncdf3z.x < ./rtofs_global_3d_ic.in 2>&1 | tee archv2ncdf3z_3d_ic.log
    ${APRUNS} ${EXEChafs}/hafs_hycom_utils_archv2ncdf2d.x < ./rtofs_global_ssh_ic.in 2>&1 | tee ./archv2ncdf2d_ssh_ic.log

    WGT_FILE_BASE='rtofs2arctic'
    ICFILENAME="${OCN_RUN_DIR}/inputs/rtofs_global_ssh_ic.nc"
    METHOD="bilinear"

    # Unlink global RTOFS analysis or forecast files
    unlink archv_in.a
    unlink archv_in.b
fi


if [ ! -e "${OCN_RUN_DIR}/inputs/ocean_subgrid_v.nc" ] && [ ! -e "${OCN_RUN_DIR}/inputs/ocean_subgrid_u.nc" ]; then
    echo "U/V subgrid files do not exist. Creating them..."
    ${OCN_SCRIPT_DIR}/utils/make_subgrids.py --lat y --lon x --fin ocean_hgrid.nc --out ocean_subgrid
fi

if [ ! -e "${OCN_RUN_DIR}/inputs/${WGT_FILE_BASE}_h.nc" ]; then
    echo "File ${WGT_FILE_BASE}_h.nc  does not exist. Creating the file..."
    ${APRUNS} ESMF_RegridWeightGen -s ${ICFILENAME} -d ocean_mask.nc -w ${WGT_FILE_BASE}_h.nc -m ${METHOD} --dst_loc center --netCDF4 --dst_regional --ignore_degenerate 
fi
if [ ! -e "${OCN_RUN_DIR}/inputs/${WGT_FILE_BASE}_v.nc" ]; then
    echo "File ${WGT_FILE_BASE}_v.nc  does not exist. Creating the file..."
    ${APRUNS} ESMF_RegridWeightGen -s ${ICFILENAME} -d ocean_subgrid_v.nc -w ${WGT_FILE_BASE}_v.nc -m ${METHOD} --dst_loc center --netCDF4 --dst_regional --ignore_degenerate
fi
if [ ! -e "${OCN_RUN_DIR}/inputs/${WGT_FILE_BASE}_u.nc" ]; then
    echo "File ${WGT_FILE_BASE}_u.nc  does not exist. Creating the file..."
    ${APRUNS} ESMF_RegridWeightGen -s ${ICFILENAME} -d ocean_subgrid_u.nc -w ${WGT_FILE_BASE}_u.nc -m ${METHOD} --dst_loc center --netCDF4 --dst_regional --ignore_degenerate
fi

cd ${OCN_RUN_DIR}/inputs/

cd ${OCN_SCRIPT_DIR}
./remap_ICs.sh

# ----------------------------------------------------------------------------------- #
#                                   OBC Setup                                         #
# ----------------------------------------------------------------------------------- #

echo ""
echo "Generating ocean OBC files"

cd ${OCN_RUN_DIR}/inputs/

if [ $OCNINTYPE == 'rtofs' ]; then
    # Define output file names and HYCOM variables
    outnc_2d=global_ssh_obc.nc
    outnc_ts=global_ts_obc.nc
    outnc_uv=global_uv_obc.nc
    
    if [ ! -e "${OCN_RUN_DIR}/inputs/${WGT_FILE_BASE}_001.nc" ]; then
        echo "File ${WGT_FILE_BASE}.nc  does not exist. Creating the file..."
        ${APRUNS} ESMF_RegridWeightGen -s ${ICFILENAME} -d ocean_hgrid_001.nc -w ${WGT_FILE_BASE}_001.nc --dst_loc center --netCDF4 --dst_regional --ignore_degenerate
    fi
    if [ ! -e "${OCN_RUN_DIR}/inputs/${WGT_FILE_BASE}_002.nc" ]; then
        echo "File ${WGT_FILE_BASE}_002.nc  does not exist. Creating the file..."
        ${APRUNS} ESMF_RegridWeightGen -s ${ICFILENAME} -d ocean_hgrid_002.nc -w ${WGT_FILE_BASE}_002.nc --dst_loc center --netCDF4 --dst_regional --ignore_degenerate
    fi
    if [ ! -e "${OCN_RUN_DIR}/inputs/${WGT_FILE_BASE}_003.nc" ]; then
        echo "File ${WGT_FILE_BASE}_003.nc  does not exist. Creating the file..."
        ${APRUNS} ESMF_RegridWeightGen -s ${ICFILENAME} -d ocean_hgrid_003.nc -w ${WGT_FILE_BASE}_003.nc --dst_loc center --netCDF4 --dst_regional --ignore_degenerate
    fi
    if [ ! -e "${OCN_RUN_DIR}/inputs/${WGT_FILE_BASE}_004.nc" ]; then
        echo "File ${WGT_FILE_BASE}_004.nc  does not exist. Creating the file..."
        ${APRUNS} ESMF_RegridWeightGen -s ${ICFILENAME} -d ocean_hgrid_004.nc -w ${WGT_FILE_BASE}_004.nc --dst_loc center --netCDF4 --dst_regional --ignore_degenerate
    fi
    
    if [ -e ${COMINrtofs}/rtofs.$ymd/rtofs_glo.t00z.${type}${HH}.archv.a ]; then
      ${NLN} ${COMINrtofs}/rtofs.$ymd/rtofs_glo.t00z.${type}${HH}.archv.a archv_in.a
    elif [ -e ${COMINrtofs}/rtofs.$ymd/rtofs_glo.t00z.${type}${HH}.archv.a.tgz ]; then
      tar -xpvzf ${COMINrtofs}/rtofs.$ymd/rtofs_glo.t00z.${type}${HH}.archv.a.tgz
      ${NLN} rtofs_glo.t00z.${type}${HH}.archv.a archv_in.a
    else
      echo "FATAL ERROR: ${COMINrtofs}/rtofs.$ymd/rtofs_glo.t00z.${type}${HH}.archv.a does not exist."
      echo "FATAL ERROR: ${COMINrtofs}/rtofs.$ymd/rtofs_glo.t00z.${type}${HH}.archv.a.tgz does not exist either."
      echo "FATAL ERROR: Cannot generate MOM6 OBC. Exiting"
      exit 1
    fi
    if [ -e ${COMINrtofs}/rtofs.$ymd/rtofs_glo.t00z.${type}${HH}.archv.b ]; then
      ${NLN} ${COMINrtofs}/rtofs.$ymd/rtofs_glo.t00z.${type}${HH}.archv.b archv_in.b
    else
      echo "FATAL ERROR: ${COMINrtofs}/rtofs.$ymd/rtofs_glo.t00z.${type}${HH}.archv.b does not exist."
      echo "FATAL ERROR: Cannot generate MOM6 OBC. Exiting"
      exit 1
    fi
    
    export CDF038=rtofs.${type}${HH}_${outnc_2d}
    export CDF034=rtofs.${type}${HH}_${outnc_ts}
    export CDF033=rtofs.${type}${HH}_${outnc_uv}
    
    # Run HYCOM-tools executables to produce OBC netcdf files
    ${APRUNS} ${EXEChafs}/hafs_hycom_utils_archv2ncdf2d.x < ./rtofs_global_ssh_obc.in 2>&1 | tee ./archv2ncdf2d_ssh_obc.log
    ${APRUNS} ${EXEChafs}/hafs_hycom_utils_archv2ncdf3z.x < ./rtofs_global_3d_obc.in 2>&1 | tee ./archv2ncdf3z_3d_obc.log
    
    unlink archv_in.a
    unlink archv_in.b
    echo "OCN source grid type invalid"
    exit 1
fi

for i in $(seq -f "%03g" 1 4); do
    FILE="${WGT_FILE_BASE}_${i}.nc"
    if [ ! -e "${OCN_RUN_DIR}/inputs/${FILE}" ]; then
        echo "File ${FILE} does not exist. Creating the file..."
        ${APRUNS} ESMF_RegridWeightGen -s ${BCFILENAME} -d ocean_hgrid_${i}.nc -w ${FILE} \
            --dst_loc center --netCDF4 --dst_regional --ignore_degenerate
    fi
done

cd ${OCN_SCRIPT_DIR}
./remap_OBCs.sh

exit 0

# ----------------------------------------------------------------------------------- #
#                                    Complete!                                        #
# ----------------------------------------------------------------------------------- #
