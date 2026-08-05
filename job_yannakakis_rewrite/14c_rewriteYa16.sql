-- DuckDB SUM(1) Yannakakis-style two-pass reducer generated from job_agg/14c.sql.

-- Source variant: query/job_duckdb/14c/rewriteYa16.sql

CREATE OR REPLACE TEMP VIEW ya_14c_rewriteYa16_base_it1 AS
SELECT it1.*
FROM info_type AS it1
WHERE (it1.info = 'countries');

CREATE OR REPLACE TEMP VIEW ya_14c_rewriteYa16_base_it2 AS
SELECT it2.*
FROM info_type AS it2
WHERE (it2.info = 'rating');

CREATE OR REPLACE TEMP VIEW ya_14c_rewriteYa16_base_k AS
SELECT k.*
FROM keyword AS k
WHERE (k.keyword IS NOT NULL)
  AND (k.keyword IN ('murder',
                    'murder-in-title',
                    'blood',
                    'violence'));

CREATE OR REPLACE TEMP VIEW ya_14c_rewriteYa16_base_kt AS
SELECT kt.*
FROM kind_type AS kt
WHERE (kt.kind IN ('movie',
                  'episode'));

CREATE OR REPLACE TEMP VIEW ya_14c_rewriteYa16_base_mi AS
SELECT mi.*
FROM movie_info AS mi
WHERE (mi.info IN ('Sweden',
                  'Norway',
                  'Germany',
                  'Denmark',
                  'Swedish',
                  'Danish',
                  'Norwegian',
                  'German',
                  'USA',
                  'American'));

CREATE OR REPLACE TEMP VIEW ya_14c_rewriteYa16_base_mi_idx AS
SELECT mi_idx.*
FROM movie_info_idx AS mi_idx
WHERE (mi_idx.info < '8.5');

CREATE OR REPLACE TEMP VIEW ya_14c_rewriteYa16_base_mk AS
SELECT mk.*
FROM movie_keyword AS mk;

CREATE OR REPLACE TEMP VIEW ya_14c_rewriteYa16_base_t AS
SELECT t.*
FROM title AS t
WHERE (t.production_year > 2005);

CREATE OR REPLACE TEMP VIEW ya_14c_rewriteYa16_up_k AS
SELECT k.*
FROM ya_14c_rewriteYa16_base_k AS k;

CREATE OR REPLACE TEMP VIEW ya_14c_rewriteYa16_up_mk AS
SELECT mk.*
FROM ya_14c_rewriteYa16_base_mk AS mk
WHERE EXISTS (SELECT 1 FROM ya_14c_rewriteYa16_up_k AS k WHERE (k.id = mk.keyword_id));

CREATE OR REPLACE TEMP VIEW ya_14c_rewriteYa16_up_kt AS
SELECT kt.*
FROM ya_14c_rewriteYa16_base_kt AS kt;

CREATE OR REPLACE TEMP VIEW ya_14c_rewriteYa16_up_t AS
SELECT t.*
FROM ya_14c_rewriteYa16_base_t AS t
WHERE EXISTS (SELECT 1 FROM ya_14c_rewriteYa16_up_kt AS kt WHERE (kt.id = t.kind_id));

CREATE OR REPLACE TEMP VIEW ya_14c_rewriteYa16_up_it2 AS
SELECT it2.*
FROM ya_14c_rewriteYa16_base_it2 AS it2;

CREATE OR REPLACE TEMP VIEW ya_14c_rewriteYa16_up_mi_idx AS
SELECT mi_idx.*
FROM ya_14c_rewriteYa16_base_mi_idx AS mi_idx
WHERE EXISTS (SELECT 1 FROM ya_14c_rewriteYa16_up_it2 AS it2 WHERE (it2.id = mi_idx.info_type_id));

CREATE OR REPLACE TEMP VIEW ya_14c_rewriteYa16_up_mi AS
SELECT mi.*
FROM ya_14c_rewriteYa16_base_mi AS mi
WHERE EXISTS (SELECT 1 FROM ya_14c_rewriteYa16_up_mk AS mk WHERE (mk.movie_id = mi.movie_id))
  AND EXISTS (SELECT 1 FROM ya_14c_rewriteYa16_up_t AS t WHERE (t.id = mi.movie_id))
  AND EXISTS (SELECT 1 FROM ya_14c_rewriteYa16_up_mi_idx AS mi_idx WHERE (mi.movie_id = mi_idx.movie_id));

CREATE OR REPLACE TEMP VIEW ya_14c_rewriteYa16_up_it1 AS
SELECT it1.*
FROM ya_14c_rewriteYa16_base_it1 AS it1
WHERE EXISTS (SELECT 1 FROM ya_14c_rewriteYa16_up_mi AS mi WHERE (it1.id = mi.info_type_id));

CREATE OR REPLACE TEMP VIEW ya_14c_rewriteYa16_down_it1 AS
SELECT it1.*
FROM ya_14c_rewriteYa16_up_it1 AS it1;

CREATE OR REPLACE TEMP VIEW ya_14c_rewriteYa16_down_mi AS
SELECT mi.*
FROM ya_14c_rewriteYa16_up_mi AS mi
WHERE EXISTS (SELECT 1 FROM ya_14c_rewriteYa16_down_it1 AS it1 WHERE (it1.id = mi.info_type_id));

CREATE OR REPLACE TEMP VIEW ya_14c_rewriteYa16_down_mk AS
SELECT mk.*
FROM ya_14c_rewriteYa16_up_mk AS mk
WHERE EXISTS (SELECT 1 FROM ya_14c_rewriteYa16_down_mi AS mi WHERE (mk.movie_id = mi.movie_id));

CREATE OR REPLACE TEMP VIEW ya_14c_rewriteYa16_down_t AS
SELECT t.*
FROM ya_14c_rewriteYa16_up_t AS t
WHERE EXISTS (SELECT 1 FROM ya_14c_rewriteYa16_down_mi AS mi WHERE (t.id = mi.movie_id));

CREATE OR REPLACE TEMP VIEW ya_14c_rewriteYa16_down_mi_idx AS
SELECT mi_idx.*
FROM ya_14c_rewriteYa16_up_mi_idx AS mi_idx
WHERE EXISTS (SELECT 1 FROM ya_14c_rewriteYa16_down_mi AS mi WHERE (mi.movie_id = mi_idx.movie_id));

CREATE OR REPLACE TEMP VIEW ya_14c_rewriteYa16_down_k AS
SELECT k.*
FROM ya_14c_rewriteYa16_up_k AS k
WHERE EXISTS (SELECT 1 FROM ya_14c_rewriteYa16_down_mk AS mk WHERE (k.id = mk.keyword_id));

CREATE OR REPLACE TEMP VIEW ya_14c_rewriteYa16_down_kt AS
SELECT kt.*
FROM ya_14c_rewriteYa16_up_kt AS kt
WHERE EXISTS (SELECT 1 FROM ya_14c_rewriteYa16_down_t AS t WHERE (kt.id = t.kind_id));

CREATE OR REPLACE TEMP VIEW ya_14c_rewriteYa16_down_it2 AS
SELECT it2.*
FROM ya_14c_rewriteYa16_up_it2 AS it2
WHERE EXISTS (SELECT 1 FROM ya_14c_rewriteYa16_down_mi_idx AS mi_idx WHERE (it2.id = mi_idx.info_type_id));

SELECT mi_idx.info,
       t.title,
       SUM(1) AS record_count
FROM ya_14c_rewriteYa16_down_it1 AS it1,
     ya_14c_rewriteYa16_down_it2 AS it2,
     ya_14c_rewriteYa16_down_k AS k,
     ya_14c_rewriteYa16_down_kt AS kt,
     ya_14c_rewriteYa16_down_mi AS mi,
     ya_14c_rewriteYa16_down_mi_idx AS mi_idx,
     ya_14c_rewriteYa16_down_mk AS mk,
     ya_14c_rewriteYa16_down_t AS t
WHERE (it1.info = 'countries')
  AND (it2.info = 'rating')
  AND (k.keyword IS NOT NULL)
  AND (k.keyword IN ('murder',
                    'murder-in-title',
                    'blood',
                    'violence'))
  AND (kt.kind IN ('movie',
                  'episode'))
  AND (mi.info IN ('Sweden',
                  'Norway',
                  'Germany',
                  'Denmark',
                  'Swedish',
                  'Danish',
                  'Norwegian',
                  'German',
                  'USA',
                  'American'))
  AND (mi_idx.info < '8.5')
  AND (t.production_year > 2005)
  AND (kt.id = t.kind_id)
  AND (t.id = mi.movie_id)
  AND (t.id = mk.movie_id)
  AND (t.id = mi_idx.movie_id)
  AND (mk.movie_id = mi.movie_id)
  AND (mk.movie_id = mi_idx.movie_id)
  AND (mi.movie_id = mi_idx.movie_id)
  AND (k.id = mk.keyword_id)
  AND (it1.id = mi.info_type_id)
  AND (it2.id = mi_idx.info_type_id)
GROUP BY mi_idx.info, t.title;
