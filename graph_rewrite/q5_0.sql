create or replace TEMP view semiJoinView2178578127733568768 as select src as v4, dst as v6 from Graph AS g3 where (dst) in (select (src) from Graph AS g4);
create or replace TEMP view semiJoinView8614203996591400560 as select src as v2, dst as v4 from Graph AS g2 where (dst) in (select (v4) from semiJoinView2178578127733568768);
create or replace TEMP view g2Aux2 as select v2 from semiJoinView8614203996591400560;
create or replace TEMP view semiJoinView4047820905534560320 as select distinct v2 from g2Aux2 where (v2) in (select (dst) from Graph AS g1);
select distinct v2 from semiJoinView4047820905534560320;
