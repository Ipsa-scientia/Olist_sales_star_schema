import csv
import logging
import os
import time
from pathlib import Path
 
import psycopg
from dotenv import load_dotenv
from psycopg import sql
 
DATA_DIR = Path("data/raw/olist")
SCHEMA = "raw"
BLOCK_SIZE = 1024 * 1024 
 
logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
logger = logging.getLogger(__name__)
 
 
def get_connection() -> psycopg.Connection:
    """Open a database connection using the settings in .env."""
    load_dotenv()
    return psycopg.connect(
        host="localhost",
        port=os.getenv("POSTGRES_PORT", "5432"),
        user=os.environ["POSTGRES_USER"],
        password=os.environ["POSTGRES_PASSWORD"],
        dbname=os.environ["POSTGRES_DB"],
    )
 
 
def table_name_for(path: Path) -> str:
    """olist_orders_dataset.csv -> orders"""
    return path.stem.removeprefix("olist_").removesuffix("_dataset")
 
 
def read_header(path: Path) -> list[str]:
    """Return the column names from the first line of the CSV file."""
    with path.open(newline="", encoding="utf-8-sig") as f:
        return next(csv.reader(f))
 
 
def count_csv_rows(path: Path) -> int:
    """
    Count data rows with a CSV parser, not by counting lines.
    A text value in quotes can contain line breaks (for example, review comments),
    so one row can span several lines in the file.
    """
    with path.open(newline="", encoding="utf-8-sig") as f:
        return sum(1 for _ in csv.reader(f)) - 1  # minus the header row
 
 
def load_file(conn: psycopg.Connection, path: Path) -> None:
    """Replace one raw table with the contents of one CSV file."""
    table = table_name_for(path)
    columns = read_header(path)
    start = time.perf_counter()
 
    table_id = sql.Identifier(SCHEMA, table)
    column_ids = sql.SQL(", ").join(sql.Identifier(c) for c in columns)
    column_definitions = sql.SQL(", ").join(
        sql.SQL("{} text").format(sql.Identifier(c)) for c in columns
    )
 
    create_table = sql.SQL("""
        CREATE TABLE {table} (
            {columns},
            _loaded_at   timestamptz NOT NULL DEFAULT now(),
            _source_file text        NOT NULL DEFAULT {file}
        )
    """).format(table=table_id, columns=column_definitions, file=sql.Literal(path.name))
 
    copy_data = sql.SQL("COPY {table} ({columns}) FROM STDIN WITH (FORMAT csv, HEADER true)").format(
        table=table_id, columns=column_ids
    )
 
    # One transaction per table: either the whole table is replaced,
    # or (if anything fails) nothing changes and the old table stays.
    with conn.transaction():
        conn.execute(sql.SQL("DROP TABLE IF EXISTS {}").format(table_id))
        conn.execute(create_table)
 
        with conn.cursor() as cur:
            with cur.copy(copy_data) as copy, path.open("rb") as f:
                while block := f.read(BLOCK_SIZE):
                    copy.write(block)
 
            db_rows = cur.execute(sql.SQL("SELECT COUNT(*) FROM {}").format(table_id)).fetchone()[0]
 
        csv_rows = count_csv_rows(path)
        if db_rows != csv_rows:
            raise ValueError(f"{table}: CSV has {csv_rows:,} rows, database has {db_rows:,}")
 
    seconds = time.perf_counter() - start
    logger.info("Loaded %-45s %10s rows in %5.1fs", f"{SCHEMA}.{table}", f"{db_rows:,}", seconds)
 
 
def main() -> None:
    csv_files = sorted(DATA_DIR.glob("*.csv"))
    if not csv_files:
        raise SystemExit(f"No CSV files found in {DATA_DIR.resolve()}")
 
    failed = []
    with get_connection() as conn:
        conn.execute(sql.SQL("CREATE SCHEMA IF NOT EXISTS {}").format(sql.Identifier(SCHEMA)))
        conn.commit()
 
        for path in csv_files:
            try:
                load_file(conn, path)
            except Exception:
                logger.exception("Failed to load %s", path.name)
                failed.append(path.name)
 
    if failed:
        raise SystemExit(f"{len(failed)} file(s) failed: {', '.join(failed)}")
    logger.info("All %d files loaded successfully.", len(csv_files))
 
 
if __name__ == "__main__":
    main()
 