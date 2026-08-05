-- DuckDB SUM(1) Yannakakis-style two-pass reducer generated from job_agg/3c.sql.

-- Source variant: query/job_duckdb/3c/rewriteYa5.sql

CREATE OR REPLACE TEMP VIEW ya_3c_rewriteYa5_base_k AS
SELECT k.*
FROM keyword AS k
WHERE (k.keyword LIKE '%sequel%');

CREATE OR REPLACE TEMP VIEW ya_3c_rewriteYa5_base_mi AS
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
                  'USA',
                  'American'));

CREATE OR REPLACE TEMP VIEW ya_3c_rewriteYa5_base_mk AS
SELECT mk.*
FROM movie_keyword AS mk;

CREATE OR REPLACE TEMP VIEW ya_3c_rewriteYa5_base_t AS
SELECT t.*
FROM title AS t
WHERE (t.production_year > 1990);

CREATE OR REPLACE TEMP VIEW ya_3c_rewriteYa5_up_k AS
SELECT k.*
FROM ya_3c_rewriteYa5_base_k AS k;

CREATE OR REPLACE TEMP VIEW ya_3c_rewriteYa5_up_mk AS
SELECT mk.*
FROM ya_3c_rewriteYa5_base_mk AS mk
WHERE EXISTS (SELECT 1 FROM ya_3c_rewriteYa5_up_k AS k WHERE (k.id = mk.keyword_id));

CREATE OR REPLACE TEMP VIEW ya_3c_rewriteYa5_up_t AS
SELECT t.*
FROM ya_3c_rewriteYa5_base_t AS t;

CREATE OR REPLACE TEMP VIEW ya_3c_rewriteYa5_up_mi AS
SELECT mi.*
FROM ya_3c_rewriteYa5_base_mi AS mi
WHERE EXISTS (SELECT 1 FROM ya_3c_rewriteYa5_up_mk AS mk WHERE (mk.movie_id = mi.movie_id))
  AND EXISTS (SELECT 1 FROM ya_3c_rewriteYa5_up_t AS t WHERE (t.id = mi.movie_id));

CREATE OR REPLACE TEMP VIEW ya_3c_rewriteYa5_down_mi AS
SELECT mi.*
FROM ya_3c_rewriteYa5_up_mi AS mi;

CREATE OR REPLACE TEMP VIEW ya_3c_rewriteYa5_down_mk AS
SELECT mk.*
FROM ya_3c_rewriteYa5_up_mk AS mk
WHERE EXISTS (SELECT 1 FROM ya_3c_rewriteYa5_down_mi AS mi WHERE (mk.movie_id = mi.movie_id));

CREATE OR REPLACE TEMP VIEW ya_3c_rewriteYa5_down_t AS
SELECT t.*
FROM ya_3c_rewriteYa5_up_t AS t
WHERE EXISTS (SELECT 1 FROM ya_3c_rewriteYa5_down_mi AS mi WHERE (t.id = mi.movie_id));

CREATE OR REPLACE TEMP VIEW ya_3c_rewriteYa5_down_k AS
SELECT k.*
FROM ya_3c_rewriteYa5_up_k AS k
WHERE EXISTS (SELECT 1 FROM ya_3c_rewriteYa5_down_mk AS mk WHERE (k.id = mk.keyword_id));

SELECT t.title,
       SUM(1) AS record_count
FROM ya_3c_rewriteYa5_down_k AS k,
     ya_3c_rewriteYa5_down_mi AS mi,
     ya_3c_rewriteYa5_down_mk AS mk,
     ya_3c_rewriteYa5_down_t AS t
WHERE (k.keyword LIKE '%sequel%')
  AND (mi.info IN ('Sweden',
                  'Norway',
                  'Germany',
                  'Denmark',
                  'Swedish',
                  'Denish',
                  'Norwegian',
                  'German',
                  'USA',
                  'American'))
  AND (t.production_year > 1990)
  AND (t.id = mi.movie_id)
  AND (t.id = mk.movie_id)
  AND (mk.movie_id = mi.movie_id)
  AND (k.id = mk.keyword_id)
GROUP BY t.title;
