-- DuckDB SUM(1) Yannakakis-style two-pass reducer generated from job_agg/15c.sql.

-- Source variant: query/job_duckdb/15c/rewriteYa195.sql

CREATE OR REPLACE TEMP VIEW ya_15c_rewriteYa195_base_akt AS
SELECT akt.*
FROM aka_title AS akt;

CREATE OR REPLACE TEMP VIEW ya_15c_rewriteYa195_base_cn AS
SELECT cn.*
FROM company_name AS cn
WHERE (cn.country_code = '[us]');

CREATE OR REPLACE TEMP VIEW ya_15c_rewriteYa195_base_ct AS
SELECT ct.*
FROM company_type AS ct;

CREATE OR REPLACE TEMP VIEW ya_15c_rewriteYa195_base_it1 AS
SELECT it1.*
FROM info_type AS it1
WHERE (it1.info = 'release dates');

CREATE OR REPLACE TEMP VIEW ya_15c_rewriteYa195_base_k AS
SELECT k.*
FROM keyword AS k;

CREATE OR REPLACE TEMP VIEW ya_15c_rewriteYa195_base_mc AS
SELECT mc.*
FROM movie_companies AS mc;

CREATE OR REPLACE TEMP VIEW ya_15c_rewriteYa195_base_mi AS
SELECT mi.*
FROM movie_info AS mi
WHERE (mi.note LIKE '%internet%')
  AND (mi.info IS NOT NULL)
  AND ((mi.info LIKE 'USA:% 199%'
       OR mi.info LIKE 'USA:% 200%'));

CREATE OR REPLACE TEMP VIEW ya_15c_rewriteYa195_base_mk AS
SELECT mk.*
FROM movie_keyword AS mk;

CREATE OR REPLACE TEMP VIEW ya_15c_rewriteYa195_base_t AS
SELECT t.*
FROM title AS t
WHERE (t.production_year > 1990);

CREATE OR REPLACE TEMP VIEW ya_15c_rewriteYa195_up_it1 AS
SELECT it1.*
FROM ya_15c_rewriteYa195_base_it1 AS it1;

CREATE OR REPLACE TEMP VIEW ya_15c_rewriteYa195_up_cn AS
SELECT cn.*
FROM ya_15c_rewriteYa195_base_cn AS cn;

CREATE OR REPLACE TEMP VIEW ya_15c_rewriteYa195_up_ct AS
SELECT ct.*
FROM ya_15c_rewriteYa195_base_ct AS ct;

CREATE OR REPLACE TEMP VIEW ya_15c_rewriteYa195_up_mc AS
SELECT mc.*
FROM ya_15c_rewriteYa195_base_mc AS mc
WHERE EXISTS (SELECT 1 FROM ya_15c_rewriteYa195_up_cn AS cn WHERE (cn.id = mc.company_id))
  AND EXISTS (SELECT 1 FROM ya_15c_rewriteYa195_up_ct AS ct WHERE (ct.id = mc.company_type_id));

CREATE OR REPLACE TEMP VIEW ya_15c_rewriteYa195_up_k AS
SELECT k.*
FROM ya_15c_rewriteYa195_base_k AS k;

CREATE OR REPLACE TEMP VIEW ya_15c_rewriteYa195_up_mk AS
SELECT mk.*
FROM ya_15c_rewriteYa195_base_mk AS mk
WHERE EXISTS (SELECT 1 FROM ya_15c_rewriteYa195_up_k AS k WHERE (k.id = mk.keyword_id));

CREATE OR REPLACE TEMP VIEW ya_15c_rewriteYa195_up_t AS
SELECT t.*
FROM ya_15c_rewriteYa195_base_t AS t;

CREATE OR REPLACE TEMP VIEW ya_15c_rewriteYa195_up_akt AS
SELECT akt.*
FROM ya_15c_rewriteYa195_base_akt AS akt;

CREATE OR REPLACE TEMP VIEW ya_15c_rewriteYa195_up_mi AS
SELECT mi.*
FROM ya_15c_rewriteYa195_base_mi AS mi
WHERE EXISTS (SELECT 1 FROM ya_15c_rewriteYa195_up_it1 AS it1 WHERE (it1.id = mi.info_type_id))
  AND EXISTS (SELECT 1 FROM ya_15c_rewriteYa195_up_mc AS mc WHERE (mi.movie_id = mc.movie_id))
  AND EXISTS (SELECT 1 FROM ya_15c_rewriteYa195_up_mk AS mk WHERE (mk.movie_id = mi.movie_id))
  AND EXISTS (SELECT 1 FROM ya_15c_rewriteYa195_up_t AS t WHERE (t.id = mi.movie_id))
  AND EXISTS (SELECT 1 FROM ya_15c_rewriteYa195_up_akt AS akt WHERE (mi.movie_id = akt.movie_id));

CREATE OR REPLACE TEMP VIEW ya_15c_rewriteYa195_down_mi AS
SELECT mi.*
FROM ya_15c_rewriteYa195_up_mi AS mi;

CREATE OR REPLACE TEMP VIEW ya_15c_rewriteYa195_down_it1 AS
SELECT it1.*
FROM ya_15c_rewriteYa195_up_it1 AS it1
WHERE EXISTS (SELECT 1 FROM ya_15c_rewriteYa195_down_mi AS mi WHERE (it1.id = mi.info_type_id));

CREATE OR REPLACE TEMP VIEW ya_15c_rewriteYa195_down_mc AS
SELECT mc.*
FROM ya_15c_rewriteYa195_up_mc AS mc
WHERE EXISTS (SELECT 1 FROM ya_15c_rewriteYa195_down_mi AS mi WHERE (mi.movie_id = mc.movie_id));

CREATE OR REPLACE TEMP VIEW ya_15c_rewriteYa195_down_mk AS
SELECT mk.*
FROM ya_15c_rewriteYa195_up_mk AS mk
WHERE EXISTS (SELECT 1 FROM ya_15c_rewriteYa195_down_mi AS mi WHERE (mk.movie_id = mi.movie_id));

CREATE OR REPLACE TEMP VIEW ya_15c_rewriteYa195_down_t AS
SELECT t.*
FROM ya_15c_rewriteYa195_up_t AS t
WHERE EXISTS (SELECT 1 FROM ya_15c_rewriteYa195_down_mi AS mi WHERE (t.id = mi.movie_id));

CREATE OR REPLACE TEMP VIEW ya_15c_rewriteYa195_down_akt AS
SELECT akt.*
FROM ya_15c_rewriteYa195_up_akt AS akt
WHERE EXISTS (SELECT 1 FROM ya_15c_rewriteYa195_down_mi AS mi WHERE (mi.movie_id = akt.movie_id));

CREATE OR REPLACE TEMP VIEW ya_15c_rewriteYa195_down_cn AS
SELECT cn.*
FROM ya_15c_rewriteYa195_up_cn AS cn
WHERE EXISTS (SELECT 1 FROM ya_15c_rewriteYa195_down_mc AS mc WHERE (cn.id = mc.company_id));

CREATE OR REPLACE TEMP VIEW ya_15c_rewriteYa195_down_ct AS
SELECT ct.*
FROM ya_15c_rewriteYa195_up_ct AS ct
WHERE EXISTS (SELECT 1 FROM ya_15c_rewriteYa195_down_mc AS mc WHERE (ct.id = mc.company_type_id));

CREATE OR REPLACE TEMP VIEW ya_15c_rewriteYa195_down_k AS
SELECT k.*
FROM ya_15c_rewriteYa195_up_k AS k
WHERE EXISTS (SELECT 1 FROM ya_15c_rewriteYa195_down_mk AS mk WHERE (k.id = mk.keyword_id));

CREATE OR REPLACE TEMP VIEW ya_15c_rewriteYa195_r3_base_akt AS
SELECT akt.movie_id AS akt__movie_id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_15c_rewriteYa195_down_akt AS akt
GROUP BY akt.movie_id;

CREATE OR REPLACE TEMP VIEW ya_15c_rewriteYa195_r3_base_cn AS
SELECT cn.id AS cn__id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_15c_rewriteYa195_down_cn AS cn
GROUP BY cn.id;

CREATE OR REPLACE TEMP VIEW ya_15c_rewriteYa195_r3_base_ct AS
SELECT ct.id AS ct__id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_15c_rewriteYa195_down_ct AS ct
GROUP BY ct.id;

CREATE OR REPLACE TEMP VIEW ya_15c_rewriteYa195_r3_base_it1 AS
SELECT it1.id AS it1__id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_15c_rewriteYa195_down_it1 AS it1
GROUP BY it1.id;

CREATE OR REPLACE TEMP VIEW ya_15c_rewriteYa195_r3_base_k AS
SELECT k.id AS k__id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_15c_rewriteYa195_down_k AS k
GROUP BY k.id;

CREATE OR REPLACE TEMP VIEW ya_15c_rewriteYa195_r3_base_mc AS
SELECT mc.movie_id AS mc__movie_id,
       mc.company_id AS mc__company_id,
       mc.company_type_id AS mc__company_type_id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_15c_rewriteYa195_down_mc AS mc
GROUP BY mc.movie_id, mc.company_id, mc.company_type_id;

CREATE OR REPLACE TEMP VIEW ya_15c_rewriteYa195_r3_base_mi AS
SELECT mi.movie_id AS mi__movie_id,
       mi.info_type_id AS mi__info_type_id,
       mi.info AS mi__info,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_15c_rewriteYa195_down_mi AS mi
GROUP BY mi.movie_id, mi.info_type_id, mi.info;

CREATE OR REPLACE TEMP VIEW ya_15c_rewriteYa195_r3_base_mk AS
SELECT mk.movie_id AS mk__movie_id,
       mk.keyword_id AS mk__keyword_id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_15c_rewriteYa195_down_mk AS mk
GROUP BY mk.movie_id, mk.keyword_id;

CREATE OR REPLACE TEMP VIEW ya_15c_rewriteYa195_r3_base_t AS
SELECT t.id AS t__id,
       t.title AS t__title,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_15c_rewriteYa195_down_t AS t
GROUP BY t.id, t.title;

CREATE OR REPLACE TEMP VIEW ya_15c_rewriteYa195_r3_join_1 AS
SELECT round3_left.mi__info AS mi__info,
       round3_left.mi__movie_id AS mi__movie_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_15c_rewriteYa195_r3_base_mi AS round3_left
JOIN ya_15c_rewriteYa195_r3_base_it1 AS round3_right
  ON (round3_right.it1__id = round3_left.mi__info_type_id)
GROUP BY round3_left.mi__info, round3_left.mi__movie_id;

CREATE OR REPLACE TEMP VIEW ya_15c_rewriteYa195_r3_join_2 AS
SELECT round3_left.mc__movie_id AS mc__movie_id,
       round3_left.mc__company_type_id AS mc__company_type_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_15c_rewriteYa195_r3_base_mc AS round3_left
JOIN ya_15c_rewriteYa195_r3_base_cn AS round3_right
  ON (round3_right.cn__id = round3_left.mc__company_id)
GROUP BY round3_left.mc__movie_id, round3_left.mc__company_type_id;

CREATE OR REPLACE TEMP VIEW ya_15c_rewriteYa195_r3_join_3 AS
SELECT round3_left.mc__movie_id AS mc__movie_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_15c_rewriteYa195_r3_join_2 AS round3_left
JOIN ya_15c_rewriteYa195_r3_base_ct AS round3_right
  ON (round3_right.ct__id = round3_left.mc__company_type_id)
GROUP BY round3_left.mc__movie_id;

CREATE OR REPLACE TEMP VIEW ya_15c_rewriteYa195_r3_join_4 AS
SELECT round3_left.mi__info AS mi__info,
       round3_left.mi__movie_id AS mi__movie_id,
       round3_right.mc__movie_id AS mc__movie_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_15c_rewriteYa195_r3_join_1 AS round3_left
JOIN ya_15c_rewriteYa195_r3_join_3 AS round3_right
  ON (round3_left.mi__movie_id = round3_right.mc__movie_id)
GROUP BY round3_left.mi__info, round3_left.mi__movie_id, round3_right.mc__movie_id;

CREATE OR REPLACE TEMP VIEW ya_15c_rewriteYa195_r3_join_5 AS
SELECT round3_left.mk__movie_id AS mk__movie_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_15c_rewriteYa195_r3_base_mk AS round3_left
JOIN ya_15c_rewriteYa195_r3_base_k AS round3_right
  ON (round3_right.k__id = round3_left.mk__keyword_id)
GROUP BY round3_left.mk__movie_id;

CREATE OR REPLACE TEMP VIEW ya_15c_rewriteYa195_r3_join_6 AS
SELECT round3_left.mi__info AS mi__info,
       round3_left.mi__movie_id AS mi__movie_id,
       round3_right.mk__movie_id AS mk__movie_id,
       round3_left.mc__movie_id AS mc__movie_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_15c_rewriteYa195_r3_join_4 AS round3_left
JOIN ya_15c_rewriteYa195_r3_join_5 AS round3_right
  ON (round3_right.mk__movie_id = round3_left.mi__movie_id)
 AND (round3_right.mk__movie_id = round3_left.mc__movie_id)
GROUP BY round3_left.mi__info, round3_left.mi__movie_id, round3_right.mk__movie_id, round3_left.mc__movie_id;

CREATE OR REPLACE TEMP VIEW ya_15c_rewriteYa195_r3_join_7 AS
SELECT round3_left.mi__info AS mi__info,
       round3_right.t__title AS t__title,
       round3_right.t__id AS t__id,
       round3_left.mk__movie_id AS mk__movie_id,
       round3_left.mi__movie_id AS mi__movie_id,
       round3_left.mc__movie_id AS mc__movie_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_15c_rewriteYa195_r3_join_6 AS round3_left
JOIN ya_15c_rewriteYa195_r3_base_t AS round3_right
  ON (round3_right.t__id = round3_left.mi__movie_id)
 AND (round3_right.t__id = round3_left.mk__movie_id)
 AND (round3_right.t__id = round3_left.mc__movie_id)
GROUP BY round3_left.mi__info, round3_right.t__title, round3_right.t__id, round3_left.mk__movie_id, round3_left.mi__movie_id, round3_left.mc__movie_id;

CREATE OR REPLACE TEMP VIEW ya_15c_rewriteYa195_r3_join_8 AS
SELECT round3_left.mi__info AS mi__info,
       round3_left.t__title AS t__title,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_15c_rewriteYa195_r3_join_7 AS round3_left
JOIN ya_15c_rewriteYa195_r3_base_akt AS round3_right
  ON (round3_left.t__id = round3_right.akt__movie_id)
 AND (round3_left.mk__movie_id = round3_right.akt__movie_id)
 AND (round3_left.mi__movie_id = round3_right.akt__movie_id)
 AND (round3_left.mc__movie_id = round3_right.akt__movie_id)
GROUP BY round3_left.mi__info, round3_left.t__title;

SELECT round3_result.mi__info AS info,
       round3_result.t__title AS title,
       round3_result.annot AS record_count
FROM ya_15c_rewriteYa195_r3_join_8 AS round3_result;
