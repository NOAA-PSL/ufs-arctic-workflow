#!/bin/bash

# ================================= #
# User-Adjusted Parameters          #
# ================================= #

SACCT="ufs-artic"       # Account for job submission
HOURS=3                 # Model forecast length (Max: 240 Hours)
RES=(                   # Model resolution (C918 ~11km; C185 ~50km)
#    "C918"
    "C185"
)
DATES=(                 # Format: YYYYMMDD
    "20191028"          # Options: 20191028 | 20200227 | 20200702 | 20200709 | 20200827
#    "20200227"
#    "20200702"
#    "20200709"
#    "20200827"
)
# Optional: Specify pre-compiled directory. Leave blank to run from current directory.
#UFS_DIR="/scratch4/BMC/ufs-artic/Kristin.Barton/repos/kristinbarton/ufs-arctic-workflow/build/C5203a784/ufs-weather-model/"              
UFS_DIR=""

BASE_RUN_DIR="/scratch4/BMC/${SACCT}/${USER}/stmp/2mtmp_tests" # Output will go in ${BASE_RUN_DIR}/${JOB_NAME}

# ================================= #
# Other SLURM Options               #
# ================================= #

QOS="batch"             # Specify QOS
TIME="00:30:00"         # C918 may take longer than 60m. C185 should be less than 30m
NODES=2                 # Specify nodes
NTASKS=4                # Specify tasks

# ================================= #
# Execution Loop                    #
# ================================= #

echo "Starting batch submission..."
SCRIPT="./workflow/submit_workflow.sh"

for d in "${DATES[@]}"; do
for r in "${RES[@]}"; do
    echo ">> Configuring run for date: $d | Hours: $HOURS | Resolution: $r | Acct: $SACCT"

    # Edit this as well if desired. Output will go in ${BASE_RUN_DIR}/${JOB_NAME}
    JOB_NAME="${RES}_${d}_${HOURS}HRS"

    CMD=(
        "sbatch"
        "--account=$SACCT"
        "--qos=$QOS"
        "--time=$TIME"
        "--nodes=$NODES"
        "--ntasks=$NTASKS"
        "--job-name=Prep_${JOB_NAME}"
        "$SCRIPT"
        "--date" "$d"
        "--hours" "$HOURS"
        "--res" "$r"
        "--run-dir" "$BASE_RUN_DIR"
        "--job-name" "$JOB_NAME")

    if [[ -n "UFS_DIR" ]]; then
        CMD+=("--ufs-dir" "$UFS_DIR")
    fi

    # Uncomment this if you want to prep the model run WITHOUT submitting the final job
    #CMD+=("--norun")

    "${CMD[@]}"

    sleep 1
done
done
