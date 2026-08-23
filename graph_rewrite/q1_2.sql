create or replace TEMP view semiJoinView2271066312285946723 as select src as v2, dst as v4 from Graph AS g2 where (src) in (select (dst) from Graph AS g1 where (src < 800));
create or replace TEMP view semiJoinView8037280293563610785 as select v2, v4 from semiJoinView2271066312285946723 where (v4) in (select (src) from Graph AS g3);
create or replace TEMP view semiEnum1486689880544500949 as select v2, dst as v6, v4 from semiJoinView8037280293563610785, Graph as g3 where g3.src=semiJoinView8037280293563610785.v4;
create or replace TEMP view semiEnum8386848395734346206 as select v2, src as v1, v6, v4 from semiEnum1486689880544500949, Graph as g1 where g1.dst=semiEnum1486689880544500949.v2 and (g1.src < 800);
select v1, v2, v4, v6 from semiEnum8386848395734346206;
