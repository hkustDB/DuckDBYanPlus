-- DuckDB SUM(1) Yannakakis-style two-pass reducer generated from job_agg/7a.sql.

-- Source variant: query/job_duckdb/7a/rewriteYa72.sql

CREATE OR REPLACE TEMP VIEW ya_7a_rewriteYa72_base_an AS
SELECT an.*
FROM aka_name AS an
WHERE (an.name LIKE '%a%');

CREATE OR REPLACE TEMP VIEW ya_7a_rewriteYa72_base_ci AS
SELECT ci.*
FROM cast_info AS ci;

CREATE OR REPLACE TEMP VIEW ya_7a_rewriteYa72_base_it AS
SELECT it.*
FROM info_type AS it
WHERE (it.info ='mini biography');

CREATE OR REPLACE TEMP VIEW ya_7a_rewriteYa72_base_lt AS
SELECT lt.*
FROM link_type AS lt
WHERE (lt.link ='features');

CREATE OR REPLACE TEMP VIEW ya_7a_rewriteYa72_base_ml AS
SELECT ml.*
FROM movie_link AS ml;

CREATE OR REPLACE TEMP VIEW ya_7a_rewriteYa72_base_n AS
SELECT n.*
FROM name AS n
WHERE (n.name_pcode_cf BETWEEN 'A' AND 'F')
  AND ((n.gender='m'
       OR (n.gender = 'f'
           AND n.name LIKE 'B%')));

CREATE OR REPLACE TEMP VIEW ya_7a_rewriteYa72_base_pi AS
SELECT pi.*
FROM person_info AS pi
WHERE (pi.note ='Volker Boehm');

CREATE OR REPLACE TEMP VIEW ya_7a_rewriteYa72_base_t AS
SELECT t.*
FROM title AS t
WHERE (t.production_year BETWEEN 1980 AND 1995);

CREATE OR REPLACE TEMP VIEW ya_7a_rewriteYa72_up_n AS
SELECT n.*
FROM ya_7a_rewriteYa72_base_n AS n;

CREATE OR REPLACE TEMP VIEW ya_7a_rewriteYa72_up_it AS
SELECT it.*
FROM ya_7a_rewriteYa72_base_it AS it;

CREATE OR REPLACE TEMP VIEW ya_7a_rewriteYa72_up_pi AS
SELECT pi.*
FROM ya_7a_rewriteYa72_base_pi AS pi
WHERE EXISTS (SELECT 1 FROM ya_7a_rewriteYa72_up_it AS it WHERE (it.id = pi.info_type_id));

CREATE OR REPLACE TEMP VIEW ya_7a_rewriteYa72_up_t AS
SELECT t.*
FROM ya_7a_rewriteYa72_base_t AS t;

CREATE OR REPLACE TEMP VIEW ya_7a_rewriteYa72_up_lt AS
SELECT lt.*
FROM ya_7a_rewriteYa72_base_lt AS lt;

CREATE OR REPLACE TEMP VIEW ya_7a_rewriteYa72_up_ml AS
SELECT ml.*
FROM ya_7a_rewriteYa72_base_ml AS ml
WHERE EXISTS (SELECT 1 FROM ya_7a_rewriteYa72_up_lt AS lt WHERE (lt.id = ml.link_type_id));

CREATE OR REPLACE TEMP VIEW ya_7a_rewriteYa72_up_ci AS
SELECT ci.*
FROM ya_7a_rewriteYa72_base_ci AS ci
WHERE EXISTS (SELECT 1 FROM ya_7a_rewriteYa72_up_t AS t WHERE (t.id = ci.movie_id))
  AND EXISTS (SELECT 1 FROM ya_7a_rewriteYa72_up_ml AS ml WHERE (ci.movie_id = ml.linked_movie_id));

CREATE OR REPLACE TEMP VIEW ya_7a_rewriteYa72_up_an AS
SELECT an.*
FROM ya_7a_rewriteYa72_base_an AS an
WHERE EXISTS (SELECT 1 FROM ya_7a_rewriteYa72_up_n AS n WHERE (n.id = an.person_id))
  AND EXISTS (SELECT 1 FROM ya_7a_rewriteYa72_up_pi AS pi WHERE (pi.person_id = an.person_id))
  AND EXISTS (SELECT 1 FROM ya_7a_rewriteYa72_up_ci AS ci WHERE (an.person_id = ci.person_id));

CREATE OR REPLACE TEMP VIEW ya_7a_rewriteYa72_down_an AS
SELECT an.*
FROM ya_7a_rewriteYa72_up_an AS an;

CREATE OR REPLACE TEMP VIEW ya_7a_rewriteYa72_down_n AS
SELECT n.*
FROM ya_7a_rewriteYa72_up_n AS n
WHERE EXISTS (SELECT 1 FROM ya_7a_rewriteYa72_down_an AS an WHERE (n.id = an.person_id));

CREATE OR REPLACE TEMP VIEW ya_7a_rewriteYa72_down_pi AS
SELECT pi.*
FROM ya_7a_rewriteYa72_up_pi AS pi
WHERE EXISTS (SELECT 1 FROM ya_7a_rewriteYa72_down_an AS an WHERE (pi.person_id = an.person_id));

CREATE OR REPLACE TEMP VIEW ya_7a_rewriteYa72_down_ci AS
SELECT ci.*
FROM ya_7a_rewriteYa72_up_ci AS ci
WHERE EXISTS (SELECT 1 FROM ya_7a_rewriteYa72_down_an AS an WHERE (an.person_id = ci.person_id));

CREATE OR REPLACE TEMP VIEW ya_7a_rewriteYa72_down_it AS
SELECT it.*
FROM ya_7a_rewriteYa72_up_it AS it
WHERE EXISTS (SELECT 1 FROM ya_7a_rewriteYa72_down_pi AS pi WHERE (it.id = pi.info_type_id));

CREATE OR REPLACE TEMP VIEW ya_7a_rewriteYa72_down_t AS
SELECT t.*
FROM ya_7a_rewriteYa72_up_t AS t
WHERE EXISTS (SELECT 1 FROM ya_7a_rewriteYa72_down_ci AS ci WHERE (t.id = ci.movie_id));

CREATE OR REPLACE TEMP VIEW ya_7a_rewriteYa72_down_ml AS
SELECT ml.*
FROM ya_7a_rewriteYa72_up_ml AS ml
WHERE EXISTS (SELECT 1 FROM ya_7a_rewriteYa72_down_ci AS ci WHERE (ci.movie_id = ml.linked_movie_id));

CREATE OR REPLACE TEMP VIEW ya_7a_rewriteYa72_down_lt AS
SELECT lt.*
FROM ya_7a_rewriteYa72_up_lt AS lt
WHERE EXISTS (SELECT 1 FROM ya_7a_rewriteYa72_down_ml AS ml WHERE (lt.id = ml.link_type_id));

SELECT n.name,
       t.title,
       SUM(1) AS record_count
FROM ya_7a_rewriteYa72_down_an AS an,
     ya_7a_rewriteYa72_down_ci AS ci,
     ya_7a_rewriteYa72_down_it AS it,
     ya_7a_rewriteYa72_down_lt AS lt,
     ya_7a_rewriteYa72_down_ml AS ml,
     ya_7a_rewriteYa72_down_n AS n,
     ya_7a_rewriteYa72_down_pi AS pi,
     ya_7a_rewriteYa72_down_t AS t
WHERE (an.name LIKE '%a%')
  AND (it.info ='mini biography')
  AND (lt.link ='features')
  AND (n.name_pcode_cf BETWEEN 'A' AND 'F')
  AND ((n.gender='m'
       OR (n.gender = 'f'
           AND n.name LIKE 'B%')))
  AND (pi.note ='Volker Boehm')
  AND (t.production_year BETWEEN 1980 AND 1995)
  AND (n.id = an.person_id)
  AND (n.id = pi.person_id)
  AND (ci.person_id = n.id)
  AND (t.id = ci.movie_id)
  AND (ml.linked_movie_id = t.id)
  AND (lt.id = ml.link_type_id)
  AND (it.id = pi.info_type_id)
  AND (pi.person_id = an.person_id)
  AND (pi.person_id = ci.person_id)
  AND (an.person_id = ci.person_id)
  AND (ci.movie_id = ml.linked_movie_id)
GROUP BY n.name, t.title;
