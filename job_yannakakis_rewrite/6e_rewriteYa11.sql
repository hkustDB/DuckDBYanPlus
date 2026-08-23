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

CREATE OR REPLACE TEMP VIEW ya_6e_rewriteYa11_r3_base_ci AS
SELECT ci.movie_id AS ci__movie_id,
       ci.person_id AS ci__person_id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_6e_rewriteYa11_down_ci AS ci
GROUP BY ci.movie_id, ci.person_id;

CREATE OR REPLACE TEMP VIEW ya_6e_rewriteYa11_r3_base_k AS
SELECT k.id AS k__id,
       k.keyword AS k__keyword,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_6e_rewriteYa11_down_k AS k
GROUP BY k.id, k.keyword;

CREATE OR REPLACE TEMP VIEW ya_6e_rewriteYa11_r3_base_mk AS
SELECT mk.keyword_id AS mk__keyword_id,
       mk.movie_id AS mk__movie_id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_6e_rewriteYa11_down_mk AS mk
GROUP BY mk.keyword_id, mk.movie_id;

CREATE OR REPLACE TEMP VIEW ya_6e_rewriteYa11_r3_base_n AS
SELECT n.id AS n__id,
       n.name AS n__name,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_6e_rewriteYa11_down_n AS n
GROUP BY n.id, n.name;

CREATE OR REPLACE TEMP VIEW ya_6e_rewriteYa11_r3_base_t AS
SELECT t.id AS t__id,
       t.title AS t__title,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_6e_rewriteYa11_down_t AS t
GROUP BY t.id, t.title;

CREATE OR REPLACE TEMP VIEW ya_6e_rewriteYa11_r3_join_1 AS
SELECT round3_right.t__title AS t__title,
       round3_left.mk__keyword_id AS mk__keyword_id,
       round3_right.t__id AS t__id,
       round3_left.mk__movie_id AS mk__movie_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_6e_rewriteYa11_r3_base_mk AS round3_left
JOIN ya_6e_rewriteYa11_r3_base_t AS round3_right
  ON (round3_right.t__id = round3_left.mk__movie_id)
GROUP BY round3_right.t__title, round3_left.mk__keyword_id, round3_right.t__id, round3_left.mk__movie_id;

CREATE OR REPLACE TEMP VIEW ya_6e_rewriteYa11_r3_join_2 AS
SELECT round3_right.n__name AS n__name,
       round3_left.ci__movie_id AS ci__movie_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_6e_rewriteYa11_r3_base_ci AS round3_left
JOIN ya_6e_rewriteYa11_r3_base_n AS round3_right
  ON (round3_right.n__id = round3_left.ci__person_id)
GROUP BY round3_right.n__name, round3_left.ci__movie_id;

CREATE OR REPLACE TEMP VIEW ya_6e_rewriteYa11_r3_join_3 AS
SELECT round3_right.n__name AS n__name,
       round3_left.t__title AS t__title,
       round3_left.mk__keyword_id AS mk__keyword_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_6e_rewriteYa11_r3_join_1 AS round3_left
JOIN ya_6e_rewriteYa11_r3_join_2 AS round3_right
  ON (round3_left.t__id = round3_right.ci__movie_id)
 AND (round3_right.ci__movie_id = round3_left.mk__movie_id)
GROUP BY round3_right.n__name, round3_left.t__title, round3_left.mk__keyword_id;

CREATE OR REPLACE TEMP VIEW ya_6e_rewriteYa11_r3_join_4 AS
SELECT round3_left.k__keyword AS k__keyword,
       round3_right.n__name AS n__name,
       round3_right.t__title AS t__title,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_6e_rewriteYa11_r3_base_k AS round3_left
JOIN ya_6e_rewriteYa11_r3_join_3 AS round3_right
  ON (round3_left.k__id = round3_right.mk__keyword_id)
GROUP BY round3_left.k__keyword, round3_right.n__name, round3_right.t__title;

SELECT round3_result.k__keyword AS keyword,
       round3_result.n__name AS name,
       round3_result.t__title AS title,
       round3_result.annot AS record_count
FROM ya_6e_rewriteYa11_r3_join_4 AS round3_result;
