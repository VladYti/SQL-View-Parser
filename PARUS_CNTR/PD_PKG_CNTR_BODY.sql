CREATE OR REPLACE PACKAGE BODY PARUS.PD_PKG_CNTR AS







FUNCTION LONG_TO_CHAR(
                        in_table_name varchar2,
                        in_column varchar2,
                        in_column_name varchar2,
                        in_tab_name varchar2
                    )
RETURN varchar2 AS

text_c1 varchar2(32767);
sql_cur varchar2(2000);

BEGIN

    sql_cur := 'select '||in_column||' from '||in_table_name||' where column_name = ' ||
                chr(39)||in_column_name||chr(39) ||' AND TABLE_NAME=' || chr(39)||in_tab_name||chr(39);

execute immediate sql_cur into text_c1;

RETURN trim(replace(replace(TEXT_C1, chr(10), '' ), chr(13), ''));

END LONG_TO_CHAR;




FUNCTION GETCAPTION( SBASE_CAPTION IN VARCHAR2 ) RETURN VARCHAR2
   AS
   SCOUNTER VARCHAR2(3):= '0';
   SCUR_CAPTION VARCHAR2(240);
 BEGIN

   SCUR_CAPTION := SBASE_CAPTION;

   WHILE ( TRUE ) LOOP
     BEGIN
       SELECT DA.CAPTION INTO SCUR_CAPTION
       FROM DMSCLATTRS DA
       WHERE DA.PRN = NCLASS_RN AND
             DA.CAPTION = SCUR_CAPTION;

       IF (LENGTH(SBASE_CAPTION) + LENGTH(SCOUNTER) > 240 ) THEN
         SCUR_CAPTION := SUBSTR(SBASE_CAPTION, 1, LENGTH(SBASE_CAPTION) - LENGTH(SCOUNTER)) || SCOUNTER;
       ELSE
         SCUR_CAPTION := SBASE_CAPTION || SCOUNTER;
       END IF;

       SCOUNTER := TO_CHAR(TO_NUMBER(SCOUNTER) + 1);

     EXCEPTION
       WHEN OTHERS THEN
         RETURN SCUR_CAPTION;
     END;
   END LOOP;
 END GETCAPTION;










-- ************************************************************************************
-- ************************************************************************************
-- ************************************************************************************
-- ************************************************************************************
-- ************************************************************************************


FUNCTION GETDOMAIN(
                  SODATA_TYPE IN VARCHAR2,
                  NODATA_PRECISION IN NUMBER := NULL,
                  NODATA_SCALE IN NUMBER := NULL,
                  NODATA_LENGTH IN NUMBER := NULL,
                  SODATA_DEFAULT IN VARCHAR2 := NULL
                  )
RETURN VARCHAR2 AS
STEMP VARCHAR2(20);
BEGIN

    IF ( (SODATA_TYPE = 'VARCHAR2') AND  (NODATA_LENGTH = 20) ) THEN
        RETURN 'TCODE';
    END IF;

    IF ( (SODATA_TYPE = 'NUMBER') AND  (NODATA_PRECISION = 17) AND ( NODATA_SCALE = 0) ) THEN
        RETURN 'TRN';
    END IF;

    IF ( SODATA_TYPE = 'DATE' ) THEN
        RETURN 'TDATE';
    END IF;

    IF ( (SODATA_TYPE = 'NUMBER') AND  (NODATA_PRECISION = 17) AND ( NODATA_SCALE = 2) ) THEN
        RETURN 'TSUM';
    END IF;

    IF ( SODATA_TYPE = 'NUMBER' ) THEN
        STEMP := 'TNUMB'|| LPAD(NODATA_PRECISION, 2, '0') || '.' || LPAD(NODATA_SCALE, 2, '0') || ' DEF ' || CASE WHEN SODATA_DEFAULT IS NULL THEN 'NULL' ELSE SODATA_DEFAULT END;

        FOR REC IN (
                    SELECT  VDD.SCODE
                    FROM    V_DMSDOMAINS VDD
                    WHERE   VDD.SCODE = STEMP
                    )
        LOOP
            RETURN REC.SCODE;
        END LOOP;

    END IF;


    FOR REC IN (
                SELECT  VDD.SCODE
                FROM    V_DMSDOMAINS VDD
                WHERE   (VDD.SDATATYPE_ORA = SODATA_TYPE)
                AND     ( 1 =   CASE WHEN  (SODATA_TYPE = 'NUMBER') THEN
                                    CASE WHEN (VDD.NDATA_PRECISION = NODATA_PRECISION) AND (VDD.NDATA_SCALE = NODATA_SCALE ) THEN 1 ELSE 0 END
                                WHEN  (SODATA_TYPE = 'VARCHAR2') THEN
                                    CASE WHEN (VDD.NDATA_LENGTH = NODATA_LENGTH) THEN 1 ELSE 0 END
                                ELSE 0 END)
                AND     (VDD.NENUMERATED = 0)
                )
    LOOP
        RETURN REC.SCODE;
    END LOOP;


    FOR REC IN (
                SELECT DECODE(SODATA_TYPE, 'VARCHAR2', 'TCODE','NUMBER', 'TRN', 'DATE', 'TDATE', 'CLOB', 'TCLOB' ) AS SRES_DEF
                FROM DUAL
                )
    LOOP
        RETURN REC.SRES_DEF;
    END LOOP;

END GETDOMAIN;

-- ###########################################################################################################################################################################

-- ||------------------------||------------------------||------------------------||------------------------||
-- || Процедура считывания постоянных параметров.                                                          ||
-- ||------------------------||------------------------||------------------------||------------------------||
PROCEDURE INIT_CONST_PARAMS(in_NCLASS_RN IN NUMBER)
AS
BEGIN

    NCLASS_RN := in_NCLASS_RN;

    BEGIN
        SELECT  vd.table_name
        INTO    sbase_table_name
        FROM    unitlist vd
        where   vd.rn = nclass_rn;
    EXCEPTION WHEN NO_DATA_FOUND THEN
        p_exception(0, 'Не найдена основная таблица основного класса:');
    END;


    BEGIN
        SELECT  vd.rn, vd.view_name
        INTO    nbase_view_rn, sbase_view_name
        FROM    DMSCLVIEWS vd
        WHERE   vd.prn = nclass_rn;
    EXCEPTION WHEN NO_DATA_FOUND THEN
        p_exception(0, 'Не найдено представление основного класса: ' || sbase_table_name);
    END;

    cbase_view_clob := dbms_metadata.get_ddl('VIEW', upper(sbase_view_name), 'PARUS');



END INIT_CONST_PARAMS;

-- ###########################################################################################################################################################################

-- ||------------------------||------------------------||------------------------||------------------------||
-- || Конвеерная функция деления clob переменных по заяптой                                                ||
-- || На выход выдает табличку, в строчках которой содержатся кусочки clob переменной                      ||
-- ||------------------------||------------------------||------------------------||------------------------||

FUNCTION SPLIT_CLOB(IN_CLOB  IN CLOB)
RETURN TA_CLOB PIPELINED  AS

TMP_CLOB    CLOB;
TMP_RES     A_CLOB;
IDX         NUMBER;

BEGIN

    TMP_CLOB := IN_CLOB;
    WHILE ( REGEXP_INSTR(TMP_CLOB, '\,') <> 0 ) LOOP

        IDX := REGEXP_INSTR(TMP_CLOB, '\,');
        TMP_RES.CLOB_ROW := SUBSTR(TMP_CLOB, 1, IDX-1);

        PIPE ROW (TMP_RES);

        TMP_CLOB := SUBSTR(TMP_CLOB, IDX+1);
    END LOOP;

    TMP_RES.CLOB_ROW := TMP_CLOB;
    PIPE ROW (TMP_RES);

END SPLIT_CLOB;

-- ###########################################################################################################################################################################

-- ||------------------------||------------------------||------------------------||------------------------||
-- || Функция подготовки clob переменной к обработке                                                       ||
-- || Удаляет все лишние символы, переносы строк, комментарии, и тп                                        ||
-- ||------------------------||------------------------||------------------------||------------------------||

FUNCTION PREPARE_BASE_VIEW_CLOB( REPLACE_TO IN VARCHAR2 )
RETURN CLOB AS

CVIEW CLOB;

BEGIN

  CVIEW := UPPER(CBASE_VIEW_CLOB);

  CVIEW := REGEXP_REPLACE(CVIEW, '--.*$', ' ', 1, 0, 'm' );


  CVIEW := REGEXP_REPLACE(CVIEW, '[[:cntrl:]]', ' ');

  CVIEW := REGEXP_REPLACE(CVIEW, ',', ' , ');
  CVIEW := REGEXP_REPLACE(CVIEW, '\s+CASE\s+', ' ( ');
  CVIEW := REGEXP_REPLACE(CVIEW, '\s+END\s+', ' ) ');

  CVIEW := REGEXP_REPLACE(CVIEW, '[[:space:]]+', ' ');

  CVIEW := REGEXP_REPLACE(CVIEW, '"', '');

  WHILE ( INSTR(CVIEW, '(') != 0 ) LOOP
    CVIEW := REGEXP_REPLACE(CVIEW, '\([^()]*\)', REPLACE_TO);
  END LOOP;


  RETURN CVIEW;

END PREPARE_BASE_VIEW_CLOB;

-- ###########################################################################################################################################################################

-- ||------------------------||------------------------||------------------------||------------------------||
-- || Функция возвращает срез переменной типа clob                                                         ||
-- || Позиции среза определяются позициями символов                                                        ||
-- ||------------------------||------------------------||------------------------||------------------------||

FUNCTION GET_SLICE(IN_VIEW IN CLOB, SFROM IN VARCHAR2, STO IN VARCHAR2) RETURN CLOB AS

NFROM  NUMBER;
NTO    NUMBER;

BEGIN
  NFROM := REGEXP_INSTR(IN_VIEW, '\s'||SFROM||'\s', 1, 1, 1) - 1;

  IF (STO IS NULL) THEN
    NTO := LENGTH(IN_VIEW);
  ELSE
    NTO := REGEXP_INSTR(IN_VIEW, '\s'||STO||'\s');
    IF NTO = 0 THEN
       NTO := LENGTH(IN_VIEW);
    END IF;
  END IF;

  RETURN SUBSTR(IN_VIEW, NFROM, NTO-NFROM+1);
END GET_SLICE;

-- ###########################################################################################################################################################################

-- ||------------------------||------------------------||------------------------||------------------------||
-- || Конвеерная функция обработки представления.                                                          ||
-- || Первая из двух основных. Эта возвращает наружу табличку типа:                                        ||
-- || (<Номер колонки представления>, <Псевдоним таблицы>, <Наименование колонки>)                         ||
-- ||------------------------||------------------------||------------------------||------------------------||
FUNCTION GET_COLUMNS_ALIASES RETURN TA_COLS PIPELINED AS

RES         A_COLS;
TMP_TA_COLS TA_CLOB;

BEGIN

    FOR REC IN (
                SELECT  TRIM(REGEXP_SUBSTR(' ' || TMP.CLOB_ROW || ' ', '\s[A-Za-z0-9\_]+\.[A-Za-z0-9\_]+\s')) AS VAL,
                        ROWNUM AS LINE_ID
                FROM TABLE( SPLIT_CLOB( GET_SLICE(PREPARE_BASE_VIEW_CLOB( 'R' ), 'SELECT', 'FROM') ) ) TMP
                )
    LOOP
        RES.N := REC.LINE_ID;
        RES.AL := SUBSTR(REC.VAL, 1, INSTR(REC.VAL, '.')-1);
        RES.COL := SUBSTR(REC.VAL, INSTR(REC.VAL, '.') + 1);

        PIPE ROW (RES);
    END LOOP;

END GET_COLUMNS_ALIASES;

-- ###########################################################################################################################################################################

-- ||------------------------||------------------------||------------------------||------------------------||
-- || Конвеерная функция обработки представления.                                                          ||
-- || Вторая из двух основных. Эта вызвращает наружу табличку типа:                                        ||
-- || Эта возвращает наружу табличку типа:                                                                 ||
-- || (<Наименование таблицы>, <Псевдоним таблицы>, <Имя колонки основной таблицы для связи>)              ||
-- ||------------------------||------------------------||------------------------||------------------------||
FUNCTION GET_TABLES_ALIASES RETURN ta_tabs pipelined AS


tmp_a_tabs  a_tabs;

Type list_type_vv Is Table Of varchar2(2000) Index By Varchar2(100);
tmp_cols        list_type_vv;


sbase_alias     varchar2(100);
sindex_cols     varchar2(100);
sregexp_link    varchar2(2000);

tmp_conditions  clob;
conditions      clob;

cprepared_base_view_clob clob := prepare_base_view_clob( '' );

begin

    for rec in (
                   select   substr(trim(tmp.clob_row), 1, instr(trim(tmp.clob_row), ' ') -1)        as stable_name,
                            substr(trim(tmp.clob_row), instr(trim(tmp.clob_row), ' ') +1) || ' '    as stable_alias
                   from     table( split_clob(regexp_replace(get_slice(cprepared_base_view_clob, 'FROM', 'WHERE'), '(\sINNER|\sLEFT|\sRIGTH)?\sJOIN\s', ',')) ) tmp
               )
    LOOP
        if regexp_instr(rec.stable_alias, '\sON\s', 1, 1, 1) <> 0 then
            tmp_conditions := tmp_conditions  ||  substr(rec.stable_alias, regexp_instr(rec.stable_alias, '\sON\s', 1, 1, 1)) || ' AND ';
        end if;

        if ( sbase_table_name = rec.stable_name ) then
            sbase_alias := rec.stable_alias;
        end if;

        tmp_cols(trim(regexp_substr(rec.stable_alias, '\S+\s'))) := rec.stable_name;

    END LOOP;

    conditions := ' ' || tmp_conditions || get_slice(cprepared_base_view_clob, 'WHERE', null) || ' ';

    sindex_cols := tmp_cols.first;

    while (sindex_cols is not null) loop

        sregexp_link := '(\s'|| trim(sbase_alias) || '\.\S+\s+\=)?\s+' || trim(sindex_cols) ||'\.RN\s+(\=\s+'|| trim(sbase_alias) || '.\S+)?';

        tmp_a_tabs.tname :=  tmp_cols(sindex_cols);
        tmp_a_tabs.aname := sindex_cols;
        IF trim(sbase_alias) = trim(sindex_cols) THEN
            tmp_a_tabs.lcname := null;
        ELSE
            tmp_a_tabs.lcname := substr(regexp_substr(regexp_substr(conditions, sregexp_link), '\s' || trim(sbase_alias) || '\.\S+'),  length(sbase_alias) + 2);
        END IF;

        pipe ROW ( tmp_a_tabs );

        sindex_cols := tmp_cols.next(sindex_cols);
    end loop;

END GET_TABLES_ALIASES;

-- ###########################################################################################################################################################################

-- ||------------------------||------------------------||------------------------||------------------------||
-- || Табличная конвеерная функция. Возвращает табличку типа                                               ||
-- || (COLUMB_ID            <НОМЕР ПОЛЯ ПРЕДСТАВЛЕНИЯ>,                                                    ||
-- ||  COLUMN_NAME          <ИМЯ ПОЛЯ ПРЕДСТАВЛЕНИЯ>,                                                      ||
-- ||  R_TABLE_NAME         <ИМЯ РЕФЕРЕНСНОЙ ТАБЛИЦЫ>,                                                     ||
-- ||  R_COLUMN_NAME        <ИМЯ ПОЛЯ РЕФЕРЕНСНОЙ ТАБЛИЦЫ>,                                                ||
-- ||  LINK_COLUMN_NAME     <ИМЯ ПОЛЯ "ОСНОВНОЙ ТАБЛИЦЫ" ДЛЯ СВЯЗИ>)                                       ||
-- ||   Таблица эта используется при добавлении атрибутов представления                                    ||
-- ||------------------------||------------------------||------------------------||------------------------||
FUNCTION LINK_VIEW_COLUMNS RETURN ta_VLINK pipelined AS
BEGIN

    FOR rec IN (
                SELECT  a.column_id,
                        a.column_name,
                        coll.r_table_name,
                        coll.r_column_name,
                        coll.lcname
                FROM    user_tab_columns a
                JOIN    (
                            SELECT  tmp1.n  AS line_n,
                                    tmp1.col AS r_column_name,
                                    tmp2.tname AS r_table_name,
                                    tmp2.aname AS al1,
                                    tmp2.lcname
                            FROM        table( GET_COLUMNS_ALIASES() ) tmp1
                            LEFT JOIN   table( GET_TABLES_ALIASES() ) tmp2 ON  trim(UPPER(tmp2.aname)) = trim(upper(tmp1.al))
                        ) coll
                ON coll.line_n = a.column_id AND a.TABLE_NAME = sbase_view_name
                )
    LOOP

        pipe ROW ( rec );

    END LOOP;

END LINK_VIEW_COLUMNS;

-- ###########################################################################################################################################################################

-- ||------------------------||------------------------||------------------------||------------------------||
-- || Процедура добавления параметров предствления. Идет по таблице параметров и добавляет                 ||
-- || их в таблицы паруса. Использут для обработки табличную функцию, возвращающую список параметров.      ||
-- ||------------------------||------------------------||------------------------||------------------------||
PROCEDURE LOAD_CLS_VIEW_ATTRIBUTES AS

LINK_NAME                   VARCHAR2(4000);
SCLASS_ATTR_DOMAIN          VARCHAR2(4000);
SCLASS_REF_ATTR             VARCHAR2(4000);
SCLASS_ATTR_CAPTION         VARCHAR2(4000);

REF_CLASS_RN                NUMBER(17);
NLINK_TYPE                  NUMBER(1);
NVIEW_ATTR_RN               NUMBER(17);
NCLASS_ATTR_RN              NUMBER(17);
NCLASS_ATTR_POS             NUMBER(17);

BEGIN

    SELECT count(*) + 1 INTO nclass_attr_pos FROM DMSCLATTRS d WHERE d.prn = nclass_rn;

    FOR view_col IN (SELECT * FROM TABLE( LINK_VIEW_COLUMNS() ) )
    LOOP
        nview_attr_rn := NULL;
        IF view_col.r_table_name = trim(sbase_table_name) THEN

            P_DMSCLVIEWSATTRS_INSERT
                                    (
                                      nPRN              => nbase_view_rn,           -- in number,
                                      sATTR             => view_col.r_column_name,  -- in varchar2,
                                      sCOLUMN_NAME      => view_col.column_name,    -- in varchar2,
                                      nRN               => nview_attr_rn            -- out number
                                    );

            CONTINUE;
        END IF;


        BEGIN
            SELECT  d."SOURCE",
                    d.CONSTRAINT_NAME
            INTO    ref_class_rn,
                    link_name
            FROM    DMSCLLINKS d
            JOIN    unitlist u          ON u.rn = d."SOURCE"        AND u.table_name = view_col.r_table_name
            JOIN    DMSCLLINKATTRS VDA  ON VDA.PRN = D.RN
            JOIN    DMSCLATTRS d2       ON VDA."SOURCE" = D2.RN     AND D2.COLUMN_NAME = 'RN'
            JOIN    DMSCLATTRS d3       ON VDA.DESTINATION = D3.RN  AND d3.COLUMN_NAME = view_col.link_column_name
            WHERE   d.DESTINATION =  nclass_rn;

            nlink_TYPE := 2;
            sclass_ref_attr := view_col.r_column_name;
        EXCEPTION WHEN NO_DATA_FOUND THEN
            link_name := NULL;
            nlink_TYPE := 1;

            sclass_ref_attr := NULL;
            sclass_attr_caption := view_col.column_name;

        WHEN TOO_MANY_ROWS THEN
            P_EXCEPTION(0, view_col.r_table_name || ' ' || view_col.r_COLUMN_name || ' ' || view_col.COLUMN_name || ' ' || nclass_rn);
        END;

        IF (view_col.r_table_name IS NOT NULL) AND (view_col.r_table_name <> sbase_table_name ) THEN
            BEGIN
                SELECT  vd.SDOMAIN, vd.scaption || ' (' || nclass_attr_pos || ')'
                INTO    sclass_attr_DOMAIN, sclass_attr_caption
                FROM    V_DMSCLATTRS vd
                JOIN    unitlist u ON vd.nprn=u.rn
                AND     vd.SCOLUMN_NAME = view_col.r_column_name
                AND     u.table_name = view_col.R_TABLE_NAME AND rownum = 1;
            EXCEPTION WHEN NO_DATA_FOUND THEN
                p_exception(0, 'Не найдено поле - ' || view_col.r_column_name || ' в классе таблицы - ' || view_col.R_TABLE_NAME);
            WHEN TOO_MANY_ROWS THEN
                p_exception(0, view_col.r_column_name || ' ' || view_col.R_TABLE_NAME);
            END;

        ELSIF (view_col.r_table_name IS NULL) THEN
            FOR attr IN (SELECT a.data_type,
                                a.DATA_PRECISION,
                                a.DATA_SCALE,
                                a.DATA_LENGTH,
                                a.DATA_DEFAULT
                         FROM   all_tab_columns a
                         WHERE  a.table_name =  sbase_view_name
                         AND    a.column_name =  view_col.column_name)
            LOOP

                sclass_attr_DOMAIN := GETDOMAIN(
                                                  SODATA_TYPE       => attr.data_type,      -- IN VARCHAR2,
                                                  NODATA_PRECISION  => attr.DATA_PRECISION, -- IN NUMBER := NULL,
                                                  NODATA_SCALE      => attr.DATA_SCALE,     -- IN NUMBER := NULL,
                                                  NODATA_LENGTH     => attr.DATA_LENGTH,    -- IN NUMBER := NULL,
                                                  SODATA_DEFAULT    => attr.DATA_DEFAULT    -- IN VARCHAR2 := NULL
                                                );



            END LOOP;

            IF sclass_attr_DOMAIN IS NULL THEN
                p_exception(0, 'Не удалось определить домен атрибута');
            END IF;

        END IF;


        P_DMSCLATTRS_INSERT(
                              nPRN              => nclass_rn,               -- in number,          -- регистрационный номер записи класса
                              sCOLUMN_NAME      => view_col.column_name,    -- in varchar2,        -- имя атрибута
                              sCAPTION          => sclass_attr_caption,     -- in varchar2,        -- наименование атрибута
                              nKIND             => nlink_TYPE,              -- in number,          -- тип атрибута
                              nPOSITION         => nclass_attr_pos,         -- in number,          -- позиция атрибута
                              sDOMAIN           => sclass_attr_DOMAIN,      -- in varchar2,        -- мнемокод домена
                              sREF_LINK         => link_name,               -- in varchar2,        -- имя связи ссылки
                              sREF_ATTRIBUTE    => sclass_ref_attr,         -- in varchar2,        -- имя атрибута ссылки
                              nRN               => nclass_attr_rn           -- out number          -- регистрационный номер записи атрибута
                            );


        nclass_attr_pos := nclass_attr_pos + 1;
        P_DMSCLVIEWSATTRS_INSERT
                                    (
                                      nPRN              => nbase_view_rn,           -- in number,
                                      sATTR             => view_col.column_name,    -- in varchar2,
                                      sCOLUMN_NAME      => view_col.column_name,    -- in varchar2,
                                      nRN               => nview_attr_rn            -- out number
                                    );


        SCLASS_REF_ATTR     := NULL;
        NCLASS_ATTR_RN      := NULL;
        SCLASS_ATTR_DOMAIN  := NULL;
        REF_CLASS_RN        := NULL;
        LINK_NAME           := NULL;
        NLINK_TYPE          := NULL;
        SCLASS_ATTR_CAPTION := NULL;

    END LOOP;

END LOAD_CLS_VIEW_ATTRIBUTES;




-- ###########################################################################################################################################################################
-- ###########################################################################################################################################################################

-- Секиция загрузки атрибутов класса
-- ###########################################################################################################################################################################


-- ||------------------------||------------------------||------------------------||--------------------------||
-- || Процедура добавления атрибута. Стандартная процедура, в которой исключена фиксация начала и окончания  ||
-- ||------------------------||------------------------||------------------------||--------------------------||
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
)
as
  rMREC             UNITLIST%rowtype;
  rREC              DMSCLATTRS%rowtype;
begin
  /* считывание записи класса */
  PARUS.P_DMSCLASSES_EXISTS( nPRN,rMREC );

  /* фиксация начала выполнения действия */
  --PKG_ENV.PROLOGUE( null,null,null,null,rMREC.RN,'DMSClassesAttributes','DMSCLATTRS_INSERT','DMSCLATTRS' );

  /* разрешение ссылок */
  PARUS.P_DMSCLATTRS_JOINS
  (
    nCLASS_RN      => rMREC.RN,
    sDOMAIN        => sDOMAIN,
    sREF_LINK      => sREF_LINK,
    sREF_ATTRIBUTE => sREF_ATTRIBUTE,
    nDOMAIN        => rREC.DOMAIN,
    nREF_LINK      => rREC.REF_LINK,
    nREF_ATTRIBUTE => rREC.REF_ATTRIBUTE
  );

  /* базовое добавление */
  PARUS.P_DMSCLATTRS_BASE_INSERT
  (
    nPRN           => rMREC.RN,
    sCOLUMN_NAME   => sCOLUMN_NAME,
    sCAPTION       => sCAPTION,
    nKIND          => nKIND,
    nPOSITION      => nPOSITION,
    nDOMAIN        => rREC.DOMAIN,
    nREF_LINK      => rREC.REF_LINK,
    nREF_ATTRIBUTE => rREC.REF_ATTRIBUTE,
    sPRODUCER      => null,
    nRN            => nRN
  );

  /* фиксация окончания выполнения действия */
  --PKG_ENV.EPILOGUE( null,null,null,null,rMREC.RN,'DMSClassesAttributes','DMSCLATTRS_INSERT','DMSCLATTRS',nRN );
end PD_P_DMSCLATTRS_INSERT;


-- ###########################################################################################################################################################################

-- ||------------------------||------------------------||------------------------||--------------------------||
-- || Процедура добавления атрибутов класса. Идет по табличке и добавляет основные атрибуты                  ||
-- ||------------------------||------------------------||------------------------||--------------------------||
PROCEDURE LOAD_CLS_ATTRIBUTES AS
 NTEMP_RN NUMBER;

 STEMP_CAPTION VARCHAR2(240);

BEGIN

    FOR REC_COLUMN IN (
                      SELECT TRIM(DTC.COLUMN_NAME) AS COLUMN_NAME,
                             DTC.DATA_TYPE,
                             DTC.DATA_PRECISION,
                             DTC.DATA_SCALE,
                             DTC.DATA_LENGTH,
                             LONG_TO_CHAR('SYS.DBA_TAB_COLUMNS', 'DATA_DEFAULT', DTC.COLUMN_NAME, sbase_table_name ) AS DATA_DEFAULT,
                             CASE WHEN ACC.COMMENTS IS NULL THEN DTC.COLUMN_NAME
                                  ELSE SUBSTR(ACC.COMMENTS, 1, 240)
                             END AS SCAPTION,
                             ROW_NUMBER() OVER( ORDER BY DTC.COLUMN_ID ) AS NNUMBER
                      FROM SYS.DBA_TAB_COLUMNS  DTC
                      INNER JOIN ALL_COL_COMMENTS ACC
                      ON (DTC.TABLE_NAME = sbase_table_name) AND
                         (DTC.TABLE_NAME = ACC.TABLE_NAME) AND
                         (DTC.COLUMN_NAME = ACC.COLUMN_NAME)
                      ORDER BY DTC.COLUMN_ID
                    )
    LOOP
        BEGIN
            PD_P_DMSCLATTRS_INSERT(
                                    NPRN              => NCLASS_RN,                         -- РЕГИСТРАЦИОННЫЙ НОМЕР ЗАПИСИ КЛАССА
                                    SCOLUMN_NAME      => REC_COLUMN.COLUMN_NAME,            -- ИМЯ АТРИБУТА
                                    SCAPTION          => GETCAPTION( REC_COLUMN.SCAPTION ),        -- НАИМЕНОВАНИЕ АТРИБУТА
                                    NKIND             => 0,                             -- ТИП АТРИБУТА
                                    NPOSITION         => REC_COLUMN.NNUMBER,            -- ПОЗИЦИЯ АТРИБУТА
                                    SDOMAIN           => GETDOMAIN( REC_COLUMN.DATA_TYPE, REC_COLUMN.DATA_PRECISION , REC_COLUMN.DATA_SCALE , REC_COLUMN.DATA_LENGTH ),                              -- МНЕМОКОД ДОМЕНА
                                    SREF_LINK         => NULL,                          -- ИМЯ СВЯЗИ ССЫЛКИ
                                    SREF_ATTRIBUTE    => NULL,                          -- ИМЯ АТРИБУТА ССЫЛКИ
                                    NRN               => NTEMP_RN                       -- РЕГИСТРАЦИОННЫЙ НОМЕР ЗАПИСИ АТРИБУТА
                                    );

            NTEMP_RN := NULL;
        EXCEPTION WHEN OTHERS THEN
            -- Если не удалось добавить атрибут, то ниче не делаем
            NULL;
        END;
    END LOOP;

END LOAD_CLS_ATTRIBUTES;




-- ###########################################################################################################################################################################
-- ###########################################################################################################################################################################
-- ###########################################################################################################################################################################



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
                                        ) AS
  rMREC             UNITLIST%rowtype;
  rREC              DMSCLCONSTRS%rowtype;
begin
  /* считывание записи класса */
  P_DMSCLASSES_EXISTS( nPRN,rMREC );

  /* фиксация начала выполнения действия */
  --PKG_ENV.PROLOGUE( null,null,null,null,rMREC.RN,'DMSClassesConstraints','DMSCLCONSTRS_INSERT','DMSCLCONSTRS' );

  /* разрешение ссылок */
  PARUS.P_DMSCLCONSTRS_JOINS
  (
    nPRN            => rMREC.RN,
    sCHECK_FUNCTION => sCHECK_FUNCTION,
    sMESSAGE        => sMESSAGE,
    nCHECK_FUNCTION => rREC.CHECK_FUNCTION,
    nMESSAGE        => rREC.MESSAGE
  );

  /* базовое добавление */
  PARUS.P_DMSCLCONSTRS_BASE_INSERT
  (
    nPRN              => rMREC.RN,
    sCONSTRAINT_NAME  => sCONSTRAINT_NAME,
    sCONSTRAINT_NOTE  => sNAME,
    nPRN_CONSTRAINT   => null,
    nCHECK_FUNCTION   => rREC.CHECK_FUNCTION,
    nCONSTRAINT_TYPE  => nCONSTRAINT_TYPE,
    nMESSAGE          => rREC.MESSAGE,
    sCONSTRAINT_TEXT  => sCONSTRAINT_TEXT,
    cCONSTRAINT_INIT  => cCONSTRAINT_INIT,
    nLINKS_SIGN       => nLINKS_SIGN,
    iSWAP_LINKS_SIGN  => 0,
    sPRODUCER         => null,
    nRN               => nRN
  );

  /* фиксация окончания выполнения действия */
  --PKG_ENV.EPILOGUE( null,null,null,null,rMREC.RN,'DMSClassesConstraints','DMSCLCONSTRS_INSERT','DMSCLCONSTRS',nRN );
end PD_P_DMSCLCONSTRS_INSERT_ADV;

-- ###########################################################################################################################################################################

PROCEDURE PD_P_DMSCLCONATTRS_INSERT(
                                      nPRN              in number,
                                      nPOSITION         in number,
                                      sATTRIBUTE        in varchar2,
                                      nRN               out number
                                     ) AS
  rMREC             DMSCLCONSTRS%rowtype;
  rREC              DMSCLCONATTRS%rowtype;
begin
  /* считывание записи ограничения класса */
  P_DMSCLCONSTRS_EXISTS( nPRN,rMREC );

  /* фиксация начала выполнения действия */
  --PKG_ENV.PROLOGUE( null,null,null,null,rMREC.PRN,'DMSClassesConstraintsAttributes','DMSCLCONATTRS_INSERT','DMSCLCONATTRS' );

  /* разрешение ссылок */
  PARUS.P_DMSCLCONATTRS_JOINS
  (
    nCLASS     => rMREC.PRN,
    sATTRIBUTE => sATTRIBUTE,
    nATTRIBUTE => rREC.ATTRIBUTE
  );

  /* базовое добавление */
  PARUS.P_DMSCLCONATTRS_BASE_INSERT
  (
    nPRN       => rMREC.RN,
    nPOSITION  => nPOSITION,
    nATTRIBUTE => rREC.ATTRIBUTE,
    sPRODUCER  => null,
    nRN        => nRN
  );

  /* фиксация окончания выполнения действия */
  --PKG_ENV.EPILOGUE( null,null,null,null,rMREC.PRN,'DMSClassesConstraintsAttributes','DMSCLCONATTRS_INSERT','DMSCLCONATTRS',nRN );
end PD_P_DMSCLCONATTRS_INSERT;

-- ###########################################################################################################################################################################

FUNCTION GET_MSG_TEXT(con_name IN varchar2, con_type IN NUMBER)
RETURN varchar2 AS
msg_rn      varchar2(32);
tmp         NUMBER;
s_text      varchar2(1000);
BEGIN
    
    SELECT  'Нарушение ' ||  decode(con_type, 0, 'Уникальности', 1, 'Уникальности (первичный ключ)', 2, 'Проверки') || ' ('
    INTO    s_text
    FROM    dual;
--    s_text := 'Нарушение ' ||  decode(con_type, 0, 'Уникальности', 1, 'Уникальности (первичный ключ)', 2, 'Проверки') || ' (';
    
    FOR COL IN (    SELECT  U.COLUMN_NAME,
                            REGEXP_REPLACE(D.CAPTION, '\([^()]*\)', '') AS CAPTION, 
                            ROWNUM AS       POS1
                    FROM    USER_CONS_COLUMNS U
                    JOIN    UNITLIST UL ON UL.TABLE_NAME = U.TABLE_NAME 
                    JOIN    DMSCLATTRS D ON D.PRN = UL.RN AND D.COLUMN_NAME = U.COLUMN_NAME 
                    WHERE   U.CONSTRAINT_NAME =  CON_TYPE
                )
    LOOP 
        s_text := s_text || col.COLUMN_NAME || ' - ' || col.CAPTION || ', ';
        
    END LOOP;
    
    s_text := s_text || '). ' || con_name;
    
    
    BEGIN
        SELECT d.code INTO msg_rn  FROM DMSMESSAGEs d WHERE d.code = con_name;
    EXCEPTION WHEN NO_DATA_FOUND THEN
        P_DMSMESSAGES_INSERT(con_name, 1, s_text, tmp);
    END;

    RETURN con_name;
END GET_MSG_TEXT;


-- ###########################################################################################################################################################################
-- +?
PROCEDURE LOAD_CLS_CONSTRAINTS AS

cinit               clob;
nconstraint_rn      number(17);
nconstraint_attr_rn NUMBER(17);

BEGIN

        FOR cn IN ( SELECT  al.CONSTRAINT_NAME,
                            decode(al.CONSTRAINT_TYPE, 'U', '0', 'P', '1', 'C', '2') AS CON_TYPE
                    FROM    all_constraints al
                    WHERE   al.owner = 'PARUS'
                    AND     al.table_name = sbase_table_name
                    AND     al.constraint_type IN ('C', 'P', 'U')
                    AND     al."GENERATED" <> 'GENERATED NAME')
        LOOP



            BEGIN
                SELECT d.rn INTO nconstraint_rn FROM DMSCLCONSTRS d WHERE d.CONSTRAINT_NAME = cn.CONSTRAINT_NAME;
            EXCEPTION WHEN NO_DATA_FOUND THEN

                PD_P_DMSCLCONSTRS_INSERT_ADV(
                                              nPRN              => NCLASS_RN, -- number,
                                              sNAME             => cn.CONSTRAINT_NAME, -- varchar2,
                                              sCONSTRAINT_NAME  => cn.CONSTRAINT_NAME, --varchar2,
                                              nCONSTRAINT_TYPE  => cn.con_type, --number,
                                              sCHECK_FUNCTION   => null, --varchar2,
                                              sMESSAGE          => get_msg_text(cn.CONSTRAINT_NAME, cn.con_type), --varchar2,
                                              sCONSTRAINT_TEXT  => null, --varchar2,
                                              cCONSTRAINT_INIT  => cinit, --clob,
                                              nLINKS_SIGN       => 0, --number,
                                              nRN               => nconstraint_rn --out number
                                            );

            END;

            FOR col IN (    SELECT  u.COLUMN_NAME,
                                    rownum AS       pos1
                            FROM    USER_CONS_COLUMNS u
                            WHERE   u.CONSTRAINT_NAME =  cn.CONSTRAINT_NAME)
            LOOP
                BEGIN
                PD_P_DMSCLCONATTRS_INSERT(
                                   nPRN              => nconstraint_rn, -- in number,
                                   nPOSITION         => col.pos1, -- in number,
                                   sATTRIBUTE        => col.COLUMN_NAME, -- in varchar2,
                                   nRN               => nconstraint_attr_rn -- out number
                                  );
                EXCEPTION WHEN OTHERS THEN
                    NULL;
                    -- ADD_LOG
                END;

                nconstraint_attr_rn := NULL;
            END LOOP;

            nconstraint_rn := NULL;
        END LOOP;

END LOAD_CLS_CONSTRAINTS;







-- ###########################################################################################################################################################################
-- ###########################################################################################################################################################################
-- ###########################################################################################################################################################################




/* Загрузка связей */

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
                                      ) AS
  rMREC             UNITLIST%rowtype;
  rREC              DMSCLLINKS%rowtype;
begin
  /* считывание записи класса */
  P_DMSCLASSES_EXISTS( nDESTINATION,rMREC );

  /* фиксация начала выполнения действия */
  --PKG_ENV.PROLOGUE( null,null,null,null,rMREC.RN,'DMSClassesLinks','DMSCLLINKS_INSERT','DMSCLLINKS' );

  /* разрешение ссылок */
  PARUS.P_DMSCLLINKS_JOINS
  (
    sSOURCE_CODE    => sSOURCE_CODE,
    sSTEREOTYPE     => sSTEREOTYPE,
    sSRC_CONSTRAINT => sSRC_CONSTRAINT,
    sMESSAGE1       => sMESSAGE1,
    sMESSAGE2       => sMESSAGE2,
    sLEVEL_ATTR     => sLEVEL_ATTR,
    sPATH_ATTR      => sPATH_ATTR,
    nDESTINATION    => rMREC.RN,
    sMASTER_LINK    => sMASTER_LINK,
    nSOURCE         => rREC.SOURCE,
    nSTEREOTYPE     => rREC.STEREOTYPE,
    nSRC_CONSTRAINT => rREC.SRC_CONSTRAINT,
    nMESSAGE1       => rREC.MESSAGE1,
    nMESSAGE2       => rREC.MESSAGE2,
    nLEVEL_ATTR     => rREC.LEVEL_ATTR,
    nPATH_ATTR      => rREC.PATH_ATTR,
    nMASTER_LINK    => rREC.MASTER_LINK
  );

  /* базовое добавление */
  PARUS.P_DMSCLLINKS_BASE_INSERT
  (
    nSOURCE          => rREC.SOURCE,
    nDESTINATION     => rMREC.RN,
    nSTEREOTYPE      => rREC.STEREOTYPE,
    nFOREIGN_KEY     => nFOREIGN_KEY,
    nSRC_CONSTRAINT  => rREC.SRC_CONSTRAINT,
    sCONSTRAINT_NAME => sCONSTRAINT_NAME,
    sCONSTRAINT_NOTE => sNAME,
    nRULE            => nRULE,
    nMESSAGE1        => rREC.MESSAGE1,
    nMESSAGE2        => rREC.MESSAGE2,
    nLEVEL_ATTR      => rREC.LEVEL_ATTR,
    nPATH_ATTR       => rREC.PATH_ATTR,
    nMASTER_LINK     => rREC.MASTER_LINK,
    cCONSTRAINT_INIT => cCONSTRAINT_INIT,
    sPRODUCER        => null,
    nRN              => nRN
  );

  /* фиксация окончания выполнения действия */
  --PKG_ENV.EPILOGUE( null,null,null,null,rMREC.RN,'DMSClassesLinks','DMSCLLINKS_INSERT','DMSCLLINKS',nRN );
end PD_P_DMSCLLINKS_INSERT_ADV;

-- ###########################################################################################################################################################################

PROCEDURE PD_P_DMSCLLINKATTRS_INSERT(
                                          nPRN                in number,
                                          nPOSITION           in number,
                                          nSOURCE_CLASS       in number,
                                          nDESTINATION_CLASS  in number,
                                          sSOURCE             in varchar2,
                                          sDESTINATION        in varchar2,
                                          nRN                 out number
                                      ) AS
  rMREC               DMSCLLINKS%rowtype;
  rREC                DMSCLLINKATTRS%rowtype;
begin
  /* считывание записи связи классов */
  P_DMSCLLINKS_EXISTS( nPRN,rMREC );

  /* фиксация начала выполнения действия */
  --PKG_ENV.PROLOGUE( null,null,null,null,rMREC.DESTINATION,'DMSClassesLinksAttributes','DMSCLLINKATTRS_INSERT','DMSCLLINKATTRS' );

  /* разрешение ссылок */
  PARUS.P_DMSCLLINKATTRS_JOINS
  (
    nSOURCE_CLASS      => nSOURCE_CLASS,
    nDESTINATION_CLASS => nDESTINATION_CLASS,
    sSOURCE            => sSOURCE,
    sDESTINATION       => sDESTINATION,
    nSOURCE            => rREC.SOURCE,
    nDESTINATION       => rREC.DESTINATION
  );

  /* базовое добавление */
  PARUS.P_DMSCLLINKATTRS_BASE_INSERT
  (
    nPRN         => nPRN,
    nPOSITION    => nPOSITION,
    nSOURCE      => rREC.SOURCE,
    nDESTINATION => rREC.DESTINATION,
    sPRODUCER    => null,
    nRN          => nRN
   );

  /* фиксация окончания выполнения действия */
  --PKG_ENV.EPILOGUE( null,null,null,null,rMREC.DESTINATION,'DMSClassesLinksAttributes','DMSCLLINKATTRS_INSERT','DMSCLLINKATTRS',nRN );
end PD_P_DMSCLLINKATTRS_INSERT;

-- ###########################################################################################################################################################################

FUNCTION get_STEREOTYPE(col_name IN varchar2)
RETURN varchar2 AS
BEGIN
    FOR rec IN (SELECT decode(col_name, 'CRN', 'Связь с каталогами',
                                        'COMPANY', 'Связь с организациями',
                                        'PRN', 'Master-Detail',
                                        'VERSION', 'Связь с версиями', null) AS res FROM dual)
    LOOP
        RETURN rec.res;
    END LOOP;
END get_STEREOTYPE;

-- ###########################################################################################################################################################################

PROCEDURE LOAD_CLS_LINKS AS

fk_rn       NUMBER;
fk_atr_rn  NUMBER;
cinit   clob;

BEGIN

    FOR cn IN (SELECT  ac.CONSTRAINT_NAME       AS con_name,
                        ac.TABLE_NAME           AS tab_name,
                        ucc.column_name         AS col_name,
                        ac.R_CONSTRAINT_NAME    AS ref_con_name,
                        ucc_ref.table_name      AS ref_tab_name,
                        ucc_ref.column_name     AS ref_col_name,
                        (SELECT u.unitcode FROM UNITLIST u WHERE u.table_name = ucc_ref.table_name AND rownum = 1)  AS ref_unitcode,
                        (SELECT u.rn FROM UNITLIST u WHERE u.table_name = ucc_ref.table_name AND rownum = 1)        AS ref_unit_rn
                FROM    all_constraints ac
                JOIN    USER_CONS_COLUMNS ucc ON ucc.CONSTRAINT_NAME = ac.CONSTRAINT_NAME
                JOIN    USER_CONS_COLUMNS ucc_ref ON ucc_ref.CONSTRAINT_NAME = ac.R_CONSTRAINT_NAME
                WHERE   ac.owner = 'PARUS' AND ac.table_name = sbase_table_name  AND ac.constraint_type IN ('R') AND ac."GENERATED" <> 'GENERATED NAME')
    LOOP

        BEGIN
            SELECT d.rn INTO fk_rn FROM DMSCLLINKS d WHERE d.CONSTRAINT_NAME = cn.con_name;
        EXCEPTION WHEN NO_DATA_FOUND THEN
            BEGIN
                PD_P_DMSCLLINKS_INSERT_ADV
                                        (
                                          sSOURCE_CODE      => cn.ref_unitcode, -- varchar2,
                                          nDESTINATION      => NCLASS_RN, -- number,
                                          sSTEREOTYPE       => get_STEREOTYPE(cn.col_name), -- varchar2,
                                          nFOREIGN_KEY      => 1, -- number,
                                          sSRC_CONSTRAINT   => cn.ref_con_name, -- varchar2,
                                          sCONSTRAINT_NAME  => cn.con_name, -- varchar2,
                                          sNAME             => cn.con_name, -- varchar2,
                                          nRULE             => 0, -- number,
                                          sMESSAGE1         => null, -- varchar2,
                                          sMESSAGE2         => null, -- varchar2,
                                          sLEVEL_ATTR       => null, -- varchar2,
                                          sPATH_ATTR        => null, -- varchar2,
                                          sMASTER_LINK      => null, -- varchar2,
                                          cCONSTRAINT_INIT  => cinit, -- clob,
                                          nRN               => fk_rn  -- out number
                                        );
            EXCEPTION WHEN OTHERS THEN
                pkg_trace.register('tmp', sqlerrm);
                -- Добавить лог
            END;
        END;

        BEGIN
            fk_atr_rn := NULL;
            PD_P_DMSCLLINKATTRS_INSERT
                                    (
                                      nPRN                => fk_rn, -- number,
                                      nPOSITION           => 1, -- number,
                                      nSOURCE_CLASS       => cn.ref_unit_rn, -- number,
                                      nDESTINATION_CLASS  => nclass_rn, -- number,
                                      sSOURCE             => cn.ref_col_name, -- varchar2,
                                      sDESTINATION        => cn.col_name, -- varchar2,
                                      nRN                 => fk_atr_rn  -- out number
                                    );
        EXCEPTION WHEN OTHERS THEN
            NULL;
--            pkg_trace.register('tmp1', sqlerrm);
            -- Добавить лог
        END;

        fk_rn := NULL;
    END LOOP;

END LOAD_CLS_LINKS;

-- ###########################################################################################################################################################################





PROCEDURE RENAME_CLS_ATTRIBUTES(ATTR_NAME_FILE IN clob)
AS
sview_column_name       varchar2(240);
sciew_column_comment    varchar2(4000);
tmp_value               varchar2(4000);
BEGIN

    -- ########################################################################################

    -- File format:
    -- |-----------------------------------------|
    -- | ATTR_CODE1  -- ATTR_PRINT_NAME1,        |
    -- | ATTR_CODE2  -- ATTR_PRINT_NAME2,        |
    -- |-----------------------------------------|

    -- ########################################################################################


    FOR REC IN (SELECT TMP.clob_row AS column_value, ROWNUM AS POS FROM TABLE(SPLIT_CLOB(ATTR_NAME_FILE)) TMP )
    LOOP

        tmp_value := regexp_replace(rec.column_value, chr(10) || '|' || chr(13), '');
        sview_column_name := regexp_replace( substr(tmp_value, 1, instr(tmp_value, '--') - 1 ), '\s+', '' );
        sview_column_name := regexp_REPLACE(sview_column_name, '\s', '');
        
        sciew_column_comment := trim(  substr(tmp_value,  instr(tmp_value, '--') + 2 ) );
--        pkg_trace.register('UDO_NAME_VIEW_ATTRS', tmp_value,   sview_column_name,   sciew_column_comment );

        FOR attr IN (SELECT d.rn FROM DMSCLATTRS d WHERE d.prn = NCLASS_RN AND d.COLUMN_NAME = upper(sview_column_name) )
        LOOP
            BEGIN
                UPDATE DMSCLATTRS d
                SET d.CAPTION = sciew_column_comment
                WHERE d.rn = attr.rn;
            EXCEPTION WHEN OTHERS THEN
                UPDATE DMSCLATTRS d
                SET d.CAPTION = sciew_column_comment || '(' || rec.pos || ')'
                WHERE d.rn = attr.rn;
            END;
        END LOOP;


        sview_column_name := NULL;
        sciew_column_comment := NULL;
    END LOOP;

END RENAME_CLS_ATTRIBUTES;








-- ###########################################################################################################################################################################

-- ||------------------------||------------------------||------------------------||------------------------||
-- || Входная точка. Запускает считывание параметров и выполнение основных процедур обработки              ||
-- ||------------------------||------------------------||------------------------||------------------------||
PROCEDURE ENTER_POINT(nRN IN NUMBER, ATTR_NAME_FILE IN clob DEFAULT null)
AS
BEGIN

    --  Считывание константных параметров
    INIT_CONST_PARAMS(nRN);

    -- Загрузка основных атрибутов класса
    LOAD_CLS_ATTRIBUTES();


    -- Загрузка ограничений класса
    LOAD_CLS_CONSTRAINTS();

    -- Загрузка связей класса
    LOAD_CLS_LINKS();

    -- Загрузка атрибутов представления
    LOAD_CLS_VIEW_ATTRIBUTES();

    -- Замена наименований атрибутов на нормальные
    IF ATTR_NAME_FILE IS NOT NULL THEN
--        pkg_trace.register('ATTR_NAME_FILE', ATTR_NAME_FILE);
        RENAME_CLS_ATTRIBUTES(ATTR_NAME_FILE);
    END IF;

END ENTER_POINT;







END PD_PKG_CNTR;
