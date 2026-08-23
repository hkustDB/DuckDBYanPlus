create or replace TEMP view bag187 as select g5.dst as v10, g4.src as v12, g4.dst as v8 from Graph as g4, Graph as g5, Graph as g6 where g4.dst=g5.src and g5.dst=g6.src and g6.dst=g4.src;
create or replace TEMP view aggView2342847404648505626 as select v12, COUNT(*) as annot from bag187 group by v12;
create or replace TEMP view aggJoin8909182364670701114 as select src as v2, annot from Graph as g7, aggView2342847404648505626 where g7.dst=aggView2342847404648505626.v12;
create or replace TEMP view bag188 as select g1.dst as v2, g2.dst as v4, g1.src as v6 from Graph as g1, Graph as g2, Graph as g3 where g1.dst=g2.src and g2.dst=g3.src and g3.dst=g1.src;
create or replace TEMP view aggView6906784260504084903 as select v2, COUNT(*) as annot from bag188 group by v2;
create or replace TEMP view aggJoin1657488435551201938 as select aggJoin8909182364670701114.annot * aggView6906784260504084903.annot as annot from aggJoin8909182364670701114 join aggView6906784260504084903 using(v2);
select COALESCE(SUM(annot), 0) as v15 from aggJoin1657488435551201938;
