import argparse
import xarray as xr
import numpy as np
#from matplotlib import pyplot as plt
import xesmf as xe
import os

def main(args):

    cdate = args.cdate
    outdir = args.outdir
    src_grid = args.src_grid
    src_data = args.src_data
    dst_grid = args.dst_grid
    dst_mask = args.dst_mask
    if args.wfile:
        wfile = args.wfile
    else:
        wfile = args.outdir+'/replay_ice_to_arctic_grid_weights.nc'
    
    # rename lat and lons from grid files for ESMF interpolation
    grid_in=xr.open_dataset(src_grid)
    grid_out=xr.open_dataset(dst_grid)
    grid_in=grid_in.rename({'lonCt': 'lon', 'latCt': 'lat'})
    grid_out=grid_out.rename({'x': 'lon', 'y': 'lat'})

    output_file = outdir+'replay_ice.arctic_grid.%s.nc' %cdate
   
    if args.wfile:
        rg_tt = xe.Regridder(grid_in, grid_out, 'nearest_s2d', periodic=True,reuse_weights=True, filename=wfile)
    else:
        rg_tt = xe.Regridder(grid_in, grid_out, 'nearest_s2d', periodic=True,reuse_weights=False, filename=wfile)

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
    ds_in = xr.open_dataset(src_data) 
    ds_in=ds_in.drop(['fsnow','iage','alvl','vlvl','apnd','hpnd','ipnd','dhs','ffrac'])
    ds_out=rg_tt(ds_in)
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
    ds_kmt = xr.open_dataset(dst_mask)
    kmt = np.asarray(ds_kmt.kmt.values, dtype=float)
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
    
    ds_out.to_netcdf(output_file,unlimited_dims='Time')

if __name__=="__main__":
    parser = argparse.ArgumentParser(description="Remap ice initial conditions from tripole to latlon grid")
    parser.add_argument("--cdate",    required=True, help="Simulation start date")
    parser.add_argument("--outdir",   required=True, help="Output (run) directory")
    parser.add_argument("--src_grid", required=True, help="Path to source grid file")
    parser.add_argument("--src_data", required=True, help="Path to source data file")
    parser.add_argument("--dst_grid", required=True, help="Path to destination grid file (cannot include mask)")
    parser.add_argument("--dst_mask", required=True, help="Path to destination grid kmt mask")
    parser.add_argument("--wfile", required=False, help="Path to weights file (will generate weights if not supplied)")

    args = parser.parse_args()

    main(args)
