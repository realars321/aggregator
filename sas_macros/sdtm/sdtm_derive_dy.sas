/******************************************************************************
* Macro:    sdtm_derive_dy
* Purpose:  Derive Study Day (--DY) variable per SDTM rules:
*           DY = date - RFSTDTC + 1  (if date >= RFSTDTC)
*           DY = date - RFSTDTC      (if date <  RFSTDTC, no Day 0)
*
* Parameters:
*   inds     - Input dataset
*   outds    - Output dataset
*   dtc_var  - The --DTC variable to derive DY from (ISO 8601 char)
*   dy_var   - The target --DY variable name
*   rfstdtc  - Reference start date variable (default: RFSTDTC)
*
* Example:
*   %sdtm_derive_dy(inds=ae2, outds=ae3, dtc_var=AESTDTC, dy_var=AESTDY);
*   %sdtm_derive_dy(inds=ae3, outds=ae4, dtc_var=AEENDTC, dy_var=AEENDY);
******************************************************************************/

%macro sdtm_derive_dy(inds=, outds=, dtc_var=, dy_var=, rfstdtc=RFSTDTC);

  data &outds;
    set &inds;

    /* Only derive if both dates are complete (at least 10 characters: YYYY-MM-DD) */
    if length(&dtc_var) >= 10 and length(&rfstdtc) >= 10 then do;
      _dtc_dt = input(substr(&dtc_var, 1, 10), ?? yymmdd10.);
      _ref_dt = input(substr(&rfstdtc, 1, 10), ?? yymmdd10.);

      if not missing(_dtc_dt) and not missing(_ref_dt) then do;
        if _dtc_dt >= _ref_dt then
          &dy_var = _dtc_dt - _ref_dt + 1;
        else
          &dy_var = _dtc_dt - _ref_dt;
      end;
      else
        &dy_var = .;
    end;
    else
      &dy_var = .;

    drop _dtc_dt _ref_dt;
  run;

%mend sdtm_derive_dy;
