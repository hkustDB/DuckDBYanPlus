create or replace view t1 as select ca_country, ca_state, ca_county, c_birth_year, c_customer_sk from customer_address, customer where c_current_addr_sk = ca_address_sk and ca_state in ('CA', 'TX', 'NY') and c_birth_month = 8;
create or replace view t2 as select cd_demo_sk, min(cd_dep_count) as cd_dep_count from customer_demographics WHERE cd_gender = 'M' and cd_education_status = 'College' group by cd_demo_sk;
create or replace view t3 as select i_item_sk, min(i_item_id) as i_item_id from item where i_category = 'Electronics' group by i_item_sk;
select min(i_item_id), min(ca_country), min(ca_state),
       min(ca_county),
       min(cs_quantity),
       min(cs_list_price),
       min(cs_coupon_amt),
       min(cs_sales_price),
       min(cs_net_profit),
       min(c_birth_year),
       min(cd_dep_count)
from catalog_sales, date_dim, t1, t2, t3
where cs_sold_date_sk = d_date_sk
    and cs_item_sk = t3.i_item_sk
    and cs_bill_cdemo_sk = t2.cd_demo_sk
    and cs_bill_customer_sk = t1.c_customer_sk
    and d_year = 2001
    and cs_wholesale_cost between 0 and 77.5;