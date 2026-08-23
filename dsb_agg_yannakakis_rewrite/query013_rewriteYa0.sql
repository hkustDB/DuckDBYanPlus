-- Generated exact two-pass DSB reducer for dsb_agg/query013.

-- Round 3 uses the checked local Yannakakis+ aggregation/projection SQL.

CREATE OR REPLACE TEMP VIEW ya_query013_base_store_sales AS
SELECT store_sales.* FROM store_sales AS store_sales;

CREATE OR REPLACE TEMP VIEW ya_query013_base_store AS
SELECT store.* FROM store AS store;

CREATE OR REPLACE TEMP VIEW ya_query013_base_customer_demographics AS
SELECT customer_demographics.* FROM customer_demographics AS customer_demographics;

CREATE OR REPLACE TEMP VIEW ya_query013_base_household_demographics AS
SELECT household_demographics.* FROM household_demographics AS household_demographics;

CREATE OR REPLACE TEMP VIEW ya_query013_base_customer_address AS
SELECT customer_address.* FROM customer_address AS customer_address;

CREATE OR REPLACE TEMP VIEW ya_query013_base_date_dim AS
SELECT date_dim.* FROM date_dim AS date_dim;

CREATE OR REPLACE TEMP VIEW ya_query013_up_customer_address AS
SELECT customer_address.* FROM ya_query013_base_customer_address AS customer_address;

CREATE OR REPLACE TEMP VIEW ya_query013_up_customer_demographics AS
SELECT customer_demographics.* FROM ya_query013_base_customer_demographics AS customer_demographics;

CREATE OR REPLACE TEMP VIEW ya_query013_up_date_dim AS
SELECT date_dim.* FROM ya_query013_base_date_dim AS date_dim;

CREATE OR REPLACE TEMP VIEW ya_query013_up_household_demographics AS
SELECT household_demographics.* FROM ya_query013_base_household_demographics AS household_demographics;

CREATE OR REPLACE TEMP VIEW ya_query013_up_store AS
SELECT store.* FROM ya_query013_base_store AS store;

CREATE OR REPLACE TEMP VIEW ya_query013_up_store_sales AS
SELECT store_sales.* FROM ya_query013_base_store_sales AS store_sales
WHERE EXISTS (SELECT 1 FROM ya_query013_up_customer_address AS customer_address WHERE store_sales.ss_addr_sk = customer_address.ca_address_sk)
  AND EXISTS (SELECT 1 FROM ya_query013_up_customer_demographics AS customer_demographics WHERE store_sales.ss_cdemo_sk = customer_demographics.cd_demo_sk)
  AND EXISTS (SELECT 1 FROM ya_query013_up_date_dim AS date_dim WHERE store_sales.ss_sold_date_sk = date_dim.d_date_sk)
  AND EXISTS (SELECT 1 FROM ya_query013_up_household_demographics AS household_demographics WHERE store_sales.ss_hdemo_sk = household_demographics.hd_demo_sk)
  AND EXISTS (SELECT 1 FROM ya_query013_up_store AS store WHERE store_sales.ss_store_sk = store.s_store_sk);

CREATE OR REPLACE TEMP VIEW ya_query013_down_store_sales AS
SELECT store_sales.* FROM ya_query013_up_store_sales AS store_sales;

CREATE OR REPLACE TEMP VIEW ya_query013_down_customer_address AS
SELECT customer_address.* FROM ya_query013_up_customer_address AS customer_address
WHERE EXISTS (SELECT 1 FROM ya_query013_down_store_sales AS store_sales WHERE store_sales.ss_addr_sk = customer_address.ca_address_sk);

CREATE OR REPLACE TEMP VIEW ya_query013_down_customer_demographics AS
SELECT customer_demographics.* FROM ya_query013_up_customer_demographics AS customer_demographics
WHERE EXISTS (SELECT 1 FROM ya_query013_down_store_sales AS store_sales WHERE store_sales.ss_cdemo_sk = customer_demographics.cd_demo_sk);

CREATE OR REPLACE TEMP VIEW ya_query013_down_date_dim AS
SELECT date_dim.* FROM ya_query013_up_date_dim AS date_dim
WHERE EXISTS (SELECT 1 FROM ya_query013_down_store_sales AS store_sales WHERE store_sales.ss_sold_date_sk = date_dim.d_date_sk);

CREATE OR REPLACE TEMP VIEW ya_query013_down_household_demographics AS
SELECT household_demographics.* FROM ya_query013_up_household_demographics AS household_demographics
WHERE EXISTS (SELECT 1 FROM ya_query013_down_store_sales AS store_sales WHERE store_sales.ss_hdemo_sk = household_demographics.hd_demo_sk);

CREATE OR REPLACE TEMP VIEW ya_query013_down_store AS
SELECT store.* FROM ya_query013_up_store AS store
WHERE EXISTS (SELECT 1 FROM ya_query013_down_store_sales AS store_sales WHERE store_sales.ss_store_sk = store.s_store_sk);

SELECT sum(ss_ext_wholesale_cost)
FROM ya_query013_down_store_sales AS store_sales
    JOIN ya_query013_down_store AS store ON s_store_sk = ss_store_sk
    JOIN ya_query013_down_customer_demographics AS customer_demographics ON cd_demo_sk = ss_cdemo_sk
    JOIN ya_query013_down_household_demographics AS household_demographics ON ss_hdemo_sk = hd_demo_sk
    JOIN ya_query013_down_customer_address AS customer_address ON ss_addr_sk = ca_address_sk
    JOIN ya_query013_down_date_dim AS date_dim ON ss_sold_date_sk = d_date_sk
WHERE d_year = 2001
AND (
    (cd_marital_status = 'M'
     AND cd_education_status = 'College' 
     AND ss_sales_price BETWEEN 100.00 AND 150.00
     AND hd_dep_count = 3)
    OR  
    (cd_marital_status = 'S' 
     AND cd_education_status = 'High School' 
     AND ss_sales_price BETWEEN 50.00 AND 100.00
     AND hd_dep_count = 1)
    OR
    (cd_marital_status = 'W' 
     AND cd_education_status = 'Graduate Degree' 
     AND ss_sales_price BETWEEN 150.00 AND 200.00
     AND hd_dep_count = 1)
)
AND (
    (ca_country = 'United States'
     AND ca_state IN ('TN', 'TN', 'TN') 
     AND ss_net_profit BETWEEN 100 AND 200)
    OR
    (ca_country = 'United States'
     AND ca_state IN ('TN', 'TN', 'TN') 
     AND ss_net_profit BETWEEN 150 AND 300)
    OR
    (ca_country = 'United States'
     AND ca_state IN ('TN', 'TN', 'TN') 
     AND ss_net_profit BETWEEN 50 AND 250)
)
