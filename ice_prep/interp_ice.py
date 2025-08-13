import argparse
import xarray as xr
import numpy as np
from scipy.sparse import coo_matrix
import os

def main(args):

    wgt_file = args.wgt_file
    src_file = args.src_file
    src_angl = args.src_angl
    msk_file = args.msk_file
    dst_angl = args.dst_angl
    out_file = args.out_file

    #define some constants
    saltmax = 3.20
    nsal    = 0.407
    msal    = 0.573
    rhoi    =  917.0
    rhos    =  330.0
    cp_ice  = 2106.0
    cp_ocn  = 4218.0
    Lfresh  = 3.34e5
    puny    = 1.0e-3
    nilyr   = 7
    ncat=5
    salinz = np.zeros(7,np.double)
    for l in range(nilyr):
        zn = (l+1-0.5)/float(nilyr)
        salinz[l] = (saltmax/2.0)*(1.0-np.cos(np.pi*zn**(nsal/(msal+zn))))
    Tmltz = salinz / (-18.48 + (0.01848*salinz))

    # remove variables we don't need
    ds_in = xr.open_dataset(src_file) 
    ds_in=ds_in.drop(['fsnow','iage','alvl','vlvl','apnd','hpnd','ipnd','dhs','ffrac'])

    # rotate source vectors to N-S
    ang_ds = xr.open_dataset(src_angl)
    angle = get_centers(ang_ds['angle_dx'])
    ds_in['uvel'][:], ds_in['vvel'][:] = rotate(ds_in['uvel'][:], ds_in['vvel'][:], angle, 'grid2NS')

    # Remap variables
    ds_out = remap(ds_in, wgt_file)

    # rotated destination vectors to grid
    ang_ds = xr.open_dataset(dst_angl)
    angle = get_centers(ang_ds['angle_dx'])
    ds_out['uvel'][:], ds_out['vvel'][:] = rotate(ds_out['uvel'][:], ds_out['vvel'][:], angle, 'NS2grid')

    ds_out['coszen'][:]=0
    ds_out['scale_factor'][:]=0
    ds_out['strocnxT'][:]=0
    ds_out['strocnyT'][:]=0
    
    # recompute snow enthalpy
    ds_out['qsno001'][:] = -rhos*(Lfresh - cp_ice*ds_out['Tsfcn'][:].values)
    
    # recompute ice enthalpy
    for kk in range(ncat):
        ttmp = (ds_out['qice001'][kk,:,:].values + rhoi*Lfresh)/(rhoi*cp_ice)
        ttmp2 = np.where(ttmp > Tmltz[kk], Tmltz[kk], ttmp)
        ds_out['qice001'][kk,:]= rhoi*cp_ice*ttmp2 - rhoi*Lfresh
        
        ttmp = (ds_out['qice002'][kk,:,:].values + rhoi*Lfresh)/(rhoi*cp_ice)
        ttmp2 = np.where(ttmp > Tmltz[kk], Tmltz[kk], ttmp)
        ds_out['qice002'][kk,:]= rhoi*cp_ice*ttmp2 - rhoi*Lfresh
        
        ttmp = (ds_out['qice003'][kk,:,:].values + rhoi*Lfresh)/(rhoi*cp_ice)
        ttmp2 = np.where(ttmp > Tmltz[kk], Tmltz[kk], ttmp)
        ds_out['qice003'][kk,:]= rhoi*cp_ice*ttmp2 - rhoi*Lfresh
        
        ttmp = (ds_out['qice004'][kk,:,:].values + rhoi*Lfresh)/(rhoi*cp_ice)
        ttmp2 = np.where(ttmp > Tmltz[kk], Tmltz[kk], ttmp)
        ds_out['qice004'][kk,:]= rhoi*cp_ice*ttmp2 - rhoi*Lfresh
        
        ttmp = (ds_out['qice005'][kk,:,:].values + rhoi*Lfresh)/(rhoi*cp_ice)
        ttmp2 = np.where(ttmp > Tmltz[kk], Tmltz[kk], ttmp)
        ds_out['qice005'][kk,:]= rhoi*cp_ice*ttmp2 - rhoi*Lfresh
        
        ttmp = (ds_out['qice006'][kk,:,:].values + rhoi*Lfresh)/(rhoi*cp_ice)
        ttmp2 = np.where(ttmp > Tmltz[kk], Tmltz[kk], ttmp)
        ds_out['qice006'][kk,:]= rhoi*cp_ice*ttmp2 - rhoi*Lfresh
        
        ttmp = (ds_out['qice007'][kk,:,:].values + rhoi*Lfresh)/(rhoi*cp_ice)
        ttmp2 = np.where(ttmp > Tmltz[kk], Tmltz[kk], ttmp)
        ds_out['qice007'][kk,:]= rhoi*cp_ice*ttmp2 - rhoi*Lfresh
    
    
    # Read in mask and set aicen to zero over land
    ds_kmt = xr.open_dataset(msk_file)
    kmt = np.asarray(ds_kmt['mask'].values, dtype=float)
    ds_out['aicen']=xr.where(kmt==1, ds_out['aicen'],0)
    
    # zero out small ice fractions
    ds_out['aicen']=xr.where(ds_out['aicen'] > 0.1, ds_out['aicen'],0)
    ds_out['vicen']=xr.where(ds_out['aicen'] > 0, ds_out['vicen'],0)
    ds_out['vsnon']=xr.where(ds_out['aicen'] > 0, ds_out['vsnon'],0)
    ds_out['qice001']=xr.where(ds_out['aicen'] > 0, ds_out['qice001'],0)
    ds_out['qice002']=xr.where(ds_out['aicen'] > 0, ds_out['qice002'],0)
    ds_out['qice003']=xr.where(ds_out['aicen'] > 0, ds_out['qice003'],0)
    ds_out['qice004']=xr.where(ds_out['aicen'] > 0, ds_out['qice004'],0)
    ds_out['qice005']=xr.where(ds_out['aicen'] > 0, ds_out['qice005'],0)
    ds_out['qice006']=xr.where(ds_out['aicen'] > 0, ds_out['qice006'],0)
    ds_out['qice007']=xr.where(ds_out['aicen'] > 0, ds_out['qice007'],0)
    
    
    #some more constants
    
    rhos      = 330.0
    cp_ice    = 2106.
    c1        = 1.0
    Lsub      = 2.835e6
    Lvap      = 2.501e6
    Lfresh=Lsub - Lvap
    rnslyr=1.0
    puny=1.0E-012
    
    # icepack formulate for snow temperature
    A = c1 / (rhos * cp_ice)
    B = Lfresh / cp_ice
    zTsn = A * ds_out['qsno001'][:].values + B
    # icepack formula for max snow tempature
    Tmax = -ds_out['qsno001'][:].values*puny*rnslyr /(rhos*cp_ice*ds_out['vsnon'][:].values+puny)
    
    # enthlap at max now tempetarure
    Qmax=rhos*cp_ice*(Tmax-Lfresh/cp_ice)
    
    # fill in new enthalpy where snow temperature is too high
    newq=np.where(zTsn <= Tmax,ds_out['qsno001'][:].values,Qmax)
    newf=np.where(ds_out['vicen'] > 0.00001,ds_out['aicen'][:].values,0.0)
    newf2=np.where(newf > 1.0,1.0,newf)
    
    # fill in snow enthalpy (0) where there is no snow
    newq2=np.where(ds_out['vsnon'][:]==0.0,ds_out['qsno001'][:].values,newq)
    ds_out['qsno001'][:]=newq2
    ds_out['aicen'][:]=newf2
    
    
    # recompute ice fraction for mask
    aice = ds_out['aicen'].sum(dim='ncat')
    new_mask=xr.where(aice > 0.1,1.,0.)
    old_mask=ds_out['iceumask'][:].values
    ds_out['iceumask'][:] = new_mask
    
    ds_out.to_netcdf(out_file,unlimited_dims='Time')

def remap(ds_in, wgt_file):
    S_mat, dst_dims, nb = unpack(wgt_file)

    dims = (dst_dims[1], dst_dims[0])
    N = 1.2676506e+30 # NaN placeholder value
    ncat=5

    remapped = {}

    for var in ds_in:
        data_src = np.array(ds_in[var].values[:])
        shape = len(np.shape(data_src))

        if shape==2:
            data_lvl = np.where(data_src.ravel()==N, 0, data_src.ravel())
            data_rmp = S_mat.dot(data_lvl).reshape(dims)
            remapped[var] = xr.DataArray(data_rmp, dims=("nj","ni"))
        else: # 3
            ncat = data_src.shape[0]
            data_rmp = np.zeros((ncat, nb))
            for d in range(ncat):
                data_lvl = np.where(data_src[d,:,:].ravel()==N, 0, data_src[d,:,:].ravel())
                data_rmp[d,:] = S_mat.dot(data_lvl)
            data_rmp = data_rmp.reshape(ncat, dims[0], dims[1])
            remapped[var] = xr.DataArray(data_rmp, dims=("ncat","nj","ni"))

    ds_out = xr.Dataset(remapped)

    return ds_out

def unpack(wgt_file):
    wgt_ds = xr.open_dataset(wgt_file)
    na = wgt_ds['n_a'].shape[0]
    nb = wgt_ds['n_b'].shape[0]
    col = np.array(wgt_ds['col'].values[:])-1
    row = np.array(wgt_ds['row'].values[:])-1
    S = np.array(wgt_ds['S'].values[:])
    S_mat = coo_matrix((S, (row, col)), shape=(nb, na))
    
    dst_dims = wgt_ds['dst_grid_dims'].values[:]
    
    return S_mat, dst_dims, nb

def rotate(u, v, ang, rot):
    u = np.asarray(u)
    v = np.asarray(v)
    ang = np.asarray(ang)

    if (np.min(ang) < -1*np.pi) or (np.max(ang) > np.pi):
        ang = np.radians(ang)

    cosa = np.cos(ang)
    sina = np.sin(ang)

    if rot=='grid2NS':
        rotated_u = u*cosa + v*sina
        rotated_v = v*cosa - u*sina
    elif rot=='NS2grid':
        rotated_u = u*cosa - v*sina
        rotated_v = v*cosa + u*sina

    return rotated_u, rotated_v

def get_centers(data):
    return data[1::2, 1::2]

if __name__=="__main__":
    parser = argparse.ArgumentParser(description="Remap ice initial conditions from tripole to latlon grid")
    parser.add_argument("--wgt_file", required=True, help="Path to weight file")
    parser.add_argument("--src_file", required=True, help="Path to source data file")
    parser.add_argument("--src_angl", required=True, help="Path to source grid angle file")
    parser.add_argument("--msk_file", required=True, help="Path to destination mask file")
    parser.add_argument("--dst_angl", required=True, help="Path to destination grid angle file")
    parser.add_argument("--msk_name", required=False,help="Mask variable name. Defaults to 'mask'")
    parser.add_argument("--out_file", required=True, help="Path to output file")

    args = parser.parse_args()

    main(args)
