# Star Schema Design

## Overview

The marts layer turns the cleaned Olist data into a star schema for analysis.
One fact table records every item sold, and four dimension tables describe
who bought it, what was bought, who sold it and when.

The schema must answer four business questions:

1. How did monthly revenue change over time?
2. Which product categories bring in the most revenue?
3. What is the average delivery time in each Brazilian state?
4. Do late deliveries lead to lower review scores?

Diagram: see `star_schema.dbml`.

| Layer | Schema | Materialization |
|---|---|---|
| Staging | `staging` | view |
| Intermediate | `intermediate` | view |
| Marts | `marts` | table |

## Key decisions

- **Natural keys.** All tables use the IDs from the source system
  (`product_id`, `seller_id`, `customer_unique_id`) instead of new surrogate keys.
  The Olist IDs are stable and unique, and this project does not track
  history, which is the main reason to introduce surrogate keys.
- **Customers are modelled as people.** `dim_customers` uses
  `customer_unique_id`, because Olist creates a new `customer_id` for every
  order. Analyses of repeat customers are only correct at the person level.
- **Marts are tables.** The dashboard reads the marts often, and the fact table
  contains several joins. Storing the result as a table makes queries fast.
  The tables are rebuilt by `dbt run` after each load.
- **No NULL categories.** Dashboards often hide NULL groups, so
  `category_name_en` always has a readable value.
- **Date comparisons use dates on both sides.** Several source values contain
  only a date, so comparing them with full timestamps would give misleading
  results.

## fact_order_items

**Grain:** one row per item in an order.

**Primary key:** (`order_id`, `order_item_id`)

**Expected rows:** 112,650 (same as `stg_order_items`)

### Keys

| Column | Type | Source | Description |
|---|---|---|---|
| `order_id` | varchar | `stg_order_items.order_id` | The order the item belongs to. Degenerate dimension: it has no dimension table of its own. |
| `order_item_id` | int | `stg_order_items.order_item_id` | Position of the item within the order (1, 2, 3, ...). |
| `customer_unique_id` | varchar | `stg_customers.customer_unique_id` | Foreign key to `dim_customers`. Reached through `stg_orders.customer_id` (see design question 2). |
| `product_id` | varchar | `stg_order_items.product_id` | Foreign key to `dim_products`. |
| `seller_id` | varchar | `stg_order_items.seller_id` | Foreign key to `dim_sellers`. |
| `purchase_date` | date | calculated | `purchased_at` converted to a date. Foreign key to `dim_date`. |

### Measures

| Column | Type | Source | Description |
|---|---|---|---|
| `price` | numeric(10,2) | `stg_order_items.price` | Price of the item. Additive. |
| `freight_value` | numeric(10,2) | `stg_order_items.freight_value` | Freight charged for the item. Additive. |
| `item_total` | numeric(10,2) | calculated | `price` plus `freight_value`. Additive. |

### Order-level attributes

These columns describe the order, not the item. They are repeated in every
row of an order (see design question 1).

| Column | Type | Source | Description |
|---|---|---|---|
| `order_status` | varchar | `stg_orders.order_status` | Current status of the order. |
| `purchased_at` | timestamp | `stg_orders.purchased_at` | When the order was placed. |
| `approved_at` | timestamp | `stg_orders.approved_at` | When the payment was approved. Not used by the four dashboard questions; kept for analyses of the order process. |
| `delivered_to_carrier_at` | timestamp | `stg_orders.delivered_to_carrier_at` | When the order was handed to the carrier. Kept for the same reason. |
| `delivered_to_customer_at` | timestamp | `stg_orders.delivered_to_customer_at` | When the customer received the order. NULL if not delivered. |
| `estimated_delivery_date` | date | `stg_orders.estimated_delivery_date` | Delivery date promised to the customer. |
| `delivery_days` | int | calculated | Number of calendar days from the purchase date to the delivery date. NULL if there is no delivery date. Not additive. |
| `is_late` | boolean | calculated | True if the delivery date is after the estimated delivery date. NULL if there is no delivery date (see design question 3). |
| `review_score` | int | `int_order_reviews_latest.review_score` | Review score (1 to 5) of the order's most recent review. NULL if the order has no review. Not additive. |

## dim_customers

**Grain:** one row per person (`customer_unique_id`).

**Primary key:** `customer_unique_id`

**Expected rows:** 96,096

**Built from:** `int_customers_latest`, which combines `stg_customers` with
`stg_orders` to find each person's most recent order.

| Column | Type | Source | Description |
|---|---|---|---|
| `customer_unique_id` | varchar | `stg_customers.customer_unique_id` | Identifies the person. |
| `zip_code_prefix` | varchar | `stg_customers.zip_code_prefix` | 5-digit zip prefix, kept as text to preserve leading zeros. From the most recent order. |
| `city` | varchar | `stg_customers.city` | City. From the most recent order. |
| `state_code` | varchar(2) | `stg_customers.state_code` | Two-letter state code. From the most recent order. |
| `first_order_at` | timestamp | calculated | Purchase timestamp of the person's first order (`stg_orders.purchased_at`). |
| `order_count` | int | calculated | Number of orders the person placed. |

**Rule for the location:** a person can have a different address in each order.
The dimension uses the address from the most recent order. If two orders have
the same purchase timestamp, the tie-breaker is `customer_id`.

## dim_products

**Grain:** one row per product.

**Primary key:** `product_id`

**Expected rows:** 32,951

| Column | Type | Source | Description |
|---|---|---|---|
| `product_id` | varchar | `stg_products.product_id` | Identifies the product. |
| `category_name_pt` | varchar | `stg_products.product_category_name` | Original Portuguese category name. NULL for the 610 products without a category. |
| `category_name_en` | varchar | calculated | English category name from `stg_product_category_name_translation`. See the rules below. |
| `name_length` | int | `stg_products.product_name_length` | Number of characters in the product name. |
| `description_length` | int | `stg_products.product_description_length` | Number of characters in the product description. |
| `photos_qty` | int | `stg_products.product_photos_qty` | Number of product photos. |
| `weight_g` | int | `stg_products.product_weight_g` | Weight in grams. |
| `length_cm` | int | `stg_products.product_length_cm` | Length in centimeters. |
| `height_cm` | int | `stg_products.product_height_cm` | Height in centimeters. |
| `width_cm` | int | `stg_products.product_width_cm` | Width in centimeters. |

**Rules for `category_name_en`:**

1. If a translation exists, use the English name.
2. If the product has a category but no translation exists (2 categories), use the Portuguese name.
3. If the product has no category (610 products), use `unknown`.

The translation is joined so that products without a match are kept;
otherwise the products from rules 2 and 3 would disappear from the dimension.

## dim_sellers

**Grain:** one row per seller.

**Primary key:** `seller_id`

**Expected rows:** 3,095

| Column | Type | Source | Description |
|---|---|---|---|
| `seller_id` | varchar | `stg_sellers.seller_id` | Identifies the seller. |
| `zip_code_prefix` | varchar | `stg_sellers.zip_code_prefix` | 5-digit zip prefix, kept as text. |
| `city` | varchar | `stg_sellers.city` | City. |
| `state_code` | varchar(2) | `stg_sellers.state_code` | Two-letter state code. |

## dim_date

**Grain:** one row per calendar day.

**Primary key:** `date_day`

**Date range:** from the earliest purchase date to the latest delivery or
estimated delivery date in the data. The exact range is recorded here after
the model is built: <start date> to <end date>.

| Column | Type | Source | Description |
|---|---|---|---|
| `date_day` | date | generated | The calendar day. |
| `year` | int | calculated | Year, for example 2017. |
| `quarter` | int | calculated | Quarter of the year (1 to 4). |
| `month` | int | calculated | Month number (1 to 12). |
| `month_name` | varchar | calculated | Month name, for example October. |
| `weekday_number` | int | calculated | Day of the week as a number, used to sort weekdays in charts. |
| `weekday_name` | varchar | calculated | Day of the week, for example Monday. |
| `is_weekend` | boolean | calculated | True for Saturday and Sunday. |

The date dimension contains every day in the range, including days without
any orders. This makes it possible to show days with zero sales in charts.

## Design questions

### 1. Order-level columns in an item-level fact table

The fact table contains the order status, the order dates, the delivery time,
the late flag and the review score. These values belong to the order, so they
are repeated in every item row of that order. An order with three items has
the same delivery time and review score in three rows.

This makes these columns not additive across items. If the dashboard
calculated the average delivery time directly from the fact table, an order
with three items would count three times, and orders with many items would
have more weight than orders with one item.

Correct calculation: first reduce the rows to one per order (for example,
take the distinct combination of `order_id` and `delivery_days`), and then
calculate the average. The same applies to the average review score and to
the share of late orders. Measures at item level (`price`, `freight_value`,
`item_total`) can be summed directly.

### 2. Reaching customer_unique_id from the order items

The order items do not contain any customer information. The path is:

1. `stg_order_items.order_id` and `stg_orders.order_id`, which gives the `customer_id`.
2. `stg_orders.customer_id` and `stg_customers.customer_id`, which gives the `customer_unique_id`.

Both joins are many-to-one or one-to-one, so they do not change the number of
item rows.

### 3. Definition of a late delivery

An order is late if the date it was delivered to the customer is after the
estimated delivery date. The comparison uses dates on both sides, because the
estimated delivery date has no time. A delivery on the estimated day is on time.

For an order without a delivery date, `is_late` is NULL, not false or true because:

- Not false: the order was not delivered on time, so false would be wrong.
  It would also make the share of late deliveries look better than it is.
- Not true: the order may not have been delivered at all (cancelled or
  unavailable), or it may still be on its way. Calling it late would mix
  delivery performance with cancellations.
- NULL means "not applicable or unknown". Averages and counts of
  `is_late` then automatically consider only delivered orders.

This also covers the 8 orders with the status `delivered` but no delivery date.

### 4. Orders without items

The 775 orders without items (mostly `unavailable` and `canceled`) have no row
in `fact_order_items`, because the grain is one row per item.

Effect on the four dashboard questions:

- Revenue (questions 1 and 2): no effect, because orders without items have no revenue.
- Delivery time (question 3): no effect, because these orders were not delivered.
- Late deliveries and reviews (question 4): no effect for the same reason.

What it affects: any question that counts all orders, for example the
total number of orders or the cancellation rate. Counted from this fact table,
those numbers would be too low. If such questions become important, a second
fact table at the order grain (`fact_orders`) should be added.

## Validation results
TBA


| Check | Expected | Result |
|---|---|---|
| Row count `fact_order_items` | 112,650 | |
| Row count `dim_customers` | 96,096 | |
| Row count `dim_products` | 32,951 | |
| Row count `dim_sellers` | 3,095 | |
| Primary keys unique in all tables | 0 duplicates | |
| Sum of `price` in fact = sum in `stg_order_items` | equal | |
| Orphan keys | 0 | |
| Every `purchase_date` exists in `dim_date` | 0 missing | |

