-- DuckDB SUM(1) Yannakakis-style two-pass reducer generated from job_agg/1a.sql.

-- Source variant: locally generated fallback (Quorion has no rewriteYa for JOB 1a)

CREATE OR REPLACE TEMP VIEW ya_1a_rewriteYa0_base_ct AS
SELECT ct.*
FROM company_type AS ct
WHERE (ct.kind = 'production companies');

CREATE OR REPLACE TEMP VIEW ya_1a_rewriteYa0_base_it AS
SELECT it.*
FROM info_type AS it
WHERE (it.info = 'top 250 rank');

CREATE OR REPLACE TEMP VIEW ya_1a_rewriteYa0_base_mc AS
SELECT mc.*
FROM movie_companies AS mc
WHERE (mc.note NOT LIKE '%(as Metro-Goldwyn-Mayer Pictures)%')
  AND ((mc.note LIKE '%(co-production)%'
       OR mc.note LIKE '%(presents)%'));

CREATE OR REPLACE TEMP VIEW ya_1a_rewriteYa0_base_mi_idx AS
SELECT mi_idx.*
FROM movie_info_idx AS mi_idx;

CREATE OR REPLACE TEMP VIEW ya_1a_rewriteYa0_base_t AS
SELECT t.*
FROM title AS t;

CREATE OR REPLACE TEMP VIEW ya_1a_rewriteYa0_up_t AS
SELECT t.*
FROM ya_1a_rewriteYa0_base_t AS t;

CREATE OR REPLACE TEMP VIEW ya_1a_rewriteYa0_up_it AS
SELECT it.*
FROM ya_1a_rewriteYa0_base_it AS it;

CREATE OR REPLACE TEMP VIEW ya_1a_rewriteYa0_up_mi_idx AS
SELECT mi_idx.*
FROM ya_1a_rewriteYa0_base_mi_idx AS mi_idx
WHERE EXISTS (SELECT 1 FROM ya_1a_rewriteYa0_up_it AS it WHERE (it.id = mi_idx.info_type_id));

CREATE OR REPLACE TEMP VIEW ya_1a_rewriteYa0_up_mc AS
SELECT mc.*
FROM ya_1a_rewriteYa0_base_mc AS mc
WHERE EXISTS (SELECT 1 FROM ya_1a_rewriteYa0_up_t AS t WHERE (t.id = mc.movie_id))
  AND EXISTS (SELECT 1 FROM ya_1a_rewriteYa0_up_mi_idx AS mi_idx WHERE (mc.movie_id = mi_idx.movie_id));

CREATE OR REPLACE TEMP VIEW ya_1a_rewriteYa0_up_ct AS
SELECT ct.*
FROM ya_1a_rewriteYa0_base_ct AS ct
WHERE EXISTS (SELECT 1 FROM ya_1a_rewriteYa0_up_mc AS mc WHERE (ct.id = mc.company_type_id));

CREATE OR REPLACE TEMP VIEW ya_1a_rewriteYa0_down_ct AS
SELECT ct.*
FROM ya_1a_rewriteYa0_up_ct AS ct;

CREATE OR REPLACE TEMP VIEW ya_1a_rewriteYa0_down_mc AS
SELECT mc.*
FROM ya_1a_rewriteYa0_up_mc AS mc
WHERE EXISTS (SELECT 1 FROM ya_1a_rewriteYa0_down_ct AS ct WHERE (ct.id = mc.company_type_id));

CREATE OR REPLACE TEMP VIEW ya_1a_rewriteYa0_down_t AS
SELECT t.*
FROM ya_1a_rewriteYa0_up_t AS t
WHERE EXISTS (SELECT 1 FROM ya_1a_rewriteYa0_down_mc AS mc WHERE (t.id = mc.movie_id));

CREATE OR REPLACE TEMP VIEW ya_1a_rewriteYa0_down_mi_idx AS
SELECT mi_idx.*
FROM ya_1a_rewriteYa0_up_mi_idx AS mi_idx
WHERE EXISTS (SELECT 1 FROM ya_1a_rewriteYa0_down_mc AS mc WHERE (mc.movie_id = mi_idx.movie_id));

CREATE OR REPLACE TEMP VIEW ya_1a_rewriteYa0_down_it AS
SELECT it.*
FROM ya_1a_rewriteYa0_up_it AS it
WHERE EXISTS (SELECT 1 FROM ya_1a_rewriteYa0_down_mi_idx AS mi_idx WHERE (it.id = mi_idx.info_type_id));

CREATE OR REPLACE TEMP VIEW ya_1a_rewriteYa0_r3_base_ct AS
SELECT ct.id AS ct__id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_1a_rewriteYa0_down_ct AS ct
GROUP BY ct.id;

CREATE OR REPLACE TEMP VIEW ya_1a_rewriteYa0_r3_base_it AS
SELECT it.id AS it__id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_1a_rewriteYa0_down_it AS it
GROUP BY it.id;

CREATE OR REPLACE TEMP VIEW ya_1a_rewriteYa0_r3_base_mc AS
SELECT mc.company_type_id AS mc__company_type_id,
       mc.movie_id AS mc__movie_id,
       mc.note AS mc__note,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_1a_rewriteYa0_down_mc AS mc
GROUP BY mc.company_type_id, mc.movie_id, mc.note;

CREATE OR REPLACE TEMP VIEW ya_1a_rewriteYa0_r3_base_mi_idx AS
SELECT mi_idx.movie_id AS mi_idx__movie_id,
       mi_idx.info_type_id AS mi_idx__info_type_id,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_1a_rewriteYa0_down_mi_idx AS mi_idx
GROUP BY mi_idx.movie_id, mi_idx.info_type_id;

CREATE OR REPLACE TEMP VIEW ya_1a_rewriteYa0_r3_base_t AS
SELECT t.id AS t__id,
       t.title AS t__title,
       t.production_year AS t__production_year,
       CAST(COUNT(*) AS HUGEINT) AS annot
FROM ya_1a_rewriteYa0_down_t AS t
GROUP BY t.id, t.title, t.production_year;

CREATE OR REPLACE TEMP VIEW ya_1a_rewriteYa0_r3_join_1 AS
SELECT round3_left.mc__note AS mc__note,
       round3_right.t__title AS t__title,
       round3_right.t__production_year AS t__production_year,
       round3_left.mc__company_type_id AS mc__company_type_id,
       round3_right.t__id AS t__id,
       round3_left.mc__movie_id AS mc__movie_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_1a_rewriteYa0_r3_base_mc AS round3_left
JOIN ya_1a_rewriteYa0_r3_base_t AS round3_right
  ON (round3_right.t__id = round3_left.mc__movie_id)
GROUP BY round3_left.mc__note, round3_right.t__title, round3_right.t__production_year, round3_left.mc__company_type_id, round3_right.t__id, round3_left.mc__movie_id;

CREATE OR REPLACE TEMP VIEW ya_1a_rewriteYa0_r3_join_2 AS
SELECT round3_left.mi_idx__movie_id AS mi_idx__movie_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_1a_rewriteYa0_r3_base_mi_idx AS round3_left
JOIN ya_1a_rewriteYa0_r3_base_it AS round3_right
  ON (round3_right.it__id = round3_left.mi_idx__info_type_id)
GROUP BY round3_left.mi_idx__movie_id;

CREATE OR REPLACE TEMP VIEW ya_1a_rewriteYa0_r3_join_3 AS
SELECT round3_left.mc__note AS mc__note,
       round3_left.t__title AS t__title,
       round3_left.t__production_year AS t__production_year,
       round3_left.mc__company_type_id AS mc__company_type_id,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_1a_rewriteYa0_r3_join_1 AS round3_left
JOIN ya_1a_rewriteYa0_r3_join_2 AS round3_right
  ON (round3_left.t__id = round3_right.mi_idx__movie_id)
 AND (round3_left.mc__movie_id = round3_right.mi_idx__movie_id)
GROUP BY round3_left.mc__note, round3_left.t__title, round3_left.t__production_year, round3_left.mc__company_type_id;

CREATE OR REPLACE TEMP VIEW ya_1a_rewriteYa0_r3_join_4 AS
SELECT round3_right.mc__note AS mc__note,
       round3_right.t__title AS t__title,
       round3_right.t__production_year AS t__production_year,
       SUM(round3_left.annot * round3_right.annot) AS annot
FROM ya_1a_rewriteYa0_r3_base_ct AS round3_left
JOIN ya_1a_rewriteYa0_r3_join_3 AS round3_right
  ON (round3_left.ct__id = round3_right.mc__company_type_id)
GROUP BY round3_right.mc__note, round3_right.t__title, round3_right.t__production_year;

SELECT round3_result.mc__note AS note,
       round3_result.t__title AS title,
       round3_result.t__production_year AS production_year,
       round3_result.annot AS record_count
FROM ya_1a_rewriteYa0_r3_join_4 AS round3_result;
