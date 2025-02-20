# UFS-Arctic Documentation
## Description
The UFS-Arctic project aims to set up a regional coupled atmosphere-ocean-sea-ice Arctic forecasting configuration in the UFS framework. 

The UFS-Arctic requires the following pieces:
* UFS coupled regional configuration with FV3, MOM6, and CICE6
* A regional Arctic mesh and other required input files
* Workflow for generating boundary conditions for the regional domain

[HAFS (Hurricane Analysis and Forecast System)](https://github.com/hafs-community/HAFS.git), which uses the UFS framework, already contains some of the pieces we need for setting up regional configurations and boundary conditions. However, it does not come with any Arctic meshes, nor does it run with CICE6. It also includes some extra capabilities that we do not need (such as storm-following nests)

Alternatively, the [UFS model](https://github.com/ufs-community/ufs-weather-model.git) does have a compile flag (S2S) and regression tests to set up a coupled FV3+MOM6+CICE6 run *globally*, but this setup does not yet include a regional configuration. However, within UFS there are regional HAFS regression tests (that do not include CICE6) which we can start working from.
### Current Plan:
* With UFS, set up a simple static regional FV3+MOM6 test case using the default North Atlantic domain included in the HAFS regression test cases
* Set up a MOM6 mesh located over the Arctic ocean
* Following the workflow in HAFS, generate boundary conditions for the Arctic domain
* Modify the simple test case from (1) to run with the Arctic domain
* Adjust the configuration to include CICE6

## Guides
### Running Test Cases (on Hera)
These are existing run directories.
1. Recursively copy all files from the directory on Hera to your working directory
* Regional Static Atm + MOM6 (HAFS Atlantic grid):
`/scratch2/BMC/gsienkf/Kristin.Barton/files/ufs_arctic_development/test_cases/regional_static_test/`
* Arctic MOM6 Mesh Test:
`/scratch2/BMC/gsienkf/Kristin.Barton/files/ufs_arctic_development/test_cases/mom6_arctic_mesh_test/`
* Arctic ATM and Arctic MOM6 Test:
`/scratch2/BMC/gsienkf/Kristin.Barton/files/ufs_arctic_development/test_cases/arctic_ocn_atm_test`
2. From your working directory, edit `job_card` to specify account, QOS, and job name as needed.
3. Run the code:
`sbatch job_card`

### Generating MOM6 input files
If you have an existing run directory set up (e.g., see previous section), then this is the process for generating initial condition files for the run.
1. Go to the `ocn_prep` directory.
2. Copy necessary MOM6 grid files into the `fix/` directory (on Hera: `/scratch2/BMC/gsienkf/Kristin.Barton/files/ufs_arctic_development/ocn_prep/fix`)
3. Check `run_init.sh` has the environment variables set
4. Run: `./run_init.sh`
5. Copy all `.nc` output files from `intercom/` to the `INPUT/` inside your model run directory.
6. Replace `MOM_input` in your model run directory with the version in `intercom/`

#### Notes on directory files:
* `run_init.sh`
This script sets up environmental variables and is the main driver for generating 1) initial conditions from RTOFS, 2) lateral boundary conditions from RTOFS, and 3) data atmosphere input from GFS.
* `remap_ICs.sh`
This script is called by run_init.sh and calls the remapping scripts for all of the variables (SSH, temperature, salinity, and U-V velocity vector) to generate initial conditions on the MOM6 mesh. (Velocity components are placed on their respective edges).
* `remap_OBCs.sh`
This script is called by run_init.sh and calls the remapping script for each of the four boundaries. It also reformats the OBC outputs so that they can be read in by the MOM6 model.
* `rtofs_to_mom6.py`
This is the main remapping script containing the logic for remapping from RTOFS input data to MOM6 mesh. It is called by the `remap_*.sh` scripts.
* `modules/`
This directory contains modules for the remapping class used by `rtofs_to_mom6.py`
* `fix/` 
This directory contains the MOM6 mesh data.
* `intercom/`
This directory contains the files that need to be sent to the model run directory. The outputs from the remapping scripts are placed here.
* `inputs/`
This directory contains namelists and houses input files obtained while gathering the RTOFS and GFS input datasets for remapping.

### Generating ESMF mesh from MOM6 mask file
This is for generating the meshes necessary to run with MOM6 in UFS based on existing MOM6 grid files.
Note: Arctic MOM6 grid files can be found on Gaea: Arctic MOM6 files can also be found on Gaea at `/gpfs/f5/cefi/world-shared/ARC12_pub/GRID`.
1. Find the required files in `mom6_mesh_generation` (or on Hera: `/scratch2/BMC/gsienkf/Kristin.Barton/files/ufs_arctic_testing/mesh_generation/`)
2. Copy both files to the directory containing an ocean mask file.
* *Note*: This requires an `ocean_mask.nc` file containing longitude and latitude variables `x(ny,nx)` and `y(ny,nx)`, respectively. 
* If you have these variables but with different names, edit the `gen_scrip.ncl` file lines 42 and 48 to the correct variable names.
* If your mask file does not contain any center coordinates, you can add them from the ocean_hgrid.nc file by running the python script `add_center_coords.py`.
3. Edit `mesh_gen_job.sh` as needed, then run the code.
`sbatch mesh_gen_job.sh`

### Generating a MOM6 Mask File
1. Use [FRE-NCtools](https://github.com/NOAA-GFDL/FRE-NCtools.git) command:
`make_quick_mosaic --input_mosaic input_mosaic.nc [--mosaic_name mosaic_name] [--ocean_topog ocean_topog.nc] [--sea_level #] [--reproduce_siena] [--land_frac_file frac_file] [--land_frac_field frac_field]`
2. Make note of the sea level chosen in this step! 0 is the default if it is not specified. You will need to make sure this value is consistent with `MASKING_DEPTH` variable in `MOM_input`

### Generating new IC file from RTOFS input
1. Recursively copy all files from the directory on Hera to your working directory
`/scratch2/BMC/gsienkf/Kristin.Barton/files/ufs_arctic_development/input_files/ocn_ic/`
2. Required mesh and interpolation weight files are already in the directory for the current Arctic mesh. If you would like to generate new interpolation weights (e.g., for a different mesh), make sure to do the following:
* Replace `ocean_mask.nc`, `ocean_hgrid.nc`, and `ocean_vgrid.nc` files with those corresponding to your grid.
* If the `ocean_vgrid.nc` file only contains dz (layer thickness), you can run `fix_vgrid.py` to add coordinate/interface information to the file.
* The u and v velocities need to be interpolated onto appropriate edges. Create the necessary edge subgrids using `make_subgrids.py` (this will replace the existing `v_subgrid.nc` and `u_subgrid.nc` files)
3. Check `mom6_init.sh` and modify for any changes in file locations, accounts, etc. Interpolation weights should already exist between RTOFS and the current Arctic mesh. If you need to generate new weights, you can uncomment the relevant section.
4. Run `./mom6_init.sh`
5. Copy the output file (by default, this will be named mom6_init.nc) to your run’s `INPUT/` directory. Edit `MOM_input` in the run directory to contain the new IC file and variable names.

### Setting up new regional static atm+ocn test case
This explains how to set up a new test case from an existing regression test in the ufs-weather-model repository. If you just want to get it running quickly on Hera, use the run guide above.

1. Download UFS weather model
`git clone --recursive https://github.com/ufs-community/ufs-weather-model.git ufs-weather-model`
2. Go to the tests directory
`cd ufs-weather-model/tests`
3. Modify the rt.sh file so that the `dprefix` corresponding to your system (e.g., Hera) points to your local working directory (e.g., `dprefix="/scratch2/BMC/gsienkf/Kristin.Barton/stmp"`)
4. Copy `rt.conf` to `rt_test.conf` and delete all but the following lines:
```
COMPILE | hafs_mom6w | intel| -DAPP=HAFS-MOM6W -DREGIONAL_MOM6=ON -DCDEPS_INLINE=ON -DMOVING_NEST=ON -DCCPP_SUITES=FV3_HAFS_v1_gfdlmp_tedmf,FV3_HAFS_v1_gfdlmp_tedmf_nonsst,FV3_HAFS_v1_thompson,FV3_HAFS_v1_thompson_nonsst -D32BIT=ON | -jet noaacloud  s4 | fv3 |
RUN | hafs_regional_storm_following_1nest_atm_ocn_wav_mom6    | - jet s4  noaacloud            | baseline |
```
5. Change the compile line so that `-DMOVING_NEST=OFF`
6. Run the regression test:
`./rt.sh -l rt_test.conf -a [account] -k`
* (-a specifies the account (e.g., `gsienkf`) and `-k` specifies that it should keep the directory)
7. Once finished, go to the regression test run directory and remove output files:
`rm PET* logfile* err out`
8. Edit `input.nml`:
* Under `&fv_core_nml` edit:
```
layout = 9,10
ntiles = 1
```
* Delete `&fv_nest_nml` and `&fv_moving_nest_nml` sections
* Under `&gfs_physics_nml` edit:
`cplwav = .false.`
9. Edit `job_card`:
* `#SBATCH –nodes=9`
* `srun --label -n 360 ./fv3.exe`
10. Edit `model_configure`:
* `write_tasks_per_group:   60`
* Remove `<output_grid_02>` section
11. Edit `ufs.configure`:
Remove all references to wave model:
* `EARTH_component_list: MED ATM OCN`
* Delete `WAV_model = ww3` line
* Delete `wav_use_data_first_import = .true.` line
* Delete entire `# WAV #` section
* Delete all WAV-related steps in `# Run Sequence #`
* Fix `petlist_bounds` to:
```
MED_petlist_bounds:             0 119
ATM_petlist_bounds:             0 239
OCN_petlist_bounds:             240 359
```
12. (Optional) Remove references to tile 8 in `INPUT/grid_spec.nc` and `INPUT/C96_mosaic.nc`
* *Note*: This step may not be necessary 
* For `grid_spec.nc`, run:
```
ncks -d ntiles,0,0 grid_spec.nc grid_spec.nc
ncks -x -v contact_index,contacts grid_spec.nc grid_spec.nc
```
* For `C96_mosaic.nc`, run:
```
ncks -d ntiles,0,0 C96_mosaic.nc C96_mosaic.nc
ncks -x -v contact_index,contacts C96_mosaic.nc C96_mosaic.nc
```
13. Run `sbatch job_card` and check if the output files show a successfully completed run.

## Notes on Running with CICE6
Currently, there is no testcase using CICE6. Below are some points to consider when setting up CICE6:
* Grid files for CICE6 must be generated based on the MOM6 ocean grid being used (see below)
* Existing forecast datasets may be in CICE4 which will need to be converted to CICE6
* The initial conditions contain many variables, and care will need to be taken to remap correctly while maintaining the correct classifications of different cells. 

### Generating CICE6 grid files
The following grid files are needed to run CICE6:
* `grid_cice_NEMS_mx{res}.nc`
* `kmtu_cice_NEMS_mx{res}.nc`

See generated files for the existing MOM6 Arctic test case on Hera here: `/scratch2/BMC/gsienkf/Kristin.Barton/files/ufs_arctic_development/cice6_grid_gen/grid_files/`

These must be generated based on the MOM6 mesh and can be done with the [UFS_Utils](https://github.com/ufs-community/UFS_UTILS) `cpld_gridgen` utility.

This requires the following files:
* `grid.nml` namelist file (see example on Here here: `/scratch2/BMC/gsienkf/Kristin.Barton/files/ufs_arctic_development    /cice6_grid_gen/grid.nml`)
* `ocean_hgrid.nc` MOM6 supergrid file
* `ocean_topog.nc` MOM6 bathymetry file
* `ocean_mask.nc` MOM6 landmask file
* `topo_edit.nc` The program may attempt to read in a topographic edit file even if it is not used (example of an empty topo edit file can be found here: `/scratch2/BMC/gsienkf/Kristin.Barton/files/mesh_files/ARC12/GRID/empty_topo_edit.nc`)
* FV3 input files (mesh, mosaic, etc)

Running `cpld_gridgen` will generate the first of the two grid files. The second can be generated from the first using the command `ncks -O -v kmt grid_cice_NEMS_mx{res}.nc kmtu_cice_NEMS_mx{res}.nc` (for whichever resolution, `{res}`, was specified in the namelist file.)
