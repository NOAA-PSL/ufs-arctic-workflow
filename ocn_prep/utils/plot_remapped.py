import os
import argparse
import numpy as np
import matplotlib.pyplot as plt
import cartopy.crs as ccrs
import cartopy.feature as cfeature
import netCDF4 as nc


def plot_variable_comparison(remapped_file, original_files, supergrid_file, var_names, output_dir):
    # Create output directory if it doesn't exist
    os.makedirs(output_dir, exist_ok=True)

    # Open remapped dataset
    remap_ds = nc.Dataset(remapped_file)

    # Get lat/lon from the supergrid file
    supergrid_ds = nc.Dataset(supergrid_file)

    # Loop through variable names
    for var_name in var_names:
        # Open the corresponding original dataset
        original_file = original_files[var_name]
        orig_ds = nc.Dataset(original_file)
        
        # Extract remapped variable
        remap_var = remap_ds.variables[var_name][:]
        if len(remap_var.shape) == 4:
            remap_var = remap_var[0, 0, :, :]  # 0th time and depth
        elif len(remap_var.shape) == 3:
            remap_var = remap_var[0, :, :]  # 0th time
        
        # Dynamically detect dimensions for the remapped variable
        dims = remap_ds.variables[var_name].dimensions
        print(dims)
        
        # Determine the correct coordinate variables based on the dimensions
        if 'yh' in dims and 'xh' in dims:
            remap_lat = supergrid_ds.variables['y'][1::2,1::2]
            remap_lon = supergrid_ds.variables['x'][1::2,1::2]
        elif 'yq' in dims and 'xh' in dims: # N-S Edges
            remap_lat = supergrid_ds.variables['y'][0::2,1::2]
            remap_lon = supergrid_ds.variables['x'][0::2,1::2]
        elif 'yh' in dims and 'xq' in dims: # E-W Edges
            remap_lat = supergrid_ds.variables['y'][1::2,0::2]
            remap_lon = supergrid_ds.variables['x'][1::2,0::2]
        elif 'yq' in dims and 'xq' in dims: # Corners
            remap_lat = supergrid_ds.variables['y'][0::2,0::2]
            remap_lon = supergrid_ds.variables['x'][0::2,0::2]
        else:
            raise ValueError(f"Unknown lon dimensions for variable {var_name}: {dims}")

        print(np.shape(var_name), np.shape(remap_lat), np.shape(remap_lon))

        # Extract original variable
        orig_var = orig_ds.variables[var_name][:]
        if len(orig_var.shape) == 4:
            orig_var = orig_var[0, 0, :, :]  # 0th time and depth
        elif len(orig_var.shape) == 3:
            orig_var = orig_var[0, :, :]  # 0th time

        # Get original lat/lon
        orig_lat = orig_ds.variables['Latitude'][:]
        orig_lon = orig_ds.variables['Longitude'][:]

        # Mask fill values
        remap_fill = remap_ds.variables[var_name]._FillValue
        orig_fill = orig_ds.variables[var_name]._FillValue
        remap_var = np.ma.masked_equal(remap_var, remap_fill)
        orig_var = np.ma.masked_equal(orig_var, orig_fill)

        vmin = min(np.nanmin(remap_var), np.nanmin(orig_var))/2.
        vmax = max(np.nanmax(remap_var), np.nanmax(orig_var))/2.

        # Create a figure
        fig, axes = plt.subplots(1, 2, figsize=(12, 6), subplot_kw={'projection': ccrs.NorthPolarStereo()})
        
        # Plot remapped data (Polar projection)
        ax = axes[0]
        plot = ax.pcolormesh(remap_lon, remap_lat, remap_var, transform=ccrs.PlateCarree(), cmap='viridis', vmin=vmin, vmax=vmax)
        ax.coastlines()
        ax.add_feature(cfeature.LAND, facecolor='gray')
        ax.gridlines()
        ax.set_extent([-180, 180, 60, 90], ccrs.PlateCarree())  # Arctic region
        ax.set_title(f"Interpolated {var_name}")
        plt.colorbar(plot, ax=ax, orientation='horizontal')
        ax.add_feature(cfeature.LAND, facecolor='gray')

        # Plot original data (Polar projection)
        ax = axes[1]
        plot = ax.pcolormesh(orig_lon, orig_lat, orig_var, transform=ccrs.PlateCarree(), cmap='viridis', vmin=vmin, vmax=vmax)
        ax.coastlines()
        ax.add_feature(cfeature.LAND, facecolor='gray')
        ax.gridlines()
        ax.set_extent([-180, 180, 60, 90], ccrs.PlateCarree())  # Arctic region
        ax.set_title(f"Original {var_name}")
        plt.colorbar(plot, ax=ax, orientation='horizontal')
        ax.add_feature(cfeature.LAND, facecolor='gray')

        # Save the plot
        output_path = os.path.join(output_dir, f"{var_name}_comparison.png")
        plt.savefig(output_path, dpi=300)
        plt.close()

        print(f"Saved: {output_path}")
        print(f" ===================== ")

    # Close datasets
    remap_ds.close()
    for orig_file in original_files.values():
        nc.Dataset(orig_file).close()


def main(args):
    # Check that the number of variables matches the number of files
    if len(args.var_names) != len(args.orig_files):
        raise ValueError("Number of variable names must match the number of original files.")

    # Map variable names to original files
    original_files = dict(zip(args.var_names, args.orig_files))

    # Generate plots
    plot_variable_comparison(args.remap_file, original_files, args.grid_file, args.var_names, args.output_dir)


if __name__ == "__main__":
    # Command-line argument parsing
    parser = argparse.ArgumentParser(description="Compare remapped and original datasets using Arctic polar projection.")
    parser.add_argument("--remap_file", required=True, help="Path to the remapped NetCDF file.")
    parser.add_argument("--output_dir", default="plots", help="Output directory for saving plots.")
    parser.add_argument("--var_names", nargs='+', required=True, help="List of variable names to compare.")
    parser.add_argument("--orig_files", nargs='+', required=True, help="List of original NetCDF files corresponding to the variables.")
    parser.add_argument("--grid_file", required=True, help="Path to the supergrid file.")
    
    args = parser.parse_args()

    main(args)

