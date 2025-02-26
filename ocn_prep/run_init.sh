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

# ----------------------------------------------------------------------------------- #
#                                  Environment Setup                                  #
# ----------------------------------------------------------------------------------- #

# EDIT THIS SECTION AS NEEDED
# These variables are normally set by the run namelist parameters

export CDATE=${CDATE:-'2020082512'}
export CDATEprior=${CDATEprior:-'2020082506'}
export cyc=${cyc:-'12'}
export STORM=${STORM:-'NATL'}
export STORMID=${STORMID:-'00L'}
export NHRS=${NHRS:-'6'}
export FHRB=${FHRB:-'0'}
export FHRI=${FHRI:-'3'}
export FHR=${FHR:-'0'}

export NLN=${NLN:-"ln -s"}
export NCP=${NCP:-"cp"}
export WGRIB2=${WGRIB2:-"wgrib2"}

# !!! Edit for your system/account !!!
export APRUNS=${APRUNS:-"srun --mem=0 --ntasks=1 --nodes=1 --ntasks-per-node=1 --cpus-per-task=1 --account=gsienkf"}

# !!! Edit for your working directory (where the initial files will be placed) !!!
#export WORKhafs=${WORKhafs:-"/scratch2/BMC/gsienkf/Kristin.Barton/hwrf/ocn_prep_test/ocn_prep/cleanup/ocn_prep"}
export OCNgrid="ARC12"
export WORKdir=$(pwd)
export FIXdir=${WORKdir}/fix/${OCNgrid}/

# !!! Edit for your local dataset locations !!!
# These can be found by checking the relevant system.conf file in the parm/ directory of the HAFS repository.
export COMINrtofs=${COMINrtofs:-"/scratch1/NCEPDEV/hwrf/noscrub/hafs-input/COMRTOFSv2/"}
export COMINgfs=${COMINgfs:-"/scratch1/NCEPDEV/hwrf/noscrub/hafs-input/COMGFSv16/"}

# !!! Edit for your HAFS directory (if needed) !!!
export HAFSdir=${HAFSdir:-"/scratch2/BMC/gsienkf/Kristin.Barton/hwrf/HAFS/"}
export FIXhafs="${HAFSdir}/fix/"
export PARMhafs="${HAFSdir}/parm/"
export EXEChafs="${HAFSdir}/exec/"
export USHhafs="${HAFSdir}/ush/"
export MODhafs="${HAFSdir}/modulefiles/"

module use ${MODhafs}
module load hafs_mom6_obc.hera.lua # !!! Edit for your system
module load cdo

# The rest of the parameters below are set automatically
CDATE=${CDATE:-${YMDH}}
cyc=${cyc:-00}
STORM=${STORM:-FAKE}
STORMID=${STORMID:-00L}

ymd=`echo $CDATE | cut -c 1-8`
hour=`echo $CDATE | cut -c 9-10`
#CDATEprior=`${NDATE} -6 $CDATE`
ymd_prior=`echo ${CDATEprior} | cut -c1-8`
cyc_prior=`echo ${CDATEprior} | cut -c9-10`

if [ "${hour}" == "00" ]; then
  type=${type:-n}
else
  type=${type:-f}
fi

# Make the intercom dir
mkdir -p ${WORKdir}/intercom/
mkdir -p ${WORKdir}/inputs/

ymd=`echo $CDATE | cut -c 1-8`
hour=`echo $CDATE | cut -c 9-10`
if [ "${hour}" == "00" ]; then
  type=${type:-n}
else
  type=${type:-f}
fi

FHRB=0
FHRE=9
FHRI=3
FHR=0
FHR3=000

FHRB=${FHRB:-0}
FHRE=${FHRE:-$((${NHRS}+3))}
FHRI=${FHRI:-3}
FHR=${FHRB}
FHR3=$( printf "%03d" "$FHR" )

# ----------------------------------------------------------------------------------- #
#                                     IC Setup                                        #
# ----------------------------------------------------------------------------------- #

# Retrive the regridding weights and ocean grid files
mkdir -p ${FIXdir}
${NLN} /scratch2/BMC/gsienkf/Kristin.Barton/files/mesh_files/${OCNgrid}/input_files/* ${FIXdir}/.

cd ${WORKdir}/inputs/

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

cd ${FIXdir}

if [ ! -e "${FIXdir}/rtofs2hgrid_001.nc" ]; then
    echo "File rtofs2hgrid_001.nc  does not exist. Creating the file..."
    ${APRUNS} ESMF_RegridWeightGen -s ${WORKdir}/inputs/rtofs_global_ssh_ic.nc -d ocean_hgrid_001.nc -w rtofs2hgrid_001.nc --dst_loc center --netCDF4 --dst_regional --ignore_degenerate
fi
if [ ! -e "${FIXdir}/rtofs2hgrid_002.nc" ]; then
    echo "File rtofs2hgrid_002.nc  does not exist. Creating the file..."
    ${APRUNS} ESMF_RegridWeightGen -s ${WORKdir}/inputs/rtofs_global_ssh_ic.nc -d ocean_hgrid_002.nc -w rtofs2hgrid_002.nc --dst_loc center --netCDF4 --dst_regional --ignore_degenerate
fi
if [ ! -e "${FIXdir}/rtofs2hgrid_003.nc" ]; then
    echo "File rtofs2hgrid_003.nc  does not exist. Creating the file..."
    ${APRUNS} ESMF_RegridWeightGen -s ${WORKdir}/inputs/rtofs_global_ssh_ic.nc -d ocean_hgrid_003.nc -w rtofs2hgrid_003.nc --dst_loc center --netCDF4 --dst_regional --ignore_degenerate
fi
if [ ! -e "${FIXdir}/rtofs2hgrid_004.nc" ]; then
    echo "File rtofs2hgrid_004.nc  does not exist. Creating the file..."
    ${APRUNS} ESMF_RegridWeightGen -s ${WORKdir}/inputs/rtofs_global_ssh_ic.nc -d ocean_hgrid_004.nc -w rtofs2hgrid_004.nc --dst_loc center --netCDF4 --dst_regional --ignore_degenerate
fi

cd ${WORKdir}
./remap_ICs.sh

# ----------------------------------------------------------------------------------- #
#                                   OBC Setup                                         #
# ----------------------------------------------------------------------------------- #

cd ${WORKdir}/inputs/

# Define output file names and HYCOM variables
outnc_2d=global_ssh_obc.nc
outnc_ts=global_ts_obc.nc
outnc_uv=global_uv_obc.nc
export CDF038=rtofs.${type}${hour}_${outnc_2d}
export CDF034=rtofs.${type}${hour}_${outnc_ts}
export CDF033=rtofs.${type}${hour}_${outnc_uv}

# run HYCOM-tools executables to produce OBC netcdf files
${APRUNS} ${EXEChafs}/hafs_hycom_utils_archv2ncdf2d.x < ./rtofs_global_ssh_obc.in 2>&1 | tee ./archv2ncdf2d_ssh_obc.log
${APRUNS} ${EXEChafs}/hafs_hycom_utils_archv2ncdf3z.x < ./rtofs_global_3d_obc.in 2>&1 | tee ./archv2ncdf3z_3d_obc.log

cd ${WORKdir}
./remap_OBCs.sh

# ----------------------------------------------------------------------------------- #
#                                GFS Forcing Setup                                    #
# ----------------------------------------------------------------------------------- #

cd ${WORKdir}/inputs/

# Prepare data atmosphere forcings from GFS
PARMave=":USWRF:surface|:DSWRF:surface|:ULWRF:surface|:DLWRF:surface|:UFLX:surface|:VFLX:surface|:SHTFL:surface|:LHTFL:surface"
PARMins=":UGRD:10 m above ground|:VGRD:10 m above ground|:PRES:surface|:PRATE:surface|:TMP:surface"
PARMlist="${PARMave}|${PARMins}"

# Use gfs forcing from prior cycle's 6-h forecast
grib2_file=${COMINgfs}/gfs.${ymd_prior}/${cyc_prior}/atmos/gfs.t${cyc_prior}z.pgrb2.0p25.f006
if [ ! -s ${grib2_file} ]; then
  echo "FATAL ERROR: ${grib2_file} does not exist. Exiting"
  exit 1
fi

# Extract atmospheric forcing related variables
${WGRIB2} ${grib2_file} -match "${PARMlist}" -netcdf gfs_global_${ymd_prior}${cyc_prior}_f006.nc

## Loop for forecast hours
while [ $FHR -le ${FHRE} ]; do

  # Use gfs 0.25 degree grib2 files
  grib2_file=${COMINgfs}/gfs.${ymd}/${cyc}/atmos/gfs.t${cyc}z.pgrb2.0p25.f${FHR3}

  # Check and wait for input data
  MAX_WAIT_TIME=${MAX_WAIT_TIME:-900}
  n=0
  while [ $n -le ${MAX_WAIT_TIME} ]; do
    if [ -s ${grib2_file} ]; then
    while [ $(( $(date +%s) - $(stat -c %Y ${grib2_file}) )) -lt 10  ]; do sleep 10; done
      echo "${grib2_file} ready, continue ..."
      break
    else
      echo "${grib2_file} not ready, sleep 10"
      sleep 10s
    fi
    n=$((n+10))
    if [ $n -gt ${MAX_WAIT_TIME} ]; then
      echo "FATAL ERROR: Waited ${grib2_file} too long $n > ${MAX_WAIT_TIME} seconds. Exiting"
      exit 1
    fi
  done

  ${WGRIB2} ${grib2_file} -match "${PARMlist}" -netcdf gfs_global_${ymd}${cyc}_f${FHR3}.nc

  FHR=$(($FHR + ${FHRI}))
  FHR3=$(printf "%03d" "$FHR")

done
## End loop for forecast hours

echo $NHRS
${USHhafs}/hafs_mom6_gfs_forcings.py ${CDATE} -l ${NHRS} 2>&1 | tee ./mom6_gfs_forcings.log

# Obtain net longwave and shortwave radiation file
echo 'Obtaining NETLW'
ncks -A gfs_global_${CDATE}_ULWRF.nc -o gfs_global_${CDATE}_LWRF.nc
ncks -A gfs_global_${CDATE}_DLWRF.nc -o gfs_global_${CDATE}_LWRF.nc
ncap2 -v -O -s "NETLW_surface=DLWRF_surface-ULWRF_surface" gfs_global_${CDATE}_LWRF.nc gfs_global_${CDATE}_NETLW.nc
ncatted -O -a long_name,NETLW_surface,o,c,"Net Long-Wave Radiation Flux" gfs_global_${CDATE}_NETLW.nc
ncatted -O -a short_name,NETLW_surface,o,c,"NETLW_surface" gfs_global_${CDATE}_NETLW.nc

echo 'Obtaining NETSW'
ncks -A gfs_global_${CDATE}_USWRF.nc -o gfs_global_${CDATE}_SWRF.nc
ncks -A gfs_global_${CDATE}_DSWRF.nc -o gfs_global_${CDATE}_SWRF.nc
ncap2 -v -O -s "NETSW_surface=DSWRF_surface-USWRF_surface" gfs_global_${CDATE}_SWRF.nc gfs_global_${CDATE}_NETSW.nc
ncatted -O -a long_name,NETSW_surface,o,c,"Net Short-Wave Radiation Flux" gfs_global_${CDATE}_NETSW.nc
ncatted -O -a short_name,NETSW_surface,o,c,"NETSW_surface" gfs_global_${CDATE}_NETSW.nc

# Add four components to the NETSW and DSWRF radiation files
# SWVDF=Visible Diffuse Downward Solar Flux. SWVDF=0.285*DSWRF_surface
# SWVDR=Visible Beam Downward Solar Flux. SWVDR=0.285*DSWRF_surface
# SWNDF=Near IR Diffuse Downward Solar Flux. SWNDF=0.215*DSWRF_surface
# SWNDR=Near IR Beam Downward Solar Flux. SWNDR=0.215*DSWRF_surface
echo 'Adding four components to the NETSW radiation file'
echo 'Adding SWVDF'
ncap2 -v -O -s "SWVDF_surface=float(0.285*DSWRF_surface)" gfs_global_${CDATE}_DSWRF.nc gfs_global_${CDATE}_SWVDF.nc
ncatted -O -a long_name,SWVDF_surface,o,c,"Visible Diffuse Downward Solar Flux" gfs_global_${CDATE}_SWVDF.nc
ncatted -O -a short_name,SWVDF_surface,o,c,"SWVDF_surface" gfs_global_${CDATE}_SWVDF.nc

echo 'Adding SWVDR'
ncap2 -v -O -s "SWVDR_surface=float(0.285*DSWRF_surface)" gfs_global_${CDATE}_DSWRF.nc gfs_global_${CDATE}_SWVDR.nc
ncatted -O -a long_name,SWVDR_surface,o,c,"Visible Beam Downward Solar Flux" gfs_global_${CDATE}_SWVDR.nc
ncatted -O -a short_name,SWVDR_surface,o,c,"SWVDR_surface" gfs_global_${CDATE}_SWVDR.nc

echo 'Adding SWNDF'
ncap2 -v -O -s "SWNDF_surface=float(0.215*DSWRF_surface)" gfs_global_${CDATE}_DSWRF.nc gfs_global_${CDATE}_SWNDF.nc
ncatted -O -a long_name,SWNDF_surface,o,c,"Near IR Diffuse Downward Solar Flux" gfs_global_${CDATE}_SWNDF.nc
ncatted -O -a short_name,SWNDF_surface,o,c,"SWNDF_surface" gfs_global_${CDATE}_SWNDF.nc

echo 'Adding SWNDR'
ncap2 -v -O -s "SWNDR_surface=float(0.215*DSWRF_surface)" gfs_global_${CDATE}_DSWRF.nc gfs_global_${CDATE}_SWNDR.nc
ncatted -O -a long_name,SWNDR_surface,o,c,"Near IR Beam Downward Solar Flux" gfs_global_${CDATE}_SWNDR.nc
ncatted -O -a short_name,SWNDR_surface,o,c,"SWVDR_surface" gfs_global_${CDATE}_SWNDR.nc

echo 'Changing sign to SHTFL, LHTFL, UFLX, VFLX'
ncap2 -v -O -s "SHTFL_surface=float(SHTFL_surface*-1.0)" gfs_global_${CDATE}_SHTFL.nc gfs_global_${CDATE}_SHTFL.nc
ncap2 -v -O -s "LHTFL_surface=float(LHTFL_surface*-1.0)" gfs_global_${CDATE}_LHTFL.nc gfs_global_${CDATE}_LHTFL.nc
ncap2 -v -O -s "UFLX_surface=float(UFLX_surface*-1.0)" gfs_global_${CDATE}_UFLX.nc gfs_global_${CDATE}_UFLX.nc
ncap2 -v -O -s "VFLX_surface=float(VFLX_surface*-1.0)" gfs_global_${CDATE}_VFLX.nc gfs_global_${CDATE}_VFLX.nc

echo 'Adding EVAP'
ncap2 -v -O -s "EVAP_surface=float(LHTFL_surface/(2.5*10^6))" gfs_global_${CDATE}_LHTFL.nc gfs_global_${CDATE}_EVAP.nc
ncatted -O -a long_name,EVAP_surface,o,c,"Evaporation Rate" gfs_global_${CDATE}_EVAP.nc
ncatted -O -a short_name,EVAP_surface,o,c,"EVAP_surface" gfs_global_${CDATE}_EVAP.nc
ncatted -O -a units,EVAP_surface,o,c,"Kg m-2 s-1" gfs_global_${CDATE}_EVAP.nc

# Concatenate all files
fileall="gfs_global_${CDATE}_NETLW.nc \
         gfs_global_${CDATE}_DSWRF.nc \
         gfs_global_${CDATE}_NETSW.nc \
         gfs_global_${CDATE}_SWVDF.nc \
         gfs_global_${CDATE}_SWVDR.nc \
         gfs_global_${CDATE}_SWNDF.nc \
         gfs_global_${CDATE}_SWNDR.nc \
         gfs_global_${CDATE}_LHTFL.nc \
         gfs_global_${CDATE}_EVAP.nc  \
         gfs_global_${CDATE}_SHTFL.nc \
         gfs_global_${CDATE}_UFLX.nc  \
         gfs_global_${CDATE}_VFLX.nc  \
         gfs_global_${CDATE}_UGRD.nc  \
         gfs_global_${CDATE}_VGRD.nc  \
         gfs_global_${CDATE}_PRES.nc  \
         gfs_global_${CDATE}_PRATE.nc \
         gfs_global_${CDATE}_TMP.nc"
# Use cdo merge, which is faster
module load cdo
cdo merge ${fileall} gfs_forcings.nc

${NCP} gfs_forcings.nc ${WORKdir}/intercom/.

# ----------------------------------------------------------------------------------- #
#                                    Complete!                                        #
# ----------------------------------------------------------------------------------- #
