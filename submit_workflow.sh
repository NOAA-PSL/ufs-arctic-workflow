#!/bin/bash

# ================================= #
# User-Adjusted Parameters          #
# ================================= #

SACCT="ufs-artic"       # Account for job submission
HOURS=3                 # Model forecast length (Max: 240 Hours)
ATM_RES=(                   # Model resolution (C918 ~11km; C185 ~50km)
    "C185"
#    "C918"
)
OCN_RES=(
    "ARC12"             # ARC12 = 12km, ARC0p08 = 3-5km
#    "ARC0p08"
)
DATES=(                 # Format: YYYYMMDD
    "20191028"          # Options: 20191028 | 20200227 | 20200702 | 20200709 | 20200827
#    "20200227"
#    "20200702"
#    "20200709"
#    "20200827"
)
# Optional: Specify pre-compiled directory. Leave blank to run from current directory.
#UFS_DIR="/scratch4/BMC/ufs-artic/Kristin.Barton/repos/kristinbarton/ufs-arctic-workflow/build/C8db7efa4/ufs-weather-model/"       
UFS_DIR=""

BASE_RUN_DIR="/scratch4/BMC/${SACCT}/${USER}/stmp/config" # Output will go in ${BASE_RUN_DIR}/${JOB_NAME}

# ================================= #
# Other SLURM Options               #
# ================================= #

QOS="debug"             # Specify QOS
TIME="00:30:00"         # 30 min should work for C918 and C185
NODES=1                 # Specify nodes
NTASKS=30               # Specify tasks - Must be multiples of 6
CPUS=2                  # CPUS per task - Must be >= 2

# ================================= #
# Execution Loop                    #
# ================================= #

echo "Starting batch submission..."
SCRIPT="./workflow/run_workflow.sh"

for d in "${DATES[@]}"; do
for a in "${ATM_RES[@]}"; do
for o in "${OCN_RES[@]}"; do
    echo ">> Configuring run for date: $d | Hours: $HOURS | Atm: $a | Ocn: $o | Acct: $SACCT"

    # Edit this as well if desired. Output will go in ${BASE_RUN_DIR}/${JOB_NAME}
    JOB_NAME="${a}.${o}.${d}_${HOURS}HRS"

    CMD=(
        "sbatch"
        "--account=$SACCT"
        "--qos=$QOS"
        "--time=$TIME"
        "--nodes=$NODES"
        "--ntasks=$NTASKS"
        "--cpus-per-task=$CPUS"
        "--job-name=Prep_${JOB_NAME}"
        "$SCRIPT"
        "--date" "$d"
        "--hours" "$HOURS"
        "--atm-res" "$a"
        "--ocn-res" "$o"
        "--run-dir" "$BASE_RUN_DIR"
        "--job-name" "$JOB_NAME")

    if [[ -n "UFS_DIR" ]]; then
        CMD+=("--ufs-dir" "$UFS_DIR")
    fi

    # Uncomment one of these if you want to run only a single prep step
    #CMD+=("--step" "prep_atm")
    #CMD+=("--step" "prep_ocn")
    #CMD+=("--step" "prep_ice")

    # Uncomment this if you want to prep the model run WITHOUT submitting the final job
    #CMD+=("--norun")

    "${CMD[@]}"

    sleep 1

done # OCN_RES
done # ATM_RES
done # DATES
