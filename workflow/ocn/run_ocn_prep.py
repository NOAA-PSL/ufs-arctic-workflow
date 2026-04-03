"""
Script Name: run_ocn_prep.py
Authors: Kristin Barton (kristin.barton@noaa.gov) and UFS Arctic Team
Last Modified: 1 December 2025
Description:
    This code performs the interoplation data from RTOFS input netCDF file
    onto a MOM6 staggered grid using input ESMF Regridding weight files.
"""

import os
import argparse
import numpy as np
import netCDF4 as nc
from netCDF4 import Dataset

from modules import Remapper 
from modules import utilities 

def main(args):
#    print(f"... Reading arguments ...")

    wgt_file = args.wgt_file
    vrt_file = args.vrt_file
    src_file = args.src_file
    dst_file = args.dst_file
    out_file = args.out_file

    # Get variable / vector information
    var_name = args.var_name
    time_name = args.time_name
    dz_name = args.dz_name

    # Default to input names if not specified
    tme_file = args.tme_file or src_file[0]
    var_name_out = args.var_name_out or var_name
    dz_name_out = args.dz_name_out or dz_name
    time_name_out = args.time_name_out or time_name

    # Optional -- Calculate thickness (eta) and add to output file
    add_eta = args.add_eta or False

    # Optional -- Default to 0th time step if not specified
    forecast_iter = args.forecast_iter or 0
    
    # Optional -- Only required if input is a vector and grid is not NE-aligned
    src_ang_name = args.src_ang_name or None
    src_ang_file = args.src_ang_file or None
    src_ang_supergrid = args.src_ang_supergrid or False
    dst_ang_name = args.dst_ang_name or None
    dst_ang_file = args.dst_ang_file or None
    dst_ang_supergrid = args.dst_ang_supergrid or False

    # Initialize output file with vertical layer and time information
#    print(f"... Initializing output file ...")
    dz = utilities.read_variable_from_file(vrt_file, dz_name)
    times = utilities.read_variable_from_file(tme_file, time_name)
    utilities.initialize_file(dz, dz_name_out, times, time_name_out, out_file)

    # Gather datasets
    variables = [
        utilities.read_variable_from_file(src_file, var_name)
        for src_file, var_name in zip(args.src_file, args.var_name)
    ]

    # Get angles if applicable
    if src_ang_file is not None and src_ang_name is not None:
        src_angle = utilities.read_variable_from_file(src_ang_file, src_ang_name)
    else:
        src_angle = None
    if dst_ang_file is not None and dst_ang_name is not None:
        dst_angle = utilities.read_variable_from_file(dst_ang_file, dst_ang_name)
    else:
        dst_angle = None

    # Perform horizontal interpolation
#    print(f"... Interpolating ...")
    var_remapper = Remapper(*variables, depth_name = 'Layer', src_angle=src_angle, dst_angle=dst_angle, 
                            src_ang_hgrid=src_ang_supergrid, dst_ang_hgrid=dst_ang_supergrid)
    var_remapper.remap_from_file(*wgt_file)

    # Append to file
#    print(f"... Writing to output file ...")
    var_remapper.write_to_file(out_file, dz_name_out, time_name_out, forecast_iter, *var_name_out)

#    print("Complete!")


if __name__=="__main__":
    parser = argparse.ArgumentParser(description="Convert RTOFS to MOM6 Initial Conditions")

    # Required Arguments
    parser.add_argument("--var_name", 
                        nargs='+',
                        required=True, 
                        help=f"Space-seperated list of variables. "
                             f"Scalar: only include one variable name (e.g., --var_name ssh). "
                             f"Vector: include u- and v- components (e.g., --var_name u v).")
    parser.add_argument("--wgt_file",
                        nargs='+',
                        required=True, 
                        help=f"Name of netCDF file containing RTOFS to MOM6 weights file from ESMF_RegridWeightGen. "
                             f"Can accept one or two arguments (for u- and v- vector compenents, respectively)."
                             f"(e.g., `--wgt_file u_grid.nc v_grid.nc`)")
    parser.add_argument("--vrt_file", 
                        required=True, 
                        help=f"Name of netCDF file containing vertical grid data")
    parser.add_argument("--tme_file", 
                        required=False, 
                        help=f"Name of netCDF file containing time data. "
                             f"Defauts to first `--src_file` input if not specified.")
    parser.add_argument("--src_file", 
                        nargs='+',
                        required=True, 
                        help=f"Name of netCDF file containing RTOFS data "
                             f"Entry required for each `--var_name` specified")
    parser.add_argument("--dst_file", 
                        nargs='+',
                        required=False,
                        help=f"Name of netCDF file containing destination grid point points "
                             f"To interpolate vectors onto edge points, input 2 files")
    parser.add_argument("--out_file", 
                        required=True, 
                        help=f"Name of output netCDF file")
    parser.add_argument("--dz_name", 
                        required=True,
                        help=f"Name of layer thickness (dz) variable in `vrt_file`")
    parser.add_argument("--time_name", 
                        required=True, 
                        help=f"Name of output time variable in `src_file`")

    # Optional Arguments
    parser.add_argument("--src_ang_name",
                        required=False,
                        help=f"Name of source grid angles"
                             f"e.g., --ang_name src_ang")
    parser.add_argument("--src_ang_file",
                        required=False,
                        help=f"Name of file containing source grid angles"
                             f"e.g., --ang_file src_file")
    parser.add_argument("--src_ang_supergrid",
                        required=False,
                        help=f"Specify as True if the source grid angle is specified on a "
                             f"supergrid and needs to be converted to center points.")
    parser.add_argument("--dst_ang_name",
                        required=False,
                        help=f"Name of destination grid angles"
                             f"e.g., --ang_name dst_ang")
    parser.add_argument("--dst_ang_file",
                        required=False,
                        help=f"Name of file containing destination grid angles"
                             f"e.g., --ang_file dst_file")
    parser.add_argument("--dst_ang_supergrid",
                        required=False,
                        help=f"Specify as True if the destination grid angle is specified on a "
                             f"supergrid and needs to be converted to center points.")
    parser.add_argument("--var_name_out", 
                        nargs='+',
                        required=False, 
                        help=f"Output variable name. Defaults to `var_name` if not specified.")
    parser.add_argument("--dz_name_out", 
                        required=False, 
                        help=f"Output layer thickness name. Defaults to `dz_name_out` if not specified.")
    parser.add_argument("--time_name_out", 
                        required=False, 
                        help=f"Output time dimension name. Defaults to `time_name` if not specified.")
    parser.add_argument("--forecast_iter",
                        required=False,
                        type=int,
                        help=f"Forecast iter, defaults to 0 (first time step). If > 0, appends data along time dimension.")
    parser.add_argument("--add_eta",
                        required=False,
                        type=bool,
                        help=f"Calculate thickness (eta) and add to output file")

    args = parser.parse_args()  

    main(args)
