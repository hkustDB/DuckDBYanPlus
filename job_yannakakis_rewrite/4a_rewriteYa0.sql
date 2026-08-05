-- DuckDB SUM(1) Yannakakis-style two-pass reducer generated from job_agg/4a.sql.

-- Source variant: query/job_duckdb/4a/rewriteYa0.sql

CREATE OR REPLACE TEMP VIEW ya_4a_rewriteYa0_base_it AS
SELECT it.*
FROM info_type AS it
WHERE (it.info ='rating');

CREATE OR REPLACE TEMP VIEW ya_4a_rewriteYa0_base_k AS
SELECT k.*
FROM keyword AS k
WHERE (k.keyword LIKE '%sequel%');

CREATE OR REPLACE TEMP VIEW ya_4a_rewriteYa0_base_mi_idx AS
SELECT mi_idx.*
FROM movie_info_idx AS mi_idx
WHERE (mi_idx.info > '5.0');

CREATE OR REPLACE TEMP VIEW ya_4a_rewriteYa0_base_mk AS
SELECT mk.*
FROM movie_keyword AS mk;

CREATE OR REPLACE TEMP VIEW ya_4a_rewriteYa0_base_t AS
SELECT t.*
FROM title AS t
WHERE (t.production_year > 2005);

CREATE OR REPLACE TEMP VIEW ya_4a_rewriteYa0_up_t AS
SELECT t.*
FROM ya_4a_rewriteYa0_base_t AS t;

CREATE OR REPLACE TEMP VIEW ya_4a_rewriteYa0_up_k AS
SELECT k.*
FROM ya_4a_rewriteYa0_base_k AS k;

CREATE OR REPLACE TEMP VIEW ya_4a_rewriteYa0_up_mk AS
SELECT mk.*
FROM ya_4a_rewriteYa0_base_mk AS mk
WHERE EXISTS (SELECT 1 FROM ya_4a_rewriteYa0_up_k AS k WHERE (k.id = mk.keyword_id));

CREATE OR REPLACE TEMP VIEW ya_4a_rewriteYa0_up_mi_idx AS
SELECT mi_idx.*
FROM ya_4a_rewriteYa0_base_mi_idx AS mi_idx
WHERE EXISTS (SELECT 1 FROM ya_4a_rewriteYa0_up_t AS t WHERE (t.id = mi_idx.movie_id))
  AND EXISTS (SELECT 1 FROM ya_4a_rewriteYa0_up_mk AS mk WHERE (mk.movie_id = mi_idx.movie_id));

CREATE OR REPLACE TEMP VIEW ya_4a_rewriteYa0_up_it AS
SELECT it.*
FROM ya_4a_rewriteYa0_base_it AS it
WHERE EXISTS (SELECT 1 FROM ya_4a_rewriteYa0_up_mi_idx AS mi_idx WHERE (it.id = mi_idx.info_type_id));

CREATE OR REPLACE TEMP VIEW ya_4a_rewriteYa0_down_it AS
SELECT it.*
FROM ya_4a_rewriteYa0_up_it AS it;

CREATE OR REPLACE TEMP VIEW ya_4a_rewriteYa0_down_mi_idx AS
SELECT mi_idx.*
FROM ya_4a_rewriteYa0_up_mi_idx AS mi_idx
WHERE EXISTS (SELECT 1 FROM ya_4a_rewriteYa0_down_it AS it WHERE (it.id = mi_idx.info_type_id));

CREATE OR REPLACE TEMP VIEW ya_4a_rewriteYa0_down_t AS
SELECT t.*
FROM ya_4a_rewriteYa0_up_t AS t
WHERE EXISTS (SELECT 1 FROM ya_4a_rewriteYa0_down_mi_idx AS mi_idx WHERE (t.id = mi_idx.movie_id));

CREATE OR REPLACE TEMP VIEW ya_4a_rewriteYa0_down_mk AS
SELECT mk.*
FROM ya_4a_rewriteYa0_up_mk AS mk
WHERE EXISTS (SELECT 1 FROM ya_4a_rewriteYa0_down_mi_idx AS mi_idx WHERE (mk.movie_id = mi_idx.movie_id));

CREATE OR REPLACE TEMP VIEW ya_4a_rewriteYa0_down_k AS
SELECT k.*
FROM ya_4a_rewriteYa0_up_k AS k
WHERE EXISTS (SELECT 1 FROM ya_4a_rewriteYa0_down_mk AS mk WHERE (k.id = mk.keyword_id));

SELECT mi_idx.info,
       t.title,
       SUM(1) AS record_count
FROM ya_4a_rewriteYa0_down_it AS it,
     ya_4a_rewriteYa0_down_k AS k,
     ya_4a_rewriteYa0_down_mi_idx AS mi_idx,
     ya_4a_rewriteYa0_down_mk AS mk,
     ya_4a_rewriteYa0_down_t AS t
WHERE (it.info ='rating')
  AND (k.keyword LIKE '%sequel%')
  AND (mi_idx.info > '5.0')
  AND (t.production_year > 2005)
  AND (t.id = mi_idx.movie_id)
  AND (t.id = mk.movie_id)
  AND (mk.movie_id = mi_idx.movie_id)
  AND (k.id = mk.keyword_id)
  AND (it.id = mi_idx.info_type_id)
GROUP BY mi_idx.info, t.title;
