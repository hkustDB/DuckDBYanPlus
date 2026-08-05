-- DuckDB SUM(1) Yannakakis-style two-pass reducer generated from job_agg/18b.sql.

-- Source variant: query/job_duckdb/18b/rewriteYa23.sql

CREATE OR REPLACE TEMP VIEW ya_18b_rewriteYa23_base_ci AS
SELECT ci.*
FROM cast_info AS ci
WHERE (ci.note IN ('(writer)',
                  '(head writer)',
                  '(written by)',
                  '(story)',
                  '(story editor)'));

CREATE OR REPLACE TEMP VIEW ya_18b_rewriteYa23_base_it1 AS
SELECT it1.*
FROM info_type AS it1
WHERE (it1.info = 'genres');

CREATE OR REPLACE TEMP VIEW ya_18b_rewriteYa23_base_it2 AS
SELECT it2.*
FROM info_type AS it2
WHERE (it2.info = 'rating');

CREATE OR REPLACE TEMP VIEW ya_18b_rewriteYa23_base_mi AS
SELECT mi.*
FROM movie_info AS mi
WHERE (mi.info IN ('Horror',
                  'Thriller'))
  AND (mi.note IS NULL);

CREATE OR REPLACE TEMP VIEW ya_18b_rewriteYa23_base_mi_idx AS
SELECT mi_idx.*
FROM movie_info_idx AS mi_idx
WHERE (mi_idx.info > '8.0');

CREATE OR REPLACE TEMP VIEW ya_18b_rewriteYa23_base_n AS
SELECT n.*
FROM name AS n
WHERE (n.gender IS NOT NULL)
  AND (n.gender = 'f');

CREATE OR REPLACE TEMP VIEW ya_18b_rewriteYa23_base_t AS
SELECT t.*
FROM title AS t
WHERE (t.production_year BETWEEN 2008 AND 2014);

CREATE OR REPLACE TEMP VIEW ya_18b_rewriteYa23_up_it1 AS
SELECT it1.*
FROM ya_18b_rewriteYa23_base_it1 AS it1;

CREATE OR REPLACE TEMP VIEW ya_18b_rewriteYa23_up_mi AS
SELECT mi.*
FROM ya_18b_rewriteYa23_base_mi AS mi
WHERE EXISTS (SELECT 1 FROM ya_18b_rewriteYa23_up_it1 AS it1 WHERE (it1.id = mi.info_type_id));

CREATE OR REPLACE TEMP VIEW ya_18b_rewriteYa23_up_t AS
SELECT t.*
FROM ya_18b_rewriteYa23_base_t AS t;

CREATE OR REPLACE TEMP VIEW ya_18b_rewriteYa23_up_n AS
SELECT n.*
FROM ya_18b_rewriteYa23_base_n AS n;

CREATE OR REPLACE TEMP VIEW ya_18b_rewriteYa23_up_ci AS
SELECT ci.*
FROM ya_18b_rewriteYa23_base_ci AS ci
WHERE EXISTS (SELECT 1 FROM ya_18b_rewriteYa23_up_n AS n WHERE (n.id = ci.person_id));

CREATE OR REPLACE TEMP VIEW ya_18b_rewriteYa23_up_mi_idx AS
SELECT mi_idx.*
FROM ya_18b_rewriteYa23_base_mi_idx AS mi_idx
WHERE EXISTS (SELECT 1 FROM ya_18b_rewriteYa23_up_mi AS mi WHERE (mi.movie_id = mi_idx.movie_id))
  AND EXISTS (SELECT 1 FROM ya_18b_rewriteYa23_up_t AS t WHERE (t.id = mi_idx.movie_id))
  AND EXISTS (SELECT 1 FROM ya_18b_rewriteYa23_up_ci AS ci WHERE (ci.movie_id = mi_idx.movie_id));

CREATE OR REPLACE TEMP VIEW ya_18b_rewriteYa23_up_it2 AS
SELECT it2.*
FROM ya_18b_rewriteYa23_base_it2 AS it2
WHERE EXISTS (SELECT 1 FROM ya_18b_rewriteYa23_up_mi_idx AS mi_idx WHERE (it2.id = mi_idx.info_type_id));

CREATE OR REPLACE TEMP VIEW ya_18b_rewriteYa23_down_it2 AS
SELECT it2.*
FROM ya_18b_rewriteYa23_up_it2 AS it2;

CREATE OR REPLACE TEMP VIEW ya_18b_rewriteYa23_down_mi_idx AS
SELECT mi_idx.*
FROM ya_18b_rewriteYa23_up_mi_idx AS mi_idx
WHERE EXISTS (SELECT 1 FROM ya_18b_rewriteYa23_down_it2 AS it2 WHERE (it2.id = mi_idx.info_type_id));

CREATE OR REPLACE TEMP VIEW ya_18b_rewriteYa23_down_mi AS
SELECT mi.*
FROM ya_18b_rewriteYa23_up_mi AS mi
WHERE EXISTS (SELECT 1 FROM ya_18b_rewriteYa23_down_mi_idx AS mi_idx WHERE (mi.movie_id = mi_idx.movie_id));

CREATE OR REPLACE TEMP VIEW ya_18b_rewriteYa23_down_t AS
SELECT t.*
FROM ya_18b_rewriteYa23_up_t AS t
WHERE EXISTS (SELECT 1 FROM ya_18b_rewriteYa23_down_mi_idx AS mi_idx WHERE (t.id = mi_idx.movie_id));

CREATE OR REPLACE TEMP VIEW ya_18b_rewriteYa23_down_ci AS
SELECT ci.*
FROM ya_18b_rewriteYa23_up_ci AS ci
WHERE EXISTS (SELECT 1 FROM ya_18b_rewriteYa23_down_mi_idx AS mi_idx WHERE (ci.movie_id = mi_idx.movie_id));

CREATE OR REPLACE TEMP VIEW ya_18b_rewriteYa23_down_it1 AS
SELECT it1.*
FROM ya_18b_rewriteYa23_up_it1 AS it1
WHERE EXISTS (SELECT 1 FROM ya_18b_rewriteYa23_down_mi AS mi WHERE (it1.id = mi.info_type_id));

CREATE OR REPLACE TEMP VIEW ya_18b_rewriteYa23_down_n AS
SELECT n.*
FROM ya_18b_rewriteYa23_up_n AS n
WHERE EXISTS (SELECT 1 FROM ya_18b_rewriteYa23_down_ci AS ci WHERE (n.id = ci.person_id));

SELECT mi.info,
       mi_idx.info,
       t.title,
       SUM(1) AS record_count
FROM ya_18b_rewriteYa23_down_ci AS ci,
     ya_18b_rewriteYa23_down_it1 AS it1,
     ya_18b_rewriteYa23_down_it2 AS it2,
     ya_18b_rewriteYa23_down_mi AS mi,
     ya_18b_rewriteYa23_down_mi_idx AS mi_idx,
     ya_18b_rewriteYa23_down_n AS n,
     ya_18b_rewriteYa23_down_t AS t
WHERE (ci.note IN ('(writer)',
                  '(head writer)',
                  '(written by)',
                  '(story)',
                  '(story editor)'))
  AND (it1.info = 'genres')
  AND (it2.info = 'rating')
  AND (mi.info IN ('Horror',
                  'Thriller'))
  AND (mi.note IS NULL)
  AND (mi_idx.info > '8.0')
  AND (n.gender IS NOT NULL)
  AND (n.gender = 'f')
  AND (t.production_year BETWEEN 2008 AND 2014)
  AND (t.id = mi.movie_id)
  AND (t.id = mi_idx.movie_id)
  AND (t.id = ci.movie_id)
  AND (ci.movie_id = mi.movie_id)
  AND (ci.movie_id = mi_idx.movie_id)
  AND (mi.movie_id = mi_idx.movie_id)
  AND (n.id = ci.person_id)
  AND (it1.id = mi.info_type_id)
  AND (it2.id = mi_idx.info_type_id)
GROUP BY mi.info, mi_idx.info, t.title;
