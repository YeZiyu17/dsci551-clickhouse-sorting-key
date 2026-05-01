-- DSCI 551 Final Project
-- Synthetic data generation for ClickHouse sorting-key comparison
-- This script is rerunnable after schema.sql has been executed.

TRUNCATE TABLE exp_user_events_time_first;
TRUNCATE TABLE exp_user_events_country_first;

-- Insert deterministic synthetic data into the time_first table.
-- The fixed base timestamp makes the generated dataset reproducible.
INSERT INTO exp_user_events_time_first
WITH
    number AS n,
    cityHash64(n) AS h,
    toDateTime('2026-04-15 00:00:00') AS base_time
SELECT
    toUInt32(h % 1000000) AS user_id,
    arrayElement(['view', 'click', 'purchase', 'signup'], toUInt8(h % 4) + 1) AS event_type,
    arrayElement(['US', 'CA', 'GB', 'DE'], toUInt8(intDiv(h, 4) % 4) + 1) AS country,
    arrayElement(['web', 'mobile', 'tablet'], toUInt8(intDiv(h, 16) % 3) + 1) AS device,
    base_time - toIntervalSecond(h % (180 * 24 * 3600)) AS event_time,
    if(h % 4 = 2, round(toFloat64(h % 10000) / 100.0, 2), 0.0) AS revenue
FROM numbers(2000000);

-- Copy the exact same logical dataset into the country_first table.
-- ClickHouse stores it using the second table's own ORDER BY layout.
INSERT INTO exp_user_events_country_first
SELECT *
FROM exp_user_events_time_first;

-- Basic validation: both tables should contain the same number of rows.
SELECT
    (SELECT count() FROM exp_user_events_time_first) AS time_first_count,
    (SELECT count() FROM exp_user_events_country_first) AS country_first_count;

-- Basic validation: confirm the generated event-time range.
SELECT
    min(event_time) AS min_event_time,
    max(event_time) AS max_event_time
FROM exp_user_events_time_first;
