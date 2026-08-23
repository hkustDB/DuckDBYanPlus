-- DuckDB SUM(1) Yannakakis-style two-pass reducer generated from job_agg/10c.sql.

-- Source variant: query/job_duckdb/10c/rewriteYa8.sql

CREATE OR REPLACE TEMP VIEW ya_10c_rewriteYa8_base_chn AS
SELECT chn.*
FROM char_name AS chn;

CREATE OR REPLACE TEMP VIEW ya_10c_rewriteYa8_base_ci AS
SELECT ci.*
FROM cast_info AS ci
WHERE (ci.note LIKE '%(producer)%');

CREATE OR REPLACE TEMP VIEW ya_10c_rewriteYa8_base_cn AS
SELECT cn.*
FROM company_name AS cn
WHERE (cn.country_code = '[us]');

CREATE OR REPLACE TEMP VIEW ya_10c_rewriteYa8_base_ct AS
SELECT ct.*
FROM company_type AS ct;

CREATE OR REPLACE TEMP VIEW ya_10c_rewriteYa8_base_mc AS
SELECT mc.*
FROM movie_companies AS mc;

CREATE OR REPLACE TEMP VIEW ya_10c_rewriteYa8_base_rt AS
SELECT rt.*
FROM role_type AS rt;

CREATE OR REPLACE TEMP VIEW ya_10c_rewriteYa8_base_t AS
SELECT t.*
FROM title AS t
WHERE (t.production_year > 1990);

CREATE OR REPLACE TEMP VIEW ya_10c_rewriteYa8_up_cn AS
SELECT cn.*
FROM ya_10c_rewriteYa8_base_cn AS cn;

CREATE OR REPLACE TEMP VIEW ya_10c_rewriteYa8_up_ct AS
SELECT ct.*
FROM ya_10c_rewriteYa8_base_ct AS ct;

CREATE OR REPLACE TEMP VIEW ya_10c_rewriteYa8_up_mc AS
SELECT mc.*
FROM ya_10c_rewriteYa8_base_mc AS mc
WHERE EXISTS (SELECT 1 FROM ya_10c_rewriteYa8_up_cn AS cn WHERE (cn.id = mc.company_id))
  AND EXISTS (SELECT 1 FROM ya_10c_rewriteYa8_up_ct AS ct WHERE (ct.id = mc.company_type_id));

CREATE OR REPLACE TEMP VIEW ya_10c_rewriteYa8_up_rt AS
SELECT rt.*
FROM ya_10c_rewriteYa8_base_rt AS rt;

CREATE OR REPLACE TEMP VIEW ya_10c_rewriteYa8_up_t AS
SELECT t.*
FROM ya_10c_rewriteYa8_base_t AS t;

CREATE OR REPLACE TEMP VIEW ya_10c_rewriteYa8_up_chn AS
SELECT chn.*
FROM ya_10c_rewriteYa8_base_chn AS chn;

CREATE OR REPLACE TEMP VIEW ya_10c_rewriteYa8_up_ci AS
SELECT ci.*
FROM ya_10c_rewriteYa8_base_ci AS ci
WHERE EXISTS (SELECT 1 FROM ya_10c_rewriteYa8_up_mc AS mc WHERE (ci.movie_id = mc.movie_id))
  AND EXISTS (SELECT 1 FROM ya_10c_rewriteYa8_up_rt AS rt WHERE (rt.id = ci.role_id))
  AND EXISTS (SELECT 1 FROM ya_10c_rewriteYa8_up_t AS t WHERE (t.id = ci.movie_id))
  AND EXISTS (SELECT 1 FROM ya_10c_rewriteYa8_up_chn AS chn WHERE (chn.id = ci.person_role_id));

CREATE OR REPLACE TEMP VIEW ya_10c_rewriteYa8_down_ci AS
SELECT ci.*
FROM ya_10c_rewriteYa8_up_ci AS ci;

CREATE OR REPLACE TEMP VIEW ya_10c_rewriteYa8_down_mc AS
SELECT mc.*
FROM ya_10c_rewriteYa8_up_mc AS mc
WHERE EXISTS (SELECT 1 FROM ya_10c_rewriteYa8_down_ci AS ci WHERE (ci.movie_id = mc.movie_id));

CREATE OR REPLACE TEMP VIEW ya_10c_rewriteYa8_down_rt AS
SELECT rt.*
FROM ya_10c_rewriteYa8_up_rt AS rt
WHERE EXISTS (SELECT 1 FROM ya_10c_rewriteYa8_down_ci AS ci WHERE (rt.id = ci.role_id));

CREATE OR REPLACE TEMP VIEW ya_10c_rewriteYa8_down_t AS
SELECT t.*
FROM ya_10c_rewriteYa8_up_t AS t
WHERE EXISTS (SELECT 1 FROM ya_10c_rewriteYa8_down_ci AS ci WHERE (t.id = ci.movie_id));

CREATE OR REPLACE TEMP VIEW ya_10c_rewriteYa8_down_chn AS
SELECT chn.*
FROM ya_10c_rewriteYa8_up_chn AS chn
WHERE EXISTS (SELECT 1 FROM ya_10c_rewriteYa8_down_ci AS ci WHERE (chn.id = ci.person_role_id));

CREATE OR REPLACE TEMP VIEW ya_10c_rewriteYa8_down_cn AS
SELECT cn.*
FROM ya_10c_rewriteYa8_up_cn AS cn
WHERE EXISTS (SELECT 1 FROM ya_10c_rewriteYa8_down_mc AS mc WHERE (cn.id = mc.company_id));

CREATE OR REPLACE TEMP VIEW ya_10c_rewriteYa8_down_ct AS
SELECT ct.*
FROM ya_10c_rewriteYa8_up_ct AS ct
WHERE EXISTS (SELECT 1 FROM ya_10c_rewriteYa8_down_mc AS mc WHERE (ct.id = mc.company_type_id));

CREATE OR REPLACE TEMP VIEW ya_10c_rewriteYa8_r3_base_chn AS
SELECT chn.id AS chn__id,
       chn.name AS chn__name,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_10c_rewriteYa8_down_chn AS chn
GROUP BY chn.id, chn.name;

CREATE OR REPLACE TEMP VIEW ya_10c_rewriteYa8_r3_base_ci AS
SELECT ci.movie_id AS ci__movie_id,
       ci.person_role_id AS ci__person_role_id,
       ci.role_id AS ci__role_id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_10c_rewriteYa8_down_ci AS ci
GROUP BY ci.movie_id, ci.person_role_id, ci.role_id;

CREATE OR REPLACE TEMP VIEW ya_10c_rewriteYa8_r3_base_cn AS
SELECT cn.id AS cn__id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_10c_rewriteYa8_down_cn AS cn
GROUP BY cn.id;

CREATE OR REPLACE TEMP VIEW ya_10c_rewriteYa8_r3_base_ct AS
SELECT ct.id AS ct__id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_10c_rewriteYa8_down_ct AS ct
GROUP BY ct.id;

CREATE OR REPLACE TEMP VIEW ya_10c_rewriteYa8_r3_base_mc AS
SELECT mc.movie_id AS mc__movie_id,
       mc.company_id AS mc__company_id,
       mc.company_type_id AS mc__company_type_id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_10c_rewriteYa8_down_mc AS mc
GROUP BY mc.movie_id, mc.company_id, mc.company_type_id;

CREATE OR REPLACE TEMP VIEW ya_10c_rewriteYa8_r3_base_rt AS
SELECT rt.id AS rt__id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_10c_rewriteYa8_down_rt AS rt
GROUP BY rt.id;

CREATE OR REPLACE TEMP VIEW ya_10c_rewriteYa8_r3_base_t AS
SELECT t.id AS t__id,
       t.title AS t__title,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_10c_rewriteYa8_down_t AS t
GROUP BY t.id, t.title;

CREATE OR REPLACE TEMP VIEW ya_10c_rewriteYa8_r3_join_1 AS
SELECT round3_left.mc__movie_id AS mc__movie_id,
       round3_left.mc__company_type_id AS mc__company_type_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_10c_rewriteYa8_r3_base_mc AS round3_left
JOIN ya_10c_rewriteYa8_r3_base_cn AS round3_right
  ON (round3_right.cn__id = round3_left.mc__company_id)
GROUP BY round3_left.mc__movie_id, round3_left.mc__company_type_id;

CREATE OR REPLACE TEMP VIEW ya_10c_rewriteYa8_r3_join_2 AS
SELECT round3_left.mc__movie_id AS mc__movie_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_10c_rewriteYa8_r3_join_1 AS round3_left
JOIN ya_10c_rewriteYa8_r3_base_ct AS round3_right
  ON (round3_right.ct__id = round3_left.mc__company_type_id)
GROUP BY round3_left.mc__movie_id;

CREATE OR REPLACE TEMP VIEW ya_10c_rewriteYa8_r3_join_3 AS
SELECT round3_right.mc__movie_id AS mc__movie_id,
       round3_left.ci__movie_id AS ci__movie_id,
       round3_left.ci__person_role_id AS ci__person_role_id,
       round3_left.ci__role_id AS ci__role_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_10c_rewriteYa8_r3_base_ci AS round3_left
JOIN ya_10c_rewriteYa8_r3_join_2 AS round3_right
  ON (round3_left.ci__movie_id = round3_right.mc__movie_id)
GROUP BY round3_right.mc__movie_id, round3_left.ci__movie_id, round3_left.ci__person_role_id, round3_left.ci__role_id;

CREATE OR REPLACE TEMP VIEW ya_10c_rewriteYa8_r3_join_4 AS
SELECT round3_left.mc__movie_id AS mc__movie_id,
       round3_left.ci__movie_id AS ci__movie_id,
       round3_left.ci__person_role_id AS ci__person_role_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_10c_rewriteYa8_r3_join_3 AS round3_left
JOIN ya_10c_rewriteYa8_r3_base_rt AS round3_right
  ON (round3_right.rt__id = round3_left.ci__role_id)
GROUP BY round3_left.mc__movie_id, round3_left.ci__movie_id, round3_left.ci__person_role_id;

CREATE OR REPLACE TEMP VIEW ya_10c_rewriteYa8_r3_join_5 AS
SELECT round3_right.t__title AS t__title,
       round3_left.ci__person_role_id AS ci__person_role_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_10c_rewriteYa8_r3_join_4 AS round3_left
JOIN ya_10c_rewriteYa8_r3_base_t AS round3_right
  ON (round3_right.t__id = round3_left.mc__movie_id)
 AND (round3_right.t__id = round3_left.ci__movie_id)
GROUP BY round3_right.t__title, round3_left.ci__person_role_id;

CREATE OR REPLACE TEMP VIEW ya_10c_rewriteYa8_r3_join_6 AS
SELECT round3_right.chn__name AS chn__name,
       round3_left.t__title AS t__title,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_10c_rewriteYa8_r3_join_5 AS round3_left
JOIN ya_10c_rewriteYa8_r3_base_chn AS round3_right
  ON (round3_right.chn__id = round3_left.ci__person_role_id)
GROUP BY round3_right.chn__name, round3_left.t__title;

SELECT round3_result.chn__name AS name,
       round3_result.t__title AS title,
       round3_result.annot AS record_count
FROM ya_10c_rewriteYa8_r3_join_6 AS round3_result;
