-- Intermediate model: one review per order.
--
-- Grain: one row per order (order_id is unique).
--
-- Rule: when an order has several reviews, keep the review with the most
-- recent creation date (review_created_at).
--
-- Reason: the creation date is when the survey was sent, so the most recent
-- creation date means the most recent survey. A customer can answer an older
-- survey after a newer one, so the most recent answer does not always belong
-- to the most recent survey (example: order df56136b8031ecd28e200bb18e6ddb2e).
--
-- Alternatives considered:
--   - Keep the most recently answered review: not chosen, for the reason above.
--   - Sort by creation date, then by answer date: not chosen, because the
--     answer date does not indicate which survey is the most recent.
--
-- Tie-breaker: if several reviews of an order have the same creation date,
-- keep the review with the highest review_id. The source primary key is
-- (review_id, order_id), so since the rows are partitioned by order_id,
-- review_id is unique within each order, so the result is deterministic.
-- This affects up to 157 orders.
--
-- Shared reviews: a review linked to several orders is kept for each of
-- those orders. This does not break the rule of one review per order, and
-- removing it would leave the other orders without a review.

with reference as (

    select * from {{ ref('stg_order_reviews') }}

),

ranking as (

select
*,
row_number() over (partition by r.order_id order by r.review_creation_at desc, r.review_id desc) as review_rank
from reference r

),

only_first as (select
*
from ranking
where review_rank = 1
)

select * from only_first