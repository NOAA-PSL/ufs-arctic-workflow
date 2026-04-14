For more information, see the [UFS-Arctic Wiki](https://github.com/NOAA-PSL/ufs-arctic-workflow/wiki/UFS%E2%80%90Arctic-Workflow-Wiki).

Quick Start Guide
=================

Ursa 
----
1. Clone the workflow and then update submodules: `git submodule update --init --recursive`
2. Open `submit_build.sh` and adjust the test run start date, run length, account, system, compiler, and run directory as needed.
   Make sure to edit the run account in line 3!
3. Run the workflow: 
  - `sbatch submit_build.sh`
  - `sbatch submit_build.sh --norun` to setup the run directoy without submitting the model run.

**Notes**:
- There are currently a limited number of available dates:
    - 2019/10/28
    - 2020/02/27
    - 2020/07/02
    - 2020/07/09
    - 2020/08/27
- The model can be run from 3 hrs to a maximum of 240 hrs.
- Atmosphere resolution options are C918 (~11km) or C185 (~50km)
