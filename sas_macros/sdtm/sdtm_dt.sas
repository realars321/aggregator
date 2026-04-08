/******************************************************************************
* Macro:    sdtm_dt
* Purpose:  Convert character date/datetime strings to SDTM ISO 8601 format
*           (--DTC variables) and corresponding numeric dates (--DTN).
*           Handles partial dates (year-only, year-month, full date, datetime).
*
* Parameters:
*   inds     - Input dataset
*   outds    - Output dataset
*   raw_dt   - Source character date variable
*   dtc_var  - Target --DTC variable (ISO 8601 character)
*   dtn_var  - Target numeric date variable (optional, SAS date)
*   infmt    - Expected input format pattern:
*                YYYY       = year only
*                YYYYMM     = year-month
*                YYYYMMDD   = full date
*                DATETIME   = date + time
*                AUTO       = auto-detect (default)
*
* Example:
*   %sdtm_dt(inds=rawae, outds=ae1, raw_dt=AESTDAT,
*            dtc_var=AESTDTC, dtn_var=AESTDTN, infmt=AUTO);
******************************************************************************/

%macro sdtm_dt(inds=, outds=, raw_dt=, dtc_var=, dtn_var=, infmt=AUTO);

  data &outds;
    set &inds;
    length &dtc_var $19;

    _raw = strip(&raw_dt);

    if missing(_raw) then do;
      &dtc_var = '';
      %if %length(&dtn_var) > 0 %then %do;
        &dtn_var = .;
      %end;
    end;
    else do;

      %if %upcase(&infmt) = AUTO %then %do;

        /* Auto-detect based on length and content */
        _len = length(_raw);

        /* Try datetime patterns: 2024-01-15T10:30:00, 2024-01-15 10:30 etc. */
        if index(_raw, 'T') > 0 or index(_raw, ':') > 0 then do;
          /* Datetime - attempt full ISO parse */
          _dt_part = scan(_raw, 1, 'T ');
          _tm_part = scan(_raw, 2, 'T ');

          /* Parse date component */
          _yr  = input(scan(_dt_part, 1, '-/'), ?? best4.);
          _mon = input(scan(_dt_part, 2, '-/'), ?? best2.);
          _day = input(scan(_dt_part, 3, '-/'), ?? best2.);

          if not missing(_yr) and not missing(_mon) and not missing(_day) then do;
            &dtc_var = catx('-', put(_yr, z4.), put(_mon, z2.), put(_day, z2.))
                       || 'T' || strip(_tm_part);
            %if %length(&dtn_var) > 0 %then %do;
              &dtn_var = mdy(_mon, _day, _yr);
            %end;
          end;
        end;

        /* Full date: 2024-01-15, 15JAN2024, 01/15/2024, 20240115 */
        else if _len >= 8 then do;
          /* Try ddMONyyyy e.g. 15JAN2024 */
          _temp_dt = input(_raw, ?? date9.);
          if missing(_temp_dt) then
            _temp_dt = input(_raw, ?? date11.);
          if missing(_temp_dt) then
            _temp_dt = input(_raw, ?? yymmdd10.);
          if missing(_temp_dt) then
            _temp_dt = input(_raw, ?? mmddyy10.);
          if missing(_temp_dt) then
            _temp_dt = input(compress(_raw, '-/'), ?? yymmdd8.);

          if not missing(_temp_dt) then do;
            &dtc_var = put(_temp_dt, yymmdd10.);
            /* Replace '/' with '-' for ISO 8601 */
            &dtc_var = translate(&dtc_var, '-', '/');
            %if %length(&dtn_var) > 0 %then %do;
              &dtn_var = _temp_dt;
            %end;
          end;
          else do;
            /* Try parsing manually with separators */
            _yr  = input(scan(_raw, 1, '-/'), ?? best4.);
            _mon = input(scan(_raw, 2, '-/'), ?? best2.);
            _day = input(scan(_raw, 3, '-/'), ?? best2.);

            if not missing(_yr) and not missing(_mon) and not missing(_day) then do;
              &dtc_var = catx('-', put(_yr, z4.), put(_mon, z2.), put(_day, z2.));
              %if %length(&dtn_var) > 0 %then %do;
                &dtn_var = mdy(_mon, _day, _yr);
              %end;
            end;
          end;
        end;

        /* Year-month: 2024-01 */
        else if _len in (6, 7) then do;
          _yr  = input(scan(_raw, 1, '-/'), ?? best4.);
          _mon = input(scan(_raw, 2, '-/'), ?? best2.);
          if not missing(_yr) and not missing(_mon) then do;
            &dtc_var = catx('-', put(_yr, z4.), put(_mon, z2.));
            %if %length(&dtn_var) > 0 %then %do;
              &dtn_var = .;  /* Partial date - no numeric equivalent */
            %end;
          end;
        end;

        /* Year only: 2024 */
        else if _len = 4 then do;
          _yr = input(_raw, ?? best4.);
          if not missing(_yr) then do;
            &dtc_var = put(_yr, z4.);
            %if %length(&dtn_var) > 0 %then %do;
              &dtn_var = .;
            %end;
          end;
        end;

      %end; /* AUTO */

      %else %if %upcase(&infmt) = YYYY %then %do;
        _yr = input(_raw, ?? best4.);
        if not missing(_yr) then
          &dtc_var = put(_yr, z4.);
        %if %length(&dtn_var) > 0 %then %do;
          &dtn_var = .;
        %end;
      %end;

      %else %if %upcase(&infmt) = YYYYMM %then %do;
        _yr  = input(scan(_raw, 1, '-/'), ?? best4.);
        _mon = input(scan(_raw, 2, '-/'), ?? best2.);
        if not missing(_yr) and not missing(_mon) then
          &dtc_var = catx('-', put(_yr, z4.), put(_mon, z2.));
        %if %length(&dtn_var) > 0 %then %do;
          &dtn_var = .;
        %end;
      %end;

      %else %if %upcase(&infmt) = YYYYMMDD %then %do;
        _yr  = input(scan(_raw, 1, '-/'), ?? best4.);
        _mon = input(scan(_raw, 2, '-/'), ?? best2.);
        _day = input(scan(_raw, 3, '-/'), ?? best2.);
        if not missing(_yr) and not missing(_mon) and not missing(_day) then do;
          &dtc_var = catx('-', put(_yr, z4.), put(_mon, z2.), put(_day, z2.));
          %if %length(&dtn_var) > 0 %then %do;
            &dtn_var = mdy(_mon, _day, _yr);
          %end;
        end;
      %end;

      %else %if %upcase(&infmt) = DATETIME %then %do;
        _dt_part = scan(_raw, 1, 'T ');
        _tm_part = scan(_raw, 2, 'T ');
        _yr  = input(scan(_dt_part, 1, '-/'), ?? best4.);
        _mon = input(scan(_dt_part, 2, '-/'), ?? best2.);
        _day = input(scan(_dt_part, 3, '-/'), ?? best2.);
        if not missing(_yr) and not missing(_mon) and not missing(_day) then do;
          &dtc_var = catx('-', put(_yr, z4.), put(_mon, z2.), put(_day, z2.))
                     || 'T' || strip(_tm_part);
          %if %length(&dtn_var) > 0 %then %do;
            &dtn_var = mdy(_mon, _day, _yr);
          %end;
        end;
      %end;

    end;

    drop _raw _len _yr _mon _day _temp_dt _dt_part _tm_part;
  run;

%mend sdtm_dt;
