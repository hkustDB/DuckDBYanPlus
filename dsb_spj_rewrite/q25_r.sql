create or replace view t1 as select i_item_sk, min(i_item_sk) as i_item_id, min(i_item_desc) as i_item_desc from item group by i_item_sk;
create or replace view t2 as select s_store_sk, min(s_store_id) as s_store_id, min(s_store_name) as s_store_name from store group by s_store_sk;
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
from store_sales as ss,
        store_returns as sr,
        catalog_sales as cs,
        date_dim d1,
        date_dim d2,
        date_dim d3,
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