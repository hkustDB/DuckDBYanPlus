-- DuckDB SUM(1) Yannakakis-style two-pass reducer generated from job_agg/28b.sql.

-- Source variant: query/job_duckdb/28b/rewriteYa260.sql

CREATE OR REPLACE TEMP VIEW ya_28b_rewriteYa260_base_cc AS
SELECT cc.*
FROM complete_cast AS cc;

CREATE OR REPLACE TEMP VIEW ya_28b_rewriteYa260_base_cct1 AS
SELECT cct1.*
FROM comp_cast_type AS cct1
WHERE (cct1.kind = 'crew');

CREATE OR REPLACE TEMP VIEW ya_28b_rewriteYa260_base_cct2 AS
SELECT cct2.*
FROM comp_cast_type AS cct2
WHERE (cct2.kind != 'complete+verified');

CREATE OR REPLACE TEMP VIEW ya_28b_rewriteYa260_base_cn AS
SELECT cn.*
FROM company_name AS cn
WHERE (cn.country_code != '[us]');

CREATE OR REPLACE TEMP VIEW ya_28b_rewriteYa260_base_ct AS
SELECT ct.*
FROM company_type AS ct;

CREATE OR REPLACE TEMP VIEW ya_28b_rewriteYa260_base_it1 AS
SELECT it1.*
FROM info_type AS it1
WHERE (it1.info = 'countries');

CREATE OR REPLACE TEMP VIEW ya_28b_rewriteYa260_base_it2 AS
SELECT it2.*
FROM info_type AS it2
WHERE (it2.info = 'rating');

CREATE OR REPLACE TEMP VIEW ya_28b_rewriteYa260_base_k AS
SELECT k.*
FROM keyword AS k
WHERE (k.keyword IN ('murder',
                    'murder-in-title',
                    'blood',
                    'violence'));

CREATE OR REPLACE TEMP VIEW ya_28b_rewriteYa260_base_kt AS
SELECT kt.*
FROM kind_type AS kt
WHERE (kt.kind IN ('movie',
                  'episode'));

CREATE OR REPLACE TEMP VIEW ya_28b_rewriteYa260_base_mc AS
SELECT mc.*
FROM movie_companies AS mc
WHERE (mc.note NOT LIKE '%(USA)%')
  AND (mc.note LIKE '%(200%)%');

CREATE OR REPLACE TEMP VIEW ya_28b_rewriteYa260_base_mi AS
SELECT mi.*
FROM movie_info AS mi
WHERE (mi.info IN ('Sweden',
                  'Germany',
                  'Swedish',
                  'German'));

CREATE OR REPLACE TEMP VIEW ya_28b_rewriteYa260_base_mi_idx AS
SELECT mi_idx.*
FROM movie_info_idx AS mi_idx
WHERE (mi_idx.info > '6.5');

CREATE OR REPLACE TEMP VIEW ya_28b_rewriteYa260_base_mk AS
SELECT mk.*
FROM movie_keyword AS mk;

CREATE OR REPLACE TEMP VIEW ya_28b_rewriteYa260_base_t AS
SELECT t.*
FROM title AS t
WHERE (t.production_year > 2005);

CREATE OR REPLACE TEMP VIEW ya_28b_rewriteYa260_up_it2 AS
SELECT it2.*
FROM ya_28b_rewriteYa260_base_it2 AS it2;

CREATE OR REPLACE TEMP VIEW ya_28b_rewriteYa260_up_mi_idx AS
SELECT mi_idx.*
FROM ya_28b_rewriteYa260_base_mi_idx AS mi_idx
WHERE EXISTS (SELECT 1 FROM ya_28b_rewriteYa260_up_it2 AS it2 WHERE (it2.id = mi_idx.info_type_id));

CREATE OR REPLACE TEMP VIEW ya_28b_rewriteYa260_up_k AS
SELECT k.*
FROM ya_28b_rewriteYa260_base_k AS k;

CREATE OR REPLACE TEMP VIEW ya_28b_rewriteYa260_up_mk AS
SELECT mk.*
FROM ya_28b_rewriteYa260_base_mk AS mk
WHERE EXISTS (SELECT 1 FROM ya_28b_rewriteYa260_up_k AS k WHERE (k.id = mk.keyword_id));

CREATE OR REPLACE TEMP VIEW ya_28b_rewriteYa260_up_cct1 AS
SELECT cct1.*
FROM ya_28b_rewriteYa260_base_cct1 AS cct1;

CREATE OR REPLACE TEMP VIEW ya_28b_rewriteYa260_up_cct2 AS
SELECT cct2.*
FROM ya_28b_rewriteYa260_base_cct2 AS cct2;

CREATE OR REPLACE TEMP VIEW ya_28b_rewriteYa260_up_cc AS
SELECT cc.*
FROM ya_28b_rewriteYa260_base_cc AS cc
WHERE EXISTS (SELECT 1 FROM ya_28b_rewriteYa260_up_cct1 AS cct1 WHERE (cct1.id = cc.subject_id))
  AND EXISTS (SELECT 1 FROM ya_28b_rewriteYa260_up_cct2 AS cct2 WHERE (cct2.id = cc.status_id));

CREATE OR REPLACE TEMP VIEW ya_28b_rewriteYa260_up_cn AS
SELECT cn.*
FROM ya_28b_rewriteYa260_base_cn AS cn;

CREATE OR REPLACE TEMP VIEW ya_28b_rewriteYa260_up_ct AS
SELECT ct.*
FROM ya_28b_rewriteYa260_base_ct AS ct;

CREATE OR REPLACE TEMP VIEW ya_28b_rewriteYa260_up_mc AS
SELECT mc.*
FROM ya_28b_rewriteYa260_base_mc AS mc
WHERE EXISTS (SELECT 1 FROM ya_28b_rewriteYa260_up_cn AS cn WHERE (cn.id = mc.company_id))
  AND EXISTS (SELECT 1 FROM ya_28b_rewriteYa260_up_ct AS ct WHERE (ct.id = mc.company_type_id));

CREATE OR REPLACE TEMP VIEW ya_28b_rewriteYa260_up_it1 AS
SELECT it1.*
FROM ya_28b_rewriteYa260_base_it1 AS it1;

CREATE OR REPLACE TEMP VIEW ya_28b_rewriteYa260_up_mi AS
SELECT mi.*
FROM ya_28b_rewriteYa260_base_mi AS mi
WHERE EXISTS (SELECT 1 FROM ya_28b_rewriteYa260_up_it1 AS it1 WHERE (it1.id = mi.info_type_id));

CREATE OR REPLACE TEMP VIEW ya_28b_rewriteYa260_up_t AS
SELECT t.*
FROM ya_28b_rewriteYa260_base_t AS t
WHERE EXISTS (SELECT 1 FROM ya_28b_rewriteYa260_up_mi_idx AS mi_idx WHERE (t.id = mi_idx.movie_id))
  AND EXISTS (SELECT 1 FROM ya_28b_rewriteYa260_up_mk AS mk WHERE (t.id = mk.movie_id))
  AND EXISTS (SELECT 1 FROM ya_28b_rewriteYa260_up_cc AS cc WHERE (t.id = cc.movie_id))
  AND EXISTS (SELECT 1 FROM ya_28b_rewriteYa260_up_mc AS mc WHERE (t.id = mc.movie_id))
  AND EXISTS (SELECT 1 FROM ya_28b_rewriteYa260_up_mi AS mi WHERE (t.id = mi.movie_id));

CREATE OR REPLACE TEMP VIEW ya_28b_rewriteYa260_up_kt AS
SELECT kt.*
FROM ya_28b_rewriteYa260_base_kt AS kt
WHERE EXISTS (SELECT 1 FROM ya_28b_rewriteYa260_up_t AS t WHERE (kt.id = t.kind_id));

CREATE OR REPLACE TEMP VIEW ya_28b_rewriteYa260_down_kt AS
SELECT kt.*
FROM ya_28b_rewriteYa260_up_kt AS kt;

CREATE OR REPLACE TEMP VIEW ya_28b_rewriteYa260_down_t AS
SELECT t.*
FROM ya_28b_rewriteYa260_up_t AS t
WHERE EXISTS (SELECT 1 FROM ya_28b_rewriteYa260_down_kt AS kt WHERE (kt.id = t.kind_id));

CREATE OR REPLACE TEMP VIEW ya_28b_rewriteYa260_down_mi_idx AS
SELECT mi_idx.*
FROM ya_28b_rewriteYa260_up_mi_idx AS mi_idx
WHERE EXISTS (SELECT 1 FROM ya_28b_rewriteYa260_down_t AS t WHERE (t.id = mi_idx.movie_id));

CREATE OR REPLACE TEMP VIEW ya_28b_rewriteYa260_down_mk AS
SELECT mk.*
FROM ya_28b_rewriteYa260_up_mk AS mk
WHERE EXISTS (SELECT 1 FROM ya_28b_rewriteYa260_down_t AS t WHERE (t.id = mk.movie_id));

CREATE OR REPLACE TEMP VIEW ya_28b_rewriteYa260_down_cc AS
SELECT cc.*
FROM ya_28b_rewriteYa260_up_cc AS cc
WHERE EXISTS (SELECT 1 FROM ya_28b_rewriteYa260_down_t AS t WHERE (t.id = cc.movie_id));

CREATE OR REPLACE TEMP VIEW ya_28b_rewriteYa260_down_mc AS
SELECT mc.*
FROM ya_28b_rewriteYa260_up_mc AS mc
WHERE EXISTS (SELECT 1 FROM ya_28b_rewriteYa260_down_t AS t WHERE (t.id = mc.movie_id));

CREATE OR REPLACE TEMP VIEW ya_28b_rewriteYa260_down_mi AS
SELECT mi.*
FROM ya_28b_rewriteYa260_up_mi AS mi
WHERE EXISTS (SELECT 1 FROM ya_28b_rewriteYa260_down_t AS t WHERE (t.id = mi.movie_id));

CREATE OR REPLACE TEMP VIEW ya_28b_rewriteYa260_down_it2 AS
SELECT it2.*
FROM ya_28b_rewriteYa260_up_it2 AS it2
WHERE EXISTS (SELECT 1 FROM ya_28b_rewriteYa260_down_mi_idx AS mi_idx WHERE (it2.id = mi_idx.info_type_id));

CREATE OR REPLACE TEMP VIEW ya_28b_rewriteYa260_down_k AS
SELECT k.*
FROM ya_28b_rewriteYa260_up_k AS k
WHERE EXISTS (SELECT 1 FROM ya_28b_rewriteYa260_down_mk AS mk WHERE (k.id = mk.keyword_id));

CREATE OR REPLACE TEMP VIEW ya_28b_rewriteYa260_down_cct1 AS
SELECT cct1.*
FROM ya_28b_rewriteYa260_up_cct1 AS cct1
WHERE EXISTS (SELECT 1 FROM ya_28b_rewriteYa260_down_cc AS cc WHERE (cct1.id = cc.subject_id));

CREATE OR REPLACE TEMP VIEW ya_28b_rewriteYa260_down_cct2 AS
SELECT cct2.*
FROM ya_28b_rewriteYa260_up_cct2 AS cct2
WHERE EXISTS (SELECT 1 FROM ya_28b_rewriteYa260_down_cc AS cc WHERE (cct2.id = cc.status_id));

CREATE OR REPLACE TEMP VIEW ya_28b_rewriteYa260_down_cn AS
SELECT cn.*
FROM ya_28b_rewriteYa260_up_cn AS cn
WHERE EXISTS (SELECT 1 FROM ya_28b_rewriteYa260_down_mc AS mc WHERE (cn.id = mc.company_id));

CREATE OR REPLACE TEMP VIEW ya_28b_rewriteYa260_down_ct AS
SELECT ct.*
FROM ya_28b_rewriteYa260_up_ct AS ct
WHERE EXISTS (SELECT 1 FROM ya_28b_rewriteYa260_down_mc AS mc WHERE (ct.id = mc.company_type_id));

CREATE OR REPLACE TEMP VIEW ya_28b_rewriteYa260_down_it1 AS
SELECT it1.*
FROM ya_28b_rewriteYa260_up_it1 AS it1
WHERE EXISTS (SELECT 1 FROM ya_28b_rewriteYa260_down_mi AS mi WHERE (it1.id = mi.info_type_id));

SELECT cn.name,
       mi_idx.info,
       t.title,
       SUM(1) AS record_count
FROM ya_28b_rewriteYa260_down_cc AS cc,
     ya_28b_rewriteYa260_down_cct1 AS cct1,
     ya_28b_rewriteYa260_down_cct2 AS cct2,
     ya_28b_rewriteYa260_down_cn AS cn,
     ya_28b_rewriteYa260_down_ct AS ct,
     ya_28b_rewriteYa260_down_it1 AS it1,
     ya_28b_rewriteYa260_down_it2 AS it2,
     ya_28b_rewriteYa260_down_k AS k,
     ya_28b_rewriteYa260_down_kt AS kt,
     ya_28b_rewriteYa260_down_mc AS mc,
     ya_28b_rewriteYa260_down_mi AS mi,
     ya_28b_rewriteYa260_down_mi_idx AS mi_idx,
     ya_28b_rewriteYa260_down_mk AS mk,
     ya_28b_rewriteYa260_down_t AS t
WHERE (cct1.kind = 'crew')
  AND (cct2.kind != 'complete+verified')
  AND (cn.country_code != '[us]')
  AND (it1.info = 'countries')
  AND (it2.info = 'rating')
  AND (k.keyword IN ('murder',
                    'murder-in-title',
                    'blood',
                    'violence'))
  AND (kt.kind IN ('movie',
                  'episode'))
  AND (mc.note NOT LIKE '%(USA)%')
  AND (mc.note LIKE '%(200%)%')
  AND (mi.info IN ('Sweden',
                  'Germany',
                  'Swedish',
                  'German'))
  AND (mi_idx.info > '6.5')
  AND (t.production_year > 2005)
  AND (kt.id = t.kind_id)
  AND (t.id = mi.movie_id)
  AND (t.id = mk.movie_id)
  AND (t.id = mi_idx.movie_id)
  AND (t.id = mc.movie_id)
  AND (t.id = cc.movie_id)
  AND (mk.movie_id = mi.movie_id)
  AND (mk.movie_id = mi_idx.movie_id)
  AND (mk.movie_id = mc.movie_id)
  AND (mk.movie_id = cc.movie_id)
  AND (mi.movie_id = mi_idx.movie_id)
  AND (mi.movie_id = mc.movie_id)
  AND (mi.movie_id = cc.movie_id)
  AND (mc.movie_id = mi_idx.movie_id)
  AND (mc.movie_id = cc.movie_id)
  AND (mi_idx.movie_id = cc.movie_id)
  AND (k.id = mk.keyword_id)
  AND (it1.id = mi.info_type_id)
  AND (it2.id = mi_idx.info_type_id)
  AND (ct.id = mc.company_type_id)
  AND (cn.id = mc.company_id)
  AND (cct1.id = cc.subject_id)
  AND (cct2.id = cc.status_id)
GROUP BY cn.name, mi_idx.info, t.title;
