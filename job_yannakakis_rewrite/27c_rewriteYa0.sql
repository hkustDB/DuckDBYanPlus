-- DuckDB SUM(1) Yannakakis-style two-pass reducer generated from job_agg/27c.sql.

-- Source variant: query/job_duckdb/27c/rewriteYa0.sql

CREATE OR REPLACE TEMP VIEW ya_27c_rewriteYa0_base_cc AS
SELECT cc.*
FROM complete_cast AS cc;

CREATE OR REPLACE TEMP VIEW ya_27c_rewriteYa0_base_cct1 AS
SELECT cct1.*
FROM comp_cast_type AS cct1
WHERE (cct1.kind = 'cast');

CREATE OR REPLACE TEMP VIEW ya_27c_rewriteYa0_base_cct2 AS
SELECT cct2.*
FROM comp_cast_type AS cct2
WHERE (cct2.kind LIKE 'complete%');

CREATE OR REPLACE TEMP VIEW ya_27c_rewriteYa0_base_cn AS
SELECT cn.*
FROM company_name AS cn
WHERE (cn.country_code !='[pl]')
  AND ((cn.name LIKE '%Film%'
       OR cn.name LIKE '%Warner%'));

CREATE OR REPLACE TEMP VIEW ya_27c_rewriteYa0_base_ct AS
SELECT ct.*
FROM company_type AS ct
WHERE (ct.kind ='production companies');

CREATE OR REPLACE TEMP VIEW ya_27c_rewriteYa0_base_k AS
SELECT k.*
FROM keyword AS k
WHERE (k.keyword ='sequel');

CREATE OR REPLACE TEMP VIEW ya_27c_rewriteYa0_base_lt AS
SELECT lt.*
FROM link_type AS lt
WHERE (lt.link LIKE '%follow%');

CREATE OR REPLACE TEMP VIEW ya_27c_rewriteYa0_base_mc AS
SELECT mc.*
FROM movie_companies AS mc
WHERE (mc.note IS NULL);

CREATE OR REPLACE TEMP VIEW ya_27c_rewriteYa0_base_mi AS
SELECT mi.*
FROM movie_info AS mi
WHERE (mi.info IN ('Sweden',
                  'Norway',
                  'Germany',
                  'Denmark',
                  'Swedish',
                  'Denish',
                  'Norwegian',
                  'German',
                  'English'));

CREATE OR REPLACE TEMP VIEW ya_27c_rewriteYa0_base_mk AS
SELECT mk.*
FROM movie_keyword AS mk;

CREATE OR REPLACE TEMP VIEW ya_27c_rewriteYa0_base_ml AS
SELECT ml.*
FROM movie_link AS ml;

CREATE OR REPLACE TEMP VIEW ya_27c_rewriteYa0_base_t AS
SELECT t.*
FROM title AS t
WHERE (t.production_year BETWEEN 1950 AND 2010);

CREATE OR REPLACE TEMP VIEW ya_27c_rewriteYa0_up_cct2 AS
SELECT cct2.*
FROM ya_27c_rewriteYa0_base_cct2 AS cct2;

CREATE OR REPLACE TEMP VIEW ya_27c_rewriteYa0_up_cn AS
SELECT cn.*
FROM ya_27c_rewriteYa0_base_cn AS cn;

CREATE OR REPLACE TEMP VIEW ya_27c_rewriteYa0_up_ct AS
SELECT ct.*
FROM ya_27c_rewriteYa0_base_ct AS ct;

CREATE OR REPLACE TEMP VIEW ya_27c_rewriteYa0_up_mc AS
SELECT mc.*
FROM ya_27c_rewriteYa0_base_mc AS mc
WHERE EXISTS (SELECT 1 FROM ya_27c_rewriteYa0_up_cn AS cn WHERE (mc.company_id = cn.id))
  AND EXISTS (SELECT 1 FROM ya_27c_rewriteYa0_up_ct AS ct WHERE (mc.company_type_id = ct.id));

CREATE OR REPLACE TEMP VIEW ya_27c_rewriteYa0_up_mi AS
SELECT mi.*
FROM ya_27c_rewriteYa0_base_mi AS mi;

CREATE OR REPLACE TEMP VIEW ya_27c_rewriteYa0_up_k AS
SELECT k.*
FROM ya_27c_rewriteYa0_base_k AS k;

CREATE OR REPLACE TEMP VIEW ya_27c_rewriteYa0_up_mk AS
SELECT mk.*
FROM ya_27c_rewriteYa0_base_mk AS mk
WHERE EXISTS (SELECT 1 FROM ya_27c_rewriteYa0_up_k AS k WHERE (mk.keyword_id = k.id));

CREATE OR REPLACE TEMP VIEW ya_27c_rewriteYa0_up_lt AS
SELECT lt.*
FROM ya_27c_rewriteYa0_base_lt AS lt;

CREATE OR REPLACE TEMP VIEW ya_27c_rewriteYa0_up_ml AS
SELECT ml.*
FROM ya_27c_rewriteYa0_base_ml AS ml
WHERE EXISTS (SELECT 1 FROM ya_27c_rewriteYa0_up_lt AS lt WHERE (lt.id = ml.link_type_id));

CREATE OR REPLACE TEMP VIEW ya_27c_rewriteYa0_up_t AS
SELECT t.*
FROM ya_27c_rewriteYa0_base_t AS t;

CREATE OR REPLACE TEMP VIEW ya_27c_rewriteYa0_up_cct1 AS
SELECT cct1.*
FROM ya_27c_rewriteYa0_base_cct1 AS cct1;

CREATE OR REPLACE TEMP VIEW ya_27c_rewriteYa0_up_cc AS
SELECT cc.*
FROM ya_27c_rewriteYa0_base_cc AS cc
WHERE EXISTS (SELECT 1 FROM ya_27c_rewriteYa0_up_cct2 AS cct2 WHERE (cct2.id = cc.status_id))
  AND EXISTS (SELECT 1 FROM ya_27c_rewriteYa0_up_mc AS mc WHERE (mc.movie_id = cc.movie_id))
  AND EXISTS (SELECT 1 FROM ya_27c_rewriteYa0_up_mi AS mi WHERE (mi.movie_id = cc.movie_id))
  AND EXISTS (SELECT 1 FROM ya_27c_rewriteYa0_up_mk AS mk WHERE (mk.movie_id = cc.movie_id))
  AND EXISTS (SELECT 1 FROM ya_27c_rewriteYa0_up_ml AS ml WHERE (ml.movie_id = cc.movie_id))
  AND EXISTS (SELECT 1 FROM ya_27c_rewriteYa0_up_t AS t WHERE (t.id = cc.movie_id))
  AND EXISTS (SELECT 1 FROM ya_27c_rewriteYa0_up_cct1 AS cct1 WHERE (cct1.id = cc.subject_id));

CREATE OR REPLACE TEMP VIEW ya_27c_rewriteYa0_down_cc AS
SELECT cc.*
FROM ya_27c_rewriteYa0_up_cc AS cc;

CREATE OR REPLACE TEMP VIEW ya_27c_rewriteYa0_down_cct2 AS
SELECT cct2.*
FROM ya_27c_rewriteYa0_up_cct2 AS cct2
WHERE EXISTS (SELECT 1 FROM ya_27c_rewriteYa0_down_cc AS cc WHERE (cct2.id = cc.status_id));

CREATE OR REPLACE TEMP VIEW ya_27c_rewriteYa0_down_mc AS
SELECT mc.*
FROM ya_27c_rewriteYa0_up_mc AS mc
WHERE EXISTS (SELECT 1 FROM ya_27c_rewriteYa0_down_cc AS cc WHERE (mc.movie_id = cc.movie_id));

CREATE OR REPLACE TEMP VIEW ya_27c_rewriteYa0_down_mi AS
SELECT mi.*
FROM ya_27c_rewriteYa0_up_mi AS mi
WHERE EXISTS (SELECT 1 FROM ya_27c_rewriteYa0_down_cc AS cc WHERE (mi.movie_id = cc.movie_id));

CREATE OR REPLACE TEMP VIEW ya_27c_rewriteYa0_down_mk AS
SELECT mk.*
FROM ya_27c_rewriteYa0_up_mk AS mk
WHERE EXISTS (SELECT 1 FROM ya_27c_rewriteYa0_down_cc AS cc WHERE (mk.movie_id = cc.movie_id));

CREATE OR REPLACE TEMP VIEW ya_27c_rewriteYa0_down_ml AS
SELECT ml.*
FROM ya_27c_rewriteYa0_up_ml AS ml
WHERE EXISTS (SELECT 1 FROM ya_27c_rewriteYa0_down_cc AS cc WHERE (ml.movie_id = cc.movie_id));

CREATE OR REPLACE TEMP VIEW ya_27c_rewriteYa0_down_t AS
SELECT t.*
FROM ya_27c_rewriteYa0_up_t AS t
WHERE EXISTS (SELECT 1 FROM ya_27c_rewriteYa0_down_cc AS cc WHERE (t.id = cc.movie_id));

CREATE OR REPLACE TEMP VIEW ya_27c_rewriteYa0_down_cct1 AS
SELECT cct1.*
FROM ya_27c_rewriteYa0_up_cct1 AS cct1
WHERE EXISTS (SELECT 1 FROM ya_27c_rewriteYa0_down_cc AS cc WHERE (cct1.id = cc.subject_id));

CREATE OR REPLACE TEMP VIEW ya_27c_rewriteYa0_down_cn AS
SELECT cn.*
FROM ya_27c_rewriteYa0_up_cn AS cn
WHERE EXISTS (SELECT 1 FROM ya_27c_rewriteYa0_down_mc AS mc WHERE (mc.company_id = cn.id));

CREATE OR REPLACE TEMP VIEW ya_27c_rewriteYa0_down_ct AS
SELECT ct.*
FROM ya_27c_rewriteYa0_up_ct AS ct
WHERE EXISTS (SELECT 1 FROM ya_27c_rewriteYa0_down_mc AS mc WHERE (mc.company_type_id = ct.id));

CREATE OR REPLACE TEMP VIEW ya_27c_rewriteYa0_down_k AS
SELECT k.*
FROM ya_27c_rewriteYa0_up_k AS k
WHERE EXISTS (SELECT 1 FROM ya_27c_rewriteYa0_down_mk AS mk WHERE (mk.keyword_id = k.id));

CREATE OR REPLACE TEMP VIEW ya_27c_rewriteYa0_down_lt AS
SELECT lt.*
FROM ya_27c_rewriteYa0_up_lt AS lt
WHERE EXISTS (SELECT 1 FROM ya_27c_rewriteYa0_down_ml AS ml WHERE (lt.id = ml.link_type_id));

SELECT cn.name,
       lt.link,
       t.title,
       SUM(1) AS record_count
FROM ya_27c_rewriteYa0_down_cc AS cc,
     ya_27c_rewriteYa0_down_cct1 AS cct1,
     ya_27c_rewriteYa0_down_cct2 AS cct2,
     ya_27c_rewriteYa0_down_cn AS cn,
     ya_27c_rewriteYa0_down_ct AS ct,
     ya_27c_rewriteYa0_down_k AS k,
     ya_27c_rewriteYa0_down_lt AS lt,
     ya_27c_rewriteYa0_down_mc AS mc,
     ya_27c_rewriteYa0_down_mi AS mi,
     ya_27c_rewriteYa0_down_mk AS mk,
     ya_27c_rewriteYa0_down_ml AS ml,
     ya_27c_rewriteYa0_down_t AS t
WHERE (cct1.kind = 'cast')
  AND (cct2.kind LIKE 'complete%')
  AND (cn.country_code !='[pl]')
  AND ((cn.name LIKE '%Film%'
       OR cn.name LIKE '%Warner%'))
  AND (ct.kind ='production companies')
  AND (k.keyword ='sequel')
  AND (lt.link LIKE '%follow%')
  AND (mc.note IS NULL)
  AND (mi.info IN ('Sweden',
                  'Norway',
                  'Germany',
                  'Denmark',
                  'Swedish',
                  'Denish',
                  'Norwegian',
                  'German',
                  'English'))
  AND (t.production_year BETWEEN 1950 AND 2010)
  AND (lt.id = ml.link_type_id)
  AND (ml.movie_id = t.id)
  AND (t.id = mk.movie_id)
  AND (mk.keyword_id = k.id)
  AND (t.id = mc.movie_id)
  AND (mc.company_type_id = ct.id)
  AND (mc.company_id = cn.id)
  AND (mi.movie_id = t.id)
  AND (t.id = cc.movie_id)
  AND (cct1.id = cc.subject_id)
  AND (cct2.id = cc.status_id)
  AND (ml.movie_id = mk.movie_id)
  AND (ml.movie_id = mc.movie_id)
  AND (mk.movie_id = mc.movie_id)
  AND (ml.movie_id = mi.movie_id)
  AND (mk.movie_id = mi.movie_id)
  AND (mc.movie_id = mi.movie_id)
  AND (ml.movie_id = cc.movie_id)
  AND (mk.movie_id = cc.movie_id)
  AND (mc.movie_id = cc.movie_id)
  AND (mi.movie_id = cc.movie_id)
GROUP BY cn.name, lt.link, t.title;
