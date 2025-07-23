#!/bin/sh

set -e -x -o pipefail

module use ${UFSUTILS_DIR}/modulefiles
module load build.${SYSTEM}.intel.lua
#CHGRESCUBEEXEC=${CHGRESCUBEEXEC:-${UFSUTILS_DIR}/exec/chgres_cube}
CHGRESCUBEEXEC="/scratch4/BMC/gsienkf/Kristin.Barton/hwrf/HAFS/exec/hafs_utils_chgres_cube.x"

CDATE=${CDATE}
cycle_year=$(echo $CDATE | cut -c 1-4)
cycle_mon=$(echo $CDATE | cut -c 5-6)
cycle_day=$(echo $CDATE | cut -c 7-8)
cycle_hour=$(echo $CDATE | cut -c 9-10)

# Shared namelist values
regional=${ATM_REGIONAL}
halo_bndy=${ATM_HALO_BNDY}
halo_blend=${ATM_HALO_BLEND}

mosaic_file_target_grid="${FIX_DIR}/${ATM_DST_CASE}/${ATM_DST_CASE}_mosaic.nc"
fix_dir_target_grid="${FIX_DIR}/${ATM_DST_CASE}/sfc"
orog_dir_target_grid="${FIX_DIR}/${ATM_DST_CASE}"
orog_files_target_grid="${ATM_CASE}_oro_data.tile${ATM_TILE}.halo${ATM_HALO_BNDY}.nc"
vcoord_file_target_grid="${FIX_DIR}/${ATM_DST_CASE}/global_hyblev.l${ATM_LEVS}.txt"

convert_atm=.true.
convert_sfc=.true.
sotyp_from_climo=.true.
vgtyp_from_climo=.true.
vgfrc_from_climo=.true.
minmax_vgfrc_from_climo=.true.
tg3_from_soil=.false.
lai_from_climo=true.
external_model="GFS"
nsoill_out=4
thomp_mp_climo_file="NULL"
wam_cold_start=.false.

###########################
##  Generating IC Files  ##
###########################

if [ $ATM_ICTYPE = "fv3_restart" ]; then
    mosaic_file_input_grid="${FIX_DIR}/${ATM_SRC_CASE}/${ATM_SRC_CASE}_mosaic.nc"
    orog_dir_input_grid="${FIX_DIR}/${ATM_SRC_CASE}"
    orog_files_input_grid=${ATM_SRC_CASE}'_oro_data.tile1.nc","'${ATM_SRC_CASE}'_oro_data.tile2.nc","'${ATM_SRC_CASE}'_oro_data.tile3.nc","'${ATM_SRC_CASE}'_oro_data.tile4.nc","'${ATM_SRC_CASE}'_oro_data.tile5.nc","'${ATM_SRC_CASE}'_oro_data.tile6.nc'
    data_dir_input_grid="${ATM_DATA_DIR}/ics"
    atm_core_files_input_grid='fv_core.res.tile1.nc","fv_core.res.tile2.nc","fv_core.res.tile3.nc","fv_core.res.tile4.nc","fv_core.res.tile5.nc","fv_core.res.tile6.nc","fv_core.res.nc'
    atm_tracer_files_input_grid='fv_tracer.res.tile1.nc","fv_tracer.res.tile2.nc","fv_tracer.res.tile3.nc","fv_tracer.res.tile4.nc","fv_tracer.res.tile5.nc","fv_tracer.res.tile6.nc'
    sfc_files_input_grid='sfc_data.tile1.nc","sfc_data.tile2.nc","sfc_data.tile3.nc","sfc_data.tile4.nc","sfc_data.tile5.nc","sfc_data.tile6.nc'
    convert_nst=.true.
    input_type="restart"
    tracers='"sphum","liq_wat","o3mr","ice_wat","rainwat","snowwat","graupel"'
    tracers_input='"sphum","liq_wat","o3mr","ice_wat","rainwat","snowwat","graupel"'
elif [ $ATM_ICTYPE = "gefsv13_replay" ]; then
    mosaic_file_input_grid="NULL"
    orog_dir_input_grid="NULL"
    orog_files_input_grid="NULL"
    data_dir_input_grid="${ATM_DATA_DIR}/fcst/atmos/combined"
    atm_core_files_input_grid="NULL"
    atm_tracer_files_input_grid="NULL"
    #varmap_file="${UFSUTILS_DIR}/parm/varmap_tables/GFSphys_var_map.txt"
    varmap_file="/scratch4/BMC/gsienkf/Kristin.Barton/repos/hafs-community/HAFS/parm/varmap_tables/GFSphys_var_map.txt"
    convert_nst=.true.
    input_type="grib2"
    tracers='"sphum","liq_wat","o3mr"'
    tracers_input='"spfh","clwmr","o3mr"'
    #grib2_file_input_grid="gefs.t${cycle_hour}z.pgrb2_combined.0p25.f${FHR3}"
    grib2_file_input_grid="gefs.t00z.pgrb2_combined.0p25.f003"
    atm_file_input_grid="gefs.t00z.pgrb2_combined.0p25.f003"
    sfc_file_input_grid="gefs.t00z.pgrb2_combined.0p25.f003"
#elif [ $ATM_ICTYPE = "gfsnetcdf" ]; then
else
    echo "FATAL ERROR: Unknown or unsupported IC input type ${ATM_ICTYPE}"
    exit 9
fi

# Create namelist and run chgres_cube
cat>./fort.41<<EOF
&config
 mosaic_file_target_grid="${mosaic_file_target_grid:-NULL}"
 fix_dir_target_grid="${fix_dir_target_grid:-NULL}"
 orog_dir_target_grid="${orog_dir_target_grid:-NULL}"
 orog_files_target_grid="${orog_files_target_grid:-NULL}"
 vcoord_file_target_grid="${vcoord_file_target_grid:-NULL}"
 mosaic_file_input_grid="${mosaic_file_input_grid:-NULL}"
 orog_dir_input_grid="${orog_dir_input_grid:-NULL}"
 orog_files_input_grid="${orog_files_input_grid:-NULL}"
 data_dir_input_grid="${data_dir_input_grid:-NULL}"
 atm_files_input_grid="${atm_files_input_grid:-NULL}"
 atm_core_files_input_grid="${atm_core_files_input_grid:-NULL}"
 atm_tracer_files_input_grid="${atm_tracer_files_input_grid:-NULL}"
 sfc_files_input_grid="${sfc_files_input_grid:-NULL}"
 nst_files_input_grid="${nst_files_input_grid:-NULL}"
 grib2_file_input_grid="${grib2_file_input_grid:-NULL}"
 geogrid_file_input_grid="${geogrid_file_input_grid:-NULL}"
 varmap_file="${varmap_file:-NULL}"
 wam_parm_file="${warm_parm_file:-NULL}"
 cycle_year=${cycle_year}
 cycle_mon=${cycle_mon}
 cycle_day=${cycle_day}
 cycle_hour=${cycle_hour}
 convert_atm=${convert_atm}
 convert_sfc=${convert_sfc}
 convert_nst=${convert_nst}
 input_type="${input_type}"
 tracers=${tracers}
 tracers_input=${tracers_input}
 regional=${regional}
 halo_bndy=${halo_bndy}
 halo_blend=${halo_blend}
 sotyp_from_climo=${sotyp_from_climo}
 vgtyp_from_climo=${vgtyp_from_climo}
 vgfrc_from_climo=${vgfrc_from_climo}
 minmax_vgfrc_from_climo=${minmax_vgfrc_from_climo}
 tg3_from_soil=${tg3_from_soil}
 lai_from_climo=${lai_from_climo}
 external_model=${external_model}
 nsoill_out=${nsoill_out}
 thomp_mp_climo_file="${thomp_mp_climo_file:-NULL}"
 wam_cold_start=${wam_cold_start}
/
EOF

${APRUNC} ${CHGRESCUBEEXEC} 2>&1 | tee ./chgres_cube_lbc.log

mv ${ATM_RUN_DIR}/gfs_ctrl.nc ${ATM_RUN_DIR}/intercom/gfs_ctrl.nc
mv ${ATM_RUN_DIR}/gfs.bndy.nc ${ATM_RUN_DIR}/intercom/gfs_bndy.tile${ATM_TILE}.000.nc
mv ${ATM_RUN_DIR}/out.atm.tile${ATM_TILE}.nc ${ATM_RUN_DIR}/intercom/gfs_data.tile${ATM_TILE}.nc
mv ${ATM_RUN_DIR}/out.sfc.tile${ATM_TILE}.nc ${ATM_RUN_DIR}/intercom/sfc_data.tile${ATM_TILE}.nc

echo "Atmosphere IC Generation Complete"

############################
##  Generating LBC Files  ##
############################

FHRB=${ATM_NBDYINT}
FHRE=${NHRS}
FHRI=${ATM_NBDYINT}
FHR=${FHRB}
FHR3=$(printf "%03d" "$FHR")

if [ $ATM_BCTYPE = "gefsv13_replay" ]; then
    mosaic_file_input_grid="NULL"
    orog_dir_input_grid="NULL"
    orog_files_input_grid="NULL"
    data_dir_input_grid="${ATM_DATA_DIR}/fcst/atmos/combined"
    atm_files_input_grid="NULL"
    atm_core_files_input_grid="NULL"
    atm_tracer_files_input_grid="NULL"
    sfc_files_input_grid="NULL"
    varmap_file="${UFSUTILS_DIR}/parm/varmap_tables/GFSphys_var_map.txt"
    convert_nst=.false.
    input_type="grib2"
    tracers="sphum","liq_wat","o3mr","ice_wat","rainwat","snowwat","graupel"
    tracers_input="spfh","clmr","o3mr","icmr","rwmr","snmr","grle"
#elif [ $ATM_ICTYPE = "gfsnetcdf" ]; then
else
    echo "FATAL ERROR: Unknown or unsupported LBC input type ${ATM_BCTYPE}"
    exit 9
fi

#### START LOOP #####
while [ $FHR -le $FHRE ]; do
echo "Processing LBC for forecast hour ${FHR}"

grib2_file_input_grid="gefs.t${cycle_hour}z.pgrb2_combined.0p25.f${FHR3}"

# Create namelist and run chgres_cube
cat>./fort.41<<EOF
 &config
  mosaic_file_target_grid="${mosaic_file_target_grid:-NULL}"
  fix_dir_target_grid="${fix_dir_target_grid:-NULL}"
  orog_dir_target_grid="${orog_dir_target_grid:-NULL}"
  orog_files_target_grid="${orog_files_target_grid:-NULL}"
  vcoord_file_target_grid="${vcoord_file_target_grid:-NULL}"
  mosaic_file_input_grid="${mosaic_file_input_grid:-NULL}"
  orog_dir_input_grid="${orog_dir_input_grid:-NULL}"
  orog_files_input_grid="${orog_files_input_grid:-NULL}"
  data_dir_input_grid="${data_dir_input_grid:-NULL}"
  atm_files_input_grid="${atm_files_input_grid:-NULL}"
  atm_core_files_input_grid="${atm_core_files_input_grid:-NULL}"
  atm_tracer_files_input_grid="${atm_tracer_files_input_grid:-NULL}"
  sfc_files_input_grid="${sfc_files_input_grid:-NULL}"
  nst_files_input_grid="${nst_files_input_grid:-NULL}"
  grib2_file_input_grid="${grib2_file_input_grid:-NULL}"
  geogrid_file_input_grid="${geogrid_file_input_grid:-NULL}"
  varmap_file="${varmap_file:-NULL}"
  wam_parm_file="${warm_parm_file:-NULL}"
  cycle_year=${cycle_year}
  cycle_mon=${cycle_mon}
  cycle_day=${cycle_day}
  cycle_hour=${cycle_hour}
  convert_atm=${convert_atm}
  convert_sfc=${convert_sfc}
  convert_nst=${convert_nst}
  input_type="${input_type}"
  tracers=${tracers}
  tracers_input=${tracers_input}
  regional=${regional}
  halo_bndy=${halo_bndy}
  halo_blend=${halo_blend}
  sotyp_from_climo=${sotyp_from_climo}
  vgtyp_from_climo=${vgtyp_from_climo}
  vgfrc_from_climo=${vgfrc_from_climo}
  minmax_vgfrc_from_climo=${minmax_vgfrc_from_climo}
  tg3_from_soil=${tg3_from_soil}
  lai_from_climo=${lai_from_climo}
  external_model=${external_model}
  nsoill_out=${nsoill_out}
  thomp_mp_climo_file="${thomp_mp_climo_file:-NULL}"
  wam_cold_start=${wam_cold_start}
 /
EOF

${APRUNC} ${CHGRESCUBEEXEC} 2>&1 | tee ./chgres_cube_lbc_${FHR3}.log

mv ${ATM_RUN_DIR}/gfs.bndy.nc ${ATM_RUN_DIR}/intercom/gfs_bndy.tile${ATM_TILE}.${FHR3}.nc

# Go to next forecast out
FHR=$(($FHR + ${FHRI}))
FHR3=$(printf "%03d" "$FHR")

done
#### END LOOP #####

echo "Atmosphere LBC Generation Complete"

exit
