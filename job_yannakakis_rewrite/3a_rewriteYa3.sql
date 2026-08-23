-- DuckDB SUM(1) Yannakakis-style two-pass reducer generated from job_agg/3a.sql.

-- Source variant: query/job_duckdb/3a/rewriteYa3.sql

CREATE OR REPLACE TEMP VIEW ya_3a_rewriteYa3_base_k AS
SELECT k.*
FROM keyword AS k
WHERE (k.keyword LIKE '%sequel%');

CREATE OR REPLACE TEMP VIEW ya_3a_rewriteYa3_base_mi AS
SELECT mi.*
FROM movie_info AS mi
WHERE (mi.info IN ('Sweden',
                  'Norway',
                  'Germany',
                  'Denmark',
                  'Swedish',
                  'Denish',
                  'Norwegian',
                  'German'));

CREATE OR REPLACE TEMP VIEW ya_3a_rewriteYa3_base_mk AS
SELECT mk.*
FROM movie_keyword AS mk;

CREATE OR REPLACE TEMP VIEW ya_3a_rewriteYa3_base_t AS
SELECT t.*
FROM title AS t
WHERE (t.production_year > 2005);

CREATE OR REPLACE TEMP VIEW ya_3a_rewriteYa3_up_mi AS
SELECT mi.*
FROM ya_3a_rewriteYa3_base_mi AS mi;

CREATE OR REPLACE TEMP VIEW ya_3a_rewriteYa3_up_k AS
SELECT k.*
FROM ya_3a_rewriteYa3_base_k AS k;

CREATE OR REPLACE TEMP VIEW ya_3a_rewriteYa3_up_mk AS
SELECT mk.*
FROM ya_3a_rewriteYa3_base_mk AS mk
WHERE EXISTS (SELECT 1 FROM ya_3a_rewriteYa3_up_k AS k WHERE (k.id = mk.keyword_id));

CREATE OR REPLACE TEMP VIEW ya_3a_rewriteYa3_up_t AS
SELECT t.*
FROM ya_3a_rewriteYa3_base_t AS t
WHERE EXISTS (SELECT 1 FROM ya_3a_rewriteYa3_up_mi AS mi WHERE (t.id = mi.movie_id))
  AND EXISTS (SELECT 1 FROM ya_3a_rewriteYa3_up_mk AS mk WHERE (t.id = mk.movie_id));

CREATE OR REPLACE TEMP VIEW ya_3a_rewriteYa3_down_t AS
SELECT t.*
FROM ya_3a_rewriteYa3_up_t AS t;

CREATE OR REPLACE TEMP VIEW ya_3a_rewriteYa3_down_mi AS
SELECT mi.*
FROM ya_3a_rewriteYa3_up_mi AS mi
WHERE EXISTS (SELECT 1 FROM ya_3a_rewriteYa3_down_t AS t WHERE (t.id = mi.movie_id));

CREATE OR REPLACE TEMP VIEW ya_3a_rewriteYa3_down_mk AS
SELECT mk.*
FROM ya_3a_rewriteYa3_up_mk AS mk
WHERE EXISTS (SELECT 1 FROM ya_3a_rewriteYa3_down_t AS t WHERE (t.id = mk.movie_id));

CREATE OR REPLACE TEMP VIEW ya_3a_rewriteYa3_down_k AS
SELECT k.*
FROM ya_3a_rewriteYa3_up_k AS k
WHERE EXISTS (SELECT 1 FROM ya_3a_rewriteYa3_down_mk AS mk WHERE (k.id = mk.keyword_id));

CREATE OR REPLACE TEMP VIEW ya_3a_rewriteYa3_r3_base_k AS
SELECT k.id AS k__id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_3a_rewriteYa3_down_k AS k
GROUP BY k.id;

CREATE OR REPLACE TEMP VIEW ya_3a_rewriteYa3_r3_base_mi AS
SELECT mi.movie_id AS mi__movie_id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_3a_rewriteYa3_down_mi AS mi
GROUP BY mi.movie_id;

CREATE OR REPLACE TEMP VIEW ya_3a_rewriteYa3_r3_base_mk AS
SELECT mk.movie_id AS mk__movie_id,
       mk.keyword_id AS mk__keyword_id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_3a_rewriteYa3_down_mk AS mk
GROUP BY mk.movie_id, mk.keyword_id;

CREATE OR REPLACE TEMP VIEW ya_3a_rewriteYa3_r3_base_t AS
SELECT t.id AS t__id,
       t.title AS t__title,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_3a_rewriteYa3_down_t AS t
GROUP BY t.id, t.title;

CREATE OR REPLACE TEMP VIEW ya_3a_rewriteYa3_r3_join_1 AS
SELECT round3_left.t__title AS t__title,
       round3_left.t__id AS t__id,
       round3_right.mi__movie_id AS mi__movie_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_3a_rewriteYa3_r3_base_t AS round3_left
JOIN ya_3a_rewriteYa3_r3_base_mi AS round3_right
  ON (round3_left.t__id = round3_right.mi__movie_id)
GROUP BY round3_left.t__title, round3_left.t__id, round3_right.mi__movie_id;

CREATE OR REPLACE TEMP VIEW ya_3a_rewriteYa3_r3_join_2 AS
SELECT round3_left.mk__movie_id AS mk__movie_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_3a_rewriteYa3_r3_base_mk AS round3_left
JOIN ya_3a_rewriteYa3_r3_base_k AS round3_right
  ON (round3_right.k__id = round3_left.mk__keyword_id)
GROUP BY round3_left.mk__movie_id;

CREATE OR REPLACE TEMP VIEW ya_3a_rewriteYa3_r3_join_3 AS
SELECT round3_left.t__title AS t__title,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_3a_rewriteYa3_r3_join_1 AS round3_left
JOIN ya_3a_rewriteYa3_r3_join_2 AS round3_right
  ON (round3_left.t__id = round3_right.mk__movie_id)
 AND (round3_right.mk__movie_id = round3_left.mi__movie_id)
GROUP BY round3_left.t__title;

SELECT round3_result.t__title AS title,
       round3_result.annot AS record_count
FROM ya_3a_rewriteYa3_r3_join_3 AS round3_result;
