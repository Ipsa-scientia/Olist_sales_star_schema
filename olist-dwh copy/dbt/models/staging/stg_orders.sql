-- Staging model for orders.
-- Grain: one row per order (same as the source).
-- Only renaming and type casting here.

with source as (

    select * from {{ source('olist', 'orders') }}

),

renamed as (

    select
        -- keys
        order_id,
        customer_id,

        -- attributes
        order_status,

        -- timestamps (text -> timestamp)
        order_purchase_timestamp::timestamp       as purchased_at,
        order_approved_at::timestamp              as approved_at,
        order_delivered_carrier_date::timestamp   as delivered_to_carrier_at,
        order_delivered_customer_date::timestamp  as delivered_to_customer_at,
        order_estimated_delivery_date::date       as estimated_delivery_date,

        -- metadata
        _loaded_at

    from source

)

select * from renamed