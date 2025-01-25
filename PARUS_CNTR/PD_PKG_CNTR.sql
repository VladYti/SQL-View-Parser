CREATE OR REPLACE PACKAGE PARUS.PD_PKG_CNTR AS



-- ************************************************************************************
-- ************************************************************************************
-- ************************************************************************************
-- ************************************************************************************
-- ************************************************************************************

NCLASS_RN               NUMBER;
SBASE_VIEW_NAME         VARCHAR2(30);
SBASE_TABLE_NAME        VARCHAR2(30);
NBASE_VIEW_RN           NUMBER(17);
CBASE_VIEW_CLOB         CLOB;





FUNCTION LONG_TO_CHAR(
                        in_table_name varchar2,
                        in_column varchar2,
                        in_column_name varchar2,
                        in_tab_name varchar2
                    )
RETURN varchar2;

FUNCTION GETCAPTION( SBASE_CAPTION IN VARCHAR2 ) RETURN VARCHAR2;



TYPE a_clob is  record   (clob_row varchar2(4000));
TYPE ta_clob is TABLE OF a_clob;

TYPE a_cols IS  record  (n NUMBER(10), al varchar2(4000), col varchar2(4000));
TYPE ta_cols is TABLE OF a_cols;

TYPE a_tabs IS  record  (tname varchar2(4000), aname varchar2(4000), lcname varchar2(4000));
TYPE ta_tabs is TABLE OF a_tabs;

TYPE a_VLINK IS  record  (column_id NUMBER(17), column_name varchar2(4000), r_table_name varchar2(4000), r_column_name varchar2(4000), link_column_name varchar2(4000));
TYPE ta_VLINK is TABLE OF a_VLINK;



FUNCTION GETDOMAIN
(
    SODATA_TYPE         IN VARCHAR2,
    NODATA_PRECISION    IN NUMBER       := NULL,
    NODATA_SCALE        IN NUMBER       := NULL,
    NODATA_LENGTH       IN NUMBER       := NULL,
    SODATA_DEFAULT      IN VARCHAR2     := NULL
) RETURN VARCHAR2;

PROCEDURE INIT_CONST_PARAMS(in_NCLASS_RN IN NUMBER);

FUNCTION SPLIT_CLOB( IN_CLOB IN CLOB) RETURN TA_CLOB PIPELINED;

FUNCTION PREPARE_BASE_VIEW_CLOB( REPLACE_TO IN VARCHAR2 ) RETURN CLOB;

FUNCTION GET_SLICE(IN_VIEW IN CLOB, SFROM IN VARCHAR2, STO IN VARCHAR2) RETURN CLOB;

FUNCTION GET_COLUMNS_ALIASES RETURN ta_cols pipelined;

FUNCTION GET_TABLES_ALIASES RETURN ta_tabs pipelined;

FUNCTION LINK_VIEW_COLUMNS RETURN ta_VLINK pipelined;

PROCEDURE LOAD_CLS_VIEW_ATTRIBUTES;

PROCEDURE ENTER_POINT(nRN IN NUMBER, ATTR_NAME_FILE IN clob DEFAULT null);








PROCEDURE PD_P_DMSCLATTRS_INSERT
(
  nPRN              in number,          -- регистрационный номер записи класса
  sCOLUMN_NAME      in varchar2,        -- имя атрибута
  sCAPTION          in varchar2,        -- наименование атрибута
  nKIND             in number,          -- тип атрибута
  nPOSITION         in number,          -- позиция атрибута
  sDOMAIN           in varchar2,        -- мнемокод домена
  sREF_LINK         in varchar2,        -- имя связи ссылки
  sREF_ATTRIBUTE    in varchar2,        -- имя атрибута ссылки
  nRN               out number          -- регистрационный номер записи атрибута
);

PROCEDURE LOAD_CLS_ATTRIBUTES;

PROCEDURE PD_P_DMSCLCONSTRS_INSERT_ADV(
                                          nPRN              in number,
                                          sNAME             in varchar2,
                                          sCONSTRAINT_NAME  in varchar2,
                                          nCONSTRAINT_TYPE  in number,
                                          sCHECK_FUNCTION   in varchar2,
                                          sMESSAGE          in varchar2,
                                          sCONSTRAINT_TEXT  in varchar2,
                                          cCONSTRAINT_INIT  in clob,
                                          nLINKS_SIGN       in number,
                                          nRN               out number
                                        );

PROCEDURE PD_P_DMSCLCONATTRS_INSERT(
                                      nPRN              in number,
                                      nPOSITION         in number,
                                      sATTRIBUTE        in varchar2,
                                      nRN               out number
                                     );

FUNCTION GET_MSG_TEXT(con_name IN varchar2, con_type IN NUMBER) RETURN varchar2;

PROCEDURE LOAD_CLS_CONSTRAINTS;

PROCEDURE PD_P_DMSCLLINKS_INSERT_ADV(
                                          sSOURCE_CODE      in varchar2,
                                          nDESTINATION      in number,
                                          sSTEREOTYPE       in varchar2,
                                          nFOREIGN_KEY      in number,
                                          sSRC_CONSTRAINT   in varchar2,
                                          sCONSTRAINT_NAME  in varchar2,
                                          sNAME             in varchar2,
                                          nRULE             in number,
                                          sMESSAGE1         in varchar2,
                                          sMESSAGE2         in varchar2,
                                          sLEVEL_ATTR       in varchar2,
                                          sPATH_ATTR        in varchar2,
                                          sMASTER_LINK      in varchar2,
                                          cCONSTRAINT_INIT  in clob,
                                          nRN               out number
                                      );

PROCEDURE PD_P_DMSCLLINKATTRS_INSERT(
                                          nPRN                in number,
                                          nPOSITION           in number,
                                          nSOURCE_CLASS       in number,
                                          nDESTINATION_CLASS  in number,
                                          sSOURCE             in varchar2,
                                          sDESTINATION        in varchar2,
                                          nRN                 out number
                                      );

FUNCTION get_STEREOTYPE(col_name IN varchar2) RETURN varchar2;

PROCEDURE RENAME_CLS_ATTRIBUTES(ATTR_NAME_FILE IN clob);


END PD_PKG_CNTR;
