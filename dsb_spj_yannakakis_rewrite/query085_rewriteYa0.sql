-- Generated exact two-pass DSB reducer for dsb_spj/query085.

-- Round 3 uses the checked local Yannakakis+ aggregation/projection SQL.

CREATE OR REPLACE TEMP VIEW ya_query085_base_web_sales AS
SELECT web_sales.* FROM web_sales AS web_sales;

CREATE OR REPLACE TEMP VIEW ya_query085_base_web_returns AS
SELECT web_returns.* FROM web_returns AS web_returns;

CREATE OR REPLACE TEMP VIEW ya_query085_base_web_page AS
SELECT web_page.* FROM web_page AS web_page;

CREATE OR REPLACE TEMP VIEW ya_query085_base_cd1 AS
SELECT cd1.* FROM customer_demographics AS cd1;

CREATE OR REPLACE TEMP VIEW ya_query085_base_cd2 AS
SELECT cd2.* FROM customer_demographics AS cd2;

CREATE OR REPLACE TEMP VIEW ya_query085_base_customer_address AS
SELECT customer_address.* FROM customer_address AS customer_address;

CREATE OR REPLACE TEMP VIEW ya_query085_base_date_dim AS
SELECT date_dim.* FROM date_dim AS date_dim;

CREATE OR REPLACE TEMP VIEW ya_query085_base_reason AS
SELECT reason.* FROM reason AS reason;

CREATE OR REPLACE TEMP VIEW ya_query085_up_date_dim AS
SELECT date_dim.* FROM ya_query085_base_date_dim AS date_dim;

CREATE OR REPLACE TEMP VIEW ya_query085_up_web_page AS
SELECT web_page.* FROM ya_query085_base_web_page AS web_page;

CREATE OR REPLACE TEMP VIEW ya_query085_up_cd1 AS
SELECT cd1.* FROM ya_query085_base_cd1 AS cd1;

CREATE OR REPLACE TEMP VIEW ya_query085_up_cd2 AS
SELECT cd2.* FROM ya_query085_base_cd2 AS cd2;

CREATE OR REPLACE TEMP VIEW ya_query085_up_customer_address AS
SELECT customer_address.* FROM ya_query085_base_customer_address AS customer_address;

CREATE OR REPLACE TEMP VIEW ya_query085_up_reason AS
SELECT reason.* FROM ya_query085_base_reason AS reason;

CREATE OR REPLACE TEMP VIEW ya_query085_up_web_returns AS
SELECT web_returns.* FROM ya_query085_base_web_returns AS web_returns
WHERE EXISTS (SELECT 1 FROM ya_query085_up_cd1 AS cd1 WHERE web_returns.wr_refunded_cdemo_sk = cd1.cd_demo_sk)
  AND EXISTS (SELECT 1 FROM ya_query085_up_cd2 AS cd2 WHERE web_returns.wr_returning_cdemo_sk = cd2.cd_demo_sk)
  AND EXISTS (SELECT 1 FROM ya_query085_up_customer_address AS customer_address WHERE web_returns.wr_refunded_addr_sk = customer_address.ca_address_sk)
  AND EXISTS (SELECT 1 FROM ya_query085_up_reason AS reason WHERE web_returns.wr_reason_sk = reason.r_reason_sk);

CREATE OR REPLACE TEMP VIEW ya_query085_up_web_sales AS
SELECT web_sales.* FROM ya_query085_base_web_sales AS web_sales
WHERE EXISTS (SELECT 1 FROM ya_query085_up_date_dim AS date_dim WHERE web_sales.ws_sold_date_sk = date_dim.d_date_sk)
  AND EXISTS (SELECT 1 FROM ya_query085_up_web_page AS web_page WHERE web_sales.ws_web_page_sk = web_page.wp_web_page_sk)
  AND EXISTS (SELECT 1 FROM ya_query085_up_web_returns AS web_returns WHERE web_sales.ws_item_sk = web_returns.wr_item_sk AND web_sales.ws_order_number = web_returns.wr_order_number);

CREATE OR REPLACE TEMP VIEW ya_query085_down_web_sales AS
SELECT web_sales.* FROM ya_query085_up_web_sales AS web_sales;

CREATE OR REPLACE TEMP VIEW ya_query085_down_date_dim AS
SELECT date_dim.* FROM ya_query085_up_date_dim AS date_dim
WHERE EXISTS (SELECT 1 FROM ya_query085_down_web_sales AS web_sales WHERE web_sales.ws_sold_date_sk = date_dim.d_date_sk);

CREATE OR REPLACE TEMP VIEW ya_query085_down_web_page AS
SELECT web_page.* FROM ya_query085_up_web_page AS web_page
WHERE EXISTS (SELECT 1 FROM ya_query085_down_web_sales AS web_sales WHERE web_sales.ws_web_page_sk = web_page.wp_web_page_sk);

CREATE OR REPLACE TEMP VIEW ya_query085_down_web_returns AS
SELECT web_returns.* FROM ya_query085_up_web_returns AS web_returns
WHERE EXISTS (SELECT 1 FROM ya_query085_down_web_sales AS web_sales WHERE web_sales.ws_item_sk = web_returns.wr_item_sk AND web_sales.ws_order_number = web_returns.wr_order_number);

CREATE OR REPLACE TEMP VIEW ya_query085_down_cd1 AS
SELECT cd1.* FROM ya_query085_up_cd1 AS cd1
WHERE EXISTS (SELECT 1 FROM ya_query085_down_web_returns AS web_returns WHERE web_returns.wr_refunded_cdemo_sk = cd1.cd_demo_sk);

CREATE OR REPLACE TEMP VIEW ya_query085_down_cd2 AS
SELECT cd2.* FROM ya_query085_up_cd2 AS cd2
WHERE EXISTS (SELECT 1 FROM ya_query085_down_web_returns AS web_returns WHERE web_returns.wr_returning_cdemo_sk = cd2.cd_demo_sk);

CREATE OR REPLACE TEMP VIEW ya_query085_down_customer_address AS
SELECT customer_address.* FROM ya_query085_up_customer_address AS customer_address
WHERE EXISTS (SELECT 1 FROM ya_query085_down_web_returns AS web_returns WHERE web_returns.wr_refunded_addr_sk = customer_address.ca_address_sk);

CREATE OR REPLACE TEMP VIEW ya_query085_down_reason AS
SELECT reason.* FROM ya_query085_up_reason AS reason
WHERE EXISTS (SELECT 1 FROM ya_query085_down_web_returns AS web_returns WHERE web_returns.wr_reason_sk = reason.r_reason_sk);

create or replace view t1 as select ws_item_sk, ws_order_number, min(ws_quantity) as ws_quantity, min(ws_item_sk) as ws_item_sk from ya_query085_down_web_sales AS web_sales, ya_query085_down_date_dim AS date_dim, ya_query085_down_web_page AS web_page where ws_web_page_sk = wp_web_page_sk and ws_sold_date_sk = d_date_sk and d_year = 2001 and ws_sales_price between 50.00 and 200.00 group by ws_item_sk, ws_order_number;
select min(t1.ws_quantity), min(wr_refunded_cash), min(wr_fee), min(t1.ws_item_sk), min(t1.ws_order_number), min(cd1.cd_demo_sk), min(cd2.cd_demo_sk) from t1, ya_query085_down_web_returns AS web_returns, ya_query085_down_cd1 AS cd1, ya_query085_down_cd2 AS cd2, ya_query085_down_customer_address AS customer_address, ya_query085_down_reason AS reason where t1.ws_item_sk = wr_item_sk and t1.ws_order_number = wr_order_number and cd1.cd_demo_sk = wr_refunded_cdemo_sk and cd2.cd_demo_sk = wr_returning_cdemo_sk and ca_address_sk = wr_refunded_addr_sk and r_reason_sk = wr_reason_sk and ((cd1.cd_marital_status = 'M' and cd1.cd_marital_status = cd2.cd_marital_status and cd1.cd_education_status = 'College' and cd1.cd_education_status = cd2.cd_education_status) or (cd1.cd_marital_status = 'S' and cd1.cd_marital_status = cd2.cd_marital_status and cd1.cd_education_status = 'High School' and cd1.cd_education_status = cd2.cd_education_status) or (cd1.cd_marital_status = 'W' and cd1.cd_marital_status = cd2.cd_marital_status and cd1.cd_education_status = 'Graduate Degree' and cd1.cd_education_status = cd2.cd_education_status)) and ((ca_country = 'United States' and ca_state in ('CA', 'TX', 'NY')) or (ca_country = 'United States' and ca_state in ('FL', 'IL', 'PA')) or (ca_country = 'United States' and ca_state in ('OH', 'MI', 'GA')));
