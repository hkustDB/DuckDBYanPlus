-- DuckDB SUM(1) Yannakakis-style two-pass reducer generated from job_agg/9a.sql.

-- Source variant: query/job_duckdb/9a/rewriteYa0.sql

CREATE OR REPLACE TEMP VIEW ya_9a_rewriteYa0_base_an AS
SELECT an.*
FROM aka_name AS an;

CREATE OR REPLACE TEMP VIEW ya_9a_rewriteYa0_base_chn AS
SELECT chn.*
FROM char_name AS chn;

CREATE OR REPLACE TEMP VIEW ya_9a_rewriteYa0_base_ci AS
SELECT ci.*
FROM cast_info AS ci
WHERE (ci.note IN ('(voice)',
                  '(voice: Japanese version)',
                  '(voice) (uncredited)',
                  '(voice: English version)'));

CREATE OR REPLACE TEMP VIEW ya_9a_rewriteYa0_base_cn AS
SELECT cn.*
FROM company_name AS cn
WHERE (cn.country_code ='[us]');

CREATE OR REPLACE TEMP VIEW ya_9a_rewriteYa0_base_mc AS
SELECT mc.*
FROM movie_companies AS mc
WHERE (mc.note IS NOT NULL)
  AND ((mc.note LIKE '%(USA)%'
       OR mc.note LIKE '%(worldwide)%'));

CREATE OR REPLACE TEMP VIEW ya_9a_rewriteYa0_base_n AS
SELECT n.*
FROM name AS n
WHERE (n.gender ='f')
  AND (n.name LIKE '%Ang%');

CREATE OR REPLACE TEMP VIEW ya_9a_rewriteYa0_base_rt AS
SELECT rt.*
FROM role_type AS rt
WHERE (rt.role ='actress');

CREATE OR REPLACE TEMP VIEW ya_9a_rewriteYa0_base_t AS
SELECT t.*
FROM title AS t
WHERE (t.production_year BETWEEN 2005 AND 2015);

CREATE OR REPLACE TEMP VIEW ya_9a_rewriteYa0_up_n AS
SELECT n.*
FROM ya_9a_rewriteYa0_base_n AS n;

CREATE OR REPLACE TEMP VIEW ya_9a_rewriteYa0_up_rt AS
SELECT rt.*
FROM ya_9a_rewriteYa0_base_rt AS rt;

CREATE OR REPLACE TEMP VIEW ya_9a_rewriteYa0_up_t AS
SELECT t.*
FROM ya_9a_rewriteYa0_base_t AS t;

CREATE OR REPLACE TEMP VIEW ya_9a_rewriteYa0_up_chn AS
SELECT chn.*
FROM ya_9a_rewriteYa0_base_chn AS chn;

CREATE OR REPLACE TEMP VIEW ya_9a_rewriteYa0_up_cn AS
SELECT cn.*
FROM ya_9a_rewriteYa0_base_cn AS cn;

CREATE OR REPLACE TEMP VIEW ya_9a_rewriteYa0_up_mc AS
SELECT mc.*
FROM ya_9a_rewriteYa0_base_mc AS mc
WHERE EXISTS (SELECT 1 FROM ya_9a_rewriteYa0_up_cn AS cn WHERE (mc.company_id = cn.id));

CREATE OR REPLACE TEMP VIEW ya_9a_rewriteYa0_up_ci AS
SELECT ci.*
FROM ya_9a_rewriteYa0_base_ci AS ci
WHERE EXISTS (SELECT 1 FROM ya_9a_rewriteYa0_up_rt AS rt WHERE (ci.role_id = rt.id))
  AND EXISTS (SELECT 1 FROM ya_9a_rewriteYa0_up_t AS t WHERE (ci.movie_id = t.id))
  AND EXISTS (SELECT 1 FROM ya_9a_rewriteYa0_up_chn AS chn WHERE (chn.id = ci.person_role_id))
  AND EXISTS (SELECT 1 FROM ya_9a_rewriteYa0_up_mc AS mc WHERE (ci.movie_id = mc.movie_id));

CREATE OR REPLACE TEMP VIEW ya_9a_rewriteYa0_up_an AS
SELECT an.*
FROM ya_9a_rewriteYa0_base_an AS an
WHERE EXISTS (SELECT 1 FROM ya_9a_rewriteYa0_up_n AS n WHERE (an.person_id = n.id))
  AND EXISTS (SELECT 1 FROM ya_9a_rewriteYa0_up_ci AS ci WHERE (an.person_id = ci.person_id));

CREATE OR REPLACE TEMP VIEW ya_9a_rewriteYa0_down_an AS
SELECT an.*
FROM ya_9a_rewriteYa0_up_an AS an;

CREATE OR REPLACE TEMP VIEW ya_9a_rewriteYa0_down_n AS
SELECT n.*
FROM ya_9a_rewriteYa0_up_n AS n
WHERE EXISTS (SELECT 1 FROM ya_9a_rewriteYa0_down_an AS an WHERE (an.person_id = n.id));

CREATE OR REPLACE TEMP VIEW ya_9a_rewriteYa0_down_ci AS
SELECT ci.*
FROM ya_9a_rewriteYa0_up_ci AS ci
WHERE EXISTS (SELECT 1 FROM ya_9a_rewriteYa0_down_an AS an WHERE (an.person_id = ci.person_id));

CREATE OR REPLACE TEMP VIEW ya_9a_rewriteYa0_down_rt AS
SELECT rt.*
FROM ya_9a_rewriteYa0_up_rt AS rt
WHERE EXISTS (SELECT 1 FROM ya_9a_rewriteYa0_down_ci AS ci WHERE (ci.role_id = rt.id));

CREATE OR REPLACE TEMP VIEW ya_9a_rewriteYa0_down_t AS
SELECT t.*
FROM ya_9a_rewriteYa0_up_t AS t
WHERE EXISTS (SELECT 1 FROM ya_9a_rewriteYa0_down_ci AS ci WHERE (ci.movie_id = t.id));

CREATE OR REPLACE TEMP VIEW ya_9a_rewriteYa0_down_chn AS
SELECT chn.*
FROM ya_9a_rewriteYa0_up_chn AS chn
WHERE EXISTS (SELECT 1 FROM ya_9a_rewriteYa0_down_ci AS ci WHERE (chn.id = ci.person_role_id));

CREATE OR REPLACE TEMP VIEW ya_9a_rewriteYa0_down_mc AS
SELECT mc.*
FROM ya_9a_rewriteYa0_up_mc AS mc
WHERE EXISTS (SELECT 1 FROM ya_9a_rewriteYa0_down_ci AS ci WHERE (ci.movie_id = mc.movie_id));

CREATE OR REPLACE TEMP VIEW ya_9a_rewriteYa0_down_cn AS
SELECT cn.*
FROM ya_9a_rewriteYa0_up_cn AS cn
WHERE EXISTS (SELECT 1 FROM ya_9a_rewriteYa0_down_mc AS mc WHERE (mc.company_id = cn.id));

CREATE OR REPLACE TEMP VIEW ya_9a_rewriteYa0_r3_base_an AS
SELECT an.person_id AS an__person_id,
       an.name AS an__name,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_9a_rewriteYa0_down_an AS an
GROUP BY an.person_id, an.name;

CREATE OR REPLACE TEMP VIEW ya_9a_rewriteYa0_r3_base_chn AS
SELECT chn.id AS chn__id,
       chn.name AS chn__name,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_9a_rewriteYa0_down_chn AS chn
GROUP BY chn.id, chn.name;

CREATE OR REPLACE TEMP VIEW ya_9a_rewriteYa0_r3_base_ci AS
SELECT ci.movie_id AS ci__movie_id,
       ci.role_id AS ci__role_id,
       ci.person_id AS ci__person_id,
       ci.person_role_id AS ci__person_role_id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_9a_rewriteYa0_down_ci AS ci
GROUP BY ci.movie_id, ci.role_id, ci.person_id, ci.person_role_id;

CREATE OR REPLACE TEMP VIEW ya_9a_rewriteYa0_r3_base_cn AS
SELECT cn.id AS cn__id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_9a_rewriteYa0_down_cn AS cn
GROUP BY cn.id;

CREATE OR REPLACE TEMP VIEW ya_9a_rewriteYa0_r3_base_mc AS
SELECT mc.movie_id AS mc__movie_id,
       mc.company_id AS mc__company_id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_9a_rewriteYa0_down_mc AS mc
GROUP BY mc.movie_id, mc.company_id;

CREATE OR REPLACE TEMP VIEW ya_9a_rewriteYa0_r3_base_n AS
SELECT n.id AS n__id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_9a_rewriteYa0_down_n AS n
GROUP BY n.id;

CREATE OR REPLACE TEMP VIEW ya_9a_rewriteYa0_r3_base_rt AS
SELECT rt.id AS rt__id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_9a_rewriteYa0_down_rt AS rt
GROUP BY rt.id;

CREATE OR REPLACE TEMP VIEW ya_9a_rewriteYa0_r3_base_t AS
SELECT t.id AS t__id,
       t.title AS t__title,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_9a_rewriteYa0_down_t AS t
GROUP BY t.id, t.title;

CREATE OR REPLACE TEMP VIEW ya_9a_rewriteYa0_r3_join_1 AS
SELECT round3_left.an__name AS an__name,
       round3_right.n__id AS n__id,
       round3_left.an__person_id AS an__person_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_9a_rewriteYa0_r3_base_an AS round3_left
JOIN ya_9a_rewriteYa0_r3_base_n AS round3_right
  ON (round3_left.an__person_id = round3_right.n__id)
GROUP BY round3_left.an__name, round3_right.n__id, round3_left.an__person_id;

CREATE OR REPLACE TEMP VIEW ya_9a_rewriteYa0_r3_join_2 AS
SELECT round3_left.ci__movie_id AS ci__movie_id,
       round3_left.ci__person_id AS ci__person_id,
       round3_left.ci__person_role_id AS ci__person_role_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_9a_rewriteYa0_r3_base_ci AS round3_left
JOIN ya_9a_rewriteYa0_r3_base_rt AS round3_right
  ON (round3_left.ci__role_id = round3_right.rt__id)
GROUP BY round3_left.ci__movie_id, round3_left.ci__person_id, round3_left.ci__person_role_id;

CREATE OR REPLACE TEMP VIEW ya_9a_rewriteYa0_r3_join_3 AS
SELECT round3_right.t__title AS t__title,
       round3_right.t__id AS t__id,
       round3_left.ci__movie_id AS ci__movie_id,
       round3_left.ci__person_id AS ci__person_id,
       round3_left.ci__person_role_id AS ci__person_role_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_9a_rewriteYa0_r3_join_2 AS round3_left
JOIN ya_9a_rewriteYa0_r3_base_t AS round3_right
  ON (round3_left.ci__movie_id = round3_right.t__id)
GROUP BY round3_right.t__title, round3_right.t__id, round3_left.ci__movie_id, round3_left.ci__person_id, round3_left.ci__person_role_id;

CREATE OR REPLACE TEMP VIEW ya_9a_rewriteYa0_r3_join_4 AS
SELECT round3_right.chn__name AS chn__name,
       round3_left.t__title AS t__title,
       round3_left.t__id AS t__id,
       round3_left.ci__movie_id AS ci__movie_id,
       round3_left.ci__person_id AS ci__person_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_9a_rewriteYa0_r3_join_3 AS round3_left
JOIN ya_9a_rewriteYa0_r3_base_chn AS round3_right
  ON (round3_right.chn__id = round3_left.ci__person_role_id)
GROUP BY round3_right.chn__name, round3_left.t__title, round3_left.t__id, round3_left.ci__movie_id, round3_left.ci__person_id;

CREATE OR REPLACE TEMP VIEW ya_9a_rewriteYa0_r3_join_5 AS
SELECT round3_left.mc__movie_id AS mc__movie_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_9a_rewriteYa0_r3_base_mc AS round3_left
JOIN ya_9a_rewriteYa0_r3_base_cn AS round3_right
  ON (round3_left.mc__company_id = round3_right.cn__id)
GROUP BY round3_left.mc__movie_id;

CREATE OR REPLACE TEMP VIEW ya_9a_rewriteYa0_r3_join_6 AS
SELECT round3_left.chn__name AS chn__name,
       round3_left.t__title AS t__title,
       round3_left.ci__person_id AS ci__person_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_9a_rewriteYa0_r3_join_4 AS round3_left
JOIN ya_9a_rewriteYa0_r3_join_5 AS round3_right
  ON (round3_left.t__id = round3_right.mc__movie_id)
 AND (round3_left.ci__movie_id = round3_right.mc__movie_id)
GROUP BY round3_left.chn__name, round3_left.t__title, round3_left.ci__person_id;

CREATE OR REPLACE TEMP VIEW ya_9a_rewriteYa0_r3_join_7 AS
SELECT round3_left.an__name AS an__name,
       round3_right.chn__name AS chn__name,
       round3_right.t__title AS t__title,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_9a_rewriteYa0_r3_join_1 AS round3_left
JOIN ya_9a_rewriteYa0_r3_join_6 AS round3_right
  ON (round3_left.n__id = round3_right.ci__person_id)
 AND (round3_left.an__person_id = round3_right.ci__person_id)
GROUP BY round3_left.an__name, round3_right.chn__name, round3_right.t__title;

SELECT round3_result.an__name AS name,
       round3_result.chn__name AS name,
       round3_result.t__title AS title,
       round3_result.annot AS record_count
FROM ya_9a_rewriteYa0_r3_join_7 AS round3_result;
