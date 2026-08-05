-- DuckDB SUM(1) Yannakakis-style two-pass reducer generated from job_agg/11d.sql.

-- Source variant: query/job_duckdb/11d/rewriteYa33.sql

CREATE OR REPLACE TEMP VIEW ya_11d_rewriteYa33_base_cn AS
SELECT cn.*
FROM company_name AS cn
WHERE (cn.country_code !='[pl]');

CREATE OR REPLACE TEMP VIEW ya_11d_rewriteYa33_base_ct AS
SELECT ct.*
FROM company_type AS ct
WHERE (ct.kind != 'production companies')
  AND (ct.kind IS NOT NULL);

CREATE OR REPLACE TEMP VIEW ya_11d_rewriteYa33_base_k AS
SELECT k.*
FROM keyword AS k
WHERE (k.keyword IN ('sequel',
                    'revenge',
                    'based-on-novel'));

CREATE OR REPLACE TEMP VIEW ya_11d_rewriteYa33_base_lt AS
SELECT lt.*
FROM link_type AS lt;

CREATE OR REPLACE TEMP VIEW ya_11d_rewriteYa33_base_mc AS
SELECT mc.*
FROM movie_companies AS mc
WHERE (mc.note IS NOT NULL);

CREATE OR REPLACE TEMP VIEW ya_11d_rewriteYa33_base_mk AS
SELECT mk.*
FROM movie_keyword AS mk;

CREATE OR REPLACE TEMP VIEW ya_11d_rewriteYa33_base_ml AS
SELECT ml.*
FROM movie_link AS ml;

CREATE OR REPLACE TEMP VIEW ya_11d_rewriteYa33_base_t AS
SELECT t.*
FROM title AS t
WHERE (t.production_year > 1950);

CREATE OR REPLACE TEMP VIEW ya_11d_rewriteYa33_up_cn AS
SELECT cn.*
FROM ya_11d_rewriteYa33_base_cn AS cn;

CREATE OR REPLACE TEMP VIEW ya_11d_rewriteYa33_up_k AS
SELECT k.*
FROM ya_11d_rewriteYa33_base_k AS k;

CREATE OR REPLACE TEMP VIEW ya_11d_rewriteYa33_up_mk AS
SELECT mk.*
FROM ya_11d_rewriteYa33_base_mk AS mk
WHERE EXISTS (SELECT 1 FROM ya_11d_rewriteYa33_up_k AS k WHERE (mk.keyword_id = k.id));

CREATE OR REPLACE TEMP VIEW ya_11d_rewriteYa33_up_lt AS
SELECT lt.*
FROM ya_11d_rewriteYa33_base_lt AS lt;

CREATE OR REPLACE TEMP VIEW ya_11d_rewriteYa33_up_ml AS
SELECT ml.*
FROM ya_11d_rewriteYa33_base_ml AS ml
WHERE EXISTS (SELECT 1 FROM ya_11d_rewriteYa33_up_lt AS lt WHERE (lt.id = ml.link_type_id));

CREATE OR REPLACE TEMP VIEW ya_11d_rewriteYa33_up_t AS
SELECT t.*
FROM ya_11d_rewriteYa33_base_t AS t;

CREATE OR REPLACE TEMP VIEW ya_11d_rewriteYa33_up_mc AS
SELECT mc.*
FROM ya_11d_rewriteYa33_base_mc AS mc
WHERE EXISTS (SELECT 1 FROM ya_11d_rewriteYa33_up_cn AS cn WHERE (mc.company_id = cn.id))
  AND EXISTS (SELECT 1 FROM ya_11d_rewriteYa33_up_mk AS mk WHERE (mk.movie_id = mc.movie_id))
  AND EXISTS (SELECT 1 FROM ya_11d_rewriteYa33_up_ml AS ml WHERE (ml.movie_id = mc.movie_id))
  AND EXISTS (SELECT 1 FROM ya_11d_rewriteYa33_up_t AS t WHERE (t.id = mc.movie_id));

CREATE OR REPLACE TEMP VIEW ya_11d_rewriteYa33_up_ct AS
SELECT ct.*
FROM ya_11d_rewriteYa33_base_ct AS ct
WHERE EXISTS (SELECT 1 FROM ya_11d_rewriteYa33_up_mc AS mc WHERE (mc.company_type_id = ct.id));

CREATE OR REPLACE TEMP VIEW ya_11d_rewriteYa33_down_ct AS
SELECT ct.*
FROM ya_11d_rewriteYa33_up_ct AS ct;

CREATE OR REPLACE TEMP VIEW ya_11d_rewriteYa33_down_mc AS
SELECT mc.*
FROM ya_11d_rewriteYa33_up_mc AS mc
WHERE EXISTS (SELECT 1 FROM ya_11d_rewriteYa33_down_ct AS ct WHERE (mc.company_type_id = ct.id));

CREATE OR REPLACE TEMP VIEW ya_11d_rewriteYa33_down_cn AS
SELECT cn.*
FROM ya_11d_rewriteYa33_up_cn AS cn
WHERE EXISTS (SELECT 1 FROM ya_11d_rewriteYa33_down_mc AS mc WHERE (mc.company_id = cn.id));

CREATE OR REPLACE TEMP VIEW ya_11d_rewriteYa33_down_mk AS
SELECT mk.*
FROM ya_11d_rewriteYa33_up_mk AS mk
WHERE EXISTS (SELECT 1 FROM ya_11d_rewriteYa33_down_mc AS mc WHERE (mk.movie_id = mc.movie_id));

CREATE OR REPLACE TEMP VIEW ya_11d_rewriteYa33_down_ml AS
SELECT ml.*
FROM ya_11d_rewriteYa33_up_ml AS ml
WHERE EXISTS (SELECT 1 FROM ya_11d_rewriteYa33_down_mc AS mc WHERE (ml.movie_id = mc.movie_id));

CREATE OR REPLACE TEMP VIEW ya_11d_rewriteYa33_down_t AS
SELECT t.*
FROM ya_11d_rewriteYa33_up_t AS t
WHERE EXISTS (SELECT 1 FROM ya_11d_rewriteYa33_down_mc AS mc WHERE (t.id = mc.movie_id));

CREATE OR REPLACE TEMP VIEW ya_11d_rewriteYa33_down_k AS
SELECT k.*
FROM ya_11d_rewriteYa33_up_k AS k
WHERE EXISTS (SELECT 1 FROM ya_11d_rewriteYa33_down_mk AS mk WHERE (mk.keyword_id = k.id));

CREATE OR REPLACE TEMP VIEW ya_11d_rewriteYa33_down_lt AS
SELECT lt.*
FROM ya_11d_rewriteYa33_up_lt AS lt
WHERE EXISTS (SELECT 1 FROM ya_11d_rewriteYa33_down_ml AS ml WHERE (lt.id = ml.link_type_id));

SELECT cn.name,
       mc.note,
       t.title,
       SUM(1) AS record_count
FROM ya_11d_rewriteYa33_down_cn AS cn,
     ya_11d_rewriteYa33_down_ct AS ct,
     ya_11d_rewriteYa33_down_k AS k,
     ya_11d_rewriteYa33_down_lt AS lt,
     ya_11d_rewriteYa33_down_mc AS mc,
     ya_11d_rewriteYa33_down_mk AS mk,
     ya_11d_rewriteYa33_down_ml AS ml,
     ya_11d_rewriteYa33_down_t AS t
WHERE (cn.country_code !='[pl]')
  AND (ct.kind != 'production companies')
  AND (ct.kind IS NOT NULL)
  AND (k.keyword IN ('sequel',
                    'revenge',
                    'based-on-novel'))
  AND (mc.note IS NOT NULL)
  AND (t.production_year > 1950)
  AND (lt.id = ml.link_type_id)
  AND (ml.movie_id = t.id)
  AND (t.id = mk.movie_id)
  AND (mk.keyword_id = k.id)
  AND (t.id = mc.movie_id)
  AND (mc.company_type_id = ct.id)
  AND (mc.company_id = cn.id)
  AND (ml.movie_id = mk.movie_id)
  AND (ml.movie_id = mc.movie_id)
  AND (mk.movie_id = mc.movie_id)
GROUP BY cn.name, mc.note, t.title;
