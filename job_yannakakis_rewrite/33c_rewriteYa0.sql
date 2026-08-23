-- DuckDB SUM(1) Yannakakis-style two-pass reducer generated from job_agg/33c.sql.

-- Source variant: query/job_duckdb/33c/rewriteYa0.sql

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_base_cn1 AS
SELECT cn1.*
FROM company_name AS cn1
WHERE (cn1.country_code != '[us]');

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_base_cn2 AS
SELECT cn2.*
FROM company_name AS cn2;

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_base_it1 AS
SELECT it1.*
FROM info_type AS it1
WHERE (it1.info = 'rating');

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_base_it2 AS
SELECT it2.*
FROM info_type AS it2
WHERE (it2.info = 'rating');

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_base_kt1 AS
SELECT kt1.*
FROM kind_type AS kt1
WHERE (kt1.kind IN ('tv series',
                   'episode'));

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_base_kt2 AS
SELECT kt2.*
FROM kind_type AS kt2
WHERE (kt2.kind IN ('tv series',
                   'episode'));

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_base_lt AS
SELECT lt.*
FROM link_type AS lt
WHERE (lt.link IN ('sequel',
                  'follows',
                  'followed by'));

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_base_mc1 AS
SELECT mc1.*
FROM movie_companies AS mc1;

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_base_mc2 AS
SELECT mc2.*
FROM movie_companies AS mc2;

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_base_mi_idx1 AS
SELECT mi_idx1.*
FROM movie_info_idx AS mi_idx1;

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_base_mi_idx2 AS
SELECT mi_idx2.*
FROM movie_info_idx AS mi_idx2
WHERE (mi_idx2.info < '3.5');

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_base_ml AS
SELECT ml.*
FROM movie_link AS ml;

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_base_t1 AS
SELECT t1.*
FROM title AS t1;

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_base_t2 AS
SELECT t2.*
FROM title AS t2
WHERE (t2.production_year BETWEEN 2000 AND 2010);

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_up_kt2 AS
SELECT kt2.*
FROM ya_33c_rewriteYa0_base_kt2 AS kt2;

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_up_t2 AS
SELECT t2.*
FROM ya_33c_rewriteYa0_base_t2 AS t2
WHERE EXISTS (SELECT 1 FROM ya_33c_rewriteYa0_up_kt2 AS kt2 WHERE (kt2.id = t2.kind_id));

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_up_lt AS
SELECT lt.*
FROM ya_33c_rewriteYa0_base_lt AS lt;

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_up_cn2 AS
SELECT cn2.*
FROM ya_33c_rewriteYa0_base_cn2 AS cn2;

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_up_mc2 AS
SELECT mc2.*
FROM ya_33c_rewriteYa0_base_mc2 AS mc2
WHERE EXISTS (SELECT 1 FROM ya_33c_rewriteYa0_up_cn2 AS cn2 WHERE (cn2.id = mc2.company_id));

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_up_it2 AS
SELECT it2.*
FROM ya_33c_rewriteYa0_base_it2 AS it2;

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_up_mi_idx2 AS
SELECT mi_idx2.*
FROM ya_33c_rewriteYa0_base_mi_idx2 AS mi_idx2
WHERE EXISTS (SELECT 1 FROM ya_33c_rewriteYa0_up_it2 AS it2 WHERE (it2.id = mi_idx2.info_type_id));

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_up_ml AS
SELECT ml.*
FROM ya_33c_rewriteYa0_base_ml AS ml
WHERE EXISTS (SELECT 1 FROM ya_33c_rewriteYa0_up_t2 AS t2 WHERE (t2.id = ml.linked_movie_id))
  AND EXISTS (SELECT 1 FROM ya_33c_rewriteYa0_up_lt AS lt WHERE (lt.id = ml.link_type_id))
  AND EXISTS (SELECT 1 FROM ya_33c_rewriteYa0_up_mc2 AS mc2 WHERE (ml.linked_movie_id = mc2.movie_id))
  AND EXISTS (SELECT 1 FROM ya_33c_rewriteYa0_up_mi_idx2 AS mi_idx2 WHERE (ml.linked_movie_id = mi_idx2.movie_id));

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_up_kt1 AS
SELECT kt1.*
FROM ya_33c_rewriteYa0_base_kt1 AS kt1;

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_up_t1 AS
SELECT t1.*
FROM ya_33c_rewriteYa0_base_t1 AS t1
WHERE EXISTS (SELECT 1 FROM ya_33c_rewriteYa0_up_kt1 AS kt1 WHERE (kt1.id = t1.kind_id));

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_up_it1 AS
SELECT it1.*
FROM ya_33c_rewriteYa0_base_it1 AS it1;

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_up_mi_idx1 AS
SELECT mi_idx1.*
FROM ya_33c_rewriteYa0_base_mi_idx1 AS mi_idx1
WHERE EXISTS (SELECT 1 FROM ya_33c_rewriteYa0_up_it1 AS it1 WHERE (it1.id = mi_idx1.info_type_id));

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_up_mc1 AS
SELECT mc1.*
FROM ya_33c_rewriteYa0_base_mc1 AS mc1
WHERE EXISTS (SELECT 1 FROM ya_33c_rewriteYa0_up_ml AS ml WHERE (ml.movie_id = mc1.movie_id))
  AND EXISTS (SELECT 1 FROM ya_33c_rewriteYa0_up_t1 AS t1 WHERE (t1.id = mc1.movie_id))
  AND EXISTS (SELECT 1 FROM ya_33c_rewriteYa0_up_mi_idx1 AS mi_idx1 WHERE (mi_idx1.movie_id = mc1.movie_id));

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_up_cn1 AS
SELECT cn1.*
FROM ya_33c_rewriteYa0_base_cn1 AS cn1
WHERE EXISTS (SELECT 1 FROM ya_33c_rewriteYa0_up_mc1 AS mc1 WHERE (cn1.id = mc1.company_id));

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_down_cn1 AS
SELECT cn1.*
FROM ya_33c_rewriteYa0_up_cn1 AS cn1;

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_down_mc1 AS
SELECT mc1.*
FROM ya_33c_rewriteYa0_up_mc1 AS mc1
WHERE EXISTS (SELECT 1 FROM ya_33c_rewriteYa0_down_cn1 AS cn1 WHERE (cn1.id = mc1.company_id));

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_down_ml AS
SELECT ml.*
FROM ya_33c_rewriteYa0_up_ml AS ml
WHERE EXISTS (SELECT 1 FROM ya_33c_rewriteYa0_down_mc1 AS mc1 WHERE (ml.movie_id = mc1.movie_id));

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_down_t1 AS
SELECT t1.*
FROM ya_33c_rewriteYa0_up_t1 AS t1
WHERE EXISTS (SELECT 1 FROM ya_33c_rewriteYa0_down_mc1 AS mc1 WHERE (t1.id = mc1.movie_id));

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_down_mi_idx1 AS
SELECT mi_idx1.*
FROM ya_33c_rewriteYa0_up_mi_idx1 AS mi_idx1
WHERE EXISTS (SELECT 1 FROM ya_33c_rewriteYa0_down_mc1 AS mc1 WHERE (mi_idx1.movie_id = mc1.movie_id));

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_down_t2 AS
SELECT t2.*
FROM ya_33c_rewriteYa0_up_t2 AS t2
WHERE EXISTS (SELECT 1 FROM ya_33c_rewriteYa0_down_ml AS ml WHERE (t2.id = ml.linked_movie_id));

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_down_lt AS
SELECT lt.*
FROM ya_33c_rewriteYa0_up_lt AS lt
WHERE EXISTS (SELECT 1 FROM ya_33c_rewriteYa0_down_ml AS ml WHERE (lt.id = ml.link_type_id));

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_down_mc2 AS
SELECT mc2.*
FROM ya_33c_rewriteYa0_up_mc2 AS mc2
WHERE EXISTS (SELECT 1 FROM ya_33c_rewriteYa0_down_ml AS ml WHERE (ml.linked_movie_id = mc2.movie_id));

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_down_mi_idx2 AS
SELECT mi_idx2.*
FROM ya_33c_rewriteYa0_up_mi_idx2 AS mi_idx2
WHERE EXISTS (SELECT 1 FROM ya_33c_rewriteYa0_down_ml AS ml WHERE (ml.linked_movie_id = mi_idx2.movie_id));

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_down_kt1 AS
SELECT kt1.*
FROM ya_33c_rewriteYa0_up_kt1 AS kt1
WHERE EXISTS (SELECT 1 FROM ya_33c_rewriteYa0_down_t1 AS t1 WHERE (kt1.id = t1.kind_id));

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_down_it1 AS
SELECT it1.*
FROM ya_33c_rewriteYa0_up_it1 AS it1
WHERE EXISTS (SELECT 1 FROM ya_33c_rewriteYa0_down_mi_idx1 AS mi_idx1 WHERE (it1.id = mi_idx1.info_type_id));

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_down_kt2 AS
SELECT kt2.*
FROM ya_33c_rewriteYa0_up_kt2 AS kt2
WHERE EXISTS (SELECT 1 FROM ya_33c_rewriteYa0_down_t2 AS t2 WHERE (kt2.id = t2.kind_id));

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_down_cn2 AS
SELECT cn2.*
FROM ya_33c_rewriteYa0_up_cn2 AS cn2
WHERE EXISTS (SELECT 1 FROM ya_33c_rewriteYa0_down_mc2 AS mc2 WHERE (cn2.id = mc2.company_id));

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_down_it2 AS
SELECT it2.*
FROM ya_33c_rewriteYa0_up_it2 AS it2
WHERE EXISTS (SELECT 1 FROM ya_33c_rewriteYa0_down_mi_idx2 AS mi_idx2 WHERE (it2.id = mi_idx2.info_type_id));

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_r3_base_cn1 AS
SELECT cn1.id AS cn1__id,
       cn1.name AS cn1__name,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_33c_rewriteYa0_down_cn1 AS cn1
GROUP BY cn1.id, cn1.name;

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_r3_base_cn2 AS
SELECT cn2.id AS cn2__id,
       cn2.name AS cn2__name,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_33c_rewriteYa0_down_cn2 AS cn2
GROUP BY cn2.id, cn2.name;

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_r3_base_it1 AS
SELECT it1.id AS it1__id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_33c_rewriteYa0_down_it1 AS it1
GROUP BY it1.id;

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_r3_base_it2 AS
SELECT it2.id AS it2__id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_33c_rewriteYa0_down_it2 AS it2
GROUP BY it2.id;

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_r3_base_kt1 AS
SELECT kt1.id AS kt1__id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_33c_rewriteYa0_down_kt1 AS kt1
GROUP BY kt1.id;

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_r3_base_kt2 AS
SELECT kt2.id AS kt2__id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_33c_rewriteYa0_down_kt2 AS kt2
GROUP BY kt2.id;

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_r3_base_lt AS
SELECT lt.id AS lt__id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_33c_rewriteYa0_down_lt AS lt
GROUP BY lt.id;

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_r3_base_mc1 AS
SELECT mc1.company_id AS mc1__company_id,
       mc1.movie_id AS mc1__movie_id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_33c_rewriteYa0_down_mc1 AS mc1
GROUP BY mc1.company_id, mc1.movie_id;

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_r3_base_mc2 AS
SELECT mc2.company_id AS mc2__company_id,
       mc2.movie_id AS mc2__movie_id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_33c_rewriteYa0_down_mc2 AS mc2
GROUP BY mc2.company_id, mc2.movie_id;

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_r3_base_mi_idx1 AS
SELECT mi_idx1.info_type_id AS mi_idx1__info_type_id,
       mi_idx1.movie_id AS mi_idx1__movie_id,
       mi_idx1.info AS mi_idx1__info,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_33c_rewriteYa0_down_mi_idx1 AS mi_idx1
GROUP BY mi_idx1.info_type_id, mi_idx1.movie_id, mi_idx1.info;

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_r3_base_mi_idx2 AS
SELECT mi_idx2.info_type_id AS mi_idx2__info_type_id,
       mi_idx2.movie_id AS mi_idx2__movie_id,
       mi_idx2.info AS mi_idx2__info,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_33c_rewriteYa0_down_mi_idx2 AS mi_idx2
GROUP BY mi_idx2.info_type_id, mi_idx2.movie_id, mi_idx2.info;

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_r3_base_ml AS
SELECT ml.link_type_id AS ml__link_type_id,
       ml.movie_id AS ml__movie_id,
       ml.linked_movie_id AS ml__linked_movie_id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_33c_rewriteYa0_down_ml AS ml
GROUP BY ml.link_type_id, ml.movie_id, ml.linked_movie_id;

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_r3_base_t1 AS
SELECT t1.id AS t1__id,
       t1.kind_id AS t1__kind_id,
       t1.title AS t1__title,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_33c_rewriteYa0_down_t1 AS t1
GROUP BY t1.id, t1.kind_id, t1.title;

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_r3_base_t2 AS
SELECT t2.id AS t2__id,
       t2.kind_id AS t2__kind_id,
       t2.title AS t2__title,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_33c_rewriteYa0_down_t2 AS t2
GROUP BY t2.id, t2.kind_id, t2.title;

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_r3_join_1 AS
SELECT round3_left.t2__title AS t2__title,
       round3_left.t2__id AS t2__id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_33c_rewriteYa0_r3_base_t2 AS round3_left
JOIN ya_33c_rewriteYa0_r3_base_kt2 AS round3_right
  ON (round3_right.kt2__id = round3_left.t2__kind_id)
GROUP BY round3_left.t2__title, round3_left.t2__id;

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_r3_join_2 AS
SELECT round3_right.t2__title AS t2__title,
       round3_left.ml__link_type_id AS ml__link_type_id,
       round3_left.ml__movie_id AS ml__movie_id,
       round3_right.t2__id AS t2__id,
       round3_left.ml__linked_movie_id AS ml__linked_movie_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_33c_rewriteYa0_r3_base_ml AS round3_left
JOIN ya_33c_rewriteYa0_r3_join_1 AS round3_right
  ON (round3_right.t2__id = round3_left.ml__linked_movie_id)
GROUP BY round3_right.t2__title, round3_left.ml__link_type_id, round3_left.ml__movie_id, round3_right.t2__id, round3_left.ml__linked_movie_id;

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_r3_join_3 AS
SELECT round3_left.t2__title AS t2__title,
       round3_left.ml__movie_id AS ml__movie_id,
       round3_left.t2__id AS t2__id,
       round3_left.ml__linked_movie_id AS ml__linked_movie_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_33c_rewriteYa0_r3_join_2 AS round3_left
JOIN ya_33c_rewriteYa0_r3_base_lt AS round3_right
  ON (round3_right.lt__id = round3_left.ml__link_type_id)
GROUP BY round3_left.t2__title, round3_left.ml__movie_id, round3_left.t2__id, round3_left.ml__linked_movie_id;

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_r3_join_4 AS
SELECT round3_right.cn2__name AS cn2__name,
       round3_left.mc2__movie_id AS mc2__movie_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_33c_rewriteYa0_r3_base_mc2 AS round3_left
JOIN ya_33c_rewriteYa0_r3_base_cn2 AS round3_right
  ON (round3_right.cn2__id = round3_left.mc2__company_id)
GROUP BY round3_right.cn2__name, round3_left.mc2__movie_id;

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_r3_join_5 AS
SELECT round3_right.cn2__name AS cn2__name,
       round3_left.t2__title AS t2__title,
       round3_left.ml__movie_id AS ml__movie_id,
       round3_left.t2__id AS t2__id,
       round3_left.ml__linked_movie_id AS ml__linked_movie_id,
       round3_right.mc2__movie_id AS mc2__movie_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_33c_rewriteYa0_r3_join_3 AS round3_left
JOIN ya_33c_rewriteYa0_r3_join_4 AS round3_right
  ON (round3_left.t2__id = round3_right.mc2__movie_id)
 AND (round3_left.ml__linked_movie_id = round3_right.mc2__movie_id)
GROUP BY round3_right.cn2__name, round3_left.t2__title, round3_left.ml__movie_id, round3_left.t2__id, round3_left.ml__linked_movie_id, round3_right.mc2__movie_id;

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_r3_join_6 AS
SELECT round3_left.mi_idx2__info AS mi_idx2__info,
       round3_left.mi_idx2__movie_id AS mi_idx2__movie_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_33c_rewriteYa0_r3_base_mi_idx2 AS round3_left
JOIN ya_33c_rewriteYa0_r3_base_it2 AS round3_right
  ON (round3_right.it2__id = round3_left.mi_idx2__info_type_id)
GROUP BY round3_left.mi_idx2__info, round3_left.mi_idx2__movie_id;

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_r3_join_7 AS
SELECT round3_left.cn2__name AS cn2__name,
       round3_right.mi_idx2__info AS mi_idx2__info,
       round3_left.t2__title AS t2__title,
       round3_left.ml__movie_id AS ml__movie_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_33c_rewriteYa0_r3_join_5 AS round3_left
JOIN ya_33c_rewriteYa0_r3_join_6 AS round3_right
  ON (round3_left.t2__id = round3_right.mi_idx2__movie_id)
 AND (round3_left.ml__linked_movie_id = round3_right.mi_idx2__movie_id)
 AND (round3_right.mi_idx2__movie_id = round3_left.mc2__movie_id)
GROUP BY round3_left.cn2__name, round3_right.mi_idx2__info, round3_left.t2__title, round3_left.ml__movie_id;

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_r3_join_8 AS
SELECT round3_right.cn2__name AS cn2__name,
       round3_right.mi_idx2__info AS mi_idx2__info,
       round3_right.t2__title AS t2__title,
       round3_right.ml__movie_id AS ml__movie_id,
       round3_left.mc1__company_id AS mc1__company_id,
       round3_left.mc1__movie_id AS mc1__movie_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_33c_rewriteYa0_r3_base_mc1 AS round3_left
JOIN ya_33c_rewriteYa0_r3_join_7 AS round3_right
  ON (round3_right.ml__movie_id = round3_left.mc1__movie_id)
GROUP BY round3_right.cn2__name, round3_right.mi_idx2__info, round3_right.t2__title, round3_right.ml__movie_id, round3_left.mc1__company_id, round3_left.mc1__movie_id;

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_r3_join_9 AS
SELECT round3_left.t1__title AS t1__title,
       round3_left.t1__id AS t1__id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_33c_rewriteYa0_r3_base_t1 AS round3_left
JOIN ya_33c_rewriteYa0_r3_base_kt1 AS round3_right
  ON (round3_right.kt1__id = round3_left.t1__kind_id)
GROUP BY round3_left.t1__title, round3_left.t1__id;

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_r3_join_10 AS
SELECT round3_left.cn2__name AS cn2__name,
       round3_left.mi_idx2__info AS mi_idx2__info,
       round3_right.t1__title AS t1__title,
       round3_left.t2__title AS t2__title,
       round3_right.t1__id AS t1__id,
       round3_left.mc1__company_id AS mc1__company_id,
       round3_left.ml__movie_id AS ml__movie_id,
       round3_left.mc1__movie_id AS mc1__movie_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_33c_rewriteYa0_r3_join_8 AS round3_left
JOIN ya_33c_rewriteYa0_r3_join_9 AS round3_right
  ON (round3_right.t1__id = round3_left.ml__movie_id)
 AND (round3_right.t1__id = round3_left.mc1__movie_id)
GROUP BY round3_left.cn2__name, round3_left.mi_idx2__info, round3_right.t1__title, round3_left.t2__title, round3_right.t1__id, round3_left.mc1__company_id, round3_left.ml__movie_id, round3_left.mc1__movie_id;

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_r3_join_11 AS
SELECT round3_left.mi_idx1__info AS mi_idx1__info,
       round3_left.mi_idx1__movie_id AS mi_idx1__movie_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_33c_rewriteYa0_r3_base_mi_idx1 AS round3_left
JOIN ya_33c_rewriteYa0_r3_base_it1 AS round3_right
  ON (round3_right.it1__id = round3_left.mi_idx1__info_type_id)
GROUP BY round3_left.mi_idx1__info, round3_left.mi_idx1__movie_id;

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_r3_join_12 AS
SELECT round3_left.cn2__name AS cn2__name,
       round3_right.mi_idx1__info AS mi_idx1__info,
       round3_left.mi_idx2__info AS mi_idx2__info,
       round3_left.t1__title AS t1__title,
       round3_left.t2__title AS t2__title,
       round3_left.mc1__company_id AS mc1__company_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_33c_rewriteYa0_r3_join_10 AS round3_left
JOIN ya_33c_rewriteYa0_r3_join_11 AS round3_right
  ON (round3_left.t1__id = round3_right.mi_idx1__movie_id)
 AND (round3_left.ml__movie_id = round3_right.mi_idx1__movie_id)
 AND (round3_right.mi_idx1__movie_id = round3_left.mc1__movie_id)
GROUP BY round3_left.cn2__name, round3_right.mi_idx1__info, round3_left.mi_idx2__info, round3_left.t1__title, round3_left.t2__title, round3_left.mc1__company_id;

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_r3_join_13 AS
SELECT round3_left.cn1__name AS cn1__name,
       round3_right.cn2__name AS cn2__name,
       round3_right.mi_idx1__info AS mi_idx1__info,
       round3_right.mi_idx2__info AS mi_idx2__info,
       round3_right.t1__title AS t1__title,
       round3_right.t2__title AS t2__title,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_33c_rewriteYa0_r3_base_cn1 AS round3_left
JOIN ya_33c_rewriteYa0_r3_join_12 AS round3_right
  ON (round3_left.cn1__id = round3_right.mc1__company_id)
GROUP BY round3_left.cn1__name, round3_right.cn2__name, round3_right.mi_idx1__info, round3_right.mi_idx2__info, round3_right.t1__title, round3_right.t2__title;

SELECT round3_result.cn1__name AS name,
       round3_result.cn2__name AS name,
       round3_result.mi_idx1__info AS info,
       round3_result.mi_idx2__info AS info,
       round3_result.t1__title AS title,
       round3_result.t2__title AS title,
       round3_result.annot AS record_count
FROM ya_33c_rewriteYa0_r3_join_13 AS round3_result;
