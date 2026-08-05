-- DuckDB SUM(1) Yannakakis-style two-pass reducer generated from job_agg/15b.sql.

-- Source variant: query/job_duckdb/15b/rewriteYa87.sql

CREATE OR REPLACE TEMP VIEW ya_15b_rewriteYa87_base_akt AS
SELECT akt.*
FROM aka_title AS akt;

CREATE OR REPLACE TEMP VIEW ya_15b_rewriteYa87_base_cn AS
SELECT cn.*
FROM company_name AS cn
WHERE (cn.country_code = '[us]')
  AND (cn.name = 'YouTube');

CREATE OR REPLACE TEMP VIEW ya_15b_rewriteYa87_base_ct AS
SELECT ct.*
FROM company_type AS ct;

CREATE OR REPLACE TEMP VIEW ya_15b_rewriteYa87_base_it1 AS
SELECT it1.*
FROM info_type AS it1
WHERE (it1.info = 'release dates');

CREATE OR REPLACE TEMP VIEW ya_15b_rewriteYa87_base_k AS
SELECT k.*
FROM keyword AS k;

CREATE OR REPLACE TEMP VIEW ya_15b_rewriteYa87_base_mc AS
SELECT mc.*
FROM movie_companies AS mc
WHERE (mc.note LIKE '%(200%)%')
  AND (mc.note LIKE '%(worldwide)%');

CREATE OR REPLACE TEMP VIEW ya_15b_rewriteYa87_base_mi AS
SELECT mi.*
FROM movie_info AS mi
WHERE (mi.note LIKE '%internet%')
  AND (mi.info LIKE 'USA:% 200%');

CREATE OR REPLACE TEMP VIEW ya_15b_rewriteYa87_base_mk AS
SELECT mk.*
FROM movie_keyword AS mk;

CREATE OR REPLACE TEMP VIEW ya_15b_rewriteYa87_base_t AS
SELECT t.*
FROM title AS t
WHERE (t.production_year BETWEEN 2005 AND 2010);

CREATE OR REPLACE TEMP VIEW ya_15b_rewriteYa87_up_k AS
SELECT k.*
FROM ya_15b_rewriteYa87_base_k AS k;

CREATE OR REPLACE TEMP VIEW ya_15b_rewriteYa87_up_mk AS
SELECT mk.*
FROM ya_15b_rewriteYa87_base_mk AS mk
WHERE EXISTS (SELECT 1 FROM ya_15b_rewriteYa87_up_k AS k WHERE (k.id = mk.keyword_id));

CREATE OR REPLACE TEMP VIEW ya_15b_rewriteYa87_up_t AS
SELECT t.*
FROM ya_15b_rewriteYa87_base_t AS t;

CREATE OR REPLACE TEMP VIEW ya_15b_rewriteYa87_up_akt AS
SELECT akt.*
FROM ya_15b_rewriteYa87_base_akt AS akt;

CREATE OR REPLACE TEMP VIEW ya_15b_rewriteYa87_up_it1 AS
SELECT it1.*
FROM ya_15b_rewriteYa87_base_it1 AS it1;

CREATE OR REPLACE TEMP VIEW ya_15b_rewriteYa87_up_cn AS
SELECT cn.*
FROM ya_15b_rewriteYa87_base_cn AS cn;

CREATE OR REPLACE TEMP VIEW ya_15b_rewriteYa87_up_ct AS
SELECT ct.*
FROM ya_15b_rewriteYa87_base_ct AS ct;

CREATE OR REPLACE TEMP VIEW ya_15b_rewriteYa87_up_mc AS
SELECT mc.*
FROM ya_15b_rewriteYa87_base_mc AS mc
WHERE EXISTS (SELECT 1 FROM ya_15b_rewriteYa87_up_cn AS cn WHERE (cn.id = mc.company_id))
  AND EXISTS (SELECT 1 FROM ya_15b_rewriteYa87_up_ct AS ct WHERE (ct.id = mc.company_type_id));

CREATE OR REPLACE TEMP VIEW ya_15b_rewriteYa87_up_mi AS
SELECT mi.*
FROM ya_15b_rewriteYa87_base_mi AS mi
WHERE EXISTS (SELECT 1 FROM ya_15b_rewriteYa87_up_mk AS mk WHERE (mk.movie_id = mi.movie_id))
  AND EXISTS (SELECT 1 FROM ya_15b_rewriteYa87_up_t AS t WHERE (t.id = mi.movie_id))
  AND EXISTS (SELECT 1 FROM ya_15b_rewriteYa87_up_akt AS akt WHERE (mi.movie_id = akt.movie_id))
  AND EXISTS (SELECT 1 FROM ya_15b_rewriteYa87_up_it1 AS it1 WHERE (it1.id = mi.info_type_id))
  AND EXISTS (SELECT 1 FROM ya_15b_rewriteYa87_up_mc AS mc WHERE (mi.movie_id = mc.movie_id));

CREATE OR REPLACE TEMP VIEW ya_15b_rewriteYa87_down_mi AS
SELECT mi.*
FROM ya_15b_rewriteYa87_up_mi AS mi;

CREATE OR REPLACE TEMP VIEW ya_15b_rewriteYa87_down_mk AS
SELECT mk.*
FROM ya_15b_rewriteYa87_up_mk AS mk
WHERE EXISTS (SELECT 1 FROM ya_15b_rewriteYa87_down_mi AS mi WHERE (mk.movie_id = mi.movie_id));

CREATE OR REPLACE TEMP VIEW ya_15b_rewriteYa87_down_t AS
SELECT t.*
FROM ya_15b_rewriteYa87_up_t AS t
WHERE EXISTS (SELECT 1 FROM ya_15b_rewriteYa87_down_mi AS mi WHERE (t.id = mi.movie_id));

CREATE OR REPLACE TEMP VIEW ya_15b_rewriteYa87_down_akt AS
SELECT akt.*
FROM ya_15b_rewriteYa87_up_akt AS akt
WHERE EXISTS (SELECT 1 FROM ya_15b_rewriteYa87_down_mi AS mi WHERE (mi.movie_id = akt.movie_id));

CREATE OR REPLACE TEMP VIEW ya_15b_rewriteYa87_down_it1 AS
SELECT it1.*
FROM ya_15b_rewriteYa87_up_it1 AS it1
WHERE EXISTS (SELECT 1 FROM ya_15b_rewriteYa87_down_mi AS mi WHERE (it1.id = mi.info_type_id));

CREATE OR REPLACE TEMP VIEW ya_15b_rewriteYa87_down_mc AS
SELECT mc.*
FROM ya_15b_rewriteYa87_up_mc AS mc
WHERE EXISTS (SELECT 1 FROM ya_15b_rewriteYa87_down_mi AS mi WHERE (mi.movie_id = mc.movie_id));

CREATE OR REPLACE TEMP VIEW ya_15b_rewriteYa87_down_k AS
SELECT k.*
FROM ya_15b_rewriteYa87_up_k AS k
WHERE EXISTS (SELECT 1 FROM ya_15b_rewriteYa87_down_mk AS mk WHERE (k.id = mk.keyword_id));

CREATE OR REPLACE TEMP VIEW ya_15b_rewriteYa87_down_cn AS
SELECT cn.*
FROM ya_15b_rewriteYa87_up_cn AS cn
WHERE EXISTS (SELECT 1 FROM ya_15b_rewriteYa87_down_mc AS mc WHERE (cn.id = mc.company_id));

CREATE OR REPLACE TEMP VIEW ya_15b_rewriteYa87_down_ct AS
SELECT ct.*
FROM ya_15b_rewriteYa87_up_ct AS ct
WHERE EXISTS (SELECT 1 FROM ya_15b_rewriteYa87_down_mc AS mc WHERE (ct.id = mc.company_type_id));

SELECT mi.info,
       t.title,
       SUM(1) AS record_count
FROM ya_15b_rewriteYa87_down_akt AS akt,
     ya_15b_rewriteYa87_down_cn AS cn,
     ya_15b_rewriteYa87_down_ct AS ct,
     ya_15b_rewriteYa87_down_it1 AS it1,
     ya_15b_rewriteYa87_down_k AS k,
     ya_15b_rewriteYa87_down_mc AS mc,
     ya_15b_rewriteYa87_down_mi AS mi,
     ya_15b_rewriteYa87_down_mk AS mk,
     ya_15b_rewriteYa87_down_t AS t
WHERE (cn.country_code = '[us]')
  AND (cn.name = 'YouTube')
  AND (it1.info = 'release dates')
  AND (mc.note LIKE '%(200%)%')
  AND (mc.note LIKE '%(worldwide)%')
  AND (mi.note LIKE '%internet%')
  AND (mi.info LIKE 'USA:% 200%')
  AND (t.production_year BETWEEN 2005 AND 2010)
  AND (t.id = akt.movie_id)
  AND (t.id = mi.movie_id)
  AND (t.id = mk.movie_id)
  AND (t.id = mc.movie_id)
  AND (mk.movie_id = mi.movie_id)
  AND (mk.movie_id = mc.movie_id)
  AND (mk.movie_id = akt.movie_id)
  AND (mi.movie_id = mc.movie_id)
  AND (mi.movie_id = akt.movie_id)
  AND (mc.movie_id = akt.movie_id)
  AND (k.id = mk.keyword_id)
  AND (it1.id = mi.info_type_id)
  AND (cn.id = mc.company_id)
  AND (ct.id = mc.company_type_id)
GROUP BY mi.info, t.title;
