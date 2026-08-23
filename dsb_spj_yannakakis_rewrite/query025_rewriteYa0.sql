-- Generated exact two-pass DSB reducer for dsb_spj/query025.

-- Round 3 uses the checked local Yannakakis+ aggregation/projection SQL.

CREATE OR REPLACE TEMP VIEW ya_query025_base_ss AS
SELECT ss.* FROM store_sales AS ss;

CREATE OR REPLACE TEMP VIEW ya_query025_base_sr AS
SELECT sr.* FROM store_returns AS sr;

CREATE OR REPLACE TEMP VIEW ya_query025_base_cs AS
SELECT cs.* FROM catalog_sales AS cs;

CREATE OR REPLACE TEMP VIEW ya_query025_base_d1 AS
SELECT d1.* FROM date_dim AS d1;

CREATE OR REPLACE TEMP VIEW ya_query025_base_d2 AS
SELECT d2.* FROM date_dim AS d2;

CREATE OR REPLACE TEMP VIEW ya_query025_base_d3 AS
SELECT d3.* FROM date_dim AS d3;

CREATE OR REPLACE TEMP VIEW ya_query025_base_store AS
SELECT store.* FROM store AS store;

CREATE OR REPLACE TEMP VIEW ya_query025_base_item AS
SELECT item.* FROM item AS item;

CREATE OR REPLACE TEMP VIEW ya_query025_up_d1 AS
SELECT d1.* FROM ya_query025_base_d1 AS d1;

CREATE OR REPLACE TEMP VIEW ya_query025_up_item AS
SELECT item.* FROM ya_query025_base_item AS item;

CREATE OR REPLACE TEMP VIEW ya_query025_up_d3 AS
SELECT d3.* FROM ya_query025_base_d3 AS d3;

CREATE OR REPLACE TEMP VIEW ya_query025_up_cs AS
SELECT cs.* FROM ya_query025_base_cs AS cs
WHERE EXISTS (SELECT 1 FROM ya_query025_up_d3 AS d3 WHERE cs.cs_sold_date_sk = d3.d_date_sk);

CREATE OR REPLACE TEMP VIEW ya_query025_up_d2 AS
SELECT d2.* FROM ya_query025_base_d2 AS d2;

CREATE OR REPLACE TEMP VIEW ya_query025_up_sr AS
SELECT sr.* FROM ya_query025_base_sr AS sr
WHERE EXISTS (SELECT 1 FROM ya_query025_up_cs AS cs WHERE sr.sr_customer_sk = cs.cs_bill_customer_sk AND sr.sr_item_sk = cs.cs_item_sk)
  AND EXISTS (SELECT 1 FROM ya_query025_up_d2 AS d2 WHERE sr.sr_returned_date_sk = d2.d_date_sk);

CREATE OR REPLACE TEMP VIEW ya_query025_up_store AS
SELECT store.* FROM ya_query025_base_store AS store;

CREATE OR REPLACE TEMP VIEW ya_query025_up_ss AS
SELECT ss.* FROM ya_query025_base_ss AS ss
WHERE EXISTS (SELECT 1 FROM ya_query025_up_d1 AS d1 WHERE ss.ss_sold_date_sk = d1.d_date_sk)
  AND EXISTS (SELECT 1 FROM ya_query025_up_item AS item WHERE ss.ss_item_sk = item.i_item_sk)
  AND EXISTS (SELECT 1 FROM ya_query025_up_sr AS sr WHERE ss.ss_customer_sk = sr.sr_customer_sk AND ss.ss_item_sk = sr.sr_item_sk AND ss.ss_ticket_number = sr.sr_ticket_number)
  AND EXISTS (SELECT 1 FROM ya_query025_up_store AS store WHERE ss.ss_store_sk = store.s_store_sk);

CREATE OR REPLACE TEMP VIEW ya_query025_down_ss AS
SELECT ss.* FROM ya_query025_up_ss AS ss;

CREATE OR REPLACE TEMP VIEW ya_query025_down_d1 AS
SELECT d1.* FROM ya_query025_up_d1 AS d1
WHERE EXISTS (SELECT 1 FROM ya_query025_down_ss AS ss WHERE ss.ss_sold_date_sk = d1.d_date_sk);

CREATE OR REPLACE TEMP VIEW ya_query025_down_item AS
SELECT item.* FROM ya_query025_up_item AS item
WHERE EXISTS (SELECT 1 FROM ya_query025_down_ss AS ss WHERE ss.ss_item_sk = item.i_item_sk);

CREATE OR REPLACE TEMP VIEW ya_query025_down_sr AS
SELECT sr.* FROM ya_query025_up_sr AS sr
WHERE EXISTS (SELECT 1 FROM ya_query025_down_ss AS ss WHERE ss.ss_customer_sk = sr.sr_customer_sk AND ss.ss_item_sk = sr.sr_item_sk AND ss.ss_ticket_number = sr.sr_ticket_number);

CREATE OR REPLACE TEMP VIEW ya_query025_down_store AS
SELECT store.* FROM ya_query025_up_store AS store
WHERE EXISTS (SELECT 1 FROM ya_query025_down_ss AS ss WHERE ss.ss_store_sk = store.s_store_sk);

CREATE OR REPLACE TEMP VIEW ya_query025_down_cs AS
SELECT cs.* FROM ya_query025_up_cs AS cs
WHERE EXISTS (SELECT 1 FROM ya_query025_down_sr AS sr WHERE sr.sr_customer_sk = cs.cs_bill_customer_sk AND sr.sr_item_sk = cs.cs_item_sk);

CREATE OR REPLACE TEMP VIEW ya_query025_down_d2 AS
SELECT d2.* FROM ya_query025_up_d2 AS d2
WHERE EXISTS (SELECT 1 FROM ya_query025_down_sr AS sr WHERE sr.sr_returned_date_sk = d2.d_date_sk);

CREATE OR REPLACE TEMP VIEW ya_query025_down_d3 AS
SELECT d3.* FROM ya_query025_up_d3 AS d3
WHERE EXISTS (SELECT 1 FROM ya_query025_down_cs AS cs WHERE cs.cs_sold_date_sk = d3.d_date_sk);

create or replace view t1 as select i_item_sk, min(i_item_sk) as i_item_id, min(i_item_desc) as i_item_desc from ya_query025_down_item AS item group by i_item_sk;
create or replace view t2 as select s_store_sk, min(s_store_id) as s_store_id, min(s_store_name) as s_store_name from ya_query025_down_store AS store group by s_store_sk;
select min(t1.i_item_id),
       min(t1.i_item_desc),
       min(t2.s_store_id),
       min(t2.s_store_name),
       min(ss.ss_net_profit),
       min(sr.sr_net_loss),
       min(cs.cs_net_profit),
       min(ss.ss_item_sk),
       min(sr.sr_ticket_number),
       min(cs.cs_order_number)
from ya_query025_down_ss AS ss,
        ya_query025_down_sr AS sr,
        ya_query025_down_cs AS cs,
        ya_query025_down_d1 AS d1,
        ya_query025_down_d2 AS d2,
        ya_query025_down_d3 AS d3,
        t2,
        t1
where d1.d_moy = 8
    and d1.d_year = 2001
    and d1.d_date_sk = ss.ss_sold_date_sk
    and t1.i_item_sk = ss.ss_item_sk
    and t2.s_store_sk = ss.ss_store_sk
    and ss.ss_customer_sk = sr.sr_customer_sk
    and ss.ss_item_sk = sr.sr_item_sk
    and ss.ss_ticket_number = sr.sr_ticket_number
    and sr.sr_returned_date_sk = d2.d_date_sk
    and d2.d_moy BETWEEN 0 AND 10
    and d2.d_year = 2001
    and sr.sr_customer_sk = cs.cs_bill_customer_sk
    and sr.sr_item_sk = cs.cs_item_sk
    and cs.cs_sold_date_sk = d3.d_date_sk
    and d3.d_moy BETWEEN 0 AND 10
    and d3.d_year = 2001;
