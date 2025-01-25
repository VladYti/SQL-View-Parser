# SQL-View-Parser
## Анализатор SQL-представлений

Данный пакет предназначен для анализа SQL-запросов средствами Oracle. Основная задача построить табличку связей для Oracle-представления.
К примеру, имеются следующие таблицы:
### BASE_TABLE
```sql
CREATE TABLE "PARUS"."BASE_TABLE" 
(
"RN"     NUMBER(17,0) NOT NULL ENABLE, 
"CODE"   VARCHAR2(40), 
"NAME"   VARCHAR2(40), 
"ST1_1"   NUMBER(17,0), 
"ST1_2"   NUMBER(17,0), 
"ST2_1"   NUMBER(17,0), 

CONSTRAINT "BASE_TABLE_PK" PRIMARY KEY ("RN") ENABLE, 

CONSTRAINT "BASE_TABLE_ST1_1_FK" FOREIGN KEY ("ST1_1")
REFERENCES "PARUS"."SAMPLE_TABLE_1" ("RN") ENABLE, 

CONSTRAINT "BASE_TABLE_ST1_2_FK" FOREIGN KEY ("ST1_2")
REFERENCES "PARUS"."SAMPLE_TABLE_1" ("RN") ENABLE, 

CONSTRAINT "BASE_TABLE_ST2_1_FK" FOREIGN KEY ("ST2_1")
REFERENCES "PARUS"."SAMPLE_TABLE_2" ("RN") ENABLE
);
```


### SAMPLE_TABLE_1
```sql
CREATE TABLE "PARUS"."SAMPLE_TABLE_1" 
(
"RN" NUMBER(17,0), 
"ST1_CODE" VARCHAR2(40), 
"ST1_NAME" VARCHAR2(250), 

CONSTRAINT "SAMPLE_TABLE_1_PK" PRIMARY KEY ("RN") ENABLE
);
```


### SAMPLE_TABLE_2
```sql
CREATE TABLE "PARUS"."SAMPLE_TABLE_2" 
(
"RN" NUMBER(17,0), 
"ST2_CODE" VARCHAR2(40), 
"ST2_NAME" VARCHAR2(250), 
"ST3_1" NUMBER(17,0) NOT NULL ENABLE, 

CONSTRAINT "SAMPLE_TABLE_2_PK" PRIMARY KEY ("RN") ENABLE, 

CONSTRAINT "SAMPLE_TABLE_2_ST3_1_FK" FOREIGN KEY ("ST3_1")
REFERENCES "PARUS"."SAMPLE_TABLE_3" ("RN") ENABLE
);
```
### SAMPLE_TABLE_3
```sql
CREATE TABLE "PARUS"."SAMPLE_TABLE_3" 
(
"RN" NUMBER(17,0), 
"ST3_CODE" VARCHAR2(40), 
"ST3_NAME" VARCHAR2(250), 

CONSTRAINT "SAMPLE_TABLE_3_PK" PRIMARY KEY ("RN") ENABLE
);
```

А так же представление следующего вида:
### BASE_VIEW
```sql
CREATE OR REPLACE FORCE VIEW "PARUS"."BASE_VIEW"  AS 
  SELECT  bt.rn           AS NRN,
          bt.code         AS SCODE,
          bt.name         AS SNAME,
          bt.st1_1        AS NST1_1,
          st11.ST1_code   AS SST1_1_CODE,
          st11.ST1_name   AS SST1_1_NAME,
          bt.st1_2        AS NST1_2,
          st12.ST1_code   AS SST1_2_CODE,
          st12.ST1_name   AS SST1_2_NAME,
          bt.st2_1        AS NST2_1,
          st21.st2_code   AS SST2_1_CODE,
          st21.st2_name   AS SST2_1_NAME,
          st21.st3_1      AS NST3_1,
          st31.st3_CODE   AS SST3_1_CODE,
          st31.st3_NAME   AS SST3_1_NAME,
          SYSDATE         AS DDATE,
          (bt.code || ' - ' ||bt.name) AS SBT_CODE_NAME
FROM    base_table bt 
LEFT JOIN sample_table_1 st11 ON st11.rn = bt.st1_1
LEFT JOIN sample_table_1 st12 ON st12.rn = bt.st1_2
LEFT JOIN sample_table_2 st21 ON st21.rn = bt.st2_1
JOIN sample_table_3 st31 ON st31.rn = st21.st3_1;
```





Функция ```LINK_VIEW_COLUMNS``` из пакета ```PKG_VIEW_PARSE``` позволяет связать поля представления с полями таблиц, из которых они тянуться, а так же указать поле, по которому связаны таблицы.
Пример использования:
```sql
SELECT * FROM TABLE( PKG_VIEW_PARSE.LINK_VIEW_COLUMNS('BASE_VIEW') ) ORDER BY COLUMN_ID
```

На выходе получим следующую таблицу:

|COLUMN_ID|COLUMN_NAME|R_TABLE_NAME|R_COLUMN_NAME|LINK_COLUMN_NAME|
|---------|-----------|------------|-------------|----------------|
|Номер поля представления|Наименование поля представления|Наименование таблицы, откуда тянется это поле| Наименование поля в этой таблице |Наименование поля в базовой таблице, по которому построена связь с внешней таблицей|
|---------|-----------|------------|-------------|----------------|
|1	| NRN	        |BASE_TABLE	     |RN	      |_BASE_TABLE_    |
|2	|SCODE        |	BASE_TABLE     |CODE	    |_BASE_TABLE_    |
|3	|SNAME        |BASE_TABLE	     |NAME	    |_BASE_TABLE_    |
|4	|NST1_1       |BASE_TABLE      |ST1_1     |_BASE_TABLE_    |
|5	|SST1_1_CODE  |SAMPLE_TABLE_1  |ST1_CODE  |ST1_1         |
|6	|SST1_1_NAME	|SAMPLE_TABLE_1  |ST1_NAME  |ST1_1         |
|7	|NST1_2	      |BASE_TABLE      |ST1_2	    |_BASE_TABLE_    |
|8	|SST1_2_CODE  |SAMPLE_TABLE_1  |ST1_CODE	|ST1_2         |
|9	|SST1_2_NAME	|SAMPLE_TABLE_1  |ST1_NAME	|ST1_2         |
|10	|NST2_1	      |BASE_TABLE      |ST2_1	    |_BASE_TABLE_    |
|11	|SST2_1_CODE  |SAMPLE_TABLE_2  |ST2_CODE	|ST2_1         |
|12	|SST2_1_NAME  |SAMPLE_TABLE_2  |ST2_NAME	|ST2_1         |
|13	|NST3_1	      |SAMPLE_TABLE_2  |ST3_1	    |ST2_1         |
|14	|SST3_1_CODE  |SAMPLE_TABLE_3  |ST3_CODE  |NULL	         |
|15	|SST3_1_NAME  |SAMPLE_TABLE_3  |ST3_NAME  |NULL	         |
|16	|DDATE        |NULL	           |NULL		  |NULL          |
|17	|SBT_CODE_NAME|NULL            |NULL	    |NULL		       |

На данном примере видны четыре возможных случая.
#### `1` строка:
|1	| NRN	        |BASE_TABLE	     |RN	      |_BASE_TABLE_    |
|---------|-----------|------------|-------------|----------------|


В первом столбце указан порядковы номер колонки представления, во втором - имя колонки.
В четвертом - имя таблицы, из которой тянется поле, и в третьм столбце его название. (В данном случае, наименование _BASE_TABLE_ - не имя таблицы, а обозначение базовой таблицы представления. **Базовая таблица - первая таблица после ключевого слова `FROM` в запросе**)

#### `5` строка:
|5	|SST1_1_CODE  |SAMPLE_TABLE_1  |ST1_CODE  |ST1_1         |
|---------|-----------|------------|-------------|----------------|

То же самое, наименование поля в представлении, наименование таблицы, из которой тянется это поле, наименование это поля в самой таблице, и в последнем столбце указано поле, по которому базовая таблица связана с таблицей откуда взято поле.

### `14` строка:
|14	|SST3_1_CODE  |SAMPLE_TABLE_3  |ST3_CODE  |NULL	         |
|---------|-----------|------------|-------------|----------------|

В данном случае, таблицца `SAMPLE_TABLE_3` не имеет прямой связи с базовой таблицей (в нашем случае - `BASE_TABLE`), поэтому последний столбец выходной таблицы имеет значение `NULL`.

### `16` стролка:
|16	|DDATE        |NULL	           |NULL		  |NULL          |
|---------|-----------|------------|-------------|----------------|

В 16 строке поле `DDATE` представлено выражением. Не важно - это результат функции, `IF/CASE STATEMENT`, или что либо другое - 3, 4 и 5 столбцы результирующей таблицы будут иметь значение `NULL`.


## P.S.
Есть некоторые ограничения работы пакета. В частности, предполагается, что ссылка из базовой таблицы во внешнюю таблицу, всегда указывает на первичный ключ внешней таблицы. Кроме того, первичный ключ любой таблицы всегда имеет название `RN`.
https://github.com/VladYti/SQL-View-Parser/blob/170731f552d880bfe3aa0d0935d1fd2e7c01b2e5/PKG_VIEW_PARSE_BODY.sql#L189-L205
В целом, это достаточно легко адаптировать под любую другую схему.

