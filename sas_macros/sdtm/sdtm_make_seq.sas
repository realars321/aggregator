/******************************************************************************
* Macro:    sdtm_make_seq
* Purpose:  Generate --SEQ variable for any SDTM domain.
*           Creates a unique sequence number per subject within a domain.
*
* Parameters:
*   inds     - Input dataset
*   outds    - Output dataset
*   domain   - Domain abbreviation (e.g., AE, CM, LB)
*   sortby   - Variables to sort by within subject before assigning SEQ
*              (default: _ALL_ which preserves current order)
*
* Example:
*   %sdtm_make_seq(inds=ae1, outds=ae2, domain=AE, sortby=AESTDTC AETERM);
******************************************************************************/

%macro sdtm_make_seq(inds=, outds=, domain=, sortby=_ALL_);

  %let domain = %upcase(&domain);
  %let seq_var = &domain.SEQ;

  %if %upcase(&sortby) ne _ALL_ %then %do;
    proc sort data=&inds out=_seq_tmp;
      by USUBJID &sortby;
    run;
  %end;
  %else %do;
    data _seq_tmp;
      set &inds;
    run;
  %end;

  data &outds;
    set _seq_tmp;
    by USUBJID;
    if first.USUBJID then &seq_var = 0;
    &seq_var + 1;
  run;

  proc datasets lib=work nolist;
    delete _seq_tmp;
  quit;

  %put NOTE: [sdtm_make_seq] &seq_var assigned in &outds;

%mend sdtm_make_seq;
