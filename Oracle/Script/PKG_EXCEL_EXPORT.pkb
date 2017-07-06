CREATE OR REPLACE PACKAGE BODY       PKG_EXCEL_EXPORT
IS
--
  C_LOCAL_FILE_HEADER        CONSTANT RAW(4) := HEXTORAW( '504B0304' ); -- Local file header signature
  C_END_OF_CENTRAL_DIRECTORY CONSTANT RAW(4) := HEXTORAW( '504B0506' ); -- End of central directory signature
--
  TYPE TP_XF_FMT IS RECORD
    ( NUMFMTID PLS_INTEGER
    , FONTID PLS_INTEGER
    , FILLID PLS_INTEGER
    , BORDERID PLS_INTEGER
    , ALIGNMENT TP_ALIGNMENT
    );
  TYPE TP_COL_FMTS IS TABLE OF TP_XF_FMT INDEX BY PLS_INTEGER;
  TYPE TP_ROW_FMTS IS TABLE OF TP_XF_FMT INDEX BY PLS_INTEGER;
  TYPE TP_WIDTHS IS TABLE OF NUMBER INDEX BY PLS_INTEGER;
  TYPE TP_CELL IS RECORD
    ( VALUE NUMBER
    , STYLE VARCHAR2(50)
    );
  TYPE TP_CELLS IS TABLE OF TP_CELL INDEX BY PLS_INTEGER;
  TYPE TP_ROWS IS TABLE OF TP_CELLS INDEX BY PLS_INTEGER;
  TYPE TP_AUTOFILTER IS RECORD
    ( COLUMN_START PLS_INTEGER
    , COLUMN_END PLS_INTEGER
    , ROW_START PLS_INTEGER
    , ROW_END PLS_INTEGER
    );
  TYPE TP_AUTOFILTERS IS TABLE OF TP_AUTOFILTER INDEX BY PLS_INTEGER;
  TYPE TP_HYPERLINK IS RECORD
    ( CELL VARCHAR2(10)
    , URL  VARCHAR2(1000)
    );
  TYPE TP_HYPERLINKS IS TABLE OF TP_HYPERLINK INDEX BY PLS_INTEGER;
  SUBTYPE TP_AUTHOR IS VARCHAR2(32767 CHAR);
  TYPE TP_AUTHORS IS TABLE OF PLS_INTEGER INDEX BY TP_AUTHOR;
  AUTHORS TP_AUTHORS;
  TYPE TP_COMMENT IS RECORD
    ( TEXT VARCHAR2(32767 CHAR)
    , AUTHOR TP_AUTHOR
    , ROW PLS_INTEGER
    , COLUMN PLS_INTEGER
    , WIDTH PLS_INTEGER
    , HEIGHT PLS_INTEGER
    );
  TYPE TP_COMMENTS IS TABLE OF TP_COMMENT INDEX BY PLS_INTEGER;
  TYPE TP_MERGECELLS IS TABLE OF VARCHAR2(21) INDEX BY PLS_INTEGER;
  TYPE TP_VALIDATION IS RECORD
    ( TYPE VARCHAR2(10)
    , ERRORSTYLE VARCHAR2(32)
    , SHOWINPUTMESSAGE BOOLEAN
    , PROMPT VARCHAR2(32767 CHAR)
    , TITLE VARCHAR2(32767 CHAR)
    , ERROR_TITLE VARCHAR2(32767 CHAR)
    , ERROR_TXT VARCHAR2(32767 CHAR)
    , SHOWERRORMESSAGE BOOLEAN
    , FORMULA1 VARCHAR2(32767 CHAR)
    , FORMULA2 VARCHAR2(32767 CHAR)
    , ALLOWBLANK BOOLEAN
    , SQREF VARCHAR2(32767 CHAR)
    );
  TYPE TP_VALIDATIONS IS TABLE OF TP_VALIDATION INDEX BY PLS_INTEGER;
  TYPE TP_SHEET IS RECORD
    ( ROWS TP_ROWS
    , WIDTHS TP_WIDTHS
    , NAME VARCHAR2(100)
    , FREEZE_ROWS PLS_INTEGER
    , FREEZE_COLS PLS_INTEGER
    , AUTOFILTERS TP_AUTOFILTERS
    , HYPERLINKS TP_HYPERLINKS
    , COL_FMTS TP_COL_FMTS
    , ROW_FMTS TP_ROW_FMTS
    , COMMENTS TP_COMMENTS
    , MERGECELLS TP_MERGECELLS
    , VALIDATIONS TP_VALIDATIONS
    );
  TYPE TP_SHEETS IS TABLE OF TP_SHEET INDEX BY PLS_INTEGER;
  TYPE TP_NUMFMT IS RECORD
    ( NUMFMTID PLS_INTEGER
    , FORMATCODE VARCHAR2(100)
    );
  TYPE TP_NUMFMTS IS TABLE OF TP_NUMFMT INDEX BY PLS_INTEGER;
  TYPE TP_FILL IS RECORD
    ( PATTERNTYPE VARCHAR2(30)
    , FGRGB VARCHAR2(8)
    );
  TYPE TP_FILLS IS TABLE OF TP_FILL INDEX BY PLS_INTEGER;
  TYPE TP_CELLXFS IS TABLE OF TP_XF_FMT INDEX BY PLS_INTEGER;
  TYPE TP_FONT IS RECORD
    ( NAME VARCHAR2(100)
    , FAMILY PLS_INTEGER
    , FONTSIZE NUMBER
    , THEME PLS_INTEGER
    , RGB VARCHAR2(8)
    , UNDERLINE BOOLEAN
    , ITALIC BOOLEAN
    , BOLD BOOLEAN
    );
  TYPE TP_FONTS IS TABLE OF TP_FONT INDEX BY PLS_INTEGER;
  TYPE TP_BORDER IS RECORD
    ( TOP VARCHAR2(17)
    , BOTTOM VARCHAR2(17)
    , LEFT VARCHAR2(17)
    , RIGHT VARCHAR2(17)
    );
  TYPE TP_BORDERS IS TABLE OF TP_BORDER INDEX BY PLS_INTEGER;
  TYPE TP_NUMFMTINDEXES IS TABLE OF PLS_INTEGER INDEX BY PLS_INTEGER;
  TYPE TP_STRINGS IS TABLE OF PLS_INTEGER INDEX BY VARCHAR2(32767 CHAR);
  TYPE TP_STR_IND IS TABLE OF VARCHAR2(32767 CHAR) INDEX BY PLS_INTEGER;
  TYPE TP_DEFINED_NAME IS RECORD
    ( NAME VARCHAR2(32767 CHAR)
    , REF VARCHAR2(32767 CHAR)
    , SHEET PLS_INTEGER
    );
  TYPE TP_DEFINED_NAMES IS TABLE OF TP_DEFINED_NAME INDEX BY PLS_INTEGER;
  TYPE TP_BOOK IS RECORD
    ( SHEETS TP_SHEETS
    , STRINGS TP_STRINGS
    , STR_IND TP_STR_IND
    , STR_CNT PLS_INTEGER := 0
    , FONTS TP_FONTS
    , FILLS TP_FILLS
    , BORDERS TP_BORDERS
    , NUMFMTS TP_NUMFMTS
    , CELLXFS TP_CELLXFS
    , NUMFMTINDEXES TP_NUMFMTINDEXES
    , DEFINED_NAMES TP_DEFINED_NAMES
    );
  WORKBOOK TP_BOOK;
--
  PROCEDURE BLOB2FILE
    ( P_BLOB BLOB
    , P_DIRECTORY VARCHAR2 := 'MY_DIR'
    , P_FILENAME VARCHAR2 := 'my.xlsx'
    )
  IS
    T_FH UTL_FILE.FILE_TYPE;
    T_LEN PLS_INTEGER := 32767;
  BEGIN
    T_FH := UTL_FILE.FOPEN( P_DIRECTORY
                          , P_FILENAME
                          , 'wb'
                          );
    FOR I IN 0 .. TRUNC( ( DBMS_LOB.GETLENGTH( P_BLOB ) - 1 ) / T_LEN )
    LOOP
      UTL_FILE.PUT_RAW( T_FH
                      , DBMS_LOB.SUBSTR( P_BLOB
                                       , T_LEN
                                       , I * T_LEN + 1
                                       )
                      );
    END LOOP;
    UTL_FILE.FCLOSE( T_FH );
  END;
--
  FUNCTION RAW2NUM( P_RAW RAW, P_LEN INTEGER, P_POS INTEGER )
  RETURN NUMBER
  IS
  BEGIN
    RETURN UTL_RAW.CAST_TO_BINARY_INTEGER( UTL_RAW.SUBSTR( P_RAW, P_POS, P_LEN ), UTL_RAW.LITTLE_ENDIAN );
  END;
--
  FUNCTION LITTLE_ENDIAN( P_BIG NUMBER, P_BYTES PLS_INTEGER := 4 )
  RETURN RAW
  IS
  BEGIN
    RETURN UTL_RAW.SUBSTR( UTL_RAW.CAST_FROM_BINARY_INTEGER( P_BIG, UTL_RAW.LITTLE_ENDIAN ), 1, P_BYTES );
  END;
--
  FUNCTION BLOB2NUM( P_BLOB BLOB, P_LEN INTEGER, P_POS INTEGER )
  RETURN NUMBER
  IS
  BEGIN
    RETURN UTL_RAW.CAST_TO_BINARY_INTEGER( DBMS_LOB.SUBSTR( P_BLOB, P_LEN, P_POS ), UTL_RAW.LITTLE_ENDIAN );
  END;
--
  PROCEDURE ADD1FILE
    ( P_ZIPPED_BLOB IN OUT BLOB
    , P_NAME VARCHAR2
    , P_CONTENT BLOB
    )
  IS
    T_NOW DATE;
    T_BLOB BLOB;
    T_LEN INTEGER;
    T_CLEN INTEGER;
    T_CRC32 RAW(4) := HEXTORAW( '00000000' );
    T_COMPRESSED BOOLEAN := FALSE;
    T_NAME RAW(32767);
  BEGIN
    T_NOW := SYSDATE;
    T_LEN := NVL( DBMS_LOB.GETLENGTH( P_CONTENT ), 0 );
    IF T_LEN > 0
    THEN 
      T_BLOB := UTL_COMPRESS.LZ_COMPRESS( P_CONTENT );
      T_CLEN := DBMS_LOB.GETLENGTH( T_BLOB ) - 18;
      T_COMPRESSED := T_CLEN < T_LEN;
      T_CRC32 := DBMS_LOB.SUBSTR( T_BLOB, 4, T_CLEN + 11 );       
    END IF;
    IF NOT T_COMPRESSED
    THEN 
      T_CLEN := T_LEN;
      T_BLOB := P_CONTENT;
    END IF;
    IF P_ZIPPED_BLOB IS NULL
    THEN
      DBMS_LOB.CREATETEMPORARY( P_ZIPPED_BLOB, TRUE );
    END IF;
    T_NAME := UTL_I18N.STRING_TO_RAW( P_NAME, 'AL32UTF8' );
    DBMS_LOB.APPEND( P_ZIPPED_BLOB
                   , UTL_RAW.CONCAT( C_LOCAL_FILE_HEADER -- Local file header signature
                                   , HEXTORAW( '1400' )  -- version 2.0
                                   , CASE WHEN T_NAME = UTL_I18N.STRING_TO_RAW( P_NAME, 'US8PC437' )
                                       THEN HEXTORAW( '0000' ) -- no General purpose bits
                                       ELSE HEXTORAW( '0008' ) -- set Language encoding flag (EFS)
                                     END 
                                   , CASE WHEN T_COMPRESSED
                                        THEN HEXTORAW( '0800' ) -- deflate
                                        ELSE HEXTORAW( '0000' ) -- stored
                                     END
                                   , LITTLE_ENDIAN( TO_NUMBER( TO_CHAR( T_NOW, 'ss' ) ) / 2
                                                  + TO_NUMBER( TO_CHAR( T_NOW, 'mi' ) ) * 32
                                                  + TO_NUMBER( TO_CHAR( T_NOW, 'hh24' ) ) * 2048
                                                  , 2
                                                  ) -- File last modification time
                                   , LITTLE_ENDIAN( TO_NUMBER( TO_CHAR( T_NOW, 'dd' ) )
                                                  + TO_NUMBER( TO_CHAR( T_NOW, 'mm' ) ) * 32
                                                  + ( TO_NUMBER( TO_CHAR( T_NOW, 'yyyy' ) ) - 1980 ) * 512
                                                  , 2
                                                  ) -- File last modification date
                                   , T_CRC32 -- CRC-32
                                   , LITTLE_ENDIAN( T_CLEN )                      -- compressed size
                                   , LITTLE_ENDIAN( T_LEN )                       -- uncompressed size
                                   , LITTLE_ENDIAN( UTL_RAW.LENGTH( T_NAME ), 2 ) -- File name length
                                   , HEXTORAW( '0000' )                           -- Extra field length
                                   , T_NAME                                       -- File name
                                   )
                   );
    IF T_COMPRESSED
    THEN                   
      DBMS_LOB.COPY( P_ZIPPED_BLOB, T_BLOB, T_CLEN, DBMS_LOB.GETLENGTH( P_ZIPPED_BLOB ) + 1, 11 ); -- compressed content
    ELSIF T_CLEN > 0
    THEN                   
      DBMS_LOB.COPY( P_ZIPPED_BLOB, T_BLOB, T_CLEN, DBMS_LOB.GETLENGTH( P_ZIPPED_BLOB ) + 1, 1 ); --  content
    END IF;
    IF DBMS_LOB.ISTEMPORARY( T_BLOB ) = 1
    THEN      
      DBMS_LOB.FREETEMPORARY( T_BLOB );
    END IF;
  END;
--
  PROCEDURE FINISH_ZIP( P_ZIPPED_BLOB IN OUT BLOB )
  IS
    T_CNT PLS_INTEGER := 0;
    T_OFFS INTEGER;
    T_OFFS_DIR_HEADER INTEGER;
    T_OFFS_END_HEADER INTEGER;
    T_COMMENT RAW(32767) := UTL_RAW.CAST_TO_RAW( 'Implementation by Anton Scheffer' );
  BEGIN
    T_OFFS_DIR_HEADER := DBMS_LOB.GETLENGTH( P_ZIPPED_BLOB );
    T_OFFS := 1;
    WHILE DBMS_LOB.SUBSTR( P_ZIPPED_BLOB, UTL_RAW.LENGTH( C_LOCAL_FILE_HEADER ), T_OFFS ) = C_LOCAL_FILE_HEADER
    LOOP
      T_CNT := T_CNT + 1;
      DBMS_LOB.APPEND( P_ZIPPED_BLOB
                     , UTL_RAW.CONCAT( HEXTORAW( '504B0102' )      -- Central directory file header signature
                                     , HEXTORAW( '1400' )          -- version 2.0
                                     , DBMS_LOB.SUBSTR( P_ZIPPED_BLOB, 26, T_OFFS + 4 )
                                     , HEXTORAW( '0000' )          -- File comment length
                                     , HEXTORAW( '0000' )          -- Disk number where file starts
                                     , HEXTORAW( '0000' )          -- Internal file attributes => 
                                                                   --     0000 binary file
                                                                   --     0100 (ascii)text file
                                     , CASE
                                         WHEN DBMS_LOB.SUBSTR( P_ZIPPED_BLOB
                                                             , 1
                                                             , T_OFFS + 30 + BLOB2NUM( P_ZIPPED_BLOB, 2, T_OFFS + 26 ) - 1
                                                             ) IN ( HEXTORAW( '2F' ) -- /
                                                                  , HEXTORAW( '5C' ) -- \
                                                                  )
                                         THEN HEXTORAW( '10000000' ) -- a directory/folder
                                         ELSE HEXTORAW( '2000B681' ) -- a file
                                       END                         -- External file attributes
                                     , LITTLE_ENDIAN( T_OFFS - 1 ) -- Relative offset of local file header
                                     , DBMS_LOB.SUBSTR( P_ZIPPED_BLOB
                                                      , BLOB2NUM( P_ZIPPED_BLOB, 2, T_OFFS + 26 )
                                                      , T_OFFS + 30
                                                      )            -- File name
                                     )
                     );
      T_OFFS := T_OFFS + 30 + BLOB2NUM( P_ZIPPED_BLOB, 4, T_OFFS + 18 )  -- compressed size
                            + BLOB2NUM( P_ZIPPED_BLOB, 2, T_OFFS + 26 )  -- File name length 
                            + BLOB2NUM( P_ZIPPED_BLOB, 2, T_OFFS + 28 ); -- Extra field length
    END LOOP;
    T_OFFS_END_HEADER := DBMS_LOB.GETLENGTH( P_ZIPPED_BLOB );
    DBMS_LOB.APPEND( P_ZIPPED_BLOB
                   , UTL_RAW.CONCAT( C_END_OF_CENTRAL_DIRECTORY                                -- End of central directory signature
                                   , HEXTORAW( '0000' )                                        -- Number of this disk
                                   , HEXTORAW( '0000' )                                        -- Disk where central directory starts
                                   , LITTLE_ENDIAN( T_CNT, 2 )                                 -- Number of central directory records on this disk
                                   , LITTLE_ENDIAN( T_CNT, 2 )                                 -- Total number of central directory records
                                   , LITTLE_ENDIAN( T_OFFS_END_HEADER - T_OFFS_DIR_HEADER )    -- Size of central directory
                                   , LITTLE_ENDIAN( T_OFFS_DIR_HEADER )                        -- Offset of start of central directory, relative to start of archive
                                   , LITTLE_ENDIAN( NVL( UTL_RAW.LENGTH( T_COMMENT ), 0 ), 2 ) -- ZIP file comment length
                                   , T_COMMENT
                                   )
                   );
  END;
--
  FUNCTION ALFAN_COL( P_COL PLS_INTEGER )
  RETURN VARCHAR2
  IS
  BEGIN
    RETURN CASE
             WHEN P_COL > 702 THEN CHR( 64 + TRUNC( ( P_COL - 27 ) / 676 ) ) || CHR( 65 + MOD( TRUNC( ( P_COL - 1 ) / 26 ) - 1, 26 ) ) || CHR( 65 + MOD( P_COL - 1, 26 ) )
             WHEN P_COL > 26  THEN CHR( 64 + TRUNC( ( P_COL - 1 ) / 26 ) ) || CHR( 65 + MOD( P_COL - 1, 26 ) )
             ELSE CHR( 64 + P_COL )
           END;
  END;
--
  FUNCTION COL_ALFAN( P_COL VARCHAR2 )
  RETURN PLS_INTEGER
  IS
  BEGIN
    RETURN ASCII( SUBSTR( P_COL, -1 ) ) - 64
         + NVL( ( ASCII( SUBSTR( P_COL, -2, 1 ) ) - 64 ) * 26, 0 )
         + NVL( ( ASCII( SUBSTR( P_COL, -3, 1 ) ) - 64 ) * 676, 0 );
  END;
--
  PROCEDURE CLEAR_WORKBOOK
  IS
    T_ROW_IND PLS_INTEGER;
  BEGIN
    FOR S IN 1 .. WORKBOOK.SHEETS.COUNT()
    LOOP
      T_ROW_IND := WORKBOOK.SHEETS( S ).ROWS.FIRST();
      WHILE T_ROW_IND IS NOT NULL
      LOOP
        WORKBOOK.SHEETS( S ).ROWS( T_ROW_IND ).DELETE();
        T_ROW_IND := WORKBOOK.SHEETS( S ).ROWS.NEXT( T_ROW_IND );
      END LOOP;
      WORKBOOK.SHEETS( S ).ROWS.DELETE();
      WORKBOOK.SHEETS( S ).WIDTHS.DELETE();
      WORKBOOK.SHEETS( S ).AUTOFILTERS.DELETE();
      WORKBOOK.SHEETS( S ).HYPERLINKS.DELETE();
      WORKBOOK.SHEETS( S ).COL_FMTS.DELETE();
      WORKBOOK.SHEETS( S ).ROW_FMTS.DELETE();
      WORKBOOK.SHEETS( S ).COMMENTS.DELETE();
      WORKBOOK.SHEETS( S ).MERGECELLS.DELETE();
      WORKBOOK.SHEETS( S ).VALIDATIONS.DELETE();
    END LOOP;
    WORKBOOK.STRINGS.DELETE();
    WORKBOOK.STR_IND.DELETE();
    WORKBOOK.FONTS.DELETE();
    WORKBOOK.FILLS.DELETE();
    WORKBOOK.BORDERS.DELETE();
    WORKBOOK.NUMFMTS.DELETE();
    WORKBOOK.CELLXFS.DELETE();
    WORKBOOK.DEFINED_NAMES.DELETE();
    WORKBOOK := NULL;
  END;
--
  PROCEDURE NEW_SHEET( P_SHEETNAME VARCHAR2 := NULL )
  IS
    T_NR PLS_INTEGER := WORKBOOK.SHEETS.COUNT() + 1;
    T_IND PLS_INTEGER;
  BEGIN
    WORKBOOK.SHEETS( T_NR ).NAME := NVL( DBMS_XMLGEN.CONVERT( TRANSLATE( P_SHEETNAME, 'a/\[]*:?', 'a' ) ), 'Sheet' || T_NR );
    IF WORKBOOK.STRINGS.COUNT() = 0
    THEN
     WORKBOOK.STR_CNT := 0;
    END IF;
    IF WORKBOOK.FONTS.COUNT() = 0
    THEN
      T_IND := GET_FONT( 'Calibri' );
    END IF;
    IF WORKBOOK.FILLS.COUNT() = 0
    THEN
      T_IND := GET_FILL( 'none' );
      T_IND := GET_FILL( 'gray125' );
    END IF;
    IF WORKBOOK.BORDERS.COUNT() = 0
    THEN
      T_IND := GET_BORDER( '', '', '', '' );
    END IF;
  END;
--
  PROCEDURE SET_COL_WIDTH
    ( P_SHEET PLS_INTEGER
    , P_COL PLS_INTEGER
    , P_FORMAT VARCHAR2
    )
  IS
    T_WIDTH NUMBER;
    T_NR_CHR PLS_INTEGER;
  BEGIN
    IF P_FORMAT IS NULL
    THEN
      RETURN;
    END IF;
    IF INSTR( P_FORMAT, ';' ) > 0
    THEN
      T_NR_CHR := LENGTH( TRANSLATE( SUBSTR( P_FORMAT, 1, INSTR( P_FORMAT, ';' ) - 1 ), 'a\"', 'a' ) );
    ELSE
      T_NR_CHR := LENGTH( TRANSLATE( P_FORMAT, 'a\"', 'a' ) );
    END IF;
    T_WIDTH := TRUNC( ( T_NR_CHR * 7 + 5 ) / 7 * 256 ) / 256; -- assume default 11 point Calibri
    IF WORKBOOK.SHEETS( P_SHEET ).WIDTHS.EXISTS( P_COL )
    THEN
      WORKBOOK.SHEETS( P_SHEET ).WIDTHS( P_COL ) :=
        GREATEST( WORKBOOK.SHEETS( P_SHEET ).WIDTHS( P_COL )
                , T_WIDTH
                );
    ELSE
      WORKBOOK.SHEETS( P_SHEET ).WIDTHS( P_COL ) := GREATEST( T_WIDTH, 8.43 );
    END IF;
  END;
--
  FUNCTION ORAFMT2EXCEL( P_FORMAT VARCHAR2 := NULL )
  RETURN VARCHAR2
  IS
    T_FORMAT VARCHAR2(1000) := SUBSTR( P_FORMAT, 1, 1000 );
  BEGIN
    T_FORMAT := REPLACE( REPLACE( T_FORMAT, 'hh24', 'hh' ), 'hh12', 'hh' );
    T_FORMAT := REPLACE( T_FORMAT, 'mi', 'mm' );
    T_FORMAT := REPLACE( REPLACE( REPLACE( T_FORMAT, 'AM', '~~' ), 'PM', '~~' ), '~~', 'AM/PM' );
    T_FORMAT := REPLACE( REPLACE( REPLACE( T_FORMAT, 'am', '~~' ), 'pm', '~~' ), '~~', 'AM/PM' );
    T_FORMAT := REPLACE( REPLACE( T_FORMAT, 'day', 'DAY' ), 'DAY', 'dddd' );
    T_FORMAT := REPLACE( REPLACE( T_FORMAT, 'dy', 'DY' ), 'DAY', 'ddd' );
    T_FORMAT := REPLACE( REPLACE( T_FORMAT, 'RR', 'RR' ), 'RR', 'YY' );
    T_FORMAT := REPLACE( REPLACE( T_FORMAT, 'month', 'MONTH' ), 'MONTH', 'mmmm' );
    T_FORMAT := REPLACE( REPLACE( T_FORMAT, 'mon', 'MON' ), 'MON', 'mmm' );
    RETURN T_FORMAT;
  END;
--
  FUNCTION GET_NUMFMT( P_FORMAT VARCHAR2 := NULL )
  RETURN PLS_INTEGER
  IS
    T_CNT PLS_INTEGER;
    T_NUMFMTID PLS_INTEGER;
  BEGIN
    IF P_FORMAT IS NULL
    THEN
      RETURN 0;
    END IF;
    T_CNT := WORKBOOK.NUMFMTS.COUNT();
    FOR I IN 1 .. T_CNT
    LOOP
      IF WORKBOOK.NUMFMTS( I ).FORMATCODE = P_FORMAT
      THEN
        T_NUMFMTID := WORKBOOK.NUMFMTS( I ).NUMFMTID;
        EXIT;
      END IF;
    END LOOP;
    IF T_NUMFMTID IS NULL
    THEN
      T_NUMFMTID := CASE WHEN T_CNT = 0 THEN 164 ELSE WORKBOOK.NUMFMTS( T_CNT ).NUMFMTID + 1 END;
      T_CNT := T_CNT + 1;
      WORKBOOK.NUMFMTS( T_CNT ).NUMFMTID := T_NUMFMTID;
      WORKBOOK.NUMFMTS( T_CNT ).FORMATCODE := P_FORMAT;
      WORKBOOK.NUMFMTINDEXES( T_NUMFMTID ) := T_CNT;
    END IF;
    RETURN T_NUMFMTID;
  END;
--
  FUNCTION GET_FONT
    ( P_NAME VARCHAR2
    , P_FAMILY PLS_INTEGER := 2
    , P_FONTSIZE NUMBER := 11
    , P_THEME PLS_INTEGER := 1
    , P_UNDERLINE BOOLEAN := FALSE
    , P_ITALIC BOOLEAN := FALSE
    , P_BOLD BOOLEAN := FALSE
    , P_RGB VARCHAR2 := NULL -- this is a hex ALPHA Red Green Blue value
    )
  RETURN PLS_INTEGER
  IS
    T_IND PLS_INTEGER;
  BEGIN
    IF WORKBOOK.FONTS.COUNT() > 0
    THEN
      FOR F IN 0 .. WORKBOOK.FONTS.COUNT() - 1
      LOOP
        IF (   WORKBOOK.FONTS( F ).NAME = P_NAME
           AND WORKBOOK.FONTS( F ).FAMILY = P_FAMILY
           AND WORKBOOK.FONTS( F ).FONTSIZE = P_FONTSIZE
           AND WORKBOOK.FONTS( F ).THEME = P_THEME
           AND WORKBOOK.FONTS( F ).UNDERLINE = P_UNDERLINE
           AND WORKBOOK.FONTS( F ).ITALIC = P_ITALIC
           AND WORKBOOK.FONTS( F ).BOLD = P_BOLD
           AND ( WORKBOOK.FONTS( F ).RGB = P_RGB
               OR ( WORKBOOK.FONTS( F ).RGB IS NULL AND P_RGB IS NULL )
               )
           )
        THEN
          RETURN F;
        END IF;
      END LOOP;
    END IF;
    T_IND := WORKBOOK.FONTS.COUNT();
    WORKBOOK.FONTS( T_IND ).NAME := P_NAME;
    WORKBOOK.FONTS( T_IND ).FAMILY := P_FAMILY;
    WORKBOOK.FONTS( T_IND ).FONTSIZE := P_FONTSIZE;
    WORKBOOK.FONTS( T_IND ).THEME := P_THEME;
    WORKBOOK.FONTS( T_IND ).UNDERLINE := P_UNDERLINE;
    WORKBOOK.FONTS( T_IND ).ITALIC := P_ITALIC;
    WORKBOOK.FONTS( T_IND ).BOLD := P_BOLD;
    WORKBOOK.FONTS( T_IND ).RGB := P_RGB;
    RETURN T_IND;
  END;
--
  FUNCTION GET_FILL
    ( P_PATTERNTYPE VARCHAR2
    , P_FGRGB VARCHAR2 := NULL
    )
  RETURN PLS_INTEGER
  IS
    T_IND PLS_INTEGER;
  BEGIN
    IF WORKBOOK.FILLS.COUNT() > 0
    THEN
      FOR F IN 0 .. WORKBOOK.FILLS.COUNT() - 1
      LOOP
        IF (   WORKBOOK.FILLS( F ).PATTERNTYPE = P_PATTERNTYPE
           AND NVL( WORKBOOK.FILLS( F ).FGRGB, 'x' ) = NVL( UPPER( P_FGRGB ), 'x' )
           )
        THEN
          RETURN F;
        END IF;
      END LOOP;
    END IF;
    T_IND := WORKBOOK.FILLS.COUNT();
    WORKBOOK.FILLS( T_IND ).PATTERNTYPE := P_PATTERNTYPE;
    WORKBOOK.FILLS( T_IND ).FGRGB := UPPER( P_FGRGB );
    RETURN T_IND;
  END;
--
  FUNCTION GET_BORDER
    ( P_TOP VARCHAR2 := 'thin'
    , P_BOTTOM VARCHAR2 := 'thin'
    , P_LEFT VARCHAR2 := 'thin'
    , P_RIGHT VARCHAR2 := 'thin'
    )
  RETURN PLS_INTEGER
  IS
    T_IND PLS_INTEGER;
  BEGIN
    IF WORKBOOK.BORDERS.COUNT() > 0
    THEN
      FOR B IN 0 .. WORKBOOK.BORDERS.COUNT() - 1
      LOOP
        IF (   NVL( WORKBOOK.BORDERS( B ).TOP, 'x' ) = NVL( P_TOP, 'x' )
           AND NVL( WORKBOOK.BORDERS( B ).BOTTOM, 'x' ) = NVL( P_BOTTOM, 'x' )
           AND NVL( WORKBOOK.BORDERS( B ).LEFT, 'x' ) = NVL( P_LEFT, 'x' )
           AND NVL( WORKBOOK.BORDERS( B ).RIGHT, 'x' ) = NVL( P_RIGHT, 'x' )
           )
        THEN
          RETURN B;
        END IF;
      END LOOP;
    END IF;
    T_IND := WORKBOOK.BORDERS.COUNT();
    WORKBOOK.BORDERS( T_IND ).TOP := P_TOP;
    WORKBOOK.BORDERS( T_IND ).BOTTOM := P_BOTTOM;
    WORKBOOK.BORDERS( T_IND ).LEFT := P_LEFT;
    WORKBOOK.BORDERS( T_IND ).RIGHT := P_RIGHT;
    RETURN T_IND;
  END;
--
  FUNCTION GET_ALIGNMENT
    ( P_VERTICAL VARCHAR2 := NULL
    , P_HORIZONTAL VARCHAR2 := NULL
    , P_WRAPTEXT BOOLEAN := NULL
    )
  RETURN TP_ALIGNMENT
  IS
    T_RV TP_ALIGNMENT;
  BEGIN
    T_RV.VERTICAL := P_VERTICAL;
    T_RV.HORIZONTAL := P_HORIZONTAL;
    T_RV.WRAPTEXT := P_WRAPTEXT;
    RETURN T_RV;
  END;
--
  FUNCTION GET_XFID
    ( P_SHEET PLS_INTEGER
    , P_COL PLS_INTEGER
    , P_ROW PLS_INTEGER
    , P_NUMFMTID PLS_INTEGER := NULL
    , P_FONTID PLS_INTEGER := NULL
    , P_FILLID PLS_INTEGER := NULL
    , P_BORDERID PLS_INTEGER := NULL
    , P_ALIGNMENT TP_ALIGNMENT := NULL
    )
  RETURN VARCHAR2
  IS
    T_CNT PLS_INTEGER;
    T_XFID PLS_INTEGER;
    T_XF TP_XF_FMT;
    T_COL_XF TP_XF_FMT;
    T_ROW_XF TP_XF_FMT;
  BEGIN
    IF WORKBOOK.SHEETS( P_SHEET ).COL_FMTS.EXISTS( P_COL )
    THEN
      T_COL_XF := WORKBOOK.SHEETS( P_SHEET ).COL_FMTS( P_COL );
    END IF;
    IF WORKBOOK.SHEETS( P_SHEET ).ROW_FMTS.EXISTS( P_ROW )
    THEN
      T_ROW_XF := WORKBOOK.SHEETS( P_SHEET ).ROW_FMTS( P_ROW );
    END IF;
    T_XF.NUMFMTID := COALESCE( P_NUMFMTID, T_COL_XF.NUMFMTID, T_ROW_XF.NUMFMTID, 0 );
    T_XF.FONTID := COALESCE( P_FONTID, T_COL_XF.FONTID, T_ROW_XF.FONTID, 0 );
    T_XF.FILLID := COALESCE( P_FILLID, T_COL_XF.FILLID, T_ROW_XF.FILLID, 0 );
    T_XF.BORDERID := COALESCE( P_BORDERID, T_COL_XF.BORDERID, T_ROW_XF.BORDERID, 0 );
    T_XF.ALIGNMENT := COALESCE( P_ALIGNMENT, T_COL_XF.ALIGNMENT, T_ROW_XF.ALIGNMENT );
    IF (   T_XF.NUMFMTID + T_XF.FONTID + T_XF.FILLID + T_XF.BORDERID = 0
       AND T_XF.ALIGNMENT.VERTICAL IS NULL
       AND T_XF.ALIGNMENT.HORIZONTAL IS NULL
       AND NOT NVL( T_XF.ALIGNMENT.WRAPTEXT, FALSE )
       )
    THEN
      RETURN '';
    END IF;
    IF T_XF.NUMFMTID > 0
    THEN
      SET_COL_WIDTH( P_SHEET, P_COL, WORKBOOK.NUMFMTS( WORKBOOK.NUMFMTINDEXES( T_XF.NUMFMTID ) ).FORMATCODE );
    END IF;
    T_CNT := WORKBOOK.CELLXFS.COUNT();
    FOR I IN 1 .. T_CNT
    LOOP
      IF (   WORKBOOK.CELLXFS( I ).NUMFMTID = T_XF.NUMFMTID
         AND WORKBOOK.CELLXFS( I ).FONTID = T_XF.FONTID
         AND WORKBOOK.CELLXFS( I ).FILLID = T_XF.FILLID
         AND WORKBOOK.CELLXFS( I ).BORDERID = T_XF.BORDERID
         AND NVL( WORKBOOK.CELLXFS( I ).ALIGNMENT.VERTICAL, 'x' ) = NVL( T_XF.ALIGNMENT.VERTICAL, 'x' )
         AND NVL( WORKBOOK.CELLXFS( I ).ALIGNMENT.HORIZONTAL, 'x' ) = NVL( T_XF.ALIGNMENT.HORIZONTAL, 'x' )
         AND NVL( WORKBOOK.CELLXFS( I ).ALIGNMENT.WRAPTEXT, FALSE ) = NVL( T_XF.ALIGNMENT.WRAPTEXT, FALSE )
         )
      THEN
        T_XFID := I;
        EXIT;
      END IF;
    END LOOP;
    IF T_XFID IS NULL
    THEN
      T_CNT := T_CNT + 1;
      T_XFID := T_CNT;
      WORKBOOK.CELLXFS( T_CNT ) := T_XF;
    END IF;
    RETURN 's="' || T_XFID || '"';
  END;
--
  PROCEDURE CELL
    ( P_COL PLS_INTEGER
    , P_ROW PLS_INTEGER
    , P_VALUE NUMBER
    , P_NUMFMTID PLS_INTEGER := NULL
    , P_FONTID PLS_INTEGER := NULL
    , P_FILLID PLS_INTEGER := NULL
    , P_BORDERID PLS_INTEGER := NULL
    , P_ALIGNMENT TP_ALIGNMENT := NULL
    , P_SHEET PLS_INTEGER := NULL
    )
  IS
    T_SHEET PLS_INTEGER := NVL( P_SHEET, WORKBOOK.SHEETS.COUNT() );
  BEGIN
    WORKBOOK.SHEETS( T_SHEET ).ROWS( P_ROW )( P_COL ).VALUE := P_VALUE;
    WORKBOOK.SHEETS( T_SHEET ).ROWS( P_ROW )( P_COL ).STYLE := NULL;
    WORKBOOK.SHEETS( T_SHEET ).ROWS( P_ROW )( P_COL ).STYLE := GET_XFID( T_SHEET, P_COL, P_ROW, P_NUMFMTID, P_FONTID, P_FILLID, P_BORDERID, P_ALIGNMENT );
  END;
--
  FUNCTION ADD_STRING( P_STRING VARCHAR2 )
  RETURN PLS_INTEGER
  IS
    T_CNT PLS_INTEGER;
  BEGIN
    IF WORKBOOK.STRINGS.EXISTS( P_STRING )
    THEN
      T_CNT := WORKBOOK.STRINGS( P_STRING );
    ELSE
      T_CNT := WORKBOOK.STRINGS.COUNT();  
      WORKBOOK.STR_IND( T_CNT ) := P_STRING;
      WORKBOOK.STRINGS( NVL( P_STRING, '' ) ) := T_CNT;
    END IF;
    WORKBOOK.STR_CNT := WORKBOOK.STR_CNT + 1;
    RETURN T_CNT;
  END;
--
  PROCEDURE CELL
    ( P_COL PLS_INTEGER
    , P_ROW PLS_INTEGER
    , P_VALUE VARCHAR2
    , P_NUMFMTID PLS_INTEGER := NULL
    , P_FONTID PLS_INTEGER := NULL
    , P_FILLID PLS_INTEGER := NULL
    , P_BORDERID PLS_INTEGER := NULL
    , P_ALIGNMENT TP_ALIGNMENT := NULL
    , P_SHEET PLS_INTEGER := NULL
    )
  IS
    T_SHEET PLS_INTEGER := NVL( P_SHEET, WORKBOOK.SHEETS.COUNT() );
    T_ALIGNMENT TP_ALIGNMENT := P_ALIGNMENT;
  BEGIN
    WORKBOOK.SHEETS( T_SHEET ).ROWS( P_ROW )( P_COL ).VALUE := ADD_STRING( P_VALUE );
    IF T_ALIGNMENT.WRAPTEXT IS NULL AND INSTR( P_VALUE, CHR(13) ) > 0
    THEN
      T_ALIGNMENT.WRAPTEXT := TRUE;
    END IF;
    WORKBOOK.SHEETS( T_SHEET ).ROWS( P_ROW )( P_COL ).STYLE := 't="s" ' || GET_XFID( T_SHEET, P_COL, P_ROW, P_NUMFMTID, P_FONTID, P_FILLID, P_BORDERID, T_ALIGNMENT );
  END;
--
  PROCEDURE CELL
    ( P_COL PLS_INTEGER
    , P_ROW PLS_INTEGER
    , P_VALUE DATE
    , P_NUMFMTID PLS_INTEGER := NULL
    , P_FONTID PLS_INTEGER := NULL
    , P_FILLID PLS_INTEGER := NULL
    , P_BORDERID PLS_INTEGER := NULL
    , P_ALIGNMENT TP_ALIGNMENT := NULL
    , P_SHEET PLS_INTEGER := NULL
    )
  IS
    T_NUMFMTID PLS_INTEGER := P_NUMFMTID;
    T_SHEET PLS_INTEGER := NVL( P_SHEET, WORKBOOK.SHEETS.COUNT() );
  BEGIN
    WORKBOOK.SHEETS( T_SHEET ).ROWS( P_ROW )( P_COL ).VALUE := ADD_STRING(TO_CHAR(P_VALUE,'DD/MM/YYYY'));-- P_VALUE - TO_DATE('01-01-1904','DD-MM-YYYY');
    /*
    IF T_NUMFMTID IS NULL
       AND NOT (   WORKBOOK.SHEETS( T_SHEET ).COL_FMTS.EXISTS( P_COL )
               AND WORKBOOK.SHEETS( T_SHEET ).COL_FMTS( P_COL ).NUMFMTID IS NOT NULL
               )
       AND NOT (   WORKBOOK.SHEETS( T_SHEET ).ROW_FMTS.EXISTS( P_ROW )
               AND WORKBOOK.SHEETS( T_SHEET ).ROW_FMTS( P_ROW ).NUMFMTID IS NOT NULL
               )
    THEN
      T_NUMFMTID := GET_NUMFMT( 'DD/MM/YYYY' );
    END IF;
    */
    --WORKBOOK.SHEETS( T_SHEET ).ROWS( P_ROW )( P_COL ).STYLE := GET_XFID( T_SHEET, P_COL, P_ROW, T_NUMFMTID, P_FONTID, P_FILLID, P_BORDERID, P_ALIGNMENT );
    WORKBOOK.SHEETS( T_SHEET ).ROWS( P_ROW )( P_COL ).STYLE := 't="s" ' || GET_XFID( T_SHEET, P_COL, P_ROW, P_NUMFMTID, P_FONTID, P_FILLID, P_BORDERID, P_ALIGNMENT );
  END;
--
  PROCEDURE HYPERLINK
    ( P_COL PLS_INTEGER
    , P_ROW PLS_INTEGER
    , P_URL VARCHAR2
    , P_VALUE VARCHAR2 := NULL
    , P_SHEET PLS_INTEGER := NULL
    )
  IS
    T_IND PLS_INTEGER;
    T_SHEET PLS_INTEGER := NVL( P_SHEET, WORKBOOK.SHEETS.COUNT() );
  BEGIN
    WORKBOOK.SHEETS( T_SHEET ).ROWS( P_ROW )( P_COL ).VALUE := ADD_STRING( NVL( P_VALUE, P_URL ) );
    WORKBOOK.SHEETS( T_SHEET ).ROWS( P_ROW )( P_COL ).STYLE := 't="s" ' || GET_XFID( T_SHEET, P_COL, P_ROW, '', GET_FONT( 'Calibri', P_THEME => 10, P_UNDERLINE => TRUE ) );
    T_IND := WORKBOOK.SHEETS( T_SHEET ).HYPERLINKS.COUNT() + 1;
    WORKBOOK.SHEETS( T_SHEET ).HYPERLINKS( T_IND ).CELL := ALFAN_COL( P_COL ) || P_ROW;
    WORKBOOK.SHEETS( T_SHEET ).HYPERLINKS( T_IND ).URL := P_URL;
  END;
--
  PROCEDURE COMMENT
    ( P_COL PLS_INTEGER
    , P_ROW PLS_INTEGER
    , P_TEXT VARCHAR2
    , P_AUTHOR VARCHAR2 := NULL
    , P_WIDTH PLS_INTEGER := 150
    , P_HEIGHT PLS_INTEGER := 100
    , P_SHEET PLS_INTEGER := NULL
    )
  IS
    T_IND PLS_INTEGER;
    T_SHEET PLS_INTEGER := NVL( P_SHEET, WORKBOOK.SHEETS.COUNT() );
  BEGIN
    T_IND := WORKBOOK.SHEETS( T_SHEET ).COMMENTS.COUNT() + 1;
    WORKBOOK.SHEETS( T_SHEET ).COMMENTS( T_IND ).ROW := P_ROW;
    WORKBOOK.SHEETS( T_SHEET ).COMMENTS( T_IND ).COLUMN := P_COL;
    WORKBOOK.SHEETS( T_SHEET ).COMMENTS( T_IND ).TEXT := DBMS_XMLGEN.CONVERT( P_TEXT );
    WORKBOOK.SHEETS( T_SHEET ).COMMENTS( T_IND ).AUTHOR := DBMS_XMLGEN.CONVERT( P_AUTHOR );
    WORKBOOK.SHEETS( T_SHEET ).COMMENTS( T_IND ).WIDTH := P_WIDTH;
    WORKBOOK.SHEETS( T_SHEET ).COMMENTS( T_IND ).HEIGHT := P_HEIGHT;
  END;
--
  PROCEDURE MERGECELLS
    ( P_TL_COL PLS_INTEGER -- top left
    , P_TL_ROW PLS_INTEGER
    , P_BR_COL PLS_INTEGER -- bottom right
    , P_BR_ROW PLS_INTEGER
    , P_SHEET PLS_INTEGER := NULL
    )
  IS
    T_IND PLS_INTEGER;
    T_SHEET PLS_INTEGER := NVL( P_SHEET, WORKBOOK.SHEETS.COUNT() );
  BEGIN
    T_IND := WORKBOOK.SHEETS( T_SHEET ).MERGECELLS.COUNT() + 1;
    WORKBOOK.SHEETS( T_SHEET ).MERGECELLS( T_IND ) := ALFAN_COL( P_TL_COL ) || P_TL_ROW || ':' || ALFAN_COL( P_BR_COL ) || P_BR_ROW;
  END;
--
  PROCEDURE ADD_VALIDATION
    ( P_TYPE VARCHAR2
    , P_SQREF VARCHAR2
    , P_STYLE VARCHAR2 := 'stop' -- stop, warning, information
    , P_FORMULA1 VARCHAR2 := NULL
    , P_FORMULA2 VARCHAR2 := NULL
    , P_TITLE VARCHAR2 := NULL
    , P_PROMPT VARCHAR := NULL
    , P_SHOW_ERROR BOOLEAN := FALSE
    , P_ERROR_TITLE VARCHAR2 := NULL
    , P_ERROR_TXT VARCHAR2 := NULL
    , P_SHEET PLS_INTEGER := NULL
    )
  IS
    T_IND PLS_INTEGER;
    T_SHEET PLS_INTEGER := NVL( P_SHEET, WORKBOOK.SHEETS.COUNT() );
  BEGIN
    T_IND := WORKBOOK.SHEETS( T_SHEET ).VALIDATIONS.COUNT() + 1;
    WORKBOOK.SHEETS( T_SHEET ).VALIDATIONS( T_IND ).TYPE := P_TYPE;
    WORKBOOK.SHEETS( T_SHEET ).VALIDATIONS( T_IND ).ERRORSTYLE := P_STYLE;
    WORKBOOK.SHEETS( T_SHEET ).VALIDATIONS( T_IND ).SQREF := P_SQREF;
    WORKBOOK.SHEETS( T_SHEET ).VALIDATIONS( T_IND ).FORMULA1 := P_FORMULA1;
    WORKBOOK.SHEETS( T_SHEET ).VALIDATIONS( T_IND ).ERROR_TITLE := P_ERROR_TITLE;
    WORKBOOK.SHEETS( T_SHEET ).VALIDATIONS( T_IND ).ERROR_TXT := P_ERROR_TXT;
    WORKBOOK.SHEETS( T_SHEET ).VALIDATIONS( T_IND ).TITLE := P_TITLE;
    WORKBOOK.SHEETS( T_SHEET ).VALIDATIONS( T_IND ).PROMPT := P_PROMPT;
    WORKBOOK.SHEETS( T_SHEET ).VALIDATIONS( T_IND ).SHOWERRORMESSAGE := P_SHOW_ERROR;
  END;
--
  PROCEDURE LIST_VALIDATION
    ( P_SQREF_COL PLS_INTEGER
    , P_SQREF_ROW PLS_INTEGER
    , P_TL_COL PLS_INTEGER -- top left
    , P_TL_ROW PLS_INTEGER
    , P_BR_COL PLS_INTEGER -- bottom right
    , P_BR_ROW PLS_INTEGER
    , P_STYLE VARCHAR2 := 'stop' -- stop, warning, information
    , P_TITLE VARCHAR2 := NULL
    , P_PROMPT VARCHAR := NULL
    , P_SHOW_ERROR BOOLEAN := FALSE
    , P_ERROR_TITLE VARCHAR2 := NULL
    , P_ERROR_TXT VARCHAR2 := NULL
    , P_SHEET PLS_INTEGER := NULL
    )
  IS
  BEGIN
    ADD_VALIDATION( 'list'
                  , ALFAN_COL( P_SQREF_COL ) || P_SQREF_ROW
                  , P_STYLE => LOWER( P_STYLE )
                  , P_FORMULA1 => '$' || ALFAN_COL( P_TL_COL ) || '$' ||  P_TL_ROW || ':$' || ALFAN_COL( P_BR_COL ) || '$' || P_BR_ROW 
                  , P_TITLE => P_TITLE
                  , P_PROMPT => P_PROMPT
                  , P_SHOW_ERROR => P_SHOW_ERROR
                  , P_ERROR_TITLE => P_ERROR_TITLE
                  , P_ERROR_TXT => P_ERROR_TXT
                  , P_SHEET => P_SHEET
                  ); 
  END;
--
  PROCEDURE LIST_VALIDATION
    ( P_SQREF_COL PLS_INTEGER
    , P_SQREF_ROW PLS_INTEGER
    , P_DEFINED_NAME VARCHAR2
    , P_STYLE VARCHAR2 := 'stop' -- stop, warning, information
    , P_TITLE VARCHAR2 := NULL
    , P_PROMPT VARCHAR := NULL
    , P_SHOW_ERROR BOOLEAN := FALSE
    , P_ERROR_TITLE VARCHAR2 := NULL
    , P_ERROR_TXT VARCHAR2 := NULL
    , P_SHEET PLS_INTEGER := NULL
    )
  IS
  BEGIN
    ADD_VALIDATION( 'list'
                  , ALFAN_COL( P_SQREF_COL ) || P_SQREF_ROW
                  , P_STYLE => LOWER( P_STYLE )
                  , P_FORMULA1 => P_DEFINED_NAME 
                  , P_TITLE => P_TITLE
                  , P_PROMPT => P_PROMPT
                  , P_SHOW_ERROR => P_SHOW_ERROR
                  , P_ERROR_TITLE => P_ERROR_TITLE
                  , P_ERROR_TXT => P_ERROR_TXT
                  , P_SHEET => P_SHEET
                  ); 
  END;
--
  PROCEDURE DEFINED_NAME
    ( P_TL_COL PLS_INTEGER -- top left
    , P_TL_ROW PLS_INTEGER
    , P_BR_COL PLS_INTEGER -- bottom right
    , P_BR_ROW PLS_INTEGER
    , P_NAME VARCHAR2
    , P_SHEET PLS_INTEGER := NULL
    , P_LOCALSHEET PLS_INTEGER := NULL
    )
  IS
    T_IND PLS_INTEGER;
    T_SHEET PLS_INTEGER := NVL( P_SHEET, WORKBOOK.SHEETS.COUNT() );
  BEGIN
    T_IND := WORKBOOK.DEFINED_NAMES.COUNT() + 1;
    WORKBOOK.DEFINED_NAMES( T_IND ).NAME := P_NAME;
    WORKBOOK.DEFINED_NAMES( T_IND ).REF := 'Sheet' || T_SHEET || '!$' || ALFAN_COL( P_TL_COL ) || '$' ||  P_TL_ROW || ':$' || ALFAN_COL( P_BR_COL ) || '$' || P_BR_ROW;
    WORKBOOK.DEFINED_NAMES( T_IND ).SHEET := P_LOCALSHEET;
  END;
--
  PROCEDURE SET_COLUMN_WIDTH
    ( P_COL PLS_INTEGER
    , P_WIDTH NUMBER
    , P_SHEET PLS_INTEGER := NULL
    )
  IS
  BEGIN
    WORKBOOK.SHEETS( NVL( P_SHEET, WORKBOOK.SHEETS.COUNT() ) ).WIDTHS( P_COL ) := P_WIDTH;
  END;
--
  PROCEDURE SET_COLUMN
    ( P_COL PLS_INTEGER
    , P_NUMFMTID PLS_INTEGER := NULL
    , P_FONTID PLS_INTEGER := NULL
    , P_FILLID PLS_INTEGER := NULL
    , P_BORDERID PLS_INTEGER := NULL
    , P_ALIGNMENT TP_ALIGNMENT := NULL
    , P_SHEET PLS_INTEGER := NULL
    )
  IS
    T_SHEET PLS_INTEGER := NVL( P_SHEET, WORKBOOK.SHEETS.COUNT() );
  BEGIN
    WORKBOOK.SHEETS( T_SHEET ).COL_FMTS( P_COL ).NUMFMTID := P_NUMFMTID;
    WORKBOOK.SHEETS( T_SHEET ).COL_FMTS( P_COL ).FONTID := P_FONTID;
    WORKBOOK.SHEETS( T_SHEET ).COL_FMTS( P_COL ).FILLID := P_FILLID;
    WORKBOOK.SHEETS( T_SHEET ).COL_FMTS( P_COL ).BORDERID := P_BORDERID;
    WORKBOOK.SHEETS( T_SHEET ).COL_FMTS( P_COL ).ALIGNMENT := P_ALIGNMENT;
  END;
--
  PROCEDURE SET_ROW
    ( P_ROW PLS_INTEGER
    , P_NUMFMTID PLS_INTEGER := NULL
    , P_FONTID PLS_INTEGER := NULL
    , P_FILLID PLS_INTEGER := NULL
    , P_BORDERID PLS_INTEGER := NULL
    , P_ALIGNMENT TP_ALIGNMENT := NULL
    , P_SHEET PLS_INTEGER := NULL
    )
  IS
    T_SHEET PLS_INTEGER := NVL( P_SHEET, WORKBOOK.SHEETS.COUNT() );
  BEGIN
    WORKBOOK.SHEETS( T_SHEET ).ROW_FMTS( P_ROW ).NUMFMTID := P_NUMFMTID;
    WORKBOOK.SHEETS( T_SHEET ).ROW_FMTS( P_ROW ).FONTID := P_FONTID;
    WORKBOOK.SHEETS( T_SHEET ).ROW_FMTS( P_ROW ).FILLID := P_FILLID;
    WORKBOOK.SHEETS( T_SHEET ).ROW_FMTS( P_ROW ).BORDERID := P_BORDERID;
    WORKBOOK.SHEETS( T_SHEET ).ROW_FMTS( P_ROW ).ALIGNMENT := P_ALIGNMENT;
  END;
--
  PROCEDURE FREEZE_ROWS
    ( P_NR_ROWS PLS_INTEGER := 1
    , P_SHEET PLS_INTEGER := NULL
    )
  IS
    T_SHEET PLS_INTEGER := NVL( P_SHEET, WORKBOOK.SHEETS.COUNT() );
  BEGIN
    WORKBOOK.SHEETS( T_SHEET ).FREEZE_COLS := NULL;
    WORKBOOK.SHEETS( T_SHEET ).FREEZE_ROWS := P_NR_ROWS;
  END;
--
  PROCEDURE FREEZE_COLS
    ( P_NR_COLS PLS_INTEGER := 1
    , P_SHEET PLS_INTEGER := NULL
    )
  IS
    T_SHEET PLS_INTEGER := NVL( P_SHEET, WORKBOOK.SHEETS.COUNT() );
  BEGIN
    WORKBOOK.SHEETS( T_SHEET ).FREEZE_ROWS := NULL;
    WORKBOOK.SHEETS( T_SHEET ).FREEZE_COLS := P_NR_COLS;
  END;
--
  PROCEDURE FREEZE_PANE
    ( P_COL PLS_INTEGER
    , P_ROW PLS_INTEGER
    , P_SHEET PLS_INTEGER := NULL
    )
  IS
    T_SHEET PLS_INTEGER := NVL( P_SHEET, WORKBOOK.SHEETS.COUNT() );
  BEGIN
    WORKBOOK.SHEETS( T_SHEET ).FREEZE_ROWS := P_ROW;
    WORKBOOK.SHEETS( T_SHEET ).FREEZE_COLS := P_COL;
  END;
--
  PROCEDURE SET_AUTOFILTER
    ( P_COLUMN_START PLS_INTEGER := NULL
    , P_COLUMN_END PLS_INTEGER := NULL
    , P_ROW_START PLS_INTEGER := NULL
    , P_ROW_END PLS_INTEGER := NULL
    , P_SHEET PLS_INTEGER := NULL
    )
  IS
    T_IND PLS_INTEGER;
    T_SHEET PLS_INTEGER := NVL( P_SHEET, WORKBOOK.SHEETS.COUNT() );
  BEGIN
    T_IND := 1;
    WORKBOOK.SHEETS( T_SHEET ).AUTOFILTERS( T_IND ).COLUMN_START := P_COLUMN_START;
    WORKBOOK.SHEETS( T_SHEET ).AUTOFILTERS( T_IND ).COLUMN_END := P_COLUMN_END;
    WORKBOOK.SHEETS( T_SHEET ).AUTOFILTERS( T_IND ).ROW_START := P_ROW_START;
    WORKBOOK.SHEETS( T_SHEET ).AUTOFILTERS( T_IND ).ROW_END := P_ROW_END;
    DEFINED_NAME
      ( P_COLUMN_START
      , P_ROW_START
      , P_COLUMN_END
      , P_ROW_END
      , '_xlnm._FilterDatabase'
      , T_SHEET
      , T_SHEET - 1
      );
  END;
--
/*
  procedure add1xml
    ( p_excel in out nocopy blob
    , p_filename varchar2
    , p_xml clob
    )
  is
    t_tmp blob;
    c_step constant number := 24396;
  begin
    dbms_lob.createtemporary( t_tmp, true );
    for i in 0 .. trunc( length( p_xml ) / c_step )
    loop
      dbms_lob.append( t_tmp, utl_i18n.string_to_raw( substr( p_xml, i * c_step + 1, c_step ), 'AL32UTF8' ) );
    end loop;
    add1file( p_excel, p_filename, t_tmp );
    dbms_lob.freetemporary( t_tmp );
  end;
*/
--
  PROCEDURE ADD1XML
    ( P_EXCEL IN OUT NOCOPY BLOB
    , P_FILENAME VARCHAR2
    , P_XML CLOB
    )
  IS
    T_TMP BLOB;
    DEST_OFFSET INTEGER := 1;
    SRC_OFFSET INTEGER := 1;
    LANG_CONTEXT INTEGER;
    WARNING INTEGER;
  BEGIN
    LANG_CONTEXT := DBMS_LOB.DEFAULT_LANG_CTX;
    DBMS_LOB.CREATETEMPORARY( T_TMP, TRUE );
    DBMS_LOB.CONVERTTOBLOB
      ( T_TMP
      , P_XML
      , DBMS_LOB.LOBMAXSIZE
      , DEST_OFFSET
      , SRC_OFFSET
      ,  NLS_CHARSET_ID( 'AL32UTF8'  ) 
      , LANG_CONTEXT
      , WARNING
      );
    ADD1FILE( P_EXCEL, P_FILENAME, T_TMP );
    DBMS_LOB.FREETEMPORARY( T_TMP );
  END;
--
  FUNCTION FINISH
  RETURN BLOB
  IS
    T_EXCEL BLOB;
    T_XXX CLOB;
    T_TMP VARCHAR2(32767 CHAR);
    T_STR VARCHAR2(32767 CHAR);
    T_C NUMBER;
    T_H NUMBER;
    T_W NUMBER;
    T_CW NUMBER;
    T_CELL VARCHAR2(1000 CHAR);
    T_ROW_IND PLS_INTEGER;
    T_COL_MIN PLS_INTEGER;
    T_COL_MAX PLS_INTEGER;
    T_COL_IND PLS_INTEGER;
    T_LEN PLS_INTEGER;
TS TIMESTAMP := SYSTIMESTAMP;
  BEGIN
    DBMS_LOB.CREATETEMPORARY( T_EXCEL, TRUE );
    T_XXX := '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
<Default Extension="xml" ContentType="application/xml"/>
<Default Extension="vml" ContentType="application/vnd.openxmlformats-officedocument.vmlDrawing"/>
<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>';
    FOR S IN 1 .. WORKBOOK.SHEETS.COUNT()
    LOOP
      T_XXX := T_XXX || '
<Override PartName="/xl/worksheets/sheet' || S || '.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>';
    END LOOP;
    T_XXX := T_XXX || '
<Override PartName="/xl/theme/theme1.xml" ContentType="application/vnd.openxmlformats-officedocument.theme+xml"/>
<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
<Override PartName="/xl/sharedStrings.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml"/>
<Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>
<Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>';
    FOR S IN 1 .. WORKBOOK.SHEETS.COUNT()
    LOOP
      IF WORKBOOK.SHEETS( S ).COMMENTS.COUNT() > 0
      THEN
        T_XXX := T_XXX || '
<Override PartName="/xl/comments' || S || '.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.comments+xml"/>';
      END IF;
    END LOOP;
    T_XXX := T_XXX || '
</Types>';
    ADD1XML( T_EXCEL, '[Content_Types].xml', T_XXX );
    T_XXX := '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:dcmitype="http://purl.org/dc/dcmitype/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
<dc:creator>' || SYS_CONTEXT( 'userenv', 'os_user' ) || '</dc:creator>
<cp:lastModifiedBy>' || SYS_CONTEXT( 'userenv', 'os_user' ) || '</cp:lastModifiedBy>
<dcterms:created xsi:type="dcterms:W3CDTF">' || TO_CHAR( CURRENT_TIMESTAMP, 'yyyy-mm-dd"T"hh24:mi:ssTZH:TZM' ) || '</dcterms:created>
<dcterms:modified xsi:type="dcterms:W3CDTF">' || TO_CHAR( CURRENT_TIMESTAMP, 'yyyy-mm-dd"T"hh24:mi:ssTZH:TZM' ) || '</dcterms:modified>
</cp:coreProperties>';
    ADD1XML( T_EXCEL, 'docProps/core.xml', T_XXX );
    T_XXX := '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">
<Application>Microsoft Excel</Application>
<DocSecurity>0</DocSecurity>
<ScaleCrop>false</ScaleCrop>
<HeadingPairs>
<vt:vector size="2" baseType="variant">
<vt:variant>
<vt:lpstr>Worksheets</vt:lpstr>
</vt:variant>
<vt:variant>
<vt:i4>' || WORKBOOK.SHEETS.COUNT() || '</vt:i4>
</vt:variant>
</vt:vector>
</HeadingPairs>
<TitlesOfParts>
<vt:vector size="' || WORKBOOK.SHEETS.COUNT() || '" baseType="lpstr">';
    FOR S IN 1 .. WORKBOOK.SHEETS.COUNT()
    LOOP
      T_XXX := T_XXX || '
<vt:lpstr>' || WORKBOOK.SHEETS( S ).NAME || '</vt:lpstr>';
    END LOOP;
    T_XXX := T_XXX || '</vt:vector>
</TitlesOfParts>
<LinksUpToDate>false</LinksUpToDate>
<SharedDoc>false</SharedDoc>
<HyperlinksChanged>false</HyperlinksChanged>
<AppVersion>14.0300</AppVersion>
</Properties>';
    ADD1XML( T_EXCEL, 'docProps/app.xml', T_XXX );
    T_XXX := '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>
<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
</Relationships>';
    ADD1XML( T_EXCEL, '_rels/.rels', T_XXX );
    T_XXX := '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006" mc:Ignorable="x14ac" xmlns:x14ac="http://schemas.microsoft.com/office/spreadsheetml/2009/9/ac">';
    IF WORKBOOK.NUMFMTS.COUNT() > 0
    THEN
      T_XXX := T_XXX || '<numFmts count="' || WORKBOOK.NUMFMTS.COUNT() || '">';
      FOR N IN 1 .. WORKBOOK.NUMFMTS.COUNT()
      LOOP
        T_XXX := T_XXX || '<numFmt numFmtId="' || WORKBOOK.NUMFMTS( N ).NUMFMTID || '" formatCode="' || WORKBOOK.NUMFMTS( N ).FORMATCODE || '"/>';
      END LOOP;
      T_XXX := T_XXX || '</numFmts>';
    END IF;
    T_XXX := T_XXX || '<fonts count="' || WORKBOOK.FONTS.COUNT() || '" x14ac:knownFonts="1">';
    FOR F IN 0 .. WORKBOOK.FONTS.COUNT() - 1
    LOOP
      T_XXX := T_XXX || '<font>' || 
        CASE WHEN WORKBOOK.FONTS( F ).BOLD THEN '<b/>' END ||
        CASE WHEN WORKBOOK.FONTS( F ).ITALIC THEN '<i/>' END ||
        CASE WHEN WORKBOOK.FONTS( F ).UNDERLINE THEN '<u/>' END ||
'<sz val="' || TO_CHAR( WORKBOOK.FONTS( F ).FONTSIZE, 'TM9', 'NLS_NUMERIC_CHARACTERS=.,' )  || '"/>
<color ' || CASE WHEN WORKBOOK.FONTS( F ).RGB IS NOT NULL
              THEN 'rgb="' || WORKBOOK.FONTS( F ).RGB
              ELSE 'theme="' || WORKBOOK.FONTS( F ).THEME
            END || '"/>
<name val="' || WORKBOOK.FONTS( F ).NAME || '"/>
<family val="' || WORKBOOK.FONTS( F ).FAMILY || '"/>
<scheme val="none"/>
</font>';
    END LOOP;
    T_XXX := T_XXX || '</fonts>
<fills count="' || WORKBOOK.FILLS.COUNT() || '">';
    FOR F IN 0 .. WORKBOOK.FILLS.COUNT() - 1
    LOOP
      T_XXX := T_XXX || '<fill><patternFill patternType="' || WORKBOOK.FILLS( F ).PATTERNTYPE || '">' ||
         CASE WHEN WORKBOOK.FILLS( F ).FGRGB IS NOT NULL THEN '<fgColor rgb="' || WORKBOOK.FILLS( F ).FGRGB || '"/>' END ||
         '</patternFill></fill>';
    END LOOP;
    T_XXX := T_XXX || '</fills>
<borders count="' || WORKBOOK.BORDERS.COUNT() || '">';
    FOR B IN 0 .. WORKBOOK.BORDERS.COUNT() - 1
    LOOP
      T_XXX := T_XXX || '<border>' ||
         CASE WHEN WORKBOOK.BORDERS( B ).LEFT   IS NULL THEN '<left/>'   ELSE '<left style="'   || WORKBOOK.BORDERS( B ).LEFT   || '"/>' END ||
         CASE WHEN WORKBOOK.BORDERS( B ).RIGHT  IS NULL THEN '<right/>'  ELSE '<right style="'  || WORKBOOK.BORDERS( B ).RIGHT  || '"/>' END ||
         CASE WHEN WORKBOOK.BORDERS( B ).TOP    IS NULL THEN '<top/>'    ELSE '<top style="'    || WORKBOOK.BORDERS( B ).TOP    || '"/>' END ||
         CASE WHEN WORKBOOK.BORDERS( B ).BOTTOM IS NULL THEN '<bottom/>' ELSE '<bottom style="' || WORKBOOK.BORDERS( B ).BOTTOM || '"/>' END ||
         '</border>';
    END LOOP;
    T_XXX := T_XXX || '</borders>
<cellStyleXfs count="1">
<xf numFmtId="0" fontId="0" fillId="0" borderId="0"/>
</cellStyleXfs>
<cellXfs count="' || ( WORKBOOK.CELLXFS.COUNT() + 1 ) || '">
<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>';
    FOR X IN 1 .. WORKBOOK.CELLXFS.COUNT()
    LOOP
      T_XXX := T_XXX || '<xf numFmtId="' || WORKBOOK.CELLXFS( X ).NUMFMTID || '" fontId="' || WORKBOOK.CELLXFS( X ).FONTID || '" fillId="' || WORKBOOK.CELLXFS( X ).FILLID || '" borderId="' || WORKBOOK.CELLXFS( X ).BORDERID || '">';
      IF (  WORKBOOK.CELLXFS( X ).ALIGNMENT.HORIZONTAL IS NOT NULL
         OR WORKBOOK.CELLXFS( X ).ALIGNMENT.VERTICAL IS NOT NULL
         OR WORKBOOK.CELLXFS( X ).ALIGNMENT.WRAPTEXT
         )
      THEN
        T_XXX := T_XXX || '<alignment' ||
          CASE WHEN WORKBOOK.CELLXFS( X ).ALIGNMENT.HORIZONTAL IS NOT NULL THEN ' horizontal="' || WORKBOOK.CELLXFS( X ).ALIGNMENT.HORIZONTAL || '"' END ||
          CASE WHEN WORKBOOK.CELLXFS( X ).ALIGNMENT.VERTICAL IS NOT NULL THEN ' vertical="' || WORKBOOK.CELLXFS( X ).ALIGNMENT.VERTICAL || '"' END ||
          CASE WHEN WORKBOOK.CELLXFS( X ).ALIGNMENT.WRAPTEXT THEN ' wrapText="true"' END || '/>';
      END IF;
      T_XXX := T_XXX || '</xf>';
    END LOOP;
    T_XXX := T_XXX || '</cellXfs>
<cellStyles count="1">
<cellStyle name="Normal" xfId="0" builtinId="0"/>
</cellStyles>
<dxfs count="0"/>
<tableStyles count="0" defaultTableStyle="TableStyleMedium2" defaultPivotStyle="PivotStyleLight16"/>
<extLst>
<ext uri="{EB79DEF2-80B8-43e5-95BD-54CBDDF9020C}" xmlns:x14="http://schemas.microsoft.com/office/spreadsheetml/2009/9/main">
<x14:slicerStyles defaultSlicerStyle="SlicerStyleLight1"/>
</ext>
</extLst>
</styleSheet>';
    ADD1XML( T_EXCEL, 'xl/styles.xml', T_XXX );
    T_XXX := '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
<fileVersion appName="xl" lastEdited="5" lowestEdited="5" rupBuild="9302"/>
<workbookPr date1904="true" defaultThemeVersion="124226"/>
<bookViews>
<workbookView xWindow="120" yWindow="45" windowWidth="19155" windowHeight="4935"/>
</bookViews>
<sheets>';
    FOR S IN 1 .. WORKBOOK.SHEETS.COUNT()
    LOOP
      T_XXX := T_XXX || '
<sheet name="' || WORKBOOK.SHEETS( S ).NAME || '" sheetId="' || S || '" r:id="rId' || ( 9 + S ) || '"/>';
    END LOOP;
    T_XXX := T_XXX || '</sheets>';
    IF WORKBOOK.DEFINED_NAMES.COUNT() > 0
    THEN
      T_XXX := T_XXX || '<definedNames>';
      FOR S IN 1 .. WORKBOOK.DEFINED_NAMES.COUNT()
      LOOP
        T_XXX := T_XXX || '
<definedName name="' || WORKBOOK.DEFINED_NAMES( S ).NAME || '"' ||
            CASE WHEN WORKBOOK.DEFINED_NAMES( S ).SHEET IS NOT NULL THEN ' localSheetId="' || TO_CHAR( WORKBOOK.DEFINED_NAMES( S ).SHEET ) || '"' END ||
            '>' || WORKBOOK.DEFINED_NAMES( S ).REF || '</definedName>';
      END LOOP;
      T_XXX := T_XXX || '</definedNames>';
    END IF;
    T_XXX := T_XXX || '<calcPr calcId="144525"/></workbook>';
    ADD1XML( T_EXCEL, 'xl/workbook.xml', T_XXX );
    T_XXX := '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<a:theme xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" name="Office Theme">
<a:themeElements>
<a:clrScheme name="Office">
<a:dk1>
<a:sysClr val="windowText" lastClr="000000"/>
</a:dk1>
<a:lt1>
<a:sysClr val="window" lastClr="FFFFFF"/>
</a:lt1>
<a:dk2>
<a:srgbClr val="1F497D"/>
</a:dk2>
<a:lt2>
<a:srgbClr val="EEECE1"/>
</a:lt2>
<a:accent1>
<a:srgbClr val="4F81BD"/>
</a:accent1>
<a:accent2>
<a:srgbClr val="C0504D"/>
</a:accent2>
<a:accent3>
<a:srgbClr val="9BBB59"/>
</a:accent3>
<a:accent4>
<a:srgbClr val="8064A2"/>
</a:accent4>
<a:accent5>
<a:srgbClr val="4BACC6"/>
</a:accent5>
<a:accent6>
<a:srgbClr val="F79646"/>
</a:accent6>
<a:hlink>
<a:srgbClr val="0000FF"/>
</a:hlink>
<a:folHlink>
<a:srgbClr val="800080"/>
</a:folHlink>
</a:clrScheme>
<a:fontScheme name="Office">
<a:majorFont>
<a:latin typeface="Cambria"/>
<a:ea typeface=""/>
<a:cs typeface=""/>
<a:font script="Jpan" typeface="MS P????"/>
<a:font script="Hang" typeface="?? ??"/>
<a:font script="Hans" typeface="??"/>
<a:font script="Hant" typeface="????"/>
<a:font script="Arab" typeface="Times New Roman"/>
<a:font script="Hebr" typeface="Times New Roman"/>
<a:font script="Thai" typeface="Tahoma"/>
<a:font script="Ethi" typeface="Nyala"/>
<a:font script="Beng" typeface="Vrinda"/>
<a:font script="Gujr" typeface="Shruti"/>
<a:font script="Khmr" typeface="MoolBoran"/>
<a:font script="Knda" typeface="Tunga"/>
<a:font script="Guru" typeface="Raavi"/>
<a:font script="Cans" typeface="Euphemia"/>
<a:font script="Cher" typeface="Plantagenet Cherokee"/>
<a:font script="Yiii" typeface="Microsoft Yi Baiti"/>
<a:font script="Tibt" typeface="Microsoft Himalaya"/>
<a:font script="Thaa" typeface="MV Boli"/>
<a:font script="Deva" typeface="Mangal"/>
<a:font script="Telu" typeface="Gautami"/>
<a:font script="Taml" typeface="Latha"/>
<a:font script="Syrc" typeface="Estrangelo Edessa"/>
<a:font script="Orya" typeface="Kalinga"/>
<a:font script="Mlym" typeface="Kartika"/>
<a:font script="Laoo" typeface="DokChampa"/>
<a:font script="Sinh" typeface="Iskoola Pota"/>
<a:font script="Mong" typeface="Mongolian Baiti"/>
<a:font script="Viet" typeface="Times New Roman"/>
<a:font script="Uigh" typeface="Microsoft Uighur"/>
<a:font script="Geor" typeface="Sylfaen"/>
</a:majorFont>
<a:minorFont>
<a:latin typeface="Calibri"/>
<a:ea typeface=""/>
<a:cs typeface=""/>
<a:font script="Jpan" typeface="MS P????"/>
<a:font script="Hang" typeface="?? ??"/>
<a:font script="Hans" typeface="??"/>
<a:font script="Hant" typeface="????"/>
<a:font script="Arab" typeface="Arial"/>
<a:font script="Hebr" typeface="Arial"/>
<a:font script="Thai" typeface="Tahoma"/>
<a:font script="Ethi" typeface="Nyala"/>
<a:font script="Beng" typeface="Vrinda"/>
<a:font script="Gujr" typeface="Shruti"/>
<a:font script="Khmr" typeface="DaunPenh"/>
<a:font script="Knda" typeface="Tunga"/>
<a:font script="Guru" typeface="Raavi"/>
<a:font script="Cans" typeface="Euphemia"/>
<a:font script="Cher" typeface="Plantagenet Cherokee"/>
<a:font script="Yiii" typeface="Microsoft Yi Baiti"/>
<a:font script="Tibt" typeface="Microsoft Himalaya"/>
<a:font script="Thaa" typeface="MV Boli"/>
<a:font script="Deva" typeface="Mangal"/>
<a:font script="Telu" typeface="Gautami"/>
<a:font script="Taml" typeface="Latha"/>
<a:font script="Syrc" typeface="Estrangelo Edessa"/>
<a:font script="Orya" typeface="Kalinga"/>
<a:font script="Mlym" typeface="Kartika"/>
<a:font script="Laoo" typeface="DokChampa"/>
<a:font script="Sinh" typeface="Iskoola Pota"/>
<a:font script="Mong" typeface="Mongolian Baiti"/>
<a:font script="Viet" typeface="Arial"/>
<a:font script="Uigh" typeface="Microsoft Uighur"/>
<a:font script="Geor" typeface="Sylfaen"/>
</a:minorFont>
</a:fontScheme>
<a:fmtScheme name="Office">
<a:fillStyleLst>
<a:solidFill>
<a:schemeClr val="phClr"/>
</a:solidFill>
<a:gradFill rotWithShape="1">
<a:gsLst>
<a:gs pos="0">
<a:schemeClr val="phClr">
<a:tint val="50000"/>
<a:satMod val="300000"/>
</a:schemeClr>
</a:gs>
<a:gs pos="35000">
<a:schemeClr val="phClr">
<a:tint val="37000"/>
<a:satMod val="300000"/>
</a:schemeClr>
</a:gs>
<a:gs pos="100000">
<a:schemeClr val="phClr">
<a:tint val="15000"/>
<a:satMod val="350000"/>
</a:schemeClr>
</a:gs>
</a:gsLst>
<a:lin ang="16200000" scaled="1"/>
</a:gradFill>
<a:gradFill rotWithShape="1">
<a:gsLst>
<a:gs pos="0">
<a:schemeClr val="phClr">
<a:shade val="51000"/>
<a:satMod val="130000"/>
</a:schemeClr>
</a:gs>
<a:gs pos="80000">
<a:schemeClr val="phClr">
<a:shade val="93000"/>
<a:satMod val="130000"/>
</a:schemeClr>
</a:gs>
<a:gs pos="100000">
<a:schemeClr val="phClr">
<a:shade val="94000"/>
<a:satMod val="135000"/>
</a:schemeClr>
</a:gs>
</a:gsLst>
<a:lin ang="16200000" scaled="0"/>
</a:gradFill>
</a:fillStyleLst>
<a:lnStyleLst>
<a:ln w="9525" cap="flat" cmpd="sng" algn="ctr">
<a:solidFill>
<a:schemeClr val="phClr">
<a:shade val="95000"/>
<a:satMod val="105000"/>
</a:schemeClr>
</a:solidFill>
<a:prstDash val="solid"/>
</a:ln>
<a:ln w="25400" cap="flat" cmpd="sng" algn="ctr">
<a:solidFill>
<a:schemeClr val="phClr"/>
</a:solidFill>
<a:prstDash val="solid"/>
</a:ln>
<a:ln w="38100" cap="flat" cmpd="sng" algn="ctr">
<a:solidFill>
<a:schemeClr val="phClr"/>
</a:solidFill>
<a:prstDash val="solid"/>
</a:ln>
</a:lnStyleLst>
<a:effectStyleLst>
<a:effectStyle>
<a:effectLst>
<a:outerShdw blurRad="40000" dist="20000" dir="5400000" rotWithShape="0">
<a:srgbClr val="000000">
<a:alpha val="38000"/>
</a:srgbClr>
</a:outerShdw>
</a:effectLst>
</a:effectStyle>
<a:effectStyle>
<a:effectLst>
<a:outerShdw blurRad="40000" dist="23000" dir="5400000" rotWithShape="0">
<a:srgbClr val="000000">
<a:alpha val="35000"/>
</a:srgbClr>
</a:outerShdw>
</a:effectLst>
</a:effectStyle>
<a:effectStyle>
<a:effectLst>
<a:outerShdw blurRad="40000" dist="23000" dir="5400000" rotWithShape="0">
<a:srgbClr val="000000">
<a:alpha val="35000"/>
</a:srgbClr>
</a:outerShdw>
</a:effectLst>
<a:scene3d>
<a:camera prst="orthographicFront">
<a:rot lat="0" lon="0" rev="0"/>
</a:camera>
<a:lightRig rig="threePt" dir="t">
<a:rot lat="0" lon="0" rev="1200000"/>
</a:lightRig>
</a:scene3d>
<a:sp3d>
<a:bevelT w="63500" h="25400"/>
</a:sp3d>
</a:effectStyle>
</a:effectStyleLst>
<a:bgFillStyleLst>
<a:solidFill>
<a:schemeClr val="phClr"/>
</a:solidFill>
<a:gradFill rotWithShape="1">
<a:gsLst>
<a:gs pos="0">
<a:schemeClr val="phClr">
<a:tint val="40000"/>
<a:satMod val="350000"/>
</a:schemeClr>
</a:gs>
<a:gs pos="40000">
<a:schemeClr val="phClr">
<a:tint val="45000"/>
<a:shade val="99000"/>
<a:satMod val="350000"/>
</a:schemeClr>
</a:gs>
<a:gs pos="100000">
<a:schemeClr val="phClr">
<a:shade val="20000"/>
<a:satMod val="255000"/>
</a:schemeClr>
</a:gs>
</a:gsLst>
<a:path path="circle">
<a:fillToRect l="50000" t="-80000" r="50000" b="180000"/>
</a:path>
</a:gradFill>
<a:gradFill rotWithShape="1">
<a:gsLst>
<a:gs pos="0">
<a:schemeClr val="phClr">
<a:tint val="80000"/>
<a:satMod val="300000"/>
</a:schemeClr>
</a:gs>
<a:gs pos="100000">
<a:schemeClr val="phClr">
<a:shade val="30000"/>
<a:satMod val="200000"/>
</a:schemeClr>
</a:gs>
</a:gsLst>
<a:path path="circle">
<a:fillToRect l="50000" t="50000" r="50000" b="50000"/>
</a:path>
</a:gradFill>
</a:bgFillStyleLst>
</a:fmtScheme>
</a:themeElements>
<a:objectDefaults/>
<a:extraClrSchemeLst/>
</a:theme>';
    ADD1XML( T_EXCEL, 'xl/theme/theme1.xml', T_XXX );
    FOR S IN 1 .. WORKBOOK.SHEETS.COUNT()
    LOOP
      T_COL_MIN := 16384;
      T_COL_MAX := 1;
      T_ROW_IND := WORKBOOK.SHEETS( S ).ROWS.FIRST();
      WHILE T_ROW_IND IS NOT NULL
      LOOP
        T_COL_MIN := LEAST( T_COL_MIN, WORKBOOK.SHEETS( S ).ROWS( T_ROW_IND ).FIRST() );
        T_COL_MAX := GREATEST( T_COL_MAX, WORKBOOK.SHEETS( S ).ROWS( T_ROW_IND ).LAST() );
        T_ROW_IND := WORKBOOK.SHEETS( S ).ROWS.NEXT( T_ROW_IND );
      END LOOP;
      T_XXX := '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:xdr="http://schemas.openxmlformats.org/drawingml/2006/spreadsheetDrawing" xmlns:x14="http://schemas.microsoft.com/office/spreadsheetml/2009/9/main" xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006" mc:Ignorable="x14ac" xmlns:x14ac="http://schemas.microsoft.com/office/spreadsheetml/2009/9/ac">
<dimension ref="' || ALFAN_COL( T_COL_MIN ) || WORKBOOK.SHEETS( S ).ROWS.FIRST() || ':' || ALFAN_COL( T_COL_MAX ) || WORKBOOK.SHEETS( S ).ROWS.LAST() || '"/>
<sheetViews>
<sheetView' || CASE WHEN S = 1 THEN ' tabSelected="1"' END || ' workbookViewId="0">';
      IF WORKBOOK.SHEETS( S ).FREEZE_ROWS > 0 AND WORKBOOK.SHEETS( S ).FREEZE_COLS > 0
      THEN
        T_XXX := T_XXX || ( '<pane xSplit="' || WORKBOOK.SHEETS( S ).FREEZE_COLS || '" '
                          || 'ySplit="' || WORKBOOK.SHEETS( S ).FREEZE_ROWS || '" '
                          || 'topLeftCell="' || ALFAN_COL( WORKBOOK.SHEETS( S ).FREEZE_COLS + 1 ) || ( WORKBOOK.SHEETS( S ).FREEZE_ROWS + 1 ) || '" '
                          || 'activePane="bottomLeft" state="frozen"/>'
                          );
      ELSE
        IF WORKBOOK.SHEETS( S ).FREEZE_ROWS > 0
        THEN
          T_XXX := T_XXX || '<pane ySplit="' || WORKBOOK.SHEETS( S ).FREEZE_ROWS || '" topLeftCell="A' || ( WORKBOOK.SHEETS( S ).FREEZE_ROWS + 1 ) || '" activePane="bottomLeft" state="frozen"/>';
        END IF;
        IF WORKBOOK.SHEETS( S ).FREEZE_COLS > 0
        THEN
          T_XXX := T_XXX || '<pane xSplit="' || WORKBOOK.SHEETS( S ).FREEZE_COLS || '" topLeftCell="' || ALFAN_COL( WORKBOOK.SHEETS( S ).FREEZE_COLS + 1 ) || '1" activePane="bottomLeft" state="frozen"/>';
        END IF;
      END IF;
      T_XXX := T_XXX || '</sheetView>
</sheetViews>
<sheetFormatPr defaultRowHeight="15" x14ac:dyDescent="0.25"/>';
      IF WORKBOOK.SHEETS( S ).WIDTHS.COUNT() > 0
      THEN
        T_XXX := T_XXX || '<cols>';
        T_COL_IND := WORKBOOK.SHEETS( S ).WIDTHS.FIRST();
        WHILE T_COL_IND IS NOT NULL
        LOOP
          T_XXX := T_XXX ||
             '<col min="' || T_COL_IND || '" max="' || T_COL_IND || '" width="' || TO_CHAR( WORKBOOK.SHEETS( S ).WIDTHS( T_COL_IND ), 'TM9', 'NLS_NUMERIC_CHARACTERS=.,' ) || '" customWidth="1"/>';
          T_COL_IND := WORKBOOK.SHEETS( S ).WIDTHS.NEXT( T_COL_IND );
        END LOOP;
        T_XXX := T_XXX || '</cols>';
      END IF;
      T_XXX := T_XXX || '<sheetData>';
      T_ROW_IND := WORKBOOK.SHEETS( S ).ROWS.FIRST();
      T_TMP := NULL;
      WHILE T_ROW_IND IS NOT NULL
      LOOP
        T_TMP :=  T_TMP || '<row r="' || T_ROW_IND || '" spans="' || T_COL_MIN || ':' || T_COL_MAX || '">';
        T_LEN := LENGTH( T_TMP );
        T_COL_IND := WORKBOOK.SHEETS( S ).ROWS( T_ROW_IND ).FIRST();
        WHILE T_COL_IND IS NOT NULL
        LOOP
          T_CELL := '<c r="' || ALFAN_COL( T_COL_IND ) || T_ROW_IND || '"'
                 || ' ' || WORKBOOK.SHEETS( S ).ROWS( T_ROW_IND )( T_COL_IND ).STYLE
                 || '><v>'
                 || TO_CHAR( WORKBOOK.SHEETS( S ).ROWS( T_ROW_IND )( T_COL_IND ).VALUE, 'TM9', 'NLS_NUMERIC_CHARACTERS=.,' )
                 || '</v></c>';
          IF T_LEN > 32000
          THEN
            DBMS_LOB.WRITEAPPEND( T_XXX, T_LEN, T_TMP );
            T_TMP := NULL;
            T_LEN := 0;
          END IF;
          T_TMP :=  T_TMP || T_CELL;
          T_LEN := T_LEN + LENGTH( T_CELL );
          T_COL_IND := WORKBOOK.SHEETS( S ).ROWS( T_ROW_IND ).NEXT( T_COL_IND );
        END LOOP;
        T_TMP :=  T_TMP || '</row>';
        T_ROW_IND := WORKBOOK.SHEETS( S ).ROWS.NEXT( T_ROW_IND );
      END LOOP;
      T_TMP :=  T_TMP || '</sheetData>';
      T_LEN := LENGTH( T_TMP );
      DBMS_LOB.WRITEAPPEND( T_XXX, T_LEN, T_TMP );
      FOR A IN 1 ..  WORKBOOK.SHEETS( S ).AUTOFILTERS.COUNT()
      LOOP
        T_XXX := T_XXX || '<autoFilter ref="' ||
            ALFAN_COL( NVL( WORKBOOK.SHEETS( S ).AUTOFILTERS( A ).COLUMN_START, T_COL_MIN ) ) ||
            NVL( WORKBOOK.SHEETS( S ).AUTOFILTERS( A ).ROW_START, WORKBOOK.SHEETS( S ).ROWS.FIRST() ) || ':' ||
            ALFAN_COL( COALESCE( WORKBOOK.SHEETS( S ).AUTOFILTERS( A ).COLUMN_END, WORKBOOK.SHEETS( S ).AUTOFILTERS( A ).COLUMN_START, T_COL_MAX ) ) ||
            NVL( WORKBOOK.SHEETS( S ).AUTOFILTERS( A ).ROW_END, WORKBOOK.SHEETS( S ).ROWS.LAST() ) || '"/>';
      END LOOP;
      IF WORKBOOK.SHEETS( S ).MERGECELLS.COUNT() > 0
      THEN
        T_XXX := T_XXX || '<mergeCells count="' || TO_CHAR( WORKBOOK.SHEETS( S ).MERGECELLS.COUNT() ) || '">';
        FOR M IN 1 ..  WORKBOOK.SHEETS( S ).MERGECELLS.COUNT()
        LOOP
          T_XXX := T_XXX || '<mergeCell ref="' || WORKBOOK.SHEETS( S ).MERGECELLS( M ) || '"/>';
        END LOOP;
        T_XXX := T_XXX || '</mergeCells>';
      END IF;
--
      IF WORKBOOK.SHEETS( S ).VALIDATIONS.COUNT() > 0
      THEN
        T_XXX := T_XXX || '<dataValidations count="' || TO_CHAR( WORKBOOK.SHEETS( S ).VALIDATIONS.COUNT() ) || '">';
        FOR M IN 1 ..  WORKBOOK.SHEETS( S ).VALIDATIONS.COUNT()
        LOOP
          T_XXX := T_XXX || '<dataValidation' ||
              ' type="' || WORKBOOK.SHEETS( S ).VALIDATIONS( M ).TYPE || '"' ||
              ' errorStyle="' || WORKBOOK.SHEETS( S ).VALIDATIONS( M ).ERRORSTYLE || '"' ||
              ' allowBlank="' || CASE WHEN NVL( WORKBOOK.SHEETS( S ).VALIDATIONS( M ).ALLOWBLANK, TRUE ) THEN '1' ELSE '0' END || '"' ||
              ' sqref="' || WORKBOOK.SHEETS( S ).VALIDATIONS( M ).SQREF || '"';
          IF WORKBOOK.SHEETS( S ).VALIDATIONS( M ).PROMPT IS NOT NULL
          THEN
            T_XXX := T_XXX || ' showInputMessage="1" prompt="' || WORKBOOK.SHEETS( S ).VALIDATIONS( M ).PROMPT || '"';
            IF WORKBOOK.SHEETS( S ).VALIDATIONS( M ).TITLE IS NOT NULL
            THEN
              T_XXX := T_XXX || ' promptTitle="' || WORKBOOK.SHEETS( S ).VALIDATIONS( M ).TITLE || '"';
            END IF;
          END IF;
          IF WORKBOOK.SHEETS( S ).VALIDATIONS( M ).SHOWERRORMESSAGE
          THEN
            T_XXX := T_XXX || ' showErrorMessage="1"';
            IF WORKBOOK.SHEETS( S ).VALIDATIONS( M ).ERROR_TITLE IS NOT NULL
            THEN
              T_XXX := T_XXX || ' errorTitle="' || WORKBOOK.SHEETS( S ).VALIDATIONS( M ).ERROR_TITLE || '"';
            END IF;
            IF WORKBOOK.SHEETS( S ).VALIDATIONS( M ).ERROR_TXT IS NOT NULL
            THEN
              T_XXX := T_XXX || ' error="' || WORKBOOK.SHEETS( S ).VALIDATIONS( M ).ERROR_TXT || '"';
            END IF;
          END IF;
          T_XXX := T_XXX || '>';
          IF WORKBOOK.SHEETS( S ).VALIDATIONS( M ).FORMULA1 IS NOT NULL
          THEN
            T_XXX := T_XXX || '<formula1>' || WORKBOOK.SHEETS( S ).VALIDATIONS( M ).FORMULA1 || '</formula1>';
          END IF;
          IF WORKBOOK.SHEETS( S ).VALIDATIONS( M ).FORMULA2 IS NOT NULL
          THEN
            T_XXX := T_XXX || '<formula2>' || WORKBOOK.SHEETS( S ).VALIDATIONS( M ).FORMULA2 || '</formula2>';
          END IF;
          T_XXX := T_XXX || '</dataValidation>';
        END LOOP;
        T_XXX := T_XXX || '</dataValidations>';
      END IF;
--
      IF WORKBOOK.SHEETS( S ).HYPERLINKS.COUNT() > 0
      THEN
        T_XXX := T_XXX || '<hyperlinks>';
        FOR H IN 1 ..  WORKBOOK.SHEETS( S ).HYPERLINKS.COUNT()
        LOOP
          T_XXX := T_XXX || '<hyperlink ref="' || WORKBOOK.SHEETS( S ).HYPERLINKS( H ).CELL || '" r:id="rId' || H || '"/>';
        END LOOP;
        T_XXX := T_XXX || '</hyperlinks>';
      END IF;
      T_XXX := T_XXX || '<pageMargins left="0.7" right="0.7" top="0.75" bottom="0.75" header="0.3" footer="0.3"/>';
      IF WORKBOOK.SHEETS( S ).COMMENTS.COUNT() > 0
      THEN
        T_XXX := T_XXX || '<legacyDrawing r:id="rId' || ( WORKBOOK.SHEETS( S ).HYPERLINKS.COUNT() + 1 ) || '"/>';
      END IF;
--
      T_XXX := T_XXX || '</worksheet>';
      ADD1XML( T_EXCEL, 'xl/worksheets/sheet' || S || '.xml', T_XXX );
      IF WORKBOOK.SHEETS( S ).HYPERLINKS.COUNT() > 0 OR WORKBOOK.SHEETS( S ).COMMENTS.COUNT() > 0
      THEN
        T_XXX := '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">';
        IF WORKBOOK.SHEETS( S ).COMMENTS.COUNT() > 0
        THEN
          T_XXX := T_XXX || '<Relationship Id="rId' || ( WORKBOOK.SHEETS( S ).HYPERLINKS.COUNT() + 2 ) || '" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/comments" Target="../comments' || S || '.xml"/>';
          T_XXX := T_XXX || '<Relationship Id="rId' || ( WORKBOOK.SHEETS( S ).HYPERLINKS.COUNT() + 1 ) || '" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/vmlDrawing" Target="../drawings/vmlDrawing' || S || '.vml"/>';
        END IF;
        FOR H IN 1 ..  WORKBOOK.SHEETS( S ).HYPERLINKS.COUNT()
        LOOP
          T_XXX := T_XXX || '<Relationship Id="rId' || H || '" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/hyperlink" Target="' || WORKBOOK.SHEETS( S ).HYPERLINKS( H ).URL || '" TargetMode="External"/>';
        END LOOP;
        T_XXX := T_XXX || '</Relationships>';
        ADD1XML( T_EXCEL, 'xl/worksheets/_rels/sheet' || S || '.xml.rels', T_XXX );
      END IF;
--
      IF WORKBOOK.SHEETS( S ).COMMENTS.COUNT() > 0
      THEN
        DECLARE
          CNT PLS_INTEGER;
          AUTHOR_IND TP_AUTHOR;
--          t_col_ind := workbook.sheets( s ).widths.next( t_col_ind );
        BEGIN
          AUTHORS.DELETE();
          FOR C IN 1 .. WORKBOOK.SHEETS( S ).COMMENTS.COUNT()
          LOOP
            AUTHORS( WORKBOOK.SHEETS( S ).COMMENTS( C ).AUTHOR ) := 0;
          END LOOP;
          T_XXX := '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<comments xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
<authors>';
          CNT := 0;
          AUTHOR_IND := AUTHORS.FIRST();
          WHILE AUTHOR_IND IS NOT NULL OR AUTHORS.NEXT( AUTHOR_IND ) IS NOT NULL
          LOOP
            AUTHORS( AUTHOR_IND ) := CNT;
            T_XXX := T_XXX || '<author>' || AUTHOR_IND || '</author>';
            CNT := CNT + 1;
            AUTHOR_IND := AUTHORS.NEXT( AUTHOR_IND );
          END LOOP;
        END;
        T_XXX := T_XXX || '</authors><commentList>';
        FOR C IN 1 .. WORKBOOK.SHEETS( S ).COMMENTS.COUNT()
        LOOP
          T_XXX := T_XXX || '<comment ref="' || ALFAN_COL( WORKBOOK.SHEETS( S ).COMMENTS( C ).COLUMN ) ||
             TO_CHAR( WORKBOOK.SHEETS( S ).COMMENTS( C ).ROW || '" authorId="' || AUTHORS( WORKBOOK.SHEETS( S ).COMMENTS( C ).AUTHOR ) ) || '">
<text>';
          IF WORKBOOK.SHEETS( S ).COMMENTS( C ).AUTHOR IS NOT NULL
          THEN
            T_XXX := T_XXX || '<r><rPr><b/><sz val="9"/><color indexed="81"/><rFont val="Tahoma"/><charset val="1"/></rPr><t xml:space="preserve">' ||
               WORKBOOK.SHEETS( S ).COMMENTS( C ).AUTHOR || ':</t></r>';
          END IF;
          T_XXX := T_XXX || '<r><rPr><sz val="9"/><color indexed="81"/><rFont val="Tahoma"/><charset val="1"/></rPr><t xml:space="preserve">' ||
             CASE WHEN WORKBOOK.SHEETS( S ).COMMENTS( C ).AUTHOR IS NOT NULL THEN '
' END || WORKBOOK.SHEETS( S ).COMMENTS( C ).TEXT || '</t></r></text></comment>';
        END LOOP;
        T_XXX := T_XXX || '</commentList></comments>';
        ADD1XML( T_EXCEL, 'xl/comments' || S || '.xml', T_XXX );
        T_XXX := '<xml xmlns:v="urn:schemas-microsoft-com:vml" xmlns:o="urn:schemas-microsoft-com:office:office" xmlns:x="urn:schemas-microsoft-com:office:excel">
<o:shapelayout v:ext="edit"><o:idmap v:ext="edit" data="2"/></o:shapelayout>
<v:shapetype id="_x0000_t202" coordsize="21600,21600" o:spt="202" path="m,l,21600r21600,l21600,xe"><v:stroke joinstyle="miter"/><v:path gradientshapeok="t" o:connecttype="rect"/></v:shapetype>';
        FOR C IN 1 .. WORKBOOK.SHEETS( S ).COMMENTS.COUNT()
        LOOP
          T_XXX := T_XXX || '<v:shape id="_x0000_s' || TO_CHAR( C ) || '" type="#_x0000_t202"
style="position:absolute;margin-left:35.25pt;margin-top:3pt;z-index:' || TO_CHAR( C ) || ';visibility:hidden;" fillcolor="#ffffe1" o:insetmode="auto">
<v:fill color2="#ffffe1"/><v:shadow on="t" color="black" obscured="t"/><v:path o:connecttype="none"/>
<v:textbox style="mso-direction-alt:auto"><div style="text-align:left"></div></v:textbox>
<x:ClientData ObjectType="Note"><x:MoveWithCells/><x:SizeWithCells/>';
          T_W := WORKBOOK.SHEETS( S ).COMMENTS( C ).WIDTH;
          T_C := 1;
          LOOP
            IF WORKBOOK.SHEETS( S ).WIDTHS.EXISTS( WORKBOOK.SHEETS( S ).COMMENTS( C ).COLUMN + T_C )
            THEN
              T_CW := 256 * WORKBOOK.SHEETS( S ).WIDTHS( WORKBOOK.SHEETS( S ).COMMENTS( C ).COLUMN + T_C ); 
              T_CW := TRUNC( ( T_CW + 18 ) / 256 * 7); -- assume default 11 point Calibri
            ELSE
              T_CW := 64;
            END IF;
            EXIT WHEN T_W < T_CW;
            T_C := T_C + 1;
            T_W := T_W - T_CW;
          END LOOP;
          T_H := WORKBOOK.SHEETS( S ).COMMENTS( C ).HEIGHT;
          T_XXX := T_XXX || TO_CHAR( '<x:Anchor>' || WORKBOOK.SHEETS( S ).COMMENTS( C ).COLUMN || ',15,' ||
                     WORKBOOK.SHEETS( S ).COMMENTS( C ).ROW || ',30,' ||
                     ( WORKBOOK.SHEETS( S ).COMMENTS( C ).COLUMN + T_C - 1 ) || ',' || ROUND( T_W ) || ',' ||
                     ( WORKBOOK.SHEETS( S ).COMMENTS( C ).ROW + 1 + TRUNC( T_H / 20 ) ) || ',' || MOD( T_H, 20 ) || '</x:Anchor>' );
          T_XXX := T_XXX || TO_CHAR( '<x:AutoFill>False</x:AutoFill><x:Row>' ||
            ( WORKBOOK.SHEETS( S ).COMMENTS( C ).ROW - 1 ) || '</x:Row><x:Column>' ||
            ( WORKBOOK.SHEETS( S ).COMMENTS( C ).COLUMN - 1 ) || '</x:Column></x:ClientData></v:shape>' );
        END LOOP;
        T_XXX := T_XXX || '</xml>';
        ADD1XML( T_EXCEL, 'xl/drawings/vmlDrawing' || S || '.vml', T_XXX );
      END IF;
--
    END LOOP;
    T_XXX := '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/sharedStrings" Target="sharedStrings.xml"/>
<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
<Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme" Target="theme/theme1.xml"/>';
    FOR S IN 1 .. WORKBOOK.SHEETS.COUNT()
    LOOP
      T_XXX := T_XXX || '
<Relationship Id="rId' || ( 9 + S ) || '" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet' || S || '.xml"/>';
    END LOOP;
    T_XXX := T_XXX || '</Relationships>';
    ADD1XML( T_EXCEL, 'xl/_rels/workbook.xml.rels', T_XXX );
    T_XXX := '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" count="' || WORKBOOK.STR_CNT || '" uniqueCount="' || WORKBOOK.STRINGS.COUNT() || '">';
    T_TMP := NULL;
    FOR I IN 0 .. WORKBOOK.STR_IND.COUNT() - 1
    LOOP
      T_STR := '<si><t>' || DBMS_XMLGEN.CONVERT( SUBSTR( WORKBOOK.STR_IND( I ), 1, 32000 ) ) || '</t></si>';
      IF LENGTH( T_TMP ) + LENGTH( T_STR ) > 32000
      THEN
        T_XXX := T_XXX || T_TMP;
        T_TMP := NULL;
      END IF;
      T_TMP := T_TMP || T_STR;
    END LOOP;
    T_XXX := T_XXX || T_TMP || '</sst>';
    ADD1XML( T_EXCEL, 'xl/sharedStrings.xml', T_XXX );
    FINISH_ZIP( T_EXCEL );
    CLEAR_WORKBOOK;
    RETURN T_EXCEL;
  END;
--
------------------------------------------------------------------------------------------------
FUNCTION EXCEL_CONTENT
  RETURN BLOB
  IS
    T_EXCEL BLOB;
    T_XXX CLOB;
    T_TMP VARCHAR2(32767 CHAR);
    T_STR VARCHAR2(32767 CHAR);
    T_C NUMBER;
    T_H NUMBER;
    T_W NUMBER;
    T_CW NUMBER;
    T_CELL VARCHAR2(1000 CHAR);
    T_ROW_IND PLS_INTEGER;
    T_COL_MIN PLS_INTEGER;
    T_COL_MAX PLS_INTEGER;
    T_COL_IND PLS_INTEGER;
    T_LEN PLS_INTEGER;
TS TIMESTAMP := SYSTIMESTAMP;
  BEGIN
    DBMS_LOB.CREATETEMPORARY( T_EXCEL, TRUE );
    T_XXX := '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
<Default Extension="xml" ContentType="application/xml"/>
<Default Extension="vml" ContentType="application/vnd.openxmlformats-officedocument.vmlDrawing"/>
<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>';
    FOR S IN 1 .. WORKBOOK.SHEETS.COUNT()
    LOOP
      T_XXX := T_XXX || '
<Override PartName="/xl/worksheets/sheet' || S || '.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>';
    END LOOP;
    T_XXX := T_XXX || '
<Override PartName="/xl/theme/theme1.xml" ContentType="application/vnd.openxmlformats-officedocument.theme+xml"/>
<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
<Override PartName="/xl/sharedStrings.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml"/>
<Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>
<Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>';
    FOR S IN 1 .. WORKBOOK.SHEETS.COUNT()
    LOOP
      IF WORKBOOK.SHEETS( S ).COMMENTS.COUNT() > 0
      THEN
        T_XXX := T_XXX || '
<Override PartName="/xl/comments' || S || '.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.comments+xml"/>';
      END IF;
    END LOOP;
    T_XXX := T_XXX || '
</Types>';
    ADD1XML( T_EXCEL, '[Content_Types].xml', T_XXX );
    T_XXX := '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:dcmitype="http://purl.org/dc/dcmitype/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
<dc:creator>' || SYS_CONTEXT( 'userenv', 'os_user' ) || '</dc:creator>
<cp:lastModifiedBy>' || SYS_CONTEXT( 'userenv', 'os_user' ) || '</cp:lastModifiedBy>
<dcterms:created xsi:type="dcterms:W3CDTF">' || TO_CHAR( CURRENT_TIMESTAMP, 'yyyy-mm-dd"T"hh24:mi:ssTZH:TZM' ) || '</dcterms:created>
<dcterms:modified xsi:type="dcterms:W3CDTF">' || TO_CHAR( CURRENT_TIMESTAMP, 'yyyy-mm-dd"T"hh24:mi:ssTZH:TZM' ) || '</dcterms:modified>
</cp:coreProperties>';
    ADD1XML( T_EXCEL, 'docProps/core.xml', T_XXX );
    T_XXX := '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">
<Application>Microsoft Excel</Application>
<DocSecurity>0</DocSecurity>
<ScaleCrop>false</ScaleCrop>
<HeadingPairs>
<vt:vector size="2" baseType="variant">
<vt:variant>
<vt:lpstr>Worksheets</vt:lpstr>
</vt:variant>
<vt:variant>
<vt:i4>' || WORKBOOK.SHEETS.COUNT() || '</vt:i4>
</vt:variant>
</vt:vector>
</HeadingPairs>
<TitlesOfParts>
<vt:vector size="' || WORKBOOK.SHEETS.COUNT() || '" baseType="lpstr">';
    FOR S IN 1 .. WORKBOOK.SHEETS.COUNT()
    LOOP
      T_XXX := T_XXX || '
<vt:lpstr>' || WORKBOOK.SHEETS( S ).NAME || '</vt:lpstr>';
    END LOOP;
    T_XXX := T_XXX || '</vt:vector>
</TitlesOfParts>
<LinksUpToDate>false</LinksUpToDate>
<SharedDoc>false</SharedDoc>
<HyperlinksChanged>false</HyperlinksChanged>
<AppVersion>14.0300</AppVersion>
</Properties>';
    ADD1XML( T_EXCEL, 'docProps/app.xml', T_XXX );
    T_XXX := '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>
<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
</Relationships>';
    ADD1XML( T_EXCEL, '_rels/.rels', T_XXX );
    T_XXX := '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006" mc:Ignorable="x14ac" xmlns:x14ac="http://schemas.microsoft.com/office/spreadsheetml/2009/9/ac">';
    IF WORKBOOK.NUMFMTS.COUNT() > 0
    THEN
      T_XXX := T_XXX || '<numFmts count="' || WORKBOOK.NUMFMTS.COUNT() || '">';
      FOR N IN 1 .. WORKBOOK.NUMFMTS.COUNT()
      LOOP
        T_XXX := T_XXX || '<numFmt numFmtId="' || WORKBOOK.NUMFMTS( N ).NUMFMTID || '" formatCode="' || WORKBOOK.NUMFMTS( N ).FORMATCODE || '"/>';
      END LOOP;
      T_XXX := T_XXX || '</numFmts>';
    END IF;
    T_XXX := T_XXX || '<fonts count="' || WORKBOOK.FONTS.COUNT() || '" x14ac:knownFonts="1">';
    FOR F IN 0 .. WORKBOOK.FONTS.COUNT() - 1
    LOOP
      T_XXX := T_XXX || '<font>' || 
        CASE WHEN WORKBOOK.FONTS( F ).BOLD THEN '<b/>' END ||
        CASE WHEN WORKBOOK.FONTS( F ).ITALIC THEN '<i/>' END ||
        CASE WHEN WORKBOOK.FONTS( F ).UNDERLINE THEN '<u/>' END ||
'<sz val="' || TO_CHAR( WORKBOOK.FONTS( F ).FONTSIZE, 'TM9', 'NLS_NUMERIC_CHARACTERS=.,' )  || '"/>
<color ' || CASE WHEN WORKBOOK.FONTS( F ).RGB IS NOT NULL
              THEN 'rgb="' || WORKBOOK.FONTS( F ).RGB
              ELSE 'theme="' || WORKBOOK.FONTS( F ).THEME
            END || '"/>
<name val="' || WORKBOOK.FONTS( F ).NAME || '"/>
<family val="' || WORKBOOK.FONTS( F ).FAMILY || '"/>
<scheme val="none"/>
</font>';
    END LOOP;
    T_XXX := T_XXX || '</fonts>
<fills count="' || WORKBOOK.FILLS.COUNT() || '">';
    FOR F IN 0 .. WORKBOOK.FILLS.COUNT() - 1
    LOOP
      T_XXX := T_XXX || '<fill><patternFill patternType="' || WORKBOOK.FILLS( F ).PATTERNTYPE || '">' ||
         CASE WHEN WORKBOOK.FILLS( F ).FGRGB IS NOT NULL THEN '<fgColor rgb="' || WORKBOOK.FILLS( F ).FGRGB || '"/>' END ||
         '</patternFill></fill>';
    END LOOP;
    T_XXX := T_XXX || '</fills>
<borders count="' || WORKBOOK.BORDERS.COUNT() || '">';
    FOR B IN 0 .. WORKBOOK.BORDERS.COUNT() - 1
    LOOP
      T_XXX := T_XXX || '<border>' ||
         CASE WHEN WORKBOOK.BORDERS( B ).LEFT   IS NULL THEN '<left/>'   ELSE '<left style="'   || WORKBOOK.BORDERS( B ).LEFT   || '"/>' END ||
         CASE WHEN WORKBOOK.BORDERS( B ).RIGHT  IS NULL THEN '<right/>'  ELSE '<right style="'  || WORKBOOK.BORDERS( B ).RIGHT  || '"/>' END ||
         CASE WHEN WORKBOOK.BORDERS( B ).TOP    IS NULL THEN '<top/>'    ELSE '<top style="'    || WORKBOOK.BORDERS( B ).TOP    || '"/>' END ||
         CASE WHEN WORKBOOK.BORDERS( B ).BOTTOM IS NULL THEN '<bottom/>' ELSE '<bottom style="' || WORKBOOK.BORDERS( B ).BOTTOM || '"/>' END ||
         '</border>';
    END LOOP;
    T_XXX := T_XXX || '</borders>
<cellStyleXfs count="1">
<xf numFmtId="0" fontId="0" fillId="0" borderId="0"/>
</cellStyleXfs>
<cellXfs count="' || ( WORKBOOK.CELLXFS.COUNT() + 1 ) || '">
<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>';
    FOR X IN 1 .. WORKBOOK.CELLXFS.COUNT()
    LOOP
      T_XXX := T_XXX || '<xf numFmtId="' || WORKBOOK.CELLXFS( X ).NUMFMTID || '" fontId="' || WORKBOOK.CELLXFS( X ).FONTID || '" fillId="' || WORKBOOK.CELLXFS( X ).FILLID || '" borderId="' || WORKBOOK.CELLXFS( X ).BORDERID || '">';
      IF (  WORKBOOK.CELLXFS( X ).ALIGNMENT.HORIZONTAL IS NOT NULL
         OR WORKBOOK.CELLXFS( X ).ALIGNMENT.VERTICAL IS NOT NULL
         OR WORKBOOK.CELLXFS( X ).ALIGNMENT.WRAPTEXT
         )
      THEN
        T_XXX := T_XXX || '<alignment' ||
          CASE WHEN WORKBOOK.CELLXFS( X ).ALIGNMENT.HORIZONTAL IS NOT NULL THEN ' horizontal="' || WORKBOOK.CELLXFS( X ).ALIGNMENT.HORIZONTAL || '"' END ||
          CASE WHEN WORKBOOK.CELLXFS( X ).ALIGNMENT.VERTICAL IS NOT NULL THEN ' vertical="' || WORKBOOK.CELLXFS( X ).ALIGNMENT.VERTICAL || '"' END ||
          CASE WHEN WORKBOOK.CELLXFS( X ).ALIGNMENT.WRAPTEXT THEN ' wrapText="true"' END || '/>';
      END IF;
      T_XXX := T_XXX || '</xf>';
    END LOOP;
    T_XXX := T_XXX || '</cellXfs>
<cellStyles count="1">
<cellStyle name="Normal" xfId="0" builtinId="0"/>
</cellStyles>
<dxfs count="0"/>
<tableStyles count="0" defaultTableStyle="TableStyleMedium2" defaultPivotStyle="PivotStyleLight16"/>
<extLst>
<ext uri="{EB79DEF2-80B8-43e5-95BD-54CBDDF9020C}" xmlns:x14="http://schemas.microsoft.com/office/spreadsheetml/2009/9/main">
<x14:slicerStyles defaultSlicerStyle="SlicerStyleLight1"/>
</ext>
</extLst>
</styleSheet>';
    ADD1XML( T_EXCEL, 'xl/styles.xml', T_XXX );
    T_XXX := '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
<fileVersion appName="xl" lastEdited="5" lowestEdited="5" rupBuild="9302"/>
<workbookPr date1904="true" defaultThemeVersion="124226"/>
<bookViews>
<workbookView xWindow="120" yWindow="45" windowWidth="19155" windowHeight="4935"/>
</bookViews>
<sheets>';
    FOR S IN 1 .. WORKBOOK.SHEETS.COUNT()
    LOOP
      T_XXX := T_XXX || '
<sheet name="' || WORKBOOK.SHEETS( S ).NAME || '" sheetId="' || S || '" r:id="rId' || ( 9 + S ) || '"/>';
    END LOOP;
    T_XXX := T_XXX || '</sheets>';
    IF WORKBOOK.DEFINED_NAMES.COUNT() > 0
    THEN
      T_XXX := T_XXX || '<definedNames>';
      FOR S IN 1 .. WORKBOOK.DEFINED_NAMES.COUNT()
      LOOP
        T_XXX := T_XXX || '
<definedName name="' || WORKBOOK.DEFINED_NAMES( S ).NAME || '"' ||
            CASE WHEN WORKBOOK.DEFINED_NAMES( S ).SHEET IS NOT NULL THEN ' localSheetId="' || TO_CHAR( WORKBOOK.DEFINED_NAMES( S ).SHEET ) || '"' END ||
            '>' || WORKBOOK.DEFINED_NAMES( S ).REF || '</definedName>';
      END LOOP;
      T_XXX := T_XXX || '</definedNames>';
    END IF;
    T_XXX := T_XXX || '<calcPr calcId="144525"/></workbook>';
    ADD1XML( T_EXCEL, 'xl/workbook.xml', T_XXX );
    T_XXX := '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<a:theme xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" name="Office Theme">
<a:themeElements>
<a:clrScheme name="Office">
<a:dk1>
<a:sysClr val="windowText" lastClr="000000"/>
</a:dk1>
<a:lt1>
<a:sysClr val="window" lastClr="FFFFFF"/>
</a:lt1>
<a:dk2>
<a:srgbClr val="1F497D"/>
</a:dk2>
<a:lt2>
<a:srgbClr val="EEECE1"/>
</a:lt2>
<a:accent1>
<a:srgbClr val="4F81BD"/>
</a:accent1>
<a:accent2>
<a:srgbClr val="C0504D"/>
</a:accent2>
<a:accent3>
<a:srgbClr val="9BBB59"/>
</a:accent3>
<a:accent4>
<a:srgbClr val="8064A2"/>
</a:accent4>
<a:accent5>
<a:srgbClr val="4BACC6"/>
</a:accent5>
<a:accent6>
<a:srgbClr val="F79646"/>
</a:accent6>
<a:hlink>
<a:srgbClr val="0000FF"/>
</a:hlink>
<a:folHlink>
<a:srgbClr val="800080"/>
</a:folHlink>
</a:clrScheme>
<a:fontScheme name="Office">
<a:majorFont>
<a:latin typeface="Cambria"/>
<a:ea typeface=""/>
<a:cs typeface=""/>
<a:font script="Jpan" typeface="MS P????"/>
<a:font script="Hang" typeface="?? ??"/>
<a:font script="Hans" typeface="??"/>
<a:font script="Hant" typeface="????"/>
<a:font script="Arab" typeface="Times New Roman"/>
<a:font script="Hebr" typeface="Times New Roman"/>
<a:font script="Thai" typeface="Tahoma"/>
<a:font script="Ethi" typeface="Nyala"/>
<a:font script="Beng" typeface="Vrinda"/>
<a:font script="Gujr" typeface="Shruti"/>
<a:font script="Khmr" typeface="MoolBoran"/>
<a:font script="Knda" typeface="Tunga"/>
<a:font script="Guru" typeface="Raavi"/>
<a:font script="Cans" typeface="Euphemia"/>
<a:font script="Cher" typeface="Plantagenet Cherokee"/>
<a:font script="Yiii" typeface="Microsoft Yi Baiti"/>
<a:font script="Tibt" typeface="Microsoft Himalaya"/>
<a:font script="Thaa" typeface="MV Boli"/>
<a:font script="Deva" typeface="Mangal"/>
<a:font script="Telu" typeface="Gautami"/>
<a:font script="Taml" typeface="Latha"/>
<a:font script="Syrc" typeface="Estrangelo Edessa"/>
<a:font script="Orya" typeface="Kalinga"/>
<a:font script="Mlym" typeface="Kartika"/>
<a:font script="Laoo" typeface="DokChampa"/>
<a:font script="Sinh" typeface="Iskoola Pota"/>
<a:font script="Mong" typeface="Mongolian Baiti"/>
<a:font script="Viet" typeface="Times New Roman"/>
<a:font script="Uigh" typeface="Microsoft Uighur"/>
<a:font script="Geor" typeface="Sylfaen"/>
</a:majorFont>
<a:minorFont>
<a:latin typeface="Calibri"/>
<a:ea typeface=""/>
<a:cs typeface=""/>
<a:font script="Jpan" typeface="MS P????"/>
<a:font script="Hang" typeface="?? ??"/>
<a:font script="Hans" typeface="??"/>
<a:font script="Hant" typeface="????"/>
<a:font script="Arab" typeface="Arial"/>
<a:font script="Hebr" typeface="Arial"/>
<a:font script="Thai" typeface="Tahoma"/>
<a:font script="Ethi" typeface="Nyala"/>
<a:font script="Beng" typeface="Vrinda"/>
<a:font script="Gujr" typeface="Shruti"/>
<a:font script="Khmr" typeface="DaunPenh"/>
<a:font script="Knda" typeface="Tunga"/>
<a:font script="Guru" typeface="Raavi"/>
<a:font script="Cans" typeface="Euphemia"/>
<a:font script="Cher" typeface="Plantagenet Cherokee"/>
<a:font script="Yiii" typeface="Microsoft Yi Baiti"/>
<a:font script="Tibt" typeface="Microsoft Himalaya"/>
<a:font script="Thaa" typeface="MV Boli"/>
<a:font script="Deva" typeface="Mangal"/>
<a:font script="Telu" typeface="Gautami"/>
<a:font script="Taml" typeface="Latha"/>
<a:font script="Syrc" typeface="Estrangelo Edessa"/>
<a:font script="Orya" typeface="Kalinga"/>
<a:font script="Mlym" typeface="Kartika"/>
<a:font script="Laoo" typeface="DokChampa"/>
<a:font script="Sinh" typeface="Iskoola Pota"/>
<a:font script="Mong" typeface="Mongolian Baiti"/>
<a:font script="Viet" typeface="Arial"/>
<a:font script="Uigh" typeface="Microsoft Uighur"/>
<a:font script="Geor" typeface="Sylfaen"/>
</a:minorFont>
</a:fontScheme>
<a:fmtScheme name="Office">
<a:fillStyleLst>
<a:solidFill>
<a:schemeClr val="phClr"/>
</a:solidFill>
<a:gradFill rotWithShape="1">
<a:gsLst>
<a:gs pos="0">
<a:schemeClr val="phClr">
<a:tint val="50000"/>
<a:satMod val="300000"/>
</a:schemeClr>
</a:gs>
<a:gs pos="35000">
<a:schemeClr val="phClr">
<a:tint val="37000"/>
<a:satMod val="300000"/>
</a:schemeClr>
</a:gs>
<a:gs pos="100000">
<a:schemeClr val="phClr">
<a:tint val="15000"/>
<a:satMod val="350000"/>
</a:schemeClr>
</a:gs>
</a:gsLst>
<a:lin ang="16200000" scaled="1"/>
</a:gradFill>
<a:gradFill rotWithShape="1">
<a:gsLst>
<a:gs pos="0">
<a:schemeClr val="phClr">
<a:shade val="51000"/>
<a:satMod val="130000"/>
</a:schemeClr>
</a:gs>
<a:gs pos="80000">
<a:schemeClr val="phClr">
<a:shade val="93000"/>
<a:satMod val="130000"/>
</a:schemeClr>
</a:gs>
<a:gs pos="100000">
<a:schemeClr val="phClr">
<a:shade val="94000"/>
<a:satMod val="135000"/>
</a:schemeClr>
</a:gs>
</a:gsLst>
<a:lin ang="16200000" scaled="0"/>
</a:gradFill>
</a:fillStyleLst>
<a:lnStyleLst>
<a:ln w="9525" cap="flat" cmpd="sng" algn="ctr">
<a:solidFill>
<a:schemeClr val="phClr">
<a:shade val="95000"/>
<a:satMod val="105000"/>
</a:schemeClr>
</a:solidFill>
<a:prstDash val="solid"/>
</a:ln>
<a:ln w="25400" cap="flat" cmpd="sng" algn="ctr">
<a:solidFill>
<a:schemeClr val="phClr"/>
</a:solidFill>
<a:prstDash val="solid"/>
</a:ln>
<a:ln w="38100" cap="flat" cmpd="sng" algn="ctr">
<a:solidFill>
<a:schemeClr val="phClr"/>
</a:solidFill>
<a:prstDash val="solid"/>
</a:ln>
</a:lnStyleLst>
<a:effectStyleLst>
<a:effectStyle>
<a:effectLst>
<a:outerShdw blurRad="40000" dist="20000" dir="5400000" rotWithShape="0">
<a:srgbClr val="000000">
<a:alpha val="38000"/>
</a:srgbClr>
</a:outerShdw>
</a:effectLst>
</a:effectStyle>
<a:effectStyle>
<a:effectLst>
<a:outerShdw blurRad="40000" dist="23000" dir="5400000" rotWithShape="0">
<a:srgbClr val="000000">
<a:alpha val="35000"/>
</a:srgbClr>
</a:outerShdw>
</a:effectLst>
</a:effectStyle>
<a:effectStyle>
<a:effectLst>
<a:outerShdw blurRad="40000" dist="23000" dir="5400000" rotWithShape="0">
<a:srgbClr val="000000">
<a:alpha val="35000"/>
</a:srgbClr>
</a:outerShdw>
</a:effectLst>
<a:scene3d>
<a:camera prst="orthographicFront">
<a:rot lat="0" lon="0" rev="0"/>
</a:camera>
<a:lightRig rig="threePt" dir="t">
<a:rot lat="0" lon="0" rev="1200000"/>
</a:lightRig>
</a:scene3d>
<a:sp3d>
<a:bevelT w="63500" h="25400"/>
</a:sp3d>
</a:effectStyle>
</a:effectStyleLst>
<a:bgFillStyleLst>
<a:solidFill>
<a:schemeClr val="phClr"/>
</a:solidFill>
<a:gradFill rotWithShape="1">
<a:gsLst>
<a:gs pos="0">
<a:schemeClr val="phClr">
<a:tint val="40000"/>
<a:satMod val="350000"/>
</a:schemeClr>
</a:gs>
<a:gs pos="40000">
<a:schemeClr val="phClr">
<a:tint val="45000"/>
<a:shade val="99000"/>
<a:satMod val="350000"/>
</a:schemeClr>
</a:gs>
<a:gs pos="100000">
<a:schemeClr val="phClr">
<a:shade val="20000"/>
<a:satMod val="255000"/>
</a:schemeClr>
</a:gs>
</a:gsLst>
<a:path path="circle">
<a:fillToRect l="50000" t="-80000" r="50000" b="180000"/>
</a:path>
</a:gradFill>
<a:gradFill rotWithShape="1">
<a:gsLst>
<a:gs pos="0">
<a:schemeClr val="phClr">
<a:tint val="80000"/>
<a:satMod val="300000"/>
</a:schemeClr>
</a:gs>
<a:gs pos="100000">
<a:schemeClr val="phClr">
<a:shade val="30000"/>
<a:satMod val="200000"/>
</a:schemeClr>
</a:gs>
</a:gsLst>
<a:path path="circle">
<a:fillToRect l="50000" t="50000" r="50000" b="50000"/>
</a:path>
</a:gradFill>
</a:bgFillStyleLst>
</a:fmtScheme>
</a:themeElements>
<a:objectDefaults/>
<a:extraClrSchemeLst/>
</a:theme>';
    ADD1XML( T_EXCEL, 'xl/theme/theme1.xml', T_XXX );
    FOR S IN 1 .. WORKBOOK.SHEETS.COUNT()
    LOOP
      T_COL_MIN := 16384;
      T_COL_MAX := 1;
      T_ROW_IND := WORKBOOK.SHEETS( S ).ROWS.FIRST();
      WHILE T_ROW_IND IS NOT NULL
      LOOP
        T_COL_MIN := LEAST( T_COL_MIN, WORKBOOK.SHEETS( S ).ROWS( T_ROW_IND ).FIRST() );
        T_COL_MAX := GREATEST( T_COL_MAX, WORKBOOK.SHEETS( S ).ROWS( T_ROW_IND ).LAST() );
        T_ROW_IND := WORKBOOK.SHEETS( S ).ROWS.NEXT( T_ROW_IND );
      END LOOP;
      T_XXX := '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:xdr="http://schemas.openxmlformats.org/drawingml/2006/spreadsheetDrawing" xmlns:x14="http://schemas.microsoft.com/office/spreadsheetml/2009/9/main" xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006" mc:Ignorable="x14ac" xmlns:x14ac="http://schemas.microsoft.com/office/spreadsheetml/2009/9/ac">
<dimension ref="' || ALFAN_COL( T_COL_MIN ) || WORKBOOK.SHEETS( S ).ROWS.FIRST() || ':' || ALFAN_COL( T_COL_MAX ) || WORKBOOK.SHEETS( S ).ROWS.LAST() || '"/>
<sheetViews>
<sheetView' || CASE WHEN S = 1 THEN ' tabSelected="1"' END || ' workbookViewId="0">';
      IF WORKBOOK.SHEETS( S ).FREEZE_ROWS > 0 AND WORKBOOK.SHEETS( S ).FREEZE_COLS > 0
      THEN
        T_XXX := T_XXX || ( '<pane xSplit="' || WORKBOOK.SHEETS( S ).FREEZE_COLS || '" '
                          || 'ySplit="' || WORKBOOK.SHEETS( S ).FREEZE_ROWS || '" '
                          || 'topLeftCell="' || ALFAN_COL( WORKBOOK.SHEETS( S ).FREEZE_COLS + 1 ) || ( WORKBOOK.SHEETS( S ).FREEZE_ROWS + 1 ) || '" '
                          || 'activePane="bottomLeft" state="frozen"/>'
                          );
      ELSE
        IF WORKBOOK.SHEETS( S ).FREEZE_ROWS > 0
        THEN
          T_XXX := T_XXX || '<pane ySplit="' || WORKBOOK.SHEETS( S ).FREEZE_ROWS || '" topLeftCell="A' || ( WORKBOOK.SHEETS( S ).FREEZE_ROWS + 1 ) || '" activePane="bottomLeft" state="frozen"/>';
        END IF;
        IF WORKBOOK.SHEETS( S ).FREEZE_COLS > 0
        THEN
          T_XXX := T_XXX || '<pane xSplit="' || WORKBOOK.SHEETS( S ).FREEZE_COLS || '" topLeftCell="' || ALFAN_COL( WORKBOOK.SHEETS( S ).FREEZE_COLS + 1 ) || '1" activePane="bottomLeft" state="frozen"/>';
        END IF;
      END IF;
      T_XXX := T_XXX || '</sheetView>
</sheetViews>
<sheetFormatPr defaultRowHeight="15" x14ac:dyDescent="0.25"/>';
      IF WORKBOOK.SHEETS( S ).WIDTHS.COUNT() > 0
      THEN
        T_XXX := T_XXX || '<cols>';
        T_COL_IND := WORKBOOK.SHEETS( S ).WIDTHS.FIRST();
        WHILE T_COL_IND IS NOT NULL
        LOOP
          T_XXX := T_XXX ||
             '<col min="' || T_COL_IND || '" max="' || T_COL_IND || '" width="' || TO_CHAR( WORKBOOK.SHEETS( S ).WIDTHS( T_COL_IND ), 'TM9', 'NLS_NUMERIC_CHARACTERS=.,' ) || '" customWidth="1"/>';
          T_COL_IND := WORKBOOK.SHEETS( S ).WIDTHS.NEXT( T_COL_IND );
        END LOOP;
        T_XXX := T_XXX || '</cols>';
      END IF;
      T_XXX := T_XXX || '<sheetData>';
      T_ROW_IND := WORKBOOK.SHEETS( S ).ROWS.FIRST();
      T_TMP := NULL;
      WHILE T_ROW_IND IS NOT NULL
      LOOP
        T_TMP :=  T_TMP || '<row r="' || T_ROW_IND || '" spans="' || T_COL_MIN || ':' || T_COL_MAX || '">';
        T_LEN := LENGTH( T_TMP );
        T_COL_IND := WORKBOOK.SHEETS( S ).ROWS( T_ROW_IND ).FIRST();
        WHILE T_COL_IND IS NOT NULL
        LOOP
          T_CELL := '<c r="' || ALFAN_COL( T_COL_IND ) || T_ROW_IND || '"'
                 || ' ' || WORKBOOK.SHEETS( S ).ROWS( T_ROW_IND )( T_COL_IND ).STYLE
                 || '><v>'
                 || TO_CHAR( WORKBOOK.SHEETS( S ).ROWS( T_ROW_IND )( T_COL_IND ).VALUE, 'TM9', 'NLS_NUMERIC_CHARACTERS=.,' )
                 || '</v></c>';
          IF T_LEN > 32000
          THEN
            DBMS_LOB.WRITEAPPEND( T_XXX, T_LEN, T_TMP );
            T_TMP := NULL;
            T_LEN := 0;
          END IF;
          T_TMP :=  T_TMP || T_CELL;
          T_LEN := T_LEN + LENGTH( T_CELL );
          T_COL_IND := WORKBOOK.SHEETS( S ).ROWS( T_ROW_IND ).NEXT( T_COL_IND );
        END LOOP;
        T_TMP :=  T_TMP || '</row>';
        T_ROW_IND := WORKBOOK.SHEETS( S ).ROWS.NEXT( T_ROW_IND );
      END LOOP;
      T_TMP :=  T_TMP || '</sheetData>';
      T_LEN := LENGTH( T_TMP );
      DBMS_LOB.WRITEAPPEND( T_XXX, T_LEN, T_TMP );
      FOR A IN 1 ..  WORKBOOK.SHEETS( S ).AUTOFILTERS.COUNT()
      LOOP
        T_XXX := T_XXX || '<autoFilter ref="' ||
            ALFAN_COL( NVL( WORKBOOK.SHEETS( S ).AUTOFILTERS( A ).COLUMN_START, T_COL_MIN ) ) ||
            NVL( WORKBOOK.SHEETS( S ).AUTOFILTERS( A ).ROW_START, WORKBOOK.SHEETS( S ).ROWS.FIRST() ) || ':' ||
            ALFAN_COL( COALESCE( WORKBOOK.SHEETS( S ).AUTOFILTERS( A ).COLUMN_END, WORKBOOK.SHEETS( S ).AUTOFILTERS( A ).COLUMN_START, T_COL_MAX ) ) ||
            NVL( WORKBOOK.SHEETS( S ).AUTOFILTERS( A ).ROW_END, WORKBOOK.SHEETS( S ).ROWS.LAST() ) || '"/>';
      END LOOP;
      IF WORKBOOK.SHEETS( S ).MERGECELLS.COUNT() > 0
      THEN
        T_XXX := T_XXX || '<mergeCells count="' || TO_CHAR( WORKBOOK.SHEETS( S ).MERGECELLS.COUNT() ) || '">';
        FOR M IN 1 ..  WORKBOOK.SHEETS( S ).MERGECELLS.COUNT()
        LOOP
          T_XXX := T_XXX || '<mergeCell ref="' || WORKBOOK.SHEETS( S ).MERGECELLS( M ) || '"/>';
        END LOOP;
        T_XXX := T_XXX || '</mergeCells>';
      END IF;
--
      IF WORKBOOK.SHEETS( S ).VALIDATIONS.COUNT() > 0
      THEN
        T_XXX := T_XXX || '<dataValidations count="' || TO_CHAR( WORKBOOK.SHEETS( S ).VALIDATIONS.COUNT() ) || '">';
        FOR M IN 1 ..  WORKBOOK.SHEETS( S ).VALIDATIONS.COUNT()
        LOOP
          T_XXX := T_XXX || '<dataValidation' ||
              ' type="' || WORKBOOK.SHEETS( S ).VALIDATIONS( M ).TYPE || '"' ||
              ' errorStyle="' || WORKBOOK.SHEETS( S ).VALIDATIONS( M ).ERRORSTYLE || '"' ||
              ' allowBlank="' || CASE WHEN NVL( WORKBOOK.SHEETS( S ).VALIDATIONS( M ).ALLOWBLANK, TRUE ) THEN '1' ELSE '0' END || '"' ||
              ' sqref="' || WORKBOOK.SHEETS( S ).VALIDATIONS( M ).SQREF || '"';
          IF WORKBOOK.SHEETS( S ).VALIDATIONS( M ).PROMPT IS NOT NULL
          THEN
            T_XXX := T_XXX || ' showInputMessage="1" prompt="' || WORKBOOK.SHEETS( S ).VALIDATIONS( M ).PROMPT || '"';
            IF WORKBOOK.SHEETS( S ).VALIDATIONS( M ).TITLE IS NOT NULL
            THEN
              T_XXX := T_XXX || ' promptTitle="' || WORKBOOK.SHEETS( S ).VALIDATIONS( M ).TITLE || '"';
            END IF;
          END IF;
          IF WORKBOOK.SHEETS( S ).VALIDATIONS( M ).SHOWERRORMESSAGE
          THEN
            T_XXX := T_XXX || ' showErrorMessage="1"';
            IF WORKBOOK.SHEETS( S ).VALIDATIONS( M ).ERROR_TITLE IS NOT NULL
            THEN
              T_XXX := T_XXX || ' errorTitle="' || WORKBOOK.SHEETS( S ).VALIDATIONS( M ).ERROR_TITLE || '"';
            END IF;
            IF WORKBOOK.SHEETS( S ).VALIDATIONS( M ).ERROR_TXT IS NOT NULL
            THEN
              T_XXX := T_XXX || ' error="' || WORKBOOK.SHEETS( S ).VALIDATIONS( M ).ERROR_TXT || '"';
            END IF;
          END IF;
          T_XXX := T_XXX || '>';
          IF WORKBOOK.SHEETS( S ).VALIDATIONS( M ).FORMULA1 IS NOT NULL
          THEN
            T_XXX := T_XXX || '<formula1>' || WORKBOOK.SHEETS( S ).VALIDATIONS( M ).FORMULA1 || '</formula1>';
          END IF;
          IF WORKBOOK.SHEETS( S ).VALIDATIONS( M ).FORMULA2 IS NOT NULL
          THEN
            T_XXX := T_XXX || '<formula2>' || WORKBOOK.SHEETS( S ).VALIDATIONS( M ).FORMULA2 || '</formula2>';
          END IF;
          T_XXX := T_XXX || '</dataValidation>';
        END LOOP;
        T_XXX := T_XXX || '</dataValidations>';
      END IF;
--
      IF WORKBOOK.SHEETS( S ).HYPERLINKS.COUNT() > 0
      THEN
        T_XXX := T_XXX || '<hyperlinks>';
        FOR H IN 1 ..  WORKBOOK.SHEETS( S ).HYPERLINKS.COUNT()
        LOOP
          T_XXX := T_XXX || '<hyperlink ref="' || WORKBOOK.SHEETS( S ).HYPERLINKS( H ).CELL || '" r:id="rId' || H || '"/>';
        END LOOP;
        T_XXX := T_XXX || '</hyperlinks>';
      END IF;
      T_XXX := T_XXX || '<pageMargins left="0.7" right="0.7" top="0.75" bottom="0.75" header="0.3" footer="0.3"/>';
      IF WORKBOOK.SHEETS( S ).COMMENTS.COUNT() > 0
      THEN
        T_XXX := T_XXX || '<legacyDrawing r:id="rId' || ( WORKBOOK.SHEETS( S ).HYPERLINKS.COUNT() + 1 ) || '"/>';
      END IF;
--
      T_XXX := T_XXX || '</worksheet>';
      ADD1XML( T_EXCEL, 'xl/worksheets/sheet' || S || '.xml', T_XXX );
      IF WORKBOOK.SHEETS( S ).HYPERLINKS.COUNT() > 0 OR WORKBOOK.SHEETS( S ).COMMENTS.COUNT() > 0
      THEN
        T_XXX := '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">';
        IF WORKBOOK.SHEETS( S ).COMMENTS.COUNT() > 0
        THEN
          T_XXX := T_XXX || '<Relationship Id="rId' || ( WORKBOOK.SHEETS( S ).HYPERLINKS.COUNT() + 2 ) || '" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/comments" Target="../comments' || S || '.xml"/>';
          T_XXX := T_XXX || '<Relationship Id="rId' || ( WORKBOOK.SHEETS( S ).HYPERLINKS.COUNT() + 1 ) || '" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/vmlDrawing" Target="../drawings/vmlDrawing' || S || '.vml"/>';
        END IF;
        FOR H IN 1 ..  WORKBOOK.SHEETS( S ).HYPERLINKS.COUNT()
        LOOP
          T_XXX := T_XXX || '<Relationship Id="rId' || H || '" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/hyperlink" Target="' || WORKBOOK.SHEETS( S ).HYPERLINKS( H ).URL || '" TargetMode="External"/>';
        END LOOP;
        T_XXX := T_XXX || '</Relationships>';
        ADD1XML( T_EXCEL, 'xl/worksheets/_rels/sheet' || S || '.xml.rels', T_XXX );
      END IF;
--
      IF WORKBOOK.SHEETS( S ).COMMENTS.COUNT() > 0
      THEN
        DECLARE
          CNT PLS_INTEGER;
          AUTHOR_IND TP_AUTHOR;
--          t_col_ind := workbook.sheets( s ).widths.next( t_col_ind );
        BEGIN
          AUTHORS.DELETE();
          FOR C IN 1 .. WORKBOOK.SHEETS( S ).COMMENTS.COUNT()
          LOOP
            AUTHORS( WORKBOOK.SHEETS( S ).COMMENTS( C ).AUTHOR ) := 0;
          END LOOP;
          T_XXX := '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<comments xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
<authors>';
          CNT := 0;
          AUTHOR_IND := AUTHORS.FIRST();
          WHILE AUTHOR_IND IS NOT NULL OR AUTHORS.NEXT( AUTHOR_IND ) IS NOT NULL
          LOOP
            AUTHORS( AUTHOR_IND ) := CNT;
            T_XXX := T_XXX || '<author>' || AUTHOR_IND || '</author>';
            CNT := CNT + 1;
            AUTHOR_IND := AUTHORS.NEXT( AUTHOR_IND );
          END LOOP;
        END;
        T_XXX := T_XXX || '</authors><commentList>';
        FOR C IN 1 .. WORKBOOK.SHEETS( S ).COMMENTS.COUNT()
        LOOP
          T_XXX := T_XXX || '<comment ref="' || ALFAN_COL( WORKBOOK.SHEETS( S ).COMMENTS( C ).COLUMN ) ||
             TO_CHAR( WORKBOOK.SHEETS( S ).COMMENTS( C ).ROW || '" authorId="' || AUTHORS( WORKBOOK.SHEETS( S ).COMMENTS( C ).AUTHOR ) ) || '">
<text>';
          IF WORKBOOK.SHEETS( S ).COMMENTS( C ).AUTHOR IS NOT NULL
          THEN
            T_XXX := T_XXX || '<r><rPr><b/><sz val="9"/><color indexed="81"/><rFont val="Tahoma"/><charset val="1"/></rPr><t xml:space="preserve">' ||
               WORKBOOK.SHEETS( S ).COMMENTS( C ).AUTHOR || ':</t></r>';
          END IF;
          T_XXX := T_XXX || '<r><rPr><sz val="9"/><color indexed="81"/><rFont val="Tahoma"/><charset val="1"/></rPr><t xml:space="preserve">' ||
             CASE WHEN WORKBOOK.SHEETS( S ).COMMENTS( C ).AUTHOR IS NOT NULL THEN '
' END || WORKBOOK.SHEETS( S ).COMMENTS( C ).TEXT || '</t></r></text></comment>';
        END LOOP;
        T_XXX := T_XXX || '</commentList></comments>';
        ADD1XML( T_EXCEL, 'xl/comments' || S || '.xml', T_XXX );
        T_XXX := '<xml xmlns:v="urn:schemas-microsoft-com:vml" xmlns:o="urn:schemas-microsoft-com:office:office" xmlns:x="urn:schemas-microsoft-com:office:excel">
<o:shapelayout v:ext="edit"><o:idmap v:ext="edit" data="2"/></o:shapelayout>
<v:shapetype id="_x0000_t202" coordsize="21600,21600" o:spt="202" path="m,l,21600r21600,l21600,xe"><v:stroke joinstyle="miter"/><v:path gradientshapeok="t" o:connecttype="rect"/></v:shapetype>';
        FOR C IN 1 .. WORKBOOK.SHEETS( S ).COMMENTS.COUNT()
        LOOP
          T_XXX := T_XXX || '<v:shape id="_x0000_s' || TO_CHAR( C ) || '" type="#_x0000_t202"
style="position:absolute;margin-left:35.25pt;margin-top:3pt;z-index:' || TO_CHAR( C ) || ';visibility:hidden;" fillcolor="#ffffe1" o:insetmode="auto">
<v:fill color2="#ffffe1"/><v:shadow on="t" color="black" obscured="t"/><v:path o:connecttype="none"/>
<v:textbox style="mso-direction-alt:auto"><div style="text-align:left"></div></v:textbox>
<x:ClientData ObjectType="Note"><x:MoveWithCells/><x:SizeWithCells/>';
          T_W := WORKBOOK.SHEETS( S ).COMMENTS( C ).WIDTH;
          T_C := 1;
          LOOP
            IF WORKBOOK.SHEETS( S ).WIDTHS.EXISTS( WORKBOOK.SHEETS( S ).COMMENTS( C ).COLUMN + T_C )
            THEN
              T_CW := 256 * WORKBOOK.SHEETS( S ).WIDTHS( WORKBOOK.SHEETS( S ).COMMENTS( C ).COLUMN + T_C ); 
              T_CW := TRUNC( ( T_CW + 18 ) / 256 * 7); -- assume default 11 point Calibri
            ELSE
              T_CW := 64;
            END IF;
            EXIT WHEN T_W < T_CW;
            T_C := T_C + 1;
            T_W := T_W - T_CW;
          END LOOP;
          T_H := WORKBOOK.SHEETS( S ).COMMENTS( C ).HEIGHT;
          T_XXX := T_XXX || TO_CHAR( '<x:Anchor>' || WORKBOOK.SHEETS( S ).COMMENTS( C ).COLUMN || ',15,' ||
                     WORKBOOK.SHEETS( S ).COMMENTS( C ).ROW || ',30,' ||
                     ( WORKBOOK.SHEETS( S ).COMMENTS( C ).COLUMN + T_C - 1 ) || ',' || ROUND( T_W ) || ',' ||
                     ( WORKBOOK.SHEETS( S ).COMMENTS( C ).ROW + 1 + TRUNC( T_H / 20 ) ) || ',' || MOD( T_H, 20 ) || '</x:Anchor>' );
          T_XXX := T_XXX || TO_CHAR( '<x:AutoFill>False</x:AutoFill><x:Row>' ||
            ( WORKBOOK.SHEETS( S ).COMMENTS( C ).ROW - 1 ) || '</x:Row><x:Column>' ||
            ( WORKBOOK.SHEETS( S ).COMMENTS( C ).COLUMN - 1 ) || '</x:Column></x:ClientData></v:shape>' );
        END LOOP;
        T_XXX := T_XXX || '</xml>';
        ADD1XML( T_EXCEL, 'xl/drawings/vmlDrawing' || S || '.vml', T_XXX );
      END IF;
--
    END LOOP;
    T_XXX := '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/sharedStrings" Target="sharedStrings.xml"/>
<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
<Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme" Target="theme/theme1.xml"/>';
    FOR S IN 1 .. WORKBOOK.SHEETS.COUNT()
    LOOP
      T_XXX := T_XXX || '
<Relationship Id="rId' || ( 9 + S ) || '" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet' || S || '.xml"/>';
    END LOOP;
    T_XXX := T_XXX || '</Relationships>';
    ADD1XML( T_EXCEL, 'xl/_rels/workbook.xml.rels', T_XXX );
    T_XXX := '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" count="' || WORKBOOK.STR_CNT || '" uniqueCount="' || WORKBOOK.STRINGS.COUNT() || '">';
    T_TMP := NULL;
    FOR I IN 0 .. WORKBOOK.STR_IND.COUNT() - 1
    LOOP
      T_STR := '<si><t>' || DBMS_XMLGEN.CONVERT( SUBSTR( WORKBOOK.STR_IND( I ), 1, 32000 ) ) || '</t></si>';
      IF LENGTH( T_TMP ) + LENGTH( T_STR ) > 32000
      THEN
        T_XXX := T_XXX || T_TMP;
        T_TMP := NULL;
      END IF;
      T_TMP := T_TMP || T_STR;
    END LOOP;
    T_XXX := T_XXX || T_TMP || '</sst>';
    ADD1XML( T_EXCEL, 'xl/sharedStrings.xml', T_XXX );
    FINISH_ZIP( T_EXCEL );
    CLEAR_WORKBOOK;
    RETURN T_EXCEL;
  END;
------------------------------------------------------------------------------------------------


  PROCEDURE SAVE
    ( P_DIRECTORY VARCHAR2
    , P_FILENAME VARCHAR2
    )
  IS
  BEGIN
    BLOB2FILE( FINISH, P_DIRECTORY, P_FILENAME );
  END;
--
  PROCEDURE QUERY2SHEET
    ( P_SQL VARCHAR2
    , P_COLUMN_HEADERS BOOLEAN := TRUE
    , P_DIRECTORY VARCHAR2 := NULL
    , P_FILENAME VARCHAR2 := NULL
    , P_SHEET PLS_INTEGER := NULL
    )
  IS
    T_SHEET PLS_INTEGER;
    T_C INTEGER;
    T_COL_CNT INTEGER;
    T_DESC_TAB DBMS_SQL.DESC_TAB2;
    D_TAB DBMS_SQL.DATE_TABLE;
    N_TAB DBMS_SQL.NUMBER_TABLE;
    V_TAB DBMS_SQL.VARCHAR2_TABLE;
    T_BULK_SIZE PLS_INTEGER := 200;
    T_R INTEGER;
    T_CUR_ROW PLS_INTEGER;
  BEGIN
    IF P_SHEET IS NULL
    THEN
      NEW_SHEET;
    END IF;
    T_C := DBMS_SQL.OPEN_CURSOR;
    DBMS_SQL.PARSE( T_C, P_SQL, DBMS_SQL.NATIVE );
    DBMS_SQL.DESCRIBE_COLUMNS2( T_C, T_COL_CNT, T_DESC_TAB );
    FOR C IN 1 .. T_COL_CNT
    LOOP
      IF P_COLUMN_HEADERS
      THEN
        CELL( C, 1, T_DESC_TAB( C ).COL_NAME, P_SHEET => T_SHEET );
      END IF;
--      dbms_output.put_line( t_desc_tab( c ).col_name || ' ' || t_desc_tab( c ).col_type );
      CASE
        WHEN T_DESC_TAB( C ).COL_TYPE IN ( 2, 100, 101 )
        THEN
          DBMS_SQL.DEFINE_ARRAY( T_C, C, N_TAB, T_BULK_SIZE, 1 );
        WHEN T_DESC_TAB( C ).COL_TYPE IN ( 12, 178, 179, 180, 181 , 231 )
        THEN
          DBMS_SQL.DEFINE_ARRAY( T_C, C, D_TAB, T_BULK_SIZE, 1 );
        WHEN T_DESC_TAB( C ).COL_TYPE IN ( 1, 8, 9, 96, 112 )
        THEN
          DBMS_SQL.DEFINE_ARRAY( T_C, C, V_TAB, T_BULK_SIZE, 1 );
        ELSE
          NULL;
      END CASE;
    END LOOP;
--
    T_CUR_ROW := CASE WHEN P_COLUMN_HEADERS THEN 2 ELSE 1 END;
    T_SHEET := NVL( P_SHEET, WORKBOOK.SHEETS.COUNT() );
--
    T_R := DBMS_SQL.EXECUTE( T_C );
    LOOP
      T_R := DBMS_SQL.FETCH_ROWS( T_C );
      IF T_R > 0
      THEN
        FOR C IN 1 .. T_COL_CNT
        LOOP
          CASE
            WHEN T_DESC_TAB( C ).COL_TYPE IN ( 2, 100, 101 )
            THEN
              DBMS_SQL.COLUMN_VALUE( T_C, C, N_TAB );
              FOR I IN 0 .. T_R - 1
              LOOP
                IF N_TAB( I + N_TAB.FIRST() ) IS NOT NULL
                THEN
                  CELL( C, T_CUR_ROW + I, N_TAB( I + N_TAB.FIRST() ), P_SHEET => T_SHEET );
                END IF;
              END LOOP;
              N_TAB.DELETE;
            WHEN T_DESC_TAB( C ).COL_TYPE IN ( 12, 178, 179, 180, 181 , 231 )
            THEN
              DBMS_SQL.COLUMN_VALUE( T_C, C, D_TAB );
              FOR I IN 0 .. T_R - 1
              LOOP
                IF D_TAB( I + D_TAB.FIRST() ) IS NOT NULL
                THEN
                  CELL( C, T_CUR_ROW + I, D_TAB( I + D_TAB.FIRST() ), P_SHEET => T_SHEET );
                END IF;
              END LOOP;
              D_TAB.DELETE;
            WHEN T_DESC_TAB( C ).COL_TYPE IN ( 1, 8, 9, 96, 112 )
            THEN
              DBMS_SQL.COLUMN_VALUE( T_C, C, V_TAB );
              FOR I IN 0 .. T_R - 1
              LOOP
                IF V_TAB( I + V_TAB.FIRST() ) IS NOT NULL
                THEN
                  CELL( C, T_CUR_ROW + I, V_TAB( I + V_TAB.FIRST() ), P_SHEET => T_SHEET );
                END IF;
              END LOOP;
              V_TAB.DELETE;
            ELSE
              NULL;
          END CASE;
        END LOOP;
      END IF;
      EXIT WHEN T_R != T_BULK_SIZE;
      T_CUR_ROW := T_CUR_ROW + T_R;
    END LOOP;
    DBMS_SQL.CLOSE_CURSOR( T_C );
    IF ( P_DIRECTORY IS NOT NULL AND  P_FILENAME IS NOT NULL )
    THEN
      SAVE( P_DIRECTORY, P_FILENAME );
    END IF;
  EXCEPTION
    WHEN OTHERS
    THEN
      IF DBMS_SQL.IS_OPEN( T_C )
      THEN
        DBMS_SQL.CLOSE_CURSOR( T_C );
      END IF;
  END;
  
  PROCEDURE QUERY2SHEET2
    ( P_SQL VARCHAR2
    , P_START_ROW NUMBER := 10
    , P_COLUMN_HEADERS BOOLEAN := TRUE
    , P_DIRECTORY VARCHAR2 := NULL
    , P_FILENAME VARCHAR2 := NULL
    , P_SHEET PLS_INTEGER := NULL
    )
  IS
    /* hunglc 
    - Khong tao new sheet
    - them mau nen cho header
    - thêm thuoc tinh p_start_row de ghi du lieu len excel bat dau tu dong p_start_row
    */
    T_SHEET PLS_INTEGER;
    T_C INTEGER;
    T_COL_CNT INTEGER;
    T_DESC_TAB DBMS_SQL.DESC_TAB2;
    D_TAB DBMS_SQL.DATE_TABLE;
    N_TAB DBMS_SQL.NUMBER_TABLE;
    V_TAB DBMS_SQL.VARCHAR2_TABLE;
    T_BULK_SIZE PLS_INTEGER := 200;
    T_R INTEGER;
    T_CUR_ROW PLS_INTEGER;
  BEGIN
    IF P_SHEET IS NULL
    THEN
      NULL;--NEW_SHEET;
    END IF;
    T_C := DBMS_SQL.OPEN_CURSOR;
    DBMS_SQL.PARSE( T_C, P_SQL, DBMS_SQL.NATIVE );
    DBMS_SQL.DESCRIBE_COLUMNS2( T_C, T_COL_CNT, T_DESC_TAB );
    FOR C IN 1 .. T_COL_CNT
    LOOP
      IF P_COLUMN_HEADERS
      THEN
        CELL( C, P_START_ROW, T_DESC_TAB( C ).COL_NAME, P_SHEET => T_SHEET, p_fontId => get_font( 'calibri', 2, p_bold =>true ), p_fillId => get_fill( 'solid', '8B795E' )  );
      END IF;
--      dbms_output.put_line( t_desc_tab( c ).col_name || ' ' || t_desc_tab( c ).col_type );
      CASE
        WHEN T_DESC_TAB( C ).COL_TYPE IN ( 2, 100, 101 )
        THEN
          DBMS_SQL.DEFINE_ARRAY( T_C, C, N_TAB, T_BULK_SIZE, 1 );
        WHEN T_DESC_TAB( C ).COL_TYPE IN ( 12, 178, 179, 180, 181 , 231 )
        THEN
          DBMS_SQL.DEFINE_ARRAY( T_C, C, D_TAB, T_BULK_SIZE, 1 );
        WHEN T_DESC_TAB( C ).COL_TYPE IN ( 1, 8, 9, 96, 112 )
        THEN
          DBMS_SQL.DEFINE_ARRAY( T_C, C, V_TAB, T_BULK_SIZE, 1 );
        ELSE
          NULL;
      END CASE;
    END LOOP;
--
    T_CUR_ROW := CASE WHEN P_COLUMN_HEADERS THEN P_START_ROW+1 ELSE P_START_ROW END;
    T_SHEET := NVL( P_SHEET, WORKBOOK.SHEETS.COUNT() );
--
    T_R := DBMS_SQL.EXECUTE( T_C );
    LOOP
      T_R := DBMS_SQL.FETCH_ROWS( T_C );
      IF T_R > 0
      THEN
        FOR C IN 1 .. T_COL_CNT
        LOOP
          CASE
            WHEN T_DESC_TAB( C ).COL_TYPE IN ( 2, 100, 101 )
            THEN
              DBMS_SQL.COLUMN_VALUE( T_C, C, N_TAB );
              FOR I IN 0 .. T_R - 1
              LOOP
                IF N_TAB( I + N_TAB.FIRST() ) IS NOT NULL
                THEN
                  CELL( C, T_CUR_ROW + I, N_TAB( I + N_TAB.FIRST() ), P_SHEET => T_SHEET );
                END IF;
              END LOOP;
              N_TAB.DELETE;
            WHEN T_DESC_TAB( C ).COL_TYPE IN ( 12, 178, 179, 180, 181 , 231 )
            THEN
              DBMS_SQL.COLUMN_VALUE( T_C, C, D_TAB );
              FOR I IN 0 .. T_R - 1
              LOOP
                IF D_TAB( I + D_TAB.FIRST() ) IS NOT NULL
                THEN
                  CELL( C, T_CUR_ROW + I, D_TAB( I + D_TAB.FIRST() ), P_SHEET => T_SHEET );
                END IF;
              END LOOP;
              D_TAB.DELETE;
            WHEN T_DESC_TAB( C ).COL_TYPE IN ( 1, 8, 9, 96, 112 )
            THEN
              DBMS_SQL.COLUMN_VALUE( T_C, C, V_TAB );
              FOR I IN 0 .. T_R - 1
              LOOP
                IF V_TAB( I + V_TAB.FIRST() ) IS NOT NULL
                THEN
                  CELL( C, T_CUR_ROW + I, V_TAB( I + V_TAB.FIRST() ), P_SHEET => T_SHEET );
                END IF;
              END LOOP;
              V_TAB.DELETE;
            ELSE
              NULL;
          END CASE;
        END LOOP;
      END IF;
      EXIT WHEN T_R != T_BULK_SIZE;
      T_CUR_ROW := T_CUR_ROW + T_R;
    END LOOP;
    DBMS_SQL.CLOSE_CURSOR( T_C );
    IF ( P_DIRECTORY IS NOT NULL AND  P_FILENAME IS NOT NULL )
    THEN
      SAVE( P_DIRECTORY, P_FILENAME );
    END IF;
  EXCEPTION
    WHEN OTHERS
    THEN
      IF DBMS_SQL.IS_OPEN( T_C )
      THEN
        DBMS_SQL.CLOSE_CURSOR( T_C );
      END IF;
  END;
END;
/

