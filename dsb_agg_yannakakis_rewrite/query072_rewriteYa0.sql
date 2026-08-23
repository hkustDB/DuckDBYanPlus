-- Generated exact two-pass DSB reducer for dsb_agg/query072.

-- Round 3 uses the checked local Yannakakis+ aggregation/projection SQL.

CREATE OR REPLACE TEMP VIEW ya_query072_base_catalog_sales AS
SELECT catalog_sales.* FROM catalog_sales AS catalog_sales;

CREATE OR REPLACE TEMP VIEW ya_query072_base_inventory AS
SELECT inventory.* FROM inventory AS inventory;

CREATE OR REPLACE TEMP VIEW ya_query072_base_warehouse AS
SELECT warehouse.* FROM warehouse AS warehouse;

CREATE OR REPLACE TEMP VIEW ya_query072_base_item AS
SELECT item.* FROM item AS item;

CREATE OR REPLACE TEMP VIEW ya_query072_base_customer_demographics AS
SELECT customer_demographics.* FROM customer_demographics AS customer_demographics;

CREATE OR REPLACE TEMP VIEW ya_query072_base_household_demographics AS
SELECT household_demographics.* FROM household_demographics AS household_demographics;

CREATE OR REPLACE TEMP VIEW ya_query072_base_d1 AS
SELECT d1.* FROM date_dim AS d1;

CREATE OR REPLACE TEMP VIEW ya_query072_base_d2 AS
SELECT d2.* FROM date_dim AS d2;

CREATE OR REPLACE TEMP VIEW ya_query072_base_d3 AS
SELECT d3.* FROM date_dim AS d3;

CREATE OR REPLACE TEMP VIEW ya_query072_base_promotion AS
SELECT promotion.* FROM promotion AS promotion;

CREATE OR REPLACE TEMP VIEW ya_query072_base_catalog_returns AS
SELECT catalog_returns.* FROM catalog_returns AS catalog_returns;

CREATE OR REPLACE TEMP VIEW ya_query072_up_catalog_returns AS
SELECT catalog_returns.* FROM ya_query072_base_catalog_returns AS catalog_returns;

CREATE OR REPLACE TEMP VIEW ya_query072_up_customer_demographics AS
SELECT customer_demographics.* FROM ya_query072_base_customer_demographics AS customer_demographics;

CREATE OR REPLACE TEMP VIEW ya_query072_up_d1 AS
SELECT d1.* FROM ya_query072_base_d1 AS d1;

CREATE OR REPLACE TEMP VIEW ya_query072_up_d3 AS
SELECT d3.* FROM ya_query072_base_d3 AS d3;

CREATE OR REPLACE TEMP VIEW ya_query072_up_household_demographics AS
SELECT household_demographics.* FROM ya_query072_base_household_demographics AS household_demographics;

CREATE OR REPLACE TEMP VIEW ya_query072_up_d2 AS
SELECT d2.* FROM ya_query072_base_d2 AS d2;

CREATE OR REPLACE TEMP VIEW ya_query072_up_warehouse AS
SELECT warehouse.* FROM ya_query072_base_warehouse AS warehouse;

CREATE OR REPLACE TEMP VIEW ya_query072_up_inventory AS
SELECT inventory.* FROM ya_query072_base_inventory AS inventory
WHERE EXISTS (SELECT 1 FROM ya_query072_up_d2 AS d2 WHERE inventory.inv_date_sk = d2.d_date_sk)
  AND EXISTS (SELECT 1 FROM ya_query072_up_warehouse AS warehouse WHERE inventory.inv_warehouse_sk = warehouse.w_warehouse_sk);

CREATE OR REPLACE TEMP VIEW ya_query072_up_item AS
SELECT item.* FROM ya_query072_base_item AS item;

CREATE OR REPLACE TEMP VIEW ya_query072_up_promotion AS
SELECT promotion.* FROM ya_query072_base_promotion AS promotion;

CREATE OR REPLACE TEMP VIEW ya_query072_up_catalog_sales AS
SELECT catalog_sales.* FROM ya_query072_base_catalog_sales AS catalog_sales
WHERE EXISTS (SELECT 1 FROM ya_query072_up_catalog_returns AS catalog_returns WHERE catalog_sales.cs_item_sk = catalog_returns.cr_item_sk AND catalog_sales.cs_order_number = catalog_returns.cr_order_number)
  AND EXISTS (SELECT 1 FROM ya_query072_up_customer_demographics AS customer_demographics WHERE catalog_sales.cs_bill_cdemo_sk = customer_demographics.cd_demo_sk)
  AND EXISTS (SELECT 1 FROM ya_query072_up_d1 AS d1 WHERE catalog_sales.cs_sold_date_sk = d1.d_date_sk)
  AND EXISTS (SELECT 1 FROM ya_query072_up_d3 AS d3 WHERE catalog_sales.cs_ship_date_sk = d3.d_date_sk)
  AND EXISTS (SELECT 1 FROM ya_query072_up_household_demographics AS household_demographics WHERE catalog_sales.cs_bill_hdemo_sk = household_demographics.hd_demo_sk)
  AND EXISTS (SELECT 1 FROM ya_query072_up_inventory AS inventory WHERE catalog_sales.cs_item_sk = inventory.inv_item_sk)
  AND EXISTS (SELECT 1 FROM ya_query072_up_item AS item WHERE catalog_sales.cs_item_sk = item.i_item_sk)
  AND EXISTS (SELECT 1 FROM ya_query072_up_promotion AS promotion WHERE catalog_sales.cs_promo_sk = promotion.p_promo_sk);

CREATE OR REPLACE TEMP VIEW ya_query072_down_catalog_sales AS
SELECT catalog_sales.* FROM ya_query072_up_catalog_sales AS catalog_sales;

CREATE OR REPLACE TEMP VIEW ya_query072_down_catalog_returns AS
SELECT catalog_returns.* FROM ya_query072_up_catalog_returns AS catalog_returns
WHERE EXISTS (SELECT 1 FROM ya_query072_down_catalog_sales AS catalog_sales WHERE catalog_sales.cs_item_sk = catalog_returns.cr_item_sk AND catalog_sales.cs_order_number = catalog_returns.cr_order_number);

CREATE OR REPLACE TEMP VIEW ya_query072_down_customer_demographics AS
SELECT customer_demographics.* FROM ya_query072_up_customer_demographics AS customer_demographics
WHERE EXISTS (SELECT 1 FROM ya_query072_down_catalog_sales AS catalog_sales WHERE catalog_sales.cs_bill_cdemo_sk = customer_demographics.cd_demo_sk);

CREATE OR REPLACE TEMP VIEW ya_query072_down_d1 AS
SELECT d1.* FROM ya_query072_up_d1 AS d1
WHERE EXISTS (SELECT 1 FROM ya_query072_down_catalog_sales AS catalog_sales WHERE catalog_sales.cs_sold_date_sk = d1.d_date_sk);

CREATE OR REPLACE TEMP VIEW ya_query072_down_d3 AS
SELECT d3.* FROM ya_query072_up_d3 AS d3
WHERE EXISTS (SELECT 1 FROM ya_query072_down_catalog_sales AS catalog_sales WHERE catalog_sales.cs_ship_date_sk = d3.d_date_sk);

CREATE OR REPLACE TEMP VIEW ya_query072_down_household_demographics AS
SELECT household_demographics.* FROM ya_query072_up_household_demographics AS household_demographics
WHERE EXISTS (SELECT 1 FROM ya_query072_down_catalog_sales AS catalog_sales WHERE catalog_sales.cs_bill_hdemo_sk = household_demographics.hd_demo_sk);

CREATE OR REPLACE TEMP VIEW ya_query072_down_inventory AS
SELECT inventory.* FROM ya_query072_up_inventory AS inventory
WHERE EXISTS (SELECT 1 FROM ya_query072_down_catalog_sales AS catalog_sales WHERE catalog_sales.cs_item_sk = inventory.inv_item_sk);

CREATE OR REPLACE TEMP VIEW ya_query072_down_item AS
SELECT item.* FROM ya_query072_up_item AS item
WHERE EXISTS (SELECT 1 FROM ya_query072_down_catalog_sales AS catalog_sales WHERE catalog_sales.cs_item_sk = item.i_item_sk);

CREATE OR REPLACE TEMP VIEW ya_query072_down_promotion AS
SELECT promotion.* FROM ya_query072_up_promotion AS promotion
WHERE EXISTS (SELECT 1 FROM ya_query072_down_catalog_sales AS catalog_sales WHERE catalog_sales.cs_promo_sk = promotion.p_promo_sk);

CREATE OR REPLACE TEMP VIEW ya_query072_down_d2 AS
SELECT d2.* FROM ya_query072_up_d2 AS d2
WHERE EXISTS (SELECT 1 FROM ya_query072_down_inventory AS inventory WHERE inventory.inv_date_sk = d2.d_date_sk);

CREATE OR REPLACE TEMP VIEW ya_query072_down_warehouse AS
SELECT warehouse.* FROM ya_query072_up_warehouse AS warehouse
WHERE EXISTS (SELECT 1 FROM ya_query072_down_inventory AS inventory WHERE inventory.inv_warehouse_sk = warehouse.w_warehouse_sk);

select i_item_desc
      ,w_warehouse_name
      ,d1.d_week_seq
      ,count(*) total_cnt
FROM ya_query072_down_catalog_sales AS catalog_sales
JOIN ya_query072_down_inventory AS inventory ON (cs_item_sk = inv_item_sk)
JOIN ya_query072_down_warehouse AS warehouse ON (w_warehouse_sk = inv_warehouse_sk)
JOIN ya_query072_down_item AS item ON (i_item_sk = cs_item_sk)
JOIN ya_query072_down_customer_demographics AS customer_demographics ON (cs_bill_cdemo_sk = cd_demo_sk)
JOIN ya_query072_down_household_demographics AS household_demographics ON (cs_bill_hdemo_sk = hd_demo_sk)
JOIN ya_query072_down_d1 AS d1 ON (cs_sold_date_sk = d1.d_date_sk)
JOIN ya_query072_down_d2 AS d2 ON (inv_date_sk = d2.d_date_sk)
JOIN ya_query072_down_d3 AS d3 ON (cs_ship_date_sk = d3.d_date_sk)
JOIN ya_query072_down_promotion AS promotion ON (cs_promo_sk = p_promo_sk)
JOIN ya_query072_down_catalog_returns AS catalog_returns ON (cr_item_sk = cs_item_sk AND cr_order_number = cs_order_number)
WHERE d1.d_week_seq = d2.d_week_seq
  AND inv_quantity_on_hand < cs_quantity
  AND d3.d_date > d1.d_date + interval '3 day'
  AND hd_buy_potential = '1001-5000'                          
  AND d1.d_year = 2001                                        
  AND cd_marital_status = 'M'                                 
  AND cd_dep_count BETWEEN 2 AND 5                           
  AND i_category IN ('Electronics', 'Sports', 'Books')        
  AND cs_wholesale_cost BETWEEN 35 AND 55                    
GROUP BY i_item_desc, w_warehouse_name, d1.d_week_seq;
