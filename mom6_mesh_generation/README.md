This is for generating mesh needed to run UFS with MOM6 based on existing MOM6 Grid files.

To generate a mesh:

1. Copy all files to your working directory

2. Check your required files: 
    * This requires an ocean_mask.nc file containing longitude and latitude variables 
        x(ny,nx) and y(ny,nx), respectively. 
    * If you have these variables but with different names, edit the gen_scrip.ncl file 
        lines 42 and 48 to the correct variable names.
    * If your mask file does not contain any center coordinates, add them from the 
        ocean_hgrid.nc file by running the python script add_center_coords.py.

2. Edit mesh_gen_job.sh as needed, then run the code.
sbatch mesh_gen_job.sh
