import argparse
import os
import mysql.connector
import sqlite3
import pandas as pd
import numpy as np
import datetime
import decimal

# =========================
# Arguments
# =========================
parser = argparse.ArgumentParser()
parser.add_argument("--output-dir", required=True)
parser.add_argument("--timestamp", required=True)

args = parser.parse_args()

OUTPUT_DIR = args.output_dir
DATE = args.timestamp

SQLITE_FILE = os.path.join(OUTPUT_DIR, f"sqlite_{DATE}.sqlite")
EXCEL_FILE = os.path.join(OUTPUT_DIR, f"data_{DATE}.xlsx")

print(f"Output directory: {OUTPUT_DIR}")
print(f"SQLite file: {SQLITE_FILE}")
print(f"Excel file: {EXCEL_FILE}")

# =========================
# MariaDB connection
# =========================
conn = mysql.connector.connect(
    host="192.168.0.200",
    user="tiledb",
    password="T1le-db-word!",
    database="tiledb"
)

cursor = conn.cursor()

# =========================
# SQLite setup
# =========================
sqlite_conn = sqlite3.connect(SQLITE_FILE)
sqlite_cursor = sqlite_conn.cursor()

# =========================
# Excel writer
# =========================
writer = pd.ExcelWriter(EXCEL_FILE, engine="openpyxl")

# =========================
# Type normalization (IMPORTANT FIX)
# =========================
def normalize(value):
    # NULLs
    if value is None:
        return None

    # Pandas NaN
    if isinstance(value, float) and np.isnan(value):
        return None

    # Pandas / Python datetime
    if isinstance(value, (pd.Timestamp, datetime.datetime, datetime.date)):
        return value.isoformat()

    # Decimal
    if isinstance(value, decimal.Decimal):
        return float(value)

    # NumPy integers
    if isinstance(value, np.integer):
        return int(value)

    # NumPy floats
    if isinstance(value, np.floating):
        return float(value)

    # Bytes
    if isinstance(value, (bytes, bytearray)):
        return value.decode(errors="ignore")

    return value

# =========================
# Get all tables
# =========================
cursor.execute("SHOW TABLES")
tables = cursor.fetchall()

for (table,) in tables:
    print(f"Processing table: {table}")

    # =========================
    # Load table
    # =========================
    df = pd.read_sql(f"SELECT * FROM `{table}`", conn)

    # =========================
    # EXCEL EXPORT
    # =========================
    df_excel = df.copy()
    df_excel = df_excel.replace({np.nan: None})

    for col in df_excel.columns:
        if df_excel[col].dtype == "datetime64[ns]":
            df_excel[col] = df_excel[col].astype(str)

    df_excel.to_excel(writer, sheet_name=table[:31], index=False)

    # =========================
    # SQLITE EXPORT (FIXED)
    # =========================
    columns = df.columns

    col_def = ", ".join([f"`{c}` TEXT" for c in columns])

    sqlite_cursor.execute(f"DROP TABLE IF EXISTS `{table}`")
    sqlite_cursor.execute(f"CREATE TABLE `{table}` ({col_def})")

    placeholders = ",".join(["?"] * len(columns))

    # CRITICAL FIX: normalize every value
    rows = [
        [normalize(v) for v in row]
        for row in df.values.tolist()
    ]

    sqlite_cursor.executemany(
        f"INSERT INTO `{table}` VALUES ({placeholders})",
        rows
    )

# =========================
# Finalize
# =========================
sqlite_conn.commit()
sqlite_conn.close()
conn.close()

writer.close()

print("Backup completed successfully.")
print(f"SQLite: {SQLITE_FILE}")
print(f"Excel: {EXCEL_FILE}")