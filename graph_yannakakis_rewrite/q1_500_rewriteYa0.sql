-- Locally simulated DuckDB Yannakakis-style two-pass reduction.

-- EXISTS semijoins preserve duplicate base rows; the exact local join is reconstructed last.

CREATE OR REPLACE TEMP VIEW ya_q1_500_rewriteYa0_base_g1 AS
SELECT g1.*
FROM Graph AS g1
WHERE (g1.src < 500);

CREATE OR REPLACE TEMP VIEW ya_q1_500_rewriteYa0_base_g2 AS
SELECT g2.*
FROM Graph AS g2;

CREATE OR REPLACE TEMP VIEW ya_q1_500_rewriteYa0_base_g3 AS
SELECT g3.*
FROM Graph AS g3;

CREATE OR REPLACE TEMP VIEW ya_q1_500_rewriteYa0_up_g3 AS
SELECT g3.*
FROM ya_q1_500_rewriteYa0_base_g3 AS g3;

CREATE OR REPLACE TEMP VIEW ya_q1_500_rewriteYa0_up_g2 AS
SELECT g2.*
FROM ya_q1_500_rewriteYa0_base_g2 AS g2
WHERE EXISTS (SELECT 1 FROM ya_q1_500_rewriteYa0_up_g3 AS g3 WHERE (g2.dst = g3.src));

CREATE OR REPLACE TEMP VIEW ya_q1_500_rewriteYa0_up_g1 AS
SELECT g1.*
FROM ya_q1_500_rewriteYa0_base_g1 AS g1
WHERE EXISTS (SELECT 1 FROM ya_q1_500_rewriteYa0_up_g2 AS g2 WHERE (g1.dst = g2.src));

CREATE OR REPLACE TEMP VIEW ya_q1_500_rewriteYa0_down_g1 AS
SELECT g1.*
FROM ya_q1_500_rewriteYa0_up_g1 AS g1;

CREATE OR REPLACE TEMP VIEW ya_q1_500_rewriteYa0_down_g2 AS
SELECT g2.*
FROM ya_q1_500_rewriteYa0_up_g2 AS g2
WHERE EXISTS (SELECT 1 FROM ya_q1_500_rewriteYa0_down_g1 AS g1 WHERE (g1.dst = g2.src));

CREATE OR REPLACE TEMP VIEW ya_q1_500_rewriteYa0_down_g3 AS
SELECT g3.*
FROM ya_q1_500_rewriteYa0_up_g3 AS g3
WHERE EXISTS (SELECT 1 FROM ya_q1_500_rewriteYa0_down_g2 AS g2 WHERE (g2.dst = g3.src));

SELECT g1.src AS src, g1.dst AS via1, g3.src AS via2, g3.dst AS dst
FROM ya_q1_500_rewriteYa0_down_g1 AS g1,
     ya_q1_500_rewriteYa0_down_g2 AS g2,
     ya_q1_500_rewriteYa0_down_g3 AS g3
WHERE (g1.dst = g2.src)
  AND (g2.dst = g3.src)
  AND (g1.src < 500);
