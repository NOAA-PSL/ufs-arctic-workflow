import os
import numpy as np
from netCDF4 import Dataset

##########################
### File I/O Utilities ###
##########################

def read_variable_from_file(fname, vname):
    """ Read a specified variable from a NetCDF file.

    Parameters:
        fname (str): Path to the NetCDF file from which the variable will be read.
        vname (str): The name of the variable to be read from the file.

    Returns:
        netCDF4.Variable: Variable object from the NetCDF file. This allows deferred loading of data.
    """
    ds = Dataset(fname, 'r')

    if vname not in ds.variables:
        raise KeyError(f"Variable '{vname}' not found in file '{fname}'.")
    else:
        return ds[vname]

def check_file_dimensions(ofile, dname, dim_data, append=False):
    """
    Checks the dimensions of a specific file and verifies its dimension matches the expected data.

    Parameters:
        ofile (str): Path to the output NetCDF file to check.
        dname (str): The name of the dimension to check in the NetCDF file.
        dim_data (ndarray): Array representing the expected data for the specified dimension.
                               This is used to verify the dimension length.

    Returns:
        bool: Returns `True` if the dimension exists and its length matches the expected length.
              Returns `False` if the file doesn't exist or the dimension does not match the expected length.
    """
    if os.path.exists(ofile):
        with Dataset(ofile, 'r') as ds:
            if dname in ds.dimensions:
                dlen = len(ds.dimensions[dname])
                if dlen != len(dim_data):
                    raise ValueError(f"Dimension mismatch in file '{ofile}': "
                                     f"{dname} length {dlen} vs expected {len(dim_data)}.")
            elif not append:
                raise ValueError(f"'{ofile}' already exists but is missing {dname} dimension.")

    else:
        return False
    
    return True

def initialize_file(dz, dz_name_out, times, time_name_out, out_file):
    """ Initialize the output file with layer depth and time data

    Parameters:
        dz (netCDF4.variable): Depth data for initializing the vertical dimension.
        dz_name_out (str): The name of the depth dimension to use in the output file.
        times (netCDF4.variable): Time data for initializing the time dimension.
        time_name_out (str): The name of the time dimension to use in the output file.
        out_file (str): Path to the output NetCDF file to initialize.
    """
    dz = np.asarray(dz[:], dtype=float)

    # Check if the output file exists and has the correct depth dimension
    file_exists = check_file_dimensions(out_file, dz_name_out, dz)

    if not file_exists:
        # If the file doesn't exist, initialize it
        with Dataset(out_file, 'w', format='NETCDF4') as new_ds:
            # Add depth dimension
            new_ds.createDimension(dz_name_out, len(dz))
            new_ds.createDimension(time_name_out, None)

            # Add depth data
            depth_var = new_ds.createVariable(dz_name_out, 'f4', (dz_name_out), fill_value=1.e+20)
            time_var = new_ds.createVariable(time_name_out, 'f4', (time_name_out))

            depth_var[:] = dz
#            time_var[:] = 737678.5 # times[:]
            time_var[:] = times[:]
            if hasattr(times, 'long_name'):
                time_var.long_name = times.long_name
            else:
                time_var.long_name = "Time"
            if hasattr(times, 'units') and (times.units != "days"):
                time_var.units = times.units
            else:
                time_var.units = "days since 0001-01-01 00:00:00"
            if hasattr(times, 'calendar'):
                time_var.calendar = times.calendar
            else:
                time_var.calendar = "julian"
    else:
        print(f"(Output file {out_file} already exists.)")
        print(f"(Assuming dimensions are correct -- skipping dimension creation.)")


##########################
###   Interpolation    ###
##########################

def interpolate_vertical(v_s, z_s, z_d):

    """ Performs piecewise linear interpolation of vertical levels using numpy.interp()

    Parameters:
        z_s(k_s)     (netCDF4.variable): Source vertical levels
        z_d(k_d)     (netCDF4.variable): Destination vertical levels
        v_s(i,j,k_s) (netCDF4.variable): Source vertical data to interpolate

    Returns:
        v_d(i,j,k_d) (netCDF4.variable): Destination vertical interpolated data
    """
    ni, nj, _ = np.shape(v_s)
    nk_s = np.size(z_s)
    nk_d = np.size(z_d)

    v_d = np.zeros([ni, nj, nk_d])

    # Perform standard numpy interpolation, column by column
    for i in range(ni):
        for j in range(nj):
            # `left`:  Value to return for x < xp[0], default is fp[0] (Above surface)
            # `right`: Value to return for x > xp[-1], default is fp[-1] (Below bathymetry)
            v_d[i,j,:] = np.interp(z_d, z_s, v_s[i,j,:], right=0)

    np.interp()

    return v_d
