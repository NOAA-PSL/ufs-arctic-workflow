import argparse
import xarray as xr
import numpy as np
from scipy.sparse import coo_matrix

def main(args):
    wgt_file = args.wgt_file
    src_file = args.src_file
    src_angl = args.src_angl
    msk_file = args.msk_file
    dst_angl = args.dst_angl
    out_file = args.out_file
    msk_name = args.msk_name

    #define some constants
    saltmax = 3.20
    nsal    = 0.407
    msal    = 0.573
    rhoi    = 917.0
    rhos    = 330.0
    cp_ice  = 2106.0
    cp_ocn  = 4218.0
    Lvap    = 2.501e6
    Lsub    = 2.835e6
    Lfresh  = 3.34e5
    puny    = 1.0e-3
    nilyr   = 7
    ncat    = 5

    # Compute salinity and melting temperature per layer
    salinz = np.zeros(nilyr, np.double)
    for l in range(nilyr):
        zn = (l + 1 - 0.5) / float(nilyr)
        salinz[l] = (saltmax / 2.0) * (1.0 - np.cos(np.pi * zn**(nsal / (msal + zn))))

    Tmltz = salinz / (-18.48 + (0.01848 * salinz))

    # --- Read Source Data ---
#    print(f"Reading source file: {src_file}")
    ds_in = xr.open_dataset(src_file)
    vars_to_drop = ['fsnow', 'iage', 'alvl', 'vlvl', 'apnd', 'hpnd', 'ipnd', 'dhs', 'ffrac']
    ds_in = ds_in.drop_vars([v for v in vars_to_drop if v in ds_in])

    # --- Rotate vectors (Source Grid -> North-South) ---
#    print("Rotating vectors to N-S...")
    ang_ds = xr.open_dataset(src_angl)
    angle = get_centers(ang_ds['angle_dx'])
    ds_in['uvel'][:], ds_in['vvel'][:] = rotate(ds_in['uvel'][:], ds_in['vvel'][:], angle, 'grid2NS')

    # --- Remap variables ---
#    print(f"Remapping data using weights: {wgt_file}")
    ds_out = remap(ds_in, wgt_file)

    # --- Rotate vectors (North-South -> Target Grid) ---
#    print("Rotating vectors to grid...") 
    ang_ds = xr.open_dataset(dst_angl)
    angle = get_centers(ang_ds['angle_dx'])
    ds_out['uvel'][:], ds_out['vvel'][:] = rotate(ds_out['uvel'][:], ds_out['vvel'][:], angle, 'NS2grid')

    # Zero out certain arrays
    for var in ['coszen', 'scale_factor', 'strocnxT', 'strocnyT']:
        if var in ds_out:
            ds_out[var][:] = 0
    
    # --- Recompute Enthalpies ---
#    print("Recomputing enthalpies...")

    # Snow  enthalpy
    ds_out['qsno001'][:] = -rhos * (Lfresh - cp_ice * ds_out['Tsfcn'][:].values)

    # Ice enthalpy:
    # First go through each layer
    for l in range(nilyr):
        var_name = f'qice{l+1:03d}'
        if var_name in ds_out:
            q_lyr = ds_out[var_name].values
            T_lyr = Tmltz[l]

            # Convert enthalpy to temperature (see eq 53: https://cice-consortium-icepack.readthedocs.io/en/icepack1.2.2/science_guide/sg_thermo.html#bitz-and-lipscomb-thermodynamics-ktherm-1)
            a = cp_ice
            b = ((cp_ocn - cp_ice) * T_lyr) - (q_lyr / rhoi) - Lfresh
            c = Lfresh * T_lyr
            d = np.maximum(b**2 - 4.0*a*c, 0)
            q2T = (-b - np.sqrt(d) ) / (2.0 * a)

            # Cap temperature to melting temp for each layer
            q2T_fix = np.where( q2T > T_lyr, T_lyr, q2T)

            # Convert temperature back to enthalpy
            ds_out[var_name][:] = -rhoi* ( cp_ice*(T_lyr-q2T_fix) + Lfresh*(1-(T_lyr/q2T_fix)) - cp_ocn*T_lyr )
    
    # --- Apply Land Mask & Ice Fractions ---
#    print("Applying masks...")
    ds_kmt = xr.open_dataset(msk_file)
    kmt = np.asarray(ds_kmt[msk_name].values, dtype=float)

    # Set aicen to zero over land and zero out small ice fractions
    ds_out['aicen'] = xr.where(kmt == 1, ds_out['aicen'], 0)
    ds_out['aicen'] = xr.where(ds_out['aicen'] > 0.01, ds_out['aicen'], 0)

    vars_to_zero = ['vicen', 'vsnon'] + [f'qice{l+1:03d}' for l in range(nilyr)]
    for var in vars_to_zero:
        if var in ds_out:
            ds_out[var] = xr.where(ds_out['aicen'] > 0, ds_out[var], 0)

    # --- Correct Snow Temperature (using Icepack formulas) ---
#    print("Correcting snow temperatures...")
    puny_temp = 1.0E-012
    rnslyr = 1.0
    c1 = 1.0

    A = c1 / (rhos * cp_ice)
    B = Lfresh / cp_ice

    qsno = ds_out['qsno001'][:].values
    vsnon = ds_out['vsnon'][:].values
    aicen = ds_out['aicen'][:].values
    vicen = ds_out['vicen'][:].values

    zTsn = A * qsno + B
    Tmax = -qsno * puny_temp * rnslyr / (rhos * cp_ice * vsnon + puny_temp)
    Qmax = rhos * cp_ice * (Tmax - Lfresh / cp_ice)

    newq = np.where(zTsn <= Tmax, qsno, Qmax)
    newf = np.where(vicen > 0.00001, aicen, 0.0)
    newf2 = np.where(newf > 1.0, 1.0, newf)

    # Fill in snow enthalpy (0) where there is no snow
    newq2 = np.where(vsnon == 0.0, qsno, newq)
    
    ds_out['qsno001'][:] = newq2
    ds_out['aicen'][:] = newf2

    # --- Recompute Ice Fraction Mask ---
    aice = ds_out['aicen'].sum(dim='ncat')
    ds_out['iceumask'][:] = xr.where(aice > 0.1, 1.0, 0.0)

    # --- Save Output ---
#    print(f"Writing output to {out_file}...")
#    ds_out = ds_out.expand_dims('Time')
    ds_out.to_netcdf(out_file) #, unlimited_dims='Time')
#    print("Interpolation complete.")

def remap(ds_in, wgt_file):
    S_mat, dst_dims, nb = unpack(wgt_file)

    dims = (dst_dims[1], dst_dims[0])
    N = 1.2676506e+30 # NaN placeholder value

    remapped = {}

    for var in ds_in:
        data_src = np.array(ds_in[var].values[:])
        shape = len(np.shape(data_src))

        if shape == 2:
            data_lvl = np.where(data_src.ravel() == N, 0, data_src.ravel())
            data_rmp = S_mat.dot(data_lvl).reshape(dims)
            remapped[var] = xr.DataArray(data_rmp, dims=("nj", "ni"))
        else: # 3D (ncat, nj, ni)
            ncat = data_src.shape[0]
            data_rmp = np.zeros((ncat, nb))
            for d in range(ncat):
                data_lvl = np.where(data_src[d, :, :].ravel() == N, 0, data_src[d, :, :].ravel())
                data_rmp[d, :] = S_mat.dot(data_lvl)
            data_rmp = data_rmp.reshape(ncat, dims[0], dims[1])
            remapped[var] = xr.DataArray(data_rmp, dims=("ncat", "nj", "ni"))

    return xr.Dataset(remapped)

def unpack(wgt_file):
    wgt_ds = xr.open_dataset(wgt_file)
    na = wgt_ds['n_a'].shape[0]
    nb = wgt_ds['n_b'].shape[0]
    col = np.array(wgt_ds['col'].values[:]) - 1
    row = np.array(wgt_ds['row'].values[:]) - 1
    S = np.array(wgt_ds['S'].values[:])

    # Sparse matrix mapping source to target grid
    S_mat = coo_matrix((S, (row, col)), shape=(nb, na))
    dst_dims = wgt_ds['dst_grid_dims'].values[:]

    return S_mat, dst_dims, nb

def rotate(u, v, ang, rot):
    u = np.asarray(u)
    v = np.asarray(v)
    ang = np.asarray(ang)

    if (np.min(ang) < -1 * np.pi) or (np.max(ang) > np.pi):
        ang = np.radians(ang)

    cosa = np.cos(ang)
    sina = np.sin(ang)

    if rot == 'grid2NS':
        rotated_u = u*cosa + v*sina
        rotated_v = v*cosa - u*sina
    elif rot == 'NS2grid':
        rotated_u = u*cosa - v*sina
        rotated_v = v*cosa + u*sina

    return rotated_u, rotated_v

def get_centers(data):
    # Extracts cell centers from supergrid
    return data[1::2, 1::2]

if __name__=="__main__":
    parser = argparse.ArgumentParser(description="Remap ice initial conditions from tripole to latlon grid")
    parser.add_argument("--wgt_file", required=True,  help="Path to weight file")
    parser.add_argument("--src_file", required=True,  help="Path to source data file")
    parser.add_argument("--src_angl", required=True,  help="Path to source grid angle file")
    parser.add_argument("--msk_file", required=True,  help="Path to destination mask file")
    parser.add_argument("--dst_angl", required=True,  help="Path to destination grid angle file")
    parser.add_argument("--msk_name", default="mask", help="Mask variable name. Defaults to 'mask'")
    parser.add_argument("--out_file", required=True,  help="Path to output file")

    args = parser.parse_args()

    main(args)
