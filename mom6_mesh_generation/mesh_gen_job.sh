#!/bin/bash
#SBATCH --job-name=mesh_gen
#SBATCH --output=mesh_gen.log
#SBATCH --ntasks=1
## Edit the account
#SBATCH --account=gsienkf
#SBATCH --time=05:00

set -e

module purge

# Required modules are NCL and ESMF
module use /scratch2/BMC/gsienkf/Kristin.Barton/ufs-weather-model/modulefiles/
module load ufs_hera.intel
module load ncl

# Uncomment to run script that adds center coordinates to an ocean_mask.nc file
# Requires an ocean_hgrid.nc input file.
# python add_center_coords.py

# Edit these file paths
MASKFILE="ocean_mask.nc"
OUTFILE="slurm_test.nc"

# NCL script reads input file name from a text file
echo "$MASKFILE" > mesh_gen_input_file.txt
ncl gen_scrip.ncl
rm -f mesh_gen_input_file.txt

# The 0 indicates that it is a straight conversion rather than a dual mesh
srun ESMF_Scrip2Unstruct ocean_mask.SCRIP.nc $OUTFILE 0
