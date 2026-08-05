-- DuckDB SUM(1) Yannakakis-style two-pass reducer generated from job_agg/32b.sql.

-- Source variant: query/job_duckdb/32b/rewriteYa4.sql

CREATE OR REPLACE TEMP VIEW ya_32b_rewriteYa4_base_k AS
SELECT k.*
FROM keyword AS k
WHERE (k.keyword ='character-name-in-title');

CREATE OR REPLACE TEMP VIEW ya_32b_rewriteYa4_base_lt AS
SELECT lt.*
FROM link_type AS lt;

CREATE OR REPLACE TEMP VIEW ya_32b_rewriteYa4_base_mk AS
SELECT mk.*
FROM movie_keyword AS mk;

CREATE OR REPLACE TEMP VIEW ya_32b_rewriteYa4_base_ml AS
SELECT ml.*
FROM movie_link AS ml;

CREATE OR REPLACE TEMP VIEW ya_32b_rewriteYa4_base_t1 AS
SELECT t1.*
FROM title AS t1;

CREATE OR REPLACE TEMP VIEW ya_32b_rewriteYa4_base_t2 AS
SELECT t2.*
FROM title AS t2;

CREATE OR REPLACE TEMP VIEW ya_32b_rewriteYa4_up_t2 AS
SELECT t2.*
FROM ya_32b_rewriteYa4_base_t2 AS t2;

CREATE OR REPLACE TEMP VIEW ya_32b_rewriteYa4_up_lt AS
SELECT lt.*
FROM ya_32b_rewriteYa4_base_lt AS lt;

CREATE OR REPLACE TEMP VIEW ya_32b_rewriteYa4_up_ml AS
SELECT ml.*
FROM ya_32b_rewriteYa4_base_ml AS ml
WHERE EXISTS (SELECT 1 FROM ya_32b_rewriteYa4_up_t2 AS t2 WHERE (ml.linked_movie_id = t2.id))
  AND EXISTS (SELECT 1 FROM ya_32b_rewriteYa4_up_lt AS lt WHERE (lt.id = ml.link_type_id));

CREATE OR REPLACE TEMP VIEW ya_32b_rewriteYa4_up_k AS
SELECT k.*
FROM ya_32b_rewriteYa4_base_k AS k;

CREATE OR REPLACE TEMP VIEW ya_32b_rewriteYa4_up_mk AS
SELECT mk.*
FROM ya_32b_rewriteYa4_base_mk AS mk
WHERE EXISTS (SELECT 1 FROM ya_32b_rewriteYa4_up_k AS k WHERE (mk.keyword_id = k.id));

CREATE OR REPLACE TEMP VIEW ya_32b_rewriteYa4_up_t1 AS
SELECT t1.*
FROM ya_32b_rewriteYa4_base_t1 AS t1
WHERE EXISTS (SELECT 1 FROM ya_32b_rewriteYa4_up_ml AS ml WHERE (ml.movie_id = t1.id))
  AND EXISTS (SELECT 1 FROM ya_32b_rewriteYa4_up_mk AS mk WHERE (t1.id = mk.movie_id) AND (mk.movie_id = t1.id));

CREATE OR REPLACE TEMP VIEW ya_32b_rewriteYa4_down_t1 AS
SELECT t1.*
FROM ya_32b_rewriteYa4_up_t1 AS t1;

CREATE OR REPLACE TEMP VIEW ya_32b_rewriteYa4_down_ml AS
SELECT ml.*
FROM ya_32b_rewriteYa4_up_ml AS ml
WHERE EXISTS (SELECT 1 FROM ya_32b_rewriteYa4_down_t1 AS t1 WHERE (ml.movie_id = t1.id));

CREATE OR REPLACE TEMP VIEW ya_32b_rewriteYa4_down_mk AS
SELECT mk.*
FROM ya_32b_rewriteYa4_up_mk AS mk
WHERE EXISTS (SELECT 1 FROM ya_32b_rewriteYa4_down_t1 AS t1 WHERE (t1.id = mk.movie_id) AND (mk.movie_id = t1.id));

CREATE OR REPLACE TEMP VIEW ya_32b_rewriteYa4_down_t2 AS
SELECT t2.*
FROM ya_32b_rewriteYa4_up_t2 AS t2
WHERE EXISTS (SELECT 1 FROM ya_32b_rewriteYa4_down_ml AS ml WHERE (ml.linked_movie_id = t2.id));

CREATE OR REPLACE TEMP VIEW ya_32b_rewriteYa4_down_lt AS
SELECT lt.*
FROM ya_32b_rewriteYa4_up_lt AS lt
WHERE EXISTS (SELECT 1 FROM ya_32b_rewriteYa4_down_ml AS ml WHERE (lt.id = ml.link_type_id));

CREATE OR REPLACE TEMP VIEW ya_32b_rewriteYa4_down_k AS
SELECT k.*
FROM ya_32b_rewriteYa4_up_k AS k
WHERE EXISTS (SELECT 1 FROM ya_32b_rewriteYa4_down_mk AS mk WHERE (mk.keyword_id = k.id));

SELECT lt.link,
       t1.title,
       t2.title,
       SUM(1) AS record_count
FROM ya_32b_rewriteYa4_down_k AS k,
     ya_32b_rewriteYa4_down_lt AS lt,
     ya_32b_rewriteYa4_down_mk AS mk,
     ya_32b_rewriteYa4_down_ml AS ml,
     ya_32b_rewriteYa4_down_t1 AS t1,
     ya_32b_rewriteYa4_down_t2 AS t2
WHERE (k.keyword ='character-name-in-title')
  AND (mk.keyword_id = k.id)
  AND (t1.id = mk.movie_id)
  AND (ml.movie_id = t1.id)
  AND (ml.linked_movie_id = t2.id)
  AND (lt.id = ml.link_type_id)
  AND (mk.movie_id = t1.id)
GROUP BY lt.link, t1.title, t2.title;
