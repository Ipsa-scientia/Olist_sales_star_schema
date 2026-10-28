

with results as (

    -- 1. Row counts
    select
        'fact_order_items: row count' as check_name,
        112650 as expected,
        (select count(*) from marts.fact_order_items) as actual

    union all
    select
        'dim_customers: row count',
        96096,
        (select count(*) from marts.dim_customers)

    union all
    select
        'dim_products: row count',
        32951,
        (select count(*) from marts.dim_products)

    union all
    select
        'dim_sellers: row count',
        3095,
        (select count(*) from marts.dim_sellers)

    union all
    select
        'dim_date: row count',
        1096,
        (select count(*) from marts.dim_date)

    -- 2. Unique primary keys (number of duplicated keys)
    union all
    select
        'fact_order_items: duplicate keys',
        0,
        (select count(*) from (
            select order_id, order_item_id
            from marts.fact_order_items
            group by order_id, order_item_id
            having count(*) > 1
        ) as duplicates)

    union all
    select
        'dim_customers: duplicate keys',
        0,
        (select count(*) from (
            select customer_unique_id
            from marts.dim_customers
            group by customer_unique_id
            having count(*) > 1
        ) as duplicates)

    union all
    select
        'dim_products: duplicate keys',
        0,
        (select count(*) from (
            select product_id
            from marts.dim_products
            group by product_id
            having count(*) > 1
        ) as duplicates)

    union all
    select
        'dim_sellers: duplicate keys',
        0,
        (select count(*) from (
            select seller_id
            from marts.dim_sellers
            group by seller_id
            having count(*) > 1
        ) as duplicates)

    union all
    select
        'dim_date: duplicate keys',
        0,
        (select count(*) from (
            select date_day
            from marts.dim_date
            group by date_day
            having count(*) > 1
        ) as duplicates)

    -- 3. No lost revenue (difference between fact and staging)
    union all
    select
        'fact_order_items: price difference to staging',
        0,
        (select sum(price) from marts.fact_order_items)
        - (select sum(price) from staging.stg_order_items)

    -- 4. No orphan keys (fact rows without a matching dimension row)
    union all
    select
        'orphans: customer_unique_id',
        0,
        (select count(*)
         from marts.fact_order_items as f
         left join marts.dim_customers as d
             on f.customer_unique_id = d.customer_unique_id
         where d.customer_unique_id is null)

    union all
    select
        'orphans: product_id',
        0,
        (select count(*)
         from marts.fact_order_items as f
         left join marts.dim_products as d
             on f.product_id = d.product_id
         where d.product_id is null)

    union all
    select
        'orphans: seller_id',
        0,
        (select count(*)
         from marts.fact_order_items as f
         left join marts.dim_sellers as d
             on f.seller_id = d.seller_id
         where d.seller_id is null)

    -- 5. Date coverage (orphan check for the date key)
    union all
    select
        'orphans: purchase_date',
        0,
        (select count(*)
         from marts.fact_order_items as f
         left join marts.dim_date as d
             on f.purchase_date = d.date_day
         where d.date_day is null)

    -- 6. Late flag is NULL exactly when there is no delivery date
    union all
    select
        'is_late: NULL rows minus rows without delivery date',
        0,
        (select count(*) from marts.fact_order_items where is_late is null)
        - (select count(*) from marts.fact_order_items where delivered_to_customer_at is null)

)

select
    check_name,
    expected,
    actual,
    expected = actual as passed

from results

order by passed, check_name