/* =====================================================================
   CYCLISTIC — 02_pipeline.sql
   raw_trips → stg_trips → data_quality_log → dim_stations (SCD2) → fact_trips

   stg_trips        typed + derived columns + one dq_issue label per row
   data_quality_log rows kept / removed per rule per file   (Dashboard 8)
   dim_stations     one row per station VERSION (rename / relocation)  (Q21)
   fact_trips       clean trips joined to the station version valid that day
   ===================================================================== */
\set ON_ERROR_STOP on
SET search_path = cyclistic, public;

/* ---------------------------------------------------------------------
   1. STAGING: cast types, derive analysis columns, label quality issues
   --------------------------------------------------------------------- */
DROP TABLE IF EXISTS cyclistic.stg_trips CASCADE;

CREATE TABLE cyclistic.stg_trips AS
WITH typed AS (
    SELECT
        NULLIF(TRIM(ride_id), '')                    AS ride_id,
        NULLIF(TRIM(rideable_type), '')              AS bike_type,
        NULLIF(TRIM(started_at), '')::TIMESTAMP      AS started_at,
        NULLIF(TRIM(ended_at), '')::TIMESTAMP        AS ended_at,
        NULLIF(TRIM(start_station_name), '')         AS start_station_name,
        NULLIF(TRIM(start_station_id), '')           AS start_station_id,
        NULLIF(TRIM(end_station_name), '')           AS end_station_name,
        NULLIF(TRIM(end_station_id), '')             AS end_station_id,
        NULLIF(TRIM(start_lat), '')::FLOAT8          AS start_lat,
        NULLIF(TRIM(start_lng), '')::FLOAT8          AS start_lng,
        NULLIF(TRIM(end_lat), '')::FLOAT8            AS end_lat,
        NULLIF(TRIM(end_lng), '')::FLOAT8            AS end_lng,
        LOWER(NULLIF(TRIM(member_casual), ''))       AS rider_type,
        source_file
    FROM cyclistic.raw_trips
),
derived AS (
    SELECT
        t.*,
        EXTRACT(EPOCH FROM (ended_at - started_at)) / 60.0          AS ride_length_min,
        started_at::DATE                                            AS start_date,
        DATE_TRUNC('month', started_at)::DATE                       AS start_month,
        EXTRACT(HOUR FROM started_at)::INT                          AS start_hour,
        EXTRACT(ISODOW FROM started_at)::INT                        AS iso_dow,      -- 1 = Mon … 7 = Sun
        TO_CHAR(started_at, 'Dy')                                   AS day_name,
        EXTRACT(ISODOW FROM started_at) >= 6                        AS is_weekend,
        COALESCE(start_station_id = end_station_id, FALSE)          AS is_round_trip,
        cyclistic.haversine_km(start_lat, start_lng, end_lat, end_lng) AS distance_km,
        ROW_NUMBER() OVER (PARTITION BY ride_id ORDER BY source_file) AS ride_id_seq
    FROM typed t
)
SELECT
    d.*,
    CASE WHEN ride_length_min > 0 THEN distance_km / (ride_length_min / 60.0) END AS speed_kmh,
    CASE
        WHEN ride_id_seq > 1                                         THEN 'duplicate_ride_id'
        WHEN ride_id IS NULL OR started_at IS NULL OR ended_at IS NULL
          OR rider_type NOT IN ('member', 'casual') OR rider_type IS NULL THEN 'missing_core_field'
        WHEN ride_length_min <= 0                                    THEN 'non_positive_duration'
        WHEN ride_length_min < 1                                     THEN 'under_1_min'
        WHEN ride_length_min > 1440                                  THEN 'over_24_hours'
        WHEN distance_km >= cyclistic.a('min_km_for_speed_check')
         AND distance_km / (ride_length_min / 60.0) > cyclistic.a('max_plausible_speed_kmh')
                                                                     THEN 'impossible_speed'
    END                                       AS dq_issue,            -- NULL = clean
    start_station_id IS NULL                  AS no_start_station,    -- kept: dockless e-bike rides are real rides
    end_station_id   IS NULL                  AS no_end_station       -- kept, but tracked (lost/stolen candidates)
FROM derived d;

CREATE INDEX ON cyclistic.stg_trips (dq_issue);

/* ---------------------------------------------------------------------
   2. DATA QUALITY LOG — the audit trail (Dashboard 8, Q18)
   --------------------------------------------------------------------- */
DROP TABLE IF EXISTS cyclistic.data_quality_log;

CREATE TABLE cyclistic.data_quality_log AS
SELECT
    source_file,
    COALESCE(dq_issue, 'kept')                      AS outcome,
    COUNT(*)                                        AS rows,
    COUNT(*) FILTER (WHERE no_start_station)        AS rows_missing_start_station,
    COUNT(*) FILTER (WHERE no_end_station)          AS rows_missing_end_station,
    now()                                           AS logged_at
FROM cyclistic.stg_trips
GROUP BY source_file, COALESCE(dq_issue, 'kept');

/* ---------------------------------------------------------------------
   3. DIM_STATIONS — Slowly Changing Dimension, Type 2  (Q21)
   A station gets a new version when its name changes or it moves more
   than station_move_threshold_km. Observed weekly (weekly medians smooth
   GPS noise). Location uses classic-bike coordinates where possible,
   because e-bike coordinates are often rounded.
   --------------------------------------------------------------------- */
DROP TABLE IF EXISTS cyclistic.dim_stations CASCADE;

CREATE TABLE cyclistic.dim_stations AS
WITH sightings AS (
    SELECT start_station_id AS station_id, DATE_TRUNC('week', started_at)::DATE AS obs_week,
           start_station_name AS station_name, start_lat AS lat, start_lng AS lng, bike_type
    FROM cyclistic.stg_trips WHERE dq_issue IS NULL AND start_station_id IS NOT NULL
    UNION ALL
    SELECT end_station_id, DATE_TRUNC('week', ended_at)::DATE,
           end_station_name, end_lat, end_lng, bike_type
    FROM cyclistic.stg_trips WHERE dq_issue IS NULL AND end_station_id IS NOT NULL
),
weekly AS (                              -- what did each station look like each week?
    SELECT station_id, obs_week,
           MODE() WITHIN GROUP (ORDER BY station_name) AS station_name,
           COALESCE(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY lat) FILTER (WHERE bike_type <> 'electric_bike'),
                    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY lat)) AS lat,
           COALESCE(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY lng) FILTER (WHERE bike_type <> 'electric_bike'),
                    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY lng)) AS lng
    FROM sightings
    GROUP BY station_id, obs_week
),
flagged AS (                             -- did anything change since last week?
    SELECT w.*,
           CASE WHEN LAG(station_name) OVER s IS NULL THEN 1
                WHEN station_name <> LAG(station_name) OVER s THEN 1
                WHEN cyclistic.haversine_km(lat, lng, LAG(lat) OVER s, LAG(lng) OVER s)
                     > cyclistic.a('station_move_threshold_km') THEN 1
                ELSE 0 END AS is_change
    FROM weekly w
    WINDOW s AS (PARTITION BY station_id ORDER BY obs_week)
),
versioned AS (
    SELECT f.*, SUM(is_change) OVER (PARTITION BY station_id ORDER BY obs_week) AS version_no
    FROM flagged f
),
versions AS (
    SELECT station_id, version_no,
           MIN(station_name)                                       AS station_name,
           PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY lat)        AS lat,
           PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY lng)        AS lng,
           MIN(obs_week)                                           AS valid_from,
           COUNT(*)                                                AS weeks_observed
    FROM versioned
    GROUP BY station_id, version_no
)
SELECT
    ROW_NUMBER() OVER (ORDER BY station_id, version_no)::INT                     AS station_key,
    station_id,
    version_no::INT                                                              AS version_no,
    station_name,
    lat, lng,
    cyclistic.zone_id(lat, lng)                                                  AS zone_id,
    valid_from,
    COALESCE(LEAD(valid_from) OVER (PARTITION BY station_id ORDER BY version_no) - 1,
             DATE '9999-12-31')                                                  AS valid_to,
    LEAD(valid_from) OVER (PARTITION BY station_id ORDER BY version_no) IS NULL  AS is_current,
    weeks_observed
FROM versions;

ALTER TABLE cyclistic.dim_stations ADD PRIMARY KEY (station_key);
CREATE INDEX ON cyclistic.dim_stations (station_id, valid_from, valid_to);

-- Current view of each station (latest name/location) — used for maps and rollups.
CREATE VIEW cyclistic.v_station_current AS
SELECT station_id, station_name, lat, lng, zone_id
FROM cyclistic.dim_stations WHERE is_current;

/* ---------------------------------------------------------------------
   4. FACT_TRIPS — clean trips, each joined to the station version valid
   on the trip date. Analysis rolls up by station_id (stable across
   renames) and displays the current name.
   --------------------------------------------------------------------- */
DROP TABLE IF EXISTS cyclistic.fact_trips CASCADE;

CREATE TABLE cyclistic.fact_trips AS
SELECT
    s.ride_id,
    s.rider_type,
    s.bike_type,
    s.started_at,
    s.ended_at,
    s.start_date,
    s.start_month,
    s.start_hour,
    s.iso_dow,
    s.day_name,
    s.is_weekend,
    CASE WHEN EXTRACT(MONTH FROM s.started_at) IN (12, 1, 2) THEN 'Winter'
         WHEN EXTRACT(MONTH FROM s.started_at) IN (3, 4, 5)  THEN 'Spring'
         WHEN EXTRACT(MONTH FROM s.started_at) IN (6, 7, 8)  THEN 'Summer'
         ELSE 'Autumn' END                                    AS season,
    ROUND(s.ride_length_min::NUMERIC, 2)                      AS ride_length_min,
    ROUND(s.distance_km::NUMERIC, 3)                          AS distance_km,
    s.is_round_trip,
    CASE WHEN s.ride_length_min < 15 THEN '0-15 min'
         WHEN s.ride_length_min < 30 THEN '15-30 min'
         WHEN s.ride_length_min < 60 THEN '30-60 min'
         ELSE '60+ min' END                                   AS duration_bucket,
    -- "Commute pattern": weekday, 7-9am or 4-6pm start, one-way, 30 min or less (Q2)
    (NOT s.is_weekend AND s.start_hour IN (7, 8, 16, 17)
         AND NOT s.is_round_trip AND s.ride_length_min <= 30) AS is_commute_pattern,
    s.start_station_id,
    ds.station_key                                            AS start_station_key,
    ds.zone_id                                                AS start_zone_id,
    s.end_station_id,
    de.station_key                                            AS end_station_key,
    de.zone_id                                                AS end_zone_id,
    s.no_end_station
FROM cyclistic.stg_trips s
LEFT JOIN cyclistic.dim_stations ds
       ON ds.station_id = s.start_station_id
      AND s.started_at::DATE BETWEEN ds.valid_from AND ds.valid_to
LEFT JOIN cyclistic.dim_stations de
       ON de.station_id = s.end_station_id
      AND s.ended_at::DATE BETWEEN de.valid_from AND de.valid_to
WHERE s.dq_issue IS NULL;

ALTER TABLE cyclistic.fact_trips ADD PRIMARY KEY (ride_id);
CREATE INDEX ON cyclistic.fact_trips (start_date);
CREATE INDEX ON cyclistic.fact_trips (start_station_id);
CREATE INDEX ON cyclistic.fact_trips (start_zone_id);
ANALYZE cyclistic.fact_trips;

/* Analysis windows, driven by the data itself: the latest 12 months
   ("current") and the 12 months before them ("prior"). */
CREATE VIEW cyclistic.v_periods AS
SELECT MAX(start_month)                                  AS last_month,
       (MAX(start_month) - INTERVAL '11 months')::DATE   AS current_start,
       (MAX(start_month) - INTERVAL '23 months')::DATE   AS prior_start
FROM cyclistic.fact_trips;

/* Pipeline check: every raw row is accounted for. */
SELECT (SELECT COUNT(*) FROM cyclistic.raw_trips)                      AS raw_rows,
       (SELECT COUNT(*) FROM cyclistic.stg_trips WHERE dq_issue IS NOT NULL) AS removed_rows,
       (SELECT COUNT(*) FROM cyclistic.fact_trips)                     AS clean_rows,
       (SELECT COUNT(*) FROM cyclistic.dim_stations)                   AS station_versions,
       (SELECT COUNT(DISTINCT station_id) FROM cyclistic.dim_stations) AS stations;
