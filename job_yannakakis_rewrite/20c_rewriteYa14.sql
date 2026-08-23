-- DuckDB SUM(1) Yannakakis-style two-pass reducer generated from job_agg/20c.sql.

-- Source variant: query/job_duckdb/20c/rewriteYa14.sql

CREATE OR REPLACE TEMP VIEW ya_20c_rewriteYa14_base_cc AS
SELECT cc.*
FROM complete_cast AS cc;

CREATE OR REPLACE TEMP VIEW ya_20c_rewriteYa14_base_cct1 AS
SELECT cct1.*
FROM comp_cast_type AS cct1
WHERE (cct1.kind = 'cast');

CREATE OR REPLACE TEMP VIEW ya_20c_rewriteYa14_base_cct2 AS
SELECT cct2.*
FROM comp_cast_type AS cct2
WHERE (cct2.kind LIKE '%complete%');

CREATE OR REPLACE TEMP VIEW ya_20c_rewriteYa14_base_chn AS
SELECT chn.*
FROM char_name AS chn
WHERE (chn.name IS NOT NULL)
  AND ((chn.name LIKE '%man%'
       OR chn.name LIKE '%Man%'));

CREATE OR REPLACE TEMP VIEW ya_20c_rewriteYa14_base_ci AS
SELECT ci.*
FROM cast_info AS ci;

CREATE OR REPLACE TEMP VIEW ya_20c_rewriteYa14_base_k AS
SELECT k.*
FROM keyword AS k
WHERE (k.keyword IN ('superhero',
                    'marvel-comics',
                    'based-on-comic',
                    'tv-special',
                    'fight',
                    'violence',
                    'magnet',
                    'web',
                    'claw',
                    'laser'));

CREATE OR REPLACE TEMP VIEW ya_20c_rewriteYa14_base_kt AS
SELECT kt.*
FROM kind_type AS kt
WHERE (kt.kind = 'movie');

CREATE OR REPLACE TEMP VIEW ya_20c_rewriteYa14_base_mk AS
SELECT mk.*
FROM movie_keyword AS mk;

CREATE OR REPLACE TEMP VIEW ya_20c_rewriteYa14_base_n AS
SELECT n.*
FROM name AS n;

CREATE OR REPLACE TEMP VIEW ya_20c_rewriteYa14_base_t AS
SELECT t.*
FROM title AS t
WHERE (t.production_year > 2000);

CREATE OR REPLACE TEMP VIEW ya_20c_rewriteYa14_up_cct1 AS
SELECT cct1.*
FROM ya_20c_rewriteYa14_base_cct1 AS cct1;

CREATE OR REPLACE TEMP VIEW ya_20c_rewriteYa14_up_cct2 AS
SELECT cct2.*
FROM ya_20c_rewriteYa14_base_cct2 AS cct2;

CREATE OR REPLACE TEMP VIEW ya_20c_rewriteYa14_up_cc AS
SELECT cc.*
FROM ya_20c_rewriteYa14_base_cc AS cc
WHERE EXISTS (SELECT 1 FROM ya_20c_rewriteYa14_up_cct1 AS cct1 WHERE (cct1.id = cc.subject_id))
  AND EXISTS (SELECT 1 FROM ya_20c_rewriteYa14_up_cct2 AS cct2 WHERE (cct2.id = cc.status_id));

CREATE OR REPLACE TEMP VIEW ya_20c_rewriteYa14_up_chn AS
SELECT chn.*
FROM ya_20c_rewriteYa14_base_chn AS chn;

CREATE OR REPLACE TEMP VIEW ya_20c_rewriteYa14_up_k AS
SELECT k.*
FROM ya_20c_rewriteYa14_base_k AS k;

CREATE OR REPLACE TEMP VIEW ya_20c_rewriteYa14_up_mk AS
SELECT mk.*
FROM ya_20c_rewriteYa14_base_mk AS mk
WHERE EXISTS (SELECT 1 FROM ya_20c_rewriteYa14_up_k AS k WHERE (k.id = mk.keyword_id));

CREATE OR REPLACE TEMP VIEW ya_20c_rewriteYa14_up_n AS
SELECT n.*
FROM ya_20c_rewriteYa14_base_n AS n;

CREATE OR REPLACE TEMP VIEW ya_20c_rewriteYa14_up_kt AS
SELECT kt.*
FROM ya_20c_rewriteYa14_base_kt AS kt;

CREATE OR REPLACE TEMP VIEW ya_20c_rewriteYa14_up_t AS
SELECT t.*
FROM ya_20c_rewriteYa14_base_t AS t
WHERE EXISTS (SELECT 1 FROM ya_20c_rewriteYa14_up_kt AS kt WHERE (kt.id = t.kind_id));

CREATE OR REPLACE TEMP VIEW ya_20c_rewriteYa14_up_ci AS
SELECT ci.*
FROM ya_20c_rewriteYa14_base_ci AS ci
WHERE EXISTS (SELECT 1 FROM ya_20c_rewriteYa14_up_cc AS cc WHERE (ci.movie_id = cc.movie_id))
  AND EXISTS (SELECT 1 FROM ya_20c_rewriteYa14_up_chn AS chn WHERE (chn.id = ci.person_role_id))
  AND EXISTS (SELECT 1 FROM ya_20c_rewriteYa14_up_mk AS mk WHERE (mk.movie_id = ci.movie_id))
  AND EXISTS (SELECT 1 FROM ya_20c_rewriteYa14_up_n AS n WHERE (n.id = ci.person_id))
  AND EXISTS (SELECT 1 FROM ya_20c_rewriteYa14_up_t AS t WHERE (t.id = ci.movie_id));

CREATE OR REPLACE TEMP VIEW ya_20c_rewriteYa14_down_ci AS
SELECT ci.*
FROM ya_20c_rewriteYa14_up_ci AS ci;

CREATE OR REPLACE TEMP VIEW ya_20c_rewriteYa14_down_cc AS
SELECT cc.*
FROM ya_20c_rewriteYa14_up_cc AS cc
WHERE EXISTS (SELECT 1 FROM ya_20c_rewriteYa14_down_ci AS ci WHERE (ci.movie_id = cc.movie_id));

CREATE OR REPLACE TEMP VIEW ya_20c_rewriteYa14_down_chn AS
SELECT chn.*
FROM ya_20c_rewriteYa14_up_chn AS chn
WHERE EXISTS (SELECT 1 FROM ya_20c_rewriteYa14_down_ci AS ci WHERE (chn.id = ci.person_role_id));

CREATE OR REPLACE TEMP VIEW ya_20c_rewriteYa14_down_mk AS
SELECT mk.*
FROM ya_20c_rewriteYa14_up_mk AS mk
WHERE EXISTS (SELECT 1 FROM ya_20c_rewriteYa14_down_ci AS ci WHERE (mk.movie_id = ci.movie_id));

CREATE OR REPLACE TEMP VIEW ya_20c_rewriteYa14_down_n AS
SELECT n.*
FROM ya_20c_rewriteYa14_up_n AS n
WHERE EXISTS (SELECT 1 FROM ya_20c_rewriteYa14_down_ci AS ci WHERE (n.id = ci.person_id));

CREATE OR REPLACE TEMP VIEW ya_20c_rewriteYa14_down_t AS
SELECT t.*
FROM ya_20c_rewriteYa14_up_t AS t
WHERE EXISTS (SELECT 1 FROM ya_20c_rewriteYa14_down_ci AS ci WHERE (t.id = ci.movie_id));

CREATE OR REPLACE TEMP VIEW ya_20c_rewriteYa14_down_cct1 AS
SELECT cct1.*
FROM ya_20c_rewriteYa14_up_cct1 AS cct1
WHERE EXISTS (SELECT 1 FROM ya_20c_rewriteYa14_down_cc AS cc WHERE (cct1.id = cc.subject_id));

CREATE OR REPLACE TEMP VIEW ya_20c_rewriteYa14_down_cct2 AS
SELECT cct2.*
FROM ya_20c_rewriteYa14_up_cct2 AS cct2
WHERE EXISTS (SELECT 1 FROM ya_20c_rewriteYa14_down_cc AS cc WHERE (cct2.id = cc.status_id));

CREATE OR REPLACE TEMP VIEW ya_20c_rewriteYa14_down_k AS
SELECT k.*
FROM ya_20c_rewriteYa14_up_k AS k
WHERE EXISTS (SELECT 1 FROM ya_20c_rewriteYa14_down_mk AS mk WHERE (k.id = mk.keyword_id));

CREATE OR REPLACE TEMP VIEW ya_20c_rewriteYa14_down_kt AS
SELECT kt.*
FROM ya_20c_rewriteYa14_up_kt AS kt
WHERE EXISTS (SELECT 1 FROM ya_20c_rewriteYa14_down_t AS t WHERE (kt.id = t.kind_id));

CREATE OR REPLACE TEMP VIEW ya_20c_rewriteYa14_r3_base_cc AS
SELECT cc.movie_id AS cc__movie_id,
       cc.subject_id AS cc__subject_id,
       cc.status_id AS cc__status_id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_20c_rewriteYa14_down_cc AS cc
GROUP BY cc.movie_id, cc.subject_id, cc.status_id;

CREATE OR REPLACE TEMP VIEW ya_20c_rewriteYa14_r3_base_cct1 AS
SELECT cct1.id AS cct1__id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_20c_rewriteYa14_down_cct1 AS cct1
GROUP BY cct1.id;

CREATE OR REPLACE TEMP VIEW ya_20c_rewriteYa14_r3_base_cct2 AS
SELECT cct2.id AS cct2__id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_20c_rewriteYa14_down_cct2 AS cct2
GROUP BY cct2.id;

CREATE OR REPLACE TEMP VIEW ya_20c_rewriteYa14_r3_base_chn AS
SELECT chn.id AS chn__id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_20c_rewriteYa14_down_chn AS chn
GROUP BY chn.id;

CREATE OR REPLACE TEMP VIEW ya_20c_rewriteYa14_r3_base_ci AS
SELECT ci.movie_id AS ci__movie_id,
       ci.person_role_id AS ci__person_role_id,
       ci.person_id AS ci__person_id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_20c_rewriteYa14_down_ci AS ci
GROUP BY ci.movie_id, ci.person_role_id, ci.person_id;

CREATE OR REPLACE TEMP VIEW ya_20c_rewriteYa14_r3_base_k AS
SELECT k.id AS k__id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_20c_rewriteYa14_down_k AS k
GROUP BY k.id;

CREATE OR REPLACE TEMP VIEW ya_20c_rewriteYa14_r3_base_kt AS
SELECT kt.id AS kt__id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_20c_rewriteYa14_down_kt AS kt
GROUP BY kt.id;

CREATE OR REPLACE TEMP VIEW ya_20c_rewriteYa14_r3_base_mk AS
SELECT mk.movie_id AS mk__movie_id,
       mk.keyword_id AS mk__keyword_id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_20c_rewriteYa14_down_mk AS mk
GROUP BY mk.movie_id, mk.keyword_id;

CREATE OR REPLACE TEMP VIEW ya_20c_rewriteYa14_r3_base_n AS
SELECT n.id AS n__id,
       n.name AS n__name,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_20c_rewriteYa14_down_n AS n
GROUP BY n.id, n.name;

CREATE OR REPLACE TEMP VIEW ya_20c_rewriteYa14_r3_base_t AS
SELECT t.kind_id AS t__kind_id,
       t.id AS t__id,
       t.title AS t__title,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_20c_rewriteYa14_down_t AS t
GROUP BY t.kind_id, t.id, t.title;

CREATE OR REPLACE TEMP VIEW ya_20c_rewriteYa14_r3_join_1 AS
SELECT round3_left.cc__movie_id AS cc__movie_id,
       round3_left.cc__status_id AS cc__status_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_20c_rewriteYa14_r3_base_cc AS round3_left
JOIN ya_20c_rewriteYa14_r3_base_cct1 AS round3_right
  ON (round3_right.cct1__id = round3_left.cc__subject_id)
GROUP BY round3_left.cc__movie_id, round3_left.cc__status_id;

CREATE OR REPLACE TEMP VIEW ya_20c_rewriteYa14_r3_join_2 AS
SELECT round3_left.cc__movie_id AS cc__movie_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_20c_rewriteYa14_r3_join_1 AS round3_left
JOIN ya_20c_rewriteYa14_r3_base_cct2 AS round3_right
  ON (round3_right.cct2__id = round3_left.cc__status_id)
GROUP BY round3_left.cc__movie_id;

CREATE OR REPLACE TEMP VIEW ya_20c_rewriteYa14_r3_join_3 AS
SELECT round3_left.ci__movie_id AS ci__movie_id,
       round3_right.cc__movie_id AS cc__movie_id,
       round3_left.ci__person_role_id AS ci__person_role_id,
       round3_left.ci__person_id AS ci__person_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_20c_rewriteYa14_r3_base_ci AS round3_left
JOIN ya_20c_rewriteYa14_r3_join_2 AS round3_right
  ON (round3_left.ci__movie_id = round3_right.cc__movie_id)
GROUP BY round3_left.ci__movie_id, round3_right.cc__movie_id, round3_left.ci__person_role_id, round3_left.ci__person_id;

CREATE OR REPLACE TEMP VIEW ya_20c_rewriteYa14_r3_join_4 AS
SELECT round3_left.ci__movie_id AS ci__movie_id,
       round3_left.cc__movie_id AS cc__movie_id,
       round3_left.ci__person_id AS ci__person_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_20c_rewriteYa14_r3_join_3 AS round3_left
JOIN ya_20c_rewriteYa14_r3_base_chn AS round3_right
  ON (round3_right.chn__id = round3_left.ci__person_role_id)
GROUP BY round3_left.ci__movie_id, round3_left.cc__movie_id, round3_left.ci__person_id;

CREATE OR REPLACE TEMP VIEW ya_20c_rewriteYa14_r3_join_5 AS
SELECT round3_left.mk__movie_id AS mk__movie_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_20c_rewriteYa14_r3_base_mk AS round3_left
JOIN ya_20c_rewriteYa14_r3_base_k AS round3_right
  ON (round3_right.k__id = round3_left.mk__keyword_id)
GROUP BY round3_left.mk__movie_id;

CREATE OR REPLACE TEMP VIEW ya_20c_rewriteYa14_r3_join_6 AS
SELECT round3_right.mk__movie_id AS mk__movie_id,
       round3_left.ci__movie_id AS ci__movie_id,
       round3_left.cc__movie_id AS cc__movie_id,
       round3_left.ci__person_id AS ci__person_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_20c_rewriteYa14_r3_join_4 AS round3_left
JOIN ya_20c_rewriteYa14_r3_join_5 AS round3_right
  ON (round3_right.mk__movie_id = round3_left.ci__movie_id)
 AND (round3_right.mk__movie_id = round3_left.cc__movie_id)
GROUP BY round3_right.mk__movie_id, round3_left.ci__movie_id, round3_left.cc__movie_id, round3_left.ci__person_id;

CREATE OR REPLACE TEMP VIEW ya_20c_rewriteYa14_r3_join_7 AS
SELECT round3_right.n__name AS n__name,
       round3_left.mk__movie_id AS mk__movie_id,
       round3_left.ci__movie_id AS ci__movie_id,
       round3_left.cc__movie_id AS cc__movie_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_20c_rewriteYa14_r3_join_6 AS round3_left
JOIN ya_20c_rewriteYa14_r3_base_n AS round3_right
  ON (round3_right.n__id = round3_left.ci__person_id)
GROUP BY round3_right.n__name, round3_left.mk__movie_id, round3_left.ci__movie_id, round3_left.cc__movie_id;

CREATE OR REPLACE TEMP VIEW ya_20c_rewriteYa14_r3_join_8 AS
SELECT round3_left.t__title AS t__title,
       round3_left.t__id AS t__id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_20c_rewriteYa14_r3_base_t AS round3_left
JOIN ya_20c_rewriteYa14_r3_base_kt AS round3_right
  ON (round3_right.kt__id = round3_left.t__kind_id)
GROUP BY round3_left.t__title, round3_left.t__id;

CREATE OR REPLACE TEMP VIEW ya_20c_rewriteYa14_r3_join_9 AS
SELECT round3_left.n__name AS n__name,
       round3_right.t__title AS t__title,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_20c_rewriteYa14_r3_join_7 AS round3_left
JOIN ya_20c_rewriteYa14_r3_join_8 AS round3_right
  ON (round3_right.t__id = round3_left.mk__movie_id)
 AND (round3_right.t__id = round3_left.ci__movie_id)
 AND (round3_right.t__id = round3_left.cc__movie_id)
GROUP BY round3_left.n__name, round3_right.t__title;

SELECT round3_result.n__name AS name,
       round3_result.t__title AS title,
       round3_result.annot AS record_count
FROM ya_20c_rewriteYa14_r3_join_9 AS round3_result;
