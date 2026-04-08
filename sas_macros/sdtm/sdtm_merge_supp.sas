/******************************************************************************
* Macro:    sdtm_merge_supp
* Purpose:  Merge supplemental qualifier dataset (SUPPxx) back into the
*           parent SDTM domain. Transposes SUPP vertical structure to
*           horizontal columns and merges by STUDYID, RDOMAIN, USUBJID, IDVAR.
*
* Parameters:
*   parent_ds  - Parent domain dataset (e.g., sdtm.ae)
*   supp_ds    - Supplemental dataset (e.g., sdtm.suppae)
*   outds      - Output merged dataset
*   domain     - Domain abbreviation (e.g., AE)
*
* Example:
*   %sdtm_merge_supp(parent_ds=sdtm.ae, supp_ds=sdtm.suppae,
*                     outds=work.ae_merged, domain=AE);
******************************************************************************/

%macro sdtm_merge_supp(parent_ds=, supp_ds=, outds=, domain=);

  /* Step 1: Get distinct QNAM values from the SUPP dataset */
  proc sql noprint;
    select distinct QNAM into :qnam_list separated by ' '
    from &supp_ds
    where upcase(RDOMAIN) = "%upcase(&domain)";

    select count(distinct QNAM) into :qnam_cnt trimmed
    from &supp_ds
    where upcase(RDOMAIN) = "%upcase(&domain)";
  quit;

  %if &qnam_cnt = 0 %then %do;
    %put NOTE: [sdtm_merge_supp] No supplemental qualifiers found for domain=&domain. Copying parent as-is.;
    data &outds;
      set &parent_ds;
    run;
    %return;
  %end;

  /* Step 2: Determine IDVAR values to identify join keys */
  proc sql noprint;
    select distinct IDVAR into :idvar_list separated by '|'
    from &supp_ds
    where upcase(RDOMAIN) = "%upcase(&domain)" and not missing(IDVAR);
  quit;

  /* Step 3: Transpose SUPP - one column per QNAM */
  proc sort data=&supp_ds out=_supp_sorted;
    by STUDYID USUBJID IDVAR IDVARVAL QNAM;
    where upcase(RDOMAIN) = "%upcase(&domain)";
  run;

  proc transpose data=_supp_sorted out=_supp_t(drop=_NAME_) prefix=_;
    by STUDYID USUBJID IDVAR IDVARVAL;
    var QVAL;
    id QNAM;
  run;

  /* Step 4: Rename transposed variables (remove underscore prefix) */
  proc contents data=_supp_t out=_supp_vars(keep=NAME) noprint; run;

  proc sql noprint;
    select catx(' ', NAME, '=', substr(NAME, 2))
    into :rename_list separated by ' '
    from _supp_vars
    where NAME like '_%' and upcase(NAME) not in ('_NAME_', '_LABEL_')
          and substr(NAME, 2) in (
            select distinct QNAM from &supp_ds
            where upcase(RDOMAIN) = "%upcase(&domain)"
          );
  quit;

  %if %length(&rename_list) > 0 %then %do;
    data _supp_t;
      set _supp_t;
      rename &rename_list;
    run;
  %end;

  /* Step 5: Create a sequence number in parent for joining on IDVARVAL */
  data _parent;
    set &parent_ds;
    _seq_num = _N_;
    _seq_char = strip(put(_N_, best.));
  run;

  /* Step 6: Merge based on IDVAR logic */
  %if %length(&idvar_list) > 0 %then %do;
    /* Join using IDVAR/IDVARVAL */
    proc sql;
      create table &outds as
      select a.*,
        %do i = 1 %to &qnam_cnt;
          %let _qn = %scan(&qnam_list, &i, %str( ));
          b.&_qn
          %if &i < &qnam_cnt %then ,;
        %end;
      from _parent as a
      left join _supp_t as b
        on a.STUDYID = b.STUDYID
        and a.USUBJID = b.USUBJID
        and a._seq_char = b.IDVARVAL
      order by a._seq_num;
    quit;

    data &outds;
      set &outds;
      drop _seq_num _seq_char;
    run;
  %end;
  %else %do;
    /* No IDVAR - merge by STUDYID + USUBJID only */
    proc sql;
      create table &outds as
      select a.*,
        %do i = 1 %to &qnam_cnt;
          %let _qn = %scan(&qnam_list, &i, %str( ));
          b.&_qn
          %if &i < &qnam_cnt %then ,;
        %end;
      from _parent as a
      left join _supp_t as b
        on a.STUDYID = b.STUDYID
        and a.USUBJID = b.USUBJID
      order by a._seq_num;
    quit;

    data &outds;
      set &outds;
      drop _seq_num _seq_char;
    run;
  %end;

  /* Cleanup */
  proc datasets lib=work nolist;
    delete _supp_sorted _supp_t _supp_vars _parent;
  quit;

  %put NOTE: [sdtm_merge_supp] Merged &qnam_cnt supplemental qualifiers into &outds;

%mend sdtm_merge_supp;
