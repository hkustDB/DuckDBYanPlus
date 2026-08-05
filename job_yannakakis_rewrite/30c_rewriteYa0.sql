-- DuckDB SUM(1) Yannakakis-style two-pass reducer generated from job_agg/30c.sql.

-- Source variant: query/job_duckdb/30c/rewriteYa0.sql

CREATE OR REPLACE TEMP VIEW ya_30c_rewriteYa0_base_cc AS
SELECT cc.*
FROM complete_cast AS cc;

CREATE OR REPLACE TEMP VIEW ya_30c_rewriteYa0_base_cct1 AS
SELECT cct1.*
FROM comp_cast_type AS cct1
WHERE (cct1.kind = 'cast');

CREATE OR REPLACE TEMP VIEW ya_30c_rewriteYa0_base_cct2 AS
SELECT cct2.*
FROM comp_cast_type AS cct2
WHERE (cct2.kind ='complete+verified');

CREATE OR REPLACE TEMP VIEW ya_30c_rewriteYa0_base_ci AS
SELECT ci.*
FROM cast_info AS ci
WHERE (ci.note IN ('(writer)',
                  '(head writer)',
                  '(written by)',
                  '(story)',
                  '(story editor)'));

CREATE OR REPLACE TEMP VIEW ya_30c_rewriteYa0_base_it1 AS
SELECT it1.*
FROM info_type AS it1
WHERE (it1.info = 'genres');

CREATE OR REPLACE TEMP VIEW ya_30c_rewriteYa0_base_it2 AS
SELECT it2.*
FROM info_type AS it2
WHERE (it2.info = 'votes');

CREATE OR REPLACE TEMP VIEW ya_30c_rewriteYa0_base_k AS
SELECT k.*
FROM keyword AS k
WHERE (k.keyword IN ('murder',
                    'violence',
                    'blood',
                    'gore',
                    'death',
                    'female-nudity',
                    'hospital'));

CREATE OR REPLACE TEMP VIEW ya_30c_rewriteYa0_base_mi AS
SELECT mi.*
FROM movie_info AS mi
WHERE (mi.info IN ('Horror',
                  'Action',
                  'Sci-Fi',
                  'Thriller',
                  'Crime',
                  'War'));

CREATE OR REPLACE TEMP VIEW ya_30c_rewriteYa0_base_mi_idx AS
SELECT mi_idx.*
FROM movie_info_idx AS mi_idx;

CREATE OR REPLACE TEMP VIEW ya_30c_rewriteYa0_base_mk AS
SELECT mk.*
FROM movie_keyword AS mk;

CREATE OR REPLACE TEMP VIEW ya_30c_rewriteYa0_base_n AS
SELECT n.*
FROM name AS n
WHERE (n.gender = 'm');

CREATE OR REPLACE TEMP VIEW ya_30c_rewriteYa0_base_t AS
SELECT t.*
FROM title AS t;

CREATE OR REPLACE TEMP VIEW ya_30c_rewriteYa0_up_cct2 AS
SELECT cct2.*
FROM ya_30c_rewriteYa0_base_cct2 AS cct2;

CREATE OR REPLACE TEMP VIEW ya_30c_rewriteYa0_up_n AS
SELECT n.*
FROM ya_30c_rewriteYa0_base_n AS n;

CREATE OR REPLACE TEMP VIEW ya_30c_rewriteYa0_up_ci AS
SELECT ci.*
FROM ya_30c_rewriteYa0_base_ci AS ci
WHERE EXISTS (SELECT 1 FROM ya_30c_rewriteYa0_up_n AS n WHERE (n.id = ci.person_id));

CREATE OR REPLACE TEMP VIEW ya_30c_rewriteYa0_up_it1 AS
SELECT it1.*
FROM ya_30c_rewriteYa0_base_it1 AS it1;

CREATE OR REPLACE TEMP VIEW ya_30c_rewriteYa0_up_mi AS
SELECT mi.*
FROM ya_30c_rewriteYa0_base_mi AS mi
WHERE EXISTS (SELECT 1 FROM ya_30c_rewriteYa0_up_it1 AS it1 WHERE (it1.id = mi.info_type_id));

CREATE OR REPLACE TEMP VIEW ya_30c_rewriteYa0_up_it2 AS
SELECT it2.*
FROM ya_30c_rewriteYa0_base_it2 AS it2;

CREATE OR REPLACE TEMP VIEW ya_30c_rewriteYa0_up_mi_idx AS
SELECT mi_idx.*
FROM ya_30c_rewriteYa0_base_mi_idx AS mi_idx
WHERE EXISTS (SELECT 1 FROM ya_30c_rewriteYa0_up_it2 AS it2 WHERE (it2.id = mi_idx.info_type_id));

CREATE OR REPLACE TEMP VIEW ya_30c_rewriteYa0_up_k AS
SELECT k.*
FROM ya_30c_rewriteYa0_base_k AS k;

CREATE OR REPLACE TEMP VIEW ya_30c_rewriteYa0_up_mk AS
SELECT mk.*
FROM ya_30c_rewriteYa0_base_mk AS mk
WHERE EXISTS (SELECT 1 FROM ya_30c_rewriteYa0_up_k AS k WHERE (k.id = mk.keyword_id));

CREATE OR REPLACE TEMP VIEW ya_30c_rewriteYa0_up_t AS
SELECT t.*
FROM ya_30c_rewriteYa0_base_t AS t;

CREATE OR REPLACE TEMP VIEW ya_30c_rewriteYa0_up_cct1 AS
SELECT cct1.*
FROM ya_30c_rewriteYa0_base_cct1 AS cct1;

CREATE OR REPLACE TEMP VIEW ya_30c_rewriteYa0_up_cc AS
SELECT cc.*
FROM ya_30c_rewriteYa0_base_cc AS cc
WHERE EXISTS (SELECT 1 FROM ya_30c_rewriteYa0_up_cct2 AS cct2 WHERE (cct2.id = cc.status_id))
  AND EXISTS (SELECT 1 FROM ya_30c_rewriteYa0_up_ci AS ci WHERE (ci.movie_id = cc.movie_id))
  AND EXISTS (SELECT 1 FROM ya_30c_rewriteYa0_up_mi AS mi WHERE (mi.movie_id = cc.movie_id))
  AND EXISTS (SELECT 1 FROM ya_30c_rewriteYa0_up_mi_idx AS mi_idx WHERE (mi_idx.movie_id = cc.movie_id))
  AND EXISTS (SELECT 1 FROM ya_30c_rewriteYa0_up_mk AS mk WHERE (mk.movie_id = cc.movie_id))
  AND EXISTS (SELECT 1 FROM ya_30c_rewriteYa0_up_t AS t WHERE (t.id = cc.movie_id))
  AND EXISTS (SELECT 1 FROM ya_30c_rewriteYa0_up_cct1 AS cct1 WHERE (cct1.id = cc.subject_id));

CREATE OR REPLACE TEMP VIEW ya_30c_rewriteYa0_down_cc AS
SELECT cc.*
FROM ya_30c_rewriteYa0_up_cc AS cc;

CREATE OR REPLACE TEMP VIEW ya_30c_rewriteYa0_down_cct2 AS
SELECT cct2.*
FROM ya_30c_rewriteYa0_up_cct2 AS cct2
WHERE EXISTS (SELECT 1 FROM ya_30c_rewriteYa0_down_cc AS cc WHERE (cct2.id = cc.status_id));

CREATE OR REPLACE TEMP VIEW ya_30c_rewriteYa0_down_ci AS
SELECT ci.*
FROM ya_30c_rewriteYa0_up_ci AS ci
WHERE EXISTS (SELECT 1 FROM ya_30c_rewriteYa0_down_cc AS cc WHERE (ci.movie_id = cc.movie_id));

CREATE OR REPLACE TEMP VIEW ya_30c_rewriteYa0_down_mi AS
SELECT mi.*
FROM ya_30c_rewriteYa0_up_mi AS mi
WHERE EXISTS (SELECT 1 FROM ya_30c_rewriteYa0_down_cc AS cc WHERE (mi.movie_id = cc.movie_id));

CREATE OR REPLACE TEMP VIEW ya_30c_rewriteYa0_down_mi_idx AS
SELECT mi_idx.*
FROM ya_30c_rewriteYa0_up_mi_idx AS mi_idx
WHERE EXISTS (SELECT 1 FROM ya_30c_rewriteYa0_down_cc AS cc WHERE (mi_idx.movie_id = cc.movie_id));

CREATE OR REPLACE TEMP VIEW ya_30c_rewriteYa0_down_mk AS
SELECT mk.*
FROM ya_30c_rewriteYa0_up_mk AS mk
WHERE EXISTS (SELECT 1 FROM ya_30c_rewriteYa0_down_cc AS cc WHERE (mk.movie_id = cc.movie_id));

CREATE OR REPLACE TEMP VIEW ya_30c_rewriteYa0_down_t AS
SELECT t.*
FROM ya_30c_rewriteYa0_up_t AS t
WHERE EXISTS (SELECT 1 FROM ya_30c_rewriteYa0_down_cc AS cc WHERE (t.id = cc.movie_id));

CREATE OR REPLACE TEMP VIEW ya_30c_rewriteYa0_down_cct1 AS
SELECT cct1.*
FROM ya_30c_rewriteYa0_up_cct1 AS cct1
WHERE EXISTS (SELECT 1 FROM ya_30c_rewriteYa0_down_cc AS cc WHERE (cct1.id = cc.subject_id));

CREATE OR REPLACE TEMP VIEW ya_30c_rewriteYa0_down_n AS
SELECT n.*
FROM ya_30c_rewriteYa0_up_n AS n
WHERE EXISTS (SELECT 1 FROM ya_30c_rewriteYa0_down_ci AS ci WHERE (n.id = ci.person_id));

CREATE OR REPLACE TEMP VIEW ya_30c_rewriteYa0_down_it1 AS
SELECT it1.*
FROM ya_30c_rewriteYa0_up_it1 AS it1
WHERE EXISTS (SELECT 1 FROM ya_30c_rewriteYa0_down_mi AS mi WHERE (it1.id = mi.info_type_id));

CREATE OR REPLACE TEMP VIEW ya_30c_rewriteYa0_down_it2 AS
SELECT it2.*
FROM ya_30c_rewriteYa0_up_it2 AS it2
WHERE EXISTS (SELECT 1 FROM ya_30c_rewriteYa0_down_mi_idx AS mi_idx WHERE (it2.id = mi_idx.info_type_id));

CREATE OR REPLACE TEMP VIEW ya_30c_rewriteYa0_down_k AS
SELECT k.*
FROM ya_30c_rewriteYa0_up_k AS k
WHERE EXISTS (SELECT 1 FROM ya_30c_rewriteYa0_down_mk AS mk WHERE (k.id = mk.keyword_id));

SELECT mi.info,
       mi_idx.info,
       n.name,
       t.title,
       SUM(1) AS record_count
FROM ya_30c_rewriteYa0_down_cc AS cc,
     ya_30c_rewriteYa0_down_cct1 AS cct1,
     ya_30c_rewriteYa0_down_cct2 AS cct2,
     ya_30c_rewriteYa0_down_ci AS ci,
     ya_30c_rewriteYa0_down_it1 AS it1,
     ya_30c_rewriteYa0_down_it2 AS it2,
     ya_30c_rewriteYa0_down_k AS k,
     ya_30c_rewriteYa0_down_mi AS mi,
     ya_30c_rewriteYa0_down_mi_idx AS mi_idx,
     ya_30c_rewriteYa0_down_mk AS mk,
     ya_30c_rewriteYa0_down_n AS n,
     ya_30c_rewriteYa0_down_t AS t
WHERE (cct1.kind = 'cast')
  AND (cct2.kind ='complete+verified')
  AND (ci.note IN ('(writer)',
                  '(head writer)',
                  '(written by)',
                  '(story)',
                  '(story editor)'))
  AND (it1.info = 'genres')
  AND (it2.info = 'votes')
  AND (k.keyword IN ('murder',
                    'violence',
                    'blood',
                    'gore',
                    'death',
                    'female-nudity',
                    'hospital'))
  AND (mi.info IN ('Horror',
                  'Action',
                  'Sci-Fi',
                  'Thriller',
                  'Crime',
                  'War'))
  AND (n.gender = 'm')
  AND (t.id = mi.movie_id)
  AND (t.id = mi_idx.movie_id)
  AND (t.id = ci.movie_id)
  AND (t.id = mk.movie_id)
  AND (t.id = cc.movie_id)
  AND (ci.movie_id = mi.movie_id)
  AND (ci.movie_id = mi_idx.movie_id)
  AND (ci.movie_id = mk.movie_id)
  AND (ci.movie_id = cc.movie_id)
  AND (mi.movie_id = mi_idx.movie_id)
  AND (mi.movie_id = mk.movie_id)
  AND (mi.movie_id = cc.movie_id)
  AND (mi_idx.movie_id = mk.movie_id)
  AND (mi_idx.movie_id = cc.movie_id)
  AND (mk.movie_id = cc.movie_id)
  AND (n.id = ci.person_id)
  AND (it1.id = mi.info_type_id)
  AND (it2.id = mi_idx.info_type_id)
  AND (k.id = mk.keyword_id)
  AND (cct1.id = cc.subject_id)
  AND (cct2.id = cc.status_id)
GROUP BY mi.info, mi_idx.info, n.name, t.title;
