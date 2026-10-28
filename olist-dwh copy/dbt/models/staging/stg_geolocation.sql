

with source as (

    select * from {{ source('olist', 'geolocation') }}

),

renamed as (

    select
        -- keys
        geolocation_zip_code_prefix,

        -- 
        geolocation_lat::numeric,
        geolocation_lng::numeric,
        geolocation_city,
        geolocation_state,
        -- metadata
        _loaded_at

    from source

)

select * from renamed