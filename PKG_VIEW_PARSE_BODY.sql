CREATE OR REPLACE PACKAGE BODY PARUS.PKG_VIEW_PARSE
AS 

-- ###########################################################################################################################################################################

-- ||------------------------||------------------------||------------------------||------------------------||
-- || Конвеерная функция деления clob переменных по заяптой                                                ||
-- || На выход выдает табличку, в строчках которой содержатся кусочки clob переменной                      ||
-- ||________________________||________________________||________________________||________________________||

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

FUNCTION PREPARE_BASE_VIEW_CLOB(in_clob IN clob, REPLACE_TO IN VARCHAR2 )
RETURN CLOB AS

CVIEW CLOB;

BEGIN

  CVIEW := UPPER(in_clob);

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
FUNCTION GET_COLUMNS_ALIASES(in_clob IN clob) RETURN TA_COLS PIPELINED AS

RES         A_COLS;
TMP_TA_COLS TA_CLOB;

BEGIN

    FOR REC IN (
                SELECT  TRIM(REGEXP_SUBSTR(' ' || TMP.CLOB_ROW || ' ', '\s[A-Za-z0-9\_]+\.[A-Za-z0-9\_]+\s')) AS VAL,
                        ROWNUM AS LINE_ID
                FROM TABLE( SPLIT_CLOB( GET_SLICE(PREPARE_BASE_VIEW_CLOB(in_clob, 'R' ), 'SELECT', 'FROM') ) ) TMP
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
FUNCTION GET_TABLES_ALIASES(in_clob IN clob) RETURN ta_tabs pipelined AS


tmp_a_tabs  a_tabs;

Type list_type_vv Is Table Of varchar2(2000) Index By Varchar2(100);
tmp_cols        list_type_vv;


sbase_alias     varchar2(100);
sindex_cols     varchar2(100);
sregexp_link    varchar2(2000);
sbase_table_name varchar2(100);
tmp_conditions  clob;
conditions      clob;

cprepared_base_view_clob clob := prepare_base_view_clob(in_clob,  '' );

BEGIN
    
    sbase_table_name := trim( regexp_substr(get_slice(cprepared_base_view_clob, 'FROM', 'WHERE'),  '\S+\s') );
    
--    pkg_trace.register_lob(get_slice(cprepared_base_view_clob, 'FROM', 'WHERE'), '123');
    for rec in (
                   select   substr(trim(tmp.clob_row), 1, instr(trim(tmp.clob_row), ' ') -1)        as stable_name,
                            substr(trim(tmp.clob_row), instr(trim(tmp.clob_row), ' ') +1) || ' '    as stable_alias,
                            tmp.clob_row
                   from     table( split_clob(regexp_replace(get_slice(cprepared_base_view_clob, 'FROM', 'WHERE'), '(\sINNER|\sLEFT|\sRIGTH)?\sJOIN\s', ',')) ) tmp
               )
    LOOP
--        pkg_trace.register('123', rec.clob_row, rec.stable_name, rec.stable_alias);
        if regexp_instr(rec.stable_alias, '\sON\s', 1, 1, 1) <> 0 then
            tmp_conditions := tmp_conditions  ||  substr(rec.stable_alias, regexp_instr(rec.stable_alias, '\sON\s', 1, 1, 1)) || ' AND ';
        end if;

        if ( sbase_table_name = rec.stable_name ) then
            sbase_alias := rec.stable_alias;
        end if;

        tmp_cols(trim(regexp_substr(rec.stable_alias, '\S+\s'))) := rec.stable_name;
        
        
    END LOOP;

    conditions := '  ' || tmp_conditions || get_slice(cprepared_base_view_clob, 'WHERE', null);
    
--    pkg_trace.REGISTER_LOB( conditions, 'view_parse' );
    

    sindex_cols := tmp_cols.first;

    while (sindex_cols is not null) loop

        sregexp_link := '(\s'|| trim(sbase_alias) || '\.\S+\s+\=)?\s+' || trim(sindex_cols) ||'\.RN\s+(\=\s+'|| trim(sbase_alias) || '.\S+)?';
        
        tmp_a_tabs.tname :=  tmp_cols(sindex_cols);
        tmp_a_tabs.aname := sindex_cols;
        IF trim(sbase_alias) = trim(sindex_cols) THEN
            tmp_a_tabs.lcname := 'BASE_TABLE';
        ELSE
            tmp_a_tabs.lcname := substr(regexp_substr(regexp_substr(conditions, sregexp_link), '\s' || trim(sbase_alias) || '\.\S+'),  length(sbase_alias) + 2);
        END IF;
        
--        pkg_trace.register('123', tmp_a_tabs.tname, tmp_a_tabs.aname);
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
FUNCTION LINK_VIEW_COLUMNS(sbase_view_name IN varchar2) RETURN ta_VLINK pipelined AS
cview   clob := dbms_metadata.get_ddl('VIEW', upper(sbase_view_name), 'PARUS');
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
                            FROM        table( GET_COLUMNS_ALIASES(cview) ) tmp1
                            LEFT JOIN   table( GET_TABLES_ALIASES(cview) ) tmp2 ON  trim(UPPER(tmp2.aname)) = trim(upper(tmp1.al))
                        ) coll
                ON coll.line_n = a.column_id AND a.TABLE_NAME = sbase_view_name
                )
    LOOP 

        pipe ROW ( rec );

    END LOOP;

END LINK_VIEW_COLUMNS;

END;