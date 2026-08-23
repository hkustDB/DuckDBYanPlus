-- DuckDB SUM(1) Yannakakis-style two-pass reducer generated from job_agg/32a.sql.

-- Source variant: query/job_duckdb/32a/rewriteYa0.sql

CREATE OR REPLACE TEMP VIEW ya_32a_rewriteYa0_base_k AS
SELECT k.*
FROM keyword AS k
WHERE (k.keyword ='10,000-mile-club');

CREATE OR REPLACE TEMP VIEW ya_32a_rewriteYa0_base_lt AS
SELECT lt.*
FROM link_type AS lt;

CREATE OR REPLACE TEMP VIEW ya_32a_rewriteYa0_base_mk AS
SELECT mk.*
FROM movie_keyword AS mk;

CREATE OR REPLACE TEMP VIEW ya_32a_rewriteYa0_base_ml AS
SELECT ml.*
FROM movie_link AS ml;

CREATE OR REPLACE TEMP VIEW ya_32a_rewriteYa0_base_t1 AS
SELECT t1.*
FROM title AS t1;

CREATE OR REPLACE TEMP VIEW ya_32a_rewriteYa0_base_t2 AS
SELECT t2.*
FROM title AS t2;

CREATE OR REPLACE TEMP VIEW ya_32a_rewriteYa0_up_t2 AS
SELECT t2.*
FROM ya_32a_rewriteYa0_base_t2 AS t2;

CREATE OR REPLACE TEMP VIEW ya_32a_rewriteYa0_up_lt AS
SELECT lt.*
FROM ya_32a_rewriteYa0_base_lt AS lt;

CREATE OR REPLACE TEMP VIEW ya_32a_rewriteYa0_up_ml AS
SELECT ml.*
FROM ya_32a_rewriteYa0_base_ml AS ml
WHERE EXISTS (SELECT 1 FROM ya_32a_rewriteYa0_up_t2 AS t2 WHERE (ml.linked_movie_id = t2.id))
  AND EXISTS (SELECT 1 FROM ya_32a_rewriteYa0_up_lt AS lt WHERE (lt.id = ml.link_type_id));

CREATE OR REPLACE TEMP VIEW ya_32a_rewriteYa0_up_t1 AS
SELECT t1.*
FROM ya_32a_rewriteYa0_base_t1 AS t1
WHERE EXISTS (SELECT 1 FROM ya_32a_rewriteYa0_up_ml AS ml WHERE (ml.movie_id = t1.id));

CREATE OR REPLACE TEMP VIEW ya_32a_rewriteYa0_up_mk AS
SELECT mk.*
FROM ya_32a_rewriteYa0_base_mk AS mk
WHERE EXISTS (SELECT 1 FROM ya_32a_rewriteYa0_up_t1 AS t1 WHERE (t1.id = mk.movie_id) AND (mk.movie_id = t1.id));

CREATE OR REPLACE TEMP VIEW ya_32a_rewriteYa0_up_k AS
SELECT k.*
FROM ya_32a_rewriteYa0_base_k AS k
WHERE EXISTS (SELECT 1 FROM ya_32a_rewriteYa0_up_mk AS mk WHERE (mk.keyword_id = k.id));

CREATE OR REPLACE TEMP VIEW ya_32a_rewriteYa0_down_k AS
SELECT k.*
FROM ya_32a_rewriteYa0_up_k AS k;

CREATE OR REPLACE TEMP VIEW ya_32a_rewriteYa0_down_mk AS
SELECT mk.*
FROM ya_32a_rewriteYa0_up_mk AS mk
WHERE EXISTS (SELECT 1 FROM ya_32a_rewriteYa0_down_k AS k WHERE (mk.keyword_id = k.id));

CREATE OR REPLACE TEMP VIEW ya_32a_rewriteYa0_down_t1 AS
SELECT t1.*
FROM ya_32a_rewriteYa0_up_t1 AS t1
WHERE EXISTS (SELECT 1 FROM ya_32a_rewriteYa0_down_mk AS mk WHERE (t1.id = mk.movie_id) AND (mk.movie_id = t1.id));

CREATE OR REPLACE TEMP VIEW ya_32a_rewriteYa0_down_ml AS
SELECT ml.*
FROM ya_32a_rewriteYa0_up_ml AS ml
WHERE EXISTS (SELECT 1 FROM ya_32a_rewriteYa0_down_t1 AS t1 WHERE (ml.movie_id = t1.id));

CREATE OR REPLACE TEMP VIEW ya_32a_rewriteYa0_down_t2 AS
SELECT t2.*
FROM ya_32a_rewriteYa0_up_t2 AS t2
WHERE EXISTS (SELECT 1 FROM ya_32a_rewriteYa0_down_ml AS ml WHERE (ml.linked_movie_id = t2.id));

CREATE OR REPLACE TEMP VIEW ya_32a_rewriteYa0_down_lt AS
SELECT lt.*
FROM ya_32a_rewriteYa0_up_lt AS lt
WHERE EXISTS (SELECT 1 FROM ya_32a_rewriteYa0_down_ml AS ml WHERE (lt.id = ml.link_type_id));

CREATE OR REPLACE TEMP VIEW ya_32a_rewriteYa0_r3_base_k AS
SELECT k.id AS k__id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_32a_rewriteYa0_down_k AS k
GROUP BY k.id;

CREATE OR REPLACE TEMP VIEW ya_32a_rewriteYa0_r3_base_lt AS
SELECT lt.id AS lt__id,
       lt.link AS lt__link,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_32a_rewriteYa0_down_lt AS lt
GROUP BY lt.id, lt.link;

CREATE OR REPLACE TEMP VIEW ya_32a_rewriteYa0_r3_base_mk AS
SELECT mk.keyword_id AS mk__keyword_id,
       mk.movie_id AS mk__movie_id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_32a_rewriteYa0_down_mk AS mk
GROUP BY mk.keyword_id, mk.movie_id;

CREATE OR REPLACE TEMP VIEW ya_32a_rewriteYa0_r3_base_ml AS
SELECT ml.movie_id AS ml__movie_id,
       ml.linked_movie_id AS ml__linked_movie_id,
       ml.link_type_id AS ml__link_type_id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_32a_rewriteYa0_down_ml AS ml
GROUP BY ml.movie_id, ml.linked_movie_id, ml.link_type_id;

CREATE OR REPLACE TEMP VIEW ya_32a_rewriteYa0_r3_base_t1 AS
SELECT t1.id AS t1__id,
       t1.title AS t1__title,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_32a_rewriteYa0_down_t1 AS t1
GROUP BY t1.id, t1.title;

CREATE OR REPLACE TEMP VIEW ya_32a_rewriteYa0_r3_base_t2 AS
SELECT t2.id AS t2__id,
       t2.title AS t2__title,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_32a_rewriteYa0_down_t2 AS t2
GROUP BY t2.id, t2.title;

CREATE OR REPLACE TEMP VIEW ya_32a_rewriteYa0_r3_join_1 AS
SELECT round3_right.t2__title AS t2__title,
       round3_left.ml__movie_id AS ml__movie_id,
       round3_left.ml__link_type_id AS ml__link_type_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_32a_rewriteYa0_r3_base_ml AS round3_left
JOIN ya_32a_rewriteYa0_r3_base_t2 AS round3_right
  ON (round3_left.ml__linked_movie_id = round3_right.t2__id)
GROUP BY round3_right.t2__title, round3_left.ml__movie_id, round3_left.ml__link_type_id;

CREATE OR REPLACE TEMP VIEW ya_32a_rewriteYa0_r3_join_2 AS
SELECT round3_right.lt__link AS lt__link,
       round3_left.t2__title AS t2__title,
       round3_left.ml__movie_id AS ml__movie_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_32a_rewriteYa0_r3_join_1 AS round3_left
JOIN ya_32a_rewriteYa0_r3_base_lt AS round3_right
  ON (round3_right.lt__id = round3_left.ml__link_type_id)
GROUP BY round3_right.lt__link, round3_left.t2__title, round3_left.ml__movie_id;

CREATE OR REPLACE TEMP VIEW ya_32a_rewriteYa0_r3_join_3 AS
SELECT round3_right.lt__link AS lt__link,
       round3_left.t1__title AS t1__title,
       round3_right.t2__title AS t2__title,
       round3_left.t1__id AS t1__id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_32a_rewriteYa0_r3_base_t1 AS round3_left
JOIN ya_32a_rewriteYa0_r3_join_2 AS round3_right
  ON (round3_right.ml__movie_id = round3_left.t1__id)
GROUP BY round3_right.lt__link, round3_left.t1__title, round3_right.t2__title, round3_left.t1__id;

CREATE OR REPLACE TEMP VIEW ya_32a_rewriteYa0_r3_join_4 AS
SELECT round3_right.lt__link AS lt__link,
       round3_right.t1__title AS t1__title,
       round3_right.t2__title AS t2__title,
       round3_left.mk__keyword_id AS mk__keyword_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_32a_rewriteYa0_r3_base_mk AS round3_left
JOIN ya_32a_rewriteYa0_r3_join_3 AS round3_right
  ON (round3_right.t1__id = round3_left.mk__movie_id)
 AND (round3_left.mk__movie_id = round3_right.t1__id)
GROUP BY round3_right.lt__link, round3_right.t1__title, round3_right.t2__title, round3_left.mk__keyword_id;

CREATE OR REPLACE TEMP VIEW ya_32a_rewriteYa0_r3_join_5 AS
SELECT round3_right.lt__link AS lt__link,
       round3_right.t1__title AS t1__title,
       round3_right.t2__title AS t2__title,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_32a_rewriteYa0_r3_base_k AS round3_left
JOIN ya_32a_rewriteYa0_r3_join_4 AS round3_right
  ON (round3_right.mk__keyword_id = round3_left.k__id)
GROUP BY round3_right.lt__link, round3_right.t1__title, round3_right.t2__title;

SELECT round3_result.lt__link AS link,
       round3_result.t1__title AS title,
       round3_result.t2__title AS title,
       round3_result.annot AS record_count
FROM ya_32a_rewriteYa0_r3_join_5 AS round3_result;
