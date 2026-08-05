-- DuckDB SUM(1) Yannakakis-style two-pass reducer generated from job_agg/19c.sql.

-- Source variant: query/job_duckdb/19c/rewriteYa125.sql

CREATE OR REPLACE TEMP VIEW ya_19c_rewriteYa125_base_an AS
SELECT an.*
FROM aka_name AS an;

CREATE OR REPLACE TEMP VIEW ya_19c_rewriteYa125_base_chn AS
SELECT chn.*
FROM char_name AS chn;

CREATE OR REPLACE TEMP VIEW ya_19c_rewriteYa125_base_ci AS
SELECT ci.*
FROM cast_info AS ci
WHERE (ci.note IN ('(voice)',
                  '(voice: Japanese version)',
                  '(voice) (uncredited)',
                  '(voice: English version)'));

CREATE OR REPLACE TEMP VIEW ya_19c_rewriteYa125_base_cn AS
SELECT cn.*
FROM company_name AS cn
WHERE (cn.country_code ='[us]');

CREATE OR REPLACE TEMP VIEW ya_19c_rewriteYa125_base_it AS
SELECT it.*
FROM info_type AS it
WHERE (it.info = 'release dates');

CREATE OR REPLACE TEMP VIEW ya_19c_rewriteYa125_base_mc AS
SELECT mc.*
FROM movie_companies AS mc;

CREATE OR REPLACE TEMP VIEW ya_19c_rewriteYa125_base_mi AS
SELECT mi.*
FROM movie_info AS mi
WHERE (mi.info IS NOT NULL)
  AND ((mi.info LIKE 'Japan:%200%'
       OR mi.info LIKE 'USA:%200%'));

CREATE OR REPLACE TEMP VIEW ya_19c_rewriteYa125_base_n AS
SELECT n.*
FROM name AS n
WHERE (n.gender ='f')
  AND (n.name LIKE '%An%');

CREATE OR REPLACE TEMP VIEW ya_19c_rewriteYa125_base_rt AS
SELECT rt.*
FROM role_type AS rt
WHERE (rt.role ='actress');

CREATE OR REPLACE TEMP VIEW ya_19c_rewriteYa125_base_t AS
SELECT t.*
FROM title AS t
WHERE (t.production_year > 2000);

CREATE OR REPLACE TEMP VIEW ya_19c_rewriteYa125_up_it AS
SELECT it.*
FROM ya_19c_rewriteYa125_base_it AS it;

CREATE OR REPLACE TEMP VIEW ya_19c_rewriteYa125_up_mi AS
SELECT mi.*
FROM ya_19c_rewriteYa125_base_mi AS mi
WHERE EXISTS (SELECT 1 FROM ya_19c_rewriteYa125_up_it AS it WHERE (it.id = mi.info_type_id));

CREATE OR REPLACE TEMP VIEW ya_19c_rewriteYa125_up_t AS
SELECT t.*
FROM ya_19c_rewriteYa125_base_t AS t;

CREATE OR REPLACE TEMP VIEW ya_19c_rewriteYa125_up_rt AS
SELECT rt.*
FROM ya_19c_rewriteYa125_base_rt AS rt;

CREATE OR REPLACE TEMP VIEW ya_19c_rewriteYa125_up_an AS
SELECT an.*
FROM ya_19c_rewriteYa125_base_an AS an;

CREATE OR REPLACE TEMP VIEW ya_19c_rewriteYa125_up_chn AS
SELECT chn.*
FROM ya_19c_rewriteYa125_base_chn AS chn;

CREATE OR REPLACE TEMP VIEW ya_19c_rewriteYa125_up_n AS
SELECT n.*
FROM ya_19c_rewriteYa125_base_n AS n;

CREATE OR REPLACE TEMP VIEW ya_19c_rewriteYa125_up_ci AS
SELECT ci.*
FROM ya_19c_rewriteYa125_base_ci AS ci
WHERE EXISTS (SELECT 1 FROM ya_19c_rewriteYa125_up_rt AS rt WHERE (rt.id = ci.role_id))
  AND EXISTS (SELECT 1 FROM ya_19c_rewriteYa125_up_an AS an WHERE (ci.person_id = an.person_id))
  AND EXISTS (SELECT 1 FROM ya_19c_rewriteYa125_up_chn AS chn WHERE (chn.id = ci.person_role_id))
  AND EXISTS (SELECT 1 FROM ya_19c_rewriteYa125_up_n AS n WHERE (n.id = ci.person_id));

CREATE OR REPLACE TEMP VIEW ya_19c_rewriteYa125_up_cn AS
SELECT cn.*
FROM ya_19c_rewriteYa125_base_cn AS cn;

CREATE OR REPLACE TEMP VIEW ya_19c_rewriteYa125_up_mc AS
SELECT mc.*
FROM ya_19c_rewriteYa125_base_mc AS mc
WHERE EXISTS (SELECT 1 FROM ya_19c_rewriteYa125_up_mi AS mi WHERE (mc.movie_id = mi.movie_id))
  AND EXISTS (SELECT 1 FROM ya_19c_rewriteYa125_up_t AS t WHERE (t.id = mc.movie_id))
  AND EXISTS (SELECT 1 FROM ya_19c_rewriteYa125_up_ci AS ci WHERE (mc.movie_id = ci.movie_id))
  AND EXISTS (SELECT 1 FROM ya_19c_rewriteYa125_up_cn AS cn WHERE (cn.id = mc.company_id));

CREATE OR REPLACE TEMP VIEW ya_19c_rewriteYa125_down_mc AS
SELECT mc.*
FROM ya_19c_rewriteYa125_up_mc AS mc;

CREATE OR REPLACE TEMP VIEW ya_19c_rewriteYa125_down_mi AS
SELECT mi.*
FROM ya_19c_rewriteYa125_up_mi AS mi
WHERE EXISTS (SELECT 1 FROM ya_19c_rewriteYa125_down_mc AS mc WHERE (mc.movie_id = mi.movie_id));

CREATE OR REPLACE TEMP VIEW ya_19c_rewriteYa125_down_t AS
SELECT t.*
FROM ya_19c_rewriteYa125_up_t AS t
WHERE EXISTS (SELECT 1 FROM ya_19c_rewriteYa125_down_mc AS mc WHERE (t.id = mc.movie_id));

CREATE OR REPLACE TEMP VIEW ya_19c_rewriteYa125_down_ci AS
SELECT ci.*
FROM ya_19c_rewriteYa125_up_ci AS ci
WHERE EXISTS (SELECT 1 FROM ya_19c_rewriteYa125_down_mc AS mc WHERE (mc.movie_id = ci.movie_id));

CREATE OR REPLACE TEMP VIEW ya_19c_rewriteYa125_down_cn AS
SELECT cn.*
FROM ya_19c_rewriteYa125_up_cn AS cn
WHERE EXISTS (SELECT 1 FROM ya_19c_rewriteYa125_down_mc AS mc WHERE (cn.id = mc.company_id));

CREATE OR REPLACE TEMP VIEW ya_19c_rewriteYa125_down_it AS
SELECT it.*
FROM ya_19c_rewriteYa125_up_it AS it
WHERE EXISTS (SELECT 1 FROM ya_19c_rewriteYa125_down_mi AS mi WHERE (it.id = mi.info_type_id));

CREATE OR REPLACE TEMP VIEW ya_19c_rewriteYa125_down_rt AS
SELECT rt.*
FROM ya_19c_rewriteYa125_up_rt AS rt
WHERE EXISTS (SELECT 1 FROM ya_19c_rewriteYa125_down_ci AS ci WHERE (rt.id = ci.role_id));

CREATE OR REPLACE TEMP VIEW ya_19c_rewriteYa125_down_an AS
SELECT an.*
FROM ya_19c_rewriteYa125_up_an AS an
WHERE EXISTS (SELECT 1 FROM ya_19c_rewriteYa125_down_ci AS ci WHERE (ci.person_id = an.person_id));

CREATE OR REPLACE TEMP VIEW ya_19c_rewriteYa125_down_chn AS
SELECT chn.*
FROM ya_19c_rewriteYa125_up_chn AS chn
WHERE EXISTS (SELECT 1 FROM ya_19c_rewriteYa125_down_ci AS ci WHERE (chn.id = ci.person_role_id));

CREATE OR REPLACE TEMP VIEW ya_19c_rewriteYa125_down_n AS
SELECT n.*
FROM ya_19c_rewriteYa125_up_n AS n
WHERE EXISTS (SELECT 1 FROM ya_19c_rewriteYa125_down_ci AS ci WHERE (n.id = ci.person_id));

SELECT n.name,
       t.title,
       SUM(1) AS record_count
FROM ya_19c_rewriteYa125_down_an AS an,
     ya_19c_rewriteYa125_down_chn AS chn,
     ya_19c_rewriteYa125_down_ci AS ci,
     ya_19c_rewriteYa125_down_cn AS cn,
     ya_19c_rewriteYa125_down_it AS it,
     ya_19c_rewriteYa125_down_mc AS mc,
     ya_19c_rewriteYa125_down_mi AS mi,
     ya_19c_rewriteYa125_down_n AS n,
     ya_19c_rewriteYa125_down_rt AS rt,
     ya_19c_rewriteYa125_down_t AS t
WHERE (ci.note IN ('(voice)',
                  '(voice: Japanese version)',
                  '(voice) (uncredited)',
                  '(voice: English version)'))
  AND (cn.country_code ='[us]')
  AND (it.info = 'release dates')
  AND (mi.info IS NOT NULL)
  AND ((mi.info LIKE 'Japan:%200%'
       OR mi.info LIKE 'USA:%200%'))
  AND (n.gender ='f')
  AND (n.name LIKE '%An%')
  AND (rt.role ='actress')
  AND (t.production_year > 2000)
  AND (t.id = mi.movie_id)
  AND (t.id = mc.movie_id)
  AND (t.id = ci.movie_id)
  AND (mc.movie_id = ci.movie_id)
  AND (mc.movie_id = mi.movie_id)
  AND (mi.movie_id = ci.movie_id)
  AND (cn.id = mc.company_id)
  AND (it.id = mi.info_type_id)
  AND (n.id = ci.person_id)
  AND (rt.id = ci.role_id)
  AND (n.id = an.person_id)
  AND (ci.person_id = an.person_id)
  AND (chn.id = ci.person_role_id)
GROUP BY n.name, t.title;
