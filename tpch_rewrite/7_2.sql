CREATE OR REPLACE TEMP VIEW lineitemwithyear AS
SELECT lineitem.*, year(l_shipdate) AS l_year FROM lineitem;

create or replace TEMP view aggView106555344001081693 as select n_nationkey as v37, n_name as v47 from nation as n2;
create or replace TEMP view aggJoin4095866967928832749 as select v37, v47 from aggView106555344001081693 where v47= 'GERMANY';
create or replace TEMP view aggView109729022523567099 as select l_year as v9, l_orderkey as v25, l_suppkey as v1, SUM(l_extendedprice * (1 - l_discount)) as v51, COUNT(*) as annot from lineitemwithyear as lineitemwithyear where (l_shipdate >= DATE '1995-01-01') and (l_shipdate <= DATE '1996-12-31') group by l_year,l_orderkey,l_suppkey;
create or replace TEMP view aggView3522138881096355775 as select n_nationkey as v4, n_name as v43 from nation as n1;
create or replace TEMP view aggJoin2387868904232496709 as select v4, v43 from aggView3522138881096355775 where v43= 'FRANCE';
create or replace TEMP view semiJoinView7687679912488899075 as select c_custkey as v34, c_nationkey as v37 from customer AS customer where (c_nationkey) in (select (v37) from aggJoin4095866967928832749);
create or replace TEMP view semiJoinView2310390681844658028 as select o_orderkey as v25, o_custkey as v34 from orders AS orders where (o_custkey) in (select (v34) from semiJoinView7687679912488899075);
create or replace TEMP view semiJoinView1435809953598050335 as select v9, v25, v1, v51, annot from aggView109729022523567099 where (v25) in (select (v25) from semiJoinView2310390681844658028);
create or replace TEMP view semiJoinView1209924686987534254 as select s_suppkey as v1, s_nationkey as v4 from supplier AS supplier where (s_suppkey) in (select (v1) from semiJoinView1435809953598050335);
create or replace TEMP view semiJoinView7923317341225259712 as select distinct v4, v43 from aggJoin2387868904232496709 where (v4) in (select (v4) from semiJoinView1209924686987534254);
create or replace TEMP view semiEnum8597417000792156714 as select distinct v1, v43 from semiJoinView7923317341225259712 join semiJoinView1209924686987534254 using(v4);
create or replace TEMP view semiEnum2109082094294609158 as select distinct v9, v51, annot, v25, v43 from semiEnum8597417000792156714 join semiJoinView1435809953598050335 using(v1);
create or replace TEMP view semiEnum5408697729647620134 as select distinct v9, v51, v43, v34, annot from semiEnum2109082094294609158 join semiJoinView2310390681844658028 using(v25);
create or replace TEMP view semiEnum7806803823549016886 as select distinct v9, v51, v37, v43, annot from semiEnum5408697729647620134 join semiJoinView7687679912488899075 using(v34);
create or replace TEMP view semiEnum2058678904992042684 as select v9, v51, v47, v43, annot from semiEnum7806803823549016886 join aggJoin4095866967928832749 using(v37);
select v43,v47,v9,SUM(v51) as v51 from semiEnum2058678904992042684 group by v43, v47, v9;
