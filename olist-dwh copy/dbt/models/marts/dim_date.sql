/*
Date dimension.

The grain is one row per calendar day, identified by date_day.

The range covers full calendar years, from 1 January of the year of the first
purchase to 31 December of the year of the latest date in the orders
(purchase, delivery to the carrier, delivery to the customer, or estimated
delivery). With the current data, this is 2016-01-01 to 2018-12-31, which is
1,096 days. Full years make charts easier to read. The range is calculated
from the data, so it grows automatically when newer orders are loaded.

Every day in the range has a row, including days without orders, so that
charts can show days with zero sales.

Weekdays use the ISO numbering, where Monday is 1 and Sunday is 7. This makes
weekdays sort from Monday to Sunday in charts.

The FM prefix in to_char removes the spaces that PostgreSQL otherwise adds to
month and weekday names, so that a filter such as month_name = 'May' works.
*/

with orders as (

    select * from {{ ref('stg_orders') }}

),

date_range as (

    select
        date_trunc('year', min(purchased_at))::date as start_date,
        (
            date_trunc(
                'year',
                max(greatest(
                    purchased_at,
                    delivered_to_carrier_at,
                    delivered_to_customer_at,
                    estimated_delivery_date::timestamp
                ))
            )
            + interval '1 year'
            - interval '1 day'
        )::date as end_date

    from orders

),

days as (

    select
        generate_series(start_date, end_date, interval '1 day')::date as date_day

    from date_range

)

select
    -- key
    date_day,

    -- calendar parts
    extract(year from date_day)::int        as year,
    extract(quarter from date_day)::int     as quarter,
    extract(month from date_day)::int       as month,
    to_char(date_day, 'FMMonth')            as month_name,

    -- weekday (ISO: Monday = 1, Sunday = 7)
    extract(isodow from date_day)::int      as weekday_number,
    to_char(date_day, 'FMDay')              as weekday_name,
    extract(isodow from date_day) in (6, 7) as is_weekend

from days