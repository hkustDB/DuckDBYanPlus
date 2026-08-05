-- DuckDB SUM(1) Yannakakis-style two-pass reducer generated from job_agg/12a.sql.

-- Source variant: query/job_duckdb/12a/rewriteYa42.sql

CREATE OR REPLACE TEMP VIEW ya_12a_rewriteYa42_base_cn AS
SELECT cn.*
FROM company_name AS cn
WHERE (cn.country_code = '[us]');

CREATE OR REPLACE TEMP VIEW ya_12a_rewriteYa42_base_ct AS
SELECT ct.*
FROM company_type AS ct
WHERE (ct.kind = 'production companies');

CREATE OR REPLACE TEMP VIEW ya_12a_rewriteYa42_base_it1 AS
SELECT it1.*
FROM info_type AS it1
WHERE (it1.info = 'genres');

CREATE OR REPLACE TEMP VIEW ya_12a_rewriteYa42_base_it2 AS
SELECT it2.*
FROM info_type AS it2
WHERE (it2.info = 'rating');

CREATE OR REPLACE TEMP VIEW ya_12a_rewriteYa42_base_mc AS
SELECT mc.*
FROM movie_companies AS mc;

CREATE OR REPLACE TEMP VIEW ya_12a_rewriteYa42_base_mi AS
SELECT mi.*
FROM movie_info AS mi
WHERE (mi.info IN ('Drama',
                  'Horror'));

CREATE OR REPLACE TEMP VIEW ya_12a_rewriteYa42_base_mi_idx AS
SELECT mi_idx.*
FROM movie_info_idx AS mi_idx
WHERE (mi_idx.info > '8.0');

CREATE OR REPLACE TEMP VIEW ya_12a_rewriteYa42_base_t AS
SELECT t.*
FROM title AS t
WHERE (t.production_year BETWEEN 2005 AND 2008);

CREATE OR REPLACE TEMP VIEW ya_12a_rewriteYa42_up_cn AS
SELECT cn.*
FROM ya_12a_rewriteYa42_base_cn AS cn;

CREATE OR REPLACE TEMP VIEW ya_12a_rewriteYa42_up_ct AS
SELECT ct.*
FROM ya_12a_rewriteYa42_base_ct AS ct;

CREATE OR REPLACE TEMP VIEW ya_12a_rewriteYa42_up_mc AS
SELECT mc.*
FROM ya_12a_rewriteYa42_base_mc AS mc
WHERE EXISTS (SELECT 1 FROM ya_12a_rewriteYa42_up_cn AS cn WHERE (cn.id = mc.company_id))
  AND EXISTS (SELECT 1 FROM ya_12a_rewriteYa42_up_ct AS ct WHERE (ct.id = mc.company_type_id));

CREATE OR REPLACE TEMP VIEW ya_12a_rewriteYa42_up_it2 AS
SELECT it2.*
FROM ya_12a_rewriteYa42_base_it2 AS it2;

CREATE OR REPLACE TEMP VIEW ya_12a_rewriteYa42_up_mi_idx AS
SELECT mi_idx.*
FROM ya_12a_rewriteYa42_base_mi_idx AS mi_idx
WHERE EXISTS (SELECT 1 FROM ya_12a_rewriteYa42_up_it2 AS it2 WHERE (mi_idx.info_type_id = it2.id));

CREATE OR REPLACE TEMP VIEW ya_12a_rewriteYa42_up_t AS
SELECT t.*
FROM ya_12a_rewriteYa42_base_t AS t;

CREATE OR REPLACE TEMP VIEW ya_12a_rewriteYa42_up_mi AS
SELECT mi.*
FROM ya_12a_rewriteYa42_base_mi AS mi
WHERE EXISTS (SELECT 1 FROM ya_12a_rewriteYa42_up_mc AS mc WHERE (mc.movie_id = mi.movie_id))
  AND EXISTS (SELECT 1 FROM ya_12a_rewriteYa42_up_mi_idx AS mi_idx WHERE (mi.movie_id = mi_idx.movie_id))
  AND EXISTS (SELECT 1 FROM ya_12a_rewriteYa42_up_t AS t WHERE (t.id = mi.movie_id));

CREATE OR REPLACE TEMP VIEW ya_12a_rewriteYa42_up_it1 AS
SELECT it1.*
FROM ya_12a_rewriteYa42_base_it1 AS it1
WHERE EXISTS (SELECT 1 FROM ya_12a_rewriteYa42_up_mi AS mi WHERE (mi.info_type_id = it1.id));

CREATE OR REPLACE TEMP VIEW ya_12a_rewriteYa42_down_it1 AS
SELECT it1.*
FROM ya_12a_rewriteYa42_up_it1 AS it1;

CREATE OR REPLACE TEMP VIEW ya_12a_rewriteYa42_down_mi AS
SELECT mi.*
FROM ya_12a_rewriteYa42_up_mi AS mi
WHERE EXISTS (SELECT 1 FROM ya_12a_rewriteYa42_down_it1 AS it1 WHERE (mi.info_type_id = it1.id));

CREATE OR REPLACE TEMP VIEW ya_12a_rewriteYa42_down_mc AS
SELECT mc.*
FROM ya_12a_rewriteYa42_up_mc AS mc
WHERE EXISTS (SELECT 1 FROM ya_12a_rewriteYa42_down_mi AS mi WHERE (mc.movie_id = mi.movie_id));

CREATE OR REPLACE TEMP VIEW ya_12a_rewriteYa42_down_mi_idx AS
SELECT mi_idx.*
FROM ya_12a_rewriteYa42_up_mi_idx AS mi_idx
WHERE EXISTS (SELECT 1 FROM ya_12a_rewriteYa42_down_mi AS mi WHERE (mi.movie_id = mi_idx.movie_id));

CREATE OR REPLACE TEMP VIEW ya_12a_rewriteYa42_down_t AS
SELECT t.*
FROM ya_12a_rewriteYa42_up_t AS t
WHERE EXISTS (SELECT 1 FROM ya_12a_rewriteYa42_down_mi AS mi WHERE (t.id = mi.movie_id));

CREATE OR REPLACE TEMP VIEW ya_12a_rewriteYa42_down_cn AS
SELECT cn.*
FROM ya_12a_rewriteYa42_up_cn AS cn
WHERE EXISTS (SELECT 1 FROM ya_12a_rewriteYa42_down_mc AS mc WHERE (cn.id = mc.company_id));

CREATE OR REPLACE TEMP VIEW ya_12a_rewriteYa42_down_ct AS
SELECT ct.*
FROM ya_12a_rewriteYa42_up_ct AS ct
WHERE EXISTS (SELECT 1 FROM ya_12a_rewriteYa42_down_mc AS mc WHERE (ct.id = mc.company_type_id));

CREATE OR REPLACE TEMP VIEW ya_12a_rewriteYa42_down_it2 AS
SELECT it2.*
FROM ya_12a_rewriteYa42_up_it2 AS it2
WHERE EXISTS (SELECT 1 FROM ya_12a_rewriteYa42_down_mi_idx AS mi_idx WHERE (mi_idx.info_type_id = it2.id));

SELECT cn.name,
       mi_idx.info,
       t.title,
       SUM(1) AS record_count
FROM ya_12a_rewriteYa42_down_cn AS cn,
     ya_12a_rewriteYa42_down_ct AS ct,
     ya_12a_rewriteYa42_down_it1 AS it1,
     ya_12a_rewriteYa42_down_it2 AS it2,
     ya_12a_rewriteYa42_down_mc AS mc,
     ya_12a_rewriteYa42_down_mi AS mi,
     ya_12a_rewriteYa42_down_mi_idx AS mi_idx,
     ya_12a_rewriteYa42_down_t AS t
WHERE (cn.country_code = '[us]')
  AND (ct.kind = 'production companies')
  AND (it1.info = 'genres')
  AND (it2.info = 'rating')
  AND (mi.info IN ('Drama',
                  'Horror'))
  AND (mi_idx.info > '8.0')
  AND (t.production_year BETWEEN 2005 AND 2008)
  AND (t.id = mi.movie_id)
  AND (t.id = mi_idx.movie_id)
  AND (mi.info_type_id = it1.id)
  AND (mi_idx.info_type_id = it2.id)
  AND (t.id = mc.movie_id)
  AND (ct.id = mc.company_type_id)
  AND (cn.id = mc.company_id)
  AND (mc.movie_id = mi.movie_id)
  AND (mc.movie_id = mi_idx.movie_id)
  AND (mi.movie_id = mi_idx.movie_id)
GROUP BY cn.name, mi_idx.info, t.title;
