import netCDF4 as nc
import sys
import os

def patch_layers(srcpath, dstpath, varnames):
    with nc.Dataset(srcpath, 'r') as src, nc.Dataset(dstpath, 'r+') as dst:
        for var in varnames:
            dst.variables[var][-7:, ...] = src.variables[var][-7, ...]

if __name__ == "__main__":
    workdir = sys.argv[1]
    atmtile = sys.argv[2]

    icsrc = os.path.join(workdir, "patch", f"out.atm.tile{atmtile}.nc")
    icdst = os.path.join(workdir, f"out.atm.tile{atmtile}.nc")
    patch_layers(icsrc, icdst, ["t"])

    bndysrc = os.path.join(workdir, "patch", "gfs.bndy.nc")
    bndydst = os.path.join(workdir, "gfs.bndy.nc")
    patch_layers(bndysrc, bndydst, ["t_top", "t_bottom", "t_left", "t_right"])
