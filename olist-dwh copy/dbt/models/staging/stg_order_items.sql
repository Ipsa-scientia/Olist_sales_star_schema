-- Staging model for order_items.
-- Grain: one row per order_items (same as the source).
-- Only renaming and type casting here.

with source as (

    select * from {{ source('olist', 'order_items') }}

),

renamed as (

    select
        -- keys
        order_item_id::int,
        order_id,

        -- attributes
        product_id,
        seller_id,

        -- 
        shipping_limit_date::timestamp     as shipping_limit_at,
        price::numeric(10,2),
        freight_value::numeric(10,2),

        -- metadata
        _loaded_at

    from source

)

select * from renamed