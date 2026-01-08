SELECT cd_gender,
       cd_marital_status,
       cd_education_status,
       hd_vehicle_count,
       count(*) as cnt
FROM store_sales ss,
     web_sales ws,
     date_dim d1,
     date_dim d2,
     customer,
     inventory,
     store,
     warehouse,
     item,
     customer_demographics,
     household_demographics,
     customer_address
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