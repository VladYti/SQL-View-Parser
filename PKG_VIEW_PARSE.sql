CREATE OR REPLACE PACKAGE PARUS.PKG_VIEW_PARSE
AS 

TYPE a_clob is  record   (clob_row varchar2(4000));
TYPE ta_clob is TABLE OF a_clob;

TYPE a_cols IS  record  (n NUMBER(10), al varchar2(4000), col varchar2(4000));
TYPE ta_cols is TABLE OF a_cols;

TYPE a_tabs IS  record  (tname varchar2(4000), aname varchar2(4000), lcname varchar2(4000));
TYPE ta_tabs is TABLE OF a_tabs;

TYPE a_VLINK IS  record  (column_id NUMBER(17), column_name varchar2(4000), r_table_name varchar2(4000), r_column_name varchar2(4000), link_column_name varchar2(4000));
TYPE ta_VLINK is TABLE OF a_VLINK;


FUNCTION SPLIT_CLOB( IN_CLOB IN CLOB) RETURN TA_CLOB PIPELINED;

FUNCTION PREPARE_BASE_VIEW_CLOB(in_clob IN clob, REPLACE_TO IN VARCHAR2 ) RETURN CLOB;

FUNCTION GET_SLICE(IN_VIEW IN CLOB, SFROM IN VARCHAR2, STO IN VARCHAR2) RETURN CLOB;

FUNCTION GET_COLUMNS_ALIASES(in_clob  IN clob) RETURN ta_cols pipelined;

FUNCTION GET_TABLES_ALIASES(in_clob  IN clob) RETURN ta_tabs pipelined;

FUNCTION LINK_VIEW_COLUMNS(sbase_view_name IN varchar2) RETURN ta_VLINK pipelined;
    
    
END PKG_VIEW_PARSE;