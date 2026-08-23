-- Generated exact two-pass DSB reducer for dsb_agg/query101.

-- Round 3 uses the checked local Yannakakis+ aggregation/projection SQL.

CREATE OR REPLACE TEMP VIEW ya_query101_base_store_sales AS
SELECT store_sales.* FROM store_sales AS store_sales;

CREATE OR REPLACE TEMP VIEW ya_query101_base_store_returns AS
SELECT store_returns.* FROM store_returns AS store_returns;

CREATE OR REPLACE TEMP VIEW ya_query101_base_web_sales AS
SELECT web_sales.* FROM web_sales AS web_sales;

CREATE OR REPLACE TEMP VIEW ya_query101_base_d1 AS
SELECT d1.* FROM date_dim AS d1;

CREATE OR REPLACE TEMP VIEW ya_query101_base_d2 AS
SELECT d2.* FROM date_dim AS d2;

CREATE OR REPLACE TEMP VIEW ya_query101_base_item AS
SELECT item.* FROM item AS item;

CREATE OR REPLACE TEMP VIEW ya_query101_base_customer AS
SELECT customer.* FROM customer AS customer;

CREATE OR REPLACE TEMP VIEW ya_query101_base_customer_address AS
SELECT customer_address.* FROM customer_address AS customer_address;

CREATE OR REPLACE TEMP VIEW ya_query101_base_household_demographics AS
SELECT household_demographics.* FROM household_demographics AS household_demographics;

CREATE OR REPLACE TEMP VIEW ya_query101_up_customer_address AS
SELECT customer_address.* FROM ya_query101_base_customer_address AS customer_address;

CREATE OR REPLACE TEMP VIEW ya_query101_up_household_demographics AS
SELECT household_demographics.* FROM ya_query101_base_household_demographics AS household_demographics;

CREATE OR REPLACE TEMP VIEW ya_query101_up_customer AS
SELECT customer.* FROM ya_query101_base_customer AS customer
WHERE EXISTS (SELECT 1 FROM ya_query101_up_customer_address AS customer_address WHERE customer.c_current_addr_sk = customer_address.ca_address_sk)
  AND EXISTS (SELECT 1 FROM ya_query101_up_household_demographics AS household_demographics WHERE customer.c_current_hdemo_sk = household_demographics.hd_demo_sk);

CREATE OR REPLACE TEMP VIEW ya_query101_up_item AS
SELECT item.* FROM ya_query101_base_item AS item;

CREATE OR REPLACE TEMP VIEW ya_query101_up_d1 AS
SELECT d1.* FROM ya_query101_base_d1 AS d1;

CREATE OR REPLACE TEMP VIEW ya_query101_up_store_returns AS
SELECT store_returns.* FROM ya_query101_base_store_returns AS store_returns
WHERE EXISTS (SELECT 1 FROM ya_query101_up_d1 AS d1 WHERE store_returns.sr_returned_date_sk = d1.d_date_sk);

CREATE OR REPLACE TEMP VIEW ya_query101_up_d2 AS
SELECT d2.* FROM ya_query101_base_d2 AS d2;

CREATE OR REPLACE TEMP VIEW ya_query101_up_web_sales AS
SELECT web_sales.* FROM ya_query101_base_web_sales AS web_sales
WHERE EXISTS (SELECT 1 FROM ya_query101_up_d2 AS d2 WHERE web_sales.ws_sold_date_sk = d2.d_date_sk);

CREATE OR REPLACE TEMP VIEW ya_query101_up_store_sales AS
SELECT store_sales.* FROM ya_query101_base_store_sales AS store_sales
WHERE EXISTS (SELECT 1 FROM ya_query101_up_customer AS customer WHERE store_sales.ss_customer_sk = customer.c_customer_sk)
  AND EXISTS (SELECT 1 FROM ya_query101_up_item AS item WHERE store_sales.ss_item_sk = item.i_item_sk)
  AND EXISTS (SELECT 1 FROM ya_query101_up_store_returns AS store_returns WHERE store_sales.ss_ticket_number = store_returns.sr_ticket_number AND store_sales.ss_item_sk = store_returns.sr_item_sk)
  AND EXISTS (SELECT 1 FROM ya_query101_up_web_sales AS web_sales WHERE store_sales.ss_customer_sk = web_sales.ws_bill_customer_sk);

CREATE OR REPLACE TEMP VIEW ya_query101_down_store_sales AS
SELECT store_sales.* FROM ya_query101_up_store_sales AS store_sales;

CREATE OR REPLACE TEMP VIEW ya_query101_down_customer AS
SELECT customer.* FROM ya_query101_up_customer AS customer
WHERE EXISTS (SELECT 1 FROM ya_query101_down_store_sales AS store_sales WHERE store_sales.ss_customer_sk = customer.c_customer_sk);

CREATE OR REPLACE TEMP VIEW ya_query101_down_item AS
SELECT item.* FROM ya_query101_up_item AS item
WHERE EXISTS (SELECT 1 FROM ya_query101_down_store_sales AS store_sales WHERE store_sales.ss_item_sk = item.i_item_sk);

CREATE OR REPLACE TEMP VIEW ya_query101_down_store_returns AS
SELECT store_returns.* FROM ya_query101_up_store_returns AS store_returns
WHERE EXISTS (SELECT 1 FROM ya_query101_down_store_sales AS store_sales WHERE store_sales.ss_ticket_number = store_returns.sr_ticket_number AND store_sales.ss_item_sk = store_returns.sr_item_sk);

CREATE OR REPLACE TEMP VIEW ya_query101_down_web_sales AS
SELECT web_sales.* FROM ya_query101_up_web_sales AS web_sales
WHERE EXISTS (SELECT 1 FROM ya_query101_down_store_sales AS store_sales WHERE store_sales.ss_customer_sk = web_sales.ws_bill_customer_sk);

CREATE OR REPLACE TEMP VIEW ya_query101_down_customer_address AS
SELECT customer_address.* FROM ya_query101_up_customer_address AS customer_address
WHERE EXISTS (SELECT 1 FROM ya_query101_down_customer AS customer WHERE customer.c_current_addr_sk = customer_address.ca_address_sk);

CREATE OR REPLACE TEMP VIEW ya_query101_down_household_demographics AS
SELECT household_demographics.* FROM ya_query101_up_household_demographics AS household_demographics
WHERE EXISTS (SELECT 1 FROM ya_query101_down_customer AS customer WHERE customer.c_current_hdemo_sk = household_demographics.hd_demo_sk);

CREATE OR REPLACE TEMP VIEW ya_query101_down_d1 AS
SELECT d1.* FROM ya_query101_up_d1 AS d1
WHERE EXISTS (SELECT 1 FROM ya_query101_down_store_returns AS store_returns WHERE store_returns.sr_returned_date_sk = d1.d_date_sk);

CREATE OR REPLACE TEMP VIEW ya_query101_down_d2 AS
SELECT d2.* FROM ya_query101_up_d2 AS d2
WHERE EXISTS (SELECT 1 FROM ya_query101_down_web_sales AS web_sales WHERE web_sales.ws_sold_date_sk = d2.d_date_sk);

create or replace view t1 as select ss_customer_sk, count(*) as annot from ya_query101_down_store_sales AS store_sales, ya_query101_down_store_returns AS store_returns, ya_query101_down_web_sales AS web_sales, ya_query101_down_d1 AS d1, ya_query101_down_d2 AS d2, ya_query101_down_item AS item where ss_ticket_number = sr_ticket_number and ss_customer_sk = ws_bill_customer_sk and ss_item_sk = sr_item_sk and sr_item_sk = ws_item_sk and i_item_sk = ss_item_sk and i_category IN ('Electronics', 'Sports', 'Books') and sr_returned_date_sk = d1.d_date_sk and ws_sold_date_sk = d2.d_date_sk and d2.d_date BETWEEN d1.d_date AND (d1.d_date + interval '180 day') and d1.d_year = 1999 group by ss_customer_sk;
select c_customer_sk,
         c_first_name,
         c_last_name,
         sum(annot) as cnt
from ya_query101_down_customer AS customer, ya_query101_down_customer_address AS customer_address, ya_query101_down_household_demographics AS household_demographics, t1
where c_current_addr_sk = ca_address_sk
    and c_current_hdemo_sk = hd_demo_sk
    and ca_state NOT IN ('CA')
    and hd_income_band_sk BETWEEN 2 AND 50
    and t1.ss_customer_sk = c_customer_sk
group by c_customer_sk,
         c_first_name,
         c_last_name;
