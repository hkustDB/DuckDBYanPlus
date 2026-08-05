-- DuckDB SUM(1) Yannakakis-style two-pass reducer generated from job_agg/8b.sql.

-- Source variant: query/job_duckdb/8b/rewriteYa10.sql

CREATE OR REPLACE TEMP VIEW ya_8b_rewriteYa10_base_an AS
SELECT an.*
FROM aka_name AS an;

CREATE OR REPLACE TEMP VIEW ya_8b_rewriteYa10_base_ci AS
SELECT ci.*
FROM cast_info AS ci
WHERE (ci.note ='(voice: English version)');

CREATE OR REPLACE TEMP VIEW ya_8b_rewriteYa10_base_cn AS
SELECT cn.*
FROM company_name AS cn
WHERE (cn.country_code ='[jp]');

CREATE OR REPLACE TEMP VIEW ya_8b_rewriteYa10_base_mc AS
SELECT mc.*
FROM movie_companies AS mc
WHERE (mc.note LIKE '%(Japan)%')
  AND (mc.note NOT LIKE '%(USA)%')
  AND ((mc.note LIKE '%(2006)%'
       OR mc.note LIKE '%(2007)%'));

CREATE OR REPLACE TEMP VIEW ya_8b_rewriteYa10_base_n AS
SELECT n.*
FROM name AS n
WHERE (n.name LIKE '%Yo%')
  AND (n.name NOT LIKE '%Yu%');

CREATE OR REPLACE TEMP VIEW ya_8b_rewriteYa10_base_rt AS
SELECT rt.*
FROM role_type AS rt
WHERE (rt.role ='actress');

CREATE OR REPLACE TEMP VIEW ya_8b_rewriteYa10_base_t AS
SELECT t.*
FROM title AS t
WHERE (t.production_year BETWEEN 2006 AND 2007)
  AND ((t.title LIKE 'One Piece%'
       OR t.title LIKE 'Dragon Ball Z%'));

CREATE OR REPLACE TEMP VIEW ya_8b_rewriteYa10_up_t AS
SELECT t.*
FROM ya_8b_rewriteYa10_base_t AS t;

CREATE OR REPLACE TEMP VIEW ya_8b_rewriteYa10_up_an AS
SELECT an.*
FROM ya_8b_rewriteYa10_base_an AS an;

CREATE OR REPLACE TEMP VIEW ya_8b_rewriteYa10_up_n AS
SELECT n.*
FROM ya_8b_rewriteYa10_base_n AS n;

CREATE OR REPLACE TEMP VIEW ya_8b_rewriteYa10_up_rt AS
SELECT rt.*
FROM ya_8b_rewriteYa10_base_rt AS rt;

CREATE OR REPLACE TEMP VIEW ya_8b_rewriteYa10_up_ci AS
SELECT ci.*
FROM ya_8b_rewriteYa10_base_ci AS ci
WHERE EXISTS (SELECT 1 FROM ya_8b_rewriteYa10_up_an AS an WHERE (an.person_id = ci.person_id))
  AND EXISTS (SELECT 1 FROM ya_8b_rewriteYa10_up_n AS n WHERE (n.id = ci.person_id))
  AND EXISTS (SELECT 1 FROM ya_8b_rewriteYa10_up_rt AS rt WHERE (ci.role_id = rt.id));

CREATE OR REPLACE TEMP VIEW ya_8b_rewriteYa10_up_cn AS
SELECT cn.*
FROM ya_8b_rewriteYa10_base_cn AS cn;

CREATE OR REPLACE TEMP VIEW ya_8b_rewriteYa10_up_mc AS
SELECT mc.*
FROM ya_8b_rewriteYa10_base_mc AS mc
WHERE EXISTS (SELECT 1 FROM ya_8b_rewriteYa10_up_t AS t WHERE (t.id = mc.movie_id))
  AND EXISTS (SELECT 1 FROM ya_8b_rewriteYa10_up_ci AS ci WHERE (ci.movie_id = mc.movie_id))
  AND EXISTS (SELECT 1 FROM ya_8b_rewriteYa10_up_cn AS cn WHERE (mc.company_id = cn.id));

CREATE OR REPLACE TEMP VIEW ya_8b_rewriteYa10_down_mc AS
SELECT mc.*
FROM ya_8b_rewriteYa10_up_mc AS mc;

CREATE OR REPLACE TEMP VIEW ya_8b_rewriteYa10_down_t AS
SELECT t.*
FROM ya_8b_rewriteYa10_up_t AS t
WHERE EXISTS (SELECT 1 FROM ya_8b_rewriteYa10_down_mc AS mc WHERE (t.id = mc.movie_id));

CREATE OR REPLACE TEMP VIEW ya_8b_rewriteYa10_down_ci AS
SELECT ci.*
FROM ya_8b_rewriteYa10_up_ci AS ci
WHERE EXISTS (SELECT 1 FROM ya_8b_rewriteYa10_down_mc AS mc WHERE (ci.movie_id = mc.movie_id));

CREATE OR REPLACE TEMP VIEW ya_8b_rewriteYa10_down_cn AS
SELECT cn.*
FROM ya_8b_rewriteYa10_up_cn AS cn
WHERE EXISTS (SELECT 1 FROM ya_8b_rewriteYa10_down_mc AS mc WHERE (mc.company_id = cn.id));

CREATE OR REPLACE TEMP VIEW ya_8b_rewriteYa10_down_an AS
SELECT an.*
FROM ya_8b_rewriteYa10_up_an AS an
WHERE EXISTS (SELECT 1 FROM ya_8b_rewriteYa10_down_ci AS ci WHERE (an.person_id = ci.person_id));

CREATE OR REPLACE TEMP VIEW ya_8b_rewriteYa10_down_n AS
SELECT n.*
FROM ya_8b_rewriteYa10_up_n AS n
WHERE EXISTS (SELECT 1 FROM ya_8b_rewriteYa10_down_ci AS ci WHERE (n.id = ci.person_id));

CREATE OR REPLACE TEMP VIEW ya_8b_rewriteYa10_down_rt AS
SELECT rt.*
FROM ya_8b_rewriteYa10_up_rt AS rt
WHERE EXISTS (SELECT 1 FROM ya_8b_rewriteYa10_down_ci AS ci WHERE (ci.role_id = rt.id));

SELECT an.name,
       t.title,
       SUM(1) AS record_count
FROM ya_8b_rewriteYa10_down_an AS an,
     ya_8b_rewriteYa10_down_ci AS ci,
     ya_8b_rewriteYa10_down_cn AS cn,
     ya_8b_rewriteYa10_down_mc AS mc,
     ya_8b_rewriteYa10_down_n AS n,
     ya_8b_rewriteYa10_down_rt AS rt,
     ya_8b_rewriteYa10_down_t AS t
WHERE (ci.note ='(voice: English version)')
  AND (cn.country_code ='[jp]')
  AND (mc.note LIKE '%(Japan)%')
  AND (mc.note NOT LIKE '%(USA)%')
  AND ((mc.note LIKE '%(2006)%'
       OR mc.note LIKE '%(2007)%'))
  AND (n.name LIKE '%Yo%')
  AND (n.name NOT LIKE '%Yu%')
  AND (rt.role ='actress')
  AND (t.production_year BETWEEN 2006 AND 2007)
  AND ((t.title LIKE 'One Piece%'
       OR t.title LIKE 'Dragon Ball Z%'))
  AND (an.person_id = n.id)
  AND (n.id = ci.person_id)
  AND (ci.movie_id = t.id)
  AND (t.id = mc.movie_id)
  AND (mc.company_id = cn.id)
  AND (ci.role_id = rt.id)
  AND (an.person_id = ci.person_id)
  AND (ci.movie_id = mc.movie_id)
GROUP BY an.name, t.title;
