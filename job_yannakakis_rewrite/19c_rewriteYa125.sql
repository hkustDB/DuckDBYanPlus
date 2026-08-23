-- DuckDB SUM(1) Yannakakis-style two-pass reducer generated from job_agg/19c.sql.

-- Source variant: query/job_duckdb/19c/rewriteYa125.sql

CREATE OR REPLACE TEMP VIEW ya_19c_rewriteYa125_base_an AS
SELECT an.*
FROM aka_name AS an;

CREATE OR REPLACE TEMP VIEW ya_19c_rewriteYa125_base_chn AS
SELECT chn.*
FROM char_name AS chn;

CREATE OR REPLACE TEMP VIEW ya_19c_rewriteYa125_base_ci AS
SELECT ci.*
FROM cast_info AS ci
WHERE (ci.note IN ('(voice)',
                  '(voice: Japanese version)',
                  '(voice) (uncredited)',
                  '(voice: English version)'));

CREATE OR REPLACE TEMP VIEW ya_19c_rewriteYa125_base_cn AS
SELECT cn.*
FROM company_name AS cn
WHERE (cn.country_code ='[us]');

CREATE OR REPLACE TEMP VIEW ya_19c_rewriteYa125_base_it AS
SELECT it.*
FROM info_type AS it
WHERE (it.info = 'release dates');

CREATE OR REPLACE TEMP VIEW ya_19c_rewriteYa125_base_mc AS
SELECT mc.*
FROM movie_companies AS mc;

CREATE OR REPLACE TEMP VIEW ya_19c_rewriteYa125_base_mi AS
SELECT mi.*
FROM movie_info AS mi
WHERE (mi.info IS NOT NULL)
  AND ((mi.info LIKE 'Japan:%200%'
       OR mi.info LIKE 'USA:%200%'));

CREATE OR REPLACE TEMP VIEW ya_19c_rewriteYa125_base_n AS
SELECT n.*
FROM name AS n
WHERE (n.gender ='f')
  AND (n.name LIKE '%An%');

CREATE OR REPLACE TEMP VIEW ya_19c_rewriteYa125_base_rt AS
SELECT rt.*
FROM role_type AS rt
WHERE (rt.role ='actress');

CREATE OR REPLACE TEMP VIEW ya_19c_rewriteYa125_base_t AS
SELECT t.*
FROM title AS t
WHERE (t.production_year > 2000);

CREATE OR REPLACE TEMP VIEW ya_19c_rewriteYa125_up_it AS
SELECT it.*
FROM ya_19c_rewriteYa125_base_it AS it;

CREATE OR REPLACE TEMP VIEW ya_19c_rewriteYa125_up_mi AS
SELECT mi.*
FROM ya_19c_rewriteYa125_base_mi AS mi
WHERE EXISTS (SELECT 1 FROM ya_19c_rewriteYa125_up_it AS it WHERE (it.id = mi.info_type_id));

CREATE OR REPLACE TEMP VIEW ya_19c_rewriteYa125_up_t AS
SELECT t.*
FROM ya_19c_rewriteYa125_base_t AS t;

CREATE OR REPLACE TEMP VIEW ya_19c_rewriteYa125_up_rt AS
SELECT rt.*
FROM ya_19c_rewriteYa125_base_rt AS rt;

CREATE OR REPLACE TEMP VIEW ya_19c_rewriteYa125_up_an AS
SELECT an.*
FROM ya_19c_rewriteYa125_base_an AS an;

CREATE OR REPLACE TEMP VIEW ya_19c_rewriteYa125_up_chn AS
SELECT chn.*
FROM ya_19c_rewriteYa125_base_chn AS chn;

CREATE OR REPLACE TEMP VIEW ya_19c_rewriteYa125_up_n AS
SELECT n.*
FROM ya_19c_rewriteYa125_base_n AS n;

CREATE OR REPLACE TEMP VIEW ya_19c_rewriteYa125_up_ci AS
SELECT ci.*
FROM ya_19c_rewriteYa125_base_ci AS ci
WHERE EXISTS (SELECT 1 FROM ya_19c_rewriteYa125_up_rt AS rt WHERE (rt.id = ci.role_id))
  AND EXISTS (SELECT 1 FROM ya_19c_rewriteYa125_up_an AS an WHERE (ci.person_id = an.person_id))
  AND EXISTS (SELECT 1 FROM ya_19c_rewriteYa125_up_chn AS chn WHERE (chn.id = ci.person_role_id))
  AND EXISTS (SELECT 1 FROM ya_19c_rewriteYa125_up_n AS n WHERE (n.id = ci.person_id));

CREATE OR REPLACE TEMP VIEW ya_19c_rewriteYa125_up_cn AS
SELECT cn.*
FROM ya_19c_rewriteYa125_base_cn AS cn;

CREATE OR REPLACE TEMP VIEW ya_19c_rewriteYa125_up_mc AS
SELECT mc.*
FROM ya_19c_rewriteYa125_base_mc AS mc
WHERE EXISTS (SELECT 1 FROM ya_19c_rewriteYa125_up_mi AS mi WHERE (mc.movie_id = mi.movie_id))
  AND EXISTS (SELECT 1 FROM ya_19c_rewriteYa125_up_t AS t WHERE (t.id = mc.movie_id))
  AND EXISTS (SELECT 1 FROM ya_19c_rewriteYa125_up_ci AS ci WHERE (mc.movie_id = ci.movie_id))
  AND EXISTS (SELECT 1 FROM ya_19c_rewriteYa125_up_cn AS cn WHERE (cn.id = mc.company_id));

CREATE OR REPLACE TEMP VIEW ya_19c_rewriteYa125_down_mc AS
SELECT mc.*
FROM ya_19c_rewriteYa125_up_mc AS mc;

CREATE OR REPLACE TEMP VIEW ya_19c_rewriteYa125_down_mi AS
SELECT mi.*
FROM ya_19c_rewriteYa125_up_mi AS mi
WHERE EXISTS (SELECT 1 FROM ya_19c_rewriteYa125_down_mc AS mc WHERE (mc.movie_id = mi.movie_id));

CREATE OR REPLACE TEMP VIEW ya_19c_rewriteYa125_down_t AS
SELECT t.*
FROM ya_19c_rewriteYa125_up_t AS t
WHERE EXISTS (SELECT 1 FROM ya_19c_rewriteYa125_down_mc AS mc WHERE (t.id = mc.movie_id));

CREATE OR REPLACE TEMP VIEW ya_19c_rewriteYa125_down_ci AS
SELECT ci.*
FROM ya_19c_rewriteYa125_up_ci AS ci
WHERE EXISTS (SELECT 1 FROM ya_19c_rewriteYa125_down_mc AS mc WHERE (mc.movie_id = ci.movie_id));

CREATE OR REPLACE TEMP VIEW ya_19c_rewriteYa125_down_cn AS
SELECT cn.*
FROM ya_19c_rewriteYa125_up_cn AS cn
WHERE EXISTS (SELECT 1 FROM ya_19c_rewriteYa125_down_mc AS mc WHERE (cn.id = mc.company_id));

CREATE OR REPLACE TEMP VIEW ya_19c_rewriteYa125_down_it AS
SELECT it.*
FROM ya_19c_rewriteYa125_up_it AS it
WHERE EXISTS (SELECT 1 FROM ya_19c_rewriteYa125_down_mi AS mi WHERE (it.id = mi.info_type_id));

CREATE OR REPLACE TEMP VIEW ya_19c_rewriteYa125_down_rt AS
SELECT rt.*
FROM ya_19c_rewriteYa125_up_rt AS rt
WHERE EXISTS (SELECT 1 FROM ya_19c_rewriteYa125_down_ci AS ci WHERE (rt.id = ci.role_id));

CREATE OR REPLACE TEMP VIEW ya_19c_rewriteYa125_down_an AS
SELECT an.*
FROM ya_19c_rewriteYa125_up_an AS an
WHERE EXISTS (SELECT 1 FROM ya_19c_rewriteYa125_down_ci AS ci WHERE (ci.person_id = an.person_id));

CREATE OR REPLACE TEMP VIEW ya_19c_rewriteYa125_down_chn AS
SELECT chn.*
FROM ya_19c_rewriteYa125_up_chn AS chn
WHERE EXISTS (SELECT 1 FROM ya_19c_rewriteYa125_down_ci AS ci WHERE (chn.id = ci.person_role_id));

CREATE OR REPLACE TEMP VIEW ya_19c_rewriteYa125_down_n AS
SELECT n.*
FROM ya_19c_rewriteYa125_up_n AS n
WHERE EXISTS (SELECT 1 FROM ya_19c_rewriteYa125_down_ci AS ci WHERE (n.id = ci.person_id));

CREATE OR REPLACE TEMP VIEW ya_19c_rewriteYa125_r3_base_an AS
SELECT an.person_id AS an__person_id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_19c_rewriteYa125_down_an AS an
GROUP BY an.person_id;

CREATE OR REPLACE TEMP VIEW ya_19c_rewriteYa125_r3_base_chn AS
SELECT chn.id AS chn__id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_19c_rewriteYa125_down_chn AS chn
GROUP BY chn.id;

CREATE OR REPLACE TEMP VIEW ya_19c_rewriteYa125_r3_base_ci AS
SELECT ci.movie_id AS ci__movie_id,
       ci.person_id AS ci__person_id,
       ci.role_id AS ci__role_id,
       ci.person_role_id AS ci__person_role_id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_19c_rewriteYa125_down_ci AS ci
GROUP BY ci.movie_id, ci.person_id, ci.role_id, ci.person_role_id;

CREATE OR REPLACE TEMP VIEW ya_19c_rewriteYa125_r3_base_cn AS
SELECT cn.id AS cn__id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_19c_rewriteYa125_down_cn AS cn
GROUP BY cn.id;

CREATE OR REPLACE TEMP VIEW ya_19c_rewriteYa125_r3_base_it AS
SELECT it.id AS it__id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_19c_rewriteYa125_down_it AS it
GROUP BY it.id;

CREATE OR REPLACE TEMP VIEW ya_19c_rewriteYa125_r3_base_mc AS
SELECT mc.movie_id AS mc__movie_id,
       mc.company_id AS mc__company_id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_19c_rewriteYa125_down_mc AS mc
GROUP BY mc.movie_id, mc.company_id;

CREATE OR REPLACE TEMP VIEW ya_19c_rewriteYa125_r3_base_mi AS
SELECT mi.movie_id AS mi__movie_id,
       mi.info_type_id AS mi__info_type_id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_19c_rewriteYa125_down_mi AS mi
GROUP BY mi.movie_id, mi.info_type_id;

CREATE OR REPLACE TEMP VIEW ya_19c_rewriteYa125_r3_base_n AS
SELECT n.id AS n__id,
       n.name AS n__name,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_19c_rewriteYa125_down_n AS n
GROUP BY n.id, n.name;

CREATE OR REPLACE TEMP VIEW ya_19c_rewriteYa125_r3_base_rt AS
SELECT rt.id AS rt__id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_19c_rewriteYa125_down_rt AS rt
GROUP BY rt.id;

CREATE OR REPLACE TEMP VIEW ya_19c_rewriteYa125_r3_base_t AS
SELECT t.id AS t__id,
       t.title AS t__title,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_19c_rewriteYa125_down_t AS t
GROUP BY t.id, t.title;

CREATE OR REPLACE TEMP VIEW ya_19c_rewriteYa125_r3_join_1 AS
SELECT round3_left.mi__movie_id AS mi__movie_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_19c_rewriteYa125_r3_base_mi AS round3_left
JOIN ya_19c_rewriteYa125_r3_base_it AS round3_right
  ON (round3_right.it__id = round3_left.mi__info_type_id)
GROUP BY round3_left.mi__movie_id;

CREATE OR REPLACE TEMP VIEW ya_19c_rewriteYa125_r3_join_2 AS
SELECT round3_right.mi__movie_id AS mi__movie_id,
       round3_left.mc__movie_id AS mc__movie_id,
       round3_left.mc__company_id AS mc__company_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_19c_rewriteYa125_r3_base_mc AS round3_left
JOIN ya_19c_rewriteYa125_r3_join_1 AS round3_right
  ON (round3_left.mc__movie_id = round3_right.mi__movie_id)
GROUP BY round3_right.mi__movie_id, round3_left.mc__movie_id, round3_left.mc__company_id;

CREATE OR REPLACE TEMP VIEW ya_19c_rewriteYa125_r3_join_3 AS
SELECT round3_right.t__title AS t__title,
       round3_right.t__id AS t__id,
       round3_left.mc__movie_id AS mc__movie_id,
       round3_left.mi__movie_id AS mi__movie_id,
       round3_left.mc__company_id AS mc__company_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_19c_rewriteYa125_r3_join_2 AS round3_left
JOIN ya_19c_rewriteYa125_r3_base_t AS round3_right
  ON (round3_right.t__id = round3_left.mi__movie_id)
 AND (round3_right.t__id = round3_left.mc__movie_id)
GROUP BY round3_right.t__title, round3_right.t__id, round3_left.mc__movie_id, round3_left.mi__movie_id, round3_left.mc__company_id;

CREATE OR REPLACE TEMP VIEW ya_19c_rewriteYa125_r3_join_4 AS
SELECT round3_left.ci__movie_id AS ci__movie_id,
       round3_left.ci__person_id AS ci__person_id,
       round3_left.ci__person_role_id AS ci__person_role_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_19c_rewriteYa125_r3_base_ci AS round3_left
JOIN ya_19c_rewriteYa125_r3_base_rt AS round3_right
  ON (round3_right.rt__id = round3_left.ci__role_id)
GROUP BY round3_left.ci__movie_id, round3_left.ci__person_id, round3_left.ci__person_role_id;

CREATE OR REPLACE TEMP VIEW ya_19c_rewriteYa125_r3_join_5 AS
SELECT round3_left.ci__movie_id AS ci__movie_id,
       round3_left.ci__person_id AS ci__person_id,
       round3_right.an__person_id AS an__person_id,
       round3_left.ci__person_role_id AS ci__person_role_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_19c_rewriteYa125_r3_join_4 AS round3_left
JOIN ya_19c_rewriteYa125_r3_base_an AS round3_right
  ON (round3_left.ci__person_id = round3_right.an__person_id)
GROUP BY round3_left.ci__movie_id, round3_left.ci__person_id, round3_right.an__person_id, round3_left.ci__person_role_id;

CREATE OR REPLACE TEMP VIEW ya_19c_rewriteYa125_r3_join_6 AS
SELECT round3_left.ci__movie_id AS ci__movie_id,
       round3_left.ci__person_id AS ci__person_id,
       round3_left.an__person_id AS an__person_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_19c_rewriteYa125_r3_join_5 AS round3_left
JOIN ya_19c_rewriteYa125_r3_base_chn AS round3_right
  ON (round3_right.chn__id = round3_left.ci__person_role_id)
GROUP BY round3_left.ci__movie_id, round3_left.ci__person_id, round3_left.an__person_id;

CREATE OR REPLACE TEMP VIEW ya_19c_rewriteYa125_r3_join_7 AS
SELECT round3_right.n__name AS n__name,
       round3_left.ci__movie_id AS ci__movie_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_19c_rewriteYa125_r3_join_6 AS round3_left
JOIN ya_19c_rewriteYa125_r3_base_n AS round3_right
  ON (round3_right.n__id = round3_left.ci__person_id)
 AND (round3_right.n__id = round3_left.an__person_id)
GROUP BY round3_right.n__name, round3_left.ci__movie_id;

CREATE OR REPLACE TEMP VIEW ya_19c_rewriteYa125_r3_join_8 AS
SELECT round3_right.n__name AS n__name,
       round3_left.t__title AS t__title,
       round3_left.mc__company_id AS mc__company_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_19c_rewriteYa125_r3_join_3 AS round3_left
JOIN ya_19c_rewriteYa125_r3_join_7 AS round3_right
  ON (round3_left.t__id = round3_right.ci__movie_id)
 AND (round3_left.mc__movie_id = round3_right.ci__movie_id)
 AND (round3_left.mi__movie_id = round3_right.ci__movie_id)
GROUP BY round3_right.n__name, round3_left.t__title, round3_left.mc__company_id;

CREATE OR REPLACE TEMP VIEW ya_19c_rewriteYa125_r3_join_9 AS
SELECT round3_left.n__name AS n__name,
       round3_left.t__title AS t__title,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_19c_rewriteYa125_r3_join_8 AS round3_left
JOIN ya_19c_rewriteYa125_r3_base_cn AS round3_right
  ON (round3_right.cn__id = round3_left.mc__company_id)
GROUP BY round3_left.n__name, round3_left.t__title;

SELECT round3_result.n__name AS name,
       round3_result.t__title AS title,
       round3_result.annot AS record_count
FROM ya_19c_rewriteYa125_r3_join_9 AS round3_result;
