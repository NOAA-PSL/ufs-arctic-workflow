#!/bin/bash

# ================================= #
# User-Adjusted Parameters          #
# ================================= #

SACCT="ufs-artic"       # Account for job submission
HOURS=240               # Model forecast length (Max: 240 Hours)
RES="C918"              # Model resolution (C918: ~11km; C185: ~50km)
DATES=(                 # Format: YYYYMMDD
    "20191028"          # Options: 20191028 | 20200227 | 20200702 | 20200709 | 20200827
    "20200227"
    "20200702"
    "20200709"
    "20200827"
)
UFS_DIR=""              # Optional: Specify pre-compiled directory. Leave blank to compile from UFS submodule.

BASE_RUN_DIR="/scratch4/BMC/${SACCT}/${USER}/stmp" # Output will go in ${BASE_RUN_DIR}/${JOB_NAME}

# ================================= #
# Other SLURM Options               #
# ================================= #

PARTITION="u1-compute"  # Specify partition
TIME="00:60:00"         # C918 may take longer than 60m. C185 should be less than 30m
NODES=2                 # Specify nodes
NTASKS=4                # Specify tasks

# ================================= #
# Execution Loop                    #
# ================================= #

echo "Starting batch submission..."
SCRIPT="./workflow/submit_workflow.sh"

for d in "${DATES[@]}"; do
    echo ">> Configuring run for date: $d"

    # Edit this as well if desired. Output will go in ${BASE_RUN_DIR}/${JOB_NAME}
    JOB_NAME="${RES}_${d}_${HOURS}HRS"

    CMD=(
        "sbatch"
        "--account=$ACCOUNT"
        "--partition=$PARTITION"
        "--time=$TIME"
        "--nodes=$NODES"
        "--ntasks=$NTASKS"
        "--job-name=Prep_${JOB_NAME}"
        "$SCRIPT"
        "--date" "$d"
        "--hours" "$HOURS"
        "--account" "$ACCOUNT"
        "--res" "$RES"
        "--run-dir" "$BASE_RUN_DIR"
        "--job-name" "$JOB_NAME")

    if [[ -n "UFS_DIR" ]]; then
        CMD+=("--ufs-dir" "$UFS_DIR")
    fi

    # Uncomment below if you want to prep the model run WITHOUT submitting the final job
    #CMD+=("--norun")

    # Uncomment one of the options below if you want to ONLY run a specific portion of the workflow
    #STEP="compile"
    #STEP="prep_ocn"
    #STEP="prep_ice"
    #STEP="prep_atm"
    #CMD+=("--step" "$STEP")

    "${CMD[@]}"

    sleep 1
done
