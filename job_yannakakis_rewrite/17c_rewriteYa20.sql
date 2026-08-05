-- DuckDB SUM(1) Yannakakis-style two-pass reducer generated from job_agg/17c.sql.

-- Source variant: query/job_duckdb/17c/rewriteYa20.sql

CREATE OR REPLACE TEMP VIEW ya_17c_rewriteYa20_base_ci AS
SELECT ci.*
FROM cast_info AS ci;

CREATE OR REPLACE TEMP VIEW ya_17c_rewriteYa20_base_cn AS
SELECT cn.*
FROM company_name AS cn;

CREATE OR REPLACE TEMP VIEW ya_17c_rewriteYa20_base_k AS
SELECT k.*
FROM keyword AS k
WHERE (k.keyword ='character-name-in-title');

CREATE OR REPLACE TEMP VIEW ya_17c_rewriteYa20_base_mc AS
SELECT mc.*
FROM movie_companies AS mc;

CREATE OR REPLACE TEMP VIEW ya_17c_rewriteYa20_base_mk AS
SELECT mk.*
FROM movie_keyword AS mk;

CREATE OR REPLACE TEMP VIEW ya_17c_rewriteYa20_base_n AS
SELECT n.*
FROM name AS n
WHERE (n.name LIKE 'X%');

CREATE OR REPLACE TEMP VIEW ya_17c_rewriteYa20_base_t AS
SELECT t.*
FROM title AS t;

CREATE OR REPLACE TEMP VIEW ya_17c_rewriteYa20_up_n AS
SELECT n.*
FROM ya_17c_rewriteYa20_base_n AS n;

CREATE OR REPLACE TEMP VIEW ya_17c_rewriteYa20_up_ci AS
SELECT ci.*
FROM ya_17c_rewriteYa20_base_ci AS ci
WHERE EXISTS (SELECT 1 FROM ya_17c_rewriteYa20_up_n AS n WHERE (n.id = ci.person_id));

CREATE OR REPLACE TEMP VIEW ya_17c_rewriteYa20_up_cn AS
SELECT cn.*
FROM ya_17c_rewriteYa20_base_cn AS cn;

CREATE OR REPLACE TEMP VIEW ya_17c_rewriteYa20_up_mc AS
SELECT mc.*
FROM ya_17c_rewriteYa20_base_mc AS mc
WHERE EXISTS (SELECT 1 FROM ya_17c_rewriteYa20_up_cn AS cn WHERE (mc.company_id = cn.id));

CREATE OR REPLACE TEMP VIEW ya_17c_rewriteYa20_up_k AS
SELECT k.*
FROM ya_17c_rewriteYa20_base_k AS k;

CREATE OR REPLACE TEMP VIEW ya_17c_rewriteYa20_up_mk AS
SELECT mk.*
FROM ya_17c_rewriteYa20_base_mk AS mk
WHERE EXISTS (SELECT 1 FROM ya_17c_rewriteYa20_up_k AS k WHERE (mk.keyword_id = k.id));

CREATE OR REPLACE TEMP VIEW ya_17c_rewriteYa20_up_t AS
SELECT t.*
FROM ya_17c_rewriteYa20_base_t AS t
WHERE EXISTS (SELECT 1 FROM ya_17c_rewriteYa20_up_ci AS ci WHERE (ci.movie_id = t.id))
  AND EXISTS (SELECT 1 FROM ya_17c_rewriteYa20_up_mc AS mc WHERE (t.id = mc.movie_id))
  AND EXISTS (SELECT 1 FROM ya_17c_rewriteYa20_up_mk AS mk WHERE (t.id = mk.movie_id));

CREATE OR REPLACE TEMP VIEW ya_17c_rewriteYa20_down_t AS
SELECT t.*
FROM ya_17c_rewriteYa20_up_t AS t;

CREATE OR REPLACE TEMP VIEW ya_17c_rewriteYa20_down_ci AS
SELECT ci.*
FROM ya_17c_rewriteYa20_up_ci AS ci
WHERE EXISTS (SELECT 1 FROM ya_17c_rewriteYa20_down_t AS t WHERE (ci.movie_id = t.id));

CREATE OR REPLACE TEMP VIEW ya_17c_rewriteYa20_down_mc AS
SELECT mc.*
FROM ya_17c_rewriteYa20_up_mc AS mc
WHERE EXISTS (SELECT 1 FROM ya_17c_rewriteYa20_down_t AS t WHERE (t.id = mc.movie_id));

CREATE OR REPLACE TEMP VIEW ya_17c_rewriteYa20_down_mk AS
SELECT mk.*
FROM ya_17c_rewriteYa20_up_mk AS mk
WHERE EXISTS (SELECT 1 FROM ya_17c_rewriteYa20_down_t AS t WHERE (t.id = mk.movie_id));

CREATE OR REPLACE TEMP VIEW ya_17c_rewriteYa20_down_n AS
SELECT n.*
FROM ya_17c_rewriteYa20_up_n AS n
WHERE EXISTS (SELECT 1 FROM ya_17c_rewriteYa20_down_ci AS ci WHERE (n.id = ci.person_id));

CREATE OR REPLACE TEMP VIEW ya_17c_rewriteYa20_down_cn AS
SELECT cn.*
FROM ya_17c_rewriteYa20_up_cn AS cn
WHERE EXISTS (SELECT 1 FROM ya_17c_rewriteYa20_down_mc AS mc WHERE (mc.company_id = cn.id));

CREATE OR REPLACE TEMP VIEW ya_17c_rewriteYa20_down_k AS
SELECT k.*
FROM ya_17c_rewriteYa20_up_k AS k
WHERE EXISTS (SELECT 1 FROM ya_17c_rewriteYa20_down_mk AS mk WHERE (mk.keyword_id = k.id));

SELECT n.name,
       SUM(1) AS record_count
FROM ya_17c_rewriteYa20_down_ci AS ci,
     ya_17c_rewriteYa20_down_cn AS cn,
     ya_17c_rewriteYa20_down_k AS k,
     ya_17c_rewriteYa20_down_mc AS mc,
     ya_17c_rewriteYa20_down_mk AS mk,
     ya_17c_rewriteYa20_down_n AS n,
     ya_17c_rewriteYa20_down_t AS t
WHERE (k.keyword ='character-name-in-title')
  AND (n.name LIKE 'X%')
  AND (n.id = ci.person_id)
  AND (ci.movie_id = t.id)
  AND (t.id = mk.movie_id)
  AND (mk.keyword_id = k.id)
  AND (t.id = mc.movie_id)
  AND (mc.company_id = cn.id)
  AND (ci.movie_id = mc.movie_id)
  AND (ci.movie_id = mk.movie_id)
  AND (mc.movie_id = mk.movie_id)
GROUP BY n.name;
