"""
data_quality_checks.py
Digital Product Analytics KPI Dashboard

Validates the integrity of data/raw_sample_data.csv before analysis.
Run:  python python/data_quality_checks.py
Exit code 0 = every check passed, 1 = at least one check failed.
 Mirrors the validation rules in sql/01_data_cleaning.sql.
"""
import sys
from pathlib import Path

import pandas as pd

DATA = Path(__file__).resolve().parent.parent / "data" / "raw_sample_data.csv"

FUNNEL = ["page_view", "signup_started", "form_step_1_completed", "onboarding_completed"]
PAGE_FOR = {
    "page_view": "/landing",
    "signup_started": "/onboarding-1",
    "form_step_1_completed": "/onboarding-2",
    "onboarding_completed": "/dashboard",
    "error": "/onboarding-1",
    "button_click": "/landing",
}
ERROR_CODE = "ERR_MOBILE_RENDER_502"

results = []


def check(name, passed, detail=""):
    results.append((name, bool(passed), detail))
    print(f"[{'PASS' if passed else 'FAIL'}] {name}" + (f" — {detail}" if detail else ""))


def main():
    df = pd.read_csv(DATA, parse_dates=["event_timestamp"])
    print(f"Loaded {DATA.name}: {len(df):,} events\n")

    # ---- shape & keys ----------------------------------------------------
    check("row_count_is_1000", len(df) == 1000, f"{len(df)} rows")
    check("event_id_unique", df["event_id"].is_unique,
          f"{df['event_id'].duplicated().sum()} duplicates")
    check("no_missing_critical_fields",
          df[["event_id", "session_id", "user_id", "event_timestamp",
              "event_type", "device_type", "user_segment"]].notna().all().all())
    check("session_count_is_290", df["session_id"].nunique() == 290,
          f"{df['session_id'].nunique()} sessions")
    check("user_count_is_290", df["user_id"].nunique() == 290,
          f"{df['user_id'].nunique()} users")

    per_session_users = df.groupby("session_id")["user_id"].nunique()
    check("one_user_per_session", (per_session_users == 1).all())

    # ---- dimension values -------------------------------------------------
    check("device_values_valid",
          set(df["device_type"].unique()) == {"Desktop", "Mobile", "Tablet"},
          str(sorted(df["device_type"].unique())))
    check("segment_values_valid",
          set(df["user_segment"].unique()) == {"Enterprise", "Premium", "Free"},
          str(sorted(df["user_segment"].unique())))
    drift = df.groupby("session_id").agg(
        d=("device_type", "nunique"), s=("user_segment", "nunique"))
    check("device_and_segment_stable_within_session",
          (drift["d"] == 1).all() and (drift["s"] == 1).all())

    # ---- event / page mapping ---------------------------------------------
    mapping_ok = all(
        set(df.loc[df["event_type"] == et, "page_url"].unique()) == {pg}
        for et, pg in PAGE_FOR.items())
    check("event_page_mapping_consistent", mapping_ok)

    # ---- funnel integrity ---------------------------------------------------
    stage_of = {et: i for i, et in enumerate(FUNNEL)}
    funnel_only = df[df["event_type"].isin(FUNNEL)].copy()
    funnel_only["stage"] = funnel_only["event_type"].map(stage_of)
    order_ok, skip_ok = True, True
    for _, g in funnel_only.groupby("session_id"):
        stages = list(g.sort_values("duration_sec")["stage"])
        if stages != sorted(stages):
            order_ok = False
        if set(stages) != set(range(max(stages) + 1)):
            skip_ok = False
    check("funnel_stage_order_valid_in_every_session", order_ok)
    check("no_session_skips_a_funnel_stage", skip_ok)

    reached = {et: df.loc[df["event_type"] == et, "session_id"].nunique() for et in FUNNEL}
    check("funnel_counts_reconcile_290_241_201_167",
          reached == {"page_view": 290, "signup_started": 241,
                      "form_step_1_completed": 201, "onboarding_completed": 167},
          str(reached))

    # ---- error telemetry -----------------------------------------------------
    err = df[df["error_code"] == ERROR_CODE]
    err_sessions = err["session_id"].nunique()
    check("error_code_only_expected_value",
          set(df["error_code"].dropna().unique()) <= {ERROR_CODE, ""})
    check("errors_only_on_mobile", (err["device_type"] == "Mobile").all(),
          f"{err_sessions} error sessions")
    check("errors_only_on_onboarding_1", (err["page_url"] == "/onboarding-1").all())
    check("error_session_count_is_28", err_sessions == 28)
    err_converted = df[df["session_id"].isin(err["session_id"]) &
                       (df["event_type"] == "onboarding_completed")]["session_id"].nunique()
    check("no_error_session_converts", err_converted == 0)

    # ---- durations & timestamps ------------------------------------------------
    check("duration_sec_positive", (df["duration_sec"] > 0).all())
    mono = df.sort_values(["session_id", "event_timestamp"]).groupby("session_id")["duration_sec"]
    check("duration_increases_within_session",
          mono.apply(lambda x: x.is_monotonic_increasing).all())
    ts_ok = df.sort_values(["session_id", "duration_sec"]).groupby("session_id")["event_timestamp"]
    check("timestamp_increases_within_session",
          ts_ok.apply(lambda x: x.is_monotonic_increasing).all())
    check("timestamps_inside_2026_09_01_to_2026_09_14",
          df["event_timestamp"].min() >= pd.Timestamp("2026-09-01")
          and df["event_timestamp"].max() < pd.Timestamp("2026-09-15"),
          f"{df['event_timestamp'].min()} to {df['event_timestamp'].max()}")

    # ---- KPI reconciliation ------------------------------------------------------
    conv = reached["onboarding_completed"] / reached["page_view"] * 100
    check("overall_conversion_rate_57_59_pct", round(conv, 2) == 57.59, f"{conv:.2f}%")

    print()
    failed = [r for r in results if not r[1]]
    print(f"{len(results) - len(failed)}/{len(results)} checks passed")
    if failed:
        print("FAILED:", ", ".join(r[0] for r in failed))
        sys.exit(1)
    print("All data quality checks passed.")


if __name__ == "__main__":
    main()
