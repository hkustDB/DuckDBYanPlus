-- DuckDB SUM(1) Yannakakis-style two-pass reducer generated from job_agg/13a.sql.

-- Source variant: query/job_duckdb/13a/rewriteYa0.sql

CREATE OR REPLACE TEMP VIEW ya_13a_rewriteYa0_base_cn AS
SELECT cn.*
FROM company_name AS cn
WHERE (cn.country_code ='[de]');

CREATE OR REPLACE TEMP VIEW ya_13a_rewriteYa0_base_ct AS
SELECT ct.*
FROM company_type AS ct
WHERE (ct.kind ='production companies');

CREATE OR REPLACE TEMP VIEW ya_13a_rewriteYa0_base_it AS
SELECT it.*
FROM info_type AS it
WHERE (it.info ='rating');

CREATE OR REPLACE TEMP VIEW ya_13a_rewriteYa0_base_it2 AS
SELECT it2.*
FROM info_type AS it2
WHERE (it2.info ='release dates');

CREATE OR REPLACE TEMP VIEW ya_13a_rewriteYa0_base_kt AS
SELECT kt.*
FROM kind_type AS kt
WHERE (kt.kind ='movie');

CREATE OR REPLACE TEMP VIEW ya_13a_rewriteYa0_base_mc AS
SELECT mc.*
FROM movie_companies AS mc;

CREATE OR REPLACE TEMP VIEW ya_13a_rewriteYa0_base_mi AS
SELECT mi.*
FROM movie_info AS mi;

CREATE OR REPLACE TEMP VIEW ya_13a_rewriteYa0_base_miidx AS
SELECT miidx.*
FROM movie_info_idx AS miidx;

CREATE OR REPLACE TEMP VIEW ya_13a_rewriteYa0_base_t AS
SELECT t.*
FROM title AS t;

CREATE OR REPLACE TEMP VIEW ya_13a_rewriteYa0_up_it2 AS
SELECT it2.*
FROM ya_13a_rewriteYa0_base_it2 AS it2;

CREATE OR REPLACE TEMP VIEW ya_13a_rewriteYa0_up_mi AS
SELECT mi.*
FROM ya_13a_rewriteYa0_base_mi AS mi
WHERE EXISTS (SELECT 1 FROM ya_13a_rewriteYa0_up_it2 AS it2 WHERE (it2.id = mi.info_type_id));

CREATE OR REPLACE TEMP VIEW ya_13a_rewriteYa0_up_it AS
SELECT it.*
FROM ya_13a_rewriteYa0_base_it AS it;

CREATE OR REPLACE TEMP VIEW ya_13a_rewriteYa0_up_miidx AS
SELECT miidx.*
FROM ya_13a_rewriteYa0_base_miidx AS miidx
WHERE EXISTS (SELECT 1 FROM ya_13a_rewriteYa0_up_it AS it WHERE (it.id = miidx.info_type_id));

CREATE OR REPLACE TEMP VIEW ya_13a_rewriteYa0_up_kt AS
SELECT kt.*
FROM ya_13a_rewriteYa0_base_kt AS kt;

CREATE OR REPLACE TEMP VIEW ya_13a_rewriteYa0_up_t AS
SELECT t.*
FROM ya_13a_rewriteYa0_base_t AS t
WHERE EXISTS (SELECT 1 FROM ya_13a_rewriteYa0_up_kt AS kt WHERE (kt.id = t.kind_id));

CREATE OR REPLACE TEMP VIEW ya_13a_rewriteYa0_up_ct AS
SELECT ct.*
FROM ya_13a_rewriteYa0_base_ct AS ct;

CREATE OR REPLACE TEMP VIEW ya_13a_rewriteYa0_up_mc AS
SELECT mc.*
FROM ya_13a_rewriteYa0_base_mc AS mc
WHERE EXISTS (SELECT 1 FROM ya_13a_rewriteYa0_up_mi AS mi WHERE (mi.movie_id = mc.movie_id))
  AND EXISTS (SELECT 1 FROM ya_13a_rewriteYa0_up_miidx AS miidx WHERE (miidx.movie_id = mc.movie_id))
  AND EXISTS (SELECT 1 FROM ya_13a_rewriteYa0_up_t AS t WHERE (mc.movie_id = t.id))
  AND EXISTS (SELECT 1 FROM ya_13a_rewriteYa0_up_ct AS ct WHERE (ct.id = mc.company_type_id));

CREATE OR REPLACE TEMP VIEW ya_13a_rewriteYa0_up_cn AS
SELECT cn.*
FROM ya_13a_rewriteYa0_base_cn AS cn
WHERE EXISTS (SELECT 1 FROM ya_13a_rewriteYa0_up_mc AS mc WHERE (cn.id = mc.company_id));

CREATE OR REPLACE TEMP VIEW ya_13a_rewriteYa0_down_cn AS
SELECT cn.*
FROM ya_13a_rewriteYa0_up_cn AS cn;

CREATE OR REPLACE TEMP VIEW ya_13a_rewriteYa0_down_mc AS
SELECT mc.*
FROM ya_13a_rewriteYa0_up_mc AS mc
WHERE EXISTS (SELECT 1 FROM ya_13a_rewriteYa0_down_cn AS cn WHERE (cn.id = mc.company_id));

CREATE OR REPLACE TEMP VIEW ya_13a_rewriteYa0_down_mi AS
SELECT mi.*
FROM ya_13a_rewriteYa0_up_mi AS mi
WHERE EXISTS (SELECT 1 FROM ya_13a_rewriteYa0_down_mc AS mc WHERE (mi.movie_id = mc.movie_id));

CREATE OR REPLACE TEMP VIEW ya_13a_rewriteYa0_down_miidx AS
SELECT miidx.*
FROM ya_13a_rewriteYa0_up_miidx AS miidx
WHERE EXISTS (SELECT 1 FROM ya_13a_rewriteYa0_down_mc AS mc WHERE (miidx.movie_id = mc.movie_id));

CREATE OR REPLACE TEMP VIEW ya_13a_rewriteYa0_down_t AS
SELECT t.*
FROM ya_13a_rewriteYa0_up_t AS t
WHERE EXISTS (SELECT 1 FROM ya_13a_rewriteYa0_down_mc AS mc WHERE (mc.movie_id = t.id));

CREATE OR REPLACE TEMP VIEW ya_13a_rewriteYa0_down_ct AS
SELECT ct.*
FROM ya_13a_rewriteYa0_up_ct AS ct
WHERE EXISTS (SELECT 1 FROM ya_13a_rewriteYa0_down_mc AS mc WHERE (ct.id = mc.company_type_id));

CREATE OR REPLACE TEMP VIEW ya_13a_rewriteYa0_down_it2 AS
SELECT it2.*
FROM ya_13a_rewriteYa0_up_it2 AS it2
WHERE EXISTS (SELECT 1 FROM ya_13a_rewriteYa0_down_mi AS mi WHERE (it2.id = mi.info_type_id));

CREATE OR REPLACE TEMP VIEW ya_13a_rewriteYa0_down_it AS
SELECT it.*
FROM ya_13a_rewriteYa0_up_it AS it
WHERE EXISTS (SELECT 1 FROM ya_13a_rewriteYa0_down_miidx AS miidx WHERE (it.id = miidx.info_type_id));

CREATE OR REPLACE TEMP VIEW ya_13a_rewriteYa0_down_kt AS
SELECT kt.*
FROM ya_13a_rewriteYa0_up_kt AS kt
WHERE EXISTS (SELECT 1 FROM ya_13a_rewriteYa0_down_t AS t WHERE (kt.id = t.kind_id));

CREATE OR REPLACE TEMP VIEW ya_13a_rewriteYa0_r3_base_cn AS
SELECT cn.id AS cn__id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_13a_rewriteYa0_down_cn AS cn
GROUP BY cn.id;

CREATE OR REPLACE TEMP VIEW ya_13a_rewriteYa0_r3_base_ct AS
SELECT ct.id AS ct__id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_13a_rewriteYa0_down_ct AS ct
GROUP BY ct.id;

CREATE OR REPLACE TEMP VIEW ya_13a_rewriteYa0_r3_base_it AS
SELECT it.id AS it__id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_13a_rewriteYa0_down_it AS it
GROUP BY it.id;

CREATE OR REPLACE TEMP VIEW ya_13a_rewriteYa0_r3_base_it2 AS
SELECT it2.id AS it2__id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_13a_rewriteYa0_down_it2 AS it2
GROUP BY it2.id;

CREATE OR REPLACE TEMP VIEW ya_13a_rewriteYa0_r3_base_kt AS
SELECT kt.id AS kt__id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_13a_rewriteYa0_down_kt AS kt
GROUP BY kt.id;

CREATE OR REPLACE TEMP VIEW ya_13a_rewriteYa0_r3_base_mc AS
SELECT mc.movie_id AS mc__movie_id,
       mc.company_id AS mc__company_id,
       mc.company_type_id AS mc__company_type_id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_13a_rewriteYa0_down_mc AS mc
GROUP BY mc.movie_id, mc.company_id, mc.company_type_id;

CREATE OR REPLACE TEMP VIEW ya_13a_rewriteYa0_r3_base_mi AS
SELECT mi.movie_id AS mi__movie_id,
       mi.info_type_id AS mi__info_type_id,
       mi.info AS mi__info,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_13a_rewriteYa0_down_mi AS mi
GROUP BY mi.movie_id, mi.info_type_id, mi.info;

CREATE OR REPLACE TEMP VIEW ya_13a_rewriteYa0_r3_base_miidx AS
SELECT miidx.movie_id AS miidx__movie_id,
       miidx.info_type_id AS miidx__info_type_id,
       miidx.info AS miidx__info,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_13a_rewriteYa0_down_miidx AS miidx
GROUP BY miidx.movie_id, miidx.info_type_id, miidx.info;

CREATE OR REPLACE TEMP VIEW ya_13a_rewriteYa0_r3_base_t AS
SELECT t.id AS t__id,
       t.kind_id AS t__kind_id,
       t.title AS t__title,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_13a_rewriteYa0_down_t AS t
GROUP BY t.id, t.kind_id, t.title;

CREATE OR REPLACE TEMP VIEW ya_13a_rewriteYa0_r3_join_1 AS
SELECT round3_left.mi__info AS mi__info,
       round3_left.mi__movie_id AS mi__movie_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_13a_rewriteYa0_r3_base_mi AS round3_left
JOIN ya_13a_rewriteYa0_r3_base_it2 AS round3_right
  ON (round3_right.it2__id = round3_left.mi__info_type_id)
GROUP BY round3_left.mi__info, round3_left.mi__movie_id;

CREATE OR REPLACE TEMP VIEW ya_13a_rewriteYa0_r3_join_2 AS
SELECT round3_right.mi__info AS mi__info,
       round3_right.mi__movie_id AS mi__movie_id,
       round3_left.mc__movie_id AS mc__movie_id,
       round3_left.mc__company_id AS mc__company_id,
       round3_left.mc__company_type_id AS mc__company_type_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_13a_rewriteYa0_r3_base_mc AS round3_left
JOIN ya_13a_rewriteYa0_r3_join_1 AS round3_right
  ON (round3_right.mi__movie_id = round3_left.mc__movie_id)
GROUP BY round3_right.mi__info, round3_right.mi__movie_id, round3_left.mc__movie_id, round3_left.mc__company_id, round3_left.mc__company_type_id;

CREATE OR REPLACE TEMP VIEW ya_13a_rewriteYa0_r3_join_3 AS
SELECT round3_left.miidx__info AS miidx__info,
       round3_left.miidx__movie_id AS miidx__movie_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_13a_rewriteYa0_r3_base_miidx AS round3_left
JOIN ya_13a_rewriteYa0_r3_base_it AS round3_right
  ON (round3_right.it__id = round3_left.miidx__info_type_id)
GROUP BY round3_left.miidx__info, round3_left.miidx__movie_id;

CREATE OR REPLACE TEMP VIEW ya_13a_rewriteYa0_r3_join_4 AS
SELECT round3_left.mi__info AS mi__info,
       round3_right.miidx__info AS miidx__info,
       round3_left.mi__movie_id AS mi__movie_id,
       round3_left.mc__movie_id AS mc__movie_id,
       round3_left.mc__company_id AS mc__company_id,
       round3_left.mc__company_type_id AS mc__company_type_id,
       round3_right.miidx__movie_id AS miidx__movie_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_13a_rewriteYa0_r3_join_2 AS round3_left
JOIN ya_13a_rewriteYa0_r3_join_3 AS round3_right
  ON (round3_left.mi__movie_id = round3_right.miidx__movie_id)
 AND (round3_right.miidx__movie_id = round3_left.mc__movie_id)
GROUP BY round3_left.mi__info, round3_right.miidx__info, round3_left.mi__movie_id, round3_left.mc__movie_id, round3_left.mc__company_id, round3_left.mc__company_type_id, round3_right.miidx__movie_id;

CREATE OR REPLACE TEMP VIEW ya_13a_rewriteYa0_r3_join_5 AS
SELECT round3_left.t__title AS t__title,
       round3_left.t__id AS t__id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_13a_rewriteYa0_r3_base_t AS round3_left
JOIN ya_13a_rewriteYa0_r3_base_kt AS round3_right
  ON (round3_right.kt__id = round3_left.t__kind_id)
GROUP BY round3_left.t__title, round3_left.t__id;

CREATE OR REPLACE TEMP VIEW ya_13a_rewriteYa0_r3_join_6 AS
SELECT round3_left.mi__info AS mi__info,
       round3_left.miidx__info AS miidx__info,
       round3_right.t__title AS t__title,
       round3_left.mc__company_id AS mc__company_id,
       round3_left.mc__company_type_id AS mc__company_type_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_13a_rewriteYa0_r3_join_4 AS round3_left
JOIN ya_13a_rewriteYa0_r3_join_5 AS round3_right
  ON (round3_left.mi__movie_id = round3_right.t__id)
 AND (round3_left.mc__movie_id = round3_right.t__id)
 AND (round3_left.miidx__movie_id = round3_right.t__id)
GROUP BY round3_left.mi__info, round3_left.miidx__info, round3_right.t__title, round3_left.mc__company_id, round3_left.mc__company_type_id;

CREATE OR REPLACE TEMP VIEW ya_13a_rewriteYa0_r3_join_7 AS
SELECT round3_left.mi__info AS mi__info,
       round3_left.miidx__info AS miidx__info,
       round3_left.t__title AS t__title,
       round3_left.mc__company_id AS mc__company_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_13a_rewriteYa0_r3_join_6 AS round3_left
JOIN ya_13a_rewriteYa0_r3_base_ct AS round3_right
  ON (round3_right.ct__id = round3_left.mc__company_type_id)
GROUP BY round3_left.mi__info, round3_left.miidx__info, round3_left.t__title, round3_left.mc__company_id;

CREATE OR REPLACE TEMP VIEW ya_13a_rewriteYa0_r3_join_8 AS
SELECT round3_right.mi__info AS mi__info,
       round3_right.miidx__info AS miidx__info,
       round3_right.t__title AS t__title,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_13a_rewriteYa0_r3_base_cn AS round3_left
JOIN ya_13a_rewriteYa0_r3_join_7 AS round3_right
  ON (round3_left.cn__id = round3_right.mc__company_id)
GROUP BY round3_right.mi__info, round3_right.miidx__info, round3_right.t__title;

SELECT round3_result.mi__info AS info,
       round3_result.miidx__info AS info,
       round3_result.t__title AS title,
       round3_result.annot AS record_count
FROM ya_13a_rewriteYa0_r3_join_8 AS round3_result;
