create or replace TEMP view semiJoinView_q1_1200_0_g2 as select src as v2, dst as v4 from Graph AS g2 where (src) in (select (dst) from Graph AS g1 where (src < 1200));
create or replace TEMP view semiJoinView_q1_1200_0_g3 as select src as v4, dst as v6 from Graph AS g3 where (src) in (select (v4) from semiJoinView_q1_1200_0_g2);
create or replace TEMP view semiEnum_q1_1200_0_g23 as select v4, v6, v2 from semiJoinView_q1_1200_0_g3 join semiJoinView_q1_1200_0_g2 using(v4);
create or replace TEMP view semiEnum_q1_1200_0_all as select v6, v2, src as v1, v4 from semiEnum_q1_1200_0_g23, Graph as g1 where g1.dst=semiEnum_q1_1200_0_g23.v2 and (g1.src < 1200);
select v1, v2, v4, v6 from semiEnum_q1_1200_0_all;
