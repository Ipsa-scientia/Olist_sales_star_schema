-- Staging model for customers.
-- Grain: one row per customer (same as the source).
-- Only renaming and type casting here.

with source as (

    select * from {{ source('olist', 'customers') }}

),

renamed as (

    select
        -- keys
        customer_id,

        -- attributes
        customer_unique_id,

        -- 
        customer_city      as city,
        customer_state             as state_code,
        customer_zip_code_prefix   as zip_code_prefix,

        -- metadata
        _loaded_at

    from source

)

select * from renamed