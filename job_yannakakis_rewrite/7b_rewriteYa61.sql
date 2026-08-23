-- DuckDB SUM(1) Yannakakis-style two-pass reducer generated from job_agg/7b.sql.

-- Source variant: query/job_duckdb/7b/rewriteYa61.sql

CREATE OR REPLACE TEMP VIEW ya_7b_rewriteYa61_base_an AS
SELECT an.*
FROM aka_name AS an
WHERE (an.name LIKE '%a%');

CREATE OR REPLACE TEMP VIEW ya_7b_rewriteYa61_base_ci AS
SELECT ci.*
FROM cast_info AS ci;

CREATE OR REPLACE TEMP VIEW ya_7b_rewriteYa61_base_it AS
SELECT it.*
FROM info_type AS it
WHERE (it.info ='mini biography');

CREATE OR REPLACE TEMP VIEW ya_7b_rewriteYa61_base_lt AS
SELECT lt.*
FROM link_type AS lt
WHERE (lt.link ='features');

CREATE OR REPLACE TEMP VIEW ya_7b_rewriteYa61_base_ml AS
SELECT ml.*
FROM movie_link AS ml;

CREATE OR REPLACE TEMP VIEW ya_7b_rewriteYa61_base_n AS
SELECT n.*
FROM name AS n
WHERE (n.name_pcode_cf LIKE 'D%')
  AND (n.gender='m');

CREATE OR REPLACE TEMP VIEW ya_7b_rewriteYa61_base_pi AS
SELECT pi.*
FROM person_info AS pi
WHERE (pi.note ='Volker Boehm');

CREATE OR REPLACE TEMP VIEW ya_7b_rewriteYa61_base_t AS
SELECT t.*
FROM title AS t
WHERE (t.production_year BETWEEN 1980 AND 1984);

CREATE OR REPLACE TEMP VIEW ya_7b_rewriteYa61_up_it AS
SELECT it.*
FROM ya_7b_rewriteYa61_base_it AS it;

CREATE OR REPLACE TEMP VIEW ya_7b_rewriteYa61_up_pi AS
SELECT pi.*
FROM ya_7b_rewriteYa61_base_pi AS pi
WHERE EXISTS (SELECT 1 FROM ya_7b_rewriteYa61_up_it AS it WHERE (it.id = pi.info_type_id));

CREATE OR REPLACE TEMP VIEW ya_7b_rewriteYa61_up_an AS
SELECT an.*
FROM ya_7b_rewriteYa61_base_an AS an;

CREATE OR REPLACE TEMP VIEW ya_7b_rewriteYa61_up_lt AS
SELECT lt.*
FROM ya_7b_rewriteYa61_base_lt AS lt;

CREATE OR REPLACE TEMP VIEW ya_7b_rewriteYa61_up_ml AS
SELECT ml.*
FROM ya_7b_rewriteYa61_base_ml AS ml
WHERE EXISTS (SELECT 1 FROM ya_7b_rewriteYa61_up_lt AS lt WHERE (lt.id = ml.link_type_id));

CREATE OR REPLACE TEMP VIEW ya_7b_rewriteYa61_up_t AS
SELECT t.*
FROM ya_7b_rewriteYa61_base_t AS t;

CREATE OR REPLACE TEMP VIEW ya_7b_rewriteYa61_up_ci AS
SELECT ci.*
FROM ya_7b_rewriteYa61_base_ci AS ci
WHERE EXISTS (SELECT 1 FROM ya_7b_rewriteYa61_up_ml AS ml WHERE (ci.movie_id = ml.linked_movie_id))
  AND EXISTS (SELECT 1 FROM ya_7b_rewriteYa61_up_t AS t WHERE (t.id = ci.movie_id));

CREATE OR REPLACE TEMP VIEW ya_7b_rewriteYa61_up_n AS
SELECT n.*
FROM ya_7b_rewriteYa61_base_n AS n
WHERE EXISTS (SELECT 1 FROM ya_7b_rewriteYa61_up_pi AS pi WHERE (n.id = pi.person_id))
  AND EXISTS (SELECT 1 FROM ya_7b_rewriteYa61_up_an AS an WHERE (n.id = an.person_id))
  AND EXISTS (SELECT 1 FROM ya_7b_rewriteYa61_up_ci AS ci WHERE (ci.person_id = n.id));

CREATE OR REPLACE TEMP VIEW ya_7b_rewriteYa61_down_n AS
SELECT n.*
FROM ya_7b_rewriteYa61_up_n AS n;

CREATE OR REPLACE TEMP VIEW ya_7b_rewriteYa61_down_pi AS
SELECT pi.*
FROM ya_7b_rewriteYa61_up_pi AS pi
WHERE EXISTS (SELECT 1 FROM ya_7b_rewriteYa61_down_n AS n WHERE (n.id = pi.person_id));

CREATE OR REPLACE TEMP VIEW ya_7b_rewriteYa61_down_an AS
SELECT an.*
FROM ya_7b_rewriteYa61_up_an AS an
WHERE EXISTS (SELECT 1 FROM ya_7b_rewriteYa61_down_n AS n WHERE (n.id = an.person_id));

CREATE OR REPLACE TEMP VIEW ya_7b_rewriteYa61_down_ci AS
SELECT ci.*
FROM ya_7b_rewriteYa61_up_ci AS ci
WHERE EXISTS (SELECT 1 FROM ya_7b_rewriteYa61_down_n AS n WHERE (ci.person_id = n.id));

CREATE OR REPLACE TEMP VIEW ya_7b_rewriteYa61_down_it AS
SELECT it.*
FROM ya_7b_rewriteYa61_up_it AS it
WHERE EXISTS (SELECT 1 FROM ya_7b_rewriteYa61_down_pi AS pi WHERE (it.id = pi.info_type_id));

CREATE OR REPLACE TEMP VIEW ya_7b_rewriteYa61_down_ml AS
SELECT ml.*
FROM ya_7b_rewriteYa61_up_ml AS ml
WHERE EXISTS (SELECT 1 FROM ya_7b_rewriteYa61_down_ci AS ci WHERE (ci.movie_id = ml.linked_movie_id));

CREATE OR REPLACE TEMP VIEW ya_7b_rewriteYa61_down_t AS
SELECT t.*
FROM ya_7b_rewriteYa61_up_t AS t
WHERE EXISTS (SELECT 1 FROM ya_7b_rewriteYa61_down_ci AS ci WHERE (t.id = ci.movie_id));

CREATE OR REPLACE TEMP VIEW ya_7b_rewriteYa61_down_lt AS
SELECT lt.*
FROM ya_7b_rewriteYa61_up_lt AS lt
WHERE EXISTS (SELECT 1 FROM ya_7b_rewriteYa61_down_ml AS ml WHERE (lt.id = ml.link_type_id));

CREATE OR REPLACE TEMP VIEW ya_7b_rewriteYa61_r3_base_an AS
SELECT an.person_id AS an__person_id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_7b_rewriteYa61_down_an AS an
GROUP BY an.person_id;

CREATE OR REPLACE TEMP VIEW ya_7b_rewriteYa61_r3_base_ci AS
SELECT ci.person_id AS ci__person_id,
       ci.movie_id AS ci__movie_id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_7b_rewriteYa61_down_ci AS ci
GROUP BY ci.person_id, ci.movie_id;

CREATE OR REPLACE TEMP VIEW ya_7b_rewriteYa61_r3_base_it AS
SELECT it.id AS it__id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_7b_rewriteYa61_down_it AS it
GROUP BY it.id;

CREATE OR REPLACE TEMP VIEW ya_7b_rewriteYa61_r3_base_lt AS
SELECT lt.id AS lt__id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_7b_rewriteYa61_down_lt AS lt
GROUP BY lt.id;

CREATE OR REPLACE TEMP VIEW ya_7b_rewriteYa61_r3_base_ml AS
SELECT ml.linked_movie_id AS ml__linked_movie_id,
       ml.link_type_id AS ml__link_type_id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_7b_rewriteYa61_down_ml AS ml
GROUP BY ml.linked_movie_id, ml.link_type_id;

CREATE OR REPLACE TEMP VIEW ya_7b_rewriteYa61_r3_base_n AS
SELECT n.id AS n__id,
       n.name AS n__name,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_7b_rewriteYa61_down_n AS n
GROUP BY n.id, n.name;

CREATE OR REPLACE TEMP VIEW ya_7b_rewriteYa61_r3_base_pi AS
SELECT pi.person_id AS pi__person_id,
       pi.info_type_id AS pi__info_type_id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_7b_rewriteYa61_down_pi AS pi
GROUP BY pi.person_id, pi.info_type_id;

CREATE OR REPLACE TEMP VIEW ya_7b_rewriteYa61_r3_base_t AS
SELECT t.id AS t__id,
       t.title AS t__title,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_7b_rewriteYa61_down_t AS t
GROUP BY t.id, t.title;

CREATE OR REPLACE TEMP VIEW ya_7b_rewriteYa61_r3_join_1 AS
SELECT round3_left.pi__person_id AS pi__person_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_7b_rewriteYa61_r3_base_pi AS round3_left
JOIN ya_7b_rewriteYa61_r3_base_it AS round3_right
  ON (round3_right.it__id = round3_left.pi__info_type_id)
GROUP BY round3_left.pi__person_id;

CREATE OR REPLACE TEMP VIEW ya_7b_rewriteYa61_r3_join_2 AS
SELECT round3_left.n__name AS n__name,
       round3_left.n__id AS n__id,
       round3_right.pi__person_id AS pi__person_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_7b_rewriteYa61_r3_base_n AS round3_left
JOIN ya_7b_rewriteYa61_r3_join_1 AS round3_right
  ON (round3_left.n__id = round3_right.pi__person_id)
GROUP BY round3_left.n__name, round3_left.n__id, round3_right.pi__person_id;

CREATE OR REPLACE TEMP VIEW ya_7b_rewriteYa61_r3_join_3 AS
SELECT round3_left.n__name AS n__name,
       round3_left.n__id AS n__id,
       round3_left.pi__person_id AS pi__person_id,
       round3_right.an__person_id AS an__person_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_7b_rewriteYa61_r3_join_2 AS round3_left
JOIN ya_7b_rewriteYa61_r3_base_an AS round3_right
  ON (round3_left.n__id = round3_right.an__person_id)
 AND (round3_left.pi__person_id = round3_right.an__person_id)
GROUP BY round3_left.n__name, round3_left.n__id, round3_left.pi__person_id, round3_right.an__person_id;

CREATE OR REPLACE TEMP VIEW ya_7b_rewriteYa61_r3_join_4 AS
SELECT round3_left.ml__linked_movie_id AS ml__linked_movie_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_7b_rewriteYa61_r3_base_ml AS round3_left
JOIN ya_7b_rewriteYa61_r3_base_lt AS round3_right
  ON (round3_right.lt__id = round3_left.ml__link_type_id)
GROUP BY round3_left.ml__linked_movie_id;

CREATE OR REPLACE TEMP VIEW ya_7b_rewriteYa61_r3_join_5 AS
SELECT round3_left.ci__person_id AS ci__person_id,
       round3_left.ci__movie_id AS ci__movie_id,
       round3_right.ml__linked_movie_id AS ml__linked_movie_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_7b_rewriteYa61_r3_base_ci AS round3_left
JOIN ya_7b_rewriteYa61_r3_join_4 AS round3_right
  ON (round3_left.ci__movie_id = round3_right.ml__linked_movie_id)
GROUP BY round3_left.ci__person_id, round3_left.ci__movie_id, round3_right.ml__linked_movie_id;

CREATE OR REPLACE TEMP VIEW ya_7b_rewriteYa61_r3_join_6 AS
SELECT round3_right.t__title AS t__title,
       round3_left.ci__person_id AS ci__person_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_7b_rewriteYa61_r3_join_5 AS round3_left
JOIN ya_7b_rewriteYa61_r3_base_t AS round3_right
  ON (round3_right.t__id = round3_left.ci__movie_id)
 AND (round3_left.ml__linked_movie_id = round3_right.t__id)
GROUP BY round3_right.t__title, round3_left.ci__person_id;

CREATE OR REPLACE TEMP VIEW ya_7b_rewriteYa61_r3_join_7 AS
SELECT round3_left.n__name AS n__name,
       round3_right.t__title AS t__title,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_7b_rewriteYa61_r3_join_3 AS round3_left
JOIN ya_7b_rewriteYa61_r3_join_6 AS round3_right
  ON (round3_right.ci__person_id = round3_left.n__id)
 AND (round3_left.pi__person_id = round3_right.ci__person_id)
 AND (round3_left.an__person_id = round3_right.ci__person_id)
GROUP BY round3_left.n__name, round3_right.t__title;

SELECT round3_result.n__name AS name,
       round3_result.t__title AS title,
       round3_result.annot AS record_count
FROM ya_7b_rewriteYa61_r3_join_7 AS round3_result;
