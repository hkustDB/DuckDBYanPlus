-- DuckDB SUM(1) Yannakakis-style two-pass reducer generated from job_agg/8d.sql.

-- Source variant: query/job_duckdb/8d/rewriteYa2.sql

CREATE OR REPLACE TEMP VIEW ya_8d_rewriteYa2_base_an1 AS
SELECT an1.*
FROM aka_name AS an1;

CREATE OR REPLACE TEMP VIEW ya_8d_rewriteYa2_base_ci AS
SELECT ci.*
FROM cast_info AS ci;

CREATE OR REPLACE TEMP VIEW ya_8d_rewriteYa2_base_cn AS
SELECT cn.*
FROM company_name AS cn
WHERE (cn.country_code ='[us]');

CREATE OR REPLACE TEMP VIEW ya_8d_rewriteYa2_base_mc AS
SELECT mc.*
FROM movie_companies AS mc;

CREATE OR REPLACE TEMP VIEW ya_8d_rewriteYa2_base_n1 AS
SELECT n1.*
FROM name AS n1;

CREATE OR REPLACE TEMP VIEW ya_8d_rewriteYa2_base_rt AS
SELECT rt.*
FROM role_type AS rt
WHERE (rt.role ='costume designer');

CREATE OR REPLACE TEMP VIEW ya_8d_rewriteYa2_base_t AS
SELECT t.*
FROM title AS t;

CREATE OR REPLACE TEMP VIEW ya_8d_rewriteYa2_up_t AS
SELECT t.*
FROM ya_8d_rewriteYa2_base_t AS t;

CREATE OR REPLACE TEMP VIEW ya_8d_rewriteYa2_up_n1 AS
SELECT n1.*
FROM ya_8d_rewriteYa2_base_n1 AS n1;

CREATE OR REPLACE TEMP VIEW ya_8d_rewriteYa2_up_rt AS
SELECT rt.*
FROM ya_8d_rewriteYa2_base_rt AS rt;

CREATE OR REPLACE TEMP VIEW ya_8d_rewriteYa2_up_an1 AS
SELECT an1.*
FROM ya_8d_rewriteYa2_base_an1 AS an1;

CREATE OR REPLACE TEMP VIEW ya_8d_rewriteYa2_up_ci AS
SELECT ci.*
FROM ya_8d_rewriteYa2_base_ci AS ci
WHERE EXISTS (SELECT 1 FROM ya_8d_rewriteYa2_up_n1 AS n1 WHERE (n1.id = ci.person_id))
  AND EXISTS (SELECT 1 FROM ya_8d_rewriteYa2_up_rt AS rt WHERE (ci.role_id = rt.id))
  AND EXISTS (SELECT 1 FROM ya_8d_rewriteYa2_up_an1 AS an1 WHERE (an1.person_id = ci.person_id));

CREATE OR REPLACE TEMP VIEW ya_8d_rewriteYa2_up_mc AS
SELECT mc.*
FROM ya_8d_rewriteYa2_base_mc AS mc
WHERE EXISTS (SELECT 1 FROM ya_8d_rewriteYa2_up_t AS t WHERE (t.id = mc.movie_id))
  AND EXISTS (SELECT 1 FROM ya_8d_rewriteYa2_up_ci AS ci WHERE (ci.movie_id = mc.movie_id));

CREATE OR REPLACE TEMP VIEW ya_8d_rewriteYa2_up_cn AS
SELECT cn.*
FROM ya_8d_rewriteYa2_base_cn AS cn
WHERE EXISTS (SELECT 1 FROM ya_8d_rewriteYa2_up_mc AS mc WHERE (mc.company_id = cn.id));

CREATE OR REPLACE TEMP VIEW ya_8d_rewriteYa2_down_cn AS
SELECT cn.*
FROM ya_8d_rewriteYa2_up_cn AS cn;

CREATE OR REPLACE TEMP VIEW ya_8d_rewriteYa2_down_mc AS
SELECT mc.*
FROM ya_8d_rewriteYa2_up_mc AS mc
WHERE EXISTS (SELECT 1 FROM ya_8d_rewriteYa2_down_cn AS cn WHERE (mc.company_id = cn.id));

CREATE OR REPLACE TEMP VIEW ya_8d_rewriteYa2_down_t AS
SELECT t.*
FROM ya_8d_rewriteYa2_up_t AS t
WHERE EXISTS (SELECT 1 FROM ya_8d_rewriteYa2_down_mc AS mc WHERE (t.id = mc.movie_id));

CREATE OR REPLACE TEMP VIEW ya_8d_rewriteYa2_down_ci AS
SELECT ci.*
FROM ya_8d_rewriteYa2_up_ci AS ci
WHERE EXISTS (SELECT 1 FROM ya_8d_rewriteYa2_down_mc AS mc WHERE (ci.movie_id = mc.movie_id));

CREATE OR REPLACE TEMP VIEW ya_8d_rewriteYa2_down_n1 AS
SELECT n1.*
FROM ya_8d_rewriteYa2_up_n1 AS n1
WHERE EXISTS (SELECT 1 FROM ya_8d_rewriteYa2_down_ci AS ci WHERE (n1.id = ci.person_id));

CREATE OR REPLACE TEMP VIEW ya_8d_rewriteYa2_down_rt AS
SELECT rt.*
FROM ya_8d_rewriteYa2_up_rt AS rt
WHERE EXISTS (SELECT 1 FROM ya_8d_rewriteYa2_down_ci AS ci WHERE (ci.role_id = rt.id));

CREATE OR REPLACE TEMP VIEW ya_8d_rewriteYa2_down_an1 AS
SELECT an1.*
FROM ya_8d_rewriteYa2_up_an1 AS an1
WHERE EXISTS (SELECT 1 FROM ya_8d_rewriteYa2_down_ci AS ci WHERE (an1.person_id = ci.person_id));

SELECT an1.name,
       t.title,
       SUM(1) AS record_count
FROM ya_8d_rewriteYa2_down_an1 AS an1,
     ya_8d_rewriteYa2_down_ci AS ci,
     ya_8d_rewriteYa2_down_cn AS cn,
     ya_8d_rewriteYa2_down_mc AS mc,
     ya_8d_rewriteYa2_down_n1 AS n1,
     ya_8d_rewriteYa2_down_rt AS rt,
     ya_8d_rewriteYa2_down_t AS t
WHERE (cn.country_code ='[us]')
  AND (rt.role ='costume designer')
  AND (an1.person_id = n1.id)
  AND (n1.id = ci.person_id)
  AND (ci.movie_id = t.id)
  AND (t.id = mc.movie_id)
  AND (mc.company_id = cn.id)
  AND (ci.role_id = rt.id)
  AND (an1.person_id = ci.person_id)
  AND (ci.movie_id = mc.movie_id)
GROUP BY an1.name, t.title;
