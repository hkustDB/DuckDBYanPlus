-- DuckDB SUM(1) Yannakakis-style two-pass reducer generated from job_agg/9b.sql.

-- Source variant: query/job_duckdb/9b/rewriteYa10.sql

CREATE OR REPLACE TEMP VIEW ya_9b_rewriteYa10_base_an AS
SELECT an.*
FROM aka_name AS an;

CREATE OR REPLACE TEMP VIEW ya_9b_rewriteYa10_base_chn AS
SELECT chn.*
FROM char_name AS chn;

CREATE OR REPLACE TEMP VIEW ya_9b_rewriteYa10_base_ci AS
SELECT ci.*
FROM cast_info AS ci
WHERE (ci.note = '(voice)');

CREATE OR REPLACE TEMP VIEW ya_9b_rewriteYa10_base_cn AS
SELECT cn.*
FROM company_name AS cn
WHERE (cn.country_code ='[us]');

CREATE OR REPLACE TEMP VIEW ya_9b_rewriteYa10_base_mc AS
SELECT mc.*
FROM movie_companies AS mc
WHERE (mc.note LIKE '%(200%)%')
  AND ((mc.note LIKE '%(USA)%'
       OR mc.note LIKE '%(worldwide)%'));

CREATE OR REPLACE TEMP VIEW ya_9b_rewriteYa10_base_n AS
SELECT n.*
FROM name AS n
WHERE (n.gender ='f')
  AND (n.name LIKE '%Angel%');

CREATE OR REPLACE TEMP VIEW ya_9b_rewriteYa10_base_rt AS
SELECT rt.*
FROM role_type AS rt
WHERE (rt.role ='actress');

CREATE OR REPLACE TEMP VIEW ya_9b_rewriteYa10_base_t AS
SELECT t.*
FROM title AS t
WHERE (t.production_year BETWEEN 2007 AND 2010);

CREATE OR REPLACE TEMP VIEW ya_9b_rewriteYa10_up_t AS
SELECT t.*
FROM ya_9b_rewriteYa10_base_t AS t;

CREATE OR REPLACE TEMP VIEW ya_9b_rewriteYa10_up_an AS
SELECT an.*
FROM ya_9b_rewriteYa10_base_an AS an;

CREATE OR REPLACE TEMP VIEW ya_9b_rewriteYa10_up_chn AS
SELECT chn.*
FROM ya_9b_rewriteYa10_base_chn AS chn;

CREATE OR REPLACE TEMP VIEW ya_9b_rewriteYa10_up_cn AS
SELECT cn.*
FROM ya_9b_rewriteYa10_base_cn AS cn;

CREATE OR REPLACE TEMP VIEW ya_9b_rewriteYa10_up_mc AS
SELECT mc.*
FROM ya_9b_rewriteYa10_base_mc AS mc
WHERE EXISTS (SELECT 1 FROM ya_9b_rewriteYa10_up_cn AS cn WHERE (mc.company_id = cn.id));

CREATE OR REPLACE TEMP VIEW ya_9b_rewriteYa10_up_n AS
SELECT n.*
FROM ya_9b_rewriteYa10_base_n AS n;

CREATE OR REPLACE TEMP VIEW ya_9b_rewriteYa10_up_rt AS
SELECT rt.*
FROM ya_9b_rewriteYa10_base_rt AS rt;

CREATE OR REPLACE TEMP VIEW ya_9b_rewriteYa10_up_ci AS
SELECT ci.*
FROM ya_9b_rewriteYa10_base_ci AS ci
WHERE EXISTS (SELECT 1 FROM ya_9b_rewriteYa10_up_t AS t WHERE (ci.movie_id = t.id))
  AND EXISTS (SELECT 1 FROM ya_9b_rewriteYa10_up_an AS an WHERE (an.person_id = ci.person_id))
  AND EXISTS (SELECT 1 FROM ya_9b_rewriteYa10_up_chn AS chn WHERE (chn.id = ci.person_role_id))
  AND EXISTS (SELECT 1 FROM ya_9b_rewriteYa10_up_mc AS mc WHERE (ci.movie_id = mc.movie_id))
  AND EXISTS (SELECT 1 FROM ya_9b_rewriteYa10_up_n AS n WHERE (n.id = ci.person_id))
  AND EXISTS (SELECT 1 FROM ya_9b_rewriteYa10_up_rt AS rt WHERE (ci.role_id = rt.id));

CREATE OR REPLACE TEMP VIEW ya_9b_rewriteYa10_down_ci AS
SELECT ci.*
FROM ya_9b_rewriteYa10_up_ci AS ci;

CREATE OR REPLACE TEMP VIEW ya_9b_rewriteYa10_down_t AS
SELECT t.*
FROM ya_9b_rewriteYa10_up_t AS t
WHERE EXISTS (SELECT 1 FROM ya_9b_rewriteYa10_down_ci AS ci WHERE (ci.movie_id = t.id));

CREATE OR REPLACE TEMP VIEW ya_9b_rewriteYa10_down_an AS
SELECT an.*
FROM ya_9b_rewriteYa10_up_an AS an
WHERE EXISTS (SELECT 1 FROM ya_9b_rewriteYa10_down_ci AS ci WHERE (an.person_id = ci.person_id));

CREATE OR REPLACE TEMP VIEW ya_9b_rewriteYa10_down_chn AS
SELECT chn.*
FROM ya_9b_rewriteYa10_up_chn AS chn
WHERE EXISTS (SELECT 1 FROM ya_9b_rewriteYa10_down_ci AS ci WHERE (chn.id = ci.person_role_id));

CREATE OR REPLACE TEMP VIEW ya_9b_rewriteYa10_down_mc AS
SELECT mc.*
FROM ya_9b_rewriteYa10_up_mc AS mc
WHERE EXISTS (SELECT 1 FROM ya_9b_rewriteYa10_down_ci AS ci WHERE (ci.movie_id = mc.movie_id));

CREATE OR REPLACE TEMP VIEW ya_9b_rewriteYa10_down_n AS
SELECT n.*
FROM ya_9b_rewriteYa10_up_n AS n
WHERE EXISTS (SELECT 1 FROM ya_9b_rewriteYa10_down_ci AS ci WHERE (n.id = ci.person_id));

CREATE OR REPLACE TEMP VIEW ya_9b_rewriteYa10_down_rt AS
SELECT rt.*
FROM ya_9b_rewriteYa10_up_rt AS rt
WHERE EXISTS (SELECT 1 FROM ya_9b_rewriteYa10_down_ci AS ci WHERE (ci.role_id = rt.id));

CREATE OR REPLACE TEMP VIEW ya_9b_rewriteYa10_down_cn AS
SELECT cn.*
FROM ya_9b_rewriteYa10_up_cn AS cn
WHERE EXISTS (SELECT 1 FROM ya_9b_rewriteYa10_down_mc AS mc WHERE (mc.company_id = cn.id));

SELECT an.name,
       chn.name,
       n.name,
       t.title,
       SUM(1) AS record_count
FROM ya_9b_rewriteYa10_down_an AS an,
     ya_9b_rewriteYa10_down_chn AS chn,
     ya_9b_rewriteYa10_down_ci AS ci,
     ya_9b_rewriteYa10_down_cn AS cn,
     ya_9b_rewriteYa10_down_mc AS mc,
     ya_9b_rewriteYa10_down_n AS n,
     ya_9b_rewriteYa10_down_rt AS rt,
     ya_9b_rewriteYa10_down_t AS t
WHERE (ci.note = '(voice)')
  AND (cn.country_code ='[us]')
  AND (mc.note LIKE '%(200%)%')
  AND ((mc.note LIKE '%(USA)%'
       OR mc.note LIKE '%(worldwide)%'))
  AND (n.gender ='f')
  AND (n.name LIKE '%Angel%')
  AND (rt.role ='actress')
  AND (t.production_year BETWEEN 2007 AND 2010)
  AND (ci.movie_id = t.id)
  AND (t.id = mc.movie_id)
  AND (ci.movie_id = mc.movie_id)
  AND (mc.company_id = cn.id)
  AND (ci.role_id = rt.id)
  AND (n.id = ci.person_id)
  AND (chn.id = ci.person_role_id)
  AND (an.person_id = n.id)
  AND (an.person_id = ci.person_id)
GROUP BY an.name, chn.name, n.name, t.title;
