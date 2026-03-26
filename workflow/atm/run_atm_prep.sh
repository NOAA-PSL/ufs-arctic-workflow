#!/bin/sh
# ==============================================================================
# Atmosphere Prep Script (arctic_atm_prep.sh)
# Description: Generates surface initial conditions and atmosphere 
#              initial/lateral boundary conditions using chgres_cube
# ==============================================================================

set -eo pipefail

# ================================= #
# Logging & Validation              #
# ================================= #

log_info()  { echo -e "(info) $1"; }
log_warn()  { echo -e "(Warn) $1"; }
log_error() { echo -e "[ERROR] $1" >&2; }
error_exit() { log_error "$1"; exit 1; }

[[ -z "$CHGRES_EXEC" ]] && error_exit "CHGRES_EXEC is not set."
[[ -z "$CDATE" ]] && error_exit "CDATE is not set."
[[ -z "$ATM_RUN_DIR" ]] && error_exit "ATM_RUN_DIR is not set."

log_info "-> Using chgres_cube at: $CHGRES_EXEC"

module use "${UFSUTILS_DIR}/modulefiles"
module load "build.${SYSTEM}.intelllvm.lua" || error_exit "Failed to load chgres module."

# ================================= #
# Global Variables & Date Setup     #
# ================================= #


cycle_year="${CDATE:0:4}"
cycle_mon="${CDATE:4:2}"
cycle_day="${CDATE:6:2}"
cycle_hour="${CDATE:8:2}"
cycle_hour="${cycle_hour:-00}"

# Shared namelist values
regional="${ATM_REGIONAL}"
halo_bndy="${ATM_HALO_BNDY}"
halo_blend="${ATM_HALO_BLEND}"

mosaic_file_target_grid="${FIX_DIR}/mesh_files/${ATM_DST_CASE}/${ATM_DST_CASE}_mosaic.nc"
fix_dir_target_grid="${FIX_DIR}/mesh_files/${ATM_DST_CASE}/sfc"
orog_dir_target_grid="${FIX_DIR}/mesh_files/${ATM_DST_CASE}"
orog_files_target_grid="${ATM_RES}_oro_data.tile${ATM_TILE}.halo${ATM_HALO_BNDY}.nc"
vcoord_file_target_grid="${FIX_DIR}/mesh_files/${ATM_DST_CASE}/global_hyblev.l${ATM_LEVS}.txt"

sotyp_from_climo=.true.
vgtyp_from_climo=.true.
vgfrc_from_climo=.true.
minmax_vgfrc_from_climo=.true.
tg3_from_soil=.true.
lai_from_climo=.true.
external_model="GFS"
nsoill_out=4
thomp_mp_climo_file="NULL"
wam_cold_start=.false.

# ================================= #
# Function Definitions              #
# ================================= #

generate_namelist() {
    cat > ./fort.41 <<EOF
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
 wam_parm_file="${wam_parm_file:-NULL}"
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
 external_model="${external_model}"
 nsoill_out=${nsoill_out}
 thomp_mp_climo_file="${thomp_mp_climo_file:-NULL}"
 wam_cold_start=${wam_cold_start}
/
EOF
}

run_chgres() {
    local log_file="$1"
    ${APRUNC} --time=30:00 "${CHGRES_EXEC}" 2>&1 | tee "${log_file}" > /dev/null

    if [ ${PIPESTATUS[0]} -ne 0 ]; then
        error_exit "chgres_cube failed! Check ${log_file} for details."
    fi

}

# ================================= #
# Generating SFC Files              #
# ================================= #


SFC_OUT="${ATM_RUN_DIR}/intercom/sfc_data.tile${ATM_TILE}.nc"
if [ -s "$SFC_OUT" ]; then
    log_info "-> Surface IC file already exists. Skipping."
else
    log_info "-> Generating surface IC files..."
    if [ "$SFC_ICTYPE" = "restart_files" ]; then
        convert_atm=.false.
        convert_sfc=.true.
        convert_nst=.true.
        mosaic_file_input_grid="${FIX_DIR}/mesh_files/${ATM_SRC_CASE}/${ATM_SRC_CASE}_mosaic.nc"
        orog_dir_input_grid="${FIX_DIR}/mesh_files/${ATM_SRC_CASE}"
        orog_files_input_grid=${ATM_SRC_CASE}'_oro_data.tile1.nc","'${ATM_SRC_CASE}'_oro_data.tile2.nc","'${ATM_SRC_CASE}'_oro_data.tile3.nc","'${ATM_SRC_CASE}'_oro_data.tile4.nc","'${ATM_SRC_CASE}'_oro_data.tile5.nc","'${ATM_SRC_CASE}'_oro_data.tile6.nc'
        data_dir_input_grid="${ATM_DATA_DIR}/ics"
        atm_core_files_input_grid='fv_core.res.tile1.nc","fv_core.res.tile2.nc","fv_core.res.tile3.nc","fv_core.res.tile4.nc","fv_core.res.tile5.nc","fv_core.res.tile6.nc","fv_core.res.nc'
        atm_tracer_files_input_grid='fv_tracer.res.tile1.nc","fv_tracer.res.tile2.nc","fv_tracer.res.tile3.nc","fv_tracer.res.tile4.nc","fv_tracer.res.tile5.nc","fv_tracer.res.tile6.nc'
        sfc_files_input_grid='sfc_data.tile1.nc","sfc_data.tile2.nc","sfc_data.tile3.nc","sfc_data.tile4.nc","sfc_data.tile5.nc","sfc_data.tile6.nc'
        input_type="restart"
        tracers='"sphum","liq_wat","o3mr","ice_wat","rainwat","snowwat","graupel"'
        tracers_input='"sphum","liq_wat","o3mr","ice_wat","rainwat","snowwat","graupel"'
    else
        error_exit "Unknown or unsupported SFC input type: ${SFC_ICTYPE}"
    fi

    generate_namelist
    run_chgres "./chgres_cube_sfc.log"
    mv "${ATM_RUN_DIR}/out.sfc.tile${ATM_TILE}.nc" "$SFC_OUT"
fi

# ================================= #
# Generating ATM Files              #
# ================================= #


ATM_OUT="${ATM_RUN_DIR}/intercom/gfs_data.tile${ATM_TILE}.nc"

if [ -s "$ATM_OUT" ]; then
    log_info "-> Atmosphere IC files already exist. Skipping."
else
    log_info "-> Generating atmosphere IC files..."
    if [ "$ATM_ICTYPE" = "restart_files" ]; then
        convert_atm=.true.
        convert_sfc=.false.
        convert_nst=.false.
        mosaic_file_input_grid="${FIX_DIR}/mesh_files/${ATM_SRC_CASE}/${ATM_SRC_CASE}_mosaic.nc"
        orog_dir_input_grid="${FIX_DIR}/mesh_files/${ATM_SRC_CASE}"
        orog_files_input_grid=${ATM_SRC_CASE}'_oro_data.tile1.nc","'${ATM_SRC_CASE}'_oro_data.tile2.nc","'${ATM_SRC_CASE}'_oro_data.tile3.nc","'${ATM_SRC_CASE}'_oro_data.tile4.nc","'${ATM_SRC_CASE}'_oro_data.tile5.nc","'${ATM_SRC_CASE}'_oro_data.tile6.nc'
        data_dir_input_grid="${ATM_DATA_DIR}/ics"
        atm_core_files_input_grid='fv_core.res.tile1.nc","fv_core.res.tile2.nc","fv_core.res.tile3.nc","fv_core.res.tile4.nc","fv_core.res.tile5.nc","fv_core.res.tile6.nc","fv_core.res.nc'
        atm_tracer_files_input_grid='fv_tracer.res.tile1.nc","fv_tracer.res.tile2.nc","fv_tracer.res.tile3.nc","fv_tracer.res.tile4.nc","fv_tracer.res.tile5.nc","fv_tracer.res.tile6.nc'
        sfc_files_input_grid='sfc_data.tile1.nc","sfc_data.tile2.nc","sfc_data.tile3.nc","sfc_data.tile4.nc","sfc_data.tile5.nc","sfc_data.tile6.nc'
        input_type="restart"
        tracers='"sphum","liq_wat","o3mr","ice_wat","rainwat","snowwat","graupel"'
        tracers_input='"sphum","liq_wat","o3mr","ice_wat","rainwat","snowwat","graupel"'
    
    elif [ $ATM_ICTYPE = "grib_files" ]; then
        convert_atm=.true.
        convert_sfc=.false.
        convert_nst=.false.
        mosaic_file_input_grid="NULL"
        orog_dir_input_grid="NULL"
        orog_files_input_grid="NULL"
        data_dir_input_grid="${ATM_DATA_DIR}/fcst/atmos/combined"
        atm_core_files_input_grid="NULL"
        atm_tracer_files_input_grid="NULL"
        input_type="grib2"
        tracers='"sphum","liq_wat","o3mr","ice_wat","rainwat","snowwat","graupel"'
        tracers_input='"spfh","clwmr","o3mr","ice_wat","rainwat","snowwat","graupel"'
    #    tracers='"sphum","liq_wat","o3mr"'
    #    tracers_input='"spfh","clwmr","o3mr"'
        #grib2_file_input_grid="gefs.t${cycle_hour}z.pgrb2_combined.0p25.f${FHR3}"
        grib2_file_input_grid="gefs.t00z.pgrb2_combined.0p25.f003"
        atm_file_input_grid="gefs.t00z.pgrb2_combined.0p25.f003"
        sfc_file_input_grid="gefs.t00z.pgrb2_combined.0p25.f003"
        varmap_file="${UFSUTILS_DIR}/parm/varmap_tables/GFSphys_var_map.txt"
    
    else
        error_exit "Unknown or unsupported ATM input type: ${ATM_ICTYPE}"
    fi

    generate_namelist
    run_chgres "./chgres_cube_atm.log"
    
    mv "${ATM_RUN_DIR}/gfs_ctrl.nc" "${ATM_RUN_DIR}/intercom/gfs_ctrl.nc"
    mv "${ATM_RUN_DIR}/gfs.bndy.nc" "${ATM_RUN_DIR}/intercom/gfs_bndy.tile${ATM_TILE}.000.nc"
    mv "${ATM_RUN_DIR}/out.atm.tile${ATM_TILE}.nc" "$ATM_OUT"
fi

# ================================= #
# Generating LBC Files              #
# ================================= #

log_info "-> Generating atmosphere LBC files..."

FHRB=${ATM_NBDYINT}
FHRE=${NHRS}
FHRI=${ATM_NBDYINT}
FHR=${FHRB}

if [ $ATM_BCTYPE = "grib_files" ]; then
    convert_atm=.true.
    convert_sfc=.false.
    convert_nst=.false.
    mosaic_file_input_grid="NULL"
    orog_dir_input_grid="NULL"
    orog_files_input_grid="NULL"
    data_dir_input_grid="${ATM_DATA_DIR}/fcst/atmos/combined"
    atm_files_input_grid="NULL"
    atm_core_files_input_grid="NULL"
    atm_tracer_files_input_grid="NULL"
    sfc_files_input_grid="NULL"
    convert_nst=.true.
    input_type="grib2"
    tracers="sphum","liq_wat","o3mr","ice_wat","rainwat","snowwat","graupel"
    tracers_input="spfh","clmr","o3mr","icmr","rwmr","snmr","grle"
    varmap_file="${UFSUTILS_DIR}/parm/varmap_tables/GFSphys_var_map.txt"
else
    error_exit "Unknown or unsupported LBC input type: ${ATM_BCTYPE}"
fi

while [ "$FHR" -le "$FHRE" ]; do
    FHR3=$(printf "%03d" "$FHR")
    LBC_OUT="${ATM_RUN_DIR}/intercom/gfs_bndy.tile${ATM_TILE}.${FHR3}.nc"

    if [ -s "$LBC_OUT" ]; then
        log_info "-> Atmosphere LBC file for forecast hour ${FHR3} already exists. Skipping."
    else
        log_info "-> Processing LBC at forecast hour ${FHR3}"
    
        grib2_file_input_grid="gefs.t${cycle_hour}z.pgrb2_combined.0p25.f${FHR3}"
        
        generate_namelist
        run_chgres "./chgres_cube_lbc_${FHR3}.log"
    
        mv "${ATM_RUN_DIR}/gfs.bndy.nc" "$LBC_OUT"
    
    fi
    FHR=$(($FHR + ${FHRI}))
done

log_info "-> Atmosphere prep complete."
exit 0
