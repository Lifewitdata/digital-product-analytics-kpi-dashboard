# Tableau Build Guide — Product_Experience_KPIs
### Step-by-step: build the workbook yourself, sheet by sheet

You are building **11 worksheets + 1 dashboard** named `Product_Experience_KPIs`
(Part C numbers the sheets 1–10; `Device Table` from Step 12 is the eleventh).
Every number you should see is written as a ✅ checkpoint after each sheet — if
your sheet shows a different number, stop and fix that sheet before moving on
(the fix is almost always in the *Common problems* table at the end).

**Works in:** Tableau Public (free) or Tableau Desktop. All data sources are
CSV files, no database connection needed.

---

## Files you will use (in `dashboards/tableau/data/`)

| File | Rows | Used for |
|---|---|---|
| `session_level.csv` | 290 | **Main data source** — KPI cards, device, segment, error impact, daily trend (one row per session) |
| `funnel_long.csv` | 16 | Funnel sheets (stage grain: 4 stages × All Devices / Desktop / Mobile / Tablet) |
| `kpi_funnel_stage.csv` | 4 | Verification only — do not build on it |
| `kpi_device_funnel.csv` | 12 | Verification only — the device rows that `funnel_long.csv` carries |
| `kpi_device_performance.csv` | 3 | Verification only |
| `kpi_segment_performance.csv` | 3 | Verification only |
| `kpi_error_impact.csv` | 2 | Verification only |
| `kpi_daily_trend.csv` | 14 | Verification only |
| `cleaned_events.csv` | 1,000 | Not needed for this workbook (event-grain backup) |

> Why two build sources? Funnel stages need a *long* table (one row per stage)
> to draw bars in stage order, while every other sheet is easiest at
> *session* grain, where filters for device / segment / date work normally.

---

# PART A — Connect the data

### Step 1 — Open Tableau and connect `session_level.csv`
- [ ] Open Tableau → **Connect → To a File → Text File**
- [ ] Select `dashboards/tableau/data/session_level.csv`
- [ ] You land on the Data Source page. At the bottom you should see 290 rows.

### Step 2 — Check the field types (Data Source page)
Click the icon above each column and confirm / set:

- [ ] `session_date` → **Date**
- [ ] `session_id`, `user_id` → **String** (keep them as Dimensions later)
- [ ] `device_type`, `user_segment` → **String**
- [ ] `is_converted`, `has_render_error`, `reached_page_view`,
      `reached_signup_started`, `reached_form_step_1` → **Number (whole)**
- [ ] `session_duration_sec`, `event_count` → **Number (decimal / whole)**

### Step 3 — Add the second data source
- [ ] Menu **Data → New Data Source → Text File** → select `funnel_long.csv`
- [ ] Rename it (right-click the source name → Rename): **`Funnel Long`**
- [ ] Rename the first source: **`Session Level`**
- [ ] In `Funnel Long`, set `stage_order` → Number (whole), `sessions` →
      Number (whole). `stage_retention_pct` and `cumulative_retention_pct`
      stay decimal numbers — they already hold values like `83.10`
      (see the % warning in Step 9).

### Step 4 — Go to Sheet 1
- [ ] Click **Sheet 1** at the bottom. All of Part B happens on the
      **Session Level** source (check the highlighted source name in the
      Data pane before each sheet).

---

# PART B — Calculated fields (Session Level source)

Create each field: in the Data pane, click the small ▼ at the top →
**Create Calculated Field** → paste the formula → OK.
Field names must match exactly what is written here, the sheets refer to them.

### Step 5 — Create the 9 calculated fields

- [ ] **Total Sessions**
  ```
  COUNTD([session_id])
  ```
- [ ] **Conversions**
  ```
  SUM([is_converted])
  ```
- [ ] **Conversion Rate**
  ```
  SUM([is_converted]) / COUNTD([session_id])
  ```
  Then: right-click the field → **Default Properties → Number Format →
  Percentage, 2 decimal places**.
- [ ] **Drop-offs**
  ```
  COUNTD([session_id]) - SUM([is_converted])
  ```
- [ ] **Error Sessions**
  ```
  SUM([has_render_error])
  ```
- [ ] **Error Rate**
  ```
  SUM([has_render_error]) / COUNTD([session_id])
  ```
  Format as Percentage, 2 decimal places.
- [ ] **Mobile Error Rate** (works even when the sheet is not filtered to Mobile)
  ```
  SUM(IF [device_type] = "Mobile" THEN [has_render_error] END)
  /
  SUM(IF [device_type] = "Mobile" THEN 1 END)
  ```
  Format as Percentage, 2 decimal places.
- [ ] **Error Cohort** (this one is a *dimension* — drag it to Dimensions after creating)
  ```
  IF [has_render_error] = 1 THEN "With ERR_MOBILE_RENDER_502" ELSE "Without error" END
  ```
- [ ] **Avg Session Duration**
  ```
  AVG([session_duration_sec])
  ```
  Format: Number, 1 decimal place.

### ✅ Checkpoint B — test the fields
Drag **Total Sessions**, **Conversions**, **Conversion Rate** onto the
**Text** marks card of the blank sheet. You must see:

| Total Sessions | Conversions | Conversion Rate |
|---|---|---|
| 290 | 167 | 57.59% |

If Conversion Rate shows `0.58`, the number format is still decimal — fix it
in Step 5. Clear the sheet before continuing (drag everything off).

---

# PART C — The 11 worksheets

## Sheet 1–4 — KPI cards (BANs)

You will make 4 tiny worksheets, one per KPI card. The method is identical;
only the field and the filter change.

### Step 6 — KPI card method (do it for the first card)
- [ ] New worksheet, rename it **`KPI - Sessions`**
- [ ] Drag **Total Sessions** onto **Text**
- [ ] Click the **Label** marks card → set font size **28**, bold
- [ ] Menu **Format → Borders** → set all to None; **Worksheet → Show Title** off
- [ ] Toolbar: set the view to **Entire View**

### Step 7 — The other three cards (duplicate and change)
Right-click the `KPI - Sessions` tab → **Duplicate**, then change the field:

- [ ] **`KPI - Conversions`** → replace with **Conversions** → ✅ shows **167**
- [ ] **`KPI - Conv Rate`** → replace with **Conversion Rate** → ✅ shows **57.59%**
- [ ] **`KPI - Mobile Error Rate`** → replace with **Mobile Error Rate**, and
      drag `device_type` to **Filters** → tick **Mobile** only → ✅ shows **28.57%**

Rename each tab exactly as written — the dashboard steps use these names.

## Sheet 5 — Funnel

### Step 8 — Switch source and set the filter
- [ ] New worksheet, rename **`Funnel`**
- [ ] In the Data pane, click the **`Funnel Long`** source (this sheet is
      built on it — all other Part C sheets use Session Level)
- [ ] Drag `device_type` (from Funnel Long) to **Filters** → tick
      **All Devices** only

### Step 9 — Build the bars
- [ ] Drag `funnel_stage` to **Rows**
- [ ] Drag `sessions` to **Columns** (it becomes SUM(sessions))
- [ ] Sort the stages: click the `funnel_stage` pill in Rows → **Sort** →
      Sort By **Field** → Field Name `stage_order` → **Ascending** →
      Aggregation **Minimum**. (This is what keeps Page View on top instead
      of alphabetical order.)
- [ ] Drag `sessions` again onto **Label**
- [ ] Drag `cumulative_retention_pct` onto **Label** as well
- [ ] Select both retention pills in the Marks card → format each as
      **Number (Custom)** with suffix `"%"` — ⚠️ do **not** use the Percentage
      format here: the values are already percentages (83.10 means 83.10%),
      Percentage format would multiply them by 100 and show 8310%.
- [ ] Drag `funnel_stage` onto **Color**; keep the default palette or set
      the four stages to shades of blue `#4C72B0`
- [ ] Add `stage_retention_pct` to **Tooltip** (same `"%"` custom format)

### ✅ Checkpoint C1
Bars must read, top to bottom: **290, 241, 201, 167** with cumulative labels
**100.00%, 83.10%, 69.31%, 57.59%** — identical to `kpi_funnel_stage.csv`.

## Sheet 6 — Device Funnel Comparison

### Step 10 — Small multiples per device (still Funnel Long source)
- [ ] Duplicate the `Funnel` sheet → rename **`Device Funnel`**
- [ ] On the Filters card, change `device_type` to **Desktop, Mobile, Tablet**
      (untick All Devices)
- [ ] Drag `device_type` to **Columns**, to the **left** of SUM(sessions)…
      if Tableau nests it awkwardly, instead put `device_type` on **Rows**
      above `funnel_stage` — either gives one mini-funnel per device.

### ✅ Checkpoint C2
Desktop **142 → 134 → 114 → 101** · Mobile **98 → 61 → 50 → 36** ·
Tablet **50 → 46 → 37 → 30**.

## Sheet 7 — Device Performance

### Step 11 — Conversion rate by device (back to Session Level source)
- [ ] New worksheet, rename **`Device Performance`**. Confirm the Data pane
      source is **Session Level**
- [ ] Drag `device_type` to **Rows**
- [ ] Drag **Conversion Rate** to **Columns**
- [ ] Sort descending: click the axis sort icon (or right-click `device_type`
      → Sort → By Field → Conversion Rate → Descending)
- [ ] Drag **Conversion Rate** onto **Label**, and **Total Sessions** onto
      **Tooltip**
- [ ] Drag `device_type` onto **Color** → Edit Colors, set manually:
      Desktop `#55A868` (green) · Tablet `#DD8452` (orange) · Mobile `#C44E52` (red)

### ✅ Checkpoint C3
Desktop **71.13%** · Tablet **60.00%** · Mobile **36.73%**.

### Step 12 — Device scorecard table (optional but strong on the dashboard)
- [ ] New worksheet, rename **`Device Table`**
- [ ] `device_type` → **Rows**
- [ ] Drag these onto **Text** one by one: **Total Sessions, Conversions,
      Conversion Rate, Drop-offs, Error Sessions, Error Rate**
      (Tableau creates a Measure Names / Measure Values table)

### ✅ Checkpoint C4 — the table must match this exactly

| Device | Sessions | Conversions | Conv. rate | Drop-offs | Error sessions | Error rate |
|---|---|---|---|---|---|---|
| Desktop | 142 | 101 | 71.13% | 41 | 0 | 0.00% |
| Mobile | 98 | 36 | 36.73% | 62 | 28 | 28.57% |
| Tablet | 50 | 30 | 60.00% | 20 | 0 | 0.00% |

## Sheet 8 — Error Impact

### Step 13 — Mobile, with vs without the error
- [ ] New worksheet (Session Level), rename **`Error Impact`**
- [ ] Drag `device_type` to **Filters** → **Mobile** only
- [ ] Drag **Error Cohort** to **Columns**
- [ ] Drag **Total Sessions** to **Rows** → bars of 28 and 70
- [ ] Drag **Conversion Rate** onto **Label** (format is already % from Step 5)
- [ ] Drag **Conversions** onto **Tooltip**
- [ ] Colour: drag **Error Cohort** to Color → `With ERR_MOBILE_RENDER_502`
      = `#C44E52`, `Without error` = `#55A868`

### ✅ Checkpoint C5
**With error: 28 sessions, 0 conversions, 0.00%** ·
**Without error: 70 sessions, 36 conversions, 51.43%** —
matches `kpi_error_impact.csv`.

## Sheet 9 — Segments

### Step 14 — Conversion rate by user segment
- [ ] New worksheet (Session Level), rename **`Segments`**
- [ ] `user_segment` → **Rows**; **Conversion Rate** → **Columns**
- [ ] Sort descending by Conversion Rate
- [ ] **Conversion Rate** → **Label**; **Error Sessions** and
      **Total Sessions** → **Tooltip**
- [ ] Colour all bars `#8172B2`, or `user_segment` on Color with default palette

### ✅ Checkpoint C6
Premium **64.86%** (74 sessions) · Enterprise **60.00%** (50) ·
Free **53.61%** (166). Error sessions in tooltips: Premium 7, Enterprise 4, Free 17.

## Sheet 10 — Daily Trend

### Step 15 — Two lines over 14 days
- [ ] New worksheet (Session Level), rename **`Daily Trend`**
- [ ] Drag `session_date` to **Columns** → right-click the pill → choose
      **Day** (continuous, green pill) — exact date, not the blue discrete one
- [ ] Drag **Measure Values** to **Rows**; on the Measure Values card remove
      everything except **Conversion Rate** and **Mobile Error Rate**,
      then drag **Measure Names** to **Color**
- [ ] Format both as % (already set in Step 5); set the axis title to `%`

### ✅ Checkpoint C7
14 points (1–14 Sep 2026). Eyeball check only — daily volumes are ~21
sessions, so the lines are noisy. Sum of sessions across the trend must
still be 290 (check against `kpi_daily_trend.csv` if unsure).

---

# PART D — Assemble the dashboard

### Step 16 — Create the dashboard
- [ ] New Dashboard → rename **`Product Experience KPIs`**
- [ ] Size → **Fixed size → Custom: 1280 × 850**
- [ ] Add a **Text** object at the top:
      **Title:** `Digital Product Experience — KPI Dashboard`
      **Subtitle (smaller):** `Onboarding funnel · 290 sessions · 1–14 Sep 2026`

### Step 17 — Lay out the tiles (drag sheets from the left panel)
```
┌────────────┬────────────┬────────────┬──────────────────┐
│ KPI -      │ KPI -      │ KPI -      │ KPI - Mobile     │
│ Sessions   │ Conversions│ Conv Rate  │ Error Rate       │
├──────────────────────┬───────────────────────────────┤
│ Funnel               │ Device Performance            │
│                      │ (+ Device Table underneath)   │
├──────────────────────┬───────────────────────────────┤
│ Error Impact         │ Segments                      │
├─────────────────────────────────────────────────────┤
│ Daily Trend (full width)                            │
└─────────────────────────────────────────────────────┘
```
- [ ] Use **Vertical / Horizontal containers** (Objects panel) for the rows —
      do not free-place tiles, containers keep the layout clean
- [ ] Set each sheet tile to **Fit → Entire View**, hide every sheet title
      (right-click title → Hide Title) and write short tile titles as Text
      objects instead: *Funnel — sessions per stage*, *Conversion rate by
      device*, *Mobile: error vs no error*, *Conversion rate by segment*,
      *Daily trend*

### Step 18 — Add the insight text box (right side or below the KPIs)
- [ ] Drag a **Text** object in and paste:

> **Headline:** Mobile converts at 36.73% vs Desktop 71.13%. The cause is
> ERR_MOBILE_RENDER_502 — a rendering error on /onboarding-1 that hits
> 28.57% of mobile sessions; every affected session drops out and none convert.
> **Fix value:** ~+14 conversions per 98 mobile sessions (realistic, mobile
> → ~51.4%); upper bound 65.31% if every error session converted.

### Step 19 — Dashboard filters
Two ways to do this; both ship in the published workbook's notes. Follow
**Option A** here (native cross-sheet filters) — the workbook on Tableau Public
uses **Option B** (parameters) instead; see `dashboards/README.md`.

**Option A — apply-to-worksheets filters (this guide):**
- [ ] Select the `Device Performance` tile → its ▼ menu → **Filters →
      `device_type`** → the filter card appears on the right
- [ ] On that filter card's ▼ → **Apply to Worksheets → Selected Worksheets**
      → tick the Session Level sheets: Device Performance, Device Table,
      Segments, Daily Trend, and the three KPI cards (not Mobile Error Rate)
- [ ] Repeat for `user_segment` from the `Segments` tile, same target sheets
- [ ] ⚠️ Do **not** apply these filters to `Funnel` / `Device Funnel` —
      they use the Funnel Long source and have their own `device_type`
      filter (Step 8/10). Cross-source filters here would blank them out.

**Option B — parameters (what the published workbook does):** create two
string **parameters**, `Device` and `Segment` (Allowed values → List:
`All`, `Desktop`/`Mobile`/`Tablet`, `All`, `Enterprise`/`Premium`/`Free`;
Current value → `All`), then one boolean calculated field —

```
([Parameters].[Device filter] = "All" OR [device_type] = [Parameters].[Device filter])
AND
([Parameters].[Segment filter] = "All" OR [user_segment] = [Parameters].[Segment filter])
```

— and put it on the **Filters** card of `Device Performance`, `Device Table`,
`Segments` and `Daily Trend` only. Same result as Option A, with one pair of
dropdowns on the dashboard instead of two filter cards.

### Step 20 — Final formatting pass
- [ ] Dashboard → Format → Font: one family throughout (Tableau Book / Arial)
- [ ] Background: white or very light grey `#F7F7F7`; KPI numbers stay 28pt bold
- [ ] Check every % one last time against the checkpoints — especially that
      no label reads 5759% or 8310% (that is the Step 9 format trap)

---

# PART E — Save, publish, verify

### Step 21 — Save the workbook
- [ ] **File → Save As** → name **`Product_Experience_KPIs`**
- [ ] Save it into the project's `dashboards/` folder.
      Tableau Public saves to the web instead — after publishing (Step 22),
      use **File → Save to Tableau Public As** with the same name.
      Desktop users: choose **Packaged Workbook (.twbx)** so the CSVs travel
      with the file.

### Step 22 — Publish to Tableau Public
- [ ] **Server → Publish Workbook** (or Save to Tableau Public) → sign in
- [ ] Name: `Product_Experience_KPIs`, add the description:
      *Onboarding funnel KPI dashboard — device friction and
      ERR_MOBILE_RENDER_502 root-cause analysis (290 sessions)*
- [ ] After it opens in the browser, copy the URL and paste it into
      `dashboards/README.md` under “Workbook status”.

### Step 23 — Final verification (tick every row before calling it done)

| Check | Expected |
|---|---|
| KPI cards | 290 · 167 · 57.59% · 28.57% (mobile error) |
| Funnel | 290 → 241 → 201 → 167; cumulative 100 / 83.10 / 69.31 / 57.59% |
| Device rates | Desktop 71.13% · Tablet 60.00% · Mobile 36.73% |
| Device table | matches Checkpoint C4 table exactly |
| Error impact | 28 sessions / 0.00% vs 70 sessions / 51.43% |
| Segments | Premium 64.86% · Enterprise 60.00% · Free 53.61% |
| Trend | 14 days, 1–14 Sep 2026 |
| Filters | device/segment filters move the Session Level sheets; funnel sheets unchanged |

---

## Common problems

| Problem | Cause | Fix |
|---|---|---|
| Conversion rate shows 5759% | Field formatted as % twice, or value stored as 57.59 | Conversion Rate formula returns a ratio (0.5759) — format as Percentage (Step 5). The funnel retention fields are the opposite: use custom `"%"` suffix (Step 9) |
| Funnel stages in alphabetical order | Sorted by name, not stage | Sort `funnel_stage` by Field `stage_order`, Minimum, Ascending (Step 9) |
| Funnel shows 1,000 instead of 290 | Built on `cleaned_events.csv` (events, not sessions) | Funnel sheets use `funnel_long.csv` only; KPI sheets use `session_level.csv` |
| KPI cards change when device filter is applied on the dashboard | Filter applied to all worksheets | Re-apply Step 19 targeting — KPI cards keep no device filter except Mobile Error Rate |
| Error Impact shows all devices | Missing filter | Step 13: `device_type` = Mobile must be on Filters for that sheet |
| Daily trend shows months/quarters | `session_date` pill is discrete (blue) | Right-click pill → Day (continuous, green) — Step 15 |
| Numbers off by a few sessions on a sheet | A leftover filter from duplicating a sheet | Open the Filters card on that sheet and compare with the step that created it |
