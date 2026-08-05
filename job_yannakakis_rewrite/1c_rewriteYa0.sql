-- DuckDB SUM(1) Yannakakis-style two-pass reducer generated from job_agg/1c.sql.

-- Source variant: query/job_duckdb/1c/rewriteYa0.sql

CREATE OR REPLACE TEMP VIEW ya_1c_rewriteYa0_base_ct AS
SELECT ct.*
FROM company_type AS ct
WHERE (ct.kind = 'production companies');

CREATE OR REPLACE TEMP VIEW ya_1c_rewriteYa0_base_it AS
SELECT it.*
FROM info_type AS it
WHERE (it.info = 'top 250 rank');

CREATE OR REPLACE TEMP VIEW ya_1c_rewriteYa0_base_mc AS
SELECT mc.*
FROM movie_companies AS mc
WHERE (mc.note NOT LIKE '%(as Metro-Goldwyn-Mayer Pictures)%')
  AND ((mc.note LIKE '%(co-production)%'));

CREATE OR REPLACE TEMP VIEW ya_1c_rewriteYa0_base_mi_idx AS
SELECT mi_idx.*
FROM movie_info_idx AS mi_idx;

CREATE OR REPLACE TEMP VIEW ya_1c_rewriteYa0_base_t AS
SELECT t.*
FROM title AS t
WHERE (t.production_year >2010);

CREATE OR REPLACE TEMP VIEW ya_1c_rewriteYa0_up_t AS
SELECT t.*
FROM ya_1c_rewriteYa0_base_t AS t;

CREATE OR REPLACE TEMP VIEW ya_1c_rewriteYa0_up_it AS
SELECT it.*
FROM ya_1c_rewriteYa0_base_it AS it;

CREATE OR REPLACE TEMP VIEW ya_1c_rewriteYa0_up_mi_idx AS
SELECT mi_idx.*
FROM ya_1c_rewriteYa0_base_mi_idx AS mi_idx
WHERE EXISTS (SELECT 1 FROM ya_1c_rewriteYa0_up_it AS it WHERE (it.id = mi_idx.info_type_id));

CREATE OR REPLACE TEMP VIEW ya_1c_rewriteYa0_up_mc AS
SELECT mc.*
FROM ya_1c_rewriteYa0_base_mc AS mc
WHERE EXISTS (SELECT 1 FROM ya_1c_rewriteYa0_up_t AS t WHERE (t.id = mc.movie_id))
  AND EXISTS (SELECT 1 FROM ya_1c_rewriteYa0_up_mi_idx AS mi_idx WHERE (mc.movie_id = mi_idx.movie_id));

CREATE OR REPLACE TEMP VIEW ya_1c_rewriteYa0_up_ct AS
SELECT ct.*
FROM ya_1c_rewriteYa0_base_ct AS ct
WHERE EXISTS (SELECT 1 FROM ya_1c_rewriteYa0_up_mc AS mc WHERE (ct.id = mc.company_type_id));

CREATE OR REPLACE TEMP VIEW ya_1c_rewriteYa0_down_ct AS
SELECT ct.*
FROM ya_1c_rewriteYa0_up_ct AS ct;

CREATE OR REPLACE TEMP VIEW ya_1c_rewriteYa0_down_mc AS
SELECT mc.*
FROM ya_1c_rewriteYa0_up_mc AS mc
WHERE EXISTS (SELECT 1 FROM ya_1c_rewriteYa0_down_ct AS ct WHERE (ct.id = mc.company_type_id));

CREATE OR REPLACE TEMP VIEW ya_1c_rewriteYa0_down_t AS
SELECT t.*
FROM ya_1c_rewriteYa0_up_t AS t
WHERE EXISTS (SELECT 1 FROM ya_1c_rewriteYa0_down_mc AS mc WHERE (t.id = mc.movie_id));

CREATE OR REPLACE TEMP VIEW ya_1c_rewriteYa0_down_mi_idx AS
SELECT mi_idx.*
FROM ya_1c_rewriteYa0_up_mi_idx AS mi_idx
WHERE EXISTS (SELECT 1 FROM ya_1c_rewriteYa0_down_mc AS mc WHERE (mc.movie_id = mi_idx.movie_id));

CREATE OR REPLACE TEMP VIEW ya_1c_rewriteYa0_down_it AS
SELECT it.*
FROM ya_1c_rewriteYa0_up_it AS it
WHERE EXISTS (SELECT 1 FROM ya_1c_rewriteYa0_down_mi_idx AS mi_idx WHERE (it.id = mi_idx.info_type_id));

SELECT mc.note,
       t.title,
       t.production_year,
       SUM(1) AS record_count
FROM ya_1c_rewriteYa0_down_ct AS ct,
     ya_1c_rewriteYa0_down_it AS it,
     ya_1c_rewriteYa0_down_mc AS mc,
     ya_1c_rewriteYa0_down_mi_idx AS mi_idx,
     ya_1c_rewriteYa0_down_t AS t
WHERE (ct.kind = 'production companies')
  AND (it.info = 'top 250 rank')
  AND (mc.note NOT LIKE '%(as Metro-Goldwyn-Mayer Pictures)%')
  AND ((mc.note LIKE '%(co-production)%'))
  AND (t.production_year >2010)
  AND (ct.id = mc.company_type_id)
  AND (t.id = mc.movie_id)
  AND (t.id = mi_idx.movie_id)
  AND (mc.movie_id = mi_idx.movie_id)
  AND (it.id = mi_idx.info_type_id)
GROUP BY mc.note, t.title, t.production_year;
