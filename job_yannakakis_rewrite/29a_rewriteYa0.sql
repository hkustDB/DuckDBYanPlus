-- DuckDB SUM(1) Yannakakis-style two-pass reducer generated from job_agg/29a.sql.

-- Source variant: query/job_duckdb/29a/rewriteYa0.sql

CREATE OR REPLACE TEMP VIEW ya_29a_rewriteYa0_base_an AS
SELECT an.*
FROM aka_name AS an;

CREATE OR REPLACE TEMP VIEW ya_29a_rewriteYa0_base_cc AS
SELECT cc.*
FROM complete_cast AS cc;

CREATE OR REPLACE TEMP VIEW ya_29a_rewriteYa0_base_cct1 AS
SELECT cct1.*
FROM comp_cast_type AS cct1
WHERE (cct1.kind ='cast');

CREATE OR REPLACE TEMP VIEW ya_29a_rewriteYa0_base_cct2 AS
SELECT cct2.*
FROM comp_cast_type AS cct2
WHERE (cct2.kind ='complete+verified');

CREATE OR REPLACE TEMP VIEW ya_29a_rewriteYa0_base_chn AS
SELECT chn.*
FROM char_name AS chn
WHERE (chn.name = 'Queen');

CREATE OR REPLACE TEMP VIEW ya_29a_rewriteYa0_base_ci AS
SELECT ci.*
FROM cast_info AS ci
WHERE (ci.note IN ('(voice)',
                  '(voice) (uncredited)',
                  '(voice: English version)'));

CREATE OR REPLACE TEMP VIEW ya_29a_rewriteYa0_base_cn AS
SELECT cn.*
FROM company_name AS cn
WHERE (cn.country_code ='[us]');

CREATE OR REPLACE TEMP VIEW ya_29a_rewriteYa0_base_it AS
SELECT it.*
FROM info_type AS it
WHERE (it.info = 'release dates');

CREATE OR REPLACE TEMP VIEW ya_29a_rewriteYa0_base_it3 AS
SELECT it3.*
FROM info_type AS it3
WHERE (it3.info = 'trivia');

CREATE OR REPLACE TEMP VIEW ya_29a_rewriteYa0_base_k AS
SELECT k.*
FROM keyword AS k
WHERE (k.keyword = 'computer-animation');

CREATE OR REPLACE TEMP VIEW ya_29a_rewriteYa0_base_mc AS
SELECT mc.*
FROM movie_companies AS mc;

CREATE OR REPLACE TEMP VIEW ya_29a_rewriteYa0_base_mi AS
SELECT mi.*
FROM movie_info AS mi
WHERE (mi.info IS NOT NULL)
  AND ((mi.info LIKE 'Japan:%200%'
       OR mi.info LIKE 'USA:%200%'));

CREATE OR REPLACE TEMP VIEW ya_29a_rewriteYa0_base_mk AS
SELECT mk.*
FROM movie_keyword AS mk;

CREATE OR REPLACE TEMP VIEW ya_29a_rewriteYa0_base_n AS
SELECT n.*
FROM name AS n
WHERE (n.gender ='f')
  AND (n.name LIKE '%An%');

CREATE OR REPLACE TEMP VIEW ya_29a_rewriteYa0_base_pi AS
SELECT pi.*
FROM person_info AS pi;

CREATE OR REPLACE TEMP VIEW ya_29a_rewriteYa0_base_rt AS
SELECT rt.*
FROM role_type AS rt
WHERE (rt.role ='actress');

CREATE OR REPLACE TEMP VIEW ya_29a_rewriteYa0_base_t AS
SELECT t.*
FROM title AS t
WHERE (t.title = 'Shrek 2')
  AND (t.production_year BETWEEN 2000 AND 2010);

CREATE OR REPLACE TEMP VIEW ya_29a_rewriteYa0_up_it3 AS
SELECT it3.*
FROM ya_29a_rewriteYa0_base_it3 AS it3;

CREATE OR REPLACE TEMP VIEW ya_29a_rewriteYa0_up_pi AS
SELECT pi.*
FROM ya_29a_rewriteYa0_base_pi AS pi
WHERE EXISTS (SELECT 1 FROM ya_29a_rewriteYa0_up_it3 AS it3 WHERE (it3.id = pi.info_type_id));

CREATE OR REPLACE TEMP VIEW ya_29a_rewriteYa0_up_n AS
SELECT n.*
FROM ya_29a_rewriteYa0_base_n AS n
WHERE EXISTS (SELECT 1 FROM ya_29a_rewriteYa0_up_pi AS pi WHERE (n.id = pi.person_id));

CREATE OR REPLACE TEMP VIEW ya_29a_rewriteYa0_up_it AS
SELECT it.*
FROM ya_29a_rewriteYa0_base_it AS it;

CREATE OR REPLACE TEMP VIEW ya_29a_rewriteYa0_up_mi AS
SELECT mi.*
FROM ya_29a_rewriteYa0_base_mi AS mi
WHERE EXISTS (SELECT 1 FROM ya_29a_rewriteYa0_up_it AS it WHERE (it.id = mi.info_type_id));

CREATE OR REPLACE TEMP VIEW ya_29a_rewriteYa0_up_k AS
SELECT k.*
FROM ya_29a_rewriteYa0_base_k AS k;

CREATE OR REPLACE TEMP VIEW ya_29a_rewriteYa0_up_mk AS
SELECT mk.*
FROM ya_29a_rewriteYa0_base_mk AS mk
WHERE EXISTS (SELECT 1 FROM ya_29a_rewriteYa0_up_k AS k WHERE (k.id = mk.keyword_id));

CREATE OR REPLACE TEMP VIEW ya_29a_rewriteYa0_up_rt AS
SELECT rt.*
FROM ya_29a_rewriteYa0_base_rt AS rt;

CREATE OR REPLACE TEMP VIEW ya_29a_rewriteYa0_up_t AS
SELECT t.*
FROM ya_29a_rewriteYa0_base_t AS t;

CREATE OR REPLACE TEMP VIEW ya_29a_rewriteYa0_up_cct1 AS
SELECT cct1.*
FROM ya_29a_rewriteYa0_base_cct1 AS cct1;

CREATE OR REPLACE TEMP VIEW ya_29a_rewriteYa0_up_cct2 AS
SELECT cct2.*
FROM ya_29a_rewriteYa0_base_cct2 AS cct2;

CREATE OR REPLACE TEMP VIEW ya_29a_rewriteYa0_up_cc AS
SELECT cc.*
FROM ya_29a_rewriteYa0_base_cc AS cc
WHERE EXISTS (SELECT 1 FROM ya_29a_rewriteYa0_up_cct1 AS cct1 WHERE (cct1.id = cc.subject_id))
  AND EXISTS (SELECT 1 FROM ya_29a_rewriteYa0_up_cct2 AS cct2 WHERE (cct2.id = cc.status_id));

CREATE OR REPLACE TEMP VIEW ya_29a_rewriteYa0_up_chn AS
SELECT chn.*
FROM ya_29a_rewriteYa0_base_chn AS chn;

CREATE OR REPLACE TEMP VIEW ya_29a_rewriteYa0_up_cn AS
SELECT cn.*
FROM ya_29a_rewriteYa0_base_cn AS cn;

CREATE OR REPLACE TEMP VIEW ya_29a_rewriteYa0_up_mc AS
SELECT mc.*
FROM ya_29a_rewriteYa0_base_mc AS mc
WHERE EXISTS (SELECT 1 FROM ya_29a_rewriteYa0_up_cn AS cn WHERE (cn.id = mc.company_id));

CREATE OR REPLACE TEMP VIEW ya_29a_rewriteYa0_up_ci AS
SELECT ci.*
FROM ya_29a_rewriteYa0_base_ci AS ci
WHERE EXISTS (SELECT 1 FROM ya_29a_rewriteYa0_up_mi AS mi WHERE (mi.movie_id = ci.movie_id))
  AND EXISTS (SELECT 1 FROM ya_29a_rewriteYa0_up_mk AS mk WHERE (ci.movie_id = mk.movie_id))
  AND EXISTS (SELECT 1 FROM ya_29a_rewriteYa0_up_rt AS rt WHERE (rt.id = ci.role_id))
  AND EXISTS (SELECT 1 FROM ya_29a_rewriteYa0_up_t AS t WHERE (t.id = ci.movie_id))
  AND EXISTS (SELECT 1 FROM ya_29a_rewriteYa0_up_cc AS cc WHERE (ci.movie_id = cc.movie_id))
  AND EXISTS (SELECT 1 FROM ya_29a_rewriteYa0_up_chn AS chn WHERE (chn.id = ci.person_role_id))
  AND EXISTS (SELECT 1 FROM ya_29a_rewriteYa0_up_mc AS mc WHERE (mc.movie_id = ci.movie_id));

CREATE OR REPLACE TEMP VIEW ya_29a_rewriteYa0_up_an AS
SELECT an.*
FROM ya_29a_rewriteYa0_base_an AS an
WHERE EXISTS (SELECT 1 FROM ya_29a_rewriteYa0_up_n AS n WHERE (n.id = an.person_id))
  AND EXISTS (SELECT 1 FROM ya_29a_rewriteYa0_up_ci AS ci WHERE (ci.person_id = an.person_id));

CREATE OR REPLACE TEMP VIEW ya_29a_rewriteYa0_down_an AS
SELECT an.*
FROM ya_29a_rewriteYa0_up_an AS an;

CREATE OR REPLACE TEMP VIEW ya_29a_rewriteYa0_down_n AS
SELECT n.*
FROM ya_29a_rewriteYa0_up_n AS n
WHERE EXISTS (SELECT 1 FROM ya_29a_rewriteYa0_down_an AS an WHERE (n.id = an.person_id));

CREATE OR REPLACE TEMP VIEW ya_29a_rewriteYa0_down_ci AS
SELECT ci.*
FROM ya_29a_rewriteYa0_up_ci AS ci
WHERE EXISTS (SELECT 1 FROM ya_29a_rewriteYa0_down_an AS an WHERE (ci.person_id = an.person_id));

CREATE OR REPLACE TEMP VIEW ya_29a_rewriteYa0_down_pi AS
SELECT pi.*
FROM ya_29a_rewriteYa0_up_pi AS pi
WHERE EXISTS (SELECT 1 FROM ya_29a_rewriteYa0_down_n AS n WHERE (n.id = pi.person_id));

CREATE OR REPLACE TEMP VIEW ya_29a_rewriteYa0_down_mi AS
SELECT mi.*
FROM ya_29a_rewriteYa0_up_mi AS mi
WHERE EXISTS (SELECT 1 FROM ya_29a_rewriteYa0_down_ci AS ci WHERE (mi.movie_id = ci.movie_id));

CREATE OR REPLACE TEMP VIEW ya_29a_rewriteYa0_down_mk AS
SELECT mk.*
FROM ya_29a_rewriteYa0_up_mk AS mk
WHERE EXISTS (SELECT 1 FROM ya_29a_rewriteYa0_down_ci AS ci WHERE (ci.movie_id = mk.movie_id));

CREATE OR REPLACE TEMP VIEW ya_29a_rewriteYa0_down_rt AS
SELECT rt.*
FROM ya_29a_rewriteYa0_up_rt AS rt
WHERE EXISTS (SELECT 1 FROM ya_29a_rewriteYa0_down_ci AS ci WHERE (rt.id = ci.role_id));

CREATE OR REPLACE TEMP VIEW ya_29a_rewriteYa0_down_t AS
SELECT t.*
FROM ya_29a_rewriteYa0_up_t AS t
WHERE EXISTS (SELECT 1 FROM ya_29a_rewriteYa0_down_ci AS ci WHERE (t.id = ci.movie_id));

CREATE OR REPLACE TEMP VIEW ya_29a_rewriteYa0_down_cc AS
SELECT cc.*
FROM ya_29a_rewriteYa0_up_cc AS cc
WHERE EXISTS (SELECT 1 FROM ya_29a_rewriteYa0_down_ci AS ci WHERE (ci.movie_id = cc.movie_id));

CREATE OR REPLACE TEMP VIEW ya_29a_rewriteYa0_down_chn AS
SELECT chn.*
FROM ya_29a_rewriteYa0_up_chn AS chn
WHERE EXISTS (SELECT 1 FROM ya_29a_rewriteYa0_down_ci AS ci WHERE (chn.id = ci.person_role_id));

CREATE OR REPLACE TEMP VIEW ya_29a_rewriteYa0_down_mc AS
SELECT mc.*
FROM ya_29a_rewriteYa0_up_mc AS mc
WHERE EXISTS (SELECT 1 FROM ya_29a_rewriteYa0_down_ci AS ci WHERE (mc.movie_id = ci.movie_id));

CREATE OR REPLACE TEMP VIEW ya_29a_rewriteYa0_down_it3 AS
SELECT it3.*
FROM ya_29a_rewriteYa0_up_it3 AS it3
WHERE EXISTS (SELECT 1 FROM ya_29a_rewriteYa0_down_pi AS pi WHERE (it3.id = pi.info_type_id));

CREATE OR REPLACE TEMP VIEW ya_29a_rewriteYa0_down_it AS
SELECT it.*
FROM ya_29a_rewriteYa0_up_it AS it
WHERE EXISTS (SELECT 1 FROM ya_29a_rewriteYa0_down_mi AS mi WHERE (it.id = mi.info_type_id));

CREATE OR REPLACE TEMP VIEW ya_29a_rewriteYa0_down_k AS
SELECT k.*
FROM ya_29a_rewriteYa0_up_k AS k
WHERE EXISTS (SELECT 1 FROM ya_29a_rewriteYa0_down_mk AS mk WHERE (k.id = mk.keyword_id));

CREATE OR REPLACE TEMP VIEW ya_29a_rewriteYa0_down_cct1 AS
SELECT cct1.*
FROM ya_29a_rewriteYa0_up_cct1 AS cct1
WHERE EXISTS (SELECT 1 FROM ya_29a_rewriteYa0_down_cc AS cc WHERE (cct1.id = cc.subject_id));

CREATE OR REPLACE TEMP VIEW ya_29a_rewriteYa0_down_cct2 AS
SELECT cct2.*
FROM ya_29a_rewriteYa0_up_cct2 AS cct2
WHERE EXISTS (SELECT 1 FROM ya_29a_rewriteYa0_down_cc AS cc WHERE (cct2.id = cc.status_id));

CREATE OR REPLACE TEMP VIEW ya_29a_rewriteYa0_down_cn AS
SELECT cn.*
FROM ya_29a_rewriteYa0_up_cn AS cn
WHERE EXISTS (SELECT 1 FROM ya_29a_rewriteYa0_down_mc AS mc WHERE (cn.id = mc.company_id));

SELECT chn.name,
       n.name,
       t.title,
       SUM(1) AS record_count
FROM ya_29a_rewriteYa0_down_an AS an,
     ya_29a_rewriteYa0_down_cc AS cc,
     ya_29a_rewriteYa0_down_cct1 AS cct1,
     ya_29a_rewriteYa0_down_cct2 AS cct2,
     ya_29a_rewriteYa0_down_chn AS chn,
     ya_29a_rewriteYa0_down_ci AS ci,
     ya_29a_rewriteYa0_down_cn AS cn,
     ya_29a_rewriteYa0_down_it AS it,
     ya_29a_rewriteYa0_down_it3 AS it3,
     ya_29a_rewriteYa0_down_k AS k,
     ya_29a_rewriteYa0_down_mc AS mc,
     ya_29a_rewriteYa0_down_mi AS mi,
     ya_29a_rewriteYa0_down_mk AS mk,
     ya_29a_rewriteYa0_down_n AS n,
     ya_29a_rewriteYa0_down_pi AS pi,
     ya_29a_rewriteYa0_down_rt AS rt,
     ya_29a_rewriteYa0_down_t AS t
WHERE (cct1.kind ='cast')
  AND (cct2.kind ='complete+verified')
  AND (chn.name = 'Queen')
  AND (ci.note IN ('(voice)',
                  '(voice) (uncredited)',
                  '(voice: English version)'))
  AND (cn.country_code ='[us]')
  AND (it.info = 'release dates')
  AND (it3.info = 'trivia')
  AND (k.keyword = 'computer-animation')
  AND (mi.info IS NOT NULL)
  AND ((mi.info LIKE 'Japan:%200%'
       OR mi.info LIKE 'USA:%200%'))
  AND (n.gender ='f')
  AND (n.name LIKE '%An%')
  AND (rt.role ='actress')
  AND (t.title = 'Shrek 2')
  AND (t.production_year BETWEEN 2000 AND 2010)
  AND (t.id = mi.movie_id)
  AND (t.id = mc.movie_id)
  AND (t.id = ci.movie_id)
  AND (t.id = mk.movie_id)
  AND (t.id = cc.movie_id)
  AND (mc.movie_id = ci.movie_id)
  AND (mc.movie_id = mi.movie_id)
  AND (mc.movie_id = mk.movie_id)
  AND (mc.movie_id = cc.movie_id)
  AND (mi.movie_id = ci.movie_id)
  AND (mi.movie_id = mk.movie_id)
  AND (mi.movie_id = cc.movie_id)
  AND (ci.movie_id = mk.movie_id)
  AND (ci.movie_id = cc.movie_id)
  AND (mk.movie_id = cc.movie_id)
  AND (cn.id = mc.company_id)
  AND (it.id = mi.info_type_id)
  AND (n.id = ci.person_id)
  AND (rt.id = ci.role_id)
  AND (n.id = an.person_id)
  AND (ci.person_id = an.person_id)
  AND (chn.id = ci.person_role_id)
  AND (n.id = pi.person_id)
  AND (ci.person_id = pi.person_id)
  AND (it3.id = pi.info_type_id)
  AND (k.id = mk.keyword_id)
  AND (cct1.id = cc.subject_id)
  AND (cct2.id = cc.status_id)
GROUP BY chn.name, n.name, t.title;
