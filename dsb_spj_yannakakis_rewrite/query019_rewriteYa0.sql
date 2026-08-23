-- Generated exact two-pass DSB reducer for dsb_spj/query019.

-- Round 3 uses the checked local Yannakakis+ aggregation/projection SQL.

CREATE OR REPLACE TEMP VIEW ya_query019_base_store_sales AS
SELECT store_sales.* FROM store_sales AS store_sales;

CREATE OR REPLACE TEMP VIEW ya_query019_base_date_dim AS
SELECT date_dim.* FROM date_dim AS date_dim;

CREATE OR REPLACE TEMP VIEW ya_query019_base_item AS
SELECT item.* FROM item AS item;

CREATE OR REPLACE TEMP VIEW ya_query019_base_customer AS
SELECT customer.* FROM customer AS customer;

CREATE OR REPLACE TEMP VIEW ya_query019_base_customer_address AS
SELECT customer_address.* FROM customer_address AS customer_address;

CREATE OR REPLACE TEMP VIEW ya_query019_base_store AS
SELECT store.* FROM store AS store;

CREATE OR REPLACE TEMP VIEW ya_query019_up_customer_address AS
SELECT customer_address.* FROM ya_query019_base_customer_address AS customer_address;

CREATE OR REPLACE TEMP VIEW ya_query019_up_customer AS
SELECT customer.* FROM ya_query019_base_customer AS customer
WHERE EXISTS (SELECT 1 FROM ya_query019_up_customer_address AS customer_address WHERE customer.c_current_addr_sk = customer_address.ca_address_sk);

CREATE OR REPLACE TEMP VIEW ya_query019_up_date_dim AS
SELECT date_dim.* FROM ya_query019_base_date_dim AS date_dim;

CREATE OR REPLACE TEMP VIEW ya_query019_up_item AS
SELECT item.* FROM ya_query019_base_item AS item;

CREATE OR REPLACE TEMP VIEW ya_query019_up_store AS
SELECT store.* FROM ya_query019_base_store AS store;

CREATE OR REPLACE TEMP VIEW ya_query019_up_store_sales AS
SELECT store_sales.* FROM ya_query019_base_store_sales AS store_sales
WHERE EXISTS (SELECT 1 FROM ya_query019_up_customer AS customer WHERE store_sales.ss_customer_sk = customer.c_customer_sk)
  AND EXISTS (SELECT 1 FROM ya_query019_up_date_dim AS date_dim WHERE store_sales.ss_sold_date_sk = date_dim.d_date_sk)
  AND EXISTS (SELECT 1 FROM ya_query019_up_item AS item WHERE store_sales.ss_item_sk = item.i_item_sk)
  AND EXISTS (SELECT 1 FROM ya_query019_up_store AS store WHERE store_sales.ss_store_sk = store.s_store_sk);

CREATE OR REPLACE TEMP VIEW ya_query019_down_store_sales AS
SELECT store_sales.* FROM ya_query019_up_store_sales AS store_sales;

CREATE OR REPLACE TEMP VIEW ya_query019_down_customer AS
SELECT customer.* FROM ya_query019_up_customer AS customer
WHERE EXISTS (SELECT 1 FROM ya_query019_down_store_sales AS store_sales WHERE store_sales.ss_customer_sk = customer.c_customer_sk);

CREATE OR REPLACE TEMP VIEW ya_query019_down_date_dim AS
SELECT date_dim.* FROM ya_query019_up_date_dim AS date_dim
WHERE EXISTS (SELECT 1 FROM ya_query019_down_store_sales AS store_sales WHERE store_sales.ss_sold_date_sk = date_dim.d_date_sk);

CREATE OR REPLACE TEMP VIEW ya_query019_down_item AS
SELECT item.* FROM ya_query019_up_item AS item
WHERE EXISTS (SELECT 1 FROM ya_query019_down_store_sales AS store_sales WHERE store_sales.ss_item_sk = item.i_item_sk);

CREATE OR REPLACE TEMP VIEW ya_query019_down_store AS
SELECT store.* FROM ya_query019_up_store AS store
WHERE EXISTS (SELECT 1 FROM ya_query019_down_store_sales AS store_sales WHERE store_sales.ss_store_sk = store.s_store_sk);

CREATE OR REPLACE TEMP VIEW ya_query019_down_customer_address AS
SELECT customer_address.* FROM ya_query019_up_customer_address AS customer_address
WHERE EXISTS (SELECT 1 FROM ya_query019_down_customer AS customer WHERE customer.c_current_addr_sk = customer_address.ca_address_sk);

create or replace view t1 as select c_customer_sk, ca_zip from ya_query019_down_customer AS customer, ya_query019_down_customer_address AS customer_address where c_current_addr_sk = ca_address_sk and ca_state = 'CA' and c_birth_month = 6;
create or replace view t2 as select d_date_sk from ya_query019_down_date_dim AS date_dim where d_year = 2000 and d_moy = 8 group by d_date_sk;
create or replace view t3 as select ss_item_sk, min(ss_ext_sales_price) as min_ss_ext_sales_price from ya_query019_down_store_sales AS store_sales, ya_query019_down_store AS store, t1, t2 where ss_sold_date_sk = d_date_sk and ss_store_sk = s_store_sk and ss_customer_sk = c_customer_sk and substring(ca_zip,1,5) <> substring(s_zip,1,5) and ss_wholesale_cost between 0 and 70 group by ss_item_sk;
select min(i_brand_id), min(i_manufact_id), min(min_ss_ext_sales_price) from ya_query019_down_item AS item, t3 where i_item_sk = ss_item_sk and i_category = 'Electronics';
