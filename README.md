UFS Arctic Workflow
===================
The UFS-Arctic project aims to set up a regional coupled atmosphere-ocean-sea-ice Arctic forecasting configuration in the UFS framework. 

The UFS-Arctic requires the following pieces:
* UFS coupled regional configuration with FV3, MOM6, and CICE6
* A regional Arctic mesh and other required input files
* Workflow for generating boundary conditions for the regional domain 

[HAFS (Hurricane Analysis and Forecast System)](https://github.com/hafs-community/HAFS.git), which uses the UFS framework, already contains some of the pieces we need for setting up regional configurations and boundary conditions. However, it does not come with any Arctic meshes, nor does it run with CICE6. It also includes some extra capabilities that we do not need (such as storm-following nests)

Alternatively, the [UFS model](https://github.com/ufs-community/ufs-weather-model.git) does have a compile flag (S2S) and regression tests to set up a coupled FV3+MOM6+CICE6 run *globally*, but this setup does not yet include a regional configuration. However, within UFS there are regional HAFS regression tests (that do not include CICE6) which we can start working from.

**Current Plan:**
* With UFS, set up a simple static regional FV3+MOM6 test case using the default North Atlantic domain included in the HAFS regression test cases
* Set up a MOM6 mesh located over the Arctic ocean
* Following the workflow in HAFS, generate boundary conditions for the Arctic domain
* Modify the simple test case from to run with the Arctic domain
* Adjust the configuration to include CICE6

Table of Contents
=================
- [Guides](#guides)
  - [Accessing Existing Test Cases (Hera)](#accessing-existing-test-cases-hera)
  - [Setting up initial working ATM OCN ICE configuration](#setting-up-initial-working-atm-ocn-ice-configuration)
  - [Generating all Initial and Boundary Inputs](#generating-all-initial-and-boundary-inputs)
  - [Generating MOM6 Initial and Boundary Inputs](#generating-mom6-initial-and-boundary-inputs)
  - [Generating FV3 Initial and Boundary Inputs](#generating-fv3-initial-and-boundary-inputs)
  - [Generating ESMF mesh from MOM6 mask file](#generating-esmf-mesh-from-mom6-mask-file)
  - [Generating a MOM6 Mask File](#generating-a-mom6-mask-file)
  - [Generating new Initial Condition file from RTOFS input](#generating-new-initial-condition-file-from-rtofs-input)
  - [Setting up new regional static atm+ocn test case based on HAFS](#setting-up-new-regional-static-atmocn-test-case-based-on-hafs)
- [Notes on Running with CICE6](#notes-on-running-with-cice6)
  - [Generating CICE6 grid files](#generating-cice6-grid-files)

Guides
======

Accessing Existing Test Cases (Hera)
------------------------------------
These are existing run directories containing all inputs needed to run the corresponding test case. Each one can be run independently of the others.
1. Recursively copy all files from the directory on Hera to your working directory.
* Regional Static FV3 + MOM6 (Uses HAFS North Atlantic grid for both ocean and atmosphere):
`/scratch2/BMC/gsienkf/Kristin.Barton/files/ufs_arctic_development/test_cases/regional_static_test/`
* Arctic MOM6 Mesh Test (Arctic ocean grid with HAFS North American atmosphere grid):
`/scratch2/BMC/gsienkf/Kristin.Barton/files/ufs_arctic_development/test_cases/mom6_arctic_mesh_test/`
* Arctic FV3 and Arctic MOM6 Test (Both atmosphere and ocean are over the Arctic):
`/scratch2/BMC/gsienkf/Kristin.Barton/files/ufs_arctic_development/test_cases/arctic_ocn_atm_test`
* Global FV3 and Arctic MOM6+CICE6 (using `ufs.nfrac.aoflux` coupling):
`/scratch2/BMC/gsienkf/Kristin.Barton/files/ufs_arctic_development/test_cases/global_atm_aoflux_with_cice`
* Regional Arctic FV3+MOM6+CICE6 (using default ice initial conditions):
`/scratch2/BMC/gsienkf/Kristin.Barton/files/ufs_arctic_development/test_cases/regional_fv3_mom6_cice6`
* Regional Arctic FV3+MOM6+CICE6 (with ice initial conditions from file):
`/scratch2/BMC/gsienkf/Kristin.Barton/files/ufs_arctic_development/test_cases/regional_arctic_with_ice_ics`
2. From your working directory, edit `job_card` to specify account, QOS, and job name as needed.
3. Run `sbatch job_card`

Setting up initial working ATM OCN ICE configuration
----------------------------------------------------
The ATM+OCN+ICE configuration is currently a work in progress. It runs with global FV3 and regional Arctic MOM6+CICE6. Refer to `/scratch2/BMC/gsienkf/Kristin.Barton/files/ufs_arctic_development/test_cases/regional_fv3_mom6_cice6` on Hera for a working copy of the setup.

Starting from the ATM+OCN only test case, the following changes are necessary:
1) Add regional Arctic atmosphere input files to `INPUT` and adjust the `input.nml`
  * Change values for `npx`,`npy`,`ntiles` as needed
2) Obtain CICE6 input files from MOM6. Working copies for the current test grid can be found in the test case directory on Hera (`/scratch2/BMC/gsienkf/Kristin.Barton/files/ufs_arctic_development/test_cases/global_atm_aoflux_with_cice`). The necessary files are:
  * `grid_cice_NEMS_mxarctic.nc`
  * `kmtu_cice_NEMS_mxarctic.nc`
  * `ice_in`
3) Make the following changes to the `ufs.configure` file:
  * Change `coupling_mode` to `ufs.arctic`
  * Change `omp_num_threads` to 1 for all components.
  * Add the ICE component.
```
# ICE #
ICE_model:                      cice6
ICE_petlist_bounds:             360 399
ICE_omp_num_threads:            1
ICE_attributes::
  ProfileMemory = false
  mesh_ice = INPUT/mom6_arctic_mesh.nc
  eps_imesh = 2.5e-1
  stop_n = 12
  stop_option = nhours
  stop_ymd = -999
```
  * Adjust the run sequence.
```
runSeq::
@360
  MED med_phases_prep_ocn_avg
  MED -> OCN :remapMethod=redist
  OCN
  @180
    MED med_phases_prep_atm
    MED med_phases_prep_ice
    MED -> ATM :remapMethod=redist
    MED -> ICE :remapMethod=redist
    ATM
    ICE
    ATM -> MED :remapMethod=redist
    MED med_phases_post_atm
    ICE -> MED :remapMethod=redist
    MED med_phases_post_ice
    MED med_phases_ocnalb_run
    MED med_phases_prep_ocn_accum
  @
  OCN -> MED :remapMethod=redist
  MED med_phases_post_ocn
  MED med_phases_restart_write
  MED med_phases_history_write
@
::
```
4) Make sure the `ice_in` file contains the following (this file can be found from any regression test with CICE):
  * Adjust start date, time step, etc.
  * Under `&setup_nml`, set to use default ice instead of restart:
  ```
  ice_ic              = 'default'
  restart             = .false.
  restart_ext         = .false.
  use_restart_time    = .false.
  ```
  * Under `&grid_nml` set `grid_type=regional`
  * Under `&domain_nml` make sure `nprocs`, `nx_global`, `ny_global`, `block_size_x`, and `block_size_y` are compatible with grid and processor numbers. For the global ATM + Arctic OCN/ICE run, the following values are used:
  ```
  nprocs            = 40
  nx_global         = 540
  ny_global         = 696
  block_size_x      = 108
  block_size_y      = 87
  processor_shape   = 'square-ice'
  ew_boundary_type  = 'open'
  ns_boundary_type  = 'open'
  ```
5) Fix `input.nml` layout to `layout = 6,5`
6) In `model_configure`, set `write_tasks_per_group: 60`
7) In `MOM_input` increase the SSS limit to `BAD_VAL_SSS_MAX = 100.0`
8) Adjust `job_card` to have the correct number of processes, etc.
9) Use the UFS Weather Model fork here to access the Arctic coupling mode: https://github.com/kristinbarton/ufs-weather-model

Further discussion on setup can be found in the section on CICE below.

Generating FV3/MOM6 Initial and Boundary Inputs
-----------------------------------------------
This will create both ocean and atmosphere inputs that can be placed into an existing run directory (e.g., see [Accessing Existing Test Cases (Hera)](#accessing-existing-test-cases-hera))
1. First, go the the `run` directory and edit `run_all_prep.sh` so that it points to the desired config directory found in `config_files` (or setup your own `config.in`).
2. Run `./run_all_prep` from `run` directory.
3. Output and configure files will be placed in a top-level directory called `intercom`. Place all `*.nc` files into `INPUT` in your run directory and place `MOM_input` into top level of run directory.
4. Running `./clean.sh` will reset the directory and delete all generated files.

Generating only MOM6 Initial and Boundary Inputs
------------------------------------------------
This will create only the ocean inputs that can be placed into an existing run directory (e.g., see [Accessing Existing Test Cases (Hera)](#accessing-existing-test-cases-hera))
1. Go to the `ocn_prep` directory.
2. Copy necessary MOM6 grid files into the `fix/` directory (on Hera: `/scratch2/BMC/gsienkf/Kristin.Barton/files/ufs_arctic_development/ocn_prep/fix`).
3. Check `run_init.sh` has the environment variables set.
4. Run: `./run_init.sh`.
5. Copy all `.nc` output files from `intercom/` to the `INPUT/` inside your model run directory.
6. Replace `MOM_input` in your model run directory with the version in `intercom/`.

Generating only FV3 Initial and Boundary Inputs
------------------------------------------
This will create only the atmosphere inputs that can be placed into an existing run directory (e.g., see [Accessing Existing Test Cases (Hera)](#accessing-existing-test-cases-hera))
1. Go to the `atm_prep` directory.
2. Check `config.in` file for any necessary changes to file locations or other variables.
3. Run `./run_atm_prep.sh`.
4. Copy all netcdf files from `intercom/chgres` into your model run `INPUT` directory.

Generating ESMF mesh from MOM6 mask file
----------------------------------------
This is for generating the meshes necessary to run with MOM6 in UFS based on existing MOM6 grid files. These have already been generated for the Arctic MOM6 mesh used in [Accessing Existing Test Cases (Hera)](#accessing-existing-test-cases-hera). 
1. Find the required files in `mom6_mesh_generation` (or on Hera: `/scratch2/BMC/gsienkf/Kristin.Barton/files/ufs_arctic_testing/mesh_generation/`)
2. Copy both files to the directory containing an ocean mask file.
* *Note*: This requires an `ocean_mask.nc` file containing longitude and latitude variables `x(ny,nx)` and `y(ny,nx)`, respectively. 
* If you have these variables but with different names, edit the `gen_scrip.ncl` file lines 42 and 48 to the correct variable names.
* If your mask file does not contain any center coordinates, you can add them from the `ocean_hgrid.nc` file by running the python script `add_center_coords.py`.
3. Edit `mesh_gen_job.sh` as needed, then run the code.
`sbatch mesh_gen_job.sh`

Generating a MOM6 Mask File
---------------------------
This can be used if you do not have a MOM6 mesh or need to generate a new mesh with different parameters. A MOM6 mask file has already been generated for the Arctic MOM6 mesh used in [Accessing Existing Test Cases (Hera)](#accessing-existing-test-cases-hera). 
1. Use [FRE-NCtools](https://github.com/NOAA-GFDL/FRE-NCtools.git) command:
`make_quick_mosaic --input_mosaic input_mosaic.nc [--mosaic_name mosaic_name] [--ocean_topog ocean_topog.nc] [--sea_level #] [--reproduce_siena] [--land_frac_file frac_file] [--land_frac_field frac_field]`
2. Make note of the sea level chosen in this step! 0 is the default if it is not specified. You will need to make sure this value is consistent with `MASKING_DEPTH` variable in `MOM_input`

Generating new Initial Condition file from RTOFS input
------------------------------------------------------
This is automatically done as part of the [Generating MOM6 Initial and Boundary Inputs](#generating-mom6-initial-and-boundary-inputs) scripts.
1. Recursively copy all files from the directory on Hera to your working directory
`/scratch2/BMC/gsienkf/Kristin.Barton/files/ufs_arctic_development/input_files/ocn_ic/`
2. Required mesh and interpolation weight files are already in the directory for the current Arctic mesh. If you would like to generate new interpolation weights (e.g., for a different mesh), make sure to do the following:
* Replace `ocean_mask.nc`, `ocean_hgrid.nc`, and `ocean_vgrid.nc` files with those corresponding to your grid.
* If the `ocean_vgrid.nc` file only contains dz (layer thickness), you can run `fix_vgrid.py` to add coordinate/interface information to the file.
* The u and v velocities need to be interpolated onto appropriate edges. Create the necessary edge subgrids using `make_subgrids.py` (this will replace the existing `v_subgrid.nc` and `u_subgrid.nc` files)
3. Check `mom6_init.sh` and modify for any changes in file locations, accounts, etc. Interpolation weights should already exist between RTOFS and the current Arctic mesh. If you need to generate new weights, you can uncomment the relevant section.
4. Run `./mom6_init.sh`
5. Copy the output file (by default, this will be named mom6_init.nc) to your run’s `INPUT/` directory. Edit `MOM_input` in the run directory to contain the new IC file and variable names.

Setting up new regional static atm+ocn test case based on HAFS
--------------------------------------------------------------
This explains how to set up a brand new test case from an existing regression test in the ufs-weather-model repository.

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
* `#SBATCH --nodes=9`
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

Notes on Running with CICE6
===========================
Currently, the CICE6 test configuration is still a work in progress. Some of the considerations made when setting up the working test case:
* To avoid using the aoflux coupling in runs, the atmosphere needs to fully cover the ocn/ice grid
* The atmosphere->ocn/ice mapping leads to failure unless mapping types in ufs coupling are switched to `mapbilnr_nstod`. [This fork of the UFS Weather Model](https://github.com/kristinbarton/ufs-weather-model) has a `ufs.arctic` coupling mode which accomplishes this.
* There seem to be momentarily large salinity values in MOM6 at the start of the run, which is why the SSS limit is adjusted upwards. The large values do not show up in the final output.
* Running CICE6 with `omp_num_threads=2` lead to a floating point exception in the `ice_import_export.F90` routine. It seems that threading is not fully supported in CICE6, so this must be set to 1 to work correctly.
* Take care when generating ice initial conditions files, as if there is ice concentration over a masked land cell it will lead to a floating point exception in the CICE6 model.

See [this UFS Github Discussion](https://github.com/ufs-community/ufs-weather-model/discussions/2657) for more information on some of the errors encountered in setting up the configuration.

Generating CICE6 grid files
---------------------------
**This may result in a file with all `NaN`s for the mask. If that happens, copy the mask from the ocean files into the ice files.**

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
