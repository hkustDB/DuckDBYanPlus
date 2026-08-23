-- DuckDB SUM(1) Yannakakis-style two-pass reducer generated from job_agg/4a.sql.

-- Source variant: query/job_duckdb/4a/rewriteYa6.sql

CREATE OR REPLACE TEMP VIEW ya_4a_rewriteYa6_base_it AS
SELECT it.*
FROM info_type AS it
WHERE (it.info ='rating');

CREATE OR REPLACE TEMP VIEW ya_4a_rewriteYa6_base_k AS
SELECT k.*
FROM keyword AS k
WHERE (k.keyword LIKE '%sequel%');

CREATE OR REPLACE TEMP VIEW ya_4a_rewriteYa6_base_mi_idx AS
SELECT mi_idx.*
FROM movie_info_idx AS mi_idx
WHERE (mi_idx.info > '5.0');

CREATE OR REPLACE TEMP VIEW ya_4a_rewriteYa6_base_mk AS
SELECT mk.*
FROM movie_keyword AS mk;

CREATE OR REPLACE TEMP VIEW ya_4a_rewriteYa6_base_t AS
SELECT t.*
FROM title AS t
WHERE (t.production_year > 2005);

CREATE OR REPLACE TEMP VIEW ya_4a_rewriteYa6_up_t AS
SELECT t.*
FROM ya_4a_rewriteYa6_base_t AS t;

CREATE OR REPLACE TEMP VIEW ya_4a_rewriteYa6_up_it AS
SELECT it.*
FROM ya_4a_rewriteYa6_base_it AS it;

CREATE OR REPLACE TEMP VIEW ya_4a_rewriteYa6_up_mi_idx AS
SELECT mi_idx.*
FROM ya_4a_rewriteYa6_base_mi_idx AS mi_idx
WHERE EXISTS (SELECT 1 FROM ya_4a_rewriteYa6_up_it AS it WHERE (it.id = mi_idx.info_type_id));

CREATE OR REPLACE TEMP VIEW ya_4a_rewriteYa6_up_mk AS
SELECT mk.*
FROM ya_4a_rewriteYa6_base_mk AS mk
WHERE EXISTS (SELECT 1 FROM ya_4a_rewriteYa6_up_t AS t WHERE (t.id = mk.movie_id))
  AND EXISTS (SELECT 1 FROM ya_4a_rewriteYa6_up_mi_idx AS mi_idx WHERE (mk.movie_id = mi_idx.movie_id));

CREATE OR REPLACE TEMP VIEW ya_4a_rewriteYa6_up_k AS
SELECT k.*
FROM ya_4a_rewriteYa6_base_k AS k
WHERE EXISTS (SELECT 1 FROM ya_4a_rewriteYa6_up_mk AS mk WHERE (k.id = mk.keyword_id));

CREATE OR REPLACE TEMP VIEW ya_4a_rewriteYa6_down_k AS
SELECT k.*
FROM ya_4a_rewriteYa6_up_k AS k;

CREATE OR REPLACE TEMP VIEW ya_4a_rewriteYa6_down_mk AS
SELECT mk.*
FROM ya_4a_rewriteYa6_up_mk AS mk
WHERE EXISTS (SELECT 1 FROM ya_4a_rewriteYa6_down_k AS k WHERE (k.id = mk.keyword_id));

CREATE OR REPLACE TEMP VIEW ya_4a_rewriteYa6_down_t AS
SELECT t.*
FROM ya_4a_rewriteYa6_up_t AS t
WHERE EXISTS (SELECT 1 FROM ya_4a_rewriteYa6_down_mk AS mk WHERE (t.id = mk.movie_id));

CREATE OR REPLACE TEMP VIEW ya_4a_rewriteYa6_down_mi_idx AS
SELECT mi_idx.*
FROM ya_4a_rewriteYa6_up_mi_idx AS mi_idx
WHERE EXISTS (SELECT 1 FROM ya_4a_rewriteYa6_down_mk AS mk WHERE (mk.movie_id = mi_idx.movie_id));

CREATE OR REPLACE TEMP VIEW ya_4a_rewriteYa6_down_it AS
SELECT it.*
FROM ya_4a_rewriteYa6_up_it AS it
WHERE EXISTS (SELECT 1 FROM ya_4a_rewriteYa6_down_mi_idx AS mi_idx WHERE (it.id = mi_idx.info_type_id));

CREATE OR REPLACE TEMP VIEW ya_4a_rewriteYa6_r3_base_it AS
SELECT it.id AS it__id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_4a_rewriteYa6_down_it AS it
GROUP BY it.id;

CREATE OR REPLACE TEMP VIEW ya_4a_rewriteYa6_r3_base_k AS
SELECT k.id AS k__id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_4a_rewriteYa6_down_k AS k
GROUP BY k.id;

CREATE OR REPLACE TEMP VIEW ya_4a_rewriteYa6_r3_base_mi_idx AS
SELECT mi_idx.movie_id AS mi_idx__movie_id,
       mi_idx.info_type_id AS mi_idx__info_type_id,
       mi_idx.info AS mi_idx__info,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_4a_rewriteYa6_down_mi_idx AS mi_idx
GROUP BY mi_idx.movie_id, mi_idx.info_type_id, mi_idx.info;

CREATE OR REPLACE TEMP VIEW ya_4a_rewriteYa6_r3_base_mk AS
SELECT mk.movie_id AS mk__movie_id,
       mk.keyword_id AS mk__keyword_id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_4a_rewriteYa6_down_mk AS mk
GROUP BY mk.movie_id, mk.keyword_id;

CREATE OR REPLACE TEMP VIEW ya_4a_rewriteYa6_r3_base_t AS
SELECT t.id AS t__id,
       t.title AS t__title,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_4a_rewriteYa6_down_t AS t
GROUP BY t.id, t.title;

CREATE OR REPLACE TEMP VIEW ya_4a_rewriteYa6_r3_join_1 AS
SELECT round3_right.t__title AS t__title,
       round3_right.t__id AS t__id,
       round3_left.mk__movie_id AS mk__movie_id,
       round3_left.mk__keyword_id AS mk__keyword_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_4a_rewriteYa6_r3_base_mk AS round3_left
JOIN ya_4a_rewriteYa6_r3_base_t AS round3_right
  ON (round3_right.t__id = round3_left.mk__movie_id)
GROUP BY round3_right.t__title, round3_right.t__id, round3_left.mk__movie_id, round3_left.mk__keyword_id;

CREATE OR REPLACE TEMP VIEW ya_4a_rewriteYa6_r3_join_2 AS
SELECT round3_left.mi_idx__info AS mi_idx__info,
       round3_left.mi_idx__movie_id AS mi_idx__movie_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_4a_rewriteYa6_r3_base_mi_idx AS round3_left
JOIN ya_4a_rewriteYa6_r3_base_it AS round3_right
  ON (round3_right.it__id = round3_left.mi_idx__info_type_id)
GROUP BY round3_left.mi_idx__info, round3_left.mi_idx__movie_id;

CREATE OR REPLACE TEMP VIEW ya_4a_rewriteYa6_r3_join_3 AS
SELECT round3_right.mi_idx__info AS mi_idx__info,
       round3_left.t__title AS t__title,
       round3_left.mk__keyword_id AS mk__keyword_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_4a_rewriteYa6_r3_join_1 AS round3_left
JOIN ya_4a_rewriteYa6_r3_join_2 AS round3_right
  ON (round3_left.t__id = round3_right.mi_idx__movie_id)
 AND (round3_left.mk__movie_id = round3_right.mi_idx__movie_id)
GROUP BY round3_right.mi_idx__info, round3_left.t__title, round3_left.mk__keyword_id;

CREATE OR REPLACE TEMP VIEW ya_4a_rewriteYa6_r3_join_4 AS
SELECT round3_right.mi_idx__info AS mi_idx__info,
       round3_right.t__title AS t__title,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_4a_rewriteYa6_r3_base_k AS round3_left
JOIN ya_4a_rewriteYa6_r3_join_3 AS round3_right
  ON (round3_left.k__id = round3_right.mk__keyword_id)
GROUP BY round3_right.mi_idx__info, round3_right.t__title;

SELECT round3_result.mi_idx__info AS info,
       round3_result.t__title AS title,
       round3_result.annot AS record_count
FROM ya_4a_rewriteYa6_r3_join_4 AS round3_result;
