/******************************************************************************
* Macro:    sdtm_map_ct
* Purpose:  Map raw/source values to CDISC Controlled Terminology.
*           Uses a lookup dataset for code list mapping, with optional
*           logging of unmapped values.
*
* Parameters:
*   inds       - Input dataset
*   outds      - Output dataset
*   mapds      - Mapping/lookup dataset with columns:
*                  CODELIST  - CT code list name
*                  SRCVAL    - Source/raw value
*                  STDVAL    - Standard CDISC CT value
*   src_var    - Source variable in input dataset
*   tgt_var    - Target variable in output dataset (mapped value)
*   codelist   - Code list name to filter mapping dataset
*   ignore_case - Y/N, case insensitive matching (default: Y)
*   log_unmap  - Y/N, log unmapped values to a dataset (default: Y)
*   unmap_ds   - Dataset name for unmapped values (default: work._unmapped)
*
* Example:
*   %sdtm_map_ct(inds=ae1, outds=ae2, mapds=metadata.ct_map,
*                src_var=AESEV_RAW, tgt_var=AESEV,
*                codelist=SEVERITY);
******************************************************************************/

%macro sdtm_map_ct(inds=, outds=, mapds=, src_var=, tgt_var=,
                   codelist=, ignore_case=Y, log_unmap=Y, unmap_ds=work._unmapped);

  /* Prepare mapping subset for the specified codelist */
  data _ct_map;
    set &mapds;
    where upcase(CODELIST) = "%upcase(&codelist)";
    %if %upcase(&ignore_case) = Y %then %do;
      SRCVAL = upcase(strip(SRCVAL));
    %end;
    %else %do;
      SRCVAL = strip(SRCVAL);
    %end;
  run;

  proc sort data=_ct_map nodupkey;
    by SRCVAL;
  run;

  /* Sort input for merge */
  data _ct_in;
    set &inds;
    length _merge_key $200;
    %if %upcase(&ignore_case) = Y %then %do;
      _merge_key = upcase(strip(&src_var));
    %end;
    %else %do;
      _merge_key = strip(&src_var);
    %end;
    _orig_order = _N_;
  run;

  proc sort data=_ct_in;
    by _merge_key;
  run;

  /* Merge */
  data _ct_merged;
    merge _ct_in(in=a)
          _ct_map(rename=(SRCVAL=_merge_key STDVAL=&tgt_var) in=b);
    by _merge_key;
    if a;
    _mapped = b;
  run;

  /* Restore original order */
  proc sort data=_ct_merged;
    by _orig_order;
  run;

  data &outds;
    set _ct_merged;
    drop _merge_key _orig_order _mapped;
  run;

  /* Log unmapped values */
  %if %upcase(&log_unmap) = Y %then %do;
    data &unmap_ds;
      set _ct_merged;
      where not _mapped and not missing(_merge_key);
      keep &src_var _merge_key;
    run;

    %let _unmap_cnt = 0;
    proc sql noprint;
      select count(*) into :_unmap_cnt trimmed from &unmap_ds;
    quit;

    %if &_unmap_cnt > 0 %then %do;
      %put WARNING: [sdtm_map_ct] &_unmap_cnt records have unmapped values for codelist=&codelist. See &unmap_ds;
      proc freq data=&unmap_ds noprint;
        tables &src_var / out=_unmap_freq;
      run;
      proc print data=_unmap_freq noobs;
        title "Unmapped values for codelist=&codelist, variable=&src_var";
      run;
      title;
    %end;
    %else %do;
      %put NOTE: [sdtm_map_ct] All values mapped successfully for codelist=&codelist;
    %end;
  %end;

  /* Cleanup */
  proc datasets lib=work nolist;
    delete _ct_map _ct_in _ct_merged _unmap_freq;
  quit;

%mend sdtm_map_ct;
