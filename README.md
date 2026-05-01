# DSCI 551 Final Project: ClickHouse Sorting-Key Alignment

This project studies how the ClickHouse `MergeTree` sorting key affects scan cost for analytical queries. The project uses two tables with identical synthetic event data but different physical sorting layouts:

- `exp_user_events_time_first`: sorted by `(event_time, country, user_id)`
- `exp_user_events_country_first`: sorted by `(country, event_time, user_id)`

The demo compares how these layouts behave for recent-window revenue, country aggregation, and daily trend queries.

## Repository Contents

- `README.md`: project setup, run, dataset, and reproduction instructions.
- `schema.sql`: creates the two ClickHouse `MergeTree` tables.
- `data.sql`: generates and loads the synthetic event dataset.
- `demo.sql`: runs representative analytical queries and prints scan statistics.
- `instructions.txt`: concise command-line setup instructions.
- `Final Report.docx`: final report.

## Database System

The project uses ClickHouse with the `MergeTree` storage engine. `MergeTree` stores data in sorted data parts and uses a sparse primary index over granules. This project focuses on how the `ORDER BY` sorting key affects data skipping and scan cost.

## Prerequisites

Install the following before running the project:

- Docker
- A terminal or command-line shell
- Internet access to pull the ClickHouse Docker image

No Python packages, external libraries, or external database drivers are required.

## Secret Keys and Credentials

No secret keys, API keys, credentials, tokens, or environment variables are required for this project.

## Dataset

The dataset is synthetic. It is generated automatically by `data.sql` using ClickHouse's `numbers()` table function and deterministic hashing.

The script creates 2,000,000 synthetic user-event records in `exp_user_events_time_first`, then copies the same records into `exp_user_events_country_first`. No external dataset download is required.

The generated data includes the following fields:

- `user_id`
- `event_type`
- `country`
- `device`
- `event_time`
- `revenue`

A fixed base timestamp is used so that the generated data is reproducible across runs.

## Setup and Run Instructions

From the repository root, start a ClickHouse Docker container:

```bash
docker run -d --name clickhouse \
  --ulimit nofile=262144:262144 \
  -p 8123:8123 -p 9000:9000 \
  clickhouse/clickhouse-server:latest
```

Wait a few seconds for the server to start. Then verify that ClickHouse is running:

```bash
docker exec clickhouse clickhouse-client --query "SELECT version();"
```

Create the database tables:

```bash
docker exec -i clickhouse clickhouse-client --multiquery < schema.sql
```

Generate and load the synthetic data:

```bash
docker exec -i clickhouse clickhouse-client --multiquery < data.sql
```

Run the demo queries:

```bash
docker exec -i clickhouse clickhouse-client --multiquery < demo.sql
```

## Reproducing the Results

The main comparison is between the same recent-window revenue query on the two table layouts:

- `Q1_time_first_recent_revenue`
- `Q1_country_first_recent_revenue`

Both layouts should return the same logical revenue result because they contain identical data. However, the `time_first` table is expected to read fewer rows and bytes for the recent time-window query because its leading sorting-key column is `event_time`.

`demo.sql` also runs:

- country aggregation queries over a recent time window
- daily trend queries over a recent time window
- a final query against `system.query_log` to display approximate scan statistics, including `read_rows` and `read_bytes`

Exact scan statistics may vary depending on ClickHouse version, cache state, hardware, and runtime environment. The expected qualitative result is that the time-aligned layout reduces scan volume for time-window analytical queries.

## Rerunning the Project

The scripts are designed to be rerunnable:

- `schema.sql` drops and recreates the two tables.
- `data.sql` truncates both tables before loading data.
- `demo.sql` can be run repeatedly after the data is loaded.

If you need to restart from a clean Docker container, run:

```bash
docker rm -f clickhouse
```

Then rerun the setup commands above.
