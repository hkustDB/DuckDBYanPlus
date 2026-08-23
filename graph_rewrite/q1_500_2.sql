create or replace TEMP view semiJoinView_q1_500_2_g2_up as select src as v2, dst as v4 from Graph AS g2 where (src) in (select (dst) from Graph AS g1 where (src < 500));
create or replace TEMP view semiJoinView_q1_500_2_g2_down as select v2, v4 from semiJoinView_q1_500_2_g2_up where (v4) in (select (src) from Graph AS g3);
create or replace TEMP view semiEnum_q1_500_2_g23 as select v2, dst as v6, v4 from semiJoinView_q1_500_2_g2_down, Graph as g3 where g3.src=semiJoinView_q1_500_2_g2_down.v4;
create or replace TEMP view semiEnum_q1_500_2_all as select v2, src as v1, v6, v4 from semiEnum_q1_500_2_g23, Graph as g1 where g1.dst=semiEnum_q1_500_2_g23.v2 and (g1.src < 500);
select v1, v2, v4, v6 from semiEnum_q1_500_2_all;
