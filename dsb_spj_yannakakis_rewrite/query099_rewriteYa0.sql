-- Generated exact two-pass DSB reducer for dsb_spj/query099.

-- Round 3 uses the checked local Yannakakis+ aggregation/projection SQL.

CREATE OR REPLACE TEMP VIEW ya_query099_base_catalog_sales AS
SELECT catalog_sales.* FROM catalog_sales AS catalog_sales;

CREATE OR REPLACE TEMP VIEW ya_query099_base_warehouse AS
SELECT warehouse.* FROM warehouse AS warehouse;

CREATE OR REPLACE TEMP VIEW ya_query099_base_ship_mode AS
SELECT ship_mode.* FROM ship_mode AS ship_mode;

CREATE OR REPLACE TEMP VIEW ya_query099_base_call_center AS
SELECT call_center.* FROM call_center AS call_center;

CREATE OR REPLACE TEMP VIEW ya_query099_base_date_dim AS
SELECT date_dim.* FROM date_dim AS date_dim;

CREATE OR REPLACE TEMP VIEW ya_query099_up_call_center AS
SELECT call_center.* FROM ya_query099_base_call_center AS call_center;

CREATE OR REPLACE TEMP VIEW ya_query099_up_date_dim AS
SELECT date_dim.* FROM ya_query099_base_date_dim AS date_dim;

CREATE OR REPLACE TEMP VIEW ya_query099_up_ship_mode AS
SELECT ship_mode.* FROM ya_query099_base_ship_mode AS ship_mode;

CREATE OR REPLACE TEMP VIEW ya_query099_up_warehouse AS
SELECT warehouse.* FROM ya_query099_base_warehouse AS warehouse;

CREATE OR REPLACE TEMP VIEW ya_query099_up_catalog_sales AS
SELECT catalog_sales.* FROM ya_query099_base_catalog_sales AS catalog_sales
WHERE EXISTS (SELECT 1 FROM ya_query099_up_call_center AS call_center WHERE catalog_sales.cs_call_center_sk = call_center.cc_call_center_sk)
  AND EXISTS (SELECT 1 FROM ya_query099_up_date_dim AS date_dim WHERE catalog_sales.cs_ship_date_sk = date_dim.d_date_sk)
  AND EXISTS (SELECT 1 FROM ya_query099_up_ship_mode AS ship_mode WHERE catalog_sales.cs_ship_mode_sk = ship_mode.sm_ship_mode_sk)
  AND EXISTS (SELECT 1 FROM ya_query099_up_warehouse AS warehouse WHERE catalog_sales.cs_warehouse_sk = warehouse.w_warehouse_sk);

CREATE OR REPLACE TEMP VIEW ya_query099_down_catalog_sales AS
SELECT catalog_sales.* FROM ya_query099_up_catalog_sales AS catalog_sales;

CREATE OR REPLACE TEMP VIEW ya_query099_down_call_center AS
SELECT call_center.* FROM ya_query099_up_call_center AS call_center
WHERE EXISTS (SELECT 1 FROM ya_query099_down_catalog_sales AS catalog_sales WHERE catalog_sales.cs_call_center_sk = call_center.cc_call_center_sk);

CREATE OR REPLACE TEMP VIEW ya_query099_down_date_dim AS
SELECT date_dim.* FROM ya_query099_up_date_dim AS date_dim
WHERE EXISTS (SELECT 1 FROM ya_query099_down_catalog_sales AS catalog_sales WHERE catalog_sales.cs_ship_date_sk = date_dim.d_date_sk);

CREATE OR REPLACE TEMP VIEW ya_query099_down_ship_mode AS
SELECT ship_mode.* FROM ya_query099_up_ship_mode AS ship_mode
WHERE EXISTS (SELECT 1 FROM ya_query099_down_catalog_sales AS catalog_sales WHERE catalog_sales.cs_ship_mode_sk = ship_mode.sm_ship_mode_sk);

CREATE OR REPLACE TEMP VIEW ya_query099_down_warehouse AS
SELECT warehouse.* FROM ya_query099_up_warehouse AS warehouse
WHERE EXISTS (SELECT 1 FROM ya_query099_down_catalog_sales AS catalog_sales WHERE catalog_sales.cs_warehouse_sk = warehouse.w_warehouse_sk);

create or replace view t_date as select d_date_sk from ya_query099_down_date_dim AS date_dim where d_month_seq between 1190 and 1213;
create or replace view t_warehouse as select w_warehouse_sk, w_warehouse_name from ya_query099_down_warehouse AS warehouse where w_gmt_offset = -6;
create or replace view t_ship_mode as select sm_ship_mode_sk, sm_type from ya_query099_down_ship_mode AS ship_mode where sm_type = 'EXPRESS';
create or replace view t_call_center as select cc_call_center_sk, cc_name from ya_query099_down_call_center AS call_center where cc_class = 'large';
select min(w_warehouse_name),
       min(sm_type),
       min(cc_name),
       min(cs_order_number),
       min(cs_item_sk)
from ya_query099_down_catalog_sales AS catalog_sales,
     t_warehouse,
     t_ship_mode,
     t_call_center,
     t_date
where cs_ship_date_sk = d_date_sk
  and cs_warehouse_sk = w_warehouse_sk
  and cs_ship_mode_sk = sm_ship_mode_sk
  and cs_call_center_sk = cc_call_center_sk
  and cs_list_price between 145 and 155;
