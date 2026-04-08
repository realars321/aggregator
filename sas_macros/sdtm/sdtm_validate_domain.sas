/******************************************************************************
* Macro:    sdtm_validate_domain
* Purpose:  Perform basic validation checks on a final SDTM domain dataset:
*           1. Required variables exist
*           2. No duplicate records per key variables
*           3. Missing value checks on required fields
*           4. ISO 8601 date format checks on --DTC variables
*           5. --SEQ uniqueness within subject
*           Outputs a validation report dataset and puts messages to log.
*
* Parameters:
*   inds       - Input SDTM domain dataset to validate
*   domain     - Domain abbreviation (e.g., AE, DM, LB)
*   key_vars   - Key variables for duplicate check (space-separated)
*                Default: STUDYID USUBJID &domain.SEQ
*   req_vars   - Required (non-missing) variables to check (space-separated)
*                Default: STUDYID DOMAIN USUBJID
*   report_ds  - Output validation report dataset (default: work._val_report)
*
* Example:
*   %sdtm_validate_domain(inds=sdtm.ae, domain=AE,
*     key_vars=STUDYID USUBJID AESEQ,
*     req_vars=STUDYID DOMAIN USUBJID AETERM AEDECOD AESTDTC);
******************************************************************************/

%macro sdtm_validate_domain(inds=, domain=, key_vars=, req_vars=,
                            report_ds=work._val_report);

  %let domain = %upcase(&domain);

  /* Set defaults */
  %if %length(&key_vars) = 0 %then
    %let key_vars = STUDYID USUBJID &domain.SEQ;
  %if %length(&req_vars) = 0 %then
    %let req_vars = STUDYID DOMAIN USUBJID;

  data &report_ds;
    length CHECK $60 DETAIL $200 STATUS $10 NOBS 8;
    stop;
  run;

  /* Check 1: Required variables exist */
  proc contents data=&inds out=_vcheck_vars(keep=NAME TYPE LENGTH) noprint; run;

  %let _all_check = &key_vars &req_vars;
  %let _i = 1;
  %let _v = %scan(&_all_check, &_i, %str( ));
  %do %while(%length(&_v) > 0);
    %let _found = 0;
    proc sql noprint;
      select count(*) into :_found trimmed
      from _vcheck_vars
      where upcase(NAME) = "%upcase(&_v)";
    quit;

    %if &_found = 0 %then %do;
      proc sql;
        insert into &report_ds
        values("Variable existence", "Variable &_v not found in &inds", "FAIL", 0);
      quit;
      %put ERROR: [sdtm_validate] Variable &_v not found in &inds;
    %end;
    %else %do;
      proc sql;
        insert into &report_ds
        values("Variable existence", "Variable &_v exists", "PASS", 0);
      quit;
    %end;

    %let _i = %eval(&_i + 1);
    %let _v = %scan(&_all_check, &_i, %str( ));
  %end;

  /* Check 2: Duplicate check by key variables */
  %let _dup_cnt = 0;
  proc sort data=&inds out=_vcheck_dup nodupkey dupout=_vcheck_dups;
    by &key_vars;
  run;

  proc sql noprint;
    select count(*) into :_dup_cnt trimmed from _vcheck_dups;
  quit;

  %if &_dup_cnt > 0 %then %do;
    proc sql;
      insert into &report_ds
      values("Duplicate check (&key_vars)", "&_dup_cnt duplicate records found", "FAIL", &_dup_cnt);
    quit;
    %put WARNING: [sdtm_validate] &_dup_cnt duplicate records by &key_vars in &inds;
  %end;
  %else %do;
    proc sql;
      insert into &report_ds
      values("Duplicate check (&key_vars)", "No duplicates found", "PASS", 0);
    quit;
  %end;

  /* Check 3: Missing values on required fields */
  %let _i = 1;
  %let _v = %scan(&req_vars, &_i, %str( ));
  %do %while(%length(&_v) > 0);
    %let _miss_cnt = 0;
    /* Check if variable exists first */
    %let _exists = 0;
    proc sql noprint;
      select count(*) into :_exists trimmed
      from _vcheck_vars where upcase(NAME) = "%upcase(&_v)";
    quit;

    %if &_exists > 0 %then %do;
      proc sql noprint;
        select count(*) into :_miss_cnt trimmed
        from &inds
        where missing(&_v);
      quit;

      %if &_miss_cnt > 0 %then %do;
        proc sql;
          insert into &report_ds
          values("Missing check: &_v", "&_miss_cnt records with missing &_v", "FAIL", &_miss_cnt);
        quit;
        %put WARNING: [sdtm_validate] &_miss_cnt records have missing &_v;
      %end;
      %else %do;
        proc sql;
          insert into &report_ds
          values("Missing check: &_v", "No missing values", "PASS", 0);
        quit;
      %end;
    %end;

    %let _i = %eval(&_i + 1);
    %let _v = %scan(&req_vars, &_i, %str( ));
  %end;

  /* Check 4: ISO 8601 format check on --DTC variables */
  proc sql noprint;
    select NAME into :dtc_vars separated by ' '
    from _vcheck_vars
    where upcase(NAME) like '%DTC';
  quit;

  %let _i = 1;
  %let _v = %scan(&dtc_vars, &_i, %str( ));
  %do %while(%length(&_v) > 0);
    %let _bad_dt = 0;
    proc sql noprint;
      select count(*) into :_bad_dt trimmed
      from &inds
      where not missing(&_v)
        and not prxmatch('/^\d{4}(-\d{2}(-\d{2}(T\d{2}:\d{2}(:\d{2})?)?)?)?$/', strip(&_v));
    quit;

    %if &_bad_dt > 0 %then %do;
      proc sql;
        insert into &report_ds
        values("ISO 8601 format: &_v", "&_bad_dt values not in ISO 8601 format", "FAIL", &_bad_dt);
      quit;
      %put WARNING: [sdtm_validate] &_bad_dt non-ISO 8601 values in &_v;
    %end;
    %else %do;
      proc sql;
        insert into &report_ds
        values("ISO 8601 format: &_v", "All values in ISO 8601 format", "PASS", 0);
      quit;
    %end;

    %let _i = %eval(&_i + 1);
    %let _v = %scan(&dtc_vars, &_i, %str( ));
  %end;

  /* Check 5: --SEQ uniqueness within USUBJID */
  %let _seq_var = &domain.SEQ;
  %let _seq_exists = 0;
  proc sql noprint;
    select count(*) into :_seq_exists trimmed
    from _vcheck_vars
    where upcase(NAME) = "%upcase(&_seq_var)";
  quit;

  %if &_seq_exists > 0 %then %do;
    %let _seq_dup = 0;
    proc sql noprint;
      select count(*) into :_seq_dup trimmed
      from (
        select USUBJID, &_seq_var, count(*) as cnt
        from &inds
        group by USUBJID, &_seq_var
        having cnt > 1
      );
    quit;

    %if &_seq_dup > 0 %then %do;
      proc sql;
        insert into &report_ds
        values("&_seq_var uniqueness", "&_seq_dup non-unique SEQ values within subject", "FAIL", &_seq_dup);
      quit;
      %put WARNING: [sdtm_validate] &_seq_dup non-unique &_seq_var values;
    %end;
    %else %do;
      proc sql;
        insert into &report_ds
        values("&_seq_var uniqueness", "All SEQ values unique within subject", "PASS", 0);
      quit;
    %end;
  %end;

  /* Print report */
  title "SDTM Validation Report: &domain (&inds)";
  proc print data=&report_ds noobs;
    var CHECK DETAIL STATUS NOBS;
  run;
  title;

  /* Summary counts */
  %let _fail_cnt = 0;
  proc sql noprint;
    select count(*) into :_fail_cnt trimmed
    from &report_ds where STATUS = 'FAIL';
  quit;

  %if &_fail_cnt > 0 %then %do;
    %put WARNING: [sdtm_validate] &_fail_cnt validation checks FAILED for &domain;
  %end;
  %else %do;
    %put NOTE: [sdtm_validate] All validation checks PASSED for &domain;
  %end;

  /* Cleanup */
  proc datasets lib=work nolist;
    delete _vcheck_vars _vcheck_dup _vcheck_dups;
  quit;

%mend sdtm_validate_domain;
