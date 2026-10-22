"""Regenerate the Tableau data pack (dashboards/tableau/data/*.csv) from the SQL layer.

    python python/export_tableau_data.py [output_dir]

Loads data/raw_sample_data.csv as raw_events, runs sql/01_data_cleaning.sql and
sql/02_kpi_modeling.sql on DuckDB, then writes one CSV per view plus
funnel_long.csv — the long table the workbook's funnel sheets are built on,
which no single view produces (it unions kpi_funnel_stage with
kpi_device_funnel and computes the per-device retention columns).
"""
from __future__ import annotations

import sys
from pathlib import Path

import duckdb
import pandas as pd
import sqlglot

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "data" / "raw_sample_data.csv"
SQL_FILES = ("sql/01_data_cleaning.sql", "sql/02_kpi_modeling.sql")

# view -> (sort columns, sort as text) — deterministic row order for the exports
VIEWS = {
    "cleaned_events": ["event_id"],
    "session_level": ["session_id"],
    "kpi_funnel_stage": ["stage_order"],
    "kpi_device_funnel": ["device_type", "stage_order"],
    "kpi_device_performance": ["device_type"],
    "kpi_segment_performance": ["user_segment"],
    "kpi_error_impact": ["mobile_cohort"],
    "kpi_daily_trend": ["session_date"],
}
DEVICE_ORDER = ["All Devices", "Desktop", "Mobile", "Tablet"]


def build_con() -> duckdb.DuckDBPyConnection:
    con = duckdb.connect()
    # read_csv_auto, not a registered frame: DuckDB infers the schema itself,
    # so the SQL layer is checked against an independent parser.
    path = RAW.resolve().as_posix().replace("'", "''")
    con.execute(f"CREATE TABLE raw_events AS SELECT * FROM read_csv_auto('{path}')")
    for rel in SQL_FILES:
        for stmt in sqlglot.parse((ROOT / rel).read_text(encoding="utf-8"), read="duckdb"):
            if stmt is not None:
                con.execute(stmt.sql(dialect="duckdb"))
    return con


def fetch(con: duckdb.DuckDBPyConnection, view: str) -> pd.DataFrame:
    df = con.execute(f"SELECT * FROM {view}").fetchdf()
    return df.sort_values(VIEWS[view], kind="mergesort").reset_index(drop=True)


def funnel_long(funnel_stage: pd.DataFrame, device_funnel: pd.DataFrame) -> pd.DataFrame:
    """Long funnel table for Tableau: one row per (device scope, stage)."""
    frames = []
    allv = funnel_stage.copy()
    allv.insert(0, "device_type", "All Devices")
    allv["stage_retention_pct"] = allv["stage_retention_pct"].fillna(100.00)
    frames.append(allv)

    stage1 = device_funnel[device_funnel.stage_order == 1].set_index("device_type")["sessions"]
    dev = device_funnel.sort_values(["device_type", "stage_order"]).copy()
    dev["page_url"] = dev.stage_order.map(
        dict(zip(funnel_stage.stage_order, funnel_stage.page_url)))
    prev = dev.groupby("device_type", sort=False).sessions.shift()
    dev["stage_retention_pct"] = (100.0 * dev.sessions / prev).fillna(100.00).round(2)
    dev["cumulative_retention_pct"] = (
        100.0 * dev.sessions / dev.device_type.map(stage1)).round(2)
    frames.append(dev[["device_type", "stage_order", "funnel_stage", "page_url",
                       "sessions", "stage_retention_pct", "cumulative_retention_pct"]])

    out = pd.concat(frames, ignore_index=True)
    out["device_type"] = pd.Categorical(out.device_type, DEVICE_ORDER, ordered=True)
    out = out.sort_values(["device_type", "stage_order"]).reset_index(drop=True)
    for col in ("stage_retention_pct", "cumulative_retention_pct"):
        out[col] = out[col].astype(float).round(2)
    out["sessions"] = out.sessions.astype(int)
    return out


def export(target: Path) -> list[Path]:
    target.mkdir(parents=True, exist_ok=True)
    con = build_con()
    written = []
    for view in VIEWS:
        df = fetch(con, view)
        if view == "cleaned_events":          # TIMESTAMP / DATE, not datetime64[us] noise
            df["event_timestamp"] = pd.to_datetime(df.event_timestamp).dt.strftime("%Y-%m-%d %H:%M:%S")
            df["event_date"] = pd.to_datetime(df.event_date).dt.strftime("%Y-%m-%d")
        if view in ("session_level", "kpi_daily_trend"):
            df["session_date"] = pd.to_datetime(df.session_date).dt.strftime("%Y-%m-%d")
        p = target / f"{view}.csv"
        df.to_csv(p, index=False, lineterminator="\n")
        written.append(p)
    p = target / "funnel_long.csv"
    funnel_long(fetch(con, "kpi_funnel_stage"), fetch(con, "kpi_device_funnel")).to_csv(
        p, index=False, lineterminator="\n")
    written.append(p)
    return written


if __name__ == "__main__":
    dest = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "dashboards" / "tableau" / "data"
    for f in export(dest):
        label = f.relative_to(ROOT) if f.is_relative_to(ROOT) else f
        print(f"wrote {label.as_posix()} ({f.stat().st_size:,} B)")
