# Tableau Workbook — Product_Experience_KPIs.twbx

Status: **built and published** — 11 worksheets + 1 dashboard, live on
Tableau Public (page reports first and last published 23 Oct 2026).

- **Live dashboard:**
  https://public.tableau.com/app/profile/isfaque.ansari5273/viz/Product_Experience_KPIs/ProductExperienceKPIs
- **Packaged file:** `Product_Experience_KPIs.twbx` in this folder — the two
  build CSVs and the Hyper extract travel inside it, plus a `Documentation/`
  folder (its own build scripts, `validation.json` and revision notes).

## What the workbook is connected to

Two data sources, both CSV exports of the SQL reporting layer (no live
warehouse connection):

| Source in the workbook | File | Rows | Grain |
|---|---|---|---|
| `Session Level` | `tableau/data/session_level.csv` | 290 | one row per session |
| `Funnel Long` | `tableau/data/funnel_long.csv` | 16 | one row per (scope, stage) |

`session_level.csv` is a byte-for-byte export of the `session_level` view in
`sql/02_kpi_modeling.sql`. `funnel_long.csv` is the long table the funnel
sheets need: `kpi_funnel_stage` as the `All Devices` block, plus
`kpi_device_funnel` with `page_url` and the stage/cumulative retention
columns computed per device. Both are reproduced by
`python python/export_tableau_data.py`, and the copies packaged inside the
`.twbx` are byte-identical to the ones in `tableau/data/` — so the published
dashboard and the repo's CSVs cannot silently diverge.

The other seven CSVs in `tableau/data/` are **verification references** (they
are the remaining SQL views: `kpi_funnel_stage`, `kpi_device_funnel`,
`kpi_device_performance`, `kpi_segment_performance`, `kpi_error_impact`,
`kpi_daily_trend`, `cleaned_events`). `verify_analysis.py` runs the SQL on
DuckDB and diffs all eight against those files.

## Sheets as built

| Sheet | Source | Shows | Checkpoint |
|---|---|---|---|
| `KPI - Sessions` | Session Level | BAN: total sessions | 290 |
| `KPI - Conversions` | Session Level | BAN: conversions | 167 |
| `KPI - Conv Rate` | Session Level | BAN: overall conversion rate | 57.59% |
| `KPI - Mobile Error Rate` | Session Level | BAN, filtered to Mobile | 28.57% |
| `Funnel` | Funnel Long | 4 stage bars, All Devices only | 290 → 241 → 201 → 167; cumulative 100 / 83.10 / 69.31 / 57.59% |
| `Device Funnel` | Funnel Long | same funnel per device | Desktop 142→134→114→101 · Mobile 98→61→50→36 · Tablet 50→46→37→30 |
| `Device Performance` | Session Level | conversion rate by device | Desktop 71.13% · Tablet 60.00% · Mobile 36.73% |
| `Device Table` | Session Level | scorecard: sessions, conversions, rate, drop-offs, error sessions, error rate | the device table in the root README |
| `Error Impact` | Session Level, Mobile only | with vs without `ERR_MOBILE_RENDER_502` | 28 sessions / 0.00% vs 70 / 51.43% |
| `Segments` | Session Level | conversion rate by segment | Premium 64.86% · Enterprise 60.00% · Free 53.61% |
| `Daily Trend` | Session Level | conversion rate + mobile error rate over 14 days | 14 points, 1–14 Sep 2026 |
| `Product Experience KPIs` | both | the dashboard: 4 KPI cards, funnel, device, error impact, segments, trend, filters | — |

**Global filters:** the published workbook uses two **parameters** — `Device`
and `Segment` (list parameters, default `All`) — combined in a
`Selected Device and Segment` boolean calculated field. Four sheets reference
the Parameters source and therefore respond to them: `Device Performance`,
`Device Table`, `Segments`, `Daily Trend`. The two Funnel Long sheets are
deliberately excluded — they carry their own `device_type` filter (All Devices
on `Funnel`, the three real devices on `Device Funnel`), so a cross-source
filter would blank them out.

`tableau/step_by_step_tableau_guide.md` Step 19 instead describes the native
apply-to-worksheets filter route. Both are valid; the workbook as published
uses parameters, and `verify_analysis.py` checks that from the workbook XML.

**Calculated fields:** the workbook really carries the 9 fields from the
guide's Step 5 (`Total Sessions`, `Conversions`, `Conversion Rate`,
`Drop-offs`, `Error Sessions`, `Error Rate`, `Mobile Error Rate`,
`Error Cohort`, `Avg Session Duration`) with the same formulas, plus the two
parameters and the `Selected Device and Segment` filter field.

## Build walkthroughs

- `tableau/step_by_step_tableau_guide.md` — 23 steps, the short version.
- `tableau/Tableau_Build_Guide_Product_Experience_KPIs.pdf` — the same build at
  93 steps, one tick-box per click, for someone who has never opened Tableau.

Both build only on the two sources above and both carry the ✅ checkpoints
listed in the table.

## What is verified, and what is not

Verified in this repo, by `verify_analysis.py`:

- every number in the checkpoints above recomputes from `data/raw_sample_data.csv`;
- the two build sources are byte-reproducible from the SQL layer;
- the packaged `.twbx` contains the same `session_level.csv` / `funnel_long.csv`
  as `tableau/data/`;
- the workbook XML really holds 11 worksheets + 1 dashboard with the names above;
- the Tableau Public URL resolves to that workbook and view (control-tested
  against a non-existent workbook, which returns `resource-not-found`);
- and the published view **renders**. Opened in a browser on 23 Oct 2026, the
  link above served `Product_Experience_KPIs | Tableau Public` and drew the
  dashboard with its four KPI tiles (*Sessions, Conversions, Conversion Rate,
  Mobile Error Rate*), the `Funnel` sheet with its `Page View` / `Signup
  Started` stage labels, the `Daily Trend` caption and its blue-conversion /
  red-error legend, plus the two additional sheets `Device Funnel` and `Device
  Table`. That is Tableau's own runtime, not a screenshot — but the check read
  labels and sheet names only; the numbers on screen were not reconciled
  against the CSVs.

Not verified here (and `Documentation/validation.json` inside the `.twbx`
says so itself):

- desktop Tableau authoring — the packaged `.twbx` was never opened in a local
  Tableau install, so its calculated fields have not been executed by a desktop
  runtime (`native_tableau_render_verified: false`; the published-view render
  above is Tableau Public's server-side runtime, which is not the same thing);
- filter interaction at runtime — the workbook really defines the `Device` and
  `Segment` parameters and exactly four worksheets reference them, but nobody
  has moved those sliders (`interaction_runtime_verified: false`);
- the Hyper extract's *measure values*: what is readable from the extract file
  is its string pool — the 290 `SES-*` / `USR-*` row keys, the three device
  types, `/landing` and `/dashboard`, and three of the four funnel stage labels
  (Hyper packs its strings, so `Onboarding Completed` never appears as a
  literal) — and those agree with the CSVs. The numeric columns were never
  decoded, and `validation.json` records that itself under
  `extract_data_runtime_validation: false`, next to `extract_origin`:
  *"Uploaded Book1.twbx; original extract bytes retained unchanged."*
