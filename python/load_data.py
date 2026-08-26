"""Load the original Olist CSV files into PostgreSQL's raw schema."""

from __future__ import annotations

import os
from pathlib import Path

import pandas as pd
from sqlalchemy import create_engine, text
from sqlalchemy.engine import URL

PROJECT_ROOT = Path(__file__).resolve().parent.parent
ENV_FILE = PROJECT_ROOT / ".env"
FILES = {
    "olist_customers_dataset": "olist_customers_dataset.csv",
    "olist_orders_dataset": "olist_orders_dataset.csv",
    "olist_order_items_dataset": "olist_order_items_dataset.csv",
    "olist_order_payments_dataset": "olist_order_payments_dataset.csv",
    "olist_order_reviews_dataset": "olist_order_reviews_dataset.csv",
    "olist_products_dataset": "olist_products_dataset.csv",
    "olist_sellers_dataset": "olist_sellers_dataset.csv",
    "olist_geolocation_dataset": "olist_geolocation_dataset.csv",
    "product_category_name_translation": "product_category_name_translation.csv",
}
CHUNK_SIZE = 5_000


def load_dotenv(path: Path) -> None:
    if not path.exists():
        raise FileNotFoundError(f"Missing {path}. Copy .env.example to .env and fill it in.")
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line and not line.startswith("#") and "=" in line:
            key, value = line.split("=", 1)
            os.environ.setdefault(key.strip(), value.strip())


def required_env(name: str) -> str:
    value = os.getenv(name)
    if not value:
        raise RuntimeError(f"{name} is required; set it in .env.")
    return value


def main() -> None:
    load_dotenv(ENV_FILE)
    data_dir = PROJECT_ROOT / os.getenv("OLIST_DATA_DIR", "data/raw")
    schema = os.getenv("POSTGRES_SCHEMA", "raw")
    missing = [name for name in FILES.values() if not (data_dir / name).is_file()]
    if missing:
        raise FileNotFoundError(f"Missing CSV files in {data_dir}: {', '.join(missing)}")

    url = URL.create(
        "postgresql+psycopg2",
        username=required_env("POSTGRES_USER"),
        password=required_env("POSTGRES_PASSWORD"),
        host=required_env("POSTGRES_HOST"),
        port=int(required_env("POSTGRES_PORT")),
        database=required_env("POSTGRES_DB"),
    )
    engine = create_engine(url, pool_pre_ping=True)

    with engine.begin() as connection:
        connection.execute(text(f'CREATE SCHEMA IF NOT EXISTS "{schema}"'))

    for table_name, filename in FILES.items():
        path = data_dir / filename
        print(f"Loading {filename} -> {schema}.{table_name}")
        row_count = 0
        for chunk_number, chunk in enumerate(pd.read_csv(path, chunksize=CHUNK_SIZE)):
            chunk.to_sql(
                table_name,
                engine,
                schema=schema,
                if_exists="replace" if chunk_number == 0 else "append",
                index=False,
                method="multi",
            )
            row_count += len(chunk)
        print(f"  loaded {row_count:,} rows")

    print("All CSVs loaded successfully.")


if __name__ == "__main__":
    main()
