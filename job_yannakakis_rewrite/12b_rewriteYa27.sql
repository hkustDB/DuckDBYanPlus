-- DuckDB SUM(1) Yannakakis-style two-pass reducer generated from job_agg/12b.sql.

-- Source variant: query/job_duckdb/12b/rewriteYa27.sql

CREATE OR REPLACE TEMP VIEW ya_12b_rewriteYa27_base_cn AS
SELECT cn.*
FROM company_name AS cn
WHERE (cn.country_code ='[us]');

CREATE OR REPLACE TEMP VIEW ya_12b_rewriteYa27_base_ct AS
SELECT ct.*
FROM company_type AS ct
WHERE (ct.kind IS NOT NULL)
  AND ((ct.kind ='production companies'
       OR ct.kind = 'distributors'));

CREATE OR REPLACE TEMP VIEW ya_12b_rewriteYa27_base_it1 AS
SELECT it1.*
FROM info_type AS it1
WHERE (it1.info ='budget');

CREATE OR REPLACE TEMP VIEW ya_12b_rewriteYa27_base_it2 AS
SELECT it2.*
FROM info_type AS it2
WHERE (it2.info ='bottom 10 rank');

CREATE OR REPLACE TEMP VIEW ya_12b_rewriteYa27_base_mc AS
SELECT mc.*
FROM movie_companies AS mc;

CREATE OR REPLACE TEMP VIEW ya_12b_rewriteYa27_base_mi AS
SELECT mi.*
FROM movie_info AS mi;

CREATE OR REPLACE TEMP VIEW ya_12b_rewriteYa27_base_mi_idx AS
SELECT mi_idx.*
FROM movie_info_idx AS mi_idx;

CREATE OR REPLACE TEMP VIEW ya_12b_rewriteYa27_base_t AS
SELECT t.*
FROM title AS t
WHERE (t.production_year >2000)
  AND ((t.title LIKE 'Birdemic%'
       OR t.title LIKE '%Movie%'));

CREATE OR REPLACE TEMP VIEW ya_12b_rewriteYa27_up_cn AS
SELECT cn.*
FROM ya_12b_rewriteYa27_base_cn AS cn;

CREATE OR REPLACE TEMP VIEW ya_12b_rewriteYa27_up_ct AS
SELECT ct.*
FROM ya_12b_rewriteYa27_base_ct AS ct;

CREATE OR REPLACE TEMP VIEW ya_12b_rewriteYa27_up_mc AS
SELECT mc.*
FROM ya_12b_rewriteYa27_base_mc AS mc
WHERE EXISTS (SELECT 1 FROM ya_12b_rewriteYa27_up_cn AS cn WHERE (cn.id = mc.company_id))
  AND EXISTS (SELECT 1 FROM ya_12b_rewriteYa27_up_ct AS ct WHERE (ct.id = mc.company_type_id));

CREATE OR REPLACE TEMP VIEW ya_12b_rewriteYa27_up_it1 AS
SELECT it1.*
FROM ya_12b_rewriteYa27_base_it1 AS it1;

CREATE OR REPLACE TEMP VIEW ya_12b_rewriteYa27_up_mi AS
SELECT mi.*
FROM ya_12b_rewriteYa27_base_mi AS mi
WHERE EXISTS (SELECT 1 FROM ya_12b_rewriteYa27_up_it1 AS it1 WHERE (mi.info_type_id = it1.id));

CREATE OR REPLACE TEMP VIEW ya_12b_rewriteYa27_up_t AS
SELECT t.*
FROM ya_12b_rewriteYa27_base_t AS t;

CREATE OR REPLACE TEMP VIEW ya_12b_rewriteYa27_up_mi_idx AS
SELECT mi_idx.*
FROM ya_12b_rewriteYa27_base_mi_idx AS mi_idx
WHERE EXISTS (SELECT 1 FROM ya_12b_rewriteYa27_up_mc AS mc WHERE (mc.movie_id = mi_idx.movie_id))
  AND EXISTS (SELECT 1 FROM ya_12b_rewriteYa27_up_mi AS mi WHERE (mi.movie_id = mi_idx.movie_id))
  AND EXISTS (SELECT 1 FROM ya_12b_rewriteYa27_up_t AS t WHERE (t.id = mi_idx.movie_id));

CREATE OR REPLACE TEMP VIEW ya_12b_rewriteYa27_up_it2 AS
SELECT it2.*
FROM ya_12b_rewriteYa27_base_it2 AS it2
WHERE EXISTS (SELECT 1 FROM ya_12b_rewriteYa27_up_mi_idx AS mi_idx WHERE (mi_idx.info_type_id = it2.id));

CREATE OR REPLACE TEMP VIEW ya_12b_rewriteYa27_down_it2 AS
SELECT it2.*
FROM ya_12b_rewriteYa27_up_it2 AS it2;

CREATE OR REPLACE TEMP VIEW ya_12b_rewriteYa27_down_mi_idx AS
SELECT mi_idx.*
FROM ya_12b_rewriteYa27_up_mi_idx AS mi_idx
WHERE EXISTS (SELECT 1 FROM ya_12b_rewriteYa27_down_it2 AS it2 WHERE (mi_idx.info_type_id = it2.id));

CREATE OR REPLACE TEMP VIEW ya_12b_rewriteYa27_down_mc AS
SELECT mc.*
FROM ya_12b_rewriteYa27_up_mc AS mc
WHERE EXISTS (SELECT 1 FROM ya_12b_rewriteYa27_down_mi_idx AS mi_idx WHERE (mc.movie_id = mi_idx.movie_id));

CREATE OR REPLACE TEMP VIEW ya_12b_rewriteYa27_down_mi AS
SELECT mi.*
FROM ya_12b_rewriteYa27_up_mi AS mi
WHERE EXISTS (SELECT 1 FROM ya_12b_rewriteYa27_down_mi_idx AS mi_idx WHERE (mi.movie_id = mi_idx.movie_id));

CREATE OR REPLACE TEMP VIEW ya_12b_rewriteYa27_down_t AS
SELECT t.*
FROM ya_12b_rewriteYa27_up_t AS t
WHERE EXISTS (SELECT 1 FROM ya_12b_rewriteYa27_down_mi_idx AS mi_idx WHERE (t.id = mi_idx.movie_id));

CREATE OR REPLACE TEMP VIEW ya_12b_rewriteYa27_down_cn AS
SELECT cn.*
FROM ya_12b_rewriteYa27_up_cn AS cn
WHERE EXISTS (SELECT 1 FROM ya_12b_rewriteYa27_down_mc AS mc WHERE (cn.id = mc.company_id));

CREATE OR REPLACE TEMP VIEW ya_12b_rewriteYa27_down_ct AS
SELECT ct.*
FROM ya_12b_rewriteYa27_up_ct AS ct
WHERE EXISTS (SELECT 1 FROM ya_12b_rewriteYa27_down_mc AS mc WHERE (ct.id = mc.company_type_id));

CREATE OR REPLACE TEMP VIEW ya_12b_rewriteYa27_down_it1 AS
SELECT it1.*
FROM ya_12b_rewriteYa27_up_it1 AS it1
WHERE EXISTS (SELECT 1 FROM ya_12b_rewriteYa27_down_mi AS mi WHERE (mi.info_type_id = it1.id));

CREATE OR REPLACE TEMP VIEW ya_12b_rewriteYa27_r3_base_cn AS
SELECT cn.id AS cn__id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_12b_rewriteYa27_down_cn AS cn
GROUP BY cn.id;

CREATE OR REPLACE TEMP VIEW ya_12b_rewriteYa27_r3_base_ct AS
SELECT ct.id AS ct__id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_12b_rewriteYa27_down_ct AS ct
GROUP BY ct.id;

CREATE OR REPLACE TEMP VIEW ya_12b_rewriteYa27_r3_base_it1 AS
SELECT it1.id AS it1__id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_12b_rewriteYa27_down_it1 AS it1
GROUP BY it1.id;

CREATE OR REPLACE TEMP VIEW ya_12b_rewriteYa27_r3_base_it2 AS
SELECT it2.id AS it2__id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_12b_rewriteYa27_down_it2 AS it2
GROUP BY it2.id;

CREATE OR REPLACE TEMP VIEW ya_12b_rewriteYa27_r3_base_mc AS
SELECT mc.movie_id AS mc__movie_id,
       mc.company_type_id AS mc__company_type_id,
       mc.company_id AS mc__company_id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_12b_rewriteYa27_down_mc AS mc
GROUP BY mc.movie_id, mc.company_type_id, mc.company_id;

CREATE OR REPLACE TEMP VIEW ya_12b_rewriteYa27_r3_base_mi AS
SELECT mi.movie_id AS mi__movie_id,
       mi.info_type_id AS mi__info_type_id,
       mi.info AS mi__info,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_12b_rewriteYa27_down_mi AS mi
GROUP BY mi.movie_id, mi.info_type_id, mi.info;

CREATE OR REPLACE TEMP VIEW ya_12b_rewriteYa27_r3_base_mi_idx AS
SELECT mi_idx.movie_id AS mi_idx__movie_id,
       mi_idx.info_type_id AS mi_idx__info_type_id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_12b_rewriteYa27_down_mi_idx AS mi_idx
GROUP BY mi_idx.movie_id, mi_idx.info_type_id;

CREATE OR REPLACE TEMP VIEW ya_12b_rewriteYa27_r3_base_t AS
SELECT t.id AS t__id,
       t.title AS t__title,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_12b_rewriteYa27_down_t AS t
GROUP BY t.id, t.title;

CREATE OR REPLACE TEMP VIEW ya_12b_rewriteYa27_r3_join_1 AS
SELECT round3_left.mc__movie_id AS mc__movie_id,
       round3_left.mc__company_type_id AS mc__company_type_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_12b_rewriteYa27_r3_base_mc AS round3_left
JOIN ya_12b_rewriteYa27_r3_base_cn AS round3_right
  ON (round3_right.cn__id = round3_left.mc__company_id)
GROUP BY round3_left.mc__movie_id, round3_left.mc__company_type_id;

CREATE OR REPLACE TEMP VIEW ya_12b_rewriteYa27_r3_join_2 AS
SELECT round3_left.mc__movie_id AS mc__movie_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_12b_rewriteYa27_r3_join_1 AS round3_left
JOIN ya_12b_rewriteYa27_r3_base_ct AS round3_right
  ON (round3_right.ct__id = round3_left.mc__company_type_id)
GROUP BY round3_left.mc__movie_id;

CREATE OR REPLACE TEMP VIEW ya_12b_rewriteYa27_r3_join_3 AS
SELECT round3_left.mi_idx__movie_id AS mi_idx__movie_id,
       round3_left.mi_idx__info_type_id AS mi_idx__info_type_id,
       round3_right.mc__movie_id AS mc__movie_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_12b_rewriteYa27_r3_base_mi_idx AS round3_left
JOIN ya_12b_rewriteYa27_r3_join_2 AS round3_right
  ON (round3_right.mc__movie_id = round3_left.mi_idx__movie_id)
GROUP BY round3_left.mi_idx__movie_id, round3_left.mi_idx__info_type_id, round3_right.mc__movie_id;

CREATE OR REPLACE TEMP VIEW ya_12b_rewriteYa27_r3_join_4 AS
SELECT round3_left.mi__info AS mi__info,
       round3_left.mi__movie_id AS mi__movie_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_12b_rewriteYa27_r3_base_mi AS round3_left
JOIN ya_12b_rewriteYa27_r3_base_it1 AS round3_right
  ON (round3_left.mi__info_type_id = round3_right.it1__id)
GROUP BY round3_left.mi__info, round3_left.mi__movie_id;

CREATE OR REPLACE TEMP VIEW ya_12b_rewriteYa27_r3_join_5 AS
SELECT round3_right.mi__info AS mi__info,
       round3_right.mi__movie_id AS mi__movie_id,
       round3_left.mi_idx__movie_id AS mi_idx__movie_id,
       round3_left.mi_idx__info_type_id AS mi_idx__info_type_id,
       round3_left.mc__movie_id AS mc__movie_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_12b_rewriteYa27_r3_join_3 AS round3_left
JOIN ya_12b_rewriteYa27_r3_join_4 AS round3_right
  ON (round3_left.mc__movie_id = round3_right.mi__movie_id)
 AND (round3_right.mi__movie_id = round3_left.mi_idx__movie_id)
GROUP BY round3_right.mi__info, round3_right.mi__movie_id, round3_left.mi_idx__movie_id, round3_left.mi_idx__info_type_id, round3_left.mc__movie_id;

CREATE OR REPLACE TEMP VIEW ya_12b_rewriteYa27_r3_join_6 AS
SELECT round3_left.mi__info AS mi__info,
       round3_right.t__title AS t__title,
       round3_left.mi_idx__info_type_id AS mi_idx__info_type_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_12b_rewriteYa27_r3_join_5 AS round3_left
JOIN ya_12b_rewriteYa27_r3_base_t AS round3_right
  ON (round3_right.t__id = round3_left.mi__movie_id)
 AND (round3_right.t__id = round3_left.mi_idx__movie_id)
 AND (round3_right.t__id = round3_left.mc__movie_id)
GROUP BY round3_left.mi__info, round3_right.t__title, round3_left.mi_idx__info_type_id;

CREATE OR REPLACE TEMP VIEW ya_12b_rewriteYa27_r3_join_7 AS
SELECT round3_right.mi__info AS mi__info,
       round3_right.t__title AS t__title,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_12b_rewriteYa27_r3_base_it2 AS round3_left
JOIN ya_12b_rewriteYa27_r3_join_6 AS round3_right
  ON (round3_right.mi_idx__info_type_id = round3_left.it2__id)
GROUP BY round3_right.mi__info, round3_right.t__title;

SELECT round3_result.mi__info AS info,
       round3_result.t__title AS title,
       round3_result.annot AS record_count
FROM ya_12b_rewriteYa27_r3_join_7 AS round3_result;
