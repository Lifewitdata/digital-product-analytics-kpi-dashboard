# Data Dictionary — Digital Product Analytics KPI Dashboard

Dataset: `data/raw_sample_data.csv`
An anonymized sample of product telemetry (clickstream) events for a digital
onboarding funnel. No names, emails, IPs, or free text are present; users and
sessions are pseudonymous IDs only.

- **Rows:** 1,000 events
- **Sessions:** 290 unique `session_id`, **Users:** 290 unique `user_id`
  (in this sample each user has exactly one onboarding session)
- **Window:** 1–14 September 2026
- **Grain:** one row per telemetry event

## Columns

| Column | Type | Description |
|---|---|---|
| `event_id` | string | Unique event identifier (`EVT-0001` …). Primary key of the file. |
| `session_id` | string | Onboarding session the event belongs to (`SES-0001` …). All funnel KPIs are counted in **unique sessions**, never raw events. |
| `user_id` | string | Pseudonymous user identifier (`USR-0001` …). |
| `event_timestamp` | timestamp | When the event fired, `YYYY-MM-DD HH:MM:SS`. |
| `event_type` | string | Telemetry event name — see Event Types below. |
| `page_url` | string | Page the event fired on — see mapping below. |
| `device_type` | string | `Desktop`, `Mobile`, or `Tablet`. Constant within a session. |
| `user_segment` | string | Plan segment: `Enterprise`, `Premium`, or `Free`. Constant within a session. |
| `error_code` | string | Empty for normal events. `ERR_MOBILE_RENDER_502` on rendering-error events (Mobile only). |
| `duration_sec` | float | Cumulative time-in-funnel in seconds when the event fired, to one decimal — the platform's own stopwatch. Increases monotonically inside a session, and the session's duration is its last event's value. **Not** the difference to `event_timestamp`: see the clock note below. |

## Event types and funnel mapping

| Funnel stage | `event_type` | `page_url` | Unique sessions |
|---|---|---|---|
| 1. Page View | `page_view` | `/landing` | 290 |
| 2. Signup Started | `signup_started` | `/onboarding-1` | 241 |
| 3. Form Step 1 Completed | `form_step_1_completed` | `/onboarding-2` | 201 |
| 4. Onboarding Completed (conversion) | `onboarding_completed` | `/dashboard` | 167 |
| — (non-funnel) | `button_click` | `/landing` | 73 events |
| — (non-funnel) | `error` | `/onboarding-1` | 28 events |

Event budget check: 290 + 241 + 201 + 167 funnel events + 73 `button_click`
+ 28 `error` = **1,000 events**.

## KPI definitions

| KPI | Definition |
|---|---|
| Total Sessions | `COUNT(DISTINCT session_id)` |
| Conversion (session) | A session containing an `onboarding_completed` event |
| Overall Conversion Rate | converted sessions / total sessions × 100 = 167 / 290 = **57.59%** |
| Stage Retention Rate | sessions reaching stage N / sessions reaching stage N−1 × 100 |
| Cumulative Funnel Retention | sessions reaching stage N / sessions reaching stage 1 × 100 |
| Device Conversion Rate | converted sessions on the device / total sessions on the device × 100 |
| Drop-offs (device) | sessions on the device − converted sessions on the device |
| Error Session | A session containing ≥ 1 event with `error_code = 'ERR_MOBILE_RENDER_502'` |
| Error Rate (platform) | error sessions on the platform / total sessions on the platform × 100 |
| Session Duration | `duration_sec` of the session's last event (seconds in funnel) |
| Time-in-Funnel Benchmark | mean / median / std of `duration_sec` grouped by funnel `event_type` |

## Known data characteristics (verified by `python/data_quality_checks.py`)

- `ERR_MOBILE_RENDER_502` occurs **only** on Mobile, only on `/onboarding-1`,
  in 28 sessions (28.57% of mobile sessions). All 28 error sessions drop out
  before `signup_started`.
- `device_type` and `user_segment` never change inside a session.
- Funnel stages are strictly ordered inside every session — no session skips
  a stage or fires a later stage before an earlier one.
- `button_click` is engagement telemetry, not a funnel stage; excluding it
  from funnel counts is required, or stage totals will not reconcile.
- **Two clocks.** `duration_sec` runs ahead of `event_timestamp`. Every
  session's first event already carries 3.0–23.9s of `duration_sec` (mean
  11.63s) while its timestamp delta is 0 by definition, and inside a session
  the two clocks drift apart by up to 1.0s (mean spread 0.50s). Both are
  monotonic — that is checked — but a time-in-funnel number quoted from
  `duration_sec` is not the same as one measured between timestamps. The
  benchmarks below are the `duration_sec` means, which is what the notebook
  and the dashboard publish.
- `ERR_MOBILE_RENDER_502` fires on 13 of the 14 days (2–14 Sep; day 1 has no
  errors), so it reads as a persistent defect rather than a one-day outage.

### Time-in-funnel benchmarks (mean / median of `duration_sec`)

| Funnel event | n | mean | median | std |
|---|---|---|---|---|
| `page_view` | 290 | 11.6s | 11.6s | 4.2 |
| `signup_started` | 241 | 37.6s | 37.8s | 7.3 |
| `form_step_1_completed` | 201 | 80.8s | 81.6s | 10.8 |
| `onboarding_completed` | 167 | 141.8s | 143.1s | 21.6 |
| `error` (`ERR_MOBILE_RENDER_502`) | 28 | 37.8s | 36.8s | 4.8 |

The error fires 37.8s into the session on average — the same moment
`signup_started` fires in sessions that get there, which is what places it on
the signup render path rather than the landing page.

- The sample is a teaching/analysis sample: volumes are small (290 sessions),
  so rates should be read with their counts, not as production baselines.
