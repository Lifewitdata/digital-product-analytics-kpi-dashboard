-- =====================================================================
-- 02_kpi_modeling.sql
-- Digital Product Analytics KPI Dashboard
--
-- Purpose : Reporting layers for Tableau, built on cleaned_events
--           (run 01_data_cleaning.sql first).
-- Layers  : session_level           — one row per session (the grain
--                                     every KPI is computed from)
--           kpi_funnel_stage        — funnel with stage + cumulative
--                                     retention
--           kpi_device_funnel       — funnel split by device (long
--                                     format, Tableau-ready)
--           kpi_device_performance  — conversion / drop-off / errors
--                                     by device
--           kpi_segment_performance — conversion / errors / duration
--                                     by user segment
--           kpi_error_impact        — Mobile with vs without the
--                                     ERR_MOBILE_RENDER_502 error
--           kpi_daily_trend         — sessions, conversion and mobile
--                                     error rate by day
-- Verified results on the sample data:
--   290 sessions, 167 conversions, 57.59% overall conversion rate.
-- =====================================================================


-- ---------------------------------------------------------------------
-- LAYER 1 — session_level: collapse events to one row per session.
-- Funnel flags are MAX() over the session's events, so a session is
-- counted once per stage no matter how many events it fired.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW session_level AS
SELECT
    session_id,
    MIN(user_id)                                                AS user_id,
    MIN(device_type)                                            AS device_type,
    MIN(user_segment)                                           AS user_segment,
    MIN(event_date)                                             AS session_date,
    COUNT(*)                                                    AS event_count,
    MAX(CASE WHEN event_type = 'page_view'             THEN 1 ELSE 0 END) AS reached_page_view,
    MAX(CASE WHEN event_type = 'signup_started'        THEN 1 ELSE 0 END) AS reached_signup_started,
    MAX(CASE WHEN event_type = 'form_step_1_completed' THEN 1 ELSE 0 END) AS reached_form_step_1,
    MAX(CASE WHEN event_type = 'onboarding_completed'  THEN 1 ELSE 0 END) AS is_converted,
    MAX(CASE WHEN error_code = 'ERR_MOBILE_RENDER_502' THEN 1 ELSE 0 END) AS has_render_error,
    MAX(duration_sec)                                           AS session_duration_sec
FROM cleaned_events
GROUP BY session_id;


-- ---------------------------------------------------------------------
-- LAYER 2 — kpi_funnel_stage
-- Stage Retention = sessions at stage N / sessions at stage N-1
-- Cumulative      = sessions at stage N / sessions at stage 1
-- Expected: 290 -> 241 -> 201 -> 167 (83.10% / 83.40% / 83.08%,
-- cumulative 100.00% / 83.10% / 69.31% / 57.59%)
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW kpi_funnel_stage AS
WITH stage_counts AS (
    SELECT 1 AS stage_order, 'Page View'             AS funnel_stage,
           '/landing'     AS page_url, SUM(reached_page_view)      AS sessions
    FROM session_level
    UNION ALL
    SELECT 2, 'Signup Started',        '/onboarding-1',
           SUM(reached_signup_started) FROM session_level
    UNION ALL
    SELECT 3, 'Form Step 1 Completed', '/onboarding-2',
           SUM(reached_form_step_1)    FROM session_level
    UNION ALL
    SELECT 4, 'Onboarding Completed',  '/dashboard',
           SUM(is_converted)           FROM session_level
)
SELECT
    stage_order,
    funnel_stage,
    page_url,
    sessions,
    ROUND(100.0 * sessions
          / NULLIF(LAG(sessions) OVER (ORDER BY stage_order), 0), 2)
        AS stage_retention_pct,
    ROUND(100.0 * sessions
          / FIRST_VALUE(sessions) OVER (ORDER BY stage_order), 2)
        AS cumulative_retention_pct
FROM stage_counts;


-- ---------------------------------------------------------------------
-- LAYER 3 — kpi_device_funnel (long format for Tableau)
-- Expected final conversion: Desktop 71.13%, Mobile 36.73%,
-- Tablet 60.00%.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW kpi_device_funnel AS
SELECT device_type, 1 AS stage_order, 'Page View' AS funnel_stage,
       SUM(reached_page_view) AS sessions FROM session_level GROUP BY device_type
UNION ALL
SELECT device_type, 2, 'Signup Started',
       SUM(reached_signup_started) FROM session_level GROUP BY device_type
UNION ALL
SELECT device_type, 3, 'Form Step 1 Completed',
       SUM(reached_form_step_1) FROM session_level GROUP BY device_type
UNION ALL
SELECT device_type, 4, 'Onboarding Completed',
       SUM(is_converted) FROM session_level GROUP BY device_type;


-- ---------------------------------------------------------------------
-- LAYER 4 — kpi_device_performance
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW kpi_device_performance AS
SELECT
    device_type,
    COUNT(*)                                        AS total_sessions,
    SUM(is_converted)                               AS conversions,
    ROUND(100.0 * SUM(is_converted) / COUNT(*), 2)  AS conversion_rate_pct,
    COUNT(*) - SUM(is_converted)                    AS total_drop_offs,
    SUM(has_render_error)                           AS error_sessions,
    ROUND(100.0 * SUM(has_render_error) / COUNT(*), 2) AS error_rate_pct
FROM session_level
GROUP BY device_type;


-- ---------------------------------------------------------------------
-- LAYER 5 — kpi_segment_performance
-- Expected: Enterprise 50 / 30 / 60.00%, Premium 74 / 48 / 64.86%,
-- Free 166 / 89 / 53.61%; error sessions 4 / 7 / 17.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW kpi_segment_performance AS
SELECT
    user_segment,
    COUNT(*)                                        AS total_sessions,
    SUM(is_converted)                               AS conversions,
    ROUND(100.0 * SUM(is_converted) / COUNT(*), 2)  AS conversion_rate_pct,
    SUM(has_render_error)                           AS error_sessions,
    ROUND(AVG(session_duration_sec), 1)             AS avg_session_duration_sec
FROM session_level
GROUP BY user_segment;


-- ---------------------------------------------------------------------
-- LAYER 6 — kpi_error_impact (Mobile only)
-- Observed split on the sample data: the 28 error sessions convert at
-- 0%; the 70 Mobile sessions without the error convert at 51.43%.
-- Counterfactuals (notebook, section 9):
--   realistic  — error sessions converting at the no-error Mobile
--                rate add ~14 conversions (Mobile -> ~51.4%)
--   upper bound— every error session converting gives 64/98 = 65.31%
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW kpi_error_impact AS
SELECT
    CASE WHEN has_render_error = 1 THEN 'With ERR_MOBILE_RENDER_502'
         ELSE 'Without error' END                   AS mobile_cohort,
    COUNT(*)                                        AS total_sessions,
    SUM(is_converted)                               AS conversions,
    ROUND(100.0 * SUM(is_converted) / COUNT(*), 2)  AS conversion_rate_pct
FROM session_level
WHERE device_type = 'Mobile'
GROUP BY has_render_error;


-- ---------------------------------------------------------------------
-- LAYER 7 — kpi_daily_trend (Tableau trend sheet source)
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW kpi_daily_trend AS
SELECT
    session_date,
    COUNT(*)                                            AS sessions,
    SUM(is_converted)                                   AS conversions,
    ROUND(100.0 * SUM(is_converted) / COUNT(*), 2)      AS conversion_rate_pct,
    SUM(CASE WHEN device_type = 'Mobile' THEN 1 ELSE 0 END)
                                                        AS mobile_sessions,
    SUM(has_render_error)                               AS error_sessions,
    ROUND(100.0 * SUM(has_render_error)
          / NULLIF(SUM(CASE WHEN device_type = 'Mobile' THEN 1 ELSE 0 END), 0), 2)
                                                        AS mobile_error_rate_pct
FROM session_level
GROUP BY session_date;
