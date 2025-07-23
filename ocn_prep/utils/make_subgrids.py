from netCDF4 import Dataset
import numpy as np
import argparse

def write_file(lats, lons, filename):
    with Dataset(filename, mode='w', format="NETCDF4") as dataset:
        ny, nx = lats.shape
        dataset.createDimension('ny', ny)
        dataset.createDimension('nx', nx)
    
        lat_var = dataset.createVariable('x', 'f8', ('ny', 'nx'))
        lat_var[:] = lats
        lat_var.standard_name = "latitude"
        lat_var.units = "degrees_north"

        lon_var = dataset.createVariable('y', 'f8', ('ny', 'nx'))
        lon_var[:] = lons
        lon_var.standard_name = "longitude"
        lon_var.units = "degrees_east"
    
def main(args):

    input_file=args.fin
    v_file = args.out+"_v.nc"
    u_file = args.out+"_u.nc"
    h_file = args.out+"_h.nc"

    dataset = Dataset(input_file, mode='r')
    
    lon = dataset.variables[args.lon][:]
    lat = dataset.variables[args.lat][:]

    h_lat = lat[1::2, 1::2]
    h_lon = lon[1::2, 1::2]
    
    v_lat = lat[2::2, 1::2]
    v_lon = lon[2::2, 1::2]
    
    u_lat = lat[1::2, 2::2]
    u_lon = lon[1::2, 2::2]
    
    write_file(v_lat, v_lon, v_file)
    write_file(u_lat, u_lon, u_file)
    write_file(h_lat, h_lon, h_file)

if __name__=="__main__":
    parser = argparse.ArgumentParser(description="Extract u/v subgrids from hgrid")
    parser.add_argument("--lat", help="Source grid latitude name")
    parser.add_argument("--lon", help="Source grid longitude name")
    parser.add_argument("--fin", help="Source grid file name")
    parser.add_argument("--out", help="Output grid base file name (e.g. rtofs2arctic)")

    args = parser.parse_args()
    main(args)
