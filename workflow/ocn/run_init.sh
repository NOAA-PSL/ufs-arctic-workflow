#!/bin/sh
# ==============================================================================
# Ocean Prep Script (run_init.sh)
# Description: Prepares inputs for MOM6 Arctic grid, including initial
#              conditions (IC), lateral boundary conditions (OBC), and forcing.
# ==============================================================================

set -eo pipefail

# ================================= #
# Logging & Validation              #
# ================================= #

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }
error_exit() { log_error "$1"; exit 1; }

[[ "$VERBOSE" == "true" ]] && set -x

# Fail-fast validation
required_vars=(
    "CDATE" "OCNINTYPE" "NLN" "APRUNS" "OCN_RUN_DIR" 
    "OCN_SCRIPT_DIR" "OCN_DST_GRID_DIR" "OCN_SRC_GRID_DIR"
)
for var in "${required_vars[@]}"; do
    [[ -z "${!var}" ]] && error_exit "Required variable '$var' is not set."
done

# ================================= #
# Date Parsing & Setup              #
# ================================= #

ymd="${CDATE:0:8}"
hour="00"

if [ "${hour}" == "00" ]; then
  type=${type:-n}
else
  type=${type:-f}
fi

mkdir -p "${OCN_RUN_DIR}/intercom/"
mkdir -p "${OCN_RUN_DIR}/inputs/"

# Retrive the regridding weights and ocean grid files
mkdir -p ${OCN_RUN_DIR}/inputs/
${NLN} "${OCN_DST_GRID_DIR}"/* "${OCN_RUN_DIR}/inputs/."
${NLN} "${OCN_SRC_GRID_DIR}"/* "${OCN_RUN_DIR}/inputs/."
${NLN} "${OCN_SCRIPT_DIR}/inputs/"* "${OCN_RUN_DIR}/inputs/."

if [ $OCNINTYPE == 'gefs' ]; then
    export WGT_FILE_BASE=${OCN_WGT_FILE_BASE}
    ICFILENAME="${OCN_RUN_DIR}/inputs/Ct.mx025_SCRIP_masked.nc"
    BCFILENAME="${OCN_RUN_DIR}/inputs/Ct.mx025_SCRIP.nc"
    METHOD="neareststod"
    ${NLN} ${OCN_SRC_DIR}/*.nc ${OCN_RUN_DIR}/inputs/.
elif [[ "$OCNINTYPE" == 'rtofs' ]]; then
    WGT_FILE_BASE='rtofs2arctic'
    ICFILENAME="${OCN_RUN_DIR}/inputs/rtofs_global_ssh_ic.nc"
    BCFILENAME="${OCN_RUN_DIR}/inputs/rtofs_global_ssh_ic.nc"
    METHOD="neareststod"
fi

# ================================= #
# Functions Definitions             #
# ================================= #

link_rtofs_archive() {
    local hr="$1"
    local prefix="${COMINrtofs}/rtofs.${ymd}/rtofs_glo.t00z.${type}${hr}.archv"

    for ext in a b; do
        if [[ -e "${prefix}.${ext}" ]]; then
            ${NLN} "${prefix}.${ext}" "archv_in.${ext}"
        elif [[ -e "${prefix}.${ext}.tgz" ]]; then
            log_info "Extracting ${prefix}.${ext}.tgz..."
            tar -xpvzf "${prefix}.${ext}.tgz"
            ${NLN} "rtofs_glo.t00z.${type}${hr}.archv.${ext}" "archv_in.${ext}"
        else
            error_exit "RTOFS archive missing: ${prefix}.${ext} (or .tgz equivalent)"
        fi
    done
}

generate_weight() {
    local src="$1"
    local dst="$2"
    local wgt="$3"

    if [[ ! -e "$wgt" ]]; then
        log_info "Creating weight file: ${wgt}"
        ${APRUNS} ESMF_RegridWeightGen -s "$src" -d "$dst" -w "$wgt" -m "$METHOD" \
            --dst_loc center --netCDF4 --dst_regional --ignore_degenerate > /dev/null || error_exit "ESMF failed on ${wgt}"
    fi
}

# ================================= #
# Initial Conditions (IC) Setup     #
# ================================= #

log_info "Generating Ocean IC files..."
cd "${OCN_RUN_DIR}/inputs/"

if [[ "$OCNINTYPE" == 'rtofs' ]]; then
    export CDF038="rtofs_global_ssh_ic.nc"
    export CDF034="rtofs_global_ts_ic.nc"
    export CDF033="rtofs_global_uv_ic.nc"

    # Link global RTOFS depth and grid files
    ${NLN} "${FIXhafs}/fix_mom6/fix_gofs/depth_GLBb0.08_09m11ob.a" regional.depth.a
    ${NLN} "${FIXhafs}/fix_mom6/fix_gofs/depth_GLBb0.08_09m11ob.b" regional.depth.b
    ${NLN} "${FIXhafs}/fix_hycom/rtofs_glo.navy_0.08.regional.grid.a" regional.grid.a
    ${NLN} "${FIXhafs}/fix_hycom/rtofs_glo.navy_0.08.regional.grid.b" regional.grid.b

    link_rtofs_archive "$hour"

    # Run HYCOM-tools executables
    log_info "Running HYCOM archv2ncdf utilities (IC)..."
    ${APRUNS} "${EXEChafs}/hafs_hycom_utils_archv2ncdf3z.x" < ./rtofs_global_3d_ic.in 2>&1 | tee archv2ncdf3z_3d_ic.log > /dev/null
    ${APRUNS} "${EXEChafs}/hafs_hycom_utils_archv2ncdf2d.x" < ./rtofs_global_ssh_ic.in 2>&1 | tee archv2ncdf2d_ssh_ic.log > /dev/null

    unlink archv_in.a
    unlink archv_in.b
fi

# Generate Subgrids
if [[ ! -e "ocean_subgrid_v.nc" ]] && [[ ! -e "ocean_subgrid_u.nc" ]]; then
    log_info "U/V subgrid files do not exist. Creating them..."
    "${OCN_SCRIPT_DIR}/utils/make_subgrids.py" --lat y --lon x --fin ocean_hgrid.nc --out ocean_subgrid
fi

# Generate Center, U, and V Weights
generate_weight "${ICFILENAME}" "ocean_mask.nc"      "${WGT_FILE_BASE}_h.nc"
generate_weight "${ICFILENAME}" "ocean_subgrid_v.nc" "${WGT_FILE_BASE}_v.nc"
generate_weight "${ICFILENAME}" "ocean_subgrid_u.nc" "${WGT_FILE_BASE}_u.nc"

log_info "Executing Python Remapping for Initial Conditions..."

INPUT_DIR="${OCN_RUN_DIR}/inputs"
OUTPUT_DIR="${OCN_RUN_DIR}/intercom"
OUT_FILE_PATH="${OUTPUT_DIR}/${OCN_IC_FILE}"
DST_VRT_FILE_PATH="${INPUT_DIR}/${OCN_DST_VRT_FILE}"
H_WGT="${INPUT_DIR}/${WGT_FILE_BASE}_h.nc"

log_info "-> Remapping U-V Vectors..."
${APRUNS} python "${OCN_SCRIPT_DIR}/rtofs_to_mom6.py" \
    --var_name "${OCN_U_VARNAME}" "${OCN_V_VARNAME}" \
    --src_file "${INPUT_DIR}/${OCN_U_SRC_FILE}" "${INPUT_DIR}/${OCN_V_SRC_FILE}" \
    --src_ang_name "${OCN_SRC_ANG_NAME}" \
    --src_ang_file "${INPUT_DIR}/${OCN_SRC_ANG_FILE}" \
    --src_ang_supergrid "${OCN_SRC_CONVERT_ANG}" \
    --dst_ang_name "${OCN_DST_ANG_NAME}" \
    --dst_ang_file "${INPUT_DIR}/${OCN_DST_ANG_FILE}" \
    --dst_ang_supergrid "${OCN_DST_CONVERT_ANG}" \
    --wgt_file "${INPUT_DIR}/${WGT_FILE_BASE}_u.nc" "${INPUT_DIR}/${WGT_FILE_BASE}_v.nc" \
    --vrt_file "${DST_VRT_FILE_PATH}" \
    --out_file "${OUT_FILE_PATH}" \
    --dz_name "${OCN_DST_VRT_NAME}" \
    --time_name "${OCN_TIME_VARNAME}" || error_exit "U-V Vector remapping failed."

# Define scalars in a delimited array: "DisplayName:VariableName:SourceFile"
scalars=(
    "Temperature:${OCN_TMP_VARNAME}:${OCN_TMP_SRC_FILE}"
    "Salinity:${OCN_SAL_VARNAME}:${OCN_SAL_SRC_FILE}"
    "Thickness:${OCN_THK_VARNAME}:${OCN_THK_SRC_FILE}"
    "SSH:${OCN_SSH_VARNAME}:${OCN_SSH_SRC_FILE}"
)

for item in "${scalars[@]}"; do
    desc="${item%%:*}"
    rest="${item#*:}"
    var_name="${rest%%:*}"
    src_file="${rest#*:}"

    log_info "-> Remapping ${desc} (${var_name})..."
    ${APRUNS} python "${OCN_SCRIPT_DIR}/rtofs_to_mom6.py" \
        --var_name "${var_name}" \
        --src_file "${INPUT_DIR}/${src_file}" \
        --wgt_file "${H_WGT}" \
        --vrt_file "${DST_VRT_FILE_PATH}" \
        --out_file "${OUT_FILE_PATH}" \
        --dz_name "${OCN_DST_VRT_NAME}" \
        --time_name "${OCN_TIME_VARNAME}" || error_exit "${desc} remapping failed."
done

log_info "-> Adding ETA variable to IC file..."
${APRUNS} python "${OCN_SCRIPT_DIR}/utils/add_eta.py" \
    --file_name "${OUT_FILE_PATH}" \
    --thickness_variable "${OCN_THK_VARNAME}" \
    --time_dim "${OCN_TIME_VARNAME}" || error_exit "Failed to add ETA variable."

# ================================= #
# Lateral Boundaries (OBC) Setup    #
# ================================= #

log_info "Generating Ocean OBC files..."
cd "${OCN_RUN_DIR}/inputs/"

if [[ "$OCNINTYPE" == 'rtofs' ]]; then
    export CDF038="rtofs.${type}${hour}_global_ssh_obc.nc"
    export CDF034="rtofs.${type}${hour}_global_ts_obc.nc"
    export CDF033="rtofs.${type}${hour}_global_uv_obc.nc"

    link_rtofs_archive "$hour"

    log_info "Running HYCOM archv2ncdf utilities (OBC)..."
    ${APRUNS} "${EXEChafs}/hafs_hycom_utils_archv2ncdf2d.x" < ./rtofs_global_ssh_obc.in 2>&1 | tee archv2ncdf2d_ssh_obc.log > /dev/null
    ${APRUNS} "${EXEChafs}/hafs_hycom_utils_archv2ncdf3z.x" < ./rtofs_global_3d_obc.in 2>&1 | tee archv2ncdf3z_3d_obc.log > /dev/null

    unlink archv_in.a
    unlink archv_in.b
elif [[ "$OCNINTYPE" != 'gefs' ]]; then
    error_exit "OCN source grid type invalid: ${OCNINTYPE}"
fi

TMP_VARNAME_OUT="${OCN_TMP_VARNAME_OUT:-$OCN_TMP_VARNAME}"
TIME_VARNAME_OUT="${OCN_TIME_VARNAME_OUT:-$OCN_TIME_VARNAME}"

obc_scalars=(
    "Temperature:${OCN_TMP_VARNAME}:${OCN_TMP_SRC_FILE}"
    "Salinity:${OCN_SAL_VARNAME}:${OCN_SAL_SRC_FILE}"
    "SSH:${OCN_SSH_VARNAME}:${OCN_SSH_SRC_FILE}"
)

for i in 001 002 003 004; do
    log_info "=== Processing OBC Boundary ${i} ==="
    
    WGT_FILE="${WGT_FILE_BASE}_${i}.nc"
    WGT_PATH="${INPUT_DIR}/${WGT_FILE}"
    OBC_OUT_PATH="${OUTPUT_DIR}/${OCN_OUT_FILE_PATH_BASE}${i}${OCN_FILE_TAIL}"
    ANG_FILE="${INPUT_DIR}/${OCN_ANG_FILE_PATH_BASE}${i}${OCN_FILE_TAIL}"
    HGRID_PATH="${INPUT_DIR}/ocean_hgrid_${i}.nc"
    
    generate_weight "${BCFILENAME}" "ocean_hgrid_${i}.nc" "${WGT_FILE}"

    # --- 1. Remap U-V Vectors ---
    log_info "-> Remapping OBC U-V Vectors..."
    ${APRUNS} python "${OCN_SCRIPT_DIR}/rtofs_to_mom6.py" \
        --var_name "${OCN_U_VARNAME}" "${OCN_V_VARNAME}" \
        --src_file "${INPUT_DIR}/${OCN_U_SRC_FILE}" "${INPUT_DIR}/${OCN_V_SRC_FILE}" \
        --src_ang_name "${OCN_SRC_ANG_NAME}" \
        --src_ang_file "${INPUT_DIR}/${OCN_SRC_ANG_FILE}" \
        --src_ang_supergrid "${OCN_SRC_CONVERT_ANG}" \
        --dst_ang_name "${OCN_DST_ANG_NAME}" \
        --dst_ang_file "${ANG_FILE}" \
        --dst_ang_supergrid "${OCN_DST_CONVERT_ANG}" \
        --wgt_file "${WGT_PATH}" \
        --vrt_file "${DST_VRT_FILE_PATH}" \
        --out_file "${OBC_OUT_PATH}" \
        --dz_name "${OCN_DST_VRT_NAME}" \
        --time_name "${OCN_TIME_VARNAME}" \
        --time_name_out "${TIME_VARNAME_OUT}" || error_exit "OBC Boundary ${i} U-V remapping failed."

    # --- 2. Remap Scalars ---
    for item in "${obc_scalars[@]}"; do
        desc="${item%%:*}"
        rest="${item#*:}"
        var_name="${rest%%:*}"
        src_file="${rest#*:}"

        log_info "-> Remapping OBC ${desc} (${var_name})..."
        ${APRUNS} python "${OCN_SCRIPT_DIR}/rtofs_to_mom6.py" \
            --var_name "${var_name}" \
            --src_file "${INPUT_DIR}/${src_file}" \
            --wgt_file "${WGT_PATH}" \
            --vrt_file "${DST_VRT_FILE_PATH}" \
            --out_file "${OBC_OUT_PATH}" \
            --dz_name "${OCN_DST_VRT_NAME}" \
            --time_name "${OCN_TIME_VARNAME}" \
            --time_name_out "${TIME_VARNAME_OUT}" || error_exit "OBC Boundary ${i} ${desc} remapping failed."
    done

    # --- 3. Format NetCDF Files (NCO) ---
    log_info "-> Reformatting OBC_${i} NetCDF structure..."
    
    # Rename dimensions and variables
    ncrename -O \
        -d "${OCN_DST_VRT_NAME},nz_segment_${i}" \
        -d "yh,ny_segment_${i}" \
        -d "xh,nx_segment_${i}" \
        -v "${OCN_SSH_VARNAME},ssh_segment_${i}" \
        -v "${OCN_TMP_VARNAME},temp_segment_${i}" \
        -v "${OCN_SAL_VARNAME},salinity_segment_${i}" \
        -v "${OCN_U_VARNAME},u_segment_${i}" \
        -v "${OCN_V_VARNAME},v_segment_${i}" "${OBC_OUT_PATH}"

    # Generate dz arrays via ncap2
    ncap2 -O -s "dz_u_segment_${i}[${TIME_VARNAME_OUT},nz_segment_${i},ny_segment_${i},nx_segment_${i}]=${OCN_DST_VRT_NAME}(:)" "${OBC_OUT_PATH}" "${OBC_OUT_PATH}"
    ncap2 -O -s "dz_v_segment_${i}[${TIME_VARNAME_OUT},nz_segment_${i},ny_segment_${i},nx_segment_${i}]=${OCN_DST_VRT_NAME}(:)" "${OBC_OUT_PATH}" "${OBC_OUT_PATH}"
    ncap2 -O -s "dz_ssh_segment_${i}[${TIME_VARNAME_OUT},nz_segment_${i},ny_segment_${i},nx_segment_${i}]=${OCN_DST_VRT_NAME}(:)" "${OBC_OUT_PATH}" "${OBC_OUT_PATH}"
    ncap2 -O -s "dz_salinity_segment_${i}[${TIME_VARNAME_OUT},nz_segment_${i},ny_segment_${i},nx_segment_${i}]=${OCN_DST_VRT_NAME}(:)" "${OBC_OUT_PATH}" "${OBC_OUT_PATH}"
    ncap2 -O -s "dz_temp_segment_${i}[${TIME_VARNAME_OUT},nz_segment_${i},ny_segment_${i},nx_segment_${i}]=${OCN_DST_VRT_NAME}(:)" "${OBC_OUT_PATH}" "${OBC_OUT_PATH}"

    # Remove the original vertical coordinate variable
    ncks -O -x -v "${OCN_DST_VRT_NAME}" "${OBC_OUT_PATH}" "${OBC_OUT_PATH}" > /dev/null 2>&1

    # Extract Lat/Lon from HGRID and append to OBC output safely
    rm -f tmp.nc
    if [[ "$i" == "001" ]] || [[ "$i" == "002" ]]; then
        ncap2 -A -v -s "lon_segment_${i}[nxp]=x(0,:)" "${HGRID_PATH}" tmp.nc
        ncap2 -A -v -s "lat_segment_${i}[nxp]=y(0,:)" "${HGRID_PATH}" tmp.nc
        ncrename -d "nxp,nx_segment_${i}" tmp.nc
    elif [[ "$i" == "003" ]] || [[ "$i" == "004" ]]; then
        ncap2 -A -v -s "lon_segment_${i}[nyp]=x(:,0)" "${HGRID_PATH}" tmp.nc
        ncap2 -A -v -s "lat_segment_${i}[nyp]=y(:,0)" "${HGRID_PATH}" tmp.nc
        ncrename -d "nyp,ny_segment_${i}" tmp.nc
    fi

    ncap2 -A -v -s "lon_segment_${i}=lon_segment_${i}" tmp.nc "${OBC_OUT_PATH}"
    ncap2 -A -v -s "lat_segment_${i}=lat_segment_${i}" tmp.nc "${OBC_OUT_PATH}"
    rm -f tmp.nc
done

log_info "Ocean Prep complete."
exit 0
