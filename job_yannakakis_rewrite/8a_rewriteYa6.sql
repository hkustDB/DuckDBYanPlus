-- DuckDB SUM(1) Yannakakis-style two-pass reducer generated from job_agg/8a.sql.

-- Source variant: query/job_duckdb/8a/rewriteYa6.sql

CREATE OR REPLACE TEMP VIEW ya_8a_rewriteYa6_base_an1 AS
SELECT an1.*
FROM aka_name AS an1;

CREATE OR REPLACE TEMP VIEW ya_8a_rewriteYa6_base_ci AS
SELECT ci.*
FROM cast_info AS ci
WHERE (ci.note ='(voice: English version)');

CREATE OR REPLACE TEMP VIEW ya_8a_rewriteYa6_base_cn AS
SELECT cn.*
FROM company_name AS cn
WHERE (cn.country_code ='[jp]');

CREATE OR REPLACE TEMP VIEW ya_8a_rewriteYa6_base_mc AS
SELECT mc.*
FROM movie_companies AS mc
WHERE (mc.note LIKE '%(Japan)%')
  AND (mc.note NOT LIKE '%(USA)%');

CREATE OR REPLACE TEMP VIEW ya_8a_rewriteYa6_base_n1 AS
SELECT n1.*
FROM name AS n1
WHERE (n1.name LIKE '%Yo%')
  AND (n1.name NOT LIKE '%Yu%');

CREATE OR REPLACE TEMP VIEW ya_8a_rewriteYa6_base_rt AS
SELECT rt.*
FROM role_type AS rt
WHERE (rt.role ='actress');

CREATE OR REPLACE TEMP VIEW ya_8a_rewriteYa6_base_t AS
SELECT t.*
FROM title AS t;

CREATE OR REPLACE TEMP VIEW ya_8a_rewriteYa6_up_cn AS
SELECT cn.*
FROM ya_8a_rewriteYa6_base_cn AS cn;

CREATE OR REPLACE TEMP VIEW ya_8a_rewriteYa6_up_mc AS
SELECT mc.*
FROM ya_8a_rewriteYa6_base_mc AS mc
WHERE EXISTS (SELECT 1 FROM ya_8a_rewriteYa6_up_cn AS cn WHERE (mc.company_id = cn.id));

CREATE OR REPLACE TEMP VIEW ya_8a_rewriteYa6_up_an1 AS
SELECT an1.*
FROM ya_8a_rewriteYa6_base_an1 AS an1;

CREATE OR REPLACE TEMP VIEW ya_8a_rewriteYa6_up_n1 AS
SELECT n1.*
FROM ya_8a_rewriteYa6_base_n1 AS n1;

CREATE OR REPLACE TEMP VIEW ya_8a_rewriteYa6_up_rt AS
SELECT rt.*
FROM ya_8a_rewriteYa6_base_rt AS rt;

CREATE OR REPLACE TEMP VIEW ya_8a_rewriteYa6_up_ci AS
SELECT ci.*
FROM ya_8a_rewriteYa6_base_ci AS ci
WHERE EXISTS (SELECT 1 FROM ya_8a_rewriteYa6_up_an1 AS an1 WHERE (an1.person_id = ci.person_id))
  AND EXISTS (SELECT 1 FROM ya_8a_rewriteYa6_up_n1 AS n1 WHERE (n1.id = ci.person_id))
  AND EXISTS (SELECT 1 FROM ya_8a_rewriteYa6_up_rt AS rt WHERE (ci.role_id = rt.id));

CREATE OR REPLACE TEMP VIEW ya_8a_rewriteYa6_up_t AS
SELECT t.*
FROM ya_8a_rewriteYa6_base_t AS t
WHERE EXISTS (SELECT 1 FROM ya_8a_rewriteYa6_up_mc AS mc WHERE (t.id = mc.movie_id))
  AND EXISTS (SELECT 1 FROM ya_8a_rewriteYa6_up_ci AS ci WHERE (ci.movie_id = t.id));

CREATE OR REPLACE TEMP VIEW ya_8a_rewriteYa6_down_t AS
SELECT t.*
FROM ya_8a_rewriteYa6_up_t AS t;

CREATE OR REPLACE TEMP VIEW ya_8a_rewriteYa6_down_mc AS
SELECT mc.*
FROM ya_8a_rewriteYa6_up_mc AS mc
WHERE EXISTS (SELECT 1 FROM ya_8a_rewriteYa6_down_t AS t WHERE (t.id = mc.movie_id));

CREATE OR REPLACE TEMP VIEW ya_8a_rewriteYa6_down_ci AS
SELECT ci.*
FROM ya_8a_rewriteYa6_up_ci AS ci
WHERE EXISTS (SELECT 1 FROM ya_8a_rewriteYa6_down_t AS t WHERE (ci.movie_id = t.id));

CREATE OR REPLACE TEMP VIEW ya_8a_rewriteYa6_down_cn AS
SELECT cn.*
FROM ya_8a_rewriteYa6_up_cn AS cn
WHERE EXISTS (SELECT 1 FROM ya_8a_rewriteYa6_down_mc AS mc WHERE (mc.company_id = cn.id));

CREATE OR REPLACE TEMP VIEW ya_8a_rewriteYa6_down_an1 AS
SELECT an1.*
FROM ya_8a_rewriteYa6_up_an1 AS an1
WHERE EXISTS (SELECT 1 FROM ya_8a_rewriteYa6_down_ci AS ci WHERE (an1.person_id = ci.person_id));

CREATE OR REPLACE TEMP VIEW ya_8a_rewriteYa6_down_n1 AS
SELECT n1.*
FROM ya_8a_rewriteYa6_up_n1 AS n1
WHERE EXISTS (SELECT 1 FROM ya_8a_rewriteYa6_down_ci AS ci WHERE (n1.id = ci.person_id));

CREATE OR REPLACE TEMP VIEW ya_8a_rewriteYa6_down_rt AS
SELECT rt.*
FROM ya_8a_rewriteYa6_up_rt AS rt
WHERE EXISTS (SELECT 1 FROM ya_8a_rewriteYa6_down_ci AS ci WHERE (ci.role_id = rt.id));

CREATE OR REPLACE TEMP VIEW ya_8a_rewriteYa6_r3_base_an1 AS
SELECT an1.person_id AS an1__person_id,
       an1.name AS an1__name,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_8a_rewriteYa6_down_an1 AS an1
GROUP BY an1.person_id, an1.name;

CREATE OR REPLACE TEMP VIEW ya_8a_rewriteYa6_r3_base_ci AS
SELECT ci.person_id AS ci__person_id,
       ci.movie_id AS ci__movie_id,
       ci.role_id AS ci__role_id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_8a_rewriteYa6_down_ci AS ci
GROUP BY ci.person_id, ci.movie_id, ci.role_id;

CREATE OR REPLACE TEMP VIEW ya_8a_rewriteYa6_r3_base_cn AS
SELECT cn.id AS cn__id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_8a_rewriteYa6_down_cn AS cn
GROUP BY cn.id;

CREATE OR REPLACE TEMP VIEW ya_8a_rewriteYa6_r3_base_mc AS
SELECT mc.movie_id AS mc__movie_id,
       mc.company_id AS mc__company_id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_8a_rewriteYa6_down_mc AS mc
GROUP BY mc.movie_id, mc.company_id;

CREATE OR REPLACE TEMP VIEW ya_8a_rewriteYa6_r3_base_n1 AS
SELECT n1.id AS n1__id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_8a_rewriteYa6_down_n1 AS n1
GROUP BY n1.id;

CREATE OR REPLACE TEMP VIEW ya_8a_rewriteYa6_r3_base_rt AS
SELECT rt.id AS rt__id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_8a_rewriteYa6_down_rt AS rt
GROUP BY rt.id;

CREATE OR REPLACE TEMP VIEW ya_8a_rewriteYa6_r3_base_t AS
SELECT t.id AS t__id,
       t.title AS t__title,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_8a_rewriteYa6_down_t AS t
GROUP BY t.id, t.title;

CREATE OR REPLACE TEMP VIEW ya_8a_rewriteYa6_r3_join_1 AS
SELECT round3_left.mc__movie_id AS mc__movie_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_8a_rewriteYa6_r3_base_mc AS round3_left
JOIN ya_8a_rewriteYa6_r3_base_cn AS round3_right
  ON (round3_left.mc__company_id = round3_right.cn__id)
GROUP BY round3_left.mc__movie_id;

CREATE OR REPLACE TEMP VIEW ya_8a_rewriteYa6_r3_join_2 AS
SELECT round3_left.t__title AS t__title,
       round3_left.t__id AS t__id,
       round3_right.mc__movie_id AS mc__movie_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_8a_rewriteYa6_r3_base_t AS round3_left
JOIN ya_8a_rewriteYa6_r3_join_1 AS round3_right
  ON (round3_left.t__id = round3_right.mc__movie_id)
GROUP BY round3_left.t__title, round3_left.t__id, round3_right.mc__movie_id;

CREATE OR REPLACE TEMP VIEW ya_8a_rewriteYa6_r3_join_3 AS
SELECT round3_right.an1__name AS an1__name,
       round3_right.an1__person_id AS an1__person_id,
       round3_left.ci__person_id AS ci__person_id,
       round3_left.ci__movie_id AS ci__movie_id,
       round3_left.ci__role_id AS ci__role_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_8a_rewriteYa6_r3_base_ci AS round3_left
JOIN ya_8a_rewriteYa6_r3_base_an1 AS round3_right
  ON (round3_right.an1__person_id = round3_left.ci__person_id)
GROUP BY round3_right.an1__name, round3_right.an1__person_id, round3_left.ci__person_id, round3_left.ci__movie_id, round3_left.ci__role_id;

CREATE OR REPLACE TEMP VIEW ya_8a_rewriteYa6_r3_join_4 AS
SELECT round3_left.an1__name AS an1__name,
       round3_left.ci__movie_id AS ci__movie_id,
       round3_left.ci__role_id AS ci__role_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_8a_rewriteYa6_r3_join_3 AS round3_left
JOIN ya_8a_rewriteYa6_r3_base_n1 AS round3_right
  ON (round3_left.an1__person_id = round3_right.n1__id)
 AND (round3_right.n1__id = round3_left.ci__person_id)
GROUP BY round3_left.an1__name, round3_left.ci__movie_id, round3_left.ci__role_id;

CREATE OR REPLACE TEMP VIEW ya_8a_rewriteYa6_r3_join_5 AS
SELECT round3_left.an1__name AS an1__name,
       round3_left.ci__movie_id AS ci__movie_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_8a_rewriteYa6_r3_join_4 AS round3_left
JOIN ya_8a_rewriteYa6_r3_base_rt AS round3_right
  ON (round3_left.ci__role_id = round3_right.rt__id)
GROUP BY round3_left.an1__name, round3_left.ci__movie_id;

CREATE OR REPLACE TEMP VIEW ya_8a_rewriteYa6_r3_join_6 AS
SELECT round3_right.an1__name AS an1__name,
       round3_left.t__title AS t__title,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_8a_rewriteYa6_r3_join_2 AS round3_left
JOIN ya_8a_rewriteYa6_r3_join_5 AS round3_right
  ON (round3_right.ci__movie_id = round3_left.t__id)
 AND (round3_right.ci__movie_id = round3_left.mc__movie_id)
GROUP BY round3_right.an1__name, round3_left.t__title;

SELECT round3_result.an1__name AS name,
       round3_result.t__title AS title,
       round3_result.annot AS record_count
FROM ya_8a_rewriteYa6_r3_join_6 AS round3_result;
