-- DuckDB SUM(1) Yannakakis-style two-pass reducer generated from job_agg/11a.sql.

-- Source variant: query/job_duckdb/11a/rewriteYa0.sql

CREATE OR REPLACE TEMP VIEW ya_11a_rewriteYa0_base_cn AS
SELECT cn.*
FROM company_name AS cn
WHERE (cn.country_code !='[pl]')
  AND ((cn.name LIKE '%Film%'
       OR cn.name LIKE '%Warner%'));

CREATE OR REPLACE TEMP VIEW ya_11a_rewriteYa0_base_ct AS
SELECT ct.*
FROM company_type AS ct
WHERE (ct.kind ='production companies');

CREATE OR REPLACE TEMP VIEW ya_11a_rewriteYa0_base_k AS
SELECT k.*
FROM keyword AS k
WHERE (k.keyword ='sequel');

CREATE OR REPLACE TEMP VIEW ya_11a_rewriteYa0_base_lt AS
SELECT lt.*
FROM link_type AS lt
WHERE (lt.link LIKE '%follow%');

CREATE OR REPLACE TEMP VIEW ya_11a_rewriteYa0_base_mc AS
SELECT mc.*
FROM movie_companies AS mc
WHERE (mc.note IS NULL);

CREATE OR REPLACE TEMP VIEW ya_11a_rewriteYa0_base_mk AS
SELECT mk.*
FROM movie_keyword AS mk;

CREATE OR REPLACE TEMP VIEW ya_11a_rewriteYa0_base_ml AS
SELECT ml.*
FROM movie_link AS ml;

CREATE OR REPLACE TEMP VIEW ya_11a_rewriteYa0_base_t AS
SELECT t.*
FROM title AS t
WHERE (t.production_year BETWEEN 1950 AND 2000);

CREATE OR REPLACE TEMP VIEW ya_11a_rewriteYa0_up_k AS
SELECT k.*
FROM ya_11a_rewriteYa0_base_k AS k;

CREATE OR REPLACE TEMP VIEW ya_11a_rewriteYa0_up_mk AS
SELECT mk.*
FROM ya_11a_rewriteYa0_base_mk AS mk
WHERE EXISTS (SELECT 1 FROM ya_11a_rewriteYa0_up_k AS k WHERE (mk.keyword_id = k.id));

CREATE OR REPLACE TEMP VIEW ya_11a_rewriteYa0_up_lt AS
SELECT lt.*
FROM ya_11a_rewriteYa0_base_lt AS lt;

CREATE OR REPLACE TEMP VIEW ya_11a_rewriteYa0_up_ml AS
SELECT ml.*
FROM ya_11a_rewriteYa0_base_ml AS ml
WHERE EXISTS (SELECT 1 FROM ya_11a_rewriteYa0_up_lt AS lt WHERE (lt.id = ml.link_type_id));

CREATE OR REPLACE TEMP VIEW ya_11a_rewriteYa0_up_t AS
SELECT t.*
FROM ya_11a_rewriteYa0_base_t AS t;

CREATE OR REPLACE TEMP VIEW ya_11a_rewriteYa0_up_ct AS
SELECT ct.*
FROM ya_11a_rewriteYa0_base_ct AS ct;

CREATE OR REPLACE TEMP VIEW ya_11a_rewriteYa0_up_mc AS
SELECT mc.*
FROM ya_11a_rewriteYa0_base_mc AS mc
WHERE EXISTS (SELECT 1 FROM ya_11a_rewriteYa0_up_mk AS mk WHERE (mk.movie_id = mc.movie_id))
  AND EXISTS (SELECT 1 FROM ya_11a_rewriteYa0_up_ml AS ml WHERE (ml.movie_id = mc.movie_id))
  AND EXISTS (SELECT 1 FROM ya_11a_rewriteYa0_up_t AS t WHERE (t.id = mc.movie_id))
  AND EXISTS (SELECT 1 FROM ya_11a_rewriteYa0_up_ct AS ct WHERE (mc.company_type_id = ct.id));

CREATE OR REPLACE TEMP VIEW ya_11a_rewriteYa0_up_cn AS
SELECT cn.*
FROM ya_11a_rewriteYa0_base_cn AS cn
WHERE EXISTS (SELECT 1 FROM ya_11a_rewriteYa0_up_mc AS mc WHERE (mc.company_id = cn.id));

CREATE OR REPLACE TEMP VIEW ya_11a_rewriteYa0_down_cn AS
SELECT cn.*
FROM ya_11a_rewriteYa0_up_cn AS cn;

CREATE OR REPLACE TEMP VIEW ya_11a_rewriteYa0_down_mc AS
SELECT mc.*
FROM ya_11a_rewriteYa0_up_mc AS mc
WHERE EXISTS (SELECT 1 FROM ya_11a_rewriteYa0_down_cn AS cn WHERE (mc.company_id = cn.id));

CREATE OR REPLACE TEMP VIEW ya_11a_rewriteYa0_down_mk AS
SELECT mk.*
FROM ya_11a_rewriteYa0_up_mk AS mk
WHERE EXISTS (SELECT 1 FROM ya_11a_rewriteYa0_down_mc AS mc WHERE (mk.movie_id = mc.movie_id));

CREATE OR REPLACE TEMP VIEW ya_11a_rewriteYa0_down_ml AS
SELECT ml.*
FROM ya_11a_rewriteYa0_up_ml AS ml
WHERE EXISTS (SELECT 1 FROM ya_11a_rewriteYa0_down_mc AS mc WHERE (ml.movie_id = mc.movie_id));

CREATE OR REPLACE TEMP VIEW ya_11a_rewriteYa0_down_t AS
SELECT t.*
FROM ya_11a_rewriteYa0_up_t AS t
WHERE EXISTS (SELECT 1 FROM ya_11a_rewriteYa0_down_mc AS mc WHERE (t.id = mc.movie_id));

CREATE OR REPLACE TEMP VIEW ya_11a_rewriteYa0_down_ct AS
SELECT ct.*
FROM ya_11a_rewriteYa0_up_ct AS ct
WHERE EXISTS (SELECT 1 FROM ya_11a_rewriteYa0_down_mc AS mc WHERE (mc.company_type_id = ct.id));

CREATE OR REPLACE TEMP VIEW ya_11a_rewriteYa0_down_k AS
SELECT k.*
FROM ya_11a_rewriteYa0_up_k AS k
WHERE EXISTS (SELECT 1 FROM ya_11a_rewriteYa0_down_mk AS mk WHERE (mk.keyword_id = k.id));

CREATE OR REPLACE TEMP VIEW ya_11a_rewriteYa0_down_lt AS
SELECT lt.*
FROM ya_11a_rewriteYa0_up_lt AS lt
WHERE EXISTS (SELECT 1 FROM ya_11a_rewriteYa0_down_ml AS ml WHERE (lt.id = ml.link_type_id));

CREATE OR REPLACE TEMP VIEW ya_11a_rewriteYa0_r3_base_cn AS
SELECT cn.id AS cn__id,
       cn.name AS cn__name,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_11a_rewriteYa0_down_cn AS cn
GROUP BY cn.id, cn.name;

CREATE OR REPLACE TEMP VIEW ya_11a_rewriteYa0_r3_base_ct AS
SELECT ct.id AS ct__id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_11a_rewriteYa0_down_ct AS ct
GROUP BY ct.id;

CREATE OR REPLACE TEMP VIEW ya_11a_rewriteYa0_r3_base_k AS
SELECT k.id AS k__id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_11a_rewriteYa0_down_k AS k
GROUP BY k.id;

CREATE OR REPLACE TEMP VIEW ya_11a_rewriteYa0_r3_base_lt AS
SELECT lt.id AS lt__id,
       lt.link AS lt__link,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_11a_rewriteYa0_down_lt AS lt
GROUP BY lt.id, lt.link;

CREATE OR REPLACE TEMP VIEW ya_11a_rewriteYa0_r3_base_mc AS
SELECT mc.movie_id AS mc__movie_id,
       mc.company_type_id AS mc__company_type_id,
       mc.company_id AS mc__company_id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_11a_rewriteYa0_down_mc AS mc
GROUP BY mc.movie_id, mc.company_type_id, mc.company_id;

CREATE OR REPLACE TEMP VIEW ya_11a_rewriteYa0_r3_base_mk AS
SELECT mk.movie_id AS mk__movie_id,
       mk.keyword_id AS mk__keyword_id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_11a_rewriteYa0_down_mk AS mk
GROUP BY mk.movie_id, mk.keyword_id;

CREATE OR REPLACE TEMP VIEW ya_11a_rewriteYa0_r3_base_ml AS
SELECT ml.link_type_id AS ml__link_type_id,
       ml.movie_id AS ml__movie_id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_11a_rewriteYa0_down_ml AS ml
GROUP BY ml.link_type_id, ml.movie_id;

CREATE OR REPLACE TEMP VIEW ya_11a_rewriteYa0_r3_base_t AS
SELECT t.id AS t__id,
       t.title AS t__title,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_11a_rewriteYa0_down_t AS t
GROUP BY t.id, t.title;

CREATE OR REPLACE TEMP VIEW ya_11a_rewriteYa0_r3_join_1 AS
SELECT round3_left.mk__movie_id AS mk__movie_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_11a_rewriteYa0_r3_base_mk AS round3_left
JOIN ya_11a_rewriteYa0_r3_base_k AS round3_right
  ON (round3_left.mk__keyword_id = round3_right.k__id)
GROUP BY round3_left.mk__movie_id;

CREATE OR REPLACE TEMP VIEW ya_11a_rewriteYa0_r3_join_2 AS
SELECT round3_right.mk__movie_id AS mk__movie_id,
       round3_left.mc__movie_id AS mc__movie_id,
       round3_left.mc__company_type_id AS mc__company_type_id,
       round3_left.mc__company_id AS mc__company_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_11a_rewriteYa0_r3_base_mc AS round3_left
JOIN ya_11a_rewriteYa0_r3_join_1 AS round3_right
  ON (round3_right.mk__movie_id = round3_left.mc__movie_id)
GROUP BY round3_right.mk__movie_id, round3_left.mc__movie_id, round3_left.mc__company_type_id, round3_left.mc__company_id;

CREATE OR REPLACE TEMP VIEW ya_11a_rewriteYa0_r3_join_3 AS
SELECT round3_right.lt__link AS lt__link,
       round3_left.ml__movie_id AS ml__movie_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_11a_rewriteYa0_r3_base_ml AS round3_left
JOIN ya_11a_rewriteYa0_r3_base_lt AS round3_right
  ON (round3_right.lt__id = round3_left.ml__link_type_id)
GROUP BY round3_right.lt__link, round3_left.ml__movie_id;

CREATE OR REPLACE TEMP VIEW ya_11a_rewriteYa0_r3_join_4 AS
SELECT round3_right.lt__link AS lt__link,
       round3_right.ml__movie_id AS ml__movie_id,
       round3_left.mk__movie_id AS mk__movie_id,
       round3_left.mc__movie_id AS mc__movie_id,
       round3_left.mc__company_type_id AS mc__company_type_id,
       round3_left.mc__company_id AS mc__company_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_11a_rewriteYa0_r3_join_2 AS round3_left
JOIN ya_11a_rewriteYa0_r3_join_3 AS round3_right
  ON (round3_right.ml__movie_id = round3_left.mk__movie_id)
 AND (round3_right.ml__movie_id = round3_left.mc__movie_id)
GROUP BY round3_right.lt__link, round3_right.ml__movie_id, round3_left.mk__movie_id, round3_left.mc__movie_id, round3_left.mc__company_type_id, round3_left.mc__company_id;

CREATE OR REPLACE TEMP VIEW ya_11a_rewriteYa0_r3_join_5 AS
SELECT round3_left.lt__link AS lt__link,
       round3_right.t__title AS t__title,
       round3_left.mc__company_type_id AS mc__company_type_id,
       round3_left.mc__company_id AS mc__company_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_11a_rewriteYa0_r3_join_4 AS round3_left
JOIN ya_11a_rewriteYa0_r3_base_t AS round3_right
  ON (round3_left.ml__movie_id = round3_right.t__id)
 AND (round3_right.t__id = round3_left.mk__movie_id)
 AND (round3_right.t__id = round3_left.mc__movie_id)
GROUP BY round3_left.lt__link, round3_right.t__title, round3_left.mc__company_type_id, round3_left.mc__company_id;

CREATE OR REPLACE TEMP VIEW ya_11a_rewriteYa0_r3_join_6 AS
SELECT round3_left.lt__link AS lt__link,
       round3_left.t__title AS t__title,
       round3_left.mc__company_id AS mc__company_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_11a_rewriteYa0_r3_join_5 AS round3_left
JOIN ya_11a_rewriteYa0_r3_base_ct AS round3_right
  ON (round3_left.mc__company_type_id = round3_right.ct__id)
GROUP BY round3_left.lt__link, round3_left.t__title, round3_left.mc__company_id;

CREATE OR REPLACE TEMP VIEW ya_11a_rewriteYa0_r3_join_7 AS
SELECT round3_left.cn__name AS cn__name,
       round3_right.lt__link AS lt__link,
       round3_right.t__title AS t__title,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_11a_rewriteYa0_r3_base_cn AS round3_left
JOIN ya_11a_rewriteYa0_r3_join_6 AS round3_right
  ON (round3_right.mc__company_id = round3_left.cn__id)
GROUP BY round3_left.cn__name, round3_right.lt__link, round3_right.t__title;

SELECT round3_result.cn__name AS name,
       round3_result.lt__link AS link,
       round3_result.t__title AS title,
       round3_result.annot AS record_count
FROM ya_11a_rewriteYa0_r3_join_7 AS round3_result;
