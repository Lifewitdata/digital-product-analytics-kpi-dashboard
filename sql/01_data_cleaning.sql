-- =====================================================================
-- 01_data_cleaning.sql
-- Digital Product Analytics KPI Dashboard
--
-- Purpose : Data quality validation and cleaning of raw clickstream
--           telemetry before any KPI is computed.
-- Input   : raw_events  (load data/raw_sample_data.csv into a table
--           named raw_events first — one row per telemetry event)
-- Output  : cleaned_events (view) — deduped, typed, standardised.
-- Dialect : Standard SQL (verified on DuckDB; portable to BigQuery /
--           Snowflake with the same syntax).
--
-- Rule #1 of this project: every KPI is counted in UNIQUE SESSIONS.
-- Raw event counts are telemetry volume, not funnel performance.
-- =====================================================================


-- ---------------------------------------------------------------------
-- STEP 1 — Cleaned events view
--   * drop exact re-sends: one row per event_id (keep earliest)
--   * drop rows that cannot belong to a session (null keys / timestamp)
--   * normalise types and labels so downstream SQL never re-cleans
--   * turn the empty-string error_code of the CSV into a real NULL
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW cleaned_events AS
WITH deduped AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY event_id
            ORDER BY event_timestamp
        ) AS rn
    FROM raw_events
)
SELECT
    event_id,
    TRIM(session_id)                                    AS session_id,
    TRIM(user_id)                                       AS user_id,
    CAST(event_timestamp AS TIMESTAMP)                  AS event_timestamp,
    CAST(CAST(event_timestamp AS TIMESTAMP) AS DATE)    AS event_date,
    LOWER(TRIM(event_type))                             AS event_type,
    TRIM(page_url)                                      AS page_url,
    CASE
        WHEN TRIM(device_type) IN ('Desktop', 'Mobile', 'Tablet')
            THEN TRIM(device_type)
        ELSE 'Unknown'
    END                                                 AS device_type,
    CASE
        WHEN TRIM(user_segment) IN ('Enterprise', 'Premium', 'Free')
            THEN TRIM(user_segment)
        ELSE 'Unknown'
    END                                                 AS user_segment,
    NULLIF(TRIM(error_code), '')                        AS error_code,
    CAST(duration_sec AS DOUBLE)                        AS duration_sec
FROM deduped
WHERE rn = 1
  AND session_id IS NOT NULL
  AND user_id    IS NOT NULL
  AND event_timestamp IS NOT NULL
  AND CAST(duration_sec AS DOUBLE) >= 0;


-- ---------------------------------------------------------------------
-- STEP 2 — Data quality validation checks
-- Each check returns failed_rows. Expected result for the sample
-- dataset: 0 on every check (the Python checker in
-- python/data_quality_checks.py asserts the same rules).
-- ---------------------------------------------------------------------

-- 2.1 Duplicate event_ids surviving the dedupe
SELECT 'duplicate_event_id' AS check_name,
       COUNT(*) - COUNT(DISTINCT event_id) AS failed_rows
FROM cleaned_events;

-- 2.2 Missing critical fields
SELECT 'missing_critical_field' AS check_name,
       COUNT(*) AS failed_rows
FROM cleaned_events
WHERE session_id IS NULL OR user_id IS NULL OR event_timestamp IS NULL
   OR event_type IS NULL OR device_type IS NULL OR user_segment IS NULL;

-- 2.3 Unknown / unstandardised dimension values
SELECT 'unknown_device_or_segment' AS check_name,
       COUNT(*) AS failed_rows
FROM cleaned_events
WHERE device_type = 'Unknown' OR user_segment = 'Unknown';

-- 2.4 Event/page mapping broken (each funnel event has one home page)
SELECT 'event_page_mismatch' AS check_name,
       COUNT(*) AS failed_rows
FROM cleaned_events
WHERE (event_type = 'page_view'             AND page_url <> '/landing')
   OR (event_type = 'signup_started'        AND page_url <> '/onboarding-1')
   OR (event_type = 'form_step_1_completed' AND page_url <> '/onboarding-2')
   OR (event_type = 'onboarding_completed'  AND page_url <> '/dashboard');

-- 2.5 Rendering error appearing off Mobile or off /onboarding-1
SELECT 'error_code_misplaced' AS check_name,
       COUNT(*) AS failed_rows
FROM cleaned_events
WHERE error_code IS NOT NULL
  AND (error_code <> 'ERR_MOBILE_RENDER_502'
       OR device_type <> 'Mobile'
       OR page_url <> '/onboarding-1');

-- 2.6 Funnel order violation: a session reaching a later stage
--     without the stage before it
SELECT 'funnel_order_violation' AS check_name,
       COUNT(*) AS failed_rows
FROM (
    SELECT
        session_id,
        MAX(CASE WHEN event_type = 'page_view'             THEN 1 ELSE 0 END) AS has_pv,
        MAX(CASE WHEN event_type = 'signup_started'        THEN 1 ELSE 0 END) AS has_su,
        MAX(CASE WHEN event_type = 'form_step_1_completed' THEN 1 ELSE 0 END) AS has_f1,
        MAX(CASE WHEN event_type = 'onboarding_completed'  THEN 1 ELSE 0 END) AS has_oc
    FROM cleaned_events
    GROUP BY session_id
) s
WHERE (has_su = 1 AND has_pv = 0)
   OR (has_f1 = 1 AND has_su = 0)
   OR (has_oc = 1 AND has_f1 = 0);

-- 2.7 Device or segment changing inside a session
SELECT 'session_attribute_drift' AS check_name,
       COUNT(*) AS failed_rows
FROM (
    SELECT session_id
    FROM cleaned_events
    GROUP BY session_id
    HAVING COUNT(DISTINCT device_type) > 1
        OR COUNT(DISTINCT user_segment) > 1
) d;
