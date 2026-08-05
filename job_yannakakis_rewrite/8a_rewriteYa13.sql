-- DuckDB SUM(1) Yannakakis-style two-pass reducer generated from job_agg/8a.sql.

-- Source variant: query/job_duckdb/8a/rewriteYa13.sql

CREATE OR REPLACE TEMP VIEW ya_8a_rewriteYa13_base_an1 AS
SELECT an1.*
FROM aka_name AS an1;

CREATE OR REPLACE TEMP VIEW ya_8a_rewriteYa13_base_ci AS
SELECT ci.*
FROM cast_info AS ci
WHERE (ci.note ='(voice: English version)');

CREATE OR REPLACE TEMP VIEW ya_8a_rewriteYa13_base_cn AS
SELECT cn.*
FROM company_name AS cn
WHERE (cn.country_code ='[jp]');

CREATE OR REPLACE TEMP VIEW ya_8a_rewriteYa13_base_mc AS
SELECT mc.*
FROM movie_companies AS mc
WHERE (mc.note LIKE '%(Japan)%')
  AND (mc.note NOT LIKE '%(USA)%');

CREATE OR REPLACE TEMP VIEW ya_8a_rewriteYa13_base_n1 AS
SELECT n1.*
FROM name AS n1
WHERE (n1.name LIKE '%Yo%')
  AND (n1.name NOT LIKE '%Yu%');

CREATE OR REPLACE TEMP VIEW ya_8a_rewriteYa13_base_rt AS
SELECT rt.*
FROM role_type AS rt
WHERE (rt.role ='actress');

CREATE OR REPLACE TEMP VIEW ya_8a_rewriteYa13_base_t AS
SELECT t.*
FROM title AS t;

CREATE OR REPLACE TEMP VIEW ya_8a_rewriteYa13_up_n1 AS
SELECT n1.*
FROM ya_8a_rewriteYa13_base_n1 AS n1;

CREATE OR REPLACE TEMP VIEW ya_8a_rewriteYa13_up_rt AS
SELECT rt.*
FROM ya_8a_rewriteYa13_base_rt AS rt;

CREATE OR REPLACE TEMP VIEW ya_8a_rewriteYa13_up_an1 AS
SELECT an1.*
FROM ya_8a_rewriteYa13_base_an1 AS an1;

CREATE OR REPLACE TEMP VIEW ya_8a_rewriteYa13_up_ci AS
SELECT ci.*
FROM ya_8a_rewriteYa13_base_ci AS ci
WHERE EXISTS (SELECT 1 FROM ya_8a_rewriteYa13_up_n1 AS n1 WHERE (n1.id = ci.person_id))
  AND EXISTS (SELECT 1 FROM ya_8a_rewriteYa13_up_rt AS rt WHERE (ci.role_id = rt.id))
  AND EXISTS (SELECT 1 FROM ya_8a_rewriteYa13_up_an1 AS an1 WHERE (an1.person_id = ci.person_id));

CREATE OR REPLACE TEMP VIEW ya_8a_rewriteYa13_up_cn AS
SELECT cn.*
FROM ya_8a_rewriteYa13_base_cn AS cn;

CREATE OR REPLACE TEMP VIEW ya_8a_rewriteYa13_up_mc AS
SELECT mc.*
FROM ya_8a_rewriteYa13_base_mc AS mc
WHERE EXISTS (SELECT 1 FROM ya_8a_rewriteYa13_up_cn AS cn WHERE (mc.company_id = cn.id));

CREATE OR REPLACE TEMP VIEW ya_8a_rewriteYa13_up_t AS
SELECT t.*
FROM ya_8a_rewriteYa13_base_t AS t
WHERE EXISTS (SELECT 1 FROM ya_8a_rewriteYa13_up_ci AS ci WHERE (ci.movie_id = t.id))
  AND EXISTS (SELECT 1 FROM ya_8a_rewriteYa13_up_mc AS mc WHERE (t.id = mc.movie_id));

CREATE OR REPLACE TEMP VIEW ya_8a_rewriteYa13_down_t AS
SELECT t.*
FROM ya_8a_rewriteYa13_up_t AS t;

CREATE OR REPLACE TEMP VIEW ya_8a_rewriteYa13_down_ci AS
SELECT ci.*
FROM ya_8a_rewriteYa13_up_ci AS ci
WHERE EXISTS (SELECT 1 FROM ya_8a_rewriteYa13_down_t AS t WHERE (ci.movie_id = t.id));

CREATE OR REPLACE TEMP VIEW ya_8a_rewriteYa13_down_mc AS
SELECT mc.*
FROM ya_8a_rewriteYa13_up_mc AS mc
WHERE EXISTS (SELECT 1 FROM ya_8a_rewriteYa13_down_t AS t WHERE (t.id = mc.movie_id));

CREATE OR REPLACE TEMP VIEW ya_8a_rewriteYa13_down_n1 AS
SELECT n1.*
FROM ya_8a_rewriteYa13_up_n1 AS n1
WHERE EXISTS (SELECT 1 FROM ya_8a_rewriteYa13_down_ci AS ci WHERE (n1.id = ci.person_id));

CREATE OR REPLACE TEMP VIEW ya_8a_rewriteYa13_down_rt AS
SELECT rt.*
FROM ya_8a_rewriteYa13_up_rt AS rt
WHERE EXISTS (SELECT 1 FROM ya_8a_rewriteYa13_down_ci AS ci WHERE (ci.role_id = rt.id));

CREATE OR REPLACE TEMP VIEW ya_8a_rewriteYa13_down_an1 AS
SELECT an1.*
FROM ya_8a_rewriteYa13_up_an1 AS an1
WHERE EXISTS (SELECT 1 FROM ya_8a_rewriteYa13_down_ci AS ci WHERE (an1.person_id = ci.person_id));

CREATE OR REPLACE TEMP VIEW ya_8a_rewriteYa13_down_cn AS
SELECT cn.*
FROM ya_8a_rewriteYa13_up_cn AS cn
WHERE EXISTS (SELECT 1 FROM ya_8a_rewriteYa13_down_mc AS mc WHERE (mc.company_id = cn.id));

SELECT an1.name,
       t.title,
       SUM(1) AS record_count
FROM ya_8a_rewriteYa13_down_an1 AS an1,
     ya_8a_rewriteYa13_down_ci AS ci,
     ya_8a_rewriteYa13_down_cn AS cn,
     ya_8a_rewriteYa13_down_mc AS mc,
     ya_8a_rewriteYa13_down_n1 AS n1,
     ya_8a_rewriteYa13_down_rt AS rt,
     ya_8a_rewriteYa13_down_t AS t
WHERE (ci.note ='(voice: English version)')
  AND (cn.country_code ='[jp]')
  AND (mc.note LIKE '%(Japan)%')
  AND (mc.note NOT LIKE '%(USA)%')
  AND (n1.name LIKE '%Yo%')
  AND (n1.name NOT LIKE '%Yu%')
  AND (rt.role ='actress')
  AND (an1.person_id = n1.id)
  AND (n1.id = ci.person_id)
  AND (ci.movie_id = t.id)
  AND (t.id = mc.movie_id)
  AND (mc.company_id = cn.id)
  AND (ci.role_id = rt.id)
  AND (an1.person_id = ci.person_id)
  AND (ci.movie_id = mc.movie_id)
GROUP BY an1.name, t.title;
