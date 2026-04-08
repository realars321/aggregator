/******************************************************************************
* Macro:    sdtm_make_usubjid
* Purpose:  Create USUBJID from STUDYID and SITEID/SUBJID components.
*           Standard concatenation: STUDYID-SITEID-SUBJID
*
* Parameters:
*   inds     - Input dataset
*   outds    - Output dataset
*   studyid  - Study ID variable or constant (default: STUDYID)
*   siteid   - Site ID variable (default: SITEID)
*   subjid   - Subject ID variable (default: SUBJID)
*   sep      - Separator (default: -)
*
* Example:
*   %sdtm_make_usubjid(inds=raw_dm, outds=dm1);
*   %sdtm_make_usubjid(inds=raw_dm, outds=dm1, studyid=PROTOCOL,
*                       siteid=SITE, subjid=PATNO, sep=-);
******************************************************************************/

%macro sdtm_make_usubjid(inds=, outds=, studyid=STUDYID, siteid=SITEID,
                         subjid=SUBJID, sep=-);

  data &outds;
    set &inds;
    length USUBJID $40;
    USUBJID = catx("&sep", strip(&studyid), strip(&siteid), strip(&subjid));
  run;

  %put NOTE: [sdtm_make_usubjid] USUBJID created in &outds;

%mend sdtm_make_usubjid;
