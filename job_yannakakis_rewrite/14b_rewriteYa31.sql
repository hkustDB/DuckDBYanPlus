-- DuckDB SUM(1) Yannakakis-style two-pass reducer generated from job_agg/14b.sql.

-- Source variant: query/job_duckdb/14b/rewriteYa31.sql

CREATE OR REPLACE TEMP VIEW ya_14b_rewriteYa31_base_it1 AS
SELECT it1.*
FROM info_type AS it1
WHERE (it1.info = 'countries');

CREATE OR REPLACE TEMP VIEW ya_14b_rewriteYa31_base_it2 AS
SELECT it2.*
FROM info_type AS it2
WHERE (it2.info = 'rating');

CREATE OR REPLACE TEMP VIEW ya_14b_rewriteYa31_base_k AS
SELECT k.*
FROM keyword AS k
WHERE (k.keyword IN ('murder',
                    'murder-in-title'));

CREATE OR REPLACE TEMP VIEW ya_14b_rewriteYa31_base_kt AS
SELECT kt.*
FROM kind_type AS kt
WHERE (kt.kind = 'movie');

CREATE OR REPLACE TEMP VIEW ya_14b_rewriteYa31_base_mi AS
SELECT mi.*
FROM movie_info AS mi
WHERE (mi.info IN ('Sweden',
                  'Norway',
                  'Germany',
                  'Denmark',
                  'Swedish',
                  'Denish',
                  'Norwegian',
                  'German',
                  'USA',
                  'American'));

CREATE OR REPLACE TEMP VIEW ya_14b_rewriteYa31_base_mi_idx AS
SELECT mi_idx.*
FROM movie_info_idx AS mi_idx
WHERE (mi_idx.info > '6.0');

CREATE OR REPLACE TEMP VIEW ya_14b_rewriteYa31_base_mk AS
SELECT mk.*
FROM movie_keyword AS mk;

CREATE OR REPLACE TEMP VIEW ya_14b_rewriteYa31_base_t AS
SELECT t.*
FROM title AS t
WHERE (t.production_year > 2010)
  AND ((t.title LIKE '%murder%'
       OR t.title LIKE '%Murder%'
       OR t.title LIKE '%Mord%'));

CREATE OR REPLACE TEMP VIEW ya_14b_rewriteYa31_up_kt AS
SELECT kt.*
FROM ya_14b_rewriteYa31_base_kt AS kt;

CREATE OR REPLACE TEMP VIEW ya_14b_rewriteYa31_up_it1 AS
SELECT it1.*
FROM ya_14b_rewriteYa31_base_it1 AS it1;

CREATE OR REPLACE TEMP VIEW ya_14b_rewriteYa31_up_mi AS
SELECT mi.*
FROM ya_14b_rewriteYa31_base_mi AS mi
WHERE EXISTS (SELECT 1 FROM ya_14b_rewriteYa31_up_it1 AS it1 WHERE (it1.id = mi.info_type_id));

CREATE OR REPLACE TEMP VIEW ya_14b_rewriteYa31_up_it2 AS
SELECT it2.*
FROM ya_14b_rewriteYa31_base_it2 AS it2;

CREATE OR REPLACE TEMP VIEW ya_14b_rewriteYa31_up_mi_idx AS
SELECT mi_idx.*
FROM ya_14b_rewriteYa31_base_mi_idx AS mi_idx
WHERE EXISTS (SELECT 1 FROM ya_14b_rewriteYa31_up_it2 AS it2 WHERE (it2.id = mi_idx.info_type_id));

CREATE OR REPLACE TEMP VIEW ya_14b_rewriteYa31_up_k AS
SELECT k.*
FROM ya_14b_rewriteYa31_base_k AS k;

CREATE OR REPLACE TEMP VIEW ya_14b_rewriteYa31_up_mk AS
SELECT mk.*
FROM ya_14b_rewriteYa31_base_mk AS mk
WHERE EXISTS (SELECT 1 FROM ya_14b_rewriteYa31_up_k AS k WHERE (k.id = mk.keyword_id));

CREATE OR REPLACE TEMP VIEW ya_14b_rewriteYa31_up_t AS
SELECT t.*
FROM ya_14b_rewriteYa31_base_t AS t
WHERE EXISTS (SELECT 1 FROM ya_14b_rewriteYa31_up_kt AS kt WHERE (kt.id = t.kind_id))
  AND EXISTS (SELECT 1 FROM ya_14b_rewriteYa31_up_mi AS mi WHERE (t.id = mi.movie_id))
  AND EXISTS (SELECT 1 FROM ya_14b_rewriteYa31_up_mi_idx AS mi_idx WHERE (t.id = mi_idx.movie_id))
  AND EXISTS (SELECT 1 FROM ya_14b_rewriteYa31_up_mk AS mk WHERE (t.id = mk.movie_id));

CREATE OR REPLACE TEMP VIEW ya_14b_rewriteYa31_down_t AS
SELECT t.*
FROM ya_14b_rewriteYa31_up_t AS t;

CREATE OR REPLACE TEMP VIEW ya_14b_rewriteYa31_down_kt AS
SELECT kt.*
FROM ya_14b_rewriteYa31_up_kt AS kt
WHERE EXISTS (SELECT 1 FROM ya_14b_rewriteYa31_down_t AS t WHERE (kt.id = t.kind_id));

CREATE OR REPLACE TEMP VIEW ya_14b_rewriteYa31_down_mi AS
SELECT mi.*
FROM ya_14b_rewriteYa31_up_mi AS mi
WHERE EXISTS (SELECT 1 FROM ya_14b_rewriteYa31_down_t AS t WHERE (t.id = mi.movie_id));

CREATE OR REPLACE TEMP VIEW ya_14b_rewriteYa31_down_mi_idx AS
SELECT mi_idx.*
FROM ya_14b_rewriteYa31_up_mi_idx AS mi_idx
WHERE EXISTS (SELECT 1 FROM ya_14b_rewriteYa31_down_t AS t WHERE (t.id = mi_idx.movie_id));

CREATE OR REPLACE TEMP VIEW ya_14b_rewriteYa31_down_mk AS
SELECT mk.*
FROM ya_14b_rewriteYa31_up_mk AS mk
WHERE EXISTS (SELECT 1 FROM ya_14b_rewriteYa31_down_t AS t WHERE (t.id = mk.movie_id));

CREATE OR REPLACE TEMP VIEW ya_14b_rewriteYa31_down_it1 AS
SELECT it1.*
FROM ya_14b_rewriteYa31_up_it1 AS it1
WHERE EXISTS (SELECT 1 FROM ya_14b_rewriteYa31_down_mi AS mi WHERE (it1.id = mi.info_type_id));

CREATE OR REPLACE TEMP VIEW ya_14b_rewriteYa31_down_it2 AS
SELECT it2.*
FROM ya_14b_rewriteYa31_up_it2 AS it2
WHERE EXISTS (SELECT 1 FROM ya_14b_rewriteYa31_down_mi_idx AS mi_idx WHERE (it2.id = mi_idx.info_type_id));

CREATE OR REPLACE TEMP VIEW ya_14b_rewriteYa31_down_k AS
SELECT k.*
FROM ya_14b_rewriteYa31_up_k AS k
WHERE EXISTS (SELECT 1 FROM ya_14b_rewriteYa31_down_mk AS mk WHERE (k.id = mk.keyword_id));

CREATE OR REPLACE TEMP VIEW ya_14b_rewriteYa31_r3_base_it1 AS
SELECT it1.id AS it1__id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_14b_rewriteYa31_down_it1 AS it1
GROUP BY it1.id;

CREATE OR REPLACE TEMP VIEW ya_14b_rewriteYa31_r3_base_it2 AS
SELECT it2.id AS it2__id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_14b_rewriteYa31_down_it2 AS it2
GROUP BY it2.id;

CREATE OR REPLACE TEMP VIEW ya_14b_rewriteYa31_r3_base_k AS
SELECT k.id AS k__id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_14b_rewriteYa31_down_k AS k
GROUP BY k.id;

CREATE OR REPLACE TEMP VIEW ya_14b_rewriteYa31_r3_base_kt AS
SELECT kt.id AS kt__id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_14b_rewriteYa31_down_kt AS kt
GROUP BY kt.id;

CREATE OR REPLACE TEMP VIEW ya_14b_rewriteYa31_r3_base_mi AS
SELECT mi.movie_id AS mi__movie_id,
       mi.info_type_id AS mi__info_type_id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_14b_rewriteYa31_down_mi AS mi
GROUP BY mi.movie_id, mi.info_type_id;

CREATE OR REPLACE TEMP VIEW ya_14b_rewriteYa31_r3_base_mi_idx AS
SELECT mi_idx.movie_id AS mi_idx__movie_id,
       mi_idx.info_type_id AS mi_idx__info_type_id,
       mi_idx.info AS mi_idx__info,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_14b_rewriteYa31_down_mi_idx AS mi_idx
GROUP BY mi_idx.movie_id, mi_idx.info_type_id, mi_idx.info;

CREATE OR REPLACE TEMP VIEW ya_14b_rewriteYa31_r3_base_mk AS
SELECT mk.movie_id AS mk__movie_id,
       mk.keyword_id AS mk__keyword_id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_14b_rewriteYa31_down_mk AS mk
GROUP BY mk.movie_id, mk.keyword_id;

CREATE OR REPLACE TEMP VIEW ya_14b_rewriteYa31_r3_base_t AS
SELECT t.kind_id AS t__kind_id,
       t.id AS t__id,
       t.title AS t__title,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_14b_rewriteYa31_down_t AS t
GROUP BY t.kind_id, t.id, t.title;

CREATE OR REPLACE TEMP VIEW ya_14b_rewriteYa31_r3_join_1 AS
SELECT round3_left.t__title AS t__title,
       round3_left.t__id AS t__id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_14b_rewriteYa31_r3_base_t AS round3_left
JOIN ya_14b_rewriteYa31_r3_base_kt AS round3_right
  ON (round3_right.kt__id = round3_left.t__kind_id)
GROUP BY round3_left.t__title, round3_left.t__id;

CREATE OR REPLACE TEMP VIEW ya_14b_rewriteYa31_r3_join_2 AS
SELECT round3_left.mi__movie_id AS mi__movie_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_14b_rewriteYa31_r3_base_mi AS round3_left
JOIN ya_14b_rewriteYa31_r3_base_it1 AS round3_right
  ON (round3_right.it1__id = round3_left.mi__info_type_id)
GROUP BY round3_left.mi__movie_id;

CREATE OR REPLACE TEMP VIEW ya_14b_rewriteYa31_r3_join_3 AS
SELECT round3_left.t__title AS t__title,
       round3_left.t__id AS t__id,
       round3_right.mi__movie_id AS mi__movie_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_14b_rewriteYa31_r3_join_1 AS round3_left
JOIN ya_14b_rewriteYa31_r3_join_2 AS round3_right
  ON (round3_left.t__id = round3_right.mi__movie_id)
GROUP BY round3_left.t__title, round3_left.t__id, round3_right.mi__movie_id;

CREATE OR REPLACE TEMP VIEW ya_14b_rewriteYa31_r3_join_4 AS
SELECT round3_left.mi_idx__info AS mi_idx__info,
       round3_left.mi_idx__movie_id AS mi_idx__movie_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_14b_rewriteYa31_r3_base_mi_idx AS round3_left
JOIN ya_14b_rewriteYa31_r3_base_it2 AS round3_right
  ON (round3_right.it2__id = round3_left.mi_idx__info_type_id)
GROUP BY round3_left.mi_idx__info, round3_left.mi_idx__movie_id;

CREATE OR REPLACE TEMP VIEW ya_14b_rewriteYa31_r3_join_5 AS
SELECT round3_right.mi_idx__info AS mi_idx__info,
       round3_left.t__title AS t__title,
       round3_left.t__id AS t__id,
       round3_left.mi__movie_id AS mi__movie_id,
       round3_right.mi_idx__movie_id AS mi_idx__movie_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_14b_rewriteYa31_r3_join_3 AS round3_left
JOIN ya_14b_rewriteYa31_r3_join_4 AS round3_right
  ON (round3_left.t__id = round3_right.mi_idx__movie_id)
 AND (round3_left.mi__movie_id = round3_right.mi_idx__movie_id)
GROUP BY round3_right.mi_idx__info, round3_left.t__title, round3_left.t__id, round3_left.mi__movie_id, round3_right.mi_idx__movie_id;

CREATE OR REPLACE TEMP VIEW ya_14b_rewriteYa31_r3_join_6 AS
SELECT round3_left.mk__movie_id AS mk__movie_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_14b_rewriteYa31_r3_base_mk AS round3_left
JOIN ya_14b_rewriteYa31_r3_base_k AS round3_right
  ON (round3_right.k__id = round3_left.mk__keyword_id)
GROUP BY round3_left.mk__movie_id;

CREATE OR REPLACE TEMP VIEW ya_14b_rewriteYa31_r3_join_7 AS
SELECT round3_left.mi_idx__info AS mi_idx__info,
       round3_left.t__title AS t__title,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_14b_rewriteYa31_r3_join_5 AS round3_left
JOIN ya_14b_rewriteYa31_r3_join_6 AS round3_right
  ON (round3_left.t__id = round3_right.mk__movie_id)
 AND (round3_right.mk__movie_id = round3_left.mi__movie_id)
 AND (round3_right.mk__movie_id = round3_left.mi_idx__movie_id)
GROUP BY round3_left.mi_idx__info, round3_left.t__title;

SELECT round3_result.mi_idx__info AS info,
       round3_result.t__title AS title,
       round3_result.annot AS record_count
FROM ya_14b_rewriteYa31_r3_join_7 AS round3_result;
