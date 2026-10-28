/*
Customer dimension.

The grain is one row per person, identified by customer_unique_id.
The expected result is 96,096 rows.

The source is int_customers_latest, which already reduces the customers to
one row per person. The location comes from the person's most recent order.
This model only selects the columns for the marts layer, so that users of
the marts do not depend on the intermediate model directly.
*/

with customers as (

    select * from {{ ref('int_customers_latest') }}

)

select
    -- key
    customer_unique_id,

    -- location (from the most recent order)
    zip_code_prefix,
    city,
    state_code,

    -- order history
    first_order_at,
    last_order_at,
    order_count

from customers