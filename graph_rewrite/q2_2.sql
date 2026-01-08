create or replace TEMP view aggView6540537891483786214 as select src as v4, COUNT(*) as annot from Graph as g3 group by src;
create or replace TEMP view aggJoin8088282024744502741 as select src as v2, annot from Graph as g2, aggView6540537891483786214 where g2.dst=aggView6540537891483786214.v4;
create or replace TEMP view aggView4928771996128099466 as select v2, SUM(annot) as annot from aggJoin8088282024744502741 group by v2;
create or replace TEMP view aggJoin566817631274220463 as select annot from Graph as g1, aggView4928771996128099466 where g1.dst=aggView4928771996128099466.v2;
select SUM(annot) as v7 from aggJoin566817631274220463;
