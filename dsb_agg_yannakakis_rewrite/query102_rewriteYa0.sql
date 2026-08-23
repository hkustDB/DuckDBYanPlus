-- Generated exact two-pass DSB reducer for dsb_agg/query102.

-- Round 3 uses the checked local Yannakakis+ aggregation/projection SQL.

CREATE OR REPLACE TEMP VIEW ya_query102_base_ss AS
SELECT ss.* FROM store_sales AS ss;

CREATE OR REPLACE TEMP VIEW ya_query102_base_ws AS
SELECT ws.* FROM web_sales AS ws;

CREATE OR REPLACE TEMP VIEW ya_query102_base_d1 AS
SELECT d1.* FROM date_dim AS d1;

CREATE OR REPLACE TEMP VIEW ya_query102_base_d2 AS
SELECT d2.* FROM date_dim AS d2;

CREATE OR REPLACE TEMP VIEW ya_query102_base_customer AS
SELECT customer.* FROM customer AS customer;

CREATE OR REPLACE TEMP VIEW ya_query102_base_inventory AS
SELECT inventory.* FROM inventory AS inventory;

CREATE OR REPLACE TEMP VIEW ya_query102_base_store AS
SELECT store.* FROM store AS store;

CREATE OR REPLACE TEMP VIEW ya_query102_base_warehouse AS
SELECT warehouse.* FROM warehouse AS warehouse;

CREATE OR REPLACE TEMP VIEW ya_query102_base_item AS
SELECT item.* FROM item AS item;

CREATE OR REPLACE TEMP VIEW ya_query102_base_customer_demographics AS
SELECT customer_demographics.* FROM customer_demographics AS customer_demographics;

CREATE OR REPLACE TEMP VIEW ya_query102_base_household_demographics AS
SELECT household_demographics.* FROM household_demographics AS household_demographics;

CREATE OR REPLACE TEMP VIEW ya_query102_base_customer_address AS
SELECT customer_address.* FROM customer_address AS customer_address;

CREATE OR REPLACE TEMP VIEW ya_query102_up_customer_address AS
SELECT customer_address.* FROM ya_query102_base_customer_address AS customer_address;

CREATE OR REPLACE TEMP VIEW ya_query102_up_customer_demographics AS
SELECT customer_demographics.* FROM ya_query102_base_customer_demographics AS customer_demographics;

CREATE OR REPLACE TEMP VIEW ya_query102_up_household_demographics AS
SELECT household_demographics.* FROM ya_query102_base_household_demographics AS household_demographics;

CREATE OR REPLACE TEMP VIEW ya_query102_up_customer AS
SELECT customer.* FROM ya_query102_base_customer AS customer
WHERE EXISTS (SELECT 1 FROM ya_query102_up_customer_address AS customer_address WHERE customer.c_current_addr_sk = customer_address.ca_address_sk)
  AND EXISTS (SELECT 1 FROM ya_query102_up_customer_demographics AS customer_demographics WHERE customer.c_current_cdemo_sk = customer_demographics.cd_demo_sk)
  AND EXISTS (SELECT 1 FROM ya_query102_up_household_demographics AS household_demographics WHERE customer.c_current_hdemo_sk = household_demographics.hd_demo_sk);

CREATE OR REPLACE TEMP VIEW ya_query102_up_d1 AS
SELECT d1.* FROM ya_query102_base_d1 AS d1;

CREATE OR REPLACE TEMP VIEW ya_query102_up_inventory AS
SELECT inventory.* FROM ya_query102_base_inventory AS inventory;

CREATE OR REPLACE TEMP VIEW ya_query102_up_item AS
SELECT item.* FROM ya_query102_base_item AS item;

CREATE OR REPLACE TEMP VIEW ya_query102_up_d2 AS
SELECT d2.* FROM ya_query102_base_d2 AS d2;

CREATE OR REPLACE TEMP VIEW ya_query102_up_store AS
SELECT store.* FROM ya_query102_base_store AS store;

CREATE OR REPLACE TEMP VIEW ya_query102_up_warehouse AS
SELECT warehouse.* FROM ya_query102_base_warehouse AS warehouse
WHERE EXISTS (SELECT 1 FROM ya_query102_up_store AS store WHERE store.s_state = warehouse.w_state);

CREATE OR REPLACE TEMP VIEW ya_query102_up_ws AS
SELECT ws.* FROM ya_query102_base_ws AS ws
WHERE EXISTS (SELECT 1 FROM ya_query102_up_d2 AS d2 WHERE ws.ws_sold_date_sk = d2.d_date_sk)
  AND EXISTS (SELECT 1 FROM ya_query102_up_warehouse AS warehouse WHERE ws.ws_warehouse_sk = warehouse.w_warehouse_sk);

CREATE OR REPLACE TEMP VIEW ya_query102_up_ss AS
SELECT ss.* FROM ya_query102_base_ss AS ss
WHERE EXISTS (SELECT 1 FROM ya_query102_up_customer AS customer WHERE ss.ss_customer_sk = customer.c_customer_sk)
  AND EXISTS (SELECT 1 FROM ya_query102_up_d1 AS d1 WHERE ss.ss_sold_date_sk = d1.d_date_sk)
  AND EXISTS (SELECT 1 FROM ya_query102_up_inventory AS inventory WHERE ss.ss_item_sk = inventory.inv_item_sk AND ss.ss_sold_date_sk = inventory.inv_date_sk)
  AND EXISTS (SELECT 1 FROM ya_query102_up_item AS item WHERE ss.ss_item_sk = item.i_item_sk)
  AND EXISTS (SELECT 1 FROM ya_query102_up_ws AS ws WHERE ss.ss_item_sk = ws.ws_item_sk);

CREATE OR REPLACE TEMP VIEW ya_query102_down_ss AS
SELECT ss.* FROM ya_query102_up_ss AS ss;

CREATE OR REPLACE TEMP VIEW ya_query102_down_customer AS
SELECT customer.* FROM ya_query102_up_customer AS customer
WHERE EXISTS (SELECT 1 FROM ya_query102_down_ss AS ss WHERE ss.ss_customer_sk = customer.c_customer_sk);

CREATE OR REPLACE TEMP VIEW ya_query102_down_d1 AS
SELECT d1.* FROM ya_query102_up_d1 AS d1
WHERE EXISTS (SELECT 1 FROM ya_query102_down_ss AS ss WHERE ss.ss_sold_date_sk = d1.d_date_sk);

CREATE OR REPLACE TEMP VIEW ya_query102_down_inventory AS
SELECT inventory.* FROM ya_query102_up_inventory AS inventory
WHERE EXISTS (SELECT 1 FROM ya_query102_down_ss AS ss WHERE ss.ss_item_sk = inventory.inv_item_sk AND ss.ss_sold_date_sk = inventory.inv_date_sk);

CREATE OR REPLACE TEMP VIEW ya_query102_down_item AS
SELECT item.* FROM ya_query102_up_item AS item
WHERE EXISTS (SELECT 1 FROM ya_query102_down_ss AS ss WHERE ss.ss_item_sk = item.i_item_sk);

CREATE OR REPLACE TEMP VIEW ya_query102_down_ws AS
SELECT ws.* FROM ya_query102_up_ws AS ws
WHERE EXISTS (SELECT 1 FROM ya_query102_down_ss AS ss WHERE ss.ss_item_sk = ws.ws_item_sk);

CREATE OR REPLACE TEMP VIEW ya_query102_down_customer_address AS
SELECT customer_address.* FROM ya_query102_up_customer_address AS customer_address
WHERE EXISTS (SELECT 1 FROM ya_query102_down_customer AS customer WHERE customer.c_current_addr_sk = customer_address.ca_address_sk);

CREATE OR REPLACE TEMP VIEW ya_query102_down_customer_demographics AS
SELECT customer_demographics.* FROM ya_query102_up_customer_demographics AS customer_demographics
WHERE EXISTS (SELECT 1 FROM ya_query102_down_customer AS customer WHERE customer.c_current_cdemo_sk = customer_demographics.cd_demo_sk);

CREATE OR REPLACE TEMP VIEW ya_query102_down_household_demographics AS
SELECT household_demographics.* FROM ya_query102_up_household_demographics AS household_demographics
WHERE EXISTS (SELECT 1 FROM ya_query102_down_customer AS customer WHERE customer.c_current_hdemo_sk = household_demographics.hd_demo_sk);

CREATE OR REPLACE TEMP VIEW ya_query102_down_d2 AS
SELECT d2.* FROM ya_query102_up_d2 AS d2
WHERE EXISTS (SELECT 1 FROM ya_query102_down_ws AS ws WHERE ws.ws_sold_date_sk = d2.d_date_sk);

CREATE OR REPLACE TEMP VIEW ya_query102_down_warehouse AS
SELECT warehouse.* FROM ya_query102_up_warehouse AS warehouse
WHERE EXISTS (SELECT 1 FROM ya_query102_down_ws AS ws WHERE ws.ws_warehouse_sk = warehouse.w_warehouse_sk);

CREATE OR REPLACE TEMP VIEW ya_query102_down_store AS
SELECT store.* FROM ya_query102_up_store AS store
WHERE EXISTS (SELECT 1 FROM ya_query102_down_warehouse AS warehouse WHERE store.s_state = warehouse.w_state);

SELECT cd_gender,
       cd_marital_status,
       cd_education_status,
       hd_vehicle_count,
       count(*) as cnt
FROM ya_query102_down_ss AS ss,
     ya_query102_down_ws AS ws,
     ya_query102_down_d1 AS d1,
     ya_query102_down_d2 AS d2,
     ya_query102_down_customer AS customer,
     ya_query102_down_inventory AS inventory,
     ya_query102_down_store AS store,
     ya_query102_down_warehouse AS warehouse,
     ya_query102_down_item AS item,
     ya_query102_down_customer_demographics AS customer_demographics,
     ya_query102_down_household_demographics AS household_demographics,
     ya_query102_down_customer_address AS customer_address
WHERE ss_item_sk = i_item_sk
  AND ws_item_sk = ss_item_sk
  AND ss_sold_date_sk = d1.d_date_sk
  AND ws_sold_date_sk = d2.d_date_sk
  AND d2.d_date BETWEEN d1.d_date AND (d1.d_date + interval '360 day')
  AND ss_customer_sk = c_customer_sk
  AND ws_bill_customer_sk = c_customer_sk
  AND ws_warehouse_sk = inv_warehouse_sk
  AND ws_warehouse_sk = w_warehouse_sk
  AND inv_item_sk = ss_item_sk
  AND inv_date_sk = ss_sold_date_sk
  AND inv_quantity_on_hand >= ss_quantity
  AND s_state = w_state
  AND i_category IN ('Electronics', 'Sports', 'Books')                   
  AND i_manager_id IN (15, 23, 47, 52, 68, 71, 84, 89, 93, 96)          
  AND c_current_cdemo_sk = cd_demo_sk
  AND c_current_hdemo_sk = hd_demo_sk
  AND c_current_addr_sk = ca_address_sk
  AND ca_state IN ('CA', 'TX', 'NY', 'FL', 'IL')                        
  AND d1.d_year = 2000                                               
  AND ws_wholesale_cost BETWEEN 0 AND 75                               
GROUP BY cd_gender, cd_marital_status, cd_education_status, hd_vehicle_count;
