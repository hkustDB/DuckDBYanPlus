create or replace view t_date as select d_date_sk from date_dim where d_month_seq between 1190 and 1213;
create or replace view t_warehouse as select w_warehouse_sk, w_warehouse_name from warehouse where w_gmt_offset = -6;
create or replace view t_ship_mode as select sm_ship_mode_sk, sm_type from ship_mode where sm_type = 'EXPRESS';
create or replace view t_call_center as select cc_call_center_sk, cc_name from call_center where cc_class = 'large';
select min(w_warehouse_name),
       min(sm_type),
       min(cc_name),
       min(cs_order_number),
       min(cs_item_sk)
from catalog_sales,
     t_warehouse,
     t_ship_mode,
     t_call_center,
     t_date
where cs_ship_date_sk = d_date_sk
  and cs_warehouse_sk = w_warehouse_sk
  and cs_ship_mode_sk = sm_ship_mode_sk
  and cs_call_center_sk = cc_call_center_sk
  and cs_list_price between 145 and 155;
