/*
Seller dimension.

The grain is one row per seller, identified by seller_id.
The expected result is 3,095 rows.

The source is stg_sellers, which already has one row per seller.
*/

with sellers as (

    select * from {{ ref('stg_sellers') }}

)

select
    -- key
    seller_id,

    -- location
    zip_code_prefix,
    city,
    state_code

from sellers