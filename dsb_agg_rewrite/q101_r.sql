create or replace view t1 as select ss_customer_sk, count(*) as annot from store_sales, store_returns, web_sales, date_dim d1, date_dim d2, item where ss_ticket_number = sr_ticket_number and ss_customer_sk = ws_bill_customer_sk and ss_item_sk = sr_item_sk and sr_item_sk = ws_item_sk and i_item_sk = ss_item_sk and i_category IN ('Electronics', 'Sports', 'Books') and sr_returned_date_sk = d1.d_date_sk and ws_sold_date_sk = d2.d_date_sk and d2.d_date BETWEEN d1.d_date AND (d1.d_date + interval '180 day') and d1.d_year = 1999 group by ss_customer_sk;
select c_customer_sk,
         c_first_name,
         c_last_name,
         sum(annot) as cnt
from customer, customer_address, household_demographics, t1
where c_current_addr_sk = ca_address_sk
    and c_current_hdemo_sk = hd_demo_sk
    and ca_state NOT IN ('CA')
    and hd_income_band_sk BETWEEN 2 AND 50
    and t1.ss_customer_sk = c_customer_sk
group by c_customer_sk,
         c_first_name,
         c_last_name;
