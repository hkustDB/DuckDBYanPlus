-- Generated exact two-pass DSB reducer for dsb_spj/query072.

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

create or replace view t1 as select inv_date_sk, inv_item_sk, inv_quantity_on_hand, inv_quantity_on_hand, w_warehouse_name from ya_query072_down_inventory AS inventory join ya_query072_down_warehouse AS warehouse on inv_warehouse_sk = w_warehouse_sk;
create or replace view t2 as select i_item_sk, min(i_category) as i_category from ya_query072_down_item AS item where i_category IN ('Electronics', 'Sports', 'Books') group by i_item_sk ;
select min(i_item_sk),
       min(w_warehouse_name),
       min(d1.d_week_seq),
       min(cs_item_sk),
       min(cs_order_number),
       min(inv_item_sk)
from ya_query072_down_catalog_sales AS catalog_sales
join t1 on cs_item_sk = inv_item_sk
join t2 on i_item_sk = cs_item_sk
join ya_query072_down_customer_demographics AS customer_demographics on cs_bill_cdemo_sk = cd_demo_sk
join ya_query072_down_household_demographics AS household_demographics on cs_bill_hdemo_sk = hd_demo_sk
join ya_query072_down_d1 AS d1 on cs_sold_date_sk = d1.d_date_sk
join ya_query072_down_d2 AS d2 on inv_date_sk = d2.d_date_sk
join ya_query072_down_d3 AS d3 on cs_ship_date_sk = d3.d_date_sk
join ya_query072_down_promotion AS promotion on cs_promo_sk = p_promo_sk
join ya_query072_down_catalog_returns AS catalog_returns on cr_item_sk = cs_item_sk and cr_order_number = cs_order_number
where d1.d_week_seq = d2.d_week_seq
    and inv_quantity_on_hand < cs_quantity
    and d3.d_date > d1.d_date + interval '3 day'
    and hd_buy_potential = '1001-5000'
    and d1.d_year = 2001
    and cd_marital_status = 'M'
    and cd_dep_count between 2 and 5
    and cs_wholesale_cost between 35 and 55;
