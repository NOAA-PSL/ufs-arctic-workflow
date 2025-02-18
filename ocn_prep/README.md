# Description
Contact: Kristin Barton (Kristin.Barton@noaa.gov)

These scripts will generate IC and lateral BCs for the MOM6 Arctic domain
based on RTOFS input datasets found in the HAFS test case repositories.
It has currently been tested for 2020-08-25, single forecast cycle run.

NOTE: This is setup to run on Hera. If you are on another system, check `run_init.sh` for correct file locations.

# How to run
1. Copy all files to your local working directory
2. Edit the initial parameters in the `run_init.sh` file
3. Run: `./run_init.sh`

# Repository information

## Directories
* Fix:
    Contains necessary MOM6 Arctic grid files.

* Intercom:
    Contains all output files. Copy these into your model run INPUT/ directory.

* Inputs:
    Contains files related to RTOFS and GFS input data.

* Modules:
    Contains code for performing the IC/BC remapping steps.

* Utils:
    Contains miscellaneous scripts that may be useful.

## Files
1. `run_init.sh`
    This is the primary driver. It will perform the process to generate:
        * Initial Condition files from RTOFS
        * Lateral Boundary Condition files from RTOFS
        * Data atmosphere forcing from GFS

2. `remap_ICs.sh`
    This is the driver for the initial condition remapping steps. 
    It is called by `run_init.sh`

3. `remap_OBCs.sh`
    This is the driver for the lateral boundary condition remapping steps. 
    It is called by `run_init.sh`

4. `rtofs_to_mom6.py`
    This contains the main remapping logic. It is called by the `remap_*.sh` scripts.

