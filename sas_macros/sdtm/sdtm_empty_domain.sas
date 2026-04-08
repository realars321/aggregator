/******************************************************************************
* Macro:    sdtm_empty_domain
* Purpose:  Create an empty SDTM domain dataset with correct variable
*           attributes (name, label, type, length) from a metadata spec.
*           Useful as a template to ensure the final domain has all required
*           variables in the correct order.
*
* Parameters:
*   outds    - Output empty template dataset
*   specds   - Metadata specification dataset with columns:
*                VARIABLE  - Variable name
*                LABEL     - Variable label
*                TYPE      - "Char" or "Num"
*                LENGTH    - Variable length
*                ORDER     - Sort order of variables
*   domain   - Domain abbreviation to filter specds (optional, if specds
*              contains multiple domains, filter by DOMAIN column)
*
* Example:
*   %sdtm_empty_domain(outds=work.ae_shell, specds=metadata.varspec, domain=AE);
******************************************************************************/

%macro sdtm_empty_domain(outds=, specds=, domain=);

  /* Filter spec to the target domain */
  proc sql noprint;
    %if %length(&domain) > 0 %then %do;
      select VARIABLE, LABEL, TYPE, LENGTH, ORDER
      into :var1-:var999, :lab1-:lab999, :typ1-:typ999, :len1-:len999, :ord1-:ord999
      from &specds
      where upcase(DOMAIN) = "%upcase(&domain)"
      order by ORDER;

      select count(*) into :nvar trimmed
      from &specds
      where upcase(DOMAIN) = "%upcase(&domain)";
    %end;
    %else %do;
      select VARIABLE, LABEL, TYPE, LENGTH, ORDER
      into :var1-:var999, :lab1-:lab999, :typ1-:typ999, :len1-:len999, :ord1-:ord999
      from &specds
      order by ORDER;

      select count(*) into :nvar trimmed
      from &specds;
    %end;
  quit;

  data &outds;
    /* Declare attributes via attrib in the specified order */
    %do i = 1 %to &nvar;
      %let _v = %qsysfunc(strip(&&var&i));
      %let _l = %qsysfunc(strip(&&lab&i));
      %let _t = %qsysfunc(strip(&&typ&i));
      %let _n = %qsysfunc(strip(&&len&i));

      %if %upcase(&_t) = CHAR %then %do;
        attrib &_v length=$&_n label="&_l";
      %end;
      %else %do;
        attrib &_v length=8 label="&_l";
      %end;
    %end;

    /* Stop with zero observations */
    stop;
    call missing(of _all_);
  run;

  %put NOTE: [sdtm_empty_domain] Empty domain shell created in &outds with &nvar variables.;

%mend sdtm_empty_domain;
