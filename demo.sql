-- DSCI 551 Final Project
-- Demo queries for ClickHouse sorting-key alignment
-- Run this script after schema.sql and data.sql.

SET log_queries = 1;
SET use_query_cache = 0;
SET log_comment = '';

SELECT 'ClickHouse sorting-key alignment demo' AS demo;

-- Confirm that both tables contain identical row counts.
SELECT
    (SELECT count() FROM exp_user_events_time_first) AS time_first_count,
    (SELECT count() FROM exp_user_events_country_first) AS country_first_count;

-- ============================================================
-- Q1: Recent-window revenue query
-- Application behavior: compute total revenue in the most recent 7 days.
-- Internal focus: time_first should allow stronger data skipping for the
-- event_time predicate because event_time is the leading sorting-key column.
-- ============================================================

SELECT 'Q1: recent-window revenue query' AS section;

SET log_comment = 'Q1_time_first_recent_revenue';
SELECT
    'time_first' AS layout,
    sum(revenue) AS total_revenue
FROM exp_user_events_time_first
WHERE event_time >= (
    SELECT max(event_time) - INTERVAL 7 DAY
    FROM exp_user_events_time_first
);

SET log_comment = 'Q1_country_first_recent_revenue';
SELECT
    'country_first' AS layout,
    sum(revenue) AS total_revenue
FROM exp_user_events_country_first
WHERE event_time >= (
    SELECT max(event_time) - INTERVAL 7 DAY
    FROM exp_user_events_country_first
);

-- ============================================================
-- Q2: Aggregation query by country
-- Application behavior: group recent events by country.
-- Internal focus: scan reduction before aggregation reduces the amount of
-- input data that reaches the aggregation stage.
-- ============================================================

SET log_comment = '';
SELECT 'Q2: recent-window aggregation by country' AS section;

SET log_comment = 'Q2_time_first_country_aggregation';
SELECT
    'time_first' AS layout,
    country,
    count() AS event_count,
    sum(revenue) AS total_revenue
FROM exp_user_events_time_first
WHERE event_time >= (
    SELECT max(event_time) - INTERVAL 7 DAY
    FROM exp_user_events_time_first
)
GROUP BY country
ORDER BY total_revenue DESC;

SET log_comment = 'Q2_country_first_country_aggregation';
SELECT
    'country_first' AS layout,
    country,
    count() AS event_count,
    sum(revenue) AS total_revenue
FROM exp_user_events_country_first
WHERE event_time >= (
    SELECT max(event_time) - INTERVAL 7 DAY
    FROM exp_user_events_country_first
)
GROUP BY country
ORDER BY total_revenue DESC;

-- ============================================================
-- Q3: Daily trend query
-- Application behavior: summarize revenue by day for a recent 30-day window.
-- Internal focus: the query uses only event_time and revenue, so it benefits
-- from ClickHouse columnar reads and time-based data skipping.
-- ============================================================

SET log_comment = '';
SELECT 'Q3: daily revenue trend query' AS section;

SET log_comment = 'Q3_time_first_daily_trend';
SELECT
    'time_first' AS layout,
    toDate(event_time) AS day,
    sum(revenue) AS total_revenue
FROM exp_user_events_time_first
WHERE event_time >= (
    SELECT max(event_time) - INTERVAL 30 DAY
    FROM exp_user_events_time_first
)
GROUP BY day
ORDER BY day;

SET log_comment = 'Q3_country_first_daily_trend';
SELECT
    'country_first' AS layout,
    toDate(event_time) AS day,
    sum(revenue) AS total_revenue
FROM exp_user_events_country_first
WHERE event_time >= (
    SELECT max(event_time) - INTERVAL 30 DAY
    FROM exp_user_events_country_first
)
GROUP BY day
ORDER BY day;

-- ============================================================
-- Scan statistics
-- This section reads the latest finished SELECT query for each log_comment
-- from system.query_log. It reports read_rows and read_bytes so the layouts
-- can be compared directly.
-- ============================================================

SET log_comment = '';
SYSTEM FLUSH LOGS;

SELECT 'Latest scan statistics from system.query_log' AS section;

SELECT
    log_comment AS query_label,
    argMax(query_duration_ms, event_time_microseconds) AS query_duration_ms,
    argMax(read_rows, event_time_microseconds) AS read_rows,
    argMax(read_bytes, event_time_microseconds) AS read_bytes,
    argMax(result_rows, event_time_microseconds) AS result_rows
FROM system.query_log
WHERE type = 'QueryFinish'
  AND is_initial_query = 1
  AND event_date >= today()
  AND lower(query_kind) = 'select'
  AND log_comment IN (
      'Q1_time_first_recent_revenue',
      'Q1_country_first_recent_revenue',
      'Q2_time_first_country_aggregation',
      'Q2_country_first_country_aggregation',
      'Q3_time_first_daily_trend',
      'Q3_country_first_daily_trend'
  )
GROUP BY log_comment
ORDER BY query_label;
