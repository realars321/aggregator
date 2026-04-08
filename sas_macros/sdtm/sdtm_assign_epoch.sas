/******************************************************************************
* Macro:    sdtm_assign_epoch
* Purpose:  Derive EPOCH variable based on reference start dates from the
*           SE (Subject Elements) domain or a user-provided epoch reference.
*           Assigns EPOCH for each record by comparing the record date
*           against epoch boundaries.
*
* Parameters:
*   inds       - Input dataset (must have USUBJID, RFSTDTC or a date var)
*   outds      - Output dataset with EPOCH assigned
*   epoch_ds   - Epoch reference dataset with columns:
*                  USUBJID, EPOCH, SESTDTC, SEENDTC
*                (typically derived from SE domain)
*   date_var   - Date variable to evaluate (ISO 8601 char, e.g. --DTC)
*
* Example:
*   %sdtm_assign_epoch(inds=ae2, outds=ae3, epoch_ds=se_ref,
*                      date_var=AESTDTC);
******************************************************************************/

%macro sdtm_assign_epoch(inds=, outds=, epoch_ds=, date_var=);

  /* Parse dates in epoch reference for comparison */
  data _epoch_ref;
    set &epoch_ds;
    length _se_st_c _se_en_c $10;
    /* Extract date portion (first 10 chars) for comparison */
    _se_st_c = substr(SESTDTC, 1, min(10, length(SESTDTC)));
    _se_en_c = substr(SEENDTC, 1, min(10, length(SEENDTC)));
    _se_st = input(_se_st_c, ?? yymmdd10.);
    _se_en = input(_se_en_c, ?? yymmdd10.);
    format _se_st _se_en date9.;
  run;

  proc sort data=_epoch_ref;
    by USUBJID _se_st;
  run;

  /* Parse date in input */
  data _in_parsed;
    set &inds;
    length _rec_dt_c $10;
    if length(&date_var) >= 10 then
      _rec_dt_c = substr(&date_var, 1, 10);
    else
      _rec_dt_c = &date_var;
    _rec_dt = input(_rec_dt_c, ?? yymmdd10.);
    format _rec_dt date9.;
    _orig_ord = _N_;
  run;

  /* Assign EPOCH via SQL range join */
  proc sql;
    create table _epoch_joined as
    select a.*, b.EPOCH
    from _in_parsed as a
    left join _epoch_ref as b
      on a.USUBJID = b.USUBJID
      and (a._rec_dt >= b._se_st or b._se_st is missing)
      and (a._rec_dt <= b._se_en or b._se_en is missing)
    order by a._orig_ord;
  quit;

  /* Handle potential duplicates from overlapping epochs - keep first match */
  proc sort data=_epoch_joined nodupkey;
    by _orig_ord;
  run;

  data &outds;
    set _epoch_joined;
    drop _rec_dt_c _rec_dt _orig_ord;
  run;

  /* Cleanup */
  proc datasets lib=work nolist;
    delete _epoch_ref _in_parsed _epoch_joined;
  quit;

  %put NOTE: [sdtm_assign_epoch] EPOCH assigned in &outds based on &date_var;

%mend sdtm_assign_epoch;
