-- DSCI 551 Final Project
-- ClickHouse MergeTree sorting-key comparison
-- This script is rerunnable: it drops and recreates the experiment tables.

DROP TABLE IF EXISTS exp_user_events_time_first;
DROP TABLE IF EXISTS exp_user_events_country_first;

-- Table 1: time_first
-- This layout is aligned with time-window analytical queries.
CREATE TABLE exp_user_events_time_first
(
    user_id    UInt32,
    event_type LowCardinality(String),
    country    LowCardinality(String),
    device     LowCardinality(String),
    event_time DateTime,
    revenue    Float64
)
ENGINE = MergeTree
PARTITION BY toYYYYMM(event_time)
ORDER BY (event_time, country, user_id)
SETTINGS index_granularity = 8192;

-- Table 2: country_first
-- This layout stores the same data but places country before event_time
-- in the sorting key, making it less aligned with pure time-window filters.
CREATE TABLE exp_user_events_country_first
(
    user_id    UInt32,
    event_type LowCardinality(String),
    country    LowCardinality(String),
    device     LowCardinality(String),
    event_time DateTime,
    revenue    Float64
)
ENGINE = MergeTree
PARTITION BY toYYYYMM(event_time)
ORDER BY (country, event_time, user_id)
SETTINGS index_granularity = 8192;
