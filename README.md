# Digital Product Analytics — KPI Dashboard

Exploratory product analytics on onboarding clickstream telemetry: funnel
conversion, device-level friction, and telemetry error root-cause analysis,
with SQL reporting layers built for a Tableau KPI dashboard.

**Headline finding:** the funnel does not leak at one stage — it leaks on one
platform. A mobile rendering error (`ERR_MOBILE_RENDER_502`) on the signup
page kills 28.57% of mobile sessions before signup even starts, which is why
Mobile converts at 36.73% while Desktop converts at 71.13%.

**Live dashboard:** https://public.tableau.com/app/profile/isfaque.ansari5273/viz/Product_Experience_KPIs/ProductExperienceKPIs
— the published `Product_Experience_KPIs` workbook (11 worksheets + 1
dashboard), also packaged at `dashboards/Product_Experience_KPIs.twbx`.

## Verified KPI summary (from `data/raw_sample_data.csv`)

| KPI | Value |
|---|---|
| Telemetry events | 1,000 |
| Unique sessions / users | 290 / 290 |
| Conversions | 167 |
| Overall conversion rate | **57.59%** |

### Funnel

| Stage | Page | Sessions | Stage retention | Cumulative |
|---|---|---|---|---|
| 1. Page View | `/landing` | 290 | 100.00% | 100.00% |
| 2. Signup Started | `/onboarding-1` | 241 | 83.10% | 83.10% |
| 3. Form Step 1 Completed | `/onboarding-2` | 201 | 83.40% | 69.31% |
| 4. Onboarding Completed | `/dashboard` | 167 | 83.08% | 57.59% |

Stage Conversion Rate = Sessions Reaching Stage N ÷ Sessions Reaching Stage N−1 × 100

### Device performance

| Device | Sessions | Conversions | Conversion rate | Drop-offs | Error sessions | Error rate |
|---|---|---|---|---|---|---|
| Desktop | 142 | 101 | 71.13% | 41 | 0 | 0.00% |
| Tablet | 50 | 30 | 60.00% | 20 | 0 | 0.00% |
| Mobile | 98 | 36 | 36.73% | 62 | 28 | 28.57% |

Drop-offs = sessions − conversions on that device. The 28 error sessions are
75.68% of Mobile's stage-1 drop-offs (28 of 37 sessions lost between
`/landing` and `/onboarding-1`) and 45.16% of all Mobile drop-offs (28 of 62).

### Segments

| Segment | Sessions | Conversions | Conversion rate | Error sessions |
|---|---|---|---|---|
| Enterprise | 50 | 30 | 60.00% | 4 |
| Premium | 74 | 48 | 64.86% | 7 |
| Free | 166 | 89 | 53.61% | 17 |

Segments differ by ~11 points; the error cuts across all of them — device is
the primary effect, segment is secondary.

### What fixing the bug is worth

- Mobile sessions **without** the error convert at 51.43% (36 of 70).
- **Realistic scenario:** error sessions convert at that same rate → **~+14
  conversions per 98 mobile sessions**, Mobile conversion → ~51.4%.
- **Upper bound:** every error session converts → 64/98 = **65.31%**.

## Repository structure

```
digital-product-analytics-kpi-dashboard/
├── data/
│   ├── raw_sample_data.csv          # synthetic sample telemetry (1,000 events)
│   └── data_dictionary.md           # columns, event mapping, KPI definitions
├── sql/
│   ├── 01_data_cleaning.sql         # cleaned_events view + 7 quality checks
│   └── 02_kpi_modeling.sql          # 7 reporting layers for Tableau
├── python/
│   ├── exploratory_analysis.ipynb   # executed notebook: funnel, device,
│   │                                # error root cause, segments, trends
│   ├── data_quality_checks.py       # 23 automated integrity checks
│   └── export_tableau_data.py       # rebuilds the 9 CSVs below from the SQL
├── dashboards/
│   ├── README.md                    # workbook spec + what was actually built
│   ├── Product_Experience_KPIs.twbx # packaged workbook (11 sheets + dashboard)
│   └── tableau/
│       ├── step_by_step_tableau_guide.md        # 23-step walkthrough
│       ├── Tableau_Build_Guide_Product_Experience_KPIs.pdf  # same build, 93 steps
│       └── data/                                # 8 SQL-view exports + funnel_long.csv
├── verify_analysis.py               # recomputes and cross-checks every figure
├── .github/workflows/ci.yml         # runs the data checks + the harness on push
├── requirements.txt
├── LICENSE
└── README.md
```

## How to run

```bash
pip install -r requirements.txt

# 1. Recompute and cross-check every published figure  -> "ALL PASS", exit 0
python verify_analysis.py

# 2. Validate the dataset on its own (23 checks, all must pass)
python python/data_quality_checks.py

# 3. Notebook (outputs and charts already embedded)
#    python/exploratory_analysis.ipynb — it locates data/raw_sample_data.csv
#    from the repo root or from python/, so it runs whichever folder the
#    kernel starts in.

# 4. Rebuild the Tableau data pack straight from the SQL layer
python python/export_tableau_data.py

# 5. SQL layers (any standard-SQL warehouse; verified on DuckDB)
#    load data/raw_sample_data.csv into a table named raw_events, then run:
#    sql/01_data_cleaning.sql   -> cleaned_events + quality check queries
#    sql/02_kpi_modeling.sql    -> session_level, kpi_funnel_stage,
#                                  kpi_device_funnel, kpi_device_performance,
#                                  kpi_segment_performance, kpi_error_impact,
#                                  kpi_daily_trend
```

## Verification

`verify_analysis.py` is the gate on every number in this repo. It runs 323
checks in 13 sections: the raw file's shape and provenance tells, the event →
page → funnel mapping, both SQL layers executed on DuckDB, an independent
pandas rebuild of `session_level` compared cell-by-cell with the SQL view,
every KPI table on this page, the counterfactual arithmetic, the time-in-funnel
benchmarks, the nine Tableau CSVs regenerated byte-for-byte from the SQL,
`funnel_long.csv` rebuilt from the two funnel views, the innards of the
packaged `.twbx` (sheets, datasources, calculated fields, parameters, the CSVs
inside it, `validation.json`), the notebook's stored outputs, every figure
printed in the prose, and the repo's own file tree. CI runs it — plus
`python/data_quality_checks.py` — on Python 3.11 and 3.12 on every push. Exit
0 with `ALL PASS` means nothing here is a hand-typed number.

## Data provenance

`data/raw_sample_data.csv` is a **synthetic, anonymized telemetry sample**,
not production clickstream. Its structure gives it away: `EVT-0001` …
`EVT-1000` run contiguously, every `user_id` carries the same number as its
`session_id` (`USR-0087` → `SES-0087`) in all 1,000 rows, each user has
exactly one session, funnel events appear at most once per session and always
in stage order, and `duration_sec` is recorded to one decimal on every row.
The analysis is therefore a complete, reproducible worked example — every
number in this repo, the notebook, the SQL views and the Tableau workbook is
arithmetic on that one file, and `verify_analysis.py` re-derives it. Nothing
here should be cited as evidence about a real onboarding product.

## Key insights

1. **No single stage is broken** — every stage retains ~83%. The loss is a
   population problem, and the population is Mobile.
2. **The error is precisely located:** Mobile only, `/onboarding-1` only,
   fires at 37.8s in (the signup moment — the stage mean is 37.6s), and every
   affected session drops before `signup_started`. No error session converts.
3. **Desktop is the benchmark** — 71.13% conversion, zero rendering errors,
   94.4% retention on the landing → signup transition vs Mobile's 62.2%.
4. **Time-in-funnel benchmarks** (mean `duration_sec` per funnel event):
   page view 11.6s, signup started 37.6s, form step 1 completed 80.8s,
   onboarding completed 141.8s. Medians run slightly higher: 11.6 / 37.8 /
   81.6 / 143.1s.
5. **The error is persistent, not an outage** — it fires on 13 of the 14 days
   (2–14 Sep; day 1 is clean), and high-error days track with the weakest
   daily conversion (correlation −0.76 between daily mobile error rate and
   daily conversion rate).

## Recommendations

- Treat `ERR_MOBILE_RENDER_502` as a P1 on the mobile signup render path;
  re-measure the landing → signup transition after the fix.
- Alert on mobile error rate — 28.57% of mobile sessions in this sample;
  anything above ~5% in a week should page the team.
- Always count KPIs in unique sessions. Raw event volume (1,000) includes
  non-funnel telemetry (`button_click`, `error`) and overstates the funnel
  by design.

## Notes and limitations

- Sample data is anonymized and small (290 sessions over 14 days): read rates
  with their counts, and treat daily trends as patterns, not precise effects.
- In this sample each user has exactly one session, so user-level and
  session-level conversion are identical.
- The Tableau workbook is live (link at the top) and packaged as
  `dashboards/Product_Experience_KPIs.twbx`
  (11 worksheets + 1 dashboard). It builds on two of the exports —
  `session_level.csv` (290 rows) and `funnel_long.csv` (16 rows); the other
  seven are verification references. Both build sources are byte-reproducible
  from the SQL layer with `python python/export_tableau_data.py`, and the
  copies packaged inside the `.twbx` are byte-identical to the ones in
  `dashboards/tableau/data/`. The published view was confirmed rendering on
  Tableau Public on 23 Oct 2026 — `dashboards/README.md` spells out exactly
  what that render check covers and what it does not.
- `duration_sec` and `event_timestamp` are two different clocks. Every
  session's first event already carries 3.0–23.9s (mean 11.6s) of
  `duration_sec`, so the stopwatch runs ahead of the timestamp deltas, and the
  gap drifts by up to 1.0s inside a session. Both increase monotonically
  (checked), and no funnel KPI depends on either — the only place it surfaces
  is `session_duration_sec = MAX(duration_sec)` behind the segment averages.
  Read the time-in-funnel benchmarks as the platform's own stopwatch, not as
  differences between timestamps.
