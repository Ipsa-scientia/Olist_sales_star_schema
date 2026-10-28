/*
Fact table of sold order items.

The grain is one row per item in an order. The primary key is the combination
of order_id and order_item_id. The expected result is 112,650 rows, the same
as stg_order_items.

The foreign keys point to the four dimensions.
customer_unique_id points to dim_customers. The order items contain no
customer information, so it is reached through stg_orders (customer_id)
and stg_customers (customer_unique_id).
product_id points to dim_products.
seller_id points to dim_sellers.
purchase_date points to dim_date.

The measures price, freight_value, and item_total are at item level and
can be summed directly.

The order columns (status, dates, delivery_days, is_late, review_score)
belong to the order and are repeated for every item of that order. They are
not additive across items. For averages per order, first reduce the rows to
one per order.

delivery_days is the number of calendar days from the purchase date to the
date of delivery to the customer. is_late is true when the delivery date is
after the estimated delivery date; a delivery on the estimated day is on time.
Both are NULL when the order has no delivery date.

review_score comes from int_order_reviews_latest, which has one review per
order. Orders without a review get NULL.

Join types
Items to orders and orders to customers are inner joins. Every item belongs
to an order, and every order has exactly one customer, so no item is lost.
Orders to reviews is a left join, because not every order has a review.
None of the joins can create extra rows, because each joined model has at
most one row per key.
*/

with order_items as (

    select * from {{ ref('stg_order_items') }}

),

orders as (

    select * from {{ ref('stg_orders') }}

),

customers as (

    select * from {{ ref('stg_customers') }}

),

reviews as (

    select * from {{ ref('int_order_reviews_latest') }}

),

joined as (

    select
        -- keys
        oi.order_id,
        oi.order_item_id,
        c.customer_unique_id,
        oi.product_id,
        oi.seller_id,
        o.purchased_at::date                                      as purchase_date,

        -- measures
        oi.price,
        oi.freight_value,
        oi.price + oi.freight_value                               as item_total,

        -- order-level attributes
        o.order_status,
        o.purchased_at,
        o.approved_at,
        o.delivered_to_carrier_at,
        o.delivered_to_customer_at,
        o.estimated_delivery_date,
        o.delivered_to_customer_at::date - o.purchased_at::date   as delivery_days,
        o.delivered_to_customer_at::date > o.estimated_delivery_date as is_late,
        r.review_score

    from order_items as oi
    inner join orders as o
        on oi.order_id = o.order_id
    inner join customers as c
        on o.customer_id = c.customer_id
    left join reviews as r
        on oi.order_id = r.order_id

)

select * from joined