-- DuckDB SUM(1) Yannakakis-style two-pass reducer generated from job_agg/6e.sql.

-- Source variant: query/job_duckdb/6e/rewriteYa11.sql

CREATE OR REPLACE TEMP VIEW ya_6e_rewriteYa11_base_ci AS
SELECT ci.*
FROM cast_info AS ci;

CREATE OR REPLACE TEMP VIEW ya_6e_rewriteYa11_base_k AS
SELECT k.*
FROM keyword AS k
WHERE (k.keyword = 'marvel-cinematic-universe');

CREATE OR REPLACE TEMP VIEW ya_6e_rewriteYa11_base_mk AS
SELECT mk.*
FROM movie_keyword AS mk;

CREATE OR REPLACE TEMP VIEW ya_6e_rewriteYa11_base_n AS
SELECT n.*
FROM name AS n
WHERE (n.name LIKE '%Downey%Robert%');

CREATE OR REPLACE TEMP VIEW ya_6e_rewriteYa11_base_t AS
SELECT t.*
FROM title AS t
WHERE (t.production_year > 2000);

CREATE OR REPLACE TEMP VIEW ya_6e_rewriteYa11_up_t AS
SELECT t.*
FROM ya_6e_rewriteYa11_base_t AS t;

CREATE OR REPLACE TEMP VIEW ya_6e_rewriteYa11_up_n AS
SELECT n.*
FROM ya_6e_rewriteYa11_base_n AS n;

CREATE OR REPLACE TEMP VIEW ya_6e_rewriteYa11_up_ci AS
SELECT ci.*
FROM ya_6e_rewriteYa11_base_ci AS ci
WHERE EXISTS (SELECT 1 FROM ya_6e_rewriteYa11_up_n AS n WHERE (n.id = ci.person_id));

CREATE OR REPLACE TEMP VIEW ya_6e_rewriteYa11_up_mk AS
SELECT mk.*
FROM ya_6e_rewriteYa11_base_mk AS mk
WHERE EXISTS (SELECT 1 FROM ya_6e_rewriteYa11_up_t AS t WHERE (t.id = mk.movie_id))
  AND EXISTS (SELECT 1 FROM ya_6e_rewriteYa11_up_ci AS ci WHERE (ci.movie_id = mk.movie_id));

CREATE OR REPLACE TEMP VIEW ya_6e_rewriteYa11_up_k AS
SELECT k.*
FROM ya_6e_rewriteYa11_base_k AS k
WHERE EXISTS (SELECT 1 FROM ya_6e_rewriteYa11_up_mk AS mk WHERE (k.id = mk.keyword_id));

CREATE OR REPLACE TEMP VIEW ya_6e_rewriteYa11_down_k AS
SELECT k.*
FROM ya_6e_rewriteYa11_up_k AS k;

CREATE OR REPLACE TEMP VIEW ya_6e_rewriteYa11_down_mk AS
SELECT mk.*
FROM ya_6e_rewriteYa11_up_mk AS mk
WHERE EXISTS (SELECT 1 FROM ya_6e_rewriteYa11_down_k AS k WHERE (k.id = mk.keyword_id));

CREATE OR REPLACE TEMP VIEW ya_6e_rewriteYa11_down_t AS
SELECT t.*
FROM ya_6e_rewriteYa11_up_t AS t
WHERE EXISTS (SELECT 1 FROM ya_6e_rewriteYa11_down_mk AS mk WHERE (t.id = mk.movie_id));

CREATE OR REPLACE TEMP VIEW ya_6e_rewriteYa11_down_ci AS
SELECT ci.*
FROM ya_6e_rewriteYa11_up_ci AS ci
WHERE EXISTS (SELECT 1 FROM ya_6e_rewriteYa11_down_mk AS mk WHERE (ci.movie_id = mk.movie_id));

CREATE OR REPLACE TEMP VIEW ya_6e_rewriteYa11_down_n AS
SELECT n.*
FROM ya_6e_rewriteYa11_up_n AS n
WHERE EXISTS (SELECT 1 FROM ya_6e_rewriteYa11_down_ci AS ci WHERE (n.id = ci.person_id));

SELECT k.keyword,
       n.name,
       t.title,
       SUM(1) AS record_count
FROM ya_6e_rewriteYa11_down_ci AS ci,
     ya_6e_rewriteYa11_down_k AS k,
     ya_6e_rewriteYa11_down_mk AS mk,
     ya_6e_rewriteYa11_down_n AS n,
     ya_6e_rewriteYa11_down_t AS t
WHERE (k.keyword = 'marvel-cinematic-universe')
  AND (n.name LIKE '%Downey%Robert%')
  AND (t.production_year > 2000)
  AND (k.id = mk.keyword_id)
  AND (t.id = mk.movie_id)
  AND (t.id = ci.movie_id)
  AND (ci.movie_id = mk.movie_id)
  AND (n.id = ci.person_id)
GROUP BY k.keyword, n.name, t.title;
