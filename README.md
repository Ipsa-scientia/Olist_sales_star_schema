# Olist Sales Data Warehouse

A data warehouse built on real marketplace data from Olist, a Brazilian online marketplace. The project loads about 100,000 orders from 2016 to 2018 into PostgreSQL and uses dbt to turn them into a star schema for analysis.

The goal of the project is to practice the core steps of data engineering on a realistic dataset with real data quality problems.

## Architecture

```
Kaggle CSV files → Python loader → PostgreSQL raw → dbt staging → dbt intermediate → dbt marts
```

| Layer | Schema | Built with | Materialization | Purpose |
|---|---|---|---|---|
| Raw | `raw` | Python and `COPY` | table | The source data exactly as delivered, stored as text |
| Staging | `staging` | dbt | view | One cleaned model per source table with clear names and correct types |
| Intermediate | `intermediate` | dbt | view | Models that change the grain, such as removing duplicates |
| Marts | `marts` | dbt | table | The star schema used for analysis and dashboards |

PostgreSQL runs in Docker. The Python loader and dbt run on the host machine and connect to the database through the published port.

## Tech stack

| Tool | Role |
|---|---|
| PostgreSQL 16 | Database and warehouse |
| Docker Compose | Runs PostgreSQL with a persistent volume |
| Python with psycopg | Loads the CSV files into the raw layer |
| dbt Core | Transforms the data and builds the star schema |
| pandas | Data profiling before loading |
| dbdiagram.io | Entity relationship diagrams |

## Dataset

The data is the [Olist public dataset on Kaggle](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce). It describes orders placed on the Olist marketplace between September 2016 and October 2018, split across nine related CSV files.

| Table | Rows | One row per |
|---|---|---|
| orders | 99,441 | order |
| order items | 112,650 | item in an order |
| order payments | 103,886 | payment of an order |
| order reviews | 99,224 | link between a review and an order |
| customers | 99,441 | order (see the note on customers below) |
| sellers | 3,095 | seller |
| products | 32,951 | product |
| geolocation | 1,000,163 | address point within a zip code prefix |
| category translation | 71 | product category |

## Repository structure

```
olist-dwh/
├── docker-compose.yml          PostgreSQL service
├── .env.example                Template for database settings
├── requirements.txt            Python dependencies
├── ingestion/
│   ├── explore.py              Profiles the CSV files with pandas
│   └── load_raw.py             Loads the CSV files into the raw schema
├── dbt/
│   ├── dbt_project.yml         dbt configuration for all layers
│   ├── profiles.yml            Connection settings read from environment variables
│   ├── macros/                 Custom schema naming
│   └── models/
│       ├── staging/            Nine staging models and the source definitions
│       ├── intermediate/       Deduplicated reviews and customers
│       └── marts/              Fact and dimension tables
├── validation/
│   └── day4_star_schema_checks.sql
└── docs/
    ├── star_schema.md          Design of the star schema with all decisions
```

## What the data shows

Before any modeling, every table was profiled with pandas and later explored with SQL. The findings below shaped the design of the warehouse.

### Orders follow a clear lifecycle

An order moves from creation through approval, invoicing and processing to shipping and delivery. Each step fills in one timestamp, so an order only has dates for the steps it has reached. The vast majority of orders completed the whole path.

| Status | Orders | Share |
|---|---|---|
| delivered | 96,478 | 97.0% |
| shipped | 1,107 | 1.1% |
| canceled | 625 | 0.6% |
| unavailable | 609 | 0.6% |
| invoiced | 314 | 0.3% |
| processing | 301 | 0.3% |
| created | 5 | below 0.1% |
| approved | 2 | below 0.1% |

Missing dates mostly match the status. A canceled order has no delivery date, and a shipped order has a carrier date with no customer delivery date yet. A small number of orders break this pattern, for example 8 delivered orders that have no delivery date.

### Most orders contain a single item

The 112,650 items belong to 98,666 orders, which is about 1.14 items per order. The largest order contains 21 items. 775 orders have no items at all, and most of them were canceled or unavailable.

Payments work differently from items. An order can be paid in several parts, for example with a voucher and a credit card together, so the payments table has more rows than there are orders. One order has no payment record.

### Most customers ordered only once

The customers table has one row per order because Olist creates a new `customer_id` for every purchase. The real person is identified by `customer_unique_id`. The 99,441 orders come from 96,096 people, so only about 3% of all orders came from returning customers.

Customers come from all 27 Brazilian states and 4,119 cities. Sellers are more concentrated, with 3,095 sellers in 23 states.

### Reviews are survey answers

After an order, Olist sends the customer a satisfaction survey with a score from 1 to 5 and optional text. 98,673 orders have at least one review. Most customers only give a score: 88% of reviews have no title and 59% have no comment.

The link between reviews and orders is less simple than it looks. 547 orders received several surveys, and in some cases the customer's opinion changed between them. In the other direction, 786 reviews are linked to more than one order. The survey creation date contains only a date, which became clear because almost every value is exactly midnight.

The timing of surveys is revealing. 8,320 reviews were created before the order reached the customer, which suggests that surveys are sent around the estimated delivery date. Customers waiting for a late order therefore receive the survey before the product. Comments such as "Não recebi o produto" (I did not receive the product) appear in exactly these cases.

### Products and categories

The 32,951 products belong to 73 categories. 610 products have no category, and two categories have no English translation in the translation table. The physical attributes such as weight and size are almost complete.

### Locations are stored as zip code prefixes

Customers and sellers are located by the first five digits of their zip code. These prefixes are identifiers with leading zeros, such as `01310` in São Paulo, so they must stay text. A numeric type would silently turn them into four digit numbers.

The geolocation table has about one million rows because it stores many address points for each of its 19,015 prefixes. 261,831 of its rows are exact duplicates, so it has no usable key in its raw form.

## Data model

### Source data

The diagram below shows the nine source tables and their relationships as found during profiling.
<img width="2341" height="1260" alt="Image 28-10-2026 at 16 36" src="https://github.com/user-attachments/assets/f5cdfd9d-e2d0-4720-b8d1-45c1aa17daab" />


### Star schema
<img width="1103" height="1452" alt="Image 28-10-2026 at 16 40" src="https://github.com/user-attachments/assets/03790d6d-e251-410a-8f40-cc66410881a6" />

The marts layer contains one fact table and four dimensions.

| Table | Grain | Rows |
|---|---|---|
| `fact_order_items` | One row per item in an order | 112,650 |
| `dim_customers` | One row per person | 96,096 |
| `dim_products` | One row per product | 32,951 |
| `dim_sellers` | One row per seller | 3,095 |
| `dim_date` | One row per calendar day from 2016 to 2018 | 1,096 |

The fact table holds the item price, the freight value, and the item total as measures. It also carries order attributes such as the status, the delivery time in days, a late delivery flag and the review score. 

## Design decisions

**Raw data is stored as text.** The loader keeps every value exactly as it appears in the CSV file. Type conversion happens in the staging layer, where it is visible and tested. This protects values such as the zip code prefix `01310`, which would lose its leading zero if it were read as a number.

**The load is idempotent and transactional.** Each table is replaced inside a single transaction, so running the loader twice gives the same result, and a failed load leaves the previous data untouched. After loading, the script compares the row count in the database with a count from a CSV parser, which also handles review comments that contain line breaks.

**Bulk loading uses `COPY`.** The first version of the loader inserted rows with pandas and needed about five and a half minutes. Streaming the files with the PostgreSQL `COPY` command reduced the full load to about four seconds.

**Customers are modeled as people.** Olist creates a new `customer_id` for every order. The customer dimension therefore uses `customer_unique_id`, which identifies the person. The location comes from the person's most recent order, and the dimension also records the first order, the last order, and the number of orders.

**Each order keeps one review.** Some orders have several reviews, and some reviews are linked to several orders. The intermediate model keeps the review from the most recent survey for each order and uses the review ID as a tie breaker, so the result is deterministic. Reviews shared by several orders are kept for each order.

**Categories never appear as empty values.** Products use the English category name. When no translation exists, the Portuguese name is shown, and products without any category are labeled `unknown`. Dashboards often hide empty groups, so this rule keeps all revenue visible in category charts.

**Late deliveries are defined on dates.** An order is late when the delivery date is after the estimated delivery date. The late flag is empty for orders that were never delivered, so averages and shares of late deliveries consider delivered orders only.

**Order attributes in the fact table are not additive.** The delivery time and the review score belong to the order and repeat for every item of that order. Averages of these values must be calculated with one row per order.

## Data quality findings

| Finding | Rows | Handling |
|---|---|---|
| Delivered orders without a delivery date | 8 | Kept, delivery time and late flag stay empty |
| Canceled orders with a delivery date | 6 | Kept and documented |
| Orders without any items | 775 | Not part of the item fact table, no effect on revenue |
| Orders with several reviews | 547 | Reduced to one review per order |
| Reviews linked to several orders | 786 | Kept for each linked order |
| Reviews created before the delivery date | 8,320 | Documented, suggests surveys are sent around the estimated date |
| Reviews created before the purchase date | 64 | Documented as invalid links in the source |
| Products without a category | 610 | Labeled `unknown` |
| Categories without an English translation | 2 | Portuguese name used |
| Fully duplicated geolocation rows | 261,831 | Kept in staging, the table is not used by the marts |
| Misspelled source column names | 2 | Renamed in staging |

## Validation

The star schema is validated by a set of SQL checks in [`validation/day4_star_schema_checks.sql`](validation/day4_star_schema_checks.sql). All 16 checks pass.

| Check | Result |
|---|---|
| Row counts of the fact table and all dimensions | Passed |
| Unique primary keys in all five tables | Passed |
| Total price in the fact table equals the staging total | Passed |
| Every foreign key in the fact table exists in its dimension | Passed |
| Every purchase date exists in the date dimension | Passed |
| Late flag is empty exactly for orders without a delivery date | Passed |

## Acknowledgements

The dataset was published by Olist on Kaggle. Please see the dataset page for its license and terms of use
