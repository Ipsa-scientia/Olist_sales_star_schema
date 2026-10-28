from pathlib import Path

import pandas as pd

DATA_DIR = Path("data/raw/olist")


def profile(name: str, df: pd.DataFrame) -> None:
    """Print a basic profile of one table."""
    print(f"\n{'=' * 60}\n{name}\n{'=' * 60}")
    print(f"Rows: {len(df):,}   Columns: {df.shape[1]}")
    print(f"Fully duplicated rows: {df.duplicated().sum():,}")

    summary = pd.DataFrame({
        "dtype": df.dtypes.astype(str),
        "nulls": df.isna().sum(),
        "null_%": (df.isna().mean() * 100).round(2),
        "distinct": df.nunique(),
    })
    print(summary.to_string())


def is_unique_key(df: pd.DataFrame, columns: list[str]) -> bool:
    """Return True if the columns uniquely identify every row and contain no nulls."""
    has_duplicates = df.duplicated(subset=columns).any()
    has_nulls = df[columns].isna().any().any()
    return not has_duplicates and not has_nulls


def main() -> None:
    csv_files = sorted(DATA_DIR.glob("*.csv"))
    if not csv_files:
        raise SystemExit(f"No CSV files found in {DATA_DIR.resolve()}")

    tables = {path.stem: pd.read_csv(path) for path in csv_files}

    candidate_keys = {
        "olist_orders_dataset": ["order_id"],
        "olist_customers_dataset": ["customer_id"],
        "olist_products_dataset": ["product_id"],
        "olist_sellers_dataset": ["seller_id"],
        "product_category_name_translation": ["product_category_name"],
        "olist_order_items_dataset": ["order_id", "order_item_id"],
        "olist_order_payments_dataset": ["order_id", "payment_sequential"],
        "olist_order_reviews_dataset": ["review_id", "order_id"],
    }
    print("\nPRIMARY KEY TESTS")
    for table, columns in candidate_keys.items():
        print(f"{table} {columns}: {is_unique_key(tables[table], columns)}")


if __name__ == "__main__":
    main()