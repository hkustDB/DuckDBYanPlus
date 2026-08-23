-- Generated exact two-pass DSB reducer for dsb_spj/query018.

-- Round 3 uses the checked local Yannakakis+ aggregation/projection SQL.

CREATE OR REPLACE TEMP VIEW ya_query018_base_catalog_sales AS
SELECT catalog_sales.* FROM catalog_sales AS catalog_sales;

CREATE OR REPLACE TEMP VIEW ya_query018_base_customer_demographics AS
SELECT customer_demographics.* FROM customer_demographics AS customer_demographics;

CREATE OR REPLACE TEMP VIEW ya_query018_base_customer AS
SELECT customer.* FROM customer AS customer;

CREATE OR REPLACE TEMP VIEW ya_query018_base_customer_address AS
SELECT customer_address.* FROM customer_address AS customer_address;

CREATE OR REPLACE TEMP VIEW ya_query018_base_date_dim AS
SELECT date_dim.* FROM date_dim AS date_dim;

CREATE OR REPLACE TEMP VIEW ya_query018_base_item AS
SELECT item.* FROM item AS item;

CREATE OR REPLACE TEMP VIEW ya_query018_up_customer_address AS
SELECT customer_address.* FROM ya_query018_base_customer_address AS customer_address;

CREATE OR REPLACE TEMP VIEW ya_query018_up_customer AS
SELECT customer.* FROM ya_query018_base_customer AS customer
WHERE EXISTS (SELECT 1 FROM ya_query018_up_customer_address AS customer_address WHERE customer.c_current_addr_sk = customer_address.ca_address_sk);

CREATE OR REPLACE TEMP VIEW ya_query018_up_customer_demographics AS
SELECT customer_demographics.* FROM ya_query018_base_customer_demographics AS customer_demographics;

CREATE OR REPLACE TEMP VIEW ya_query018_up_date_dim AS
SELECT date_dim.* FROM ya_query018_base_date_dim AS date_dim;

CREATE OR REPLACE TEMP VIEW ya_query018_up_item AS
SELECT item.* FROM ya_query018_base_item AS item;

CREATE OR REPLACE TEMP VIEW ya_query018_up_catalog_sales AS
SELECT catalog_sales.* FROM ya_query018_base_catalog_sales AS catalog_sales
WHERE EXISTS (SELECT 1 FROM ya_query018_up_customer AS customer WHERE catalog_sales.cs_bill_customer_sk = customer.c_customer_sk)
  AND EXISTS (SELECT 1 FROM ya_query018_up_customer_demographics AS customer_demographics WHERE catalog_sales.cs_bill_cdemo_sk = customer_demographics.cd_demo_sk)
  AND EXISTS (SELECT 1 FROM ya_query018_up_date_dim AS date_dim WHERE catalog_sales.cs_sold_date_sk = date_dim.d_date_sk)
  AND EXISTS (SELECT 1 FROM ya_query018_up_item AS item WHERE catalog_sales.cs_item_sk = item.i_item_sk);

CREATE OR REPLACE TEMP VIEW ya_query018_down_catalog_sales AS
SELECT catalog_sales.* FROM ya_query018_up_catalog_sales AS catalog_sales;

CREATE OR REPLACE TEMP VIEW ya_query018_down_customer AS
SELECT customer.* FROM ya_query018_up_customer AS customer
WHERE EXISTS (SELECT 1 FROM ya_query018_down_catalog_sales AS catalog_sales WHERE catalog_sales.cs_bill_customer_sk = customer.c_customer_sk);

CREATE OR REPLACE TEMP VIEW ya_query018_down_customer_demographics AS
SELECT customer_demographics.* FROM ya_query018_up_customer_demographics AS customer_demographics
WHERE EXISTS (SELECT 1 FROM ya_query018_down_catalog_sales AS catalog_sales WHERE catalog_sales.cs_bill_cdemo_sk = customer_demographics.cd_demo_sk);

CREATE OR REPLACE TEMP VIEW ya_query018_down_date_dim AS
SELECT date_dim.* FROM ya_query018_up_date_dim AS date_dim
WHERE EXISTS (SELECT 1 FROM ya_query018_down_catalog_sales AS catalog_sales WHERE catalog_sales.cs_sold_date_sk = date_dim.d_date_sk);

CREATE OR REPLACE TEMP VIEW ya_query018_down_item AS
SELECT item.* FROM ya_query018_up_item AS item
WHERE EXISTS (SELECT 1 FROM ya_query018_down_catalog_sales AS catalog_sales WHERE catalog_sales.cs_item_sk = item.i_item_sk);

CREATE OR REPLACE TEMP VIEW ya_query018_down_customer_address AS
SELECT customer_address.* FROM ya_query018_up_customer_address AS customer_address
WHERE EXISTS (SELECT 1 FROM ya_query018_down_customer AS customer WHERE customer.c_current_addr_sk = customer_address.ca_address_sk);

create or replace view t1 as select ca_country, ca_state, ca_county, c_birth_year, c_customer_sk from ya_query018_down_customer_address AS customer_address, ya_query018_down_customer AS customer where c_current_addr_sk = ca_address_sk and ca_state in ('CA', 'TX', 'NY') and c_birth_month = 8;
create or replace view t2 as select cd_demo_sk, min(cd_dep_count) as cd_dep_count from ya_query018_down_customer_demographics AS customer_demographics WHERE cd_gender = 'M' and cd_education_status = 'College' group by cd_demo_sk;
create or replace view t3 as select i_item_sk, min(i_item_id) as i_item_id from ya_query018_down_item AS item where i_category = 'Electronics' group by i_item_sk;
select min(i_item_id), min(ca_country), min(ca_state),
       min(ca_county),
       min(cs_quantity),
       min(cs_list_price),
       min(cs_coupon_amt),
       min(cs_sales_price),
       min(cs_net_profit),
       min(c_birth_year),
       min(cd_dep_count)
from ya_query018_down_catalog_sales AS catalog_sales, ya_query018_down_date_dim AS date_dim, t1, t2, t3
where cs_sold_date_sk = d_date_sk
    and cs_item_sk = t3.i_item_sk
    and cs_bill_cdemo_sk = t2.cd_demo_sk
    and cs_bill_customer_sk = t1.c_customer_sk
    and d_year = 2001
    and cs_wholesale_cost between 0 and 77.5;
