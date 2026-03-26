UFS Arctic Workflow
===================
The UFS-Arctic project aims to set up a regional coupled atmosphere-ocean-sea-ice Arctic forecasting configuration in the UFS framework. 

Quick Start Guide
=================

Ursa 
----
1. Clone the workflow and then update submodules: `git submodule update --init --recursive`
2. Open `submit_build.sh` and adjust the test run start date, run length, account, system, compiler, and run directory as needed.
3. Run the workflow: 
  - `sbatch submit_build.sh`
  - `sbatch submit_build.sh --norun` to setup the run directoy without submitting the job.

**Notes**:
- There are currently a limited number of available dates:
    - 2019/10/28
    - 2020/02/27
    - 2020/07/02
    - 2020/07/09
    - 2020/08/27
- The model can be run from 3 hrs to a maximum of 240 hrs.
- Atmosphere resolution options are C918 (~10km) or C185 (~50km)

Table of Contents
=================
- [More Guides](#more-guides)
  - [Generating ESMF mesh from MOM6 mask file](#generating-esmf-mesh-from-mom6-mask-file)
  - [Generating a MOM6 Mask File](#generating-a-mom6-mask-file)
- [Notes on Running with CICE6](#notes-on-running-with-cice6)
  - [Generating CICE6 grid files](#generating-cice6-grid-files)

More Guides
===========

Generating ESMF mesh from MOM6 mask file
----------------------------------------
This is for generating the meshes necessary to run with MOM6 in UFS based on existing MOM6 grid files. These have already been generated for the Arctic MOM6 mesh used in [Accessing Existing Test Cases (Ursa)](#accessing-existing-test-cases-ursa). 
1. Find the required files in `workflow/mesh` 
2. Copy both files to the directory containing an ocean mask file.
* *Note*: This requires an `ocean_mask.nc` file containing longitude and latitude variables `x(ny,nx)` and `y(ny,nx)`, respectively. 
* If you have these variables but with different names, edit the `gen_scrip.ncl` file lines 42 and 48 to the correct variable names.
* If your mask file does not contain any center coordinates, you can add them from the `ocean_hgrid.nc` file by running the python script `add_center_coords.py`.
3. Edit `mesh_gen_job.sh` as needed, then run the code.
`sbatch mesh_gen_job.sh`

Generating a MOM6 Mask File
---------------------------
This can be used if you do not have a MOM6 mesh or need to generate a new mesh with different parameters. A MOM6 mask file has already been generated for the Arctic MOM6 mesh used in [Accessing Existing Test Cases (Ursa)](#accessing-existing-test-cases-ursa). 
1. Use [FRE-NCtools](https://github.com/NOAA-GFDL/FRE-NCtools.git) command:
`make_quick_mosaic --input_mosaic input_mosaic.nc [--mosaic_name mosaic_name] [--ocean_topog ocean_topog.nc] [--sea_level #] [--reproduce_siena] [--land_frac_file frac_file] [--land_frac_field frac_field]`
2. Make note of the sea level chosen in this step! 0 is the default if it is not specified. You will need to make sure this value is consistent with `MASKING_DEPTH` variable in `MOM_input`

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

See generated files for the existing MOM6 Arctic test case on Ursa here: `/scratch4/BMC/ufs-artic/Kristin.Barton/files/ufs_arctic_development/cice6_grid_gen/grid_files/`

These must be generated based on the MOM6 mesh and can be done with the [UFS_Utils](https://github.com/ufs-community/UFS_UTILS) `cpld_gridgen` utility.

This requires the following files:
* `grid.nml` namelist file (see example on Here here: `/scratch4/BMC/ufs-artic/Kristin.Barton/files/ufs_arctic_development    /cice6_grid_gen/grid.nml`)
* `ocean_hgrid.nc` MOM6 supergrid file
* `ocean_topog.nc` MOM6 bathymetry file
* `ocean_mask.nc` MOM6 landmask file
* `topo_edit.nc` The program may attempt to read in a topographic edit file even if it is not used (example of an empty topo edit file can be found here: `/scratch4/BMC/ufs-artic/Kristin.Barton/files/mesh_files/ARC12/GRID/empty_topo_edit.nc`)
* FV3 input files (mesh, mosaic, etc)

Running `cpld_gridgen` will generate the first of the two grid files. The second can be generated from the first using the command `ncks -O -v kmt grid_cice_NEMS_mx{res}.nc kmtu_cice_NEMS_mx{res}.nc` (for whichever resolution, `{res}`, was specified in the namelist file.)
