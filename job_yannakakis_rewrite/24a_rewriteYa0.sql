-- DuckDB SUM(1) Yannakakis-style two-pass reducer generated from job_agg/24a.sql.

-- Source variant: query/job_duckdb/24a/rewriteYa0.sql

CREATE OR REPLACE TEMP VIEW ya_24a_rewriteYa0_base_an AS
SELECT an.*
FROM aka_name AS an;

CREATE OR REPLACE TEMP VIEW ya_24a_rewriteYa0_base_chn AS
SELECT chn.*
FROM char_name AS chn;

CREATE OR REPLACE TEMP VIEW ya_24a_rewriteYa0_base_ci AS
SELECT ci.*
FROM cast_info AS ci
WHERE (ci.note IN ('(voice)',
                  '(voice: Japanese version)',
                  '(voice) (uncredited)',
                  '(voice: English version)'));

CREATE OR REPLACE TEMP VIEW ya_24a_rewriteYa0_base_cn AS
SELECT cn.*
FROM company_name AS cn
WHERE (cn.country_code ='[us]');

CREATE OR REPLACE TEMP VIEW ya_24a_rewriteYa0_base_it AS
SELECT it.*
FROM info_type AS it
WHERE (it.info = 'release dates');

CREATE OR REPLACE TEMP VIEW ya_24a_rewriteYa0_base_k AS
SELECT k.*
FROM keyword AS k
WHERE (k.keyword IN ('hero',
                    'martial-arts',
                    'hand-to-hand-combat'));

CREATE OR REPLACE TEMP VIEW ya_24a_rewriteYa0_base_mc AS
SELECT mc.*
FROM movie_companies AS mc;

CREATE OR REPLACE TEMP VIEW ya_24a_rewriteYa0_base_mi AS
SELECT mi.*
FROM movie_info AS mi
WHERE (mi.info IS NOT NULL)
  AND ((mi.info LIKE 'Japan:%201%'
       OR mi.info LIKE 'USA:%201%'));

CREATE OR REPLACE TEMP VIEW ya_24a_rewriteYa0_base_mk AS
SELECT mk.*
FROM movie_keyword AS mk;

CREATE OR REPLACE TEMP VIEW ya_24a_rewriteYa0_base_n AS
SELECT n.*
FROM name AS n
WHERE (n.gender ='f')
  AND (n.name LIKE '%An%');

CREATE OR REPLACE TEMP VIEW ya_24a_rewriteYa0_base_rt AS
SELECT rt.*
FROM role_type AS rt
WHERE (rt.role ='actress');

CREATE OR REPLACE TEMP VIEW ya_24a_rewriteYa0_base_t AS
SELECT t.*
FROM title AS t
WHERE (t.production_year > 2010);

CREATE OR REPLACE TEMP VIEW ya_24a_rewriteYa0_up_n AS
SELECT n.*
FROM ya_24a_rewriteYa0_base_n AS n;

CREATE OR REPLACE TEMP VIEW ya_24a_rewriteYa0_up_it AS
SELECT it.*
FROM ya_24a_rewriteYa0_base_it AS it;

CREATE OR REPLACE TEMP VIEW ya_24a_rewriteYa0_up_mi AS
SELECT mi.*
FROM ya_24a_rewriteYa0_base_mi AS mi
WHERE EXISTS (SELECT 1 FROM ya_24a_rewriteYa0_up_it AS it WHERE (it.id = mi.info_type_id));

CREATE OR REPLACE TEMP VIEW ya_24a_rewriteYa0_up_k AS
SELECT k.*
FROM ya_24a_rewriteYa0_base_k AS k;

CREATE OR REPLACE TEMP VIEW ya_24a_rewriteYa0_up_mk AS
SELECT mk.*
FROM ya_24a_rewriteYa0_base_mk AS mk
WHERE EXISTS (SELECT 1 FROM ya_24a_rewriteYa0_up_k AS k WHERE (k.id = mk.keyword_id));

CREATE OR REPLACE TEMP VIEW ya_24a_rewriteYa0_up_rt AS
SELECT rt.*
FROM ya_24a_rewriteYa0_base_rt AS rt;

CREATE OR REPLACE TEMP VIEW ya_24a_rewriteYa0_up_t AS
SELECT t.*
FROM ya_24a_rewriteYa0_base_t AS t;

CREATE OR REPLACE TEMP VIEW ya_24a_rewriteYa0_up_chn AS
SELECT chn.*
FROM ya_24a_rewriteYa0_base_chn AS chn;

CREATE OR REPLACE TEMP VIEW ya_24a_rewriteYa0_up_cn AS
SELECT cn.*
FROM ya_24a_rewriteYa0_base_cn AS cn;

CREATE OR REPLACE TEMP VIEW ya_24a_rewriteYa0_up_mc AS
SELECT mc.*
FROM ya_24a_rewriteYa0_base_mc AS mc
WHERE EXISTS (SELECT 1 FROM ya_24a_rewriteYa0_up_cn AS cn WHERE (cn.id = mc.company_id));

CREATE OR REPLACE TEMP VIEW ya_24a_rewriteYa0_up_ci AS
SELECT ci.*
FROM ya_24a_rewriteYa0_base_ci AS ci
WHERE EXISTS (SELECT 1 FROM ya_24a_rewriteYa0_up_mi AS mi WHERE (mi.movie_id = ci.movie_id))
  AND EXISTS (SELECT 1 FROM ya_24a_rewriteYa0_up_mk AS mk WHERE (ci.movie_id = mk.movie_id))
  AND EXISTS (SELECT 1 FROM ya_24a_rewriteYa0_up_rt AS rt WHERE (rt.id = ci.role_id))
  AND EXISTS (SELECT 1 FROM ya_24a_rewriteYa0_up_t AS t WHERE (t.id = ci.movie_id))
  AND EXISTS (SELECT 1 FROM ya_24a_rewriteYa0_up_chn AS chn WHERE (chn.id = ci.person_role_id))
  AND EXISTS (SELECT 1 FROM ya_24a_rewriteYa0_up_mc AS mc WHERE (mc.movie_id = ci.movie_id));

CREATE OR REPLACE TEMP VIEW ya_24a_rewriteYa0_up_an AS
SELECT an.*
FROM ya_24a_rewriteYa0_base_an AS an
WHERE EXISTS (SELECT 1 FROM ya_24a_rewriteYa0_up_n AS n WHERE (n.id = an.person_id))
  AND EXISTS (SELECT 1 FROM ya_24a_rewriteYa0_up_ci AS ci WHERE (ci.person_id = an.person_id));

CREATE OR REPLACE TEMP VIEW ya_24a_rewriteYa0_down_an AS
SELECT an.*
FROM ya_24a_rewriteYa0_up_an AS an;

CREATE OR REPLACE TEMP VIEW ya_24a_rewriteYa0_down_n AS
SELECT n.*
FROM ya_24a_rewriteYa0_up_n AS n
WHERE EXISTS (SELECT 1 FROM ya_24a_rewriteYa0_down_an AS an WHERE (n.id = an.person_id));

CREATE OR REPLACE TEMP VIEW ya_24a_rewriteYa0_down_ci AS
SELECT ci.*
FROM ya_24a_rewriteYa0_up_ci AS ci
WHERE EXISTS (SELECT 1 FROM ya_24a_rewriteYa0_down_an AS an WHERE (ci.person_id = an.person_id));

CREATE OR REPLACE TEMP VIEW ya_24a_rewriteYa0_down_mi AS
SELECT mi.*
FROM ya_24a_rewriteYa0_up_mi AS mi
WHERE EXISTS (SELECT 1 FROM ya_24a_rewriteYa0_down_ci AS ci WHERE (mi.movie_id = ci.movie_id));

CREATE OR REPLACE TEMP VIEW ya_24a_rewriteYa0_down_mk AS
SELECT mk.*
FROM ya_24a_rewriteYa0_up_mk AS mk
WHERE EXISTS (SELECT 1 FROM ya_24a_rewriteYa0_down_ci AS ci WHERE (ci.movie_id = mk.movie_id));

CREATE OR REPLACE TEMP VIEW ya_24a_rewriteYa0_down_rt AS
SELECT rt.*
FROM ya_24a_rewriteYa0_up_rt AS rt
WHERE EXISTS (SELECT 1 FROM ya_24a_rewriteYa0_down_ci AS ci WHERE (rt.id = ci.role_id));

CREATE OR REPLACE TEMP VIEW ya_24a_rewriteYa0_down_t AS
SELECT t.*
FROM ya_24a_rewriteYa0_up_t AS t
WHERE EXISTS (SELECT 1 FROM ya_24a_rewriteYa0_down_ci AS ci WHERE (t.id = ci.movie_id));

CREATE OR REPLACE TEMP VIEW ya_24a_rewriteYa0_down_chn AS
SELECT chn.*
FROM ya_24a_rewriteYa0_up_chn AS chn
WHERE EXISTS (SELECT 1 FROM ya_24a_rewriteYa0_down_ci AS ci WHERE (chn.id = ci.person_role_id));

CREATE OR REPLACE TEMP VIEW ya_24a_rewriteYa0_down_mc AS
SELECT mc.*
FROM ya_24a_rewriteYa0_up_mc AS mc
WHERE EXISTS (SELECT 1 FROM ya_24a_rewriteYa0_down_ci AS ci WHERE (mc.movie_id = ci.movie_id));

CREATE OR REPLACE TEMP VIEW ya_24a_rewriteYa0_down_it AS
SELECT it.*
FROM ya_24a_rewriteYa0_up_it AS it
WHERE EXISTS (SELECT 1 FROM ya_24a_rewriteYa0_down_mi AS mi WHERE (it.id = mi.info_type_id));

CREATE OR REPLACE TEMP VIEW ya_24a_rewriteYa0_down_k AS
SELECT k.*
FROM ya_24a_rewriteYa0_up_k AS k
WHERE EXISTS (SELECT 1 FROM ya_24a_rewriteYa0_down_mk AS mk WHERE (k.id = mk.keyword_id));

CREATE OR REPLACE TEMP VIEW ya_24a_rewriteYa0_down_cn AS
SELECT cn.*
FROM ya_24a_rewriteYa0_up_cn AS cn
WHERE EXISTS (SELECT 1 FROM ya_24a_rewriteYa0_down_mc AS mc WHERE (cn.id = mc.company_id));

SELECT chn.name,
       n.name,
       t.title,
       SUM(1) AS record_count
FROM ya_24a_rewriteYa0_down_an AS an,
     ya_24a_rewriteYa0_down_chn AS chn,
     ya_24a_rewriteYa0_down_ci AS ci,
     ya_24a_rewriteYa0_down_cn AS cn,
     ya_24a_rewriteYa0_down_it AS it,
     ya_24a_rewriteYa0_down_k AS k,
     ya_24a_rewriteYa0_down_mc AS mc,
     ya_24a_rewriteYa0_down_mi AS mi,
     ya_24a_rewriteYa0_down_mk AS mk,
     ya_24a_rewriteYa0_down_n AS n,
     ya_24a_rewriteYa0_down_rt AS rt,
     ya_24a_rewriteYa0_down_t AS t
WHERE (ci.note IN ('(voice)',
                  '(voice: Japanese version)',
                  '(voice) (uncredited)',
                  '(voice: English version)'))
  AND (cn.country_code ='[us]')
  AND (it.info = 'release dates')
  AND (k.keyword IN ('hero',
                    'martial-arts',
                    'hand-to-hand-combat'))
  AND (mi.info IS NOT NULL)
  AND ((mi.info LIKE 'Japan:%201%'
       OR mi.info LIKE 'USA:%201%'))
  AND (n.gender ='f')
  AND (n.name LIKE '%An%')
  AND (rt.role ='actress')
  AND (t.production_year > 2010)
  AND (t.id = mi.movie_id)
  AND (t.id = mc.movie_id)
  AND (t.id = ci.movie_id)
  AND (t.id = mk.movie_id)
  AND (mc.movie_id = ci.movie_id)
  AND (mc.movie_id = mi.movie_id)
  AND (mc.movie_id = mk.movie_id)
  AND (mi.movie_id = ci.movie_id)
  AND (mi.movie_id = mk.movie_id)
  AND (ci.movie_id = mk.movie_id)
  AND (cn.id = mc.company_id)
  AND (it.id = mi.info_type_id)
  AND (n.id = ci.person_id)
  AND (rt.id = ci.role_id)
  AND (n.id = an.person_id)
  AND (ci.person_id = an.person_id)
  AND (chn.id = ci.person_role_id)
  AND (k.id = mk.keyword_id)
GROUP BY chn.name, n.name, t.title;
