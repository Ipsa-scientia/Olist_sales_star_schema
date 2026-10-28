

with source as (

    select * from {{ source('olist', 'sellers') }}

),

renamed as (

    select
        -- keys
        seller_id,

        -- 
        seller_city      as city,
        seller_state             as state_code,
        seller_zip_code_prefix   as zip_code_prefix,

        -- metadata
        _loaded_at

    from source

)

select * from renamed