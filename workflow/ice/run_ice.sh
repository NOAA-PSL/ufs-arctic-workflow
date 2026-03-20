#!/bin/bash
# ==============================================================================
# Ice Prep Script (run_ice.sh)
# Description: Generates ice initial condition files using ESMF regridding
# ==============================================================================

set -e -o pipefail

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

# ================================= #
# Generate Weights                  #
# ================================= #

log_info "Generating ice initial condition files..."
if [ ! -e ${ICE_WGT_FILE} ]; then
    log_info "Weight file ${ICE_WGT_FILE} does not exist. Creating via ESMF..."

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
    log_info "Weight file already exists, skipping generation: ${ICE_WGT_FILE}"
fi

# ================================= #
# Interpolate Ice Data              #
# ================================= #

log_info "Running Python interpolation script..."

mkdir -p "${ICE_RUN_DIR}/intercom"

python interp_ice.py \
    --wgt_file "${ICE_WGT_FILE}" \
    --src_file "iced.${yyyy}-${mm}-${dd}-${sssss}.nc" \
    --src_angl "${ICE_SRC_ANG_FILE}" \
    --msk_file "${ICE_DST_FILE}" \
    --dst_angl "${ICE_DST_ANG_FILE}" \
    --out_file "${ICE_RUN_DIR}/intercom/replay_ice.arctic_grid.${yyyy}-${mm}-${dd}-${hh}-${sssss}.nc" || error_exit "interp_ice.py crashed."

log_info "Ice IC file generation complete."
exit 0
