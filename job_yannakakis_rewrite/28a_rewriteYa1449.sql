-- DuckDB SUM(1) Yannakakis-style two-pass reducer generated from job_agg/28a.sql.

-- Source variant: query/job_duckdb/28a/rewriteYa1449.sql

CREATE OR REPLACE TEMP VIEW ya_28a_rewriteYa1449_base_cc AS
SELECT cc.*
FROM complete_cast AS cc;

CREATE OR REPLACE TEMP VIEW ya_28a_rewriteYa1449_base_cct1 AS
SELECT cct1.*
FROM comp_cast_type AS cct1
WHERE (cct1.kind = 'crew');

CREATE OR REPLACE TEMP VIEW ya_28a_rewriteYa1449_base_cct2 AS
SELECT cct2.*
FROM comp_cast_type AS cct2
WHERE (cct2.kind != 'complete+verified');

CREATE OR REPLACE TEMP VIEW ya_28a_rewriteYa1449_base_cn AS
SELECT cn.*
FROM company_name AS cn
WHERE (cn.country_code != '[us]');

CREATE OR REPLACE TEMP VIEW ya_28a_rewriteYa1449_base_ct AS
SELECT ct.*
FROM company_type AS ct;

CREATE OR REPLACE TEMP VIEW ya_28a_rewriteYa1449_base_it1 AS
SELECT it1.*
FROM info_type AS it1
WHERE (it1.info = 'countries');

CREATE OR REPLACE TEMP VIEW ya_28a_rewriteYa1449_base_it2 AS
SELECT it2.*
FROM info_type AS it2
WHERE (it2.info = 'rating');

CREATE OR REPLACE TEMP VIEW ya_28a_rewriteYa1449_base_k AS
SELECT k.*
FROM keyword AS k
WHERE (k.keyword IN ('murder',
                    'murder-in-title',
                    'blood',
                    'violence'));

CREATE OR REPLACE TEMP VIEW ya_28a_rewriteYa1449_base_kt AS
SELECT kt.*
FROM kind_type AS kt
WHERE (kt.kind IN ('movie',
                  'episode'));

CREATE OR REPLACE TEMP VIEW ya_28a_rewriteYa1449_base_mc AS
SELECT mc.*
FROM movie_companies AS mc
WHERE (mc.note NOT LIKE '%(USA)%')
  AND (mc.note LIKE '%(200%)%');

CREATE OR REPLACE TEMP VIEW ya_28a_rewriteYa1449_base_mi AS
SELECT mi.*
FROM movie_info AS mi
WHERE (mi.info IN ('Sweden',
                  'Norway',
                  'Germany',
                  'Denmark',
                  'Swedish',
                  'Danish',
                  'Norwegian',
                  'German',
                  'USA',
                  'American'));

CREATE OR REPLACE TEMP VIEW ya_28a_rewriteYa1449_base_mi_idx AS
SELECT mi_idx.*
FROM movie_info_idx AS mi_idx
WHERE (mi_idx.info < '8.5');

CREATE OR REPLACE TEMP VIEW ya_28a_rewriteYa1449_base_mk AS
SELECT mk.*
FROM movie_keyword AS mk;

CREATE OR REPLACE TEMP VIEW ya_28a_rewriteYa1449_base_t AS
SELECT t.*
FROM title AS t
WHERE (t.production_year > 2000);

CREATE OR REPLACE TEMP VIEW ya_28a_rewriteYa1449_up_kt AS
SELECT kt.*
FROM ya_28a_rewriteYa1449_base_kt AS kt;

CREATE OR REPLACE TEMP VIEW ya_28a_rewriteYa1449_up_t AS
SELECT t.*
FROM ya_28a_rewriteYa1449_base_t AS t
WHERE EXISTS (SELECT 1 FROM ya_28a_rewriteYa1449_up_kt AS kt WHERE (kt.id = t.kind_id));

CREATE OR REPLACE TEMP VIEW ya_28a_rewriteYa1449_up_cct2 AS
SELECT cct2.*
FROM ya_28a_rewriteYa1449_base_cct2 AS cct2;

CREATE OR REPLACE TEMP VIEW ya_28a_rewriteYa1449_up_cct1 AS
SELECT cct1.*
FROM ya_28a_rewriteYa1449_base_cct1 AS cct1;

CREATE OR REPLACE TEMP VIEW ya_28a_rewriteYa1449_up_cc AS
SELECT cc.*
FROM ya_28a_rewriteYa1449_base_cc AS cc
WHERE EXISTS (SELECT 1 FROM ya_28a_rewriteYa1449_up_cct2 AS cct2 WHERE (cct2.id = cc.status_id))
  AND EXISTS (SELECT 1 FROM ya_28a_rewriteYa1449_up_cct1 AS cct1 WHERE (cct1.id = cc.subject_id));

CREATE OR REPLACE TEMP VIEW ya_28a_rewriteYa1449_up_cn AS
SELECT cn.*
FROM ya_28a_rewriteYa1449_base_cn AS cn;

CREATE OR REPLACE TEMP VIEW ya_28a_rewriteYa1449_up_ct AS
SELECT ct.*
FROM ya_28a_rewriteYa1449_base_ct AS ct;

CREATE OR REPLACE TEMP VIEW ya_28a_rewriteYa1449_up_mc AS
SELECT mc.*
FROM ya_28a_rewriteYa1449_base_mc AS mc
WHERE EXISTS (SELECT 1 FROM ya_28a_rewriteYa1449_up_cn AS cn WHERE (cn.id = mc.company_id))
  AND EXISTS (SELECT 1 FROM ya_28a_rewriteYa1449_up_ct AS ct WHERE (ct.id = mc.company_type_id));

CREATE OR REPLACE TEMP VIEW ya_28a_rewriteYa1449_up_it1 AS
SELECT it1.*
FROM ya_28a_rewriteYa1449_base_it1 AS it1;

CREATE OR REPLACE TEMP VIEW ya_28a_rewriteYa1449_up_mi AS
SELECT mi.*
FROM ya_28a_rewriteYa1449_base_mi AS mi
WHERE EXISTS (SELECT 1 FROM ya_28a_rewriteYa1449_up_it1 AS it1 WHERE (it1.id = mi.info_type_id));

CREATE OR REPLACE TEMP VIEW ya_28a_rewriteYa1449_up_it2 AS
SELECT it2.*
FROM ya_28a_rewriteYa1449_base_it2 AS it2;

CREATE OR REPLACE TEMP VIEW ya_28a_rewriteYa1449_up_mi_idx AS
SELECT mi_idx.*
FROM ya_28a_rewriteYa1449_base_mi_idx AS mi_idx
WHERE EXISTS (SELECT 1 FROM ya_28a_rewriteYa1449_up_it2 AS it2 WHERE (it2.id = mi_idx.info_type_id));

CREATE OR REPLACE TEMP VIEW ya_28a_rewriteYa1449_up_mk AS
SELECT mk.*
FROM ya_28a_rewriteYa1449_base_mk AS mk
WHERE EXISTS (SELECT 1 FROM ya_28a_rewriteYa1449_up_t AS t WHERE (t.id = mk.movie_id))
  AND EXISTS (SELECT 1 FROM ya_28a_rewriteYa1449_up_cc AS cc WHERE (mk.movie_id = cc.movie_id))
  AND EXISTS (SELECT 1 FROM ya_28a_rewriteYa1449_up_mc AS mc WHERE (mk.movie_id = mc.movie_id))
  AND EXISTS (SELECT 1 FROM ya_28a_rewriteYa1449_up_mi AS mi WHERE (mk.movie_id = mi.movie_id))
  AND EXISTS (SELECT 1 FROM ya_28a_rewriteYa1449_up_mi_idx AS mi_idx WHERE (mk.movie_id = mi_idx.movie_id));

CREATE OR REPLACE TEMP VIEW ya_28a_rewriteYa1449_up_k AS
SELECT k.*
FROM ya_28a_rewriteYa1449_base_k AS k
WHERE EXISTS (SELECT 1 FROM ya_28a_rewriteYa1449_up_mk AS mk WHERE (k.id = mk.keyword_id));

CREATE OR REPLACE TEMP VIEW ya_28a_rewriteYa1449_down_k AS
SELECT k.*
FROM ya_28a_rewriteYa1449_up_k AS k;

CREATE OR REPLACE TEMP VIEW ya_28a_rewriteYa1449_down_mk AS
SELECT mk.*
FROM ya_28a_rewriteYa1449_up_mk AS mk
WHERE EXISTS (SELECT 1 FROM ya_28a_rewriteYa1449_down_k AS k WHERE (k.id = mk.keyword_id));

CREATE OR REPLACE TEMP VIEW ya_28a_rewriteYa1449_down_t AS
SELECT t.*
FROM ya_28a_rewriteYa1449_up_t AS t
WHERE EXISTS (SELECT 1 FROM ya_28a_rewriteYa1449_down_mk AS mk WHERE (t.id = mk.movie_id));

CREATE OR REPLACE TEMP VIEW ya_28a_rewriteYa1449_down_cc AS
SELECT cc.*
FROM ya_28a_rewriteYa1449_up_cc AS cc
WHERE EXISTS (SELECT 1 FROM ya_28a_rewriteYa1449_down_mk AS mk WHERE (mk.movie_id = cc.movie_id));

CREATE OR REPLACE TEMP VIEW ya_28a_rewriteYa1449_down_mc AS
SELECT mc.*
FROM ya_28a_rewriteYa1449_up_mc AS mc
WHERE EXISTS (SELECT 1 FROM ya_28a_rewriteYa1449_down_mk AS mk WHERE (mk.movie_id = mc.movie_id));

CREATE OR REPLACE TEMP VIEW ya_28a_rewriteYa1449_down_mi AS
SELECT mi.*
FROM ya_28a_rewriteYa1449_up_mi AS mi
WHERE EXISTS (SELECT 1 FROM ya_28a_rewriteYa1449_down_mk AS mk WHERE (mk.movie_id = mi.movie_id));

CREATE OR REPLACE TEMP VIEW ya_28a_rewriteYa1449_down_mi_idx AS
SELECT mi_idx.*
FROM ya_28a_rewriteYa1449_up_mi_idx AS mi_idx
WHERE EXISTS (SELECT 1 FROM ya_28a_rewriteYa1449_down_mk AS mk WHERE (mk.movie_id = mi_idx.movie_id));

CREATE OR REPLACE TEMP VIEW ya_28a_rewriteYa1449_down_kt AS
SELECT kt.*
FROM ya_28a_rewriteYa1449_up_kt AS kt
WHERE EXISTS (SELECT 1 FROM ya_28a_rewriteYa1449_down_t AS t WHERE (kt.id = t.kind_id));

CREATE OR REPLACE TEMP VIEW ya_28a_rewriteYa1449_down_cct2 AS
SELECT cct2.*
FROM ya_28a_rewriteYa1449_up_cct2 AS cct2
WHERE EXISTS (SELECT 1 FROM ya_28a_rewriteYa1449_down_cc AS cc WHERE (cct2.id = cc.status_id));

CREATE OR REPLACE TEMP VIEW ya_28a_rewriteYa1449_down_cct1 AS
SELECT cct1.*
FROM ya_28a_rewriteYa1449_up_cct1 AS cct1
WHERE EXISTS (SELECT 1 FROM ya_28a_rewriteYa1449_down_cc AS cc WHERE (cct1.id = cc.subject_id));

CREATE OR REPLACE TEMP VIEW ya_28a_rewriteYa1449_down_cn AS
SELECT cn.*
FROM ya_28a_rewriteYa1449_up_cn AS cn
WHERE EXISTS (SELECT 1 FROM ya_28a_rewriteYa1449_down_mc AS mc WHERE (cn.id = mc.company_id));

CREATE OR REPLACE TEMP VIEW ya_28a_rewriteYa1449_down_ct AS
SELECT ct.*
FROM ya_28a_rewriteYa1449_up_ct AS ct
WHERE EXISTS (SELECT 1 FROM ya_28a_rewriteYa1449_down_mc AS mc WHERE (ct.id = mc.company_type_id));

CREATE OR REPLACE TEMP VIEW ya_28a_rewriteYa1449_down_it1 AS
SELECT it1.*
FROM ya_28a_rewriteYa1449_up_it1 AS it1
WHERE EXISTS (SELECT 1 FROM ya_28a_rewriteYa1449_down_mi AS mi WHERE (it1.id = mi.info_type_id));

CREATE OR REPLACE TEMP VIEW ya_28a_rewriteYa1449_down_it2 AS
SELECT it2.*
FROM ya_28a_rewriteYa1449_up_it2 AS it2
WHERE EXISTS (SELECT 1 FROM ya_28a_rewriteYa1449_down_mi_idx AS mi_idx WHERE (it2.id = mi_idx.info_type_id));

CREATE OR REPLACE TEMP VIEW ya_28a_rewriteYa1449_r3_base_cc AS
SELECT cc.movie_id AS cc__movie_id,
       cc.subject_id AS cc__subject_id,
       cc.status_id AS cc__status_id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_28a_rewriteYa1449_down_cc AS cc
GROUP BY cc.movie_id, cc.subject_id, cc.status_id;

CREATE OR REPLACE TEMP VIEW ya_28a_rewriteYa1449_r3_base_cct1 AS
SELECT cct1.id AS cct1__id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_28a_rewriteYa1449_down_cct1 AS cct1
GROUP BY cct1.id;

CREATE OR REPLACE TEMP VIEW ya_28a_rewriteYa1449_r3_base_cct2 AS
SELECT cct2.id AS cct2__id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_28a_rewriteYa1449_down_cct2 AS cct2
GROUP BY cct2.id;

CREATE OR REPLACE TEMP VIEW ya_28a_rewriteYa1449_r3_base_cn AS
SELECT cn.id AS cn__id,
       cn.name AS cn__name,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_28a_rewriteYa1449_down_cn AS cn
GROUP BY cn.id, cn.name;

CREATE OR REPLACE TEMP VIEW ya_28a_rewriteYa1449_r3_base_ct AS
SELECT ct.id AS ct__id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_28a_rewriteYa1449_down_ct AS ct
GROUP BY ct.id;

CREATE OR REPLACE TEMP VIEW ya_28a_rewriteYa1449_r3_base_it1 AS
SELECT it1.id AS it1__id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_28a_rewriteYa1449_down_it1 AS it1
GROUP BY it1.id;

CREATE OR REPLACE TEMP VIEW ya_28a_rewriteYa1449_r3_base_it2 AS
SELECT it2.id AS it2__id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_28a_rewriteYa1449_down_it2 AS it2
GROUP BY it2.id;

CREATE OR REPLACE TEMP VIEW ya_28a_rewriteYa1449_r3_base_k AS
SELECT k.id AS k__id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_28a_rewriteYa1449_down_k AS k
GROUP BY k.id;

CREATE OR REPLACE TEMP VIEW ya_28a_rewriteYa1449_r3_base_kt AS
SELECT kt.id AS kt__id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_28a_rewriteYa1449_down_kt AS kt
GROUP BY kt.id;

CREATE OR REPLACE TEMP VIEW ya_28a_rewriteYa1449_r3_base_mc AS
SELECT mc.movie_id AS mc__movie_id,
       mc.company_type_id AS mc__company_type_id,
       mc.company_id AS mc__company_id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_28a_rewriteYa1449_down_mc AS mc
GROUP BY mc.movie_id, mc.company_type_id, mc.company_id;

CREATE OR REPLACE TEMP VIEW ya_28a_rewriteYa1449_r3_base_mi AS
SELECT mi.movie_id AS mi__movie_id,
       mi.info_type_id AS mi__info_type_id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_28a_rewriteYa1449_down_mi AS mi
GROUP BY mi.movie_id, mi.info_type_id;

CREATE OR REPLACE TEMP VIEW ya_28a_rewriteYa1449_r3_base_mi_idx AS
SELECT mi_idx.movie_id AS mi_idx__movie_id,
       mi_idx.info_type_id AS mi_idx__info_type_id,
       mi_idx.info AS mi_idx__info,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_28a_rewriteYa1449_down_mi_idx AS mi_idx
GROUP BY mi_idx.movie_id, mi_idx.info_type_id, mi_idx.info;

CREATE OR REPLACE TEMP VIEW ya_28a_rewriteYa1449_r3_base_mk AS
SELECT mk.movie_id AS mk__movie_id,
       mk.keyword_id AS mk__keyword_id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_28a_rewriteYa1449_down_mk AS mk
GROUP BY mk.movie_id, mk.keyword_id;

CREATE OR REPLACE TEMP VIEW ya_28a_rewriteYa1449_r3_base_t AS
SELECT t.kind_id AS t__kind_id,
       t.id AS t__id,
       t.title AS t__title,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_28a_rewriteYa1449_down_t AS t
GROUP BY t.kind_id, t.id, t.title;

CREATE OR REPLACE TEMP VIEW ya_28a_rewriteYa1449_r3_join_1 AS
SELECT round3_left.t__title AS t__title,
       round3_left.t__id AS t__id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_28a_rewriteYa1449_r3_base_t AS round3_left
JOIN ya_28a_rewriteYa1449_r3_base_kt AS round3_right
  ON (round3_right.kt__id = round3_left.t__kind_id)
GROUP BY round3_left.t__title, round3_left.t__id;

CREATE OR REPLACE TEMP VIEW ya_28a_rewriteYa1449_r3_join_2 AS
SELECT round3_right.t__title AS t__title,
       round3_right.t__id AS t__id,
       round3_left.mk__movie_id AS mk__movie_id,
       round3_left.mk__keyword_id AS mk__keyword_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_28a_rewriteYa1449_r3_base_mk AS round3_left
JOIN ya_28a_rewriteYa1449_r3_join_1 AS round3_right
  ON (round3_right.t__id = round3_left.mk__movie_id)
GROUP BY round3_right.t__title, round3_right.t__id, round3_left.mk__movie_id, round3_left.mk__keyword_id;

CREATE OR REPLACE TEMP VIEW ya_28a_rewriteYa1449_r3_join_3 AS
SELECT round3_left.cc__movie_id AS cc__movie_id,
       round3_left.cc__subject_id AS cc__subject_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_28a_rewriteYa1449_r3_base_cc AS round3_left
JOIN ya_28a_rewriteYa1449_r3_base_cct2 AS round3_right
  ON (round3_right.cct2__id = round3_left.cc__status_id)
GROUP BY round3_left.cc__movie_id, round3_left.cc__subject_id;

CREATE OR REPLACE TEMP VIEW ya_28a_rewriteYa1449_r3_join_4 AS
SELECT round3_left.cc__movie_id AS cc__movie_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_28a_rewriteYa1449_r3_join_3 AS round3_left
JOIN ya_28a_rewriteYa1449_r3_base_cct1 AS round3_right
  ON (round3_right.cct1__id = round3_left.cc__subject_id)
GROUP BY round3_left.cc__movie_id;

CREATE OR REPLACE TEMP VIEW ya_28a_rewriteYa1449_r3_join_5 AS
SELECT round3_left.t__title AS t__title,
       round3_left.t__id AS t__id,
       round3_left.mk__movie_id AS mk__movie_id,
       round3_right.cc__movie_id AS cc__movie_id,
       round3_left.mk__keyword_id AS mk__keyword_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_28a_rewriteYa1449_r3_join_2 AS round3_left
JOIN ya_28a_rewriteYa1449_r3_join_4 AS round3_right
  ON (round3_left.t__id = round3_right.cc__movie_id)
 AND (round3_left.mk__movie_id = round3_right.cc__movie_id)
GROUP BY round3_left.t__title, round3_left.t__id, round3_left.mk__movie_id, round3_right.cc__movie_id, round3_left.mk__keyword_id;

CREATE OR REPLACE TEMP VIEW ya_28a_rewriteYa1449_r3_join_6 AS
SELECT round3_right.cn__name AS cn__name,
       round3_left.mc__movie_id AS mc__movie_id,
       round3_left.mc__company_type_id AS mc__company_type_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_28a_rewriteYa1449_r3_base_mc AS round3_left
JOIN ya_28a_rewriteYa1449_r3_base_cn AS round3_right
  ON (round3_right.cn__id = round3_left.mc__company_id)
GROUP BY round3_right.cn__name, round3_left.mc__movie_id, round3_left.mc__company_type_id;

CREATE OR REPLACE TEMP VIEW ya_28a_rewriteYa1449_r3_join_7 AS
SELECT round3_left.cn__name AS cn__name,
       round3_left.mc__movie_id AS mc__movie_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_28a_rewriteYa1449_r3_join_6 AS round3_left
JOIN ya_28a_rewriteYa1449_r3_base_ct AS round3_right
  ON (round3_right.ct__id = round3_left.mc__company_type_id)
GROUP BY round3_left.cn__name, round3_left.mc__movie_id;

CREATE OR REPLACE TEMP VIEW ya_28a_rewriteYa1449_r3_join_8 AS
SELECT round3_right.cn__name AS cn__name,
       round3_left.t__title AS t__title,
       round3_left.t__id AS t__id,
       round3_left.mk__movie_id AS mk__movie_id,
       round3_right.mc__movie_id AS mc__movie_id,
       round3_left.cc__movie_id AS cc__movie_id,
       round3_left.mk__keyword_id AS mk__keyword_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_28a_rewriteYa1449_r3_join_5 AS round3_left
JOIN ya_28a_rewriteYa1449_r3_join_7 AS round3_right
  ON (round3_left.t__id = round3_right.mc__movie_id)
 AND (round3_left.mk__movie_id = round3_right.mc__movie_id)
 AND (round3_right.mc__movie_id = round3_left.cc__movie_id)
GROUP BY round3_right.cn__name, round3_left.t__title, round3_left.t__id, round3_left.mk__movie_id, round3_right.mc__movie_id, round3_left.cc__movie_id, round3_left.mk__keyword_id;

CREATE OR REPLACE TEMP VIEW ya_28a_rewriteYa1449_r3_join_9 AS
SELECT round3_left.mi__movie_id AS mi__movie_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_28a_rewriteYa1449_r3_base_mi AS round3_left
JOIN ya_28a_rewriteYa1449_r3_base_it1 AS round3_right
  ON (round3_right.it1__id = round3_left.mi__info_type_id)
GROUP BY round3_left.mi__movie_id;

CREATE OR REPLACE TEMP VIEW ya_28a_rewriteYa1449_r3_join_10 AS
SELECT round3_left.cn__name AS cn__name,
       round3_left.t__title AS t__title,
       round3_left.t__id AS t__id,
       round3_left.mk__movie_id AS mk__movie_id,
       round3_right.mi__movie_id AS mi__movie_id,
       round3_left.mc__movie_id AS mc__movie_id,
       round3_left.cc__movie_id AS cc__movie_id,
       round3_left.mk__keyword_id AS mk__keyword_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_28a_rewriteYa1449_r3_join_8 AS round3_left
JOIN ya_28a_rewriteYa1449_r3_join_9 AS round3_right
  ON (round3_left.t__id = round3_right.mi__movie_id)
 AND (round3_left.mk__movie_id = round3_right.mi__movie_id)
 AND (round3_right.mi__movie_id = round3_left.mc__movie_id)
 AND (round3_right.mi__movie_id = round3_left.cc__movie_id)
GROUP BY round3_left.cn__name, round3_left.t__title, round3_left.t__id, round3_left.mk__movie_id, round3_right.mi__movie_id, round3_left.mc__movie_id, round3_left.cc__movie_id, round3_left.mk__keyword_id;

CREATE OR REPLACE TEMP VIEW ya_28a_rewriteYa1449_r3_join_11 AS
SELECT round3_left.mi_idx__info AS mi_idx__info,
       round3_left.mi_idx__movie_id AS mi_idx__movie_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_28a_rewriteYa1449_r3_base_mi_idx AS round3_left
JOIN ya_28a_rewriteYa1449_r3_base_it2 AS round3_right
  ON (round3_right.it2__id = round3_left.mi_idx__info_type_id)
GROUP BY round3_left.mi_idx__info, round3_left.mi_idx__movie_id;

CREATE OR REPLACE TEMP VIEW ya_28a_rewriteYa1449_r3_join_12 AS
SELECT round3_left.cn__name AS cn__name,
       round3_right.mi_idx__info AS mi_idx__info,
       round3_left.t__title AS t__title,
       round3_left.mk__keyword_id AS mk__keyword_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_28a_rewriteYa1449_r3_join_10 AS round3_left
JOIN ya_28a_rewriteYa1449_r3_join_11 AS round3_right
  ON (round3_left.t__id = round3_right.mi_idx__movie_id)
 AND (round3_left.mk__movie_id = round3_right.mi_idx__movie_id)
 AND (round3_left.mi__movie_id = round3_right.mi_idx__movie_id)
 AND (round3_left.mc__movie_id = round3_right.mi_idx__movie_id)
 AND (round3_right.mi_idx__movie_id = round3_left.cc__movie_id)
GROUP BY round3_left.cn__name, round3_right.mi_idx__info, round3_left.t__title, round3_left.mk__keyword_id;

CREATE OR REPLACE TEMP VIEW ya_28a_rewriteYa1449_r3_join_13 AS
SELECT round3_right.cn__name AS cn__name,
       round3_right.mi_idx__info AS mi_idx__info,
       round3_right.t__title AS t__title,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_28a_rewriteYa1449_r3_base_k AS round3_left
JOIN ya_28a_rewriteYa1449_r3_join_12 AS round3_right
  ON (round3_left.k__id = round3_right.mk__keyword_id)
GROUP BY round3_right.cn__name, round3_right.mi_idx__info, round3_right.t__title;

SELECT round3_result.cn__name AS name,
       round3_result.mi_idx__info AS info,
       round3_result.t__title AS title,
       round3_result.annot AS record_count
FROM ya_28a_rewriteYa1449_r3_join_13 AS round3_result;
