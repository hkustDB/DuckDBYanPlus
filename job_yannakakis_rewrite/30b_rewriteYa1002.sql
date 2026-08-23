-- DuckDB SUM(1) Yannakakis-style two-pass reducer generated from job_agg/30b.sql.

-- Source variant: query/job_duckdb/30b/rewriteYa1002.sql

CREATE OR REPLACE TEMP VIEW ya_30b_rewriteYa1002_base_cc AS
SELECT cc.*
FROM complete_cast AS cc;

CREATE OR REPLACE TEMP VIEW ya_30b_rewriteYa1002_base_cct1 AS
SELECT cct1.*
FROM comp_cast_type AS cct1
WHERE (cct1.kind IN ('cast',
                    'crew'));

CREATE OR REPLACE TEMP VIEW ya_30b_rewriteYa1002_base_cct2 AS
SELECT cct2.*
FROM comp_cast_type AS cct2
WHERE (cct2.kind ='complete+verified');

CREATE OR REPLACE TEMP VIEW ya_30b_rewriteYa1002_base_ci AS
SELECT ci.*
FROM cast_info AS ci
WHERE (ci.note IN ('(writer)',
                  '(head writer)',
                  '(written by)',
                  '(story)',
                  '(story editor)'));

CREATE OR REPLACE TEMP VIEW ya_30b_rewriteYa1002_base_it1 AS
SELECT it1.*
FROM info_type AS it1
WHERE (it1.info = 'genres');

CREATE OR REPLACE TEMP VIEW ya_30b_rewriteYa1002_base_it2 AS
SELECT it2.*
FROM info_type AS it2
WHERE (it2.info = 'votes');

CREATE OR REPLACE TEMP VIEW ya_30b_rewriteYa1002_base_k AS
SELECT k.*
FROM keyword AS k
WHERE (k.keyword IN ('murder',
                    'violence',
                    'blood',
                    'gore',
                    'death',
                    'female-nudity',
                    'hospital'));

CREATE OR REPLACE TEMP VIEW ya_30b_rewriteYa1002_base_mi AS
SELECT mi.*
FROM movie_info AS mi
WHERE (mi.info IN ('Horror',
                  'Thriller'));

CREATE OR REPLACE TEMP VIEW ya_30b_rewriteYa1002_base_mi_idx AS
SELECT mi_idx.*
FROM movie_info_idx AS mi_idx;

CREATE OR REPLACE TEMP VIEW ya_30b_rewriteYa1002_base_mk AS
SELECT mk.*
FROM movie_keyword AS mk;

CREATE OR REPLACE TEMP VIEW ya_30b_rewriteYa1002_base_n AS
SELECT n.*
FROM name AS n
WHERE (n.gender = 'm');

CREATE OR REPLACE TEMP VIEW ya_30b_rewriteYa1002_base_t AS
SELECT t.*
FROM title AS t
WHERE (t.production_year > 2000)
  AND ((t.title LIKE '%Freddy%'
       OR t.title LIKE '%Jason%'
       OR t.title LIKE 'Saw%'));

CREATE OR REPLACE TEMP VIEW ya_30b_rewriteYa1002_up_it1 AS
SELECT it1.*
FROM ya_30b_rewriteYa1002_base_it1 AS it1;

CREATE OR REPLACE TEMP VIEW ya_30b_rewriteYa1002_up_mi AS
SELECT mi.*
FROM ya_30b_rewriteYa1002_base_mi AS mi
WHERE EXISTS (SELECT 1 FROM ya_30b_rewriteYa1002_up_it1 AS it1 WHERE (it1.id = mi.info_type_id));

CREATE OR REPLACE TEMP VIEW ya_30b_rewriteYa1002_up_it2 AS
SELECT it2.*
FROM ya_30b_rewriteYa1002_base_it2 AS it2;

CREATE OR REPLACE TEMP VIEW ya_30b_rewriteYa1002_up_mi_idx AS
SELECT mi_idx.*
FROM ya_30b_rewriteYa1002_base_mi_idx AS mi_idx
WHERE EXISTS (SELECT 1 FROM ya_30b_rewriteYa1002_up_it2 AS it2 WHERE (it2.id = mi_idx.info_type_id));

CREATE OR REPLACE TEMP VIEW ya_30b_rewriteYa1002_up_t AS
SELECT t.*
FROM ya_30b_rewriteYa1002_base_t AS t;

CREATE OR REPLACE TEMP VIEW ya_30b_rewriteYa1002_up_cct1 AS
SELECT cct1.*
FROM ya_30b_rewriteYa1002_base_cct1 AS cct1;

CREATE OR REPLACE TEMP VIEW ya_30b_rewriteYa1002_up_cct2 AS
SELECT cct2.*
FROM ya_30b_rewriteYa1002_base_cct2 AS cct2;

CREATE OR REPLACE TEMP VIEW ya_30b_rewriteYa1002_up_cc AS
SELECT cc.*
FROM ya_30b_rewriteYa1002_base_cc AS cc
WHERE EXISTS (SELECT 1 FROM ya_30b_rewriteYa1002_up_cct1 AS cct1 WHERE (cct1.id = cc.subject_id))
  AND EXISTS (SELECT 1 FROM ya_30b_rewriteYa1002_up_cct2 AS cct2 WHERE (cct2.id = cc.status_id));

CREATE OR REPLACE TEMP VIEW ya_30b_rewriteYa1002_up_n AS
SELECT n.*
FROM ya_30b_rewriteYa1002_base_n AS n;

CREATE OR REPLACE TEMP VIEW ya_30b_rewriteYa1002_up_ci AS
SELECT ci.*
FROM ya_30b_rewriteYa1002_base_ci AS ci
WHERE EXISTS (SELECT 1 FROM ya_30b_rewriteYa1002_up_n AS n WHERE (n.id = ci.person_id));

CREATE OR REPLACE TEMP VIEW ya_30b_rewriteYa1002_up_mk AS
SELECT mk.*
FROM ya_30b_rewriteYa1002_base_mk AS mk
WHERE EXISTS (SELECT 1 FROM ya_30b_rewriteYa1002_up_mi AS mi WHERE (mi.movie_id = mk.movie_id))
  AND EXISTS (SELECT 1 FROM ya_30b_rewriteYa1002_up_mi_idx AS mi_idx WHERE (mi_idx.movie_id = mk.movie_id))
  AND EXISTS (SELECT 1 FROM ya_30b_rewriteYa1002_up_t AS t WHERE (t.id = mk.movie_id))
  AND EXISTS (SELECT 1 FROM ya_30b_rewriteYa1002_up_cc AS cc WHERE (mk.movie_id = cc.movie_id))
  AND EXISTS (SELECT 1 FROM ya_30b_rewriteYa1002_up_ci AS ci WHERE (ci.movie_id = mk.movie_id));

CREATE OR REPLACE TEMP VIEW ya_30b_rewriteYa1002_up_k AS
SELECT k.*
FROM ya_30b_rewriteYa1002_base_k AS k
WHERE EXISTS (SELECT 1 FROM ya_30b_rewriteYa1002_up_mk AS mk WHERE (k.id = mk.keyword_id));

CREATE OR REPLACE TEMP VIEW ya_30b_rewriteYa1002_down_k AS
SELECT k.*
FROM ya_30b_rewriteYa1002_up_k AS k;

CREATE OR REPLACE TEMP VIEW ya_30b_rewriteYa1002_down_mk AS
SELECT mk.*
FROM ya_30b_rewriteYa1002_up_mk AS mk
WHERE EXISTS (SELECT 1 FROM ya_30b_rewriteYa1002_down_k AS k WHERE (k.id = mk.keyword_id));

CREATE OR REPLACE TEMP VIEW ya_30b_rewriteYa1002_down_mi AS
SELECT mi.*
FROM ya_30b_rewriteYa1002_up_mi AS mi
WHERE EXISTS (SELECT 1 FROM ya_30b_rewriteYa1002_down_mk AS mk WHERE (mi.movie_id = mk.movie_id));

CREATE OR REPLACE TEMP VIEW ya_30b_rewriteYa1002_down_mi_idx AS
SELECT mi_idx.*
FROM ya_30b_rewriteYa1002_up_mi_idx AS mi_idx
WHERE EXISTS (SELECT 1 FROM ya_30b_rewriteYa1002_down_mk AS mk WHERE (mi_idx.movie_id = mk.movie_id));

CREATE OR REPLACE TEMP VIEW ya_30b_rewriteYa1002_down_t AS
SELECT t.*
FROM ya_30b_rewriteYa1002_up_t AS t
WHERE EXISTS (SELECT 1 FROM ya_30b_rewriteYa1002_down_mk AS mk WHERE (t.id = mk.movie_id));

CREATE OR REPLACE TEMP VIEW ya_30b_rewriteYa1002_down_cc AS
SELECT cc.*
FROM ya_30b_rewriteYa1002_up_cc AS cc
WHERE EXISTS (SELECT 1 FROM ya_30b_rewriteYa1002_down_mk AS mk WHERE (mk.movie_id = cc.movie_id));

CREATE OR REPLACE TEMP VIEW ya_30b_rewriteYa1002_down_ci AS
SELECT ci.*
FROM ya_30b_rewriteYa1002_up_ci AS ci
WHERE EXISTS (SELECT 1 FROM ya_30b_rewriteYa1002_down_mk AS mk WHERE (ci.movie_id = mk.movie_id));

CREATE OR REPLACE TEMP VIEW ya_30b_rewriteYa1002_down_it1 AS
SELECT it1.*
FROM ya_30b_rewriteYa1002_up_it1 AS it1
WHERE EXISTS (SELECT 1 FROM ya_30b_rewriteYa1002_down_mi AS mi WHERE (it1.id = mi.info_type_id));

CREATE OR REPLACE TEMP VIEW ya_30b_rewriteYa1002_down_it2 AS
SELECT it2.*
FROM ya_30b_rewriteYa1002_up_it2 AS it2
WHERE EXISTS (SELECT 1 FROM ya_30b_rewriteYa1002_down_mi_idx AS mi_idx WHERE (it2.id = mi_idx.info_type_id));

CREATE OR REPLACE TEMP VIEW ya_30b_rewriteYa1002_down_cct1 AS
SELECT cct1.*
FROM ya_30b_rewriteYa1002_up_cct1 AS cct1
WHERE EXISTS (SELECT 1 FROM ya_30b_rewriteYa1002_down_cc AS cc WHERE (cct1.id = cc.subject_id));

CREATE OR REPLACE TEMP VIEW ya_30b_rewriteYa1002_down_cct2 AS
SELECT cct2.*
FROM ya_30b_rewriteYa1002_up_cct2 AS cct2
WHERE EXISTS (SELECT 1 FROM ya_30b_rewriteYa1002_down_cc AS cc WHERE (cct2.id = cc.status_id));

CREATE OR REPLACE TEMP VIEW ya_30b_rewriteYa1002_down_n AS
SELECT n.*
FROM ya_30b_rewriteYa1002_up_n AS n
WHERE EXISTS (SELECT 1 FROM ya_30b_rewriteYa1002_down_ci AS ci WHERE (n.id = ci.person_id));

CREATE OR REPLACE TEMP VIEW ya_30b_rewriteYa1002_r3_base_cc AS
SELECT cc.movie_id AS cc__movie_id,
       cc.subject_id AS cc__subject_id,
       cc.status_id AS cc__status_id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_30b_rewriteYa1002_down_cc AS cc
GROUP BY cc.movie_id, cc.subject_id, cc.status_id;

CREATE OR REPLACE TEMP VIEW ya_30b_rewriteYa1002_r3_base_cct1 AS
SELECT cct1.id AS cct1__id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_30b_rewriteYa1002_down_cct1 AS cct1
GROUP BY cct1.id;

CREATE OR REPLACE TEMP VIEW ya_30b_rewriteYa1002_r3_base_cct2 AS
SELECT cct2.id AS cct2__id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_30b_rewriteYa1002_down_cct2 AS cct2
GROUP BY cct2.id;

CREATE OR REPLACE TEMP VIEW ya_30b_rewriteYa1002_r3_base_ci AS
SELECT ci.movie_id AS ci__movie_id,
       ci.person_id AS ci__person_id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_30b_rewriteYa1002_down_ci AS ci
GROUP BY ci.movie_id, ci.person_id;

CREATE OR REPLACE TEMP VIEW ya_30b_rewriteYa1002_r3_base_it1 AS
SELECT it1.id AS it1__id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_30b_rewriteYa1002_down_it1 AS it1
GROUP BY it1.id;

CREATE OR REPLACE TEMP VIEW ya_30b_rewriteYa1002_r3_base_it2 AS
SELECT it2.id AS it2__id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_30b_rewriteYa1002_down_it2 AS it2
GROUP BY it2.id;

CREATE OR REPLACE TEMP VIEW ya_30b_rewriteYa1002_r3_base_k AS
SELECT k.id AS k__id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_30b_rewriteYa1002_down_k AS k
GROUP BY k.id;

CREATE OR REPLACE TEMP VIEW ya_30b_rewriteYa1002_r3_base_mi AS
SELECT mi.movie_id AS mi__movie_id,
       mi.info_type_id AS mi__info_type_id,
       mi.info AS mi__info,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_30b_rewriteYa1002_down_mi AS mi
GROUP BY mi.movie_id, mi.info_type_id, mi.info;

CREATE OR REPLACE TEMP VIEW ya_30b_rewriteYa1002_r3_base_mi_idx AS
SELECT mi_idx.movie_id AS mi_idx__movie_id,
       mi_idx.info_type_id AS mi_idx__info_type_id,
       mi_idx.info AS mi_idx__info,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_30b_rewriteYa1002_down_mi_idx AS mi_idx
GROUP BY mi_idx.movie_id, mi_idx.info_type_id, mi_idx.info;

CREATE OR REPLACE TEMP VIEW ya_30b_rewriteYa1002_r3_base_mk AS
SELECT mk.movie_id AS mk__movie_id,
       mk.keyword_id AS mk__keyword_id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_30b_rewriteYa1002_down_mk AS mk
GROUP BY mk.movie_id, mk.keyword_id;

CREATE OR REPLACE TEMP VIEW ya_30b_rewriteYa1002_r3_base_n AS
SELECT n.id AS n__id,
       n.name AS n__name,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_30b_rewriteYa1002_down_n AS n
GROUP BY n.id, n.name;

CREATE OR REPLACE TEMP VIEW ya_30b_rewriteYa1002_r3_base_t AS
SELECT t.id AS t__id,
       t.title AS t__title,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_30b_rewriteYa1002_down_t AS t
GROUP BY t.id, t.title;

CREATE OR REPLACE TEMP VIEW ya_30b_rewriteYa1002_r3_join_1 AS
SELECT round3_left.mi__info AS mi__info,
       round3_left.mi__movie_id AS mi__movie_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_30b_rewriteYa1002_r3_base_mi AS round3_left
JOIN ya_30b_rewriteYa1002_r3_base_it1 AS round3_right
  ON (round3_right.it1__id = round3_left.mi__info_type_id)
GROUP BY round3_left.mi__info, round3_left.mi__movie_id;

CREATE OR REPLACE TEMP VIEW ya_30b_rewriteYa1002_r3_join_2 AS
SELECT round3_right.mi__info AS mi__info,
       round3_right.mi__movie_id AS mi__movie_id,
       round3_left.mk__movie_id AS mk__movie_id,
       round3_left.mk__keyword_id AS mk__keyword_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_30b_rewriteYa1002_r3_base_mk AS round3_left
JOIN ya_30b_rewriteYa1002_r3_join_1 AS round3_right
  ON (round3_right.mi__movie_id = round3_left.mk__movie_id)
GROUP BY round3_right.mi__info, round3_right.mi__movie_id, round3_left.mk__movie_id, round3_left.mk__keyword_id;

CREATE OR REPLACE TEMP VIEW ya_30b_rewriteYa1002_r3_join_3 AS
SELECT round3_left.mi_idx__info AS mi_idx__info,
       round3_left.mi_idx__movie_id AS mi_idx__movie_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_30b_rewriteYa1002_r3_base_mi_idx AS round3_left
JOIN ya_30b_rewriteYa1002_r3_base_it2 AS round3_right
  ON (round3_right.it2__id = round3_left.mi_idx__info_type_id)
GROUP BY round3_left.mi_idx__info, round3_left.mi_idx__movie_id;

CREATE OR REPLACE TEMP VIEW ya_30b_rewriteYa1002_r3_join_4 AS
SELECT round3_left.mi__info AS mi__info,
       round3_right.mi_idx__info AS mi_idx__info,
       round3_left.mi__movie_id AS mi__movie_id,
       round3_right.mi_idx__movie_id AS mi_idx__movie_id,
       round3_left.mk__movie_id AS mk__movie_id,
       round3_left.mk__keyword_id AS mk__keyword_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_30b_rewriteYa1002_r3_join_2 AS round3_left
JOIN ya_30b_rewriteYa1002_r3_join_3 AS round3_right
  ON (round3_left.mi__movie_id = round3_right.mi_idx__movie_id)
 AND (round3_right.mi_idx__movie_id = round3_left.mk__movie_id)
GROUP BY round3_left.mi__info, round3_right.mi_idx__info, round3_left.mi__movie_id, round3_right.mi_idx__movie_id, round3_left.mk__movie_id, round3_left.mk__keyword_id;

CREATE OR REPLACE TEMP VIEW ya_30b_rewriteYa1002_r3_join_5 AS
SELECT round3_left.mi__info AS mi__info,
       round3_left.mi_idx__info AS mi_idx__info,
       round3_right.t__title AS t__title,
       round3_right.t__id AS t__id,
       round3_left.mi__movie_id AS mi__movie_id,
       round3_left.mi_idx__movie_id AS mi_idx__movie_id,
       round3_left.mk__movie_id AS mk__movie_id,
       round3_left.mk__keyword_id AS mk__keyword_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_30b_rewriteYa1002_r3_join_4 AS round3_left
JOIN ya_30b_rewriteYa1002_r3_base_t AS round3_right
  ON (round3_right.t__id = round3_left.mi__movie_id)
 AND (round3_right.t__id = round3_left.mi_idx__movie_id)
 AND (round3_right.t__id = round3_left.mk__movie_id)
GROUP BY round3_left.mi__info, round3_left.mi_idx__info, round3_right.t__title, round3_right.t__id, round3_left.mi__movie_id, round3_left.mi_idx__movie_id, round3_left.mk__movie_id, round3_left.mk__keyword_id;

CREATE OR REPLACE TEMP VIEW ya_30b_rewriteYa1002_r3_join_6 AS
SELECT round3_left.cc__movie_id AS cc__movie_id,
       round3_left.cc__status_id AS cc__status_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_30b_rewriteYa1002_r3_base_cc AS round3_left
JOIN ya_30b_rewriteYa1002_r3_base_cct1 AS round3_right
  ON (round3_right.cct1__id = round3_left.cc__subject_id)
GROUP BY round3_left.cc__movie_id, round3_left.cc__status_id;

CREATE OR REPLACE TEMP VIEW ya_30b_rewriteYa1002_r3_join_7 AS
SELECT round3_left.cc__movie_id AS cc__movie_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_30b_rewriteYa1002_r3_join_6 AS round3_left
JOIN ya_30b_rewriteYa1002_r3_base_cct2 AS round3_right
  ON (round3_right.cct2__id = round3_left.cc__status_id)
GROUP BY round3_left.cc__movie_id;

CREATE OR REPLACE TEMP VIEW ya_30b_rewriteYa1002_r3_join_8 AS
SELECT round3_left.mi__info AS mi__info,
       round3_left.mi_idx__info AS mi_idx__info,
       round3_left.t__title AS t__title,
       round3_left.t__id AS t__id,
       round3_left.mi__movie_id AS mi__movie_id,
       round3_left.mi_idx__movie_id AS mi_idx__movie_id,
       round3_left.mk__movie_id AS mk__movie_id,
       round3_right.cc__movie_id AS cc__movie_id,
       round3_left.mk__keyword_id AS mk__keyword_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_30b_rewriteYa1002_r3_join_5 AS round3_left
JOIN ya_30b_rewriteYa1002_r3_join_7 AS round3_right
  ON (round3_left.t__id = round3_right.cc__movie_id)
 AND (round3_left.mi__movie_id = round3_right.cc__movie_id)
 AND (round3_left.mi_idx__movie_id = round3_right.cc__movie_id)
 AND (round3_left.mk__movie_id = round3_right.cc__movie_id)
GROUP BY round3_left.mi__info, round3_left.mi_idx__info, round3_left.t__title, round3_left.t__id, round3_left.mi__movie_id, round3_left.mi_idx__movie_id, round3_left.mk__movie_id, round3_right.cc__movie_id, round3_left.mk__keyword_id;

CREATE OR REPLACE TEMP VIEW ya_30b_rewriteYa1002_r3_join_9 AS
SELECT round3_right.n__name AS n__name,
       round3_left.ci__movie_id AS ci__movie_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_30b_rewriteYa1002_r3_base_ci AS round3_left
JOIN ya_30b_rewriteYa1002_r3_base_n AS round3_right
  ON (round3_right.n__id = round3_left.ci__person_id)
GROUP BY round3_right.n__name, round3_left.ci__movie_id;

CREATE OR REPLACE TEMP VIEW ya_30b_rewriteYa1002_r3_join_10 AS
SELECT round3_left.mi__info AS mi__info,
       round3_left.mi_idx__info AS mi_idx__info,
       round3_right.n__name AS n__name,
       round3_left.t__title AS t__title,
       round3_left.mk__keyword_id AS mk__keyword_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_30b_rewriteYa1002_r3_join_8 AS round3_left
JOIN ya_30b_rewriteYa1002_r3_join_9 AS round3_right
  ON (round3_left.t__id = round3_right.ci__movie_id)
 AND (round3_right.ci__movie_id = round3_left.mi__movie_id)
 AND (round3_right.ci__movie_id = round3_left.mi_idx__movie_id)
 AND (round3_right.ci__movie_id = round3_left.mk__movie_id)
 AND (round3_right.ci__movie_id = round3_left.cc__movie_id)
GROUP BY round3_left.mi__info, round3_left.mi_idx__info, round3_right.n__name, round3_left.t__title, round3_left.mk__keyword_id;

CREATE OR REPLACE TEMP VIEW ya_30b_rewriteYa1002_r3_join_11 AS
SELECT round3_right.mi__info AS mi__info,
       round3_right.mi_idx__info AS mi_idx__info,
       round3_right.n__name AS n__name,
       round3_right.t__title AS t__title,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_30b_rewriteYa1002_r3_base_k AS round3_left
JOIN ya_30b_rewriteYa1002_r3_join_10 AS round3_right
  ON (round3_left.k__id = round3_right.mk__keyword_id)
GROUP BY round3_right.mi__info, round3_right.mi_idx__info, round3_right.n__name, round3_right.t__title;

SELECT round3_result.mi__info AS info,
       round3_result.mi_idx__info AS info,
       round3_result.n__name AS name,
       round3_result.t__title AS title,
       round3_result.annot AS record_count
FROM ya_30b_rewriteYa1002_r3_join_11 AS round3_result;
