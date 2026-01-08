create or replace view t1 as select ss_item_sk, sum(ss_ext_sales_price) as total_sales from store_sales, date_dim, customer, customer_address, store where d_date_sk = ss_sold_date_sk and ss_customer_sk = c_customer_sk and c_current_addr_sk = ca_address_sk and ss_store_sk = s_store_sk and d_year = 2001 and d_moy = 8 and substring(ca_zip,1,5) <> substring(s_zip,1,5) and ca_state = 'CA' and c_birth_month = 6 and ss_wholesale_cost between 45 and 100 group by ss_item_sk;
select i_brand_id as brand_id, 
       i_brand as brand, 
       i_manufact_id, 
       i_manufact,
       sum(t1.total_sales) as ext_price
from t1, item
where t1.ss_item_sk = i_item_sk
    and i_category = 'Electronics'
group by i_brand,
         i_brand_id,
         i_manufact_id,
         i_manufact;