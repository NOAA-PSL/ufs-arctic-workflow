For more information, see the [UFS-Arctic Wiki](https://github.com/NOAA-PSL/ufs-arctic-workflow/wiki/UFS%E2%80%90Arctic-Workflow-Wiki).

Quick Start Guide
=================

Ursa 
----
1. Clone the workflow and then update submodules: 
    `git submodule update --init --recursive`
2. Compile the UFS model:
    `sbatch --account <job-account> compile_ufs.sh`
3. Open the wrapper script `run_workflow.sh` to configure your experiment(s).
   Adjust the slurm account, run length, resolution, dates, etc.
4. Execute the workflow script: 
    `.\run_workflow.sh`

(*Optional*) If you have an existing, pre-compiled UFS directory you would like to work from,
you can skip the compile step and specify the directory directly in `run_workflow.sh`.
***Note:*** The supplied directory **must** contain `build/ufs_model` and a populated `modulefiles`.
***Note:*** Configure options and settings may not be compatible with other UFS executables!

*More information*:
- There are currently a limited number of available dates:
    - 2019/10/28
    - 2020/02/27
    - 2020/07/02
    - 2020/07/09
    - 2020/08/27
- The model can be run from 3 hrs to a maximum of 240 hrs.
- Atmosphere resolution options are C918 (~11km) or C185 (~50km)
