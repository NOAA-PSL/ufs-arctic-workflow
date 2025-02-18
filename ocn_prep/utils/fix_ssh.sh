#!/bin/bash

ncap2 -s 'ssh_segment_001[$MT,$nz_segment_001,$ny_segment_001,$nx_segment_001] = ssh_segment_001(:,:,:);' mom6_OBC_001.nc mom6_OBC_001_test.nc
