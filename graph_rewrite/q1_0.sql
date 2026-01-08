create or replace TEMP view semiJoinView7432182434041365743 as select src as v2, dst as v4 from Graph AS g2 where (src) in (select (dst) from Graph AS g1 where (dst < 1000));
create or replace TEMP view semiJoinView882112916829170591 as select src as v4, dst as v6 from Graph AS g3 where (src) in (select (v4) from semiJoinView7432182434041365743);
create or replace TEMP view semiEnum3839024167573413566 as select v4, v6, v2 from semiJoinView882112916829170591 join semiJoinView7432182434041365743 using(v4);
create or replace TEMP view semiEnum394859663861990391 as select v6, v2, src as v1, v4 from semiEnum3839024167573413566, Graph as g1 where g1.dst=semiEnum3839024167573413566.v2 and (dst < 1000);
select v1, v2, v4, v6 from semiEnum394859663861990391;
