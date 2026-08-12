# Adapted from https://github.com/NOAA-EMC/land-data-utils/blob/84c76330b26c21df18081ad6dd2e0314682edc7a/spinup/replace_land_states.py
#
# Script to replace land states in sfc_data files 
#   with those from the land spinup system
# run using:
#   replace_soil_snow.py /path-to-sfc_data-directory /path-to-spinup-file
# 

import os
import sys
import numpy as np
from netCDF4 import Dataset

# variable list in spinup vector files
vector_variables = ['soil_moisture_vol','soil_liquid_vol','temperature_soil','snow_depth','snow_water_equiv', 'temperature_ground']

# variable list in sfc_data tile files
sfc_data_variables = ['smc','slc','stc','weasdl','snodl','tsfcl']

# limit for maximum snow water equivalent on glaciers [mm]
swe_maximum_glacier = 2000.0

# limit for maximum snow water equivalent on non-glaciers [mm]
swe_maximum_land = 10000.0

# limit for minimum snow water equivalent and depth [mm]
swe_minimum = 0.1
snow_depth_minimum = 1.0

# minimum allowed smc (and slc) value [volumetric]
soil_moisture_minimum = 0.02

print_limits            = False # print min / max change for each variable
print_high_snow_removal = False # print when high snow is removed
print_low_snow_removal  = False # print when low snow is removed

##############################
# get args
if (len(sys.argv) != 3): 
  for i, arg in enumerate(sys.argv):
    print(f"Argument {i}: {arg}")
  str_err = f" ** Error: expecting 4 arguments: \n ** /path-to-sfc_data-directory /path-to-spinup-file"
  sys.exit(str_err)

tile_directory = sys.argv[1] 
vector_file    = sys.argv[2]

##############################
# read in spun-up variables on vector

ncid = Dataset(vector_file, 'r')

vec_smc = ncid.variables[vector_variables[0]][0, :, :]
vec_slc = ncid.variables[vector_variables[1]][0, :, :]
vec_stc = ncid.variables[vector_variables[2]][0, :, :]
vec_snd = ncid.variables[vector_variables[3]][0, :] # mm
vec_swe = ncid.variables[vector_variables[4]][0, :]
vec_tmp = ncid.variables[vector_variables[5]][0, :]

ncid.close()

number_in_vector = len(vec_stc[0, :])
# print(f"Number of grids in vector: {number_in_vector}")

##############################
# Loop over tile files

number_variables = len(sfc_data_variables)

location_count = -1
high_snow_removal = 0
low_snow_removal = 0

for itile in range(7, 8):
#  print(f"Starting tile: {itile}")
  min_val = np.full((number_variables,4),0.)
  max_val = np.full((number_variables,4),0.)

  tile_file = tile_directory+"sfc_data.tile"+str(itile)+".nc"

  cmd = 'chmod 755 '+tile_file
  os.system(cmd)
  ncid_tile = Dataset(tile_file, 'r+')

  tile_veg = ncid_tile.variables['vtype'][0, :, :]
  tile_smc = ncid_tile.variables[sfc_data_variables[0]][:]
  tile_slc = ncid_tile.variables[sfc_data_variables[1]][:]
  tile_stc = ncid_tile.variables[sfc_data_variables[2]][:]
  tile_swe = ncid_tile.variables[sfc_data_variables[3]][:]
  tile_snd = ncid_tile.variables[sfc_data_variables[4]][:]
  tile_tmp = ncid_tile.variables[sfc_data_variables[5]][:]

  dimension_sizes = tile_veg.shape

  for idim0 in range(dimension_sizes[0]):
    for idim1 in range(dimension_sizes[1]):
      if tile_veg[idim0, idim1] != 0:
        location_count += 1

        ################################
        # insert vector values

        # snow water equivalent
        orig = tile_swe[0, idim0, idim1]
        tile_swe[0, idim0, idim1] = vec_swe[location_count]
        min_val[3,0] = min(min_val[3,0],tile_swe[0,  idim0, idim1] - orig)
        max_val[3,0] = max(max_val[3,0],tile_swe[0,  idim0, idim1] - orig)

        # snow depth
        orig = tile_snd[0, idim0, idim1]
        tile_snd[0, idim0, idim1] = vec_snd[location_count]
        min_val[4,0] = min(min_val[4,0],tile_snd[0,  idim0, idim1] - orig)
        max_val[4,0] = max(max_val[4,0],tile_snd[0,  idim0, idim1] - orig)

        # land surface temp
        orig = tile_tmp[0, idim0, idim1]
        tile_tmp[0, idim0, idim1] = vec_tmp[location_count]
        min_val[5,0] = min(min_val[5,0],tile_tmp[0, idim0, idim1] - orig)
        max_val[5,0] = max(max_val[5,0],tile_tmp[0, idim0, idim1] - orig)

        # soil temperatures
        for l in np.arange(4):
          orig = tile_stc[0, l, idim0, idim1]
          tile_stc[0, l, idim0, idim1] = vec_stc[l, location_count]
          min_val[2,l] = min(min_val[2,l],tile_stc[0, l, idim0, idim1] - orig)
          max_val[2,l] = max(max_val[2,l],tile_stc[0, l, idim0, idim1] - orig)


        if (tile_veg[idim0,idim1] != 15):

          # don't use soil moisture values under glaciers
          # note: spun-up vector restarts have slc=0, smc=1 under glaciers
          #       tile restarts from change_res have slc=1, smc=1

          # note: applying slc pert to slc and smc (frozen soil moisture same for all members)
          # note: potentially allowing soil moisture above porosity. I think the model fixes this.
          for l in np.arange(4):
            orig = tile_smc[0, l, idim0, idim1]
            tile_smc[0, l, idim0, idim1] = max(soil_moisture_minimum, vec_smc[l, location_count])
            min_val[0,l] = min(min_val[0,l],tile_smc[0, l, idim0, idim1] - orig)
            max_val[0,l] = max(max_val[0,l],tile_smc[0, l, idim0, idim1] - orig)

            orig = tile_slc[0, l, idim0, idim1]
            tile_slc[0, l, idim0, idim1] = max(soil_moisture_minimum, vec_slc[l, location_count])
            min_val[1,l] = min(min_val[1,l],tile_slc[0, l, idim0, idim1] - orig)
            max_val[1,l] = max(max_val[1,l],tile_slc[0, l, idim0, idim1] - orig)


          #  check glacier tiles match
          if ( tile_smc[0, 0, idim0, idim1] > 0.99 or vec_smc[0,location_count]>0.99):
            print(f"tile_smc: {tile_smc[0, l, idim0, idim1]}") 
            print(f"vec_smc: {vec_smc[0,location_count]}") 
            str_err = f" ** Error:  expecting soil moisture value, got 1."
            sys.exit(str_err)

      #################################
      # sanity checks

      # remove low snow (includes negative check)
      if (tile_snd[0,idim0,idim1] < snow_depth_minimum) or (tile_swe[0,idim0,idim1] < swe_minimum):
        if print_low_snow_removal:
          print(f"Removing location with SWE = {tile_swe[0,idim0,idim1]} and depth = {tile_snd[0,idim0,idim1]}")
        tile_swe[0, idim0, idim1] = 0.
        tile_snd[0, idim0, idim1] = 0.
        low_snow_removal += 1

      # swe boundary checks over glaciers
      if tile_snd[0,idim0,idim1] > swe_maximum_glacier and tile_veg[idim0,idim1] == 15: # glaciers
        reduction_factor = swe_maximum_glacier / tile_snd[0,idim0,idim1]
        if print_high_snow_removal:
          print(f"Reducing glacier location with depth = {tile_snd[0,idim0,idim1]} by factor = {reduction_factor}")
        tile_snd[0,idim0,idim1] = swe_maximum_glacier
        tile_swe[0,idim0,idim1] *= reduction_factor
        high_snow_removal += 1

      # swe boundary checks over non-glacier
      if tile_snd[0,idim0,idim1] > swe_maximum_land:
        reduction_factor = swe_maximum_land / tile_snd[0,idim0,idim1]
        if print_high_snow_removal:
          print(f"Reducing non-glacier location with depth = {tile_snd[0,idim0,idim1]} by factor = {reduction_factor}")
        tile_snd[0,idim0,idim1] = swe_maximum_land
        tile_swe[0,idim0,idim1] *= reduction_factor
        high_snow_removal += 1

  number_in_tiles = location_count + 1

  # Update the NetCDF variables
  ncid_tile.variables[sfc_data_variables[0]][:] = tile_smc
  ncid_tile.variables[sfc_data_variables[1]][:] = tile_slc
  ncid_tile.variables[sfc_data_variables[2]][:] = tile_stc
  ncid_tile.variables[sfc_data_variables[3]][:] = tile_swe
  ncid_tile.variables[sfc_data_variables[4]][:] = tile_snd
  ncid_tile.variables[sfc_data_variables[5]][:] = tile_tmp

  ncid_tile.close()

if number_in_tiles != number_in_vector:
  str_err = f" ** Error: Number in tiles != number in vector"
  sys.exit(str_err)
 
if print_limits:
  for v in np.arange(3):
    for l in np.arange(4):
      print(f"min {var_list[v]}, level {l}:  {min_val[v,l]}")
      print(f"max {var_list[v]}, level {l}:  {max_val[v,l]}")

  for v in [3,4]:
    l=0
    print(f"min {var_list[v]}, level {l}:  {min_val[v,l]}")
    print(f"max {var_list[v]}, level {l}:  {max_val[v,l]}")

#print(f"Number high_snow_removal: {high_snow_removal}")
#print(f"Number low_snow_removal: {low_snow_removal}")
#print("Processing completed.")

