/******************************************************************************
* Program:  sdtm_macros_init.sas
* Purpose:  One-line include to load all SDTM utility macros.
*
* Usage:
*   %include "/path/to/sas_macros/sdtm/sdtm_macros_init.sas";
*
* Macros loaded:
*   %sdtm_make_usubjid  - Create USUBJID from components
*   %sdtm_dt            - Convert raw dates to ISO 8601 --DTC format
*   %sdtm_derive_dy     - Derive Study Day (--DY)
*   %sdtm_make_seq      - Generate --SEQ sequence numbers
*   %sdtm_assign_epoch  - Assign EPOCH based on SE domain
*   %sdtm_map_ct        - Map values to CDISC Controlled Terminology
*   %sdtm_merge_supp    - Merge SUPPxx back into parent domain
*   %sdtm_empty_domain  - Create empty domain shell from metadata spec
*   %sdtm_validate_domain - Basic domain validation checks
******************************************************************************/

%let _sdtm_macro_path = %sysfunc(tranwrd(%sysget(SAS_EXECFILEPATH),
                        %sysget(SAS_EXECFILENAME),));

%include "&_sdtm_macro_path.sdtm_make_usubjid.sas";
%include "&_sdtm_macro_path.sdtm_dt.sas";
%include "&_sdtm_macro_path.sdtm_derive_dy.sas";
%include "&_sdtm_macro_path.sdtm_make_seq.sas";
%include "&_sdtm_macro_path.sdtm_assign_epoch.sas";
%include "&_sdtm_macro_path.sdtm_map_ct.sas";
%include "&_sdtm_macro_path.sdtm_merge_supp.sas";
%include "&_sdtm_macro_path.sdtm_empty_domain.sas";
%include "&_sdtm_macro_path.sdtm_validate_domain.sas";

%put NOTE: [sdtm_macros_init] All SDTM macros loaded successfully.;
