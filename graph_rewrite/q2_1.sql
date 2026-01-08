create or replace TEMP view aggView6230041876669538883 as select dst as v2, COUNT(*) as annot from Graph as g1 group by dst;
create or replace TEMP view aggJoin1902641069183822897 as select dst as v4, annot from Graph as g2, aggView6230041876669538883 where g2.src=aggView6230041876669538883.v2;
create or replace TEMP view aggView4239101341248824506 as select src as v4, COUNT(*) as annot from Graph as g3 group by src;
create or replace TEMP view aggJoin9164579651966147880 as select aggJoin1902641069183822897.annot * aggView4239101341248824506.annot as annot from aggJoin1902641069183822897 join aggView4239101341248824506 using(v4);
select SUM(annot) as v7 from aggJoin9164579651966147880;
