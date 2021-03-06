;+
; Read RBSP keV proton flux.
; Save as rbspx_kev_ion_flux.
;
; set pitch_angle to load data for a specific pitch angle, otherwise load all pitch angles.
;-
pro rbsp_read_kev_proton, utr0, probe, errmsg=errmsg, pitch_angle=pitch_angle, energy=energy

    pre0 = 'rbsp'+probe+'_'
    
    ; read 'rbspx_kev_ele_flux'
    vars = ['Epoch','FPDU_Alpha','FPDU_Energy','FPDU']
    rbsp_read_mageis, utr0, 'rel03', probe, level='l3', errmsg=errmsg, variable=vars
    if errmsg ne 0 then return
    
    var = pre0+'kev_ion_flux'
    get_data, 'FPDU_Energy', uts, dat
    tmp = size(dat,/dimensions)
    nenbin = tmp[1]
    nrec = tmp[0]
    enbins = fltarr(nenbin)
    for i=0, nenbin-1 do if nrec ge 2 then enbins[i] = median(dat[*,i])
    enidx = where(finite(enbins), nenbin)
    
    get_data, 'FPDU', uts, dat
    dat = reform(dat[*,enidx,*])>1
    enbins = enbins[enidx]
    
    ; apply energy range.
    if n_elements(energy) eq 0 then enidx = findgen(nenbin) else begin
        case n_elements(energy) of
            1: begin
                enidx = where(enbins eq energy, cnt)
                if cnt eq 0 then tmp = min(enbins-energy[0], /absolute, enidx)
            end
            2: begin
                enidx = where(enbins ge energy[0] and enbins le energy[1], cnt)
                if cnt eq 0 then begin
                    errmsg = 'no energy in given range ...'
                    return
                endif
            end
            else: begin
                errmsg = 'wrong # of energy info ...'
                return
            end
        endcase
    endelse
    dat = dat[*,enidx,*]
    enbins = enbins[enidx]
    nenbin = n_elements(enbins)
    
    
    ; filter pitch angle.
    get_data, 'FPDU_Alpha', tmp, pabins
    npabin = n_elements(pabins)
    if n_elements(pitch_angle) eq 0 then paidx = findgen(npabin) else begin
        case n_elements(pitch_angle) of
            1: begin
                paidx = where(pabins eq pitch_angle, cnt)
                if cnt eq 0 then tmp = min(pabins-pitch_angle[0], /absolute, paidx)
            end
            2: begin
                paidx = where(pabins ge pitch_angle[0] and pabins le pitch_angle[1], cnt)
                if cnt eq 0 then begin
                    errmsg = 'no pitch angle in given range ...'
                    return
                endif
            end
            else: begin
                errmsg = 'wrong # of pitch angle info ...'
                return
            end
        endcase
    endelse
    dat = reform(dat[*,*,paidx])
    pabins = pabins[paidx]
    npabin = n_elements(pabins)
    
    ; save data.
    if nenbin eq 1 and npabin eq 1 then begin
        store_data, var, uts, dat
        add_setting, var, /smart, {$
            display_type: 'scalar', $
            unit: '#/cm!U2!N-s-sr-keV', $
            short_name: 'H!U+!N flux '+sgnum2str(sround(pabins))+'deg, '+sgnum2str(sround(enbins))+'keV'}
    endif else if nenbin eq 1 then begin    ; flux vs pitch angle at certain energy.
        store_data, var, uts, dat, pabins
        add_setting, var, /smart, {$
            display_type: 'list', $
            unit: '#/cm!U2!N-s-sr-keV', $
            value_unit: 'deg', $
            short_name: 'H!U+!N flux '+sgnum2str(sround(enbins))+' keV'}
    endif else if npabin eq 1 then begin    ; flux vs energy at certain pitch angle.
        store_data, var, uts, dat, enbins
        add_setting, var, /smart, {$
            display_type: 'list', $
            unit: '#/cm!U2!N-s-sr-keV', $
            value_unit: 'keV', $
            short_name: 'H!U+!N flux '+sgnum2str(sround(pabins))+' deg'}
    endif else begin
        store_data, var, uts, data
        add_setting, var, /smart, {$
            display_type: 'data', $
            energy: enbins, $
            pitch_angle: pabins}
    endelse
    
    
    dt = 10.848
    uniform_time, var, dt
    
    store_data, 'FPDU'+['','_Alpha','_Energy'], /delete
    
end

utr0 = time_double(['2014-08-28/03:00','2014-08-28/15:00'])
probe = 'b'
pitch_angle = 90
energy = [100,300]

utr0 = time_double(['2014-08-28/03:00','2014-08-28/15:00'])
probe = 'a'
pitch_angle = 45
energy = [30,300]

rbsp_read_kev_proton, utr0, probe, pitch_angle=pitch_angle, energy=energy
rbsp_read_kev_electron, utr0, probe, pitch_angle=pitch_angle, energy=energy
end
