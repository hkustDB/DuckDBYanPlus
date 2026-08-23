-- DuckDB SUM(1) Yannakakis-style two-pass reducer generated from job_agg/16c.sql.

-- Source variant: query/job_duckdb/16c/rewriteYa47.sql

CREATE OR REPLACE TEMP VIEW ya_16c_rewriteYa47_base_an AS
SELECT an.*
FROM aka_name AS an;

CREATE OR REPLACE TEMP VIEW ya_16c_rewriteYa47_base_ci AS
SELECT ci.*
FROM cast_info AS ci;

CREATE OR REPLACE TEMP VIEW ya_16c_rewriteYa47_base_cn AS
SELECT cn.*
FROM company_name AS cn
WHERE (cn.country_code ='[us]');

CREATE OR REPLACE TEMP VIEW ya_16c_rewriteYa47_base_k AS
SELECT k.*
FROM keyword AS k
WHERE (k.keyword ='character-name-in-title');

CREATE OR REPLACE TEMP VIEW ya_16c_rewriteYa47_base_mc AS
SELECT mc.*
FROM movie_companies AS mc;

CREATE OR REPLACE TEMP VIEW ya_16c_rewriteYa47_base_mk AS
SELECT mk.*
FROM movie_keyword AS mk;

CREATE OR REPLACE TEMP VIEW ya_16c_rewriteYa47_base_n AS
SELECT n.*
FROM name AS n;

CREATE OR REPLACE TEMP VIEW ya_16c_rewriteYa47_base_t AS
SELECT t.*
FROM title AS t
WHERE (t.episode_nr < 100);

CREATE OR REPLACE TEMP VIEW ya_16c_rewriteYa47_up_n AS
SELECT n.*
FROM ya_16c_rewriteYa47_base_n AS n;

CREATE OR REPLACE TEMP VIEW ya_16c_rewriteYa47_up_an AS
SELECT an.*
FROM ya_16c_rewriteYa47_base_an AS an;

CREATE OR REPLACE TEMP VIEW ya_16c_rewriteYa47_up_ci AS
SELECT ci.*
FROM ya_16c_rewriteYa47_base_ci AS ci
WHERE EXISTS (SELECT 1 FROM ya_16c_rewriteYa47_up_n AS n WHERE (n.id = ci.person_id))
  AND EXISTS (SELECT 1 FROM ya_16c_rewriteYa47_up_an AS an WHERE (an.person_id = ci.person_id));

CREATE OR REPLACE TEMP VIEW ya_16c_rewriteYa47_up_cn AS
SELECT cn.*
FROM ya_16c_rewriteYa47_base_cn AS cn;

CREATE OR REPLACE TEMP VIEW ya_16c_rewriteYa47_up_mc AS
SELECT mc.*
FROM ya_16c_rewriteYa47_base_mc AS mc
WHERE EXISTS (SELECT 1 FROM ya_16c_rewriteYa47_up_cn AS cn WHERE (mc.company_id = cn.id));

CREATE OR REPLACE TEMP VIEW ya_16c_rewriteYa47_up_k AS
SELECT k.*
FROM ya_16c_rewriteYa47_base_k AS k;

CREATE OR REPLACE TEMP VIEW ya_16c_rewriteYa47_up_mk AS
SELECT mk.*
FROM ya_16c_rewriteYa47_base_mk AS mk
WHERE EXISTS (SELECT 1 FROM ya_16c_rewriteYa47_up_k AS k WHERE (mk.keyword_id = k.id));

CREATE OR REPLACE TEMP VIEW ya_16c_rewriteYa47_up_t AS
SELECT t.*
FROM ya_16c_rewriteYa47_base_t AS t
WHERE EXISTS (SELECT 1 FROM ya_16c_rewriteYa47_up_ci AS ci WHERE (ci.movie_id = t.id))
  AND EXISTS (SELECT 1 FROM ya_16c_rewriteYa47_up_mc AS mc WHERE (t.id = mc.movie_id))
  AND EXISTS (SELECT 1 FROM ya_16c_rewriteYa47_up_mk AS mk WHERE (t.id = mk.movie_id));

CREATE OR REPLACE TEMP VIEW ya_16c_rewriteYa47_down_t AS
SELECT t.*
FROM ya_16c_rewriteYa47_up_t AS t;

CREATE OR REPLACE TEMP VIEW ya_16c_rewriteYa47_down_ci AS
SELECT ci.*
FROM ya_16c_rewriteYa47_up_ci AS ci
WHERE EXISTS (SELECT 1 FROM ya_16c_rewriteYa47_down_t AS t WHERE (ci.movie_id = t.id));

CREATE OR REPLACE TEMP VIEW ya_16c_rewriteYa47_down_mc AS
SELECT mc.*
FROM ya_16c_rewriteYa47_up_mc AS mc
WHERE EXISTS (SELECT 1 FROM ya_16c_rewriteYa47_down_t AS t WHERE (t.id = mc.movie_id));

CREATE OR REPLACE TEMP VIEW ya_16c_rewriteYa47_down_mk AS
SELECT mk.*
FROM ya_16c_rewriteYa47_up_mk AS mk
WHERE EXISTS (SELECT 1 FROM ya_16c_rewriteYa47_down_t AS t WHERE (t.id = mk.movie_id));

CREATE OR REPLACE TEMP VIEW ya_16c_rewriteYa47_down_n AS
SELECT n.*
FROM ya_16c_rewriteYa47_up_n AS n
WHERE EXISTS (SELECT 1 FROM ya_16c_rewriteYa47_down_ci AS ci WHERE (n.id = ci.person_id));

CREATE OR REPLACE TEMP VIEW ya_16c_rewriteYa47_down_an AS
SELECT an.*
FROM ya_16c_rewriteYa47_up_an AS an
WHERE EXISTS (SELECT 1 FROM ya_16c_rewriteYa47_down_ci AS ci WHERE (an.person_id = ci.person_id));

CREATE OR REPLACE TEMP VIEW ya_16c_rewriteYa47_down_cn AS
SELECT cn.*
FROM ya_16c_rewriteYa47_up_cn AS cn
WHERE EXISTS (SELECT 1 FROM ya_16c_rewriteYa47_down_mc AS mc WHERE (mc.company_id = cn.id));

CREATE OR REPLACE TEMP VIEW ya_16c_rewriteYa47_down_k AS
SELECT k.*
FROM ya_16c_rewriteYa47_up_k AS k
WHERE EXISTS (SELECT 1 FROM ya_16c_rewriteYa47_down_mk AS mk WHERE (mk.keyword_id = k.id));

CREATE OR REPLACE TEMP VIEW ya_16c_rewriteYa47_r3_base_an AS
SELECT an.person_id AS an__person_id,
       an.name AS an__name,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_16c_rewriteYa47_down_an AS an
GROUP BY an.person_id, an.name;

CREATE OR REPLACE TEMP VIEW ya_16c_rewriteYa47_r3_base_ci AS
SELECT ci.person_id AS ci__person_id,
       ci.movie_id AS ci__movie_id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_16c_rewriteYa47_down_ci AS ci
GROUP BY ci.person_id, ci.movie_id;

CREATE OR REPLACE TEMP VIEW ya_16c_rewriteYa47_r3_base_cn AS
SELECT cn.id AS cn__id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_16c_rewriteYa47_down_cn AS cn
GROUP BY cn.id;

CREATE OR REPLACE TEMP VIEW ya_16c_rewriteYa47_r3_base_k AS
SELECT k.id AS k__id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_16c_rewriteYa47_down_k AS k
GROUP BY k.id;

CREATE OR REPLACE TEMP VIEW ya_16c_rewriteYa47_r3_base_mc AS
SELECT mc.movie_id AS mc__movie_id,
       mc.company_id AS mc__company_id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_16c_rewriteYa47_down_mc AS mc
GROUP BY mc.movie_id, mc.company_id;

CREATE OR REPLACE TEMP VIEW ya_16c_rewriteYa47_r3_base_mk AS
SELECT mk.movie_id AS mk__movie_id,
       mk.keyword_id AS mk__keyword_id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_16c_rewriteYa47_down_mk AS mk
GROUP BY mk.movie_id, mk.keyword_id;

CREATE OR REPLACE TEMP VIEW ya_16c_rewriteYa47_r3_base_n AS
SELECT n.id AS n__id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_16c_rewriteYa47_down_n AS n
GROUP BY n.id;

CREATE OR REPLACE TEMP VIEW ya_16c_rewriteYa47_r3_base_t AS
SELECT t.id AS t__id,
       t.title AS t__title,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_16c_rewriteYa47_down_t AS t
GROUP BY t.id, t.title;

CREATE OR REPLACE TEMP VIEW ya_16c_rewriteYa47_r3_join_1 AS
SELECT round3_right.n__id AS n__id,
       round3_left.ci__movie_id AS ci__movie_id,
       round3_left.ci__person_id AS ci__person_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_16c_rewriteYa47_r3_base_ci AS round3_left
JOIN ya_16c_rewriteYa47_r3_base_n AS round3_right
  ON (round3_right.n__id = round3_left.ci__person_id)
GROUP BY round3_right.n__id, round3_left.ci__movie_id, round3_left.ci__person_id;

CREATE OR REPLACE TEMP VIEW ya_16c_rewriteYa47_r3_join_2 AS
SELECT round3_right.an__name AS an__name,
       round3_left.ci__movie_id AS ci__movie_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_16c_rewriteYa47_r3_join_1 AS round3_left
JOIN ya_16c_rewriteYa47_r3_base_an AS round3_right
  ON (round3_right.an__person_id = round3_left.n__id)
 AND (round3_right.an__person_id = round3_left.ci__person_id)
GROUP BY round3_right.an__name, round3_left.ci__movie_id;

CREATE OR REPLACE TEMP VIEW ya_16c_rewriteYa47_r3_join_3 AS
SELECT round3_right.an__name AS an__name,
       round3_left.t__title AS t__title,
       round3_left.t__id AS t__id,
       round3_right.ci__movie_id AS ci__movie_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_16c_rewriteYa47_r3_base_t AS round3_left
JOIN ya_16c_rewriteYa47_r3_join_2 AS round3_right
  ON (round3_right.ci__movie_id = round3_left.t__id)
GROUP BY round3_right.an__name, round3_left.t__title, round3_left.t__id, round3_right.ci__movie_id;

CREATE OR REPLACE TEMP VIEW ya_16c_rewriteYa47_r3_join_4 AS
SELECT round3_left.mc__movie_id AS mc__movie_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_16c_rewriteYa47_r3_base_mc AS round3_left
JOIN ya_16c_rewriteYa47_r3_base_cn AS round3_right
  ON (round3_left.mc__company_id = round3_right.cn__id)
GROUP BY round3_left.mc__movie_id;

CREATE OR REPLACE TEMP VIEW ya_16c_rewriteYa47_r3_join_5 AS
SELECT round3_left.an__name AS an__name,
       round3_left.t__title AS t__title,
       round3_left.t__id AS t__id,
       round3_left.ci__movie_id AS ci__movie_id,
       round3_right.mc__movie_id AS mc__movie_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_16c_rewriteYa47_r3_join_3 AS round3_left
JOIN ya_16c_rewriteYa47_r3_join_4 AS round3_right
  ON (round3_left.t__id = round3_right.mc__movie_id)
 AND (round3_left.ci__movie_id = round3_right.mc__movie_id)
GROUP BY round3_left.an__name, round3_left.t__title, round3_left.t__id, round3_left.ci__movie_id, round3_right.mc__movie_id;

CREATE OR REPLACE TEMP VIEW ya_16c_rewriteYa47_r3_join_6 AS
SELECT round3_left.mk__movie_id AS mk__movie_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_16c_rewriteYa47_r3_base_mk AS round3_left
JOIN ya_16c_rewriteYa47_r3_base_k AS round3_right
  ON (round3_left.mk__keyword_id = round3_right.k__id)
GROUP BY round3_left.mk__movie_id;

CREATE OR REPLACE TEMP VIEW ya_16c_rewriteYa47_r3_join_7 AS
SELECT round3_left.an__name AS an__name,
       round3_left.t__title AS t__title,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_16c_rewriteYa47_r3_join_5 AS round3_left
JOIN ya_16c_rewriteYa47_r3_join_6 AS round3_right
  ON (round3_left.t__id = round3_right.mk__movie_id)
 AND (round3_left.ci__movie_id = round3_right.mk__movie_id)
 AND (round3_left.mc__movie_id = round3_right.mk__movie_id)
GROUP BY round3_left.an__name, round3_left.t__title;

SELECT round3_result.an__name AS name,
       round3_result.t__title AS title,
       round3_result.annot AS record_count
FROM ya_16c_rewriteYa47_r3_join_7 AS round3_result;
