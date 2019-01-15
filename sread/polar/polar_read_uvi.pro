;+
; Read Polar UIV data.
;
; time. A time or a time range in ut time. Set time to find files
;   automatically, or set files to read data in them directly.
; datatype. A string set which set of variable to read. Use
;   print_datatype to see supported types.
; probe. A string set the probe to read data for.
; level. A string set the level of data, e.g., 'l1'.
; variable. An array of variables to read. Users can omit this keyword
;   unless want to fine tune the behaviour.
; files. A string or an array of N full file names. Set this keyword
;   will set files directly.
; version. A string sets the version of data. Default behaviour is to read
;   the highest version. Set this keyword to read specific version.
; id. A string for type dispatch. This is for low-level manipulations.
; errmsg. A flag. 1 for error in loading data, 0 for ok.
;-
;

pro polar_read_uvi, time, datatype, print_datatype=print_datatype, $
    variable=vars, files=files, level=level, version=version, id=id, errmsg=errmsg
    
    compile_opt idl2
    on_error, 0
    errmsg = 0
    
    nfile = n_elements(files)
    if n_elements(time) eq 0 and nfile eq 0 then begin
        message, 'no time or file is given ...', /continue
        if not keyword_set(print_datatype) then return
    endif

    loc_root = join_path([sdiskdir('Research'),'data','polar','uvi'])
    rem_root = 'https://cdaweb.sci.gsfc.nasa.gov/pub/data/polar/uvi'
    version = (n_elements(version) eq 0)? 'v[0-9]{2}': version
    
    type_dispatch = []
    type_dispatch = [type_dispatch, $
        {id: 'l1', $
        base_pattern: 'po_level1_uvi_%Y%m%d_'+version+'.cdf', $
        remote_pattern: join_path([rem_root,'uvi_level1','%Y']), $
        local_pattern: join_path([loc_root,'uvi_level1','%Y']), $
        variable: ['EPOCH','INT_IMAGE','FILTER','FRAMERATE','SYSTEM'], $
        time_var: 'EPOCH', $
        time_type: 'epoch'}]
    if keyword_set(print_datatype) then begin
        print, 'Suported data type: '
        ids = type_dispatch.id
        foreach tid, ids do print, '  * '+tid
        return
    endif

    ; dispatch patterns.
    if n_elements(id) eq 0 then id = strjoin([datatype],'%')
    ids = type_dispatch.id
    idx = where(ids eq id, cnt)
    if cnt eq 0 then message, 'Do not support type '+id+' yet ...'
    myinfo = type_dispatch[idx[0]]

    ; find files to be read.
    file_cadence = 86400.
    if nfile eq 0 then begin
        update_t_threshold = 365.25d*86400  ; 1 year.
        index_file = 'SHA1SUM'
        times = break_down_times(time, file_cadence)
        patterns = [myinfo.base_pattern, myinfo.local_pattern, myinfo.remote_pattern]
        files = find_data_file(time, patterns, index_file, $
            file_cadence=file_cadence, threshold=update_t_threshold)
    endif
    
    ; no file is found.
    if n_elements(files) eq 1 and files[0] eq '' then begin
        errmsg = 1
        return
    endif

    ; read variables from file.
    if n_elements(vars) eq 0 then vars = myinfo.variable
    times = make_time_range(time, file_cadence)
    time_type = myinfo.time_type
    time_var = myinfo.time_var
    times = convert_time(times, from='unix', to=time_type)
    read_data_time, files, vars, prefix='', time_var=time_var, times=times, /dum
    if time_type ne 'unix' then fix_time, vars, time_type
end
