-- DuckDB SUM(1) Yannakakis-style two-pass reducer generated from job_agg/5b.sql.

-- Source variant: query/job_duckdb/5b/rewriteYa0.sql

CREATE OR REPLACE TEMP VIEW ya_5b_rewriteYa0_base_ct AS
SELECT ct.*
FROM company_type AS ct
WHERE (ct.kind = 'production companies');

CREATE OR REPLACE TEMP VIEW ya_5b_rewriteYa0_base_it AS
SELECT it.*
FROM info_type AS it;

CREATE OR REPLACE TEMP VIEW ya_5b_rewriteYa0_base_mc AS
SELECT mc.*
FROM movie_companies AS mc
WHERE (mc.note LIKE '%(VHS)%')
  AND (mc.note LIKE '%(USA)%')
  AND (mc.note LIKE '%(1994)%');

CREATE OR REPLACE TEMP VIEW ya_5b_rewriteYa0_base_mi AS
SELECT mi.*
FROM movie_info AS mi
WHERE (mi.info IN ('USA',
                  'America'));

CREATE OR REPLACE TEMP VIEW ya_5b_rewriteYa0_base_t AS
SELECT t.*
FROM title AS t
WHERE (t.production_year > 2010);

CREATE OR REPLACE TEMP VIEW ya_5b_rewriteYa0_up_t AS
SELECT t.*
FROM ya_5b_rewriteYa0_base_t AS t;

CREATE OR REPLACE TEMP VIEW ya_5b_rewriteYa0_up_it AS
SELECT it.*
FROM ya_5b_rewriteYa0_base_it AS it;

CREATE OR REPLACE TEMP VIEW ya_5b_rewriteYa0_up_mi AS
SELECT mi.*
FROM ya_5b_rewriteYa0_base_mi AS mi
WHERE EXISTS (SELECT 1 FROM ya_5b_rewriteYa0_up_it AS it WHERE (it.id = mi.info_type_id));

CREATE OR REPLACE TEMP VIEW ya_5b_rewriteYa0_up_mc AS
SELECT mc.*
FROM ya_5b_rewriteYa0_base_mc AS mc
WHERE EXISTS (SELECT 1 FROM ya_5b_rewriteYa0_up_t AS t WHERE (t.id = mc.movie_id))
  AND EXISTS (SELECT 1 FROM ya_5b_rewriteYa0_up_mi AS mi WHERE (mc.movie_id = mi.movie_id));

CREATE OR REPLACE TEMP VIEW ya_5b_rewriteYa0_up_ct AS
SELECT ct.*
FROM ya_5b_rewriteYa0_base_ct AS ct
WHERE EXISTS (SELECT 1 FROM ya_5b_rewriteYa0_up_mc AS mc WHERE (ct.id = mc.company_type_id));

CREATE OR REPLACE TEMP VIEW ya_5b_rewriteYa0_down_ct AS
SELECT ct.*
FROM ya_5b_rewriteYa0_up_ct AS ct;

CREATE OR REPLACE TEMP VIEW ya_5b_rewriteYa0_down_mc AS
SELECT mc.*
FROM ya_5b_rewriteYa0_up_mc AS mc
WHERE EXISTS (SELECT 1 FROM ya_5b_rewriteYa0_down_ct AS ct WHERE (ct.id = mc.company_type_id));

CREATE OR REPLACE TEMP VIEW ya_5b_rewriteYa0_down_t AS
SELECT t.*
FROM ya_5b_rewriteYa0_up_t AS t
WHERE EXISTS (SELECT 1 FROM ya_5b_rewriteYa0_down_mc AS mc WHERE (t.id = mc.movie_id));

CREATE OR REPLACE TEMP VIEW ya_5b_rewriteYa0_down_mi AS
SELECT mi.*
FROM ya_5b_rewriteYa0_up_mi AS mi
WHERE EXISTS (SELECT 1 FROM ya_5b_rewriteYa0_down_mc AS mc WHERE (mc.movie_id = mi.movie_id));

CREATE OR REPLACE TEMP VIEW ya_5b_rewriteYa0_down_it AS
SELECT it.*
FROM ya_5b_rewriteYa0_up_it AS it
WHERE EXISTS (SELECT 1 FROM ya_5b_rewriteYa0_down_mi AS mi WHERE (it.id = mi.info_type_id));

SELECT t.title,
       SUM(1) AS record_count
FROM ya_5b_rewriteYa0_down_ct AS ct,
     ya_5b_rewriteYa0_down_it AS it,
     ya_5b_rewriteYa0_down_mc AS mc,
     ya_5b_rewriteYa0_down_mi AS mi,
     ya_5b_rewriteYa0_down_t AS t
WHERE (ct.kind = 'production companies')
  AND (mc.note LIKE '%(VHS)%')
  AND (mc.note LIKE '%(USA)%')
  AND (mc.note LIKE '%(1994)%')
  AND (mi.info IN ('USA',
                  'America'))
  AND (t.production_year > 2010)
  AND (t.id = mi.movie_id)
  AND (t.id = mc.movie_id)
  AND (mc.movie_id = mi.movie_id)
  AND (ct.id = mc.company_type_id)
  AND (it.id = mi.info_type_id)
GROUP BY t.title;
