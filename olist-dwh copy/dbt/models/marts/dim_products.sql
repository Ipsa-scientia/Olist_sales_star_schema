/*
Product dimension.

The grain is one row per product, identified by product_id.
The expected result is 32,951 rows.

The English category name follows three rules, in this order.
1. If a translation exists, use the English name.
2. If the product has a category but no translation exists, use the
   Portuguese name. This applies to 2 categories.
3. If the product has no category, use the text unknown. This applies to
   610 products.

The translation is joined with a left join, so that products without a
matching translation are kept. An inner join would remove the products of
rules 2 and 3 from the dimension.

The translation table has one row per category, so the join cannot create
duplicate products.
*/

with products as (

    select * from {{ ref('stg_products') }}

),

translations as (

    select * from {{ ref('stg_product_category_name_translation') }}

),

products_with_category as (

    select
        p.product_id,
        p.product_category_name                        as category_name_pt,
        coalesce(
            t.category_name_en,
            p.product_category_name,
            'unknown'
        )                                              as category_name_en,
        p.product_name_length                          as name_length,
        p.product_description_length                   as description_length,
        p.product_photos_qty                           as photos_qty,
        p.product_weight_g                             as weight_g,
        p.product_length_cm                            as length_cm,
        p.product_height_cm                            as height_cm,
        p.product_width_cm                             as width_cm

    from products as p
    left join translations as t
        on p.product_category_name = t.category_name_pt

)

select
    -- key
    product_id,

    -- category
    category_name_pt,
    category_name_en,

    -- listing details
    name_length,
    description_length,
    photos_qty,

    -- weight and dimensions
    weight_g,
    length_cm,
    height_cm,
    width_cm

from products_with_category