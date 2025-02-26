Description
===========
Contact: Kristin Barton (Kristin.Barton@noaa.gov)

These scripts will generate IC and lateral BCs for the MOM6 Arctic domain
based on RTOFS input datasets found in the HAFS test case repositories.
It has currently been tested for 2020-08-25, single forecast cycle run.

How to run
==========
1. Copy MOM6 mesh files from (Hera): `/scratch2/BMC/gsienkf/Kristin.Barton/files/ufs_arctic_development/ocn_prep/fix` into the repositories's `fix` directory
2. Edit the initial parameters in the `run_init.sh` file for your system/account
3. Run: `./run_init.sh`

Directories
===========
* `fix`:
    Contains necessary MOM6 Arctic grid files:
    * `ocean_hgrid.nc`
    * `ocean_mask.nc`
    * `ocean_vgrid.nc`
    If the `ocean_hgrid_00*.nc` are missing, find `extract_edges.py` in `utils/` directory, link to it in directory containing above files, and run.

* `intercom`:
    Contains all output files. Copy these into your model run INPUT/ directory.

* `inputs`:
    Contains files related to RTOFS and GFS input data.

* `modules`:
    Contains code for performing the IC/BC remapping steps.

* `utils`:
    Contains miscellaneous scripts that may be useful.

## Files
1. `run_init.sh`: This is the primary driver. It will perform the process to generate:
* Initial Condition files from RTOFS
* Lateral Boundary Condition files from RTOFS
* Data atmosphere forcing from GFS
2. `remap_ICs.sh`: This is the driver for the initial condition remapping steps. It is called by `run_init.sh`
3. `remap_OBCs.sh`: This is the driver for the lateral boundary condition remapping steps. It is called by `run_init.sh`
4. `rtofs_to_mom6.py`: This contains the main remapping logic. It is called by the `remap_*.sh` scripts.
