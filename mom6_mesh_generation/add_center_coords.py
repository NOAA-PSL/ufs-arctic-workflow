import numpy as np
import xarray as xr

input_file = "ocean_hgrid.nc"
output_file = "ocean_mask.nc"

ds_in = xr.open_dataset(input_file)

lon_center=ds_in['x'][1::2, 1::2]
lat_center=ds_in['y'][1::2, 1::2]

lon_da = xr.DataArray(lon_center, dims=('ny','nx'))
lat_da = xr.DataArray(lat_center, dims=('ny','nx'))

ds_out = xr.open_dataset(output_file)

ds_out['x'] = lon_da
ds_out['y'] = lat_da

ds_out.to_netcdf(output_file, mode='a')
