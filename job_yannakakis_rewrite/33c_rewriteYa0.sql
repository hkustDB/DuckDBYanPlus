-- DuckDB SUM(1) Yannakakis-style two-pass reducer generated from job_agg/33c.sql.

-- Source variant: query/job_duckdb/33c/rewriteYa0.sql

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_base_cn1 AS
SELECT cn1.*
FROM company_name AS cn1
WHERE (cn1.country_code != '[us]');

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_base_cn2 AS
SELECT cn2.*
FROM company_name AS cn2;

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_base_it1 AS
SELECT it1.*
FROM info_type AS it1
WHERE (it1.info = 'rating');

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_base_it2 AS
SELECT it2.*
FROM info_type AS it2
WHERE (it2.info = 'rating');

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_base_kt1 AS
SELECT kt1.*
FROM kind_type AS kt1
WHERE (kt1.kind IN ('tv series',
                   'episode'));

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_base_kt2 AS
SELECT kt2.*
FROM kind_type AS kt2
WHERE (kt2.kind IN ('tv series',
                   'episode'));

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_base_lt AS
SELECT lt.*
FROM link_type AS lt
WHERE (lt.link IN ('sequel',
                  'follows',
                  'followed by'));

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_base_mc1 AS
SELECT mc1.*
FROM movie_companies AS mc1;

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_base_mc2 AS
SELECT mc2.*
FROM movie_companies AS mc2;

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_base_mi_idx1 AS
SELECT mi_idx1.*
FROM movie_info_idx AS mi_idx1;

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_base_mi_idx2 AS
SELECT mi_idx2.*
FROM movie_info_idx AS mi_idx2
WHERE (mi_idx2.info < '3.5');

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_base_ml AS
SELECT ml.*
FROM movie_link AS ml;

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_base_t1 AS
SELECT t1.*
FROM title AS t1;

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_base_t2 AS
SELECT t2.*
FROM title AS t2
WHERE (t2.production_year BETWEEN 2000 AND 2010);

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_up_kt2 AS
SELECT kt2.*
FROM ya_33c_rewriteYa0_base_kt2 AS kt2;

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_up_t2 AS
SELECT t2.*
FROM ya_33c_rewriteYa0_base_t2 AS t2
WHERE EXISTS (SELECT 1 FROM ya_33c_rewriteYa0_up_kt2 AS kt2 WHERE (kt2.id = t2.kind_id));

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_up_lt AS
SELECT lt.*
FROM ya_33c_rewriteYa0_base_lt AS lt;

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_up_cn2 AS
SELECT cn2.*
FROM ya_33c_rewriteYa0_base_cn2 AS cn2;

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_up_mc2 AS
SELECT mc2.*
FROM ya_33c_rewriteYa0_base_mc2 AS mc2
WHERE EXISTS (SELECT 1 FROM ya_33c_rewriteYa0_up_cn2 AS cn2 WHERE (cn2.id = mc2.company_id));

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_up_it2 AS
SELECT it2.*
FROM ya_33c_rewriteYa0_base_it2 AS it2;

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_up_mi_idx2 AS
SELECT mi_idx2.*
FROM ya_33c_rewriteYa0_base_mi_idx2 AS mi_idx2
WHERE EXISTS (SELECT 1 FROM ya_33c_rewriteYa0_up_it2 AS it2 WHERE (it2.id = mi_idx2.info_type_id));

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_up_ml AS
SELECT ml.*
FROM ya_33c_rewriteYa0_base_ml AS ml
WHERE EXISTS (SELECT 1 FROM ya_33c_rewriteYa0_up_t2 AS t2 WHERE (t2.id = ml.linked_movie_id))
  AND EXISTS (SELECT 1 FROM ya_33c_rewriteYa0_up_lt AS lt WHERE (lt.id = ml.link_type_id))
  AND EXISTS (SELECT 1 FROM ya_33c_rewriteYa0_up_mc2 AS mc2 WHERE (ml.linked_movie_id = mc2.movie_id))
  AND EXISTS (SELECT 1 FROM ya_33c_rewriteYa0_up_mi_idx2 AS mi_idx2 WHERE (ml.linked_movie_id = mi_idx2.movie_id));

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_up_kt1 AS
SELECT kt1.*
FROM ya_33c_rewriteYa0_base_kt1 AS kt1;

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_up_t1 AS
SELECT t1.*
FROM ya_33c_rewriteYa0_base_t1 AS t1
WHERE EXISTS (SELECT 1 FROM ya_33c_rewriteYa0_up_kt1 AS kt1 WHERE (kt1.id = t1.kind_id));

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_up_it1 AS
SELECT it1.*
FROM ya_33c_rewriteYa0_base_it1 AS it1;

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_up_mi_idx1 AS
SELECT mi_idx1.*
FROM ya_33c_rewriteYa0_base_mi_idx1 AS mi_idx1
WHERE EXISTS (SELECT 1 FROM ya_33c_rewriteYa0_up_it1 AS it1 WHERE (it1.id = mi_idx1.info_type_id));

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_up_mc1 AS
SELECT mc1.*
FROM ya_33c_rewriteYa0_base_mc1 AS mc1
WHERE EXISTS (SELECT 1 FROM ya_33c_rewriteYa0_up_ml AS ml WHERE (ml.movie_id = mc1.movie_id))
  AND EXISTS (SELECT 1 FROM ya_33c_rewriteYa0_up_t1 AS t1 WHERE (t1.id = mc1.movie_id))
  AND EXISTS (SELECT 1 FROM ya_33c_rewriteYa0_up_mi_idx1 AS mi_idx1 WHERE (mi_idx1.movie_id = mc1.movie_id));

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_up_cn1 AS
SELECT cn1.*
FROM ya_33c_rewriteYa0_base_cn1 AS cn1
WHERE EXISTS (SELECT 1 FROM ya_33c_rewriteYa0_up_mc1 AS mc1 WHERE (cn1.id = mc1.company_id));

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_down_cn1 AS
SELECT cn1.*
FROM ya_33c_rewriteYa0_up_cn1 AS cn1;

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_down_mc1 AS
SELECT mc1.*
FROM ya_33c_rewriteYa0_up_mc1 AS mc1
WHERE EXISTS (SELECT 1 FROM ya_33c_rewriteYa0_down_cn1 AS cn1 WHERE (cn1.id = mc1.company_id));

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_down_ml AS
SELECT ml.*
FROM ya_33c_rewriteYa0_up_ml AS ml
WHERE EXISTS (SELECT 1 FROM ya_33c_rewriteYa0_down_mc1 AS mc1 WHERE (ml.movie_id = mc1.movie_id));

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_down_t1 AS
SELECT t1.*
FROM ya_33c_rewriteYa0_up_t1 AS t1
WHERE EXISTS (SELECT 1 FROM ya_33c_rewriteYa0_down_mc1 AS mc1 WHERE (t1.id = mc1.movie_id));

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_down_mi_idx1 AS
SELECT mi_idx1.*
FROM ya_33c_rewriteYa0_up_mi_idx1 AS mi_idx1
WHERE EXISTS (SELECT 1 FROM ya_33c_rewriteYa0_down_mc1 AS mc1 WHERE (mi_idx1.movie_id = mc1.movie_id));

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_down_t2 AS
SELECT t2.*
FROM ya_33c_rewriteYa0_up_t2 AS t2
WHERE EXISTS (SELECT 1 FROM ya_33c_rewriteYa0_down_ml AS ml WHERE (t2.id = ml.linked_movie_id));

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_down_lt AS
SELECT lt.*
FROM ya_33c_rewriteYa0_up_lt AS lt
WHERE EXISTS (SELECT 1 FROM ya_33c_rewriteYa0_down_ml AS ml WHERE (lt.id = ml.link_type_id));

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_down_mc2 AS
SELECT mc2.*
FROM ya_33c_rewriteYa0_up_mc2 AS mc2
WHERE EXISTS (SELECT 1 FROM ya_33c_rewriteYa0_down_ml AS ml WHERE (ml.linked_movie_id = mc2.movie_id));

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_down_mi_idx2 AS
SELECT mi_idx2.*
FROM ya_33c_rewriteYa0_up_mi_idx2 AS mi_idx2
WHERE EXISTS (SELECT 1 FROM ya_33c_rewriteYa0_down_ml AS ml WHERE (ml.linked_movie_id = mi_idx2.movie_id));

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_down_kt1 AS
SELECT kt1.*
FROM ya_33c_rewriteYa0_up_kt1 AS kt1
WHERE EXISTS (SELECT 1 FROM ya_33c_rewriteYa0_down_t1 AS t1 WHERE (kt1.id = t1.kind_id));

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_down_it1 AS
SELECT it1.*
FROM ya_33c_rewriteYa0_up_it1 AS it1
WHERE EXISTS (SELECT 1 FROM ya_33c_rewriteYa0_down_mi_idx1 AS mi_idx1 WHERE (it1.id = mi_idx1.info_type_id));

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_down_kt2 AS
SELECT kt2.*
FROM ya_33c_rewriteYa0_up_kt2 AS kt2
WHERE EXISTS (SELECT 1 FROM ya_33c_rewriteYa0_down_t2 AS t2 WHERE (kt2.id = t2.kind_id));

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_down_cn2 AS
SELECT cn2.*
FROM ya_33c_rewriteYa0_up_cn2 AS cn2
WHERE EXISTS (SELECT 1 FROM ya_33c_rewriteYa0_down_mc2 AS mc2 WHERE (cn2.id = mc2.company_id));

CREATE OR REPLACE TEMP VIEW ya_33c_rewriteYa0_down_it2 AS
SELECT it2.*
FROM ya_33c_rewriteYa0_up_it2 AS it2
WHERE EXISTS (SELECT 1 FROM ya_33c_rewriteYa0_down_mi_idx2 AS mi_idx2 WHERE (it2.id = mi_idx2.info_type_id));

SELECT cn1.name,
       cn2.name,
       mi_idx1.info,
       mi_idx2.info,
       t1.title,
       t2.title,
       SUM(1) AS record_count
FROM ya_33c_rewriteYa0_down_cn1 AS cn1,
     ya_33c_rewriteYa0_down_cn2 AS cn2,
     ya_33c_rewriteYa0_down_it1 AS it1,
     ya_33c_rewriteYa0_down_it2 AS it2,
     ya_33c_rewriteYa0_down_kt1 AS kt1,
     ya_33c_rewriteYa0_down_kt2 AS kt2,
     ya_33c_rewriteYa0_down_lt AS lt,
     ya_33c_rewriteYa0_down_mc1 AS mc1,
     ya_33c_rewriteYa0_down_mc2 AS mc2,
     ya_33c_rewriteYa0_down_mi_idx1 AS mi_idx1,
     ya_33c_rewriteYa0_down_mi_idx2 AS mi_idx2,
     ya_33c_rewriteYa0_down_ml AS ml,
     ya_33c_rewriteYa0_down_t1 AS t1,
     ya_33c_rewriteYa0_down_t2 AS t2
WHERE (cn1.country_code != '[us]')
  AND (it1.info = 'rating')
  AND (it2.info = 'rating')
  AND (kt1.kind IN ('tv series',
                   'episode'))
  AND (kt2.kind IN ('tv series',
                   'episode'))
  AND (lt.link IN ('sequel',
                  'follows',
                  'followed by'))
  AND (mi_idx2.info < '3.5')
  AND (t2.production_year BETWEEN 2000 AND 2010)
  AND (lt.id = ml.link_type_id)
  AND (t1.id = ml.movie_id)
  AND (t2.id = ml.linked_movie_id)
  AND (it1.id = mi_idx1.info_type_id)
  AND (t1.id = mi_idx1.movie_id)
  AND (kt1.id = t1.kind_id)
  AND (cn1.id = mc1.company_id)
  AND (t1.id = mc1.movie_id)
  AND (ml.movie_id = mi_idx1.movie_id)
  AND (ml.movie_id = mc1.movie_id)
  AND (mi_idx1.movie_id = mc1.movie_id)
  AND (it2.id = mi_idx2.info_type_id)
  AND (t2.id = mi_idx2.movie_id)
  AND (kt2.id = t2.kind_id)
  AND (cn2.id = mc2.company_id)
  AND (t2.id = mc2.movie_id)
  AND (ml.linked_movie_id = mi_idx2.movie_id)
  AND (ml.linked_movie_id = mc2.movie_id)
  AND (mi_idx2.movie_id = mc2.movie_id)
GROUP BY cn1.name, cn2.name, mi_idx1.info, mi_idx2.info, t1.title, t2.title;
