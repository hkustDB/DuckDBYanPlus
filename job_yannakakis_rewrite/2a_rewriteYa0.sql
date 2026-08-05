-- DuckDB SUM(1) Yannakakis-style two-pass reducer generated from job_agg/2a.sql.

-- Source variant: query/job_duckdb/2a/rewriteYa0.sql

CREATE OR REPLACE TEMP VIEW ya_2a_rewriteYa0_base_cn AS
SELECT cn.*
FROM company_name AS cn
WHERE (cn.country_code ='[de]');

CREATE OR REPLACE TEMP VIEW ya_2a_rewriteYa0_base_k AS
SELECT k.*
FROM keyword AS k
WHERE (k.keyword ='character-name-in-title');

CREATE OR REPLACE TEMP VIEW ya_2a_rewriteYa0_base_mc AS
SELECT mc.*
FROM movie_companies AS mc;

CREATE OR REPLACE TEMP VIEW ya_2a_rewriteYa0_base_mk AS
SELECT mk.*
FROM movie_keyword AS mk;

CREATE OR REPLACE TEMP VIEW ya_2a_rewriteYa0_base_t AS
SELECT t.*
FROM title AS t;

CREATE OR REPLACE TEMP VIEW ya_2a_rewriteYa0_up_t AS
SELECT t.*
FROM ya_2a_rewriteYa0_base_t AS t;

CREATE OR REPLACE TEMP VIEW ya_2a_rewriteYa0_up_k AS
SELECT k.*
FROM ya_2a_rewriteYa0_base_k AS k;

CREATE OR REPLACE TEMP VIEW ya_2a_rewriteYa0_up_mk AS
SELECT mk.*
FROM ya_2a_rewriteYa0_base_mk AS mk
WHERE EXISTS (SELECT 1 FROM ya_2a_rewriteYa0_up_k AS k WHERE (mk.keyword_id = k.id));

CREATE OR REPLACE TEMP VIEW ya_2a_rewriteYa0_up_mc AS
SELECT mc.*
FROM ya_2a_rewriteYa0_base_mc AS mc
WHERE EXISTS (SELECT 1 FROM ya_2a_rewriteYa0_up_t AS t WHERE (mc.movie_id = t.id))
  AND EXISTS (SELECT 1 FROM ya_2a_rewriteYa0_up_mk AS mk WHERE (mc.movie_id = mk.movie_id));

CREATE OR REPLACE TEMP VIEW ya_2a_rewriteYa0_up_cn AS
SELECT cn.*
FROM ya_2a_rewriteYa0_base_cn AS cn
WHERE EXISTS (SELECT 1 FROM ya_2a_rewriteYa0_up_mc AS mc WHERE (cn.id = mc.company_id));

CREATE OR REPLACE TEMP VIEW ya_2a_rewriteYa0_down_cn AS
SELECT cn.*
FROM ya_2a_rewriteYa0_up_cn AS cn;

CREATE OR REPLACE TEMP VIEW ya_2a_rewriteYa0_down_mc AS
SELECT mc.*
FROM ya_2a_rewriteYa0_up_mc AS mc
WHERE EXISTS (SELECT 1 FROM ya_2a_rewriteYa0_down_cn AS cn WHERE (cn.id = mc.company_id));

CREATE OR REPLACE TEMP VIEW ya_2a_rewriteYa0_down_t AS
SELECT t.*
FROM ya_2a_rewriteYa0_up_t AS t
WHERE EXISTS (SELECT 1 FROM ya_2a_rewriteYa0_down_mc AS mc WHERE (mc.movie_id = t.id));

CREATE OR REPLACE TEMP VIEW ya_2a_rewriteYa0_down_mk AS
SELECT mk.*
FROM ya_2a_rewriteYa0_up_mk AS mk
WHERE EXISTS (SELECT 1 FROM ya_2a_rewriteYa0_down_mc AS mc WHERE (mc.movie_id = mk.movie_id));

CREATE OR REPLACE TEMP VIEW ya_2a_rewriteYa0_down_k AS
SELECT k.*
FROM ya_2a_rewriteYa0_up_k AS k
WHERE EXISTS (SELECT 1 FROM ya_2a_rewriteYa0_down_mk AS mk WHERE (mk.keyword_id = k.id));

SELECT t.title,
       SUM(1) AS record_count
FROM ya_2a_rewriteYa0_down_cn AS cn,
     ya_2a_rewriteYa0_down_k AS k,
     ya_2a_rewriteYa0_down_mc AS mc,
     ya_2a_rewriteYa0_down_mk AS mk,
     ya_2a_rewriteYa0_down_t AS t
WHERE (cn.country_code ='[de]')
  AND (k.keyword ='character-name-in-title')
  AND (cn.id = mc.company_id)
  AND (mc.movie_id = t.id)
  AND (t.id = mk.movie_id)
  AND (mk.keyword_id = k.id)
  AND (mc.movie_id = mk.movie_id)
GROUP BY t.title;
