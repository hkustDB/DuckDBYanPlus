create or replace view t1 as select c_customer_sk, count(*) as annot from customer, customer_address, customer_demographics where c_current_addr_sk = ca_address_sk and c_current_cdemo_sk = cd_demo_sk and cd_marital_status = 'M' and cd_education_status = 'College' group by c_customer_sk;
select item1.i_item_sk, 
       item2.i_item_sk, 
       sum(annot) as cnt
from item as item1,
        item as item2,
        store_sales as s1,
        store_sales as s2,
        date_dim,
        t1
where item1.i_item_sk < item2.i_item_sk
    and s1.ss_ticket_number = s2.ss_ticket_number
    and s1.ss_item_sk = item1.i_item_sk
    and s2.ss_item_sk = item2.i_item_sk
    and s1.ss_customer_sk = t1.c_customer_sk
    and date_dim.d_year between 1999 and 2000
    and date_dim.d_date_sk = s1.ss_sold_date_sk
    and item1.i_category in ('Electronics', 'Sports')
    and item2.i_manager_id between 35 and 55
    and s1.ss_list_price between 147.5 and 152.5
    and s2.ss_list_price between 147.5 and 152.5
group by item1.i_item_sk, item2.i_item_sk;