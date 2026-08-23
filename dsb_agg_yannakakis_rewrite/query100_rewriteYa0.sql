-- Generated exact two-pass DSB reducer for dsb_agg/query100.

-- Round 3 uses the checked local Yannakakis+ aggregation/projection SQL.

CREATE OR REPLACE TEMP VIEW ya_query100_base_s1 AS
SELECT s1.* FROM store_sales AS s1;

CREATE OR REPLACE TEMP VIEW ya_query100_base_s2 AS
SELECT s2.* FROM store_sales AS s2;

CREATE OR REPLACE TEMP VIEW ya_query100_base_item1 AS
SELECT item1.* FROM item AS item1;

CREATE OR REPLACE TEMP VIEW ya_query100_base_item2 AS
SELECT item2.* FROM item AS item2;

CREATE OR REPLACE TEMP VIEW ya_query100_base_date_dim AS
SELECT date_dim.* FROM date_dim AS date_dim;

CREATE OR REPLACE TEMP VIEW ya_query100_base_customer AS
SELECT customer.* FROM customer AS customer;

CREATE OR REPLACE TEMP VIEW ya_query100_base_customer_address AS
SELECT customer_address.* FROM customer_address AS customer_address;

CREATE OR REPLACE TEMP VIEW ya_query100_base_customer_demographics AS
SELECT customer_demographics.* FROM customer_demographics AS customer_demographics;

CREATE OR REPLACE TEMP VIEW ya_query100_up_customer_address AS
SELECT customer_address.* FROM ya_query100_base_customer_address AS customer_address;

CREATE OR REPLACE TEMP VIEW ya_query100_up_customer_demographics AS
SELECT customer_demographics.* FROM ya_query100_base_customer_demographics AS customer_demographics;

CREATE OR REPLACE TEMP VIEW ya_query100_up_customer AS
SELECT customer.* FROM ya_query100_base_customer AS customer
WHERE EXISTS (SELECT 1 FROM ya_query100_up_customer_address AS customer_address WHERE customer.c_current_addr_sk = customer_address.ca_address_sk)
  AND EXISTS (SELECT 1 FROM ya_query100_up_customer_demographics AS customer_demographics WHERE customer.c_current_cdemo_sk = customer_demographics.cd_demo_sk);

CREATE OR REPLACE TEMP VIEW ya_query100_up_date_dim AS
SELECT date_dim.* FROM ya_query100_base_date_dim AS date_dim;

CREATE OR REPLACE TEMP VIEW ya_query100_up_item1 AS
SELECT item1.* FROM ya_query100_base_item1 AS item1;

CREATE OR REPLACE TEMP VIEW ya_query100_up_item2 AS
SELECT item2.* FROM ya_query100_base_item2 AS item2;

CREATE OR REPLACE TEMP VIEW ya_query100_up_s2 AS
SELECT s2.* FROM ya_query100_base_s2 AS s2
WHERE EXISTS (SELECT 1 FROM ya_query100_up_item2 AS item2 WHERE s2.ss_item_sk = item2.i_item_sk);

CREATE OR REPLACE TEMP VIEW ya_query100_up_s1 AS
SELECT s1.* FROM ya_query100_base_s1 AS s1
WHERE EXISTS (SELECT 1 FROM ya_query100_up_customer AS customer WHERE s1.ss_customer_sk = customer.c_customer_sk)
  AND EXISTS (SELECT 1 FROM ya_query100_up_date_dim AS date_dim WHERE s1.ss_sold_date_sk = date_dim.d_date_sk)
  AND EXISTS (SELECT 1 FROM ya_query100_up_item1 AS item1 WHERE s1.ss_item_sk = item1.i_item_sk)
  AND EXISTS (SELECT 1 FROM ya_query100_up_s2 AS s2 WHERE s1.ss_ticket_number = s2.ss_ticket_number);

CREATE OR REPLACE TEMP VIEW ya_query100_down_s1 AS
SELECT s1.* FROM ya_query100_up_s1 AS s1;

CREATE OR REPLACE TEMP VIEW ya_query100_down_customer AS
SELECT customer.* FROM ya_query100_up_customer AS customer
WHERE EXISTS (SELECT 1 FROM ya_query100_down_s1 AS s1 WHERE s1.ss_customer_sk = customer.c_customer_sk);

CREATE OR REPLACE TEMP VIEW ya_query100_down_date_dim AS
SELECT date_dim.* FROM ya_query100_up_date_dim AS date_dim
WHERE EXISTS (SELECT 1 FROM ya_query100_down_s1 AS s1 WHERE s1.ss_sold_date_sk = date_dim.d_date_sk);

CREATE OR REPLACE TEMP VIEW ya_query100_down_item1 AS
SELECT item1.* FROM ya_query100_up_item1 AS item1
WHERE EXISTS (SELECT 1 FROM ya_query100_down_s1 AS s1 WHERE s1.ss_item_sk = item1.i_item_sk);

CREATE OR REPLACE TEMP VIEW ya_query100_down_s2 AS
SELECT s2.* FROM ya_query100_up_s2 AS s2
WHERE EXISTS (SELECT 1 FROM ya_query100_down_s1 AS s1 WHERE s1.ss_ticket_number = s2.ss_ticket_number);

CREATE OR REPLACE TEMP VIEW ya_query100_down_customer_address AS
SELECT customer_address.* FROM ya_query100_up_customer_address AS customer_address
WHERE EXISTS (SELECT 1 FROM ya_query100_down_customer AS customer WHERE customer.c_current_addr_sk = customer_address.ca_address_sk);

CREATE OR REPLACE TEMP VIEW ya_query100_down_customer_demographics AS
SELECT customer_demographics.* FROM ya_query100_up_customer_demographics AS customer_demographics
WHERE EXISTS (SELECT 1 FROM ya_query100_down_customer AS customer WHERE customer.c_current_cdemo_sk = customer_demographics.cd_demo_sk);

CREATE OR REPLACE TEMP VIEW ya_query100_down_item2 AS
SELECT item2.* FROM ya_query100_up_item2 AS item2
WHERE EXISTS (SELECT 1 FROM ya_query100_down_s2 AS s2 WHERE s2.ss_item_sk = item2.i_item_sk);

create or replace view t1 as select c_customer_sk, count(*) as annot from ya_query100_down_customer AS customer, ya_query100_down_customer_address AS customer_address, ya_query100_down_customer_demographics AS customer_demographics where c_current_addr_sk = ca_address_sk and c_current_cdemo_sk = cd_demo_sk and cd_marital_status = 'M' and cd_education_status = 'College' group by c_customer_sk;
select item1.i_item_sk, 
       item2.i_item_sk, 
       sum(annot) as cnt
from ya_query100_down_item1 AS item1,
        ya_query100_down_item2 AS item2,
        ya_query100_down_s1 AS s1,
        ya_query100_down_s2 AS s2,
        ya_query100_down_date_dim AS date_dim,
        t1
where item1.i_item_sk < item2.i_item_sk
    and s1.ss_ticket_number = s2.ss_ticket_number
    and s1.ss_item_sk = item1.i_item_sk
    and s2.ss_item_sk = item2.i_item_sk
    and s1.ss_customer_sk = t1.c_customer_sk
    and date_dim.d_year between 1999 and 2000
    and date_dim.d_date_sk = s1.ss_sold_date_sk
    and item1.i_category in ('Electronics', 'Sports')
    and item2.i_manager_id between 35 and 55
    and s1.ss_list_price between 147.5 and 152.5
    and s2.ss_list_price between 147.5 and 152.5
group by item1.i_item_sk, item2.i_item_sk;
