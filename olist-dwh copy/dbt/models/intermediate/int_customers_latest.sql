/*
Intermediate model with one row per customer.

The grain is one row per person, identified by customer_unique_id.
The expected result is 96,096 rows.

Olist creates a new customer_id for every order, so one person can appear
in several rows of stg_customers, possibly with a different address in each.
This model keeps the location from the person's most recent order.

The most recent order is the one with the latest purchase time. If two orders
of the same person have exactly the same purchase time, the order with the
highest customer_id is kept. Since every order has its own customer_id, this
makes the result deterministic. 

The model also calculates the times of the person’s
first and last orders and the total number of orders the person placed

Orders and customers are joined with an inner join. Every order has exactly
one customer_id, and every customer_id belongs to exactly one order, so the
join keeps all 99,441 orders and no customer is lost.
*/
with orders as (

    select * from {{ ref('stg_orders') }}

),
customers as (

    select * from {{ ref('stg_customers') }}

),

winds as (

select
cus.customer_unique_id,
cus.zip_code_prefix,
cus.city,
cus.state_code,
o.purchased_at,
row_number() over (partition by cus.customer_unique_id order by o.purchased_at desc, o.customer_id desc) as order_recency_rank,
min(o.purchased_at) over (partition by cus.customer_unique_id) as first_order_at,
count(*) over (partition by cus.customer_unique_id) as order_count
from orders o join customers cus on cus.customer_id = o.customer_id

),

most_recent as (select
customer_unique_id,
purchased_at as last_order_at,
city,
first_order_at,
order_count,
zip_code_prefix,
state_code
from winds
where order_recency_rank = 1
)

select * from most_recent