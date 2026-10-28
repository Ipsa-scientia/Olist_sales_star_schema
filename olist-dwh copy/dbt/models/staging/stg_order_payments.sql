

with source as (

    select * from {{ source('olist', 'order_payments') }}

),

renamed as (

    select
        -- keys
        payment_sequential::int,
        order_id,

        -- 
        payment_installments::int,
        payment_value::numeric(10,2),
        NULLIF(payment_type, 'not_defined') as payment_type,

        -- metadata
        _loaded_at

    from source

)

select * from renamed