# Olist dbt + Power BI

This project loads the original Olist CSV files into PostgreSQL, transforms them with dbt, and refreshes the existing Power BI report.

## Local setup

1. Start the dedicated local PostgreSQL container:

   ```powershell
   docker start olist_pg_local
   ```

   It is exposed at `localhost:5434` and uses the `olist_dw` database. Do not use port 5433; it belongs to another local project.

2. Activate the virtual environment:

   ```powershell
   .\.venv\Scripts\Activate.ps1
   ```

3. To reload the source data, run:

   ```powershell
   python .\python\load_data.py
   ```

4. Load the local environment variables and build the warehouse:

   ```powershell
   Get-Content .env | Where-Object { $_ -and -not $_.StartsWith('#') } | ForEach-Object {
     $parts = $_ -split '=', 2
     Set-Item -Path "Env:$($parts[0])" -Value $parts[1]
   }
   dbt run --project-dir .\olist_dw --profiles-dir .\olist_dw
   dbt test --project-dir .\olist_dw --profiles-dir .\olist_dw
   ```

## Power BI

Open `power bi/olist dashboard.pbix` in Power BI Desktop. In **File > Options and settings > Data source settings**, edit the PostgreSQL source to use:

- Server: `localhost:5434`
- Database: `olist_dw`
- Username/password: the `POSTGRES_USER` and `POSTGRES_PASSWORD` values in your local `.env`

The report expects the `dev` schema and these imported tables: `dim_customers`, `dim_geolocation`, `dim_product`, `dim_seller`, `fact_order_items`, and `fact_orders`. After updating credentials, choose **Refresh**. The PBIX itself is intentionally not modified.

## Configuration and data

- Copy `.env.example` to `.env` if setting up on another machine. `.env` contains local credentials and is ignored by Git.
- The raw CSVs are expected in `data/raw/`. They are ignored by Git and are not altered by the loader.
- dbt uses `olist_dw/profiles.yml`; it reads the same PostgreSQL environment variables as the loader.
