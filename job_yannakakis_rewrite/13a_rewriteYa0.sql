-- DuckDB SUM(1) Yannakakis-style two-pass reducer generated from job_agg/13a.sql.

-- Source variant: query/job_duckdb/13a/rewriteYa0.sql

CREATE OR REPLACE TEMP VIEW ya_13a_rewriteYa0_base_cn AS
SELECT cn.*
FROM company_name AS cn
WHERE (cn.country_code ='[de]');

CREATE OR REPLACE TEMP VIEW ya_13a_rewriteYa0_base_ct AS
SELECT ct.*
FROM company_type AS ct
WHERE (ct.kind ='production companies');

CREATE OR REPLACE TEMP VIEW ya_13a_rewriteYa0_base_it AS
SELECT it.*
FROM info_type AS it
WHERE (it.info ='rating');

CREATE OR REPLACE TEMP VIEW ya_13a_rewriteYa0_base_it2 AS
SELECT it2.*
FROM info_type AS it2
WHERE (it2.info ='release dates');

CREATE OR REPLACE TEMP VIEW ya_13a_rewriteYa0_base_kt AS
SELECT kt.*
FROM kind_type AS kt
WHERE (kt.kind ='movie');

CREATE OR REPLACE TEMP VIEW ya_13a_rewriteYa0_base_mc AS
SELECT mc.*
FROM movie_companies AS mc;

CREATE OR REPLACE TEMP VIEW ya_13a_rewriteYa0_base_mi AS
SELECT mi.*
FROM movie_info AS mi;

CREATE OR REPLACE TEMP VIEW ya_13a_rewriteYa0_base_miidx AS
SELECT miidx.*
FROM movie_info_idx AS miidx;

CREATE OR REPLACE TEMP VIEW ya_13a_rewriteYa0_base_t AS
SELECT t.*
FROM title AS t;

CREATE OR REPLACE TEMP VIEW ya_13a_rewriteYa0_up_it2 AS
SELECT it2.*
FROM ya_13a_rewriteYa0_base_it2 AS it2;

CREATE OR REPLACE TEMP VIEW ya_13a_rewriteYa0_up_mi AS
SELECT mi.*
FROM ya_13a_rewriteYa0_base_mi AS mi
WHERE EXISTS (SELECT 1 FROM ya_13a_rewriteYa0_up_it2 AS it2 WHERE (it2.id = mi.info_type_id));

CREATE OR REPLACE TEMP VIEW ya_13a_rewriteYa0_up_it AS
SELECT it.*
FROM ya_13a_rewriteYa0_base_it AS it;

CREATE OR REPLACE TEMP VIEW ya_13a_rewriteYa0_up_miidx AS
SELECT miidx.*
FROM ya_13a_rewriteYa0_base_miidx AS miidx
WHERE EXISTS (SELECT 1 FROM ya_13a_rewriteYa0_up_it AS it WHERE (it.id = miidx.info_type_id));

CREATE OR REPLACE TEMP VIEW ya_13a_rewriteYa0_up_kt AS
SELECT kt.*
FROM ya_13a_rewriteYa0_base_kt AS kt;

CREATE OR REPLACE TEMP VIEW ya_13a_rewriteYa0_up_t AS
SELECT t.*
FROM ya_13a_rewriteYa0_base_t AS t
WHERE EXISTS (SELECT 1 FROM ya_13a_rewriteYa0_up_kt AS kt WHERE (kt.id = t.kind_id));

CREATE OR REPLACE TEMP VIEW ya_13a_rewriteYa0_up_ct AS
SELECT ct.*
FROM ya_13a_rewriteYa0_base_ct AS ct;

CREATE OR REPLACE TEMP VIEW ya_13a_rewriteYa0_up_mc AS
SELECT mc.*
FROM ya_13a_rewriteYa0_base_mc AS mc
WHERE EXISTS (SELECT 1 FROM ya_13a_rewriteYa0_up_mi AS mi WHERE (mi.movie_id = mc.movie_id))
  AND EXISTS (SELECT 1 FROM ya_13a_rewriteYa0_up_miidx AS miidx WHERE (miidx.movie_id = mc.movie_id))
  AND EXISTS (SELECT 1 FROM ya_13a_rewriteYa0_up_t AS t WHERE (mc.movie_id = t.id))
  AND EXISTS (SELECT 1 FROM ya_13a_rewriteYa0_up_ct AS ct WHERE (ct.id = mc.company_type_id));

CREATE OR REPLACE TEMP VIEW ya_13a_rewriteYa0_up_cn AS
SELECT cn.*
FROM ya_13a_rewriteYa0_base_cn AS cn
WHERE EXISTS (SELECT 1 FROM ya_13a_rewriteYa0_up_mc AS mc WHERE (cn.id = mc.company_id));

CREATE OR REPLACE TEMP VIEW ya_13a_rewriteYa0_down_cn AS
SELECT cn.*
FROM ya_13a_rewriteYa0_up_cn AS cn;

CREATE OR REPLACE TEMP VIEW ya_13a_rewriteYa0_down_mc AS
SELECT mc.*
FROM ya_13a_rewriteYa0_up_mc AS mc
WHERE EXISTS (SELECT 1 FROM ya_13a_rewriteYa0_down_cn AS cn WHERE (cn.id = mc.company_id));

CREATE OR REPLACE TEMP VIEW ya_13a_rewriteYa0_down_mi AS
SELECT mi.*
FROM ya_13a_rewriteYa0_up_mi AS mi
WHERE EXISTS (SELECT 1 FROM ya_13a_rewriteYa0_down_mc AS mc WHERE (mi.movie_id = mc.movie_id));

CREATE OR REPLACE TEMP VIEW ya_13a_rewriteYa0_down_miidx AS
SELECT miidx.*
FROM ya_13a_rewriteYa0_up_miidx AS miidx
WHERE EXISTS (SELECT 1 FROM ya_13a_rewriteYa0_down_mc AS mc WHERE (miidx.movie_id = mc.movie_id));

CREATE OR REPLACE TEMP VIEW ya_13a_rewriteYa0_down_t AS
SELECT t.*
FROM ya_13a_rewriteYa0_up_t AS t
WHERE EXISTS (SELECT 1 FROM ya_13a_rewriteYa0_down_mc AS mc WHERE (mc.movie_id = t.id));

CREATE OR REPLACE TEMP VIEW ya_13a_rewriteYa0_down_ct AS
SELECT ct.*
FROM ya_13a_rewriteYa0_up_ct AS ct
WHERE EXISTS (SELECT 1 FROM ya_13a_rewriteYa0_down_mc AS mc WHERE (ct.id = mc.company_type_id));

CREATE OR REPLACE TEMP VIEW ya_13a_rewriteYa0_down_it2 AS
SELECT it2.*
FROM ya_13a_rewriteYa0_up_it2 AS it2
WHERE EXISTS (SELECT 1 FROM ya_13a_rewriteYa0_down_mi AS mi WHERE (it2.id = mi.info_type_id));

CREATE OR REPLACE TEMP VIEW ya_13a_rewriteYa0_down_it AS
SELECT it.*
FROM ya_13a_rewriteYa0_up_it AS it
WHERE EXISTS (SELECT 1 FROM ya_13a_rewriteYa0_down_miidx AS miidx WHERE (it.id = miidx.info_type_id));

CREATE OR REPLACE TEMP VIEW ya_13a_rewriteYa0_down_kt AS
SELECT kt.*
FROM ya_13a_rewriteYa0_up_kt AS kt
WHERE EXISTS (SELECT 1 FROM ya_13a_rewriteYa0_down_t AS t WHERE (kt.id = t.kind_id));

SELECT mi.info,
       miidx.info,
       t.title,
       SUM(1) AS record_count
FROM ya_13a_rewriteYa0_down_cn AS cn,
     ya_13a_rewriteYa0_down_ct AS ct,
     ya_13a_rewriteYa0_down_it AS it,
     ya_13a_rewriteYa0_down_it2 AS it2,
     ya_13a_rewriteYa0_down_kt AS kt,
     ya_13a_rewriteYa0_down_mc AS mc,
     ya_13a_rewriteYa0_down_mi AS mi,
     ya_13a_rewriteYa0_down_miidx AS miidx,
     ya_13a_rewriteYa0_down_t AS t
WHERE (cn.country_code ='[de]')
  AND (ct.kind ='production companies')
  AND (it.info ='rating')
  AND (it2.info ='release dates')
  AND (kt.kind ='movie')
  AND (mi.movie_id = t.id)
  AND (it2.id = mi.info_type_id)
  AND (kt.id = t.kind_id)
  AND (mc.movie_id = t.id)
  AND (cn.id = mc.company_id)
  AND (ct.id = mc.company_type_id)
  AND (miidx.movie_id = t.id)
  AND (it.id = miidx.info_type_id)
  AND (mi.movie_id = miidx.movie_id)
  AND (mi.movie_id = mc.movie_id)
  AND (miidx.movie_id = mc.movie_id)
GROUP BY mi.info, miidx.info, t.title;
