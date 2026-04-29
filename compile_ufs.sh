#!/bin/bash
#SBATCH --job-name=ufs_compile
#SBATCH --partition=u1-compute
#SBATCH --time=30:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --output=slurm_compile_%j.log

# ============================================================= #
# USAGE:
# sbatch --account=<your_account> compile_ufs.sh [OPTIONS]
#
# OPTIONS:
#  -s|--system SYS      Target system (ursa, hera). Default: ursa
#  -c|--compiler COMP   Target compiler (gnu, intel, intelllvm). Default: intelllvm
#  --ufs-dir DIR        Optional UFS Directory to compile instead of submodule
# ============================================================= #

set -eo pipefail

log_info() { echo -e "(info) $1"; }
log_warn() { echo -e "(Warn) $1"; }
log_error() { echo -e "[ERROR] $1"; }
error_exit() { log_error "$1"; exit 1; }

SYSTEM="ursa"
COMPILER="intelllvm"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --system) SYSTEM="$2"; shift 2 ;;
        --compiler) COMPILER="$2"; shift 2 ;;
        --ufs-dir) UFS_DIR="$2"; shift 2 ;;
        -h|--help)
            grep "^#" "$0" | grep -v "^#SBATCH" | grep -v "^#!" # Prints USAGE block above
            exit 0
            ;;
        *) echo "Error: Unknown option '$1'. Use -h for help." >&2; exit 1 ;;
    esac
done

if [[ -n "$SLURM_SUBMIT_DIR" ]]; then 
    export TOP_DIR="$SLURM_SUBMIT_DIR"
else
    export TOP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
fi

export UFS_DIR="${TOP_DIR}/ufs-weather-model"
module_path="/contrib/spack-stack/spack-stack-1.9.3/envs/ue-oneapi-2024.2.1/install/modulefiles/Core"

log_info "Starting UFS Compilation process for System: $SYSTEM | Compiler: $COMPILER"
log_info "Compiling in UFS directory: $UFS_DIR"

[ -d "$UFS_DIR" ] || error_exit "UFS Model directory not found: $UFS_DIR Did you run git submodule update --init --recursive?"

# Compile
(
    cd "${UFS_DIR}"
    module use modulefiles || error_exit "Failed to find modulefiles."
    module load "ufs_${SYSTEM}.${COMPILER}.lua" || error_exit "Failed to load UFS module."
    
    if [ -d "build" ]; then
        log_warn "Existing build directory found. Cleaning..."
        (cd build && make clean)
    fi

    log_info "Running CMake and build scripts..."
    export CMAKE_FLAGS="-DDEBUG=OFF -DAPP=S2S -DREGIONAL_MOM6=ON -DMOVING_NEST=OFF -DCCPP_SUITES=FV3_GFS_v17_coupled_p8_ugwpv1"
    ./build.sh

    # Generate Provenance Metadata
    log_info "Generating build metadata..."
    META_FILE="${UFS_DIR}/build/build_metadata.txt"
    echo "========================================" > "$META_FILE"
    echo "UFS Build" >> "$META_FILE"
    echo "Build Date: $(date)" >> "$META_FILE"
    echo "System: ${SYSTEM}" >> "$META_FILE"
    echo "Compiler: ${COMPILER}" >> "$META_FILE"
    echo "CMake Flags: ${CMAKE_FLAGS}" >> "$META_FILE"
    
    if [ -d "${UFS_DIR}/.git" ]; then
        echo "Git Branch: $(git -C "${UFS_DIR}" rev-parse --abbrev-ref HEAD)" >> "$META_FILE"
        echo "Git Hash: $(git -C "${UFS_DIR}" rev-parse HEAD)" >> "$META_FILE"
    fi
    echo "========================================" >> "$META_FILE"
)

log_info "Compilation complete. Executable is ready at: ${UFS_DIR}/build/ufs_model"

