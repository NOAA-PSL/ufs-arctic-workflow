#!/bin/bash

# ================================= #
# User-Adjusted Parameters          #
# ================================= #

SACCT="ufs-artic"       # Account for job submission
HOURS=3                 # Model forecast length (Max: 240 Hours)
ATM_RES=(                   # Model resolution (C918 ~11km; C185 ~50km)
#    "C185"
    "C918"
)
OCN_RES=(
    "ARC12"             
)
DATES=(  "20200227"  # Format: YYYYMMDD - See all available dates: /scratch4/BMC/ufs-artic/fix/inputs/GEFSv13-reforecasts/
#        "20190912" "20190916" "20190919" "20190923" "20190926" "20190930"
#        "20191003" "20191007" "20191010" "20191014" "20191017" "20191021" "20191024" "20191028" "20191031" "20191104"
#        "20191107" "20191111" "20191114" "20191118" "20191121" "20191125" "20191128" 
#        "20191202" "20191205" "20191209" "20191212"
#        "20200116" "20200120" "20200123" "20200127" "20200130"
#        "20200203" "20200206" "20200213" "20200220" "20200227"
#        "20200305" "20200312" "20200319" "20200326"
#        "20200402" "20200409" "20200416" "20200423" "20200430"
#        "20200611" "20200618" "20200625"
#        "20200702" "20200709" "20200716" "20200723" "20200730"
#        "20200806" "20200813" "20200820" "20200827"
#        "20200903" "20200910" "20200917" "20200924"
#        "20201001" "20201008"
)
# Optional: Specify pre-compiled directory. Leave blank to run from current directory.
#UFS_DIR="/scratch4/BMC/ufs-artic/Kristin.Barton/repos/kristinbarton/ufs-arctic-workflow/build/Cc522566f/ufs-weather-model/"       
UFS_DIR=""

BASE_RUN_DIR="/scratch4/BMC/${SACCT}/${USER}/stmp/" # Output will go in ${BASE_RUN_DIR}/${JOB_NAME}

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
