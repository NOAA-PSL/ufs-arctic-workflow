#!/bin/sh
srun --mem=0 --ntasks=1 --nodes=1 --ntasks-per-node=1 --cpus-per-task=1 -A gsienkf ESMF_RegridWeightGen -s rtofs.f12_global_ssh_obc.nc -d ocean_hgrid_001.nc -w rtofs2hgrid_001.nc --dst_loc center --netCDF4 --dst_regional --ignore_degenerate
srun --mem=0 --ntasks=1 --nodes=1 --ntasks-per-node=1 --cpus-per-task=1 -A gsienkf ESMF_RegridWeightGen -s rtofs.f12_global_ssh_obc.nc -d ocean_hgrid_002.nc -w rtofs2hgrid_002.nc --dst_loc center --netCDF4 --dst_regional --ignore_degenerate
srun --mem=0 --ntasks=1 --nodes=1 --ntasks-per-node=1 --cpus-per-task=1 -A gsienkf ESMF_RegridWeightGen -s rtofs.f12_global_ssh_obc.nc -d ocean_hgrid_003.nc -w rtofs2hgrid_003.nc --dst_loc center --netCDF4 --dst_regional --ignore_degenerate
srun --mem=0 --ntasks=1 --nodes=1 --ntasks-per-node=1 --cpus-per-task=1 -A gsienkf ESMF_RegridWeightGen -s rtofs.f12_global_ssh_obc.nc -d ocean_hgrid_004.nc -w rtofs2hgrid_004.nc --dst_loc center --netCDF4 --dst_regional --ignore_degenerate
