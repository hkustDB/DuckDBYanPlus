-- DuckDB SUM(1) Yannakakis-style two-pass reducer generated from job_agg/26c.sql.

-- Source variant: query/job_duckdb/26c/rewriteYa0.sql

CREATE OR REPLACE TEMP VIEW ya_26c_rewriteYa0_base_cc AS
SELECT cc.*
FROM complete_cast AS cc;

CREATE OR REPLACE TEMP VIEW ya_26c_rewriteYa0_base_cct1 AS
SELECT cct1.*
FROM comp_cast_type AS cct1
WHERE (cct1.kind = 'cast');

CREATE OR REPLACE TEMP VIEW ya_26c_rewriteYa0_base_cct2 AS
SELECT cct2.*
FROM comp_cast_type AS cct2
WHERE (cct2.kind LIKE '%complete%');

CREATE OR REPLACE TEMP VIEW ya_26c_rewriteYa0_base_chn AS
SELECT chn.*
FROM char_name AS chn
WHERE (chn.name IS NOT NULL)
  AND ((chn.name LIKE '%man%'
       OR chn.name LIKE '%Man%'));

CREATE OR REPLACE TEMP VIEW ya_26c_rewriteYa0_base_ci AS
SELECT ci.*
FROM cast_info AS ci;

CREATE OR REPLACE TEMP VIEW ya_26c_rewriteYa0_base_it2 AS
SELECT it2.*
FROM info_type AS it2
WHERE (it2.info = 'rating');

CREATE OR REPLACE TEMP VIEW ya_26c_rewriteYa0_base_k AS
SELECT k.*
FROM keyword AS k
WHERE (k.keyword IN ('superhero',
                    'marvel-comics',
                    'based-on-comic',
                    'tv-special',
                    'fight',
                    'violence',
                    'magnet',
                    'web',
                    'claw',
                    'laser'));

CREATE OR REPLACE TEMP VIEW ya_26c_rewriteYa0_base_kt AS
SELECT kt.*
FROM kind_type AS kt
WHERE (kt.kind = 'movie');

CREATE OR REPLACE TEMP VIEW ya_26c_rewriteYa0_base_mi_idx AS
SELECT mi_idx.*
FROM movie_info_idx AS mi_idx;

CREATE OR REPLACE TEMP VIEW ya_26c_rewriteYa0_base_mk AS
SELECT mk.*
FROM movie_keyword AS mk;

CREATE OR REPLACE TEMP VIEW ya_26c_rewriteYa0_base_n AS
SELECT n.*
FROM name AS n;

CREATE OR REPLACE TEMP VIEW ya_26c_rewriteYa0_base_t AS
SELECT t.*
FROM title AS t
WHERE (t.production_year > 2000);

CREATE OR REPLACE TEMP VIEW ya_26c_rewriteYa0_up_cct2 AS
SELECT cct2.*
FROM ya_26c_rewriteYa0_base_cct2 AS cct2;

CREATE OR REPLACE TEMP VIEW ya_26c_rewriteYa0_up_chn AS
SELECT chn.*
FROM ya_26c_rewriteYa0_base_chn AS chn;

CREATE OR REPLACE TEMP VIEW ya_26c_rewriteYa0_up_n AS
SELECT n.*
FROM ya_26c_rewriteYa0_base_n AS n;

CREATE OR REPLACE TEMP VIEW ya_26c_rewriteYa0_up_ci AS
SELECT ci.*
FROM ya_26c_rewriteYa0_base_ci AS ci
WHERE EXISTS (SELECT 1 FROM ya_26c_rewriteYa0_up_chn AS chn WHERE (chn.id = ci.person_role_id))
  AND EXISTS (SELECT 1 FROM ya_26c_rewriteYa0_up_n AS n WHERE (n.id = ci.person_id));

CREATE OR REPLACE TEMP VIEW ya_26c_rewriteYa0_up_it2 AS
SELECT it2.*
FROM ya_26c_rewriteYa0_base_it2 AS it2;

CREATE OR REPLACE TEMP VIEW ya_26c_rewriteYa0_up_mi_idx AS
SELECT mi_idx.*
FROM ya_26c_rewriteYa0_base_mi_idx AS mi_idx
WHERE EXISTS (SELECT 1 FROM ya_26c_rewriteYa0_up_it2 AS it2 WHERE (it2.id = mi_idx.info_type_id));

CREATE OR REPLACE TEMP VIEW ya_26c_rewriteYa0_up_k AS
SELECT k.*
FROM ya_26c_rewriteYa0_base_k AS k;

CREATE OR REPLACE TEMP VIEW ya_26c_rewriteYa0_up_mk AS
SELECT mk.*
FROM ya_26c_rewriteYa0_base_mk AS mk
WHERE EXISTS (SELECT 1 FROM ya_26c_rewriteYa0_up_k AS k WHERE (k.id = mk.keyword_id));

CREATE OR REPLACE TEMP VIEW ya_26c_rewriteYa0_up_kt AS
SELECT kt.*
FROM ya_26c_rewriteYa0_base_kt AS kt;

CREATE OR REPLACE TEMP VIEW ya_26c_rewriteYa0_up_t AS
SELECT t.*
FROM ya_26c_rewriteYa0_base_t AS t
WHERE EXISTS (SELECT 1 FROM ya_26c_rewriteYa0_up_kt AS kt WHERE (kt.id = t.kind_id));

CREATE OR REPLACE TEMP VIEW ya_26c_rewriteYa0_up_cct1 AS
SELECT cct1.*
FROM ya_26c_rewriteYa0_base_cct1 AS cct1;

CREATE OR REPLACE TEMP VIEW ya_26c_rewriteYa0_up_cc AS
SELECT cc.*
FROM ya_26c_rewriteYa0_base_cc AS cc
WHERE EXISTS (SELECT 1 FROM ya_26c_rewriteYa0_up_cct2 AS cct2 WHERE (cct2.id = cc.status_id))
  AND EXISTS (SELECT 1 FROM ya_26c_rewriteYa0_up_ci AS ci WHERE (ci.movie_id = cc.movie_id))
  AND EXISTS (SELECT 1 FROM ya_26c_rewriteYa0_up_mi_idx AS mi_idx WHERE (cc.movie_id = mi_idx.movie_id))
  AND EXISTS (SELECT 1 FROM ya_26c_rewriteYa0_up_mk AS mk WHERE (mk.movie_id = cc.movie_id))
  AND EXISTS (SELECT 1 FROM ya_26c_rewriteYa0_up_t AS t WHERE (t.id = cc.movie_id))
  AND EXISTS (SELECT 1 FROM ya_26c_rewriteYa0_up_cct1 AS cct1 WHERE (cct1.id = cc.subject_id));

CREATE OR REPLACE TEMP VIEW ya_26c_rewriteYa0_down_cc AS
SELECT cc.*
FROM ya_26c_rewriteYa0_up_cc AS cc;

CREATE OR REPLACE TEMP VIEW ya_26c_rewriteYa0_down_cct2 AS
SELECT cct2.*
FROM ya_26c_rewriteYa0_up_cct2 AS cct2
WHERE EXISTS (SELECT 1 FROM ya_26c_rewriteYa0_down_cc AS cc WHERE (cct2.id = cc.status_id));

CREATE OR REPLACE TEMP VIEW ya_26c_rewriteYa0_down_ci AS
SELECT ci.*
FROM ya_26c_rewriteYa0_up_ci AS ci
WHERE EXISTS (SELECT 1 FROM ya_26c_rewriteYa0_down_cc AS cc WHERE (ci.movie_id = cc.movie_id));

CREATE OR REPLACE TEMP VIEW ya_26c_rewriteYa0_down_mi_idx AS
SELECT mi_idx.*
FROM ya_26c_rewriteYa0_up_mi_idx AS mi_idx
WHERE EXISTS (SELECT 1 FROM ya_26c_rewriteYa0_down_cc AS cc WHERE (cc.movie_id = mi_idx.movie_id));

CREATE OR REPLACE TEMP VIEW ya_26c_rewriteYa0_down_mk AS
SELECT mk.*
FROM ya_26c_rewriteYa0_up_mk AS mk
WHERE EXISTS (SELECT 1 FROM ya_26c_rewriteYa0_down_cc AS cc WHERE (mk.movie_id = cc.movie_id));

CREATE OR REPLACE TEMP VIEW ya_26c_rewriteYa0_down_t AS
SELECT t.*
FROM ya_26c_rewriteYa0_up_t AS t
WHERE EXISTS (SELECT 1 FROM ya_26c_rewriteYa0_down_cc AS cc WHERE (t.id = cc.movie_id));

CREATE OR REPLACE TEMP VIEW ya_26c_rewriteYa0_down_cct1 AS
SELECT cct1.*
FROM ya_26c_rewriteYa0_up_cct1 AS cct1
WHERE EXISTS (SELECT 1 FROM ya_26c_rewriteYa0_down_cc AS cc WHERE (cct1.id = cc.subject_id));

CREATE OR REPLACE TEMP VIEW ya_26c_rewriteYa0_down_chn AS
SELECT chn.*
FROM ya_26c_rewriteYa0_up_chn AS chn
WHERE EXISTS (SELECT 1 FROM ya_26c_rewriteYa0_down_ci AS ci WHERE (chn.id = ci.person_role_id));

CREATE OR REPLACE TEMP VIEW ya_26c_rewriteYa0_down_n AS
SELECT n.*
FROM ya_26c_rewriteYa0_up_n AS n
WHERE EXISTS (SELECT 1 FROM ya_26c_rewriteYa0_down_ci AS ci WHERE (n.id = ci.person_id));

CREATE OR REPLACE TEMP VIEW ya_26c_rewriteYa0_down_it2 AS
SELECT it2.*
FROM ya_26c_rewriteYa0_up_it2 AS it2
WHERE EXISTS (SELECT 1 FROM ya_26c_rewriteYa0_down_mi_idx AS mi_idx WHERE (it2.id = mi_idx.info_type_id));

CREATE OR REPLACE TEMP VIEW ya_26c_rewriteYa0_down_k AS
SELECT k.*
FROM ya_26c_rewriteYa0_up_k AS k
WHERE EXISTS (SELECT 1 FROM ya_26c_rewriteYa0_down_mk AS mk WHERE (k.id = mk.keyword_id));

CREATE OR REPLACE TEMP VIEW ya_26c_rewriteYa0_down_kt AS
SELECT kt.*
FROM ya_26c_rewriteYa0_up_kt AS kt
WHERE EXISTS (SELECT 1 FROM ya_26c_rewriteYa0_down_t AS t WHERE (kt.id = t.kind_id));

SELECT chn.name,
       mi_idx.info,
       t.title,
       SUM(1) AS record_count
FROM ya_26c_rewriteYa0_down_cc AS cc,
     ya_26c_rewriteYa0_down_cct1 AS cct1,
     ya_26c_rewriteYa0_down_cct2 AS cct2,
     ya_26c_rewriteYa0_down_chn AS chn,
     ya_26c_rewriteYa0_down_ci AS ci,
     ya_26c_rewriteYa0_down_it2 AS it2,
     ya_26c_rewriteYa0_down_k AS k,
     ya_26c_rewriteYa0_down_kt AS kt,
     ya_26c_rewriteYa0_down_mi_idx AS mi_idx,
     ya_26c_rewriteYa0_down_mk AS mk,
     ya_26c_rewriteYa0_down_n AS n,
     ya_26c_rewriteYa0_down_t AS t
WHERE (cct1.kind = 'cast')
  AND (cct2.kind LIKE '%complete%')
  AND (chn.name IS NOT NULL)
  AND ((chn.name LIKE '%man%'
       OR chn.name LIKE '%Man%'))
  AND (it2.info = 'rating')
  AND (k.keyword IN ('superhero',
                    'marvel-comics',
                    'based-on-comic',
                    'tv-special',
                    'fight',
                    'violence',
                    'magnet',
                    'web',
                    'claw',
                    'laser'))
  AND (kt.kind = 'movie')
  AND (t.production_year > 2000)
  AND (kt.id = t.kind_id)
  AND (t.id = mk.movie_id)
  AND (t.id = ci.movie_id)
  AND (t.id = cc.movie_id)
  AND (t.id = mi_idx.movie_id)
  AND (mk.movie_id = ci.movie_id)
  AND (mk.movie_id = cc.movie_id)
  AND (mk.movie_id = mi_idx.movie_id)
  AND (ci.movie_id = cc.movie_id)
  AND (ci.movie_id = mi_idx.movie_id)
  AND (cc.movie_id = mi_idx.movie_id)
  AND (chn.id = ci.person_role_id)
  AND (n.id = ci.person_id)
  AND (k.id = mk.keyword_id)
  AND (cct1.id = cc.subject_id)
  AND (cct2.id = cc.status_id)
  AND (it2.id = mi_idx.info_type_id)
GROUP BY chn.name, mi_idx.info, t.title;
