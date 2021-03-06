;+
; Type: function.
;
; Purpose: Read FAST ESA data from CDAWeb:
;   ftp://cdaweb.gsfc.nasa.gov/pub/data/fast/ies.
;
;   (1) If only set a time range, find data file using default pattern, 
;   download the file if not found locally, read the data in the time range.
;   (2) If only set a time, similar to (1) but read the available record
;   nearest to the given time. If the nearest record has a time separation
;   larger than the data rate, then say no data at the given time.
;   (3) If only set a file name, read all records in the file. If it's an
;   array of file names, read data in all of the files and concatenate them.
;   (4) If set both file name and record, find file use the file name, read
;   data for the given time range or time.
;
; Parameters:
;   tr0, in, double/string or dblarr[2]/strarr[2], optional. If in double or
;       string, set the time; if in dblarr[2] or strarr[2], set the time range.
;       For double or dblarr[2], it's the unix time or UTC. For string or
;       strarr[2], it's the formatted string accepted by stoepoch, e.g.,
;       'YYYY-MM-DD/hh:mm'.
;
; Keywords:
;   filename, in, string or strarr[n], optional. The full file name(s) includes
;       explicit paths.
;   tflag, in, int, optional. 0: all records, 1: nearest rec, 2: exact rec.
;   locroot, in, string, optional. The local data root directory.
;   remroot, in, string, optional. The remote data root directory.
;   type, in, string, optional. Data type. Supported type 'ies', 'ees'.
;   version, in, string, optional. Data version. In case to load an old
;       version data. By default, the highest version is loaded.
;
;   vars, in, strarr[n], optional. Set the variables to be loaded. There are
;       default settings for each type of data, check skeleton file to find
;       the available variables.
;   newnames, in/out, strarr[n], optional. The variable names appeared in the
;       returned structure. Must be valid names for structure tags.
;
; Return: struct.
;
; Notes: Related data sources.
;   <strelka>/data/fast/kp/ies/
;   <strelka>/data1/fast_cdf/ies/fa_k0_ies_orbit_v??.cdf
;
; Dependence: slib.
;
; History:
;   2013-06-17, Sheng Tian, create.
;-

function sread_fast_esa, tr0, filename = fn0, tflag = tflag, $
    vars = var0s, newnames = var1s, $
    locroot = locroot, remdir = remdir, type = type, version = version

    compile_opt idl2

    ; local and remote directory.
    sep = path_sep()
    if n_elements(locroot) eq 0 then locroot = spreproot('fast')
    if n_elements(remroot) eq 0 then $
        remroot = 'ftp://cdaweb.gsfc.nasa.gov/pub/data/fast'

    ; **** prepare file names.
    ; prepare locfns, nfn.
    nfn = n_elements(fn0)
    if nfn gt 0 then begin      ; find locally.
        locfns = fn0
        for i = 0, nfn-1 do begin
            basefn = file_basename(locfns[i])
            locpath = file_dirname(locfns[i])
            locfns[i] = sgetfile(basefn, locpath)
        endfor
        idx = where(locfns ne '', nfn)
    endif
    
    if nfn eq 0 then begin      ; find remotely.
        if n_elements(type) eq 0 then type = 'ies'  ; can be ies, ees.
        vsn = (n_elements(version))? version: 'v[0-9]{2}'
        ext = 'cdf'
        locidx = 'SHA1SUM'

        baseptn = 'fa_k0_'+type+'_YYYYMMDD_'+vsn+'.'+ext
        rempaths = [remroot,type,type+'_k0','YYYY',baseptn]
        locpaths = [locroot,type,type+'_k0','YYYY',baseptn]
        
        remfns = sprepfile(tr0, paths = rempaths)
        locfns = sprepfile(tr0, paths = locpaths)
        nfn = n_elements(locfns)
        for i = 0, nfn-1 do begin
            basefn = file_basename(locfns[i])
            locpath = file_dirname(locfns[i])
            rempath = file_dirname(remfns[i])
            locfns[i] = sgetfile(basefn, locpath, rempath, locidx = locidx)
        endfor
    endif
    idx = where(locfns ne '', nfn)
    if nfn ne 0 then locfns = locfns[idx] else return, -1
    

    ; **** check record index. locfns, nfn, recs, and etrs.
    epvname = 'Epoch'
    if ~keyword_set(tflag) then tflag = 0
    if n_elements(tr0) eq 0 then begin  ; no time info.
        recs = lon64arr(nfn,2)-1    ; [-1,-1] means to read all records.
        etrs = dblarr(2)
        tmp = scdfread(locfns[0],epvname,0)
        ets = *(tmp[0].value) & ptr_free, tmp[0].value
        etrs[0] = ets[0]
        tmp = scdfread(locfns[nfn-1],epvname,-1)
        ets = *(tmp[0].value) & ptr_free, tmp[0].value
        etrs[1] = ets[0]
    endif else begin                    ; there are time info.
        if size(tr0,/type) eq 7 then tformat = '' else tformat = 'unix'
        etrs = stoepoch(tr0, tformat)
        flags = bytarr(nfn)             ; 0 for no record.
        recs = lon64arr(nfn,2)
        for i = 0, nfn-1 do begin
            tmp = scdfread(locfns[i],epvname)   ; read each file's epoch.
            ets = *(tmp[0].value) & ptr_free, tmp[0].value
            if n_elements(etrs) eq 1 then begin ; tr0 is time.
                if tflag eq 0 then begin    ; read all records.
                    flags[i] = 1b
                    recs[i,*] = [0,n_elements(ets)-1]
                endif else if tflag eq 1 then begin ; read rearest record.
                    tmp = min(ets-etrs,idx, /absolute)
                    dr = sdatarate(ets)
                    if abs(ets[idx]-etrs) gt dr then flags[i] = 0 else begin
                        flags[i] = 1b
                        recs[i,*] = [idx,idx]
                    endelse
                endif else if tflag eq 2 then begin
                    idx = where(ets eq etrs, cnt)
                    if cnt ne 0 then begin
                        flags[i] = 1b
                        recs[i,*] = [idx,idx]
                    endif
                endif else message, 'invalid time info flag ...'
            endif else begin                    ; tr0 is time range.
                idx = where(ets ge etrs[0] and ets le etrs[1], cnt)
                if cnt eq 0 then flags[i] = 0 else begin
                    flags[i] = 1b
                    recs[i,*] = [idx[0],idx[cnt-1]]
                endelse
            endelse
        endfor
        idx = where(flags eq 1b, cnt)
        if cnt eq 0 then begin
            message, 'no data at given time ...', /continue
            return, -1
        endif else begin
            locfns = locfns[idx]
            recs = recs[idx,*]
        endelse
    endelse
    nfn = n_elements(locfns)

    ; **** prepare var names.
    if n_elements(var0s) eq 0 then begin
        case type of
            'ies': var0s = ['Epoch','ion_'+['en','0','90','180'],'JEi']
            'ees': var0s = ['Epoch','el_'+['en','0','90','180'],'JEe']
            else: message, 'unknown data type ...'
        endcase
    endif
    if n_elements(var1s) eq 0 then var1s = idl_validname(var0s)
    var1s = idl_validname(var1s)

    ; **** module for variable loading.
    nvar = n_elements(var0s)
    if nvar ne n_elements(var1s) then message, 'mismatch var names ...'
    ptrs = ptrarr(nvar)
    ; first file.
    tmp = scdfread(locfns[0],var0s,recs[0,*])
    for j = 0, nvar-1 do ptrs[j] = (tmp[j].value)
    ; rest files.
    for i = 1, nfn-1 do begin
        tmp = scdfread(locfns[i],var0s,recs[i,*])
        for j = 0, nvar-1 do begin
            ; works for all dims b/c cdf records on the 1st dim of array.
            *ptrs[j] = [*ptrs[j],*(tmp[j].value)]
            ptr_free, tmp[j].value  ; release pointers.
        endfor
    endfor
    ; remove fill value.
    fillval = -1e31
    vars = var0s
    for i = 0, n_elements(vars)-1 do begin
        idx = where(var0s eq vars[i], cnt) & idx = idx[0]
        if cnt eq 0 then continue
        idx2 = where(*ptrs[idx] eq fillval, cnt)
        if cnt ne 0 then (*ptrs[idx])[idx2] = !values.d_nan
    endfor
    ; move data to structure.
    dat = create_struct(var1s[0],*ptrs[0])
    for j = 1, nvar-1 do dat = create_struct(dat, var1s[j],*ptrs[j])
    for j = 0, nvar-1 do ptr_free, ptrs[j]

    return, dat
 end
 
 ees = sread_fast_esa('2002-09-01/00:39:49',tflag = 2)
 end
