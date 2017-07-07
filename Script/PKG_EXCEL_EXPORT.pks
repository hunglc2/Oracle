CREATE OR REPLACE PACKAGE PKG_EXCEL_EXPORT
IS
/**********************************************
**
** Author: Anton Scheffer
** Date: 19-02-2011
** Website: http://technology.amis.nl/blog
** See also: http://technology.amis.nl/blog/?p=10995
**
** Changelog:
** Date: 21-02-2011
** Added Aligment, horizontal, vertical, wrapText
** Date: 06-03-2011
** Added Comments, MergeCells, fixed bug for dependency on NLS-settings
** Date: 16-03-2011
** Added bold and italic fonts
** Date: 22-03-2011
** Fixed issue with timezone's set to a region(name) instead of a offset
** Date: 08-04-2011
** Fixed issue with XML-escaping from text
** Date: 27-05-2011
** Added MIT-license
** Date: 11-08-2011
** Fixed NLS-issue with column width
** Date: 29-09-2011
** Added font color
** Date: 16-10-2011
** fixed bug in add_string
** Date: 26-04-2012
** Fixed set_autofilter (only one autofilter per sheet, added _xlnm._FilterDatabase)
** Added list_validation = drop-down 
** Date: 27-08-2013
** Added freeze_pane
**
******************************************************************************
******************************************************************************
Copyright (C) 2011, 2012 by Anton Scheffer

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

******************************************************************************
******************************************** */
--
 TYPE TP_ALIGNMENT IS RECORD
 ( VERTICAL VARCHAR2(11)
 , HORIZONTAL VARCHAR2(16)
 , WRAPTEXT BOOLEAN
 );
--
 PROCEDURE CLEAR_WORKBOOK;
--
 PROCEDURE NEW_SHEET( P_SHEETNAME VARCHAR2 := NULL );
--
 FUNCTION ORAFMT2EXCEL( P_FORMAT VARCHAR2 := NULL )
 RETURN VARCHAR2;
--
 FUNCTION GET_NUMFMT( P_FORMAT VARCHAR2 := NULL )
 RETURN PLS_INTEGER;
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
 RETURN PLS_INTEGER;
--
 FUNCTION GET_FILL
 ( P_PATTERNTYPE VARCHAR2
 , P_FGRGB VARCHAR2 := NULL -- this is a hex ALPHA Red Green Blue value
 )
 RETURN PLS_INTEGER;
--
 FUNCTION GET_BORDER
 ( P_TOP VARCHAR2 := 'thin'
 , P_BOTTOM VARCHAR2 := 'thin'
 , P_LEFT VARCHAR2 := 'thin'
 , P_RIGHT VARCHAR2 := 'thin'
 )
/*
none
thin
medium
dashed
dotted
thick
double
hair
mediumDashed
dashDot
mediumDashDot
dashDotDot
mediumDashDotDot
slantDashDot
*/
 RETURN PLS_INTEGER;
--
 FUNCTION GET_ALIGNMENT
 ( P_VERTICAL VARCHAR2 := NULL
 , P_HORIZONTAL VARCHAR2 := NULL
 , P_WRAPTEXT BOOLEAN := NULL
 )
/* horizontal
center
centerContinuous
distributed
fill
general
justify
left
right
*/
/* vertical
bottom
center
distributed
justify
top
*/
 RETURN TP_ALIGNMENT;
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
 );
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
 );
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
 );
--
 PROCEDURE HYPERLINK
 ( P_COL PLS_INTEGER
 , P_ROW PLS_INTEGER
 , P_URL VARCHAR2
 , P_VALUE VARCHAR2 := NULL
 , P_SHEET PLS_INTEGER := NULL
 );
--
 PROCEDURE COMMENT
 ( P_COL PLS_INTEGER
 , P_ROW PLS_INTEGER
 , P_TEXT VARCHAR2
 , P_AUTHOR VARCHAR2 := NULL
 , P_WIDTH PLS_INTEGER := 150 -- pixels
 , P_HEIGHT PLS_INTEGER := 100 -- pixels
 , P_SHEET PLS_INTEGER := NULL
 );
--
 PROCEDURE MERGECELLS
 ( P_TL_COL PLS_INTEGER -- top left
 , P_TL_ROW PLS_INTEGER
 , P_BR_COL PLS_INTEGER -- bottom right
 , P_BR_ROW PLS_INTEGER
 , P_SHEET PLS_INTEGER := NULL
 );
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
 );
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
 );
--
 PROCEDURE DEFINED_NAME
 ( P_TL_COL PLS_INTEGER -- top left
 , P_TL_ROW PLS_INTEGER
 , P_BR_COL PLS_INTEGER -- bottom right
 , P_BR_ROW PLS_INTEGER
 , P_NAME VARCHAR2
 , P_SHEET PLS_INTEGER := NULL
 , P_LOCALSHEET PLS_INTEGER := NULL
 );
--
 PROCEDURE SET_COLUMN_WIDTH
 ( P_COL PLS_INTEGER
 , P_WIDTH NUMBER
 , P_SHEET PLS_INTEGER := NULL
 );
--
 PROCEDURE SET_COLUMN
 ( P_COL PLS_INTEGER
 , P_NUMFMTID PLS_INTEGER := NULL
 , P_FONTID PLS_INTEGER := NULL
 , P_FILLID PLS_INTEGER := NULL
 , P_BORDERID PLS_INTEGER := NULL
 , P_ALIGNMENT TP_ALIGNMENT := NULL
 , P_SHEET PLS_INTEGER := NULL
 );
--
 PROCEDURE SET_ROW
 ( P_ROW PLS_INTEGER
 , P_NUMFMTID PLS_INTEGER := NULL
 , P_FONTID PLS_INTEGER := NULL
 , P_FILLID PLS_INTEGER := NULL
 , P_BORDERID PLS_INTEGER := NULL
 , P_ALIGNMENT TP_ALIGNMENT := NULL
 , P_SHEET PLS_INTEGER := NULL
 );
--
 PROCEDURE FREEZE_ROWS
 ( P_NR_ROWS PLS_INTEGER := 1
 , P_SHEET PLS_INTEGER := NULL
 );
--
 PROCEDURE FREEZE_COLS
 ( P_NR_COLS PLS_INTEGER := 1
 , P_SHEET PLS_INTEGER := NULL
 );
--
 PROCEDURE FREEZE_PANE
 ( P_COL PLS_INTEGER
 , P_ROW PLS_INTEGER
 , P_SHEET PLS_INTEGER := NULL
 );
--
 PROCEDURE SET_AUTOFILTER
 ( P_COLUMN_START PLS_INTEGER := NULL
 , P_COLUMN_END PLS_INTEGER := NULL
 , P_ROW_START PLS_INTEGER := NULL
 , P_ROW_END PLS_INTEGER := NULL
 , P_SHEET PLS_INTEGER := NULL
 );
--
 FUNCTION FINISH
 RETURN BLOB;
--
 FUNCTION EXCEL_CONTENT
 RETURN BLOB;
 
 PROCEDURE SAVE
 ( P_DIRECTORY VARCHAR2
 , P_FILENAME VARCHAR2
 );
--
 PROCEDURE QUERY2SHEET
 ( P_SQL VARCHAR2
 , P_COLUMN_HEADERS BOOLEAN := TRUE
 , P_DIRECTORY VARCHAR2 := NULL
 , P_FILENAME VARCHAR2 := NULL
 , P_SHEET PLS_INTEGER := NULL
 );
 PROCEDURE QUERY2SHEET2
 ( P_SQL VARCHAR2
 , P_START_ROW NUMBER := 10
 , P_COLUMN_HEADERS BOOLEAN := TRUE
 , P_DIRECTORY VARCHAR2 := NULL
 , P_FILENAME VARCHAR2 := NULL
 , P_SHEET PLS_INTEGER := NULL
 );
--
/* Example
begin
 EABIT.PKG_EXCEL_EXPORT.clear_workbook;
 PKG_EXCEL_EXPORT.new_sheet;
 PKG_EXCEL_EXPORT.cell( 5, 1, 5 );
 PKG_EXCEL_EXPORT.cell( 3, 1, 3 );
 PKG_EXCEL_EXPORT.cell( 2, 2, 45 );
 PKG_EXCEL_EXPORT.cell( 3, 2, 'Anton Scheffer', p_alignment => PKG_EXCEL_EXPORT.get_alignment( p_wraptext => true ) );
 PKG_EXCEL_EXPORT.cell( 1, 4, sysdate, p_fontId => PKG_EXCEL_EXPORT.get_font( 'Calibri', p_rgb => 'FFFF0000' ) );
 PKG_EXCEL_EXPORT.cell( 2, 4, sysdate, p_numFmtId => PKG_EXCEL_EXPORT.get_numFmt( 'dd/mm/yyyy h:mm' ) );
 PKG_EXCEL_EXPORT.cell( 3, 4, sysdate, p_numFmtId => PKG_EXCEL_EXPORT.get_numFmt( PKG_EXCEL_EXPORT.orafmt2excel( 'dd/mon/yyyy' ) ) );
  PKG_EXCEL_EXPORT.cell( 5, 5, 75, p_borderId => PKG_EXCEL_EXPORT.get_border( 'double', 'double', 'double', 'double' ) );
  PKG_EXCEL_EXPORT.cell( 2, 3, 33 );
  PKG_EXCEL_EXPORT.hyperlink( 1, 6, 'http://www.amis.nl', 'Amis site' );
  PKG_EXCEL_EXPORT.cell( 1, 7, 'Some merged cells', p_alignment => PKG_EXCEL_EXPORT.get_alignment( p_horizontal => 'center' ) );
  PKG_EXCEL_EXPORT.mergecells( 1, 7, 3, 7 );
  for i in 1 .. 5
  loop
    PKG_EXCEL_EXPORT.comment( 3, i + 3, 'Row ' || (i+3), 'Anton' );
  end loop;
  PKG_EXCEL_EXPORT.new_sheet;
  PKG_EXCEL_EXPORT.set_row( 1, p_fillId => PKG_EXCEL_EXPORT.get_fill( 'solid', 'FFFF0000' ) ) ;
  for i in 1 .. 5
  loop
    PKG_EXCEL_EXPORT.cell( 1, i, i );
    PKG_EXCEL_EXPORT.cell( 2, i, i * 3 );
    PKG_EXCEL_EXPORT.cell( 3, i, 'x ' || i * 3 );
  end loop;
  PKG_EXCEL_EXPORT.query2sheet( 'select rownum, x.*
, case when mod( rownum, 2 ) = 0 then rownum * 3 end demo
, case when mod( rownum, 2 ) = 1 then ''demo '' || rownum end demo2 from dual x connect by rownum <= 5' );
  PKG_EXCEL_EXPORT.save( 'MY_DIR', 'my.xlsx' );
end;
--
begin
  PKG_EXCEL_EXPORT.clear_workbook;
  PKG_EXCEL_EXPORT.new_sheet;
  PKG_EXCEL_EXPORT.cell( 1, 6, 5 );
  PKG_EXCEL_EXPORT.cell( 1, 7, 3 );
  PKG_EXCEL_EXPORT.cell( 1, 8, 7 );
  PKG_EXCEL_EXPORT.new_sheet;
  PKG_EXCEL_EXPORT.cell( 2, 6, 15, p_sheet => 2 );
  PKG_EXCEL_EXPORT.cell( 2, 7, 13, p_sheet => 2 );
  PKG_EXCEL_EXPORT.cell( 2, 8, 17, p_sheet => 2 );
  PKG_EXCEL_EXPORT.list_validation( 6, 3, 1, 6, 1, 8, p_show_error => true, p_sheet => 1 );
  PKG_EXCEL_EXPORT.defined_name( 2, 6, 2, 8, 'Anton', 2 );
  PKG_EXCEL_EXPORT.list_validation
    ( 6, 1, 'Anton'
    , p_style => 'information'
    , p_title => 'valid values are'
    , p_prompt => '13, 15 and 17'
    , p_show_error => true
    , p_error_title => 'Are you sure?'
    , p_error_txt => 'Valid values are: 13, 15 and 17'
    , p_sheet => 1 );
  PKG_EXCEL_EXPORT.save( 'MY_DIR', 'my.xlsx' );
end;
--
begin
  PKG_EXCEL_EXPORT.clear_workbook;
  PKG_EXCEL_EXPORT.new_sheet;
  PKG_EXCEL_EXPORT.cell( 1, 6, 5 );
  PKG_EXCEL_EXPORT.cell( 1, 7, 3 );
  PKG_EXCEL_EXPORT.cell( 1, 8, 7 );
  PKG_EXCEL_EXPORT.set_autofilter( 1,1, p_row_start => 5, p_row_end => 8 );
  PKG_EXCEL_EXPORT.new_sheet;
  PKG_EXCEL_EXPORT.cell( 2, 6, 5 );
  PKG_EXCEL_EXPORT.cell( 2, 7, 3 );
  PKG_EXCEL_EXPORT.cell( 2, 8, 7 );
  PKG_EXCEL_EXPORT.set_autofilter( 2,2, p_row_start => 5, p_row_end => 8 );
  PKG_EXCEL_EXPORT.save( 'MY_DIR', 'my.xlsx' );
end;
--
begin
  PKG_EXCEL_EXPORT.clear_workbook;
  PKG_EXCEL_EXPORT.new_sheet;
  for c in 1 .. 10
  loop
    PKG_EXCEL_EXPORT.cell( c, 1, 'COL' || c );
    PKG_EXCEL_EXPORT.cell( c, 2, 'val' || c );
    PKG_EXCEL_EXPORT.cell( c, 3, c );
  end loop;
  PKG_EXCEL_EXPORT.freeze_rows( 1 );
  PKG_EXCEL_EXPORT.new_sheet;
  for r in 1 .. 10
  loop
    PKG_EXCEL_EXPORT.cell( 1, r, 'ROW' || r );
    PKG_EXCEL_EXPORT.cell( 2, r, 'val' || r );
    PKG_EXCEL_EXPORT.cell( 3, r, r );
  end loop;
  PKG_EXCEL_EXPORT.freeze_cols( 3 );
  PKG_EXCEL_EXPORT.new_sheet;
  PKG_EXCEL_EXPORT.cell( 3, 3, 'Start freeze' );
  PKG_EXCEL_EXPORT.freeze_pane( 3,3 );
  PKG_EXCEL_EXPORT.save( 'MY_DIR', 'my.xlsx' );
end;
*/
END;
/

