;--- Modified from script here: https://gist.github.com/uturuncoglu/9c638f003e0bf9dc089c8298d5e24c0a#file-gen_scrip-ncl ---
begin
  ;--- read list of the files ---
  lst = asciiread("mesh_gen_input_file.txt", -1, "string")
  nlst = dimsizes(lst)
  
  ;--- remove commented ones ---
  removed = str_match_ind_regex(lst, "^#")
  if (any(.not. ismissing(removed))) then 
    nremoved = dimsizes(removed)
    lst_new = new((/ nlst-nremoved /), "string")
    j = 0
    do i = 0, nlst-1
      if (.not. any(i .eq. removed)) then
        lst_new(j) = lst(i)
        j = j+1
      end if
    end do
    delete(lst)
    lst = lst_new
    delete(lst_new)
    nlst = dimsizes(lst)  
  end if

  ;--- loop over files ---
  do i = 0, nlst-1
    print(i+" "+lst(i))

    ;--- read file ---
    grd_file = addfile(lst(i), "r")

    ;--- list of variables ---
    lst_var = getfilevarnames(grd_file)

    ;--- check variables ---
    lat_name = ""
    lon_name = ""
    msk_name = ""
    do j = 0, dimsizes(lst_var)-1
      var_type = typeof(grd_file->$lst_var(j)$)
      if (isStrSubset(str_lower(lst_var(j)), "lon") .or. \
          isStrSubset(str_lower(lst_var(j)), "x")) then
        if (var_type .ne. "integer") then
          lon_name = lst_var(j)
        end if
      end if 
      if (isStrSubset(str_lower(lst_var(j)), "lat") .or. \
          isStrSubset(str_lower(lst_var(j)), "y")) then
        if (var_type .ne. "integer") then
          lat_name = lst_var(j)
        end if
      end if
      if (isStrSubset(str_lower(lst_var(j)), "mask")) then
        msk_name = lst_var(j)
      end if
    end do

    ;--- read variables ---
    if (.not. str_is_blank(lat_name)) then
      lat = grd_file->$lat_name$
      rank = dimsizes(dimsizes(lat))
    end if
    if (.not. str_is_blank(lon_name)) then
      lon = grd_file->$lon_name$
    end if
    if (.not. str_is_blank(msk_name)) then
      msk = grd_file->$msk_name$
    end if
    print(lat_name+" "+lon_name+" "+msk_name+" "+rank)

    ;--- fix lon if it is required ---
    ;if (max(lon) .lt. 360.0) then
    ;  if (rank .eq. 1) then
    ;    tmp = new((/ dimsizes(lon)+1 /), typeof(lon))
    ;    tmp(:dimsizes(lon)-1) = lon
    ;    tmp(dimsizes(lon)) = 360.0
    ;    delete(lon)
    ;    lon = new((/ dimsizes(tmp) /), typeof(tmp))
    ;    lon = tmp
    ;    delete(tmp)
    ;  end if
    ;end if

    ;--- create output file ---
    dumm = str_split(lst(i), ".")
    ofile = "ocean_mask.SCRIP.nc"
    print("ofile")
    ofile = systemfunc("basename "+ofile)
    delete(dumm)

    ;--- write file name to file that mesh generation script could read ---
    if (i .eq. 0) then
      system("echo '"+ofile+"' > create_mesh.txt")
    else
      system("echo '"+ofile+"' >> create_mesh.txt")
    end if

    ;--- generate SCRIP file ---
    opt = True
    opt@Debug = False
    opt@Testit = False
    opt@ForceOverwrite = True
    opt@PrintTimings = True
    opt@NetCDFType = "netcdf4"
    opt@Title = "input file: "+lst(i)
    if (.not. str_is_blank(msk_name)) then
      if (min(msk) .ne. max(msk)) then
        opt@GridMask = msk
        print("mask min = "+sprintf("%8.3f", min(msk))+" max = "+sprintf("%8.3f", max(msk)))
      end if
    end if

    ;--- fix for single point data ---
    dims = dimsizes(lat)
    if (dims(0) .eq. 1 .and. dims(1) .eq. 1) then
      rectilinear_to_SCRIP(ofile, lat(0,0), lon(0,0), opt)
    else
      if (rank .eq. 1) then
        rectilinear_to_SCRIP(ofile, lat, lon, opt)
      end if
      if (rank .eq. 2) then
        processed = False
        if (dims(0) .eq. 1) then
          rectilinear_to_SCRIP(ofile, lat(0,:), lon(0,:), opt)
          processed = True
        end if
        if (dims(1) .eq. 1) then
          rectilinear_to_SCRIP(ofile, lat(:,0), lon(:,0), opt)
          processed = True
        end if
        if (.not. processed) then
          curvilinear_to_SCRIP(ofile, lat, lon, opt)
        end if
      end if
    end if

    ;--- add area to SCRIP file ---
    scripFile = addfile(ofile, "w")

    grid_size = dimsizes(scripFile->grid_center_lat)
    grid_area = new(grid_size,double)
    grid_area!0 = "grid_size"

    do j = 0, grid_size-1
      temp_tlat = (/ scripFile->grid_corner_lat(j,2), \
                     scripFile->grid_corner_lat(j,1), \
                     scripFile->grid_corner_lat(j,0), \
                     scripFile->grid_corner_lat(j,3) /)
      temp_tlon = (/ scripFile->grid_corner_lon(j,2), \
                     scripFile->grid_corner_lon(j,1), \
                     scripFile->grid_corner_lon(j,0), \
                     scripFile->grid_corner_lon(j,3) /)
      print(temp_tlon)
      grid_area(j) = area_poly_sphere(temp_tlat, temp_tlon, 1)
    end do
    exit()

    scripFile->grid_area = (/ grid_area /)

    print("area min = "+sprintf("%8.3f", min(grid_area))+" max = "+sprintf("%8.3f", max(grid_area)))
    print("corner lon min = "+sprintf("%8.3f", min(scripFile->grid_corner_lon))+" max = "+sprintf("%8.3f", max(scripFile->grid_corner_lon)))
    print("corner lat min = "+sprintf("%8.3f", min(scripFile->grid_corner_lat))+" max = "+sprintf("%8.3f", max(scripFile->grid_corner_lat)))

    ;--- delete temporary variables ---
    delete([/ lst_var, opt, ofile, grid_area /])
    if (isdefined("lon")) then
      delete(lon)
    end if
    if (isdefined("lat")) then
      delete(lat)
    end if
    if (isdefined("msk")) then
      delete(msk)
    end if
  end do
end
