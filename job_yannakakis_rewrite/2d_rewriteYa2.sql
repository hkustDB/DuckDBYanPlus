-- DuckDB SUM(1) Yannakakis-style two-pass reducer generated from job_agg/2d.sql.

-- Source variant: query/job_duckdb/2d/rewriteYa2.sql

CREATE OR REPLACE TEMP VIEW ya_2d_rewriteYa2_base_cn AS
SELECT cn.*
FROM company_name AS cn
WHERE (cn.country_code ='[us]');

CREATE OR REPLACE TEMP VIEW ya_2d_rewriteYa2_base_k AS
SELECT k.*
FROM keyword AS k
WHERE (k.keyword ='character-name-in-title');

CREATE OR REPLACE TEMP VIEW ya_2d_rewriteYa2_base_mc AS
SELECT mc.*
FROM movie_companies AS mc;

CREATE OR REPLACE TEMP VIEW ya_2d_rewriteYa2_base_mk AS
SELECT mk.*
FROM movie_keyword AS mk;

CREATE OR REPLACE TEMP VIEW ya_2d_rewriteYa2_base_t AS
SELECT t.*
FROM title AS t;

CREATE OR REPLACE TEMP VIEW ya_2d_rewriteYa2_up_cn AS
SELECT cn.*
FROM ya_2d_rewriteYa2_base_cn AS cn;

CREATE OR REPLACE TEMP VIEW ya_2d_rewriteYa2_up_k AS
SELECT k.*
FROM ya_2d_rewriteYa2_base_k AS k;

CREATE OR REPLACE TEMP VIEW ya_2d_rewriteYa2_up_mk AS
SELECT mk.*
FROM ya_2d_rewriteYa2_base_mk AS mk
WHERE EXISTS (SELECT 1 FROM ya_2d_rewriteYa2_up_k AS k WHERE (mk.keyword_id = k.id));

CREATE OR REPLACE TEMP VIEW ya_2d_rewriteYa2_up_t AS
SELECT t.*
FROM ya_2d_rewriteYa2_base_t AS t;

CREATE OR REPLACE TEMP VIEW ya_2d_rewriteYa2_up_mc AS
SELECT mc.*
FROM ya_2d_rewriteYa2_base_mc AS mc
WHERE EXISTS (SELECT 1 FROM ya_2d_rewriteYa2_up_cn AS cn WHERE (cn.id = mc.company_id))
  AND EXISTS (SELECT 1 FROM ya_2d_rewriteYa2_up_mk AS mk WHERE (mc.movie_id = mk.movie_id))
  AND EXISTS (SELECT 1 FROM ya_2d_rewriteYa2_up_t AS t WHERE (mc.movie_id = t.id));

CREATE OR REPLACE TEMP VIEW ya_2d_rewriteYa2_down_mc AS
SELECT mc.*
FROM ya_2d_rewriteYa2_up_mc AS mc;

CREATE OR REPLACE TEMP VIEW ya_2d_rewriteYa2_down_cn AS
SELECT cn.*
FROM ya_2d_rewriteYa2_up_cn AS cn
WHERE EXISTS (SELECT 1 FROM ya_2d_rewriteYa2_down_mc AS mc WHERE (cn.id = mc.company_id));

CREATE OR REPLACE TEMP VIEW ya_2d_rewriteYa2_down_mk AS
SELECT mk.*
FROM ya_2d_rewriteYa2_up_mk AS mk
WHERE EXISTS (SELECT 1 FROM ya_2d_rewriteYa2_down_mc AS mc WHERE (mc.movie_id = mk.movie_id));

CREATE OR REPLACE TEMP VIEW ya_2d_rewriteYa2_down_t AS
SELECT t.*
FROM ya_2d_rewriteYa2_up_t AS t
WHERE EXISTS (SELECT 1 FROM ya_2d_rewriteYa2_down_mc AS mc WHERE (mc.movie_id = t.id));

CREATE OR REPLACE TEMP VIEW ya_2d_rewriteYa2_down_k AS
SELECT k.*
FROM ya_2d_rewriteYa2_up_k AS k
WHERE EXISTS (SELECT 1 FROM ya_2d_rewriteYa2_down_mk AS mk WHERE (mk.keyword_id = k.id));

CREATE OR REPLACE TEMP VIEW ya_2d_rewriteYa2_r3_base_cn AS
SELECT cn.id AS cn__id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_2d_rewriteYa2_down_cn AS cn
GROUP BY cn.id;

CREATE OR REPLACE TEMP VIEW ya_2d_rewriteYa2_r3_base_k AS
SELECT k.id AS k__id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_2d_rewriteYa2_down_k AS k
GROUP BY k.id;

CREATE OR REPLACE TEMP VIEW ya_2d_rewriteYa2_r3_base_mc AS
SELECT mc.company_id AS mc__company_id,
       mc.movie_id AS mc__movie_id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_2d_rewriteYa2_down_mc AS mc
GROUP BY mc.company_id, mc.movie_id;

CREATE OR REPLACE TEMP VIEW ya_2d_rewriteYa2_r3_base_mk AS
SELECT mk.movie_id AS mk__movie_id,
       mk.keyword_id AS mk__keyword_id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_2d_rewriteYa2_down_mk AS mk
GROUP BY mk.movie_id, mk.keyword_id;

CREATE OR REPLACE TEMP VIEW ya_2d_rewriteYa2_r3_base_t AS
SELECT t.id AS t__id,
       t.title AS t__title,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_2d_rewriteYa2_down_t AS t
GROUP BY t.id, t.title;

CREATE OR REPLACE TEMP VIEW ya_2d_rewriteYa2_r3_join_1 AS
SELECT round3_left.mc__movie_id AS mc__movie_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_2d_rewriteYa2_r3_base_mc AS round3_left
JOIN ya_2d_rewriteYa2_r3_base_cn AS round3_right
  ON (round3_right.cn__id = round3_left.mc__company_id)
GROUP BY round3_left.mc__movie_id;

CREATE OR REPLACE TEMP VIEW ya_2d_rewriteYa2_r3_join_2 AS
SELECT round3_left.mk__movie_id AS mk__movie_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_2d_rewriteYa2_r3_base_mk AS round3_left
JOIN ya_2d_rewriteYa2_r3_base_k AS round3_right
  ON (round3_left.mk__keyword_id = round3_right.k__id)
GROUP BY round3_left.mk__movie_id;

CREATE OR REPLACE TEMP VIEW ya_2d_rewriteYa2_r3_join_3 AS
SELECT round3_left.mc__movie_id AS mc__movie_id,
       round3_right.mk__movie_id AS mk__movie_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_2d_rewriteYa2_r3_join_1 AS round3_left
JOIN ya_2d_rewriteYa2_r3_join_2 AS round3_right
  ON (round3_left.mc__movie_id = round3_right.mk__movie_id)
GROUP BY round3_left.mc__movie_id, round3_right.mk__movie_id;

CREATE OR REPLACE TEMP VIEW ya_2d_rewriteYa2_r3_join_4 AS
SELECT round3_right.t__title AS t__title,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_2d_rewriteYa2_r3_join_3 AS round3_left
JOIN ya_2d_rewriteYa2_r3_base_t AS round3_right
  ON (round3_left.mc__movie_id = round3_right.t__id)
 AND (round3_right.t__id = round3_left.mk__movie_id)
GROUP BY round3_right.t__title;

SELECT round3_result.t__title AS title,
       round3_result.annot AS record_count
FROM ya_2d_rewriteYa2_r3_join_4 AS round3_result;
