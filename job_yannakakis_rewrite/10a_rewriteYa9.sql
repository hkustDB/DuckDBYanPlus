-- DuckDB SUM(1) Yannakakis-style two-pass reducer generated from job_agg/10a.sql.

-- Source variant: query/job_duckdb/10a/rewriteYa9.sql

CREATE OR REPLACE TEMP VIEW ya_10a_rewriteYa9_base_chn AS
SELECT chn.*
FROM char_name AS chn;

CREATE OR REPLACE TEMP VIEW ya_10a_rewriteYa9_base_ci AS
SELECT ci.*
FROM cast_info AS ci
WHERE (ci.note LIKE '%(voice)%')
  AND (ci.note LIKE '%(uncredited)%');

CREATE OR REPLACE TEMP VIEW ya_10a_rewriteYa9_base_cn AS
SELECT cn.*
FROM company_name AS cn
WHERE (cn.country_code = '[ru]');

CREATE OR REPLACE TEMP VIEW ya_10a_rewriteYa9_base_ct AS
SELECT ct.*
FROM company_type AS ct;

CREATE OR REPLACE TEMP VIEW ya_10a_rewriteYa9_base_mc AS
SELECT mc.*
FROM movie_companies AS mc;

CREATE OR REPLACE TEMP VIEW ya_10a_rewriteYa9_base_rt AS
SELECT rt.*
FROM role_type AS rt
WHERE (rt.role = 'actor');

CREATE OR REPLACE TEMP VIEW ya_10a_rewriteYa9_base_t AS
SELECT t.*
FROM title AS t
WHERE (t.production_year > 2005);

CREATE OR REPLACE TEMP VIEW ya_10a_rewriteYa9_up_t AS
SELECT t.*
FROM ya_10a_rewriteYa9_base_t AS t;

CREATE OR REPLACE TEMP VIEW ya_10a_rewriteYa9_up_rt AS
SELECT rt.*
FROM ya_10a_rewriteYa9_base_rt AS rt;

CREATE OR REPLACE TEMP VIEW ya_10a_rewriteYa9_up_chn AS
SELECT chn.*
FROM ya_10a_rewriteYa9_base_chn AS chn;

CREATE OR REPLACE TEMP VIEW ya_10a_rewriteYa9_up_ci AS
SELECT ci.*
FROM ya_10a_rewriteYa9_base_ci AS ci
WHERE EXISTS (SELECT 1 FROM ya_10a_rewriteYa9_up_rt AS rt WHERE (rt.id = ci.role_id))
  AND EXISTS (SELECT 1 FROM ya_10a_rewriteYa9_up_chn AS chn WHERE (chn.id = ci.person_role_id));

CREATE OR REPLACE TEMP VIEW ya_10a_rewriteYa9_up_ct AS
SELECT ct.*
FROM ya_10a_rewriteYa9_base_ct AS ct;

CREATE OR REPLACE TEMP VIEW ya_10a_rewriteYa9_up_mc AS
SELECT mc.*
FROM ya_10a_rewriteYa9_base_mc AS mc
WHERE EXISTS (SELECT 1 FROM ya_10a_rewriteYa9_up_t AS t WHERE (t.id = mc.movie_id))
  AND EXISTS (SELECT 1 FROM ya_10a_rewriteYa9_up_ci AS ci WHERE (ci.movie_id = mc.movie_id))
  AND EXISTS (SELECT 1 FROM ya_10a_rewriteYa9_up_ct AS ct WHERE (ct.id = mc.company_type_id));

CREATE OR REPLACE TEMP VIEW ya_10a_rewriteYa9_up_cn AS
SELECT cn.*
FROM ya_10a_rewriteYa9_base_cn AS cn
WHERE EXISTS (SELECT 1 FROM ya_10a_rewriteYa9_up_mc AS mc WHERE (cn.id = mc.company_id));

CREATE OR REPLACE TEMP VIEW ya_10a_rewriteYa9_down_cn AS
SELECT cn.*
FROM ya_10a_rewriteYa9_up_cn AS cn;

CREATE OR REPLACE TEMP VIEW ya_10a_rewriteYa9_down_mc AS
SELECT mc.*
FROM ya_10a_rewriteYa9_up_mc AS mc
WHERE EXISTS (SELECT 1 FROM ya_10a_rewriteYa9_down_cn AS cn WHERE (cn.id = mc.company_id));

CREATE OR REPLACE TEMP VIEW ya_10a_rewriteYa9_down_t AS
SELECT t.*
FROM ya_10a_rewriteYa9_up_t AS t
WHERE EXISTS (SELECT 1 FROM ya_10a_rewriteYa9_down_mc AS mc WHERE (t.id = mc.movie_id));

CREATE OR REPLACE TEMP VIEW ya_10a_rewriteYa9_down_ci AS
SELECT ci.*
FROM ya_10a_rewriteYa9_up_ci AS ci
WHERE EXISTS (SELECT 1 FROM ya_10a_rewriteYa9_down_mc AS mc WHERE (ci.movie_id = mc.movie_id));

CREATE OR REPLACE TEMP VIEW ya_10a_rewriteYa9_down_ct AS
SELECT ct.*
FROM ya_10a_rewriteYa9_up_ct AS ct
WHERE EXISTS (SELECT 1 FROM ya_10a_rewriteYa9_down_mc AS mc WHERE (ct.id = mc.company_type_id));

CREATE OR REPLACE TEMP VIEW ya_10a_rewriteYa9_down_rt AS
SELECT rt.*
FROM ya_10a_rewriteYa9_up_rt AS rt
WHERE EXISTS (SELECT 1 FROM ya_10a_rewriteYa9_down_ci AS ci WHERE (rt.id = ci.role_id));

CREATE OR REPLACE TEMP VIEW ya_10a_rewriteYa9_down_chn AS
SELECT chn.*
FROM ya_10a_rewriteYa9_up_chn AS chn
WHERE EXISTS (SELECT 1 FROM ya_10a_rewriteYa9_down_ci AS ci WHERE (chn.id = ci.person_role_id));

SELECT chn.name,
       t.title,
       SUM(1) AS record_count
FROM ya_10a_rewriteYa9_down_chn AS chn,
     ya_10a_rewriteYa9_down_ci AS ci,
     ya_10a_rewriteYa9_down_cn AS cn,
     ya_10a_rewriteYa9_down_ct AS ct,
     ya_10a_rewriteYa9_down_mc AS mc,
     ya_10a_rewriteYa9_down_rt AS rt,
     ya_10a_rewriteYa9_down_t AS t
WHERE (ci.note LIKE '%(voice)%')
  AND (ci.note LIKE '%(uncredited)%')
  AND (cn.country_code = '[ru]')
  AND (rt.role = 'actor')
  AND (t.production_year > 2005)
  AND (t.id = mc.movie_id)
  AND (t.id = ci.movie_id)
  AND (ci.movie_id = mc.movie_id)
  AND (chn.id = ci.person_role_id)
  AND (rt.id = ci.role_id)
  AND (cn.id = mc.company_id)
  AND (ct.id = mc.company_type_id)
GROUP BY chn.name, t.title;
