#!/bin/bash

ncks -A -v ssh_segment_001 mom6_OBC_001.nc ssh_001.nc
ncks -A -v ssh_segment_002 mom6_OBC_002.nc ssh_002.nc
ncks -A -v ssh_segment_003 mom6_OBC_003.nc ssh_003.nc
ncks -A -v ssh_segment_004 mom6_OBC_004.nc ssh_004.nc

ncks -A -v salinity_segment_001 mom6_OBC_001.nc salinity_001.nc
ncks -A -v salinity_segment_002 mom6_OBC_002.nc salinity_002.nc
ncks -A -v salinity_segment_003 mom6_OBC_003.nc salinity_003.nc
ncks -A -v salinity_segment_004 mom6_OBC_004.nc salinity_004.nc

ncks -A -v temp_segment_001 mom6_OBC_001.nc temp_001.nc
ncks -A -v temp_segment_002 mom6_OBC_002.nc temp_002.nc
ncks -A -v temp_segment_003 mom6_OBC_003.nc temp_003.nc
ncks -A -v temp_segment_004 mom6_OBC_004.nc temp_004.nc

ncks -A -v u_segment_001 mom6_OBC_001.nc u_001.nc
ncks -A -v u_segment_002 mom6_OBC_002.nc u_002.nc
ncks -A -v u_segment_003 mom6_OBC_003.nc u_003.nc
ncks -A -v u_segment_004 mom6_OBC_004.nc u_004.nc

ncks -A -v v_segment_001 mom6_OBC_001.nc v_001.nc
ncks -A -v v_segment_002 mom6_OBC_002.nc v_002.nc
ncks -A -v v_segment_003 mom6_OBC_003.nc v_003.nc
ncks -A -v v_segment_004 mom6_OBC_004.nc v_004.nc
