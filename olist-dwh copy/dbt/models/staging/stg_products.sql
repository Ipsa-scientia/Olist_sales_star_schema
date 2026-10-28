

with source as (

    select * from {{ source('olist', 'products') }}

),

renamed as (

    select
        -- keys
        product_id,

        -- 
        product_name_lenght::int as product_name_length,
        product_description_lenght::int as product_description_length,
        product_category_name,
        product_photos_qty::int,
        product_weight_g::int,
        product_length_cm::int,
        product_height_cm::int,
        product_width_cm::int,

        -- metadata
        _loaded_at

    from source

)

select * from renamed