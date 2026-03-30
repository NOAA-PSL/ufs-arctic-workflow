#!/bin/bash
# ==============================================================================
# Ice Prep Script (run_ice.sh)
# Description: Generates ice initial condition files using ESMF regridding
# ==============================================================================

set -e -o pipefail

# ================================= #
# Logging & Validation              #
# ================================= #

log_info()  { echo -e "(info) $1"; }
log_warn()  { echo -e "(Warn) $1"; }
log_error() { echo -e "[ERROR] $1" >&2; }
error_exit() {
    log_error "$1"
    exit 1
}

required_vars=(
    "CDATE" "APRUNS" "ICE_RUN_DIR" "ICE_SRC_FILE"
    "ICE_DST_FILE" "ICE_WGT_FILE" "ICE_SRC_ANG_FILE" "ICE_DST_ANG_FILE"
)
for var in "${required_vars[@]}"; do
    [[ -z "${!var}" ]] && error_exit "Required variable '$var' is not set."
done

# ================================= #
# Date & Time                       #
# ================================= #

yyyy="${CDATE:0:4}"
mm="${CDATE:4:2}"
dd="${CDATE:6:2}"
#hh="${CDATE:8:2}"
#sssss=$(( 10#$hh * 3600 ))
sssss=10800

METHOD="neareststod"

mkdir -p "${ICE_RUN_DIR}/intercom"
OUT_FILE="${ICE_RUN_DIR}/intercom/replay_ice.arctic_grid.${yyyy}-${mm}-${dd}-${sssss}.nc"
if [ -f "$OUT_FILE" ] && [ -s "$OUT_FILE" ]; then
    log_info "Interpolated ice file already exists. Skipping..."
    log_info "-> $OUT_FILE"

else
    log_info "-> Generating ice initial condition files..."

    # ================================= #
    # Generate Weights                  #
    # ================================= #
    if [ ! -e ${ICE_WGT_FILE} ]; then
        log_info "-> Weight file ${ICE_WGT_FILE} does not exist. Creating via ESMF..."
    
        ${APRUNS} ESMF_RegridWeightGen \
            -s "${ICE_SRC_FILE}" \ 
            -d "${ICE_DST_FILE}" \
            -w "${ICE_WGT_FILE}" \
            -m "${METHOD}" \
            --dst_loc center \
            --netCDF4 \
            --dst_regional \
            --ignore_degenerate || error_exit "ESMF_RegridWeightGen failed."
    else
        log_info "-> Weight file already exists, skipping generation: ${ICE_WGT_FILE}"
    fi
    
    log_info "-> Running interpolation script..."
    # ================================= #
    # Interpolate Ice Data              #
    # ================================= #
    python interp_ice.py \
        --wgt_file "${ICE_WGT_FILE}" \
        --src_file "iced.${yyyy}-${mm}-${dd}-${sssss}.nc" \
        --src_angl "${ICE_SRC_ANG_FILE}" \
        --msk_file "${ICE_DST_FILE}" \
        --dst_angl "${ICE_DST_ANG_FILE}" \
        --out_file "${OUT_FILE}" || error_exit "interp_ice.py crashed."
fi

log_info "-> Ice prep complete."
exit 0
