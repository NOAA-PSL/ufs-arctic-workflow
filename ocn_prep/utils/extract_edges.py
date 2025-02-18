import xarray as xr
import numpy as np

# Open the original NetCDF file
input_file = "ocean_hgrid.nc"
ds = xr.open_dataset(input_file)

# Extract edges
edge_001 = ds.isel(nyp=[-1])  # 
edge_002 = ds.isel(nyp=[0]) # Bottom edge
edge_003 = ds.isel(nxp=[-1])  # Left edge
edge_004 = ds.isel(nxp=[0]) # Right edge

# Save edges to separate files
edge_001.to_netcdf("ocean_hgrid_001.nc")
edge_002.to_netcdf("ocean_hgrid_002.nc")
edge_003.to_netcdf("ocean_hgrid_003.nc")
edge_004.to_netcdf("ocean_hgrid_004.nc")

print("Edge files created successfully.")
