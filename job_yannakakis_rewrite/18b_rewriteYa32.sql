-- DuckDB SUM(1) Yannakakis-style two-pass reducer generated from job_agg/18b.sql.

-- Source variant: query/job_duckdb/18b/rewriteYa32.sql

CREATE OR REPLACE TEMP VIEW ya_18b_rewriteYa32_base_ci AS
SELECT ci.*
FROM cast_info AS ci
WHERE (ci.note IN ('(writer)',
                  '(head writer)',
                  '(written by)',
                  '(story)',
                  '(story editor)'));

CREATE OR REPLACE TEMP VIEW ya_18b_rewriteYa32_base_it1 AS
SELECT it1.*
FROM info_type AS it1
WHERE (it1.info = 'genres');

CREATE OR REPLACE TEMP VIEW ya_18b_rewriteYa32_base_it2 AS
SELECT it2.*
FROM info_type AS it2
WHERE (it2.info = 'rating');

CREATE OR REPLACE TEMP VIEW ya_18b_rewriteYa32_base_mi AS
SELECT mi.*
FROM movie_info AS mi
WHERE (mi.info IN ('Horror',
                  'Thriller'))
  AND (mi.note IS NULL);

CREATE OR REPLACE TEMP VIEW ya_18b_rewriteYa32_base_mi_idx AS
SELECT mi_idx.*
FROM movie_info_idx AS mi_idx
WHERE (mi_idx.info > '8.0');

CREATE OR REPLACE TEMP VIEW ya_18b_rewriteYa32_base_n AS
SELECT n.*
FROM name AS n
WHERE (n.gender IS NOT NULL)
  AND (n.gender = 'f');

CREATE OR REPLACE TEMP VIEW ya_18b_rewriteYa32_base_t AS
SELECT t.*
FROM title AS t
WHERE (t.production_year BETWEEN 2008 AND 2014);

CREATE OR REPLACE TEMP VIEW ya_18b_rewriteYa32_up_it2 AS
SELECT it2.*
FROM ya_18b_rewriteYa32_base_it2 AS it2;

CREATE OR REPLACE TEMP VIEW ya_18b_rewriteYa32_up_it1 AS
SELECT it1.*
FROM ya_18b_rewriteYa32_base_it1 AS it1;

CREATE OR REPLACE TEMP VIEW ya_18b_rewriteYa32_up_mi AS
SELECT mi.*
FROM ya_18b_rewriteYa32_base_mi AS mi
WHERE EXISTS (SELECT 1 FROM ya_18b_rewriteYa32_up_it1 AS it1 WHERE (it1.id = mi.info_type_id));

CREATE OR REPLACE TEMP VIEW ya_18b_rewriteYa32_up_t AS
SELECT t.*
FROM ya_18b_rewriteYa32_base_t AS t;

CREATE OR REPLACE TEMP VIEW ya_18b_rewriteYa32_up_n AS
SELECT n.*
FROM ya_18b_rewriteYa32_base_n AS n;

CREATE OR REPLACE TEMP VIEW ya_18b_rewriteYa32_up_ci AS
SELECT ci.*
FROM ya_18b_rewriteYa32_base_ci AS ci
WHERE EXISTS (SELECT 1 FROM ya_18b_rewriteYa32_up_n AS n WHERE (n.id = ci.person_id));

CREATE OR REPLACE TEMP VIEW ya_18b_rewriteYa32_up_mi_idx AS
SELECT mi_idx.*
FROM ya_18b_rewriteYa32_base_mi_idx AS mi_idx
WHERE EXISTS (SELECT 1 FROM ya_18b_rewriteYa32_up_it2 AS it2 WHERE (it2.id = mi_idx.info_type_id))
  AND EXISTS (SELECT 1 FROM ya_18b_rewriteYa32_up_mi AS mi WHERE (mi.movie_id = mi_idx.movie_id))
  AND EXISTS (SELECT 1 FROM ya_18b_rewriteYa32_up_t AS t WHERE (t.id = mi_idx.movie_id))
  AND EXISTS (SELECT 1 FROM ya_18b_rewriteYa32_up_ci AS ci WHERE (ci.movie_id = mi_idx.movie_id));

CREATE OR REPLACE TEMP VIEW ya_18b_rewriteYa32_down_mi_idx AS
SELECT mi_idx.*
FROM ya_18b_rewriteYa32_up_mi_idx AS mi_idx;

CREATE OR REPLACE TEMP VIEW ya_18b_rewriteYa32_down_it2 AS
SELECT it2.*
FROM ya_18b_rewriteYa32_up_it2 AS it2
WHERE EXISTS (SELECT 1 FROM ya_18b_rewriteYa32_down_mi_idx AS mi_idx WHERE (it2.id = mi_idx.info_type_id));

CREATE OR REPLACE TEMP VIEW ya_18b_rewriteYa32_down_mi AS
SELECT mi.*
FROM ya_18b_rewriteYa32_up_mi AS mi
WHERE EXISTS (SELECT 1 FROM ya_18b_rewriteYa32_down_mi_idx AS mi_idx WHERE (mi.movie_id = mi_idx.movie_id));

CREATE OR REPLACE TEMP VIEW ya_18b_rewriteYa32_down_t AS
SELECT t.*
FROM ya_18b_rewriteYa32_up_t AS t
WHERE EXISTS (SELECT 1 FROM ya_18b_rewriteYa32_down_mi_idx AS mi_idx WHERE (t.id = mi_idx.movie_id));

CREATE OR REPLACE TEMP VIEW ya_18b_rewriteYa32_down_ci AS
SELECT ci.*
FROM ya_18b_rewriteYa32_up_ci AS ci
WHERE EXISTS (SELECT 1 FROM ya_18b_rewriteYa32_down_mi_idx AS mi_idx WHERE (ci.movie_id = mi_idx.movie_id));

CREATE OR REPLACE TEMP VIEW ya_18b_rewriteYa32_down_it1 AS
SELECT it1.*
FROM ya_18b_rewriteYa32_up_it1 AS it1
WHERE EXISTS (SELECT 1 FROM ya_18b_rewriteYa32_down_mi AS mi WHERE (it1.id = mi.info_type_id));

CREATE OR REPLACE TEMP VIEW ya_18b_rewriteYa32_down_n AS
SELECT n.*
FROM ya_18b_rewriteYa32_up_n AS n
WHERE EXISTS (SELECT 1 FROM ya_18b_rewriteYa32_down_ci AS ci WHERE (n.id = ci.person_id));

CREATE OR REPLACE TEMP VIEW ya_18b_rewriteYa32_r3_base_ci AS
SELECT ci.movie_id AS ci__movie_id,
       ci.person_id AS ci__person_id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_18b_rewriteYa32_down_ci AS ci
GROUP BY ci.movie_id, ci.person_id;

CREATE OR REPLACE TEMP VIEW ya_18b_rewriteYa32_r3_base_it1 AS
SELECT it1.id AS it1__id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_18b_rewriteYa32_down_it1 AS it1
GROUP BY it1.id;

CREATE OR REPLACE TEMP VIEW ya_18b_rewriteYa32_r3_base_it2 AS
SELECT it2.id AS it2__id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_18b_rewriteYa32_down_it2 AS it2
GROUP BY it2.id;

CREATE OR REPLACE TEMP VIEW ya_18b_rewriteYa32_r3_base_mi AS
SELECT mi.movie_id AS mi__movie_id,
       mi.info_type_id AS mi__info_type_id,
       mi.info AS mi__info,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_18b_rewriteYa32_down_mi AS mi
GROUP BY mi.movie_id, mi.info_type_id, mi.info;

CREATE OR REPLACE TEMP VIEW ya_18b_rewriteYa32_r3_base_mi_idx AS
SELECT mi_idx.movie_id AS mi_idx__movie_id,
       mi_idx.info_type_id AS mi_idx__info_type_id,
       mi_idx.info AS mi_idx__info,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_18b_rewriteYa32_down_mi_idx AS mi_idx
GROUP BY mi_idx.movie_id, mi_idx.info_type_id, mi_idx.info;

CREATE OR REPLACE TEMP VIEW ya_18b_rewriteYa32_r3_base_n AS
SELECT n.id AS n__id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_18b_rewriteYa32_down_n AS n
GROUP BY n.id;

CREATE OR REPLACE TEMP VIEW ya_18b_rewriteYa32_r3_base_t AS
SELECT t.id AS t__id,
       t.title AS t__title,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_18b_rewriteYa32_down_t AS t
GROUP BY t.id, t.title;

CREATE OR REPLACE TEMP VIEW ya_18b_rewriteYa32_r3_join_1 AS
SELECT round3_left.mi_idx__info AS mi_idx__info,
       round3_left.mi_idx__movie_id AS mi_idx__movie_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_18b_rewriteYa32_r3_base_mi_idx AS round3_left
JOIN ya_18b_rewriteYa32_r3_base_it2 AS round3_right
  ON (round3_right.it2__id = round3_left.mi_idx__info_type_id)
GROUP BY round3_left.mi_idx__info, round3_left.mi_idx__movie_id;

CREATE OR REPLACE TEMP VIEW ya_18b_rewriteYa32_r3_join_2 AS
SELECT round3_left.mi__info AS mi__info,
       round3_left.mi__movie_id AS mi__movie_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_18b_rewriteYa32_r3_base_mi AS round3_left
JOIN ya_18b_rewriteYa32_r3_base_it1 AS round3_right
  ON (round3_right.it1__id = round3_left.mi__info_type_id)
GROUP BY round3_left.mi__info, round3_left.mi__movie_id;

CREATE OR REPLACE TEMP VIEW ya_18b_rewriteYa32_r3_join_3 AS
SELECT round3_right.mi__info AS mi__info,
       round3_left.mi_idx__info AS mi_idx__info,
       round3_right.mi__movie_id AS mi__movie_id,
       round3_left.mi_idx__movie_id AS mi_idx__movie_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_18b_rewriteYa32_r3_join_1 AS round3_left
JOIN ya_18b_rewriteYa32_r3_join_2 AS round3_right
  ON (round3_right.mi__movie_id = round3_left.mi_idx__movie_id)
GROUP BY round3_right.mi__info, round3_left.mi_idx__info, round3_right.mi__movie_id, round3_left.mi_idx__movie_id;

CREATE OR REPLACE TEMP VIEW ya_18b_rewriteYa32_r3_join_4 AS
SELECT round3_left.mi__info AS mi__info,
       round3_left.mi_idx__info AS mi_idx__info,
       round3_right.t__title AS t__title,
       round3_right.t__id AS t__id,
       round3_left.mi__movie_id AS mi__movie_id,
       round3_left.mi_idx__movie_id AS mi_idx__movie_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_18b_rewriteYa32_r3_join_3 AS round3_left
JOIN ya_18b_rewriteYa32_r3_base_t AS round3_right
  ON (round3_right.t__id = round3_left.mi__movie_id)
 AND (round3_right.t__id = round3_left.mi_idx__movie_id)
GROUP BY round3_left.mi__info, round3_left.mi_idx__info, round3_right.t__title, round3_right.t__id, round3_left.mi__movie_id, round3_left.mi_idx__movie_id;

CREATE OR REPLACE TEMP VIEW ya_18b_rewriteYa32_r3_join_5 AS
SELECT round3_left.ci__movie_id AS ci__movie_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_18b_rewriteYa32_r3_base_ci AS round3_left
JOIN ya_18b_rewriteYa32_r3_base_n AS round3_right
  ON (round3_right.n__id = round3_left.ci__person_id)
GROUP BY round3_left.ci__movie_id;

CREATE OR REPLACE TEMP VIEW ya_18b_rewriteYa32_r3_join_6 AS
SELECT round3_left.mi__info AS mi__info,
       round3_left.mi_idx__info AS mi_idx__info,
       round3_left.t__title AS t__title,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_18b_rewriteYa32_r3_join_4 AS round3_left
JOIN ya_18b_rewriteYa32_r3_join_5 AS round3_right
  ON (round3_left.t__id = round3_right.ci__movie_id)
 AND (round3_right.ci__movie_id = round3_left.mi__movie_id)
 AND (round3_right.ci__movie_id = round3_left.mi_idx__movie_id)
GROUP BY round3_left.mi__info, round3_left.mi_idx__info, round3_left.t__title;

SELECT round3_result.mi__info AS info,
       round3_result.mi_idx__info AS info,
       round3_result.t__title AS title,
       round3_result.annot AS record_count
FROM ya_18b_rewriteYa32_r3_join_6 AS round3_result;
