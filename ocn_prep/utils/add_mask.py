import xarray as xr
import numpy as np

def main():
    scrip = xr.open_dataset("Ct.mx025_SCRIP.nc")
    mask  = xr.open_dataset("mx025.ocean_mask.nc")

    ny, nx = mask['mask'].shape
    print(ny,nx)

    mask1d = mask['mask'].values[:].flatten()
    print(mask1d.shape)

    scrip['grid_imask'].values[:] = mask1d[:]

    scrip.to_netcdf("Ct.mx025_SCRIP_masked.nc")

if __name__=="__main__":
    main()
