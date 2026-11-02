/* =====================================================================
   CYCLISTIC — 03_marts.sql
   One set of small, aggregated tables per Tableau dashboard.
   Tableau never touches the multi-million-row fact table.
   Materialized views: re-run 03 (or REFRESH) after reloading data.
   ===================================================================== */
\set ON_ERROR_STOP on
SET search_path = cyclistic, public;

/* ================= DASHBOARD 1 — Executive Overview ================== */
DROP MATERIALIZED VIEW IF EXISTS cyclistic.mart_d1_monthly CASCADE;
CREATE MATERIALIZED VIEW cyclistic.mart_d1_monthly AS
SELECT
    start_month,
    rider_type,
    COUNT(*)                                                         AS rides,
    ROUND(AVG(ride_length_min), 1)                                   AS avg_ride_min,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY ride_length_min)::NUMERIC, 1) AS median_ride_min,
    ROUND(COUNT(*)::NUMERIC / SUM(COUNT(*)) OVER (PARTITION BY start_month), 4)     AS share_of_month
FROM cyclistic.fact_trips
GROUP BY start_month, rider_type;

/* ================= DASHBOARD 2 — How the two groups differ =========== */
DROP MATERIALIZED VIEW IF EXISTS cyclistic.mart_d2_hour_dow CASCADE;
CREATE MATERIALIZED VIEW cyclistic.mart_d2_hour_dow AS
SELECT rider_type, iso_dow, day_name, start_hour,
       COUNT(*)                                                       AS rides,
       ROUND(COUNT(*)::NUMERIC / COUNT(DISTINCT start_date), 2)       AS avg_rides_per_day,
       ROUND(AVG(ride_length_min), 1)                                 AS avg_ride_min
FROM cyclistic.fact_trips
GROUP BY rider_type, iso_dow, day_name, start_hour;

DROP MATERIALIZED VIEW IF EXISTS cyclistic.mart_d2_profile CASCADE;
CREATE MATERIALIZED VIEW cyclistic.mart_d2_profile AS
SELECT start_month, rider_type, bike_type, is_weekend, is_round_trip, duration_bucket,
       COUNT(*)                         AS rides,
       SUM(ride_length_min)             AS total_min,
       SUM(distance_km)                 AS total_km
FROM cyclistic.fact_trips
GROUP BY start_month, rider_type, bike_type, is_weekend, is_round_trip, duration_bucket;

/* ================= DASHBOARD 3 — Where to target ===================== */
DROP MATERIALIZED VIEW IF EXISTS cyclistic.mart_d3_stations CASCADE;
CREATE MATERIALIZED VIEW cyclistic.mart_d3_stations AS
WITH st AS (
    SELECT f.start_station_id                                         AS station_id,
           COUNT(*)                                                   AS rides,
           COUNT(*) FILTER (WHERE rider_type = 'casual')              AS casual_rides,
           COUNT(*) FILTER (WHERE rider_type = 'member')              AS member_rides,
           COUNT(*) FILTER (WHERE rider_type = 'casual' AND is_commute_pattern) AS casual_commute_rides
    FROM cyclistic.fact_trips f
    WHERE f.start_station_id IS NOT NULL
    GROUP BY f.start_station_id
),
overall AS (SELECT SUM(casual_rides)::NUMERIC / SUM(rides) AS casual_share FROM st),
scored AS (
    SELECT st.*,
           ROUND(casual_rides::NUMERIC / rides, 4)                    AS casual_share,
           NTILE(4) OVER (ORDER BY rides)                             AS volume_quartile,
           RANK()  OVER (ORDER BY casual_rides DESC)                  AS casual_volume_rank
    FROM st
)
SELECT c.station_name, c.lat, c.lng, c.zone_id, s.*,
       ROUND(o.casual_share, 4)                                       AS network_casual_share,
       CASE
         WHEN s.volume_quartile = 1                            THEN 'Low volume'
         WHEN s.casual_share >= o.casual_share + 0.10          THEN 'Casual hotspot'
         WHEN s.casual_share <= o.casual_share - 0.10          THEN 'Member stronghold'
         ELSE 'Up for grabs (high volume, mixed)'
       END                                                            AS segment
FROM scored s
JOIN cyclistic.v_station_current c USING (station_id)
CROSS JOIN overall o;

DROP MATERIALIZED VIEW IF EXISTS cyclistic.mart_d3_zones CASCADE;
CREATE MATERIALIZED VIEW cyclistic.mart_d3_zones AS
SELECT c.zone_id,
       ROUND(AVG(c.lat)::NUMERIC, 5)                                  AS zone_lat,
       ROUND(AVG(c.lng)::NUMERIC, 5)                                  AS zone_lng,
       COUNT(*)                                                       AS stations,
       SUM(s.rides)                                                   AS rides,
       SUM(s.casual_rides)                                            AS casual_rides,
       ROUND(SUM(s.casual_rides)::NUMERIC / SUM(s.rides), 4)          AS casual_share,
       SUM(s.casual_commute_rides)                                    AS casual_commute_rides,
       STRING_AGG(c.station_name, ' | ' ORDER BY s.rides DESC)        AS stations_in_zone
FROM cyclistic.mart_d3_stations s
JOIN cyclistic.v_station_current c USING (station_id)
GROUP BY c.zone_id;

-- Routes in "path" format: two rows per route (point_order 1 = start, 2 = end)
-- so Tableau can draw lines with Mark type = Line, Path = point_order.
DROP MATERIALIZED VIEW IF EXISTS cyclistic.mart_d3_routes CASCADE;
CREATE MATERIALIZED VIEW cyclistic.mart_d3_routes AS
WITH r AS (
    SELECT rider_type, start_station_id, end_station_id,
           COUNT(*)                         AS rides,
           ROUND(AVG(ride_length_min), 1)   AS avg_ride_min,
           RANK() OVER (PARTITION BY rider_type ORDER BY COUNT(*) DESC) AS route_rank
    FROM cyclistic.fact_trips
    WHERE start_station_id IS NOT NULL AND end_station_id IS NOT NULL
      AND start_station_id <> end_station_id
    GROUP BY rider_type, start_station_id, end_station_id
)
SELECT r.rider_type, r.route_rank, r.rides, r.avg_ride_min,
       s.station_name || ' -> ' || e.station_name AS route,
       p.point_order,
       CASE p.point_order WHEN 1 THEN s.lat ELSE e.lat END AS lat,
       CASE p.point_order WHEN 1 THEN s.lng ELSE e.lng END AS lng
FROM r
JOIN cyclistic.v_station_current s ON s.station_id = r.start_station_id
JOIN cyclistic.v_station_current e ON e.station_id = r.end_station_id
CROSS JOIN (VALUES (1), (2)) AS p(point_order)
WHERE r.route_rank <= 50;

/* ================= DASHBOARD 4 — Conversion opportunity ============== */
-- Casual rides split into behaviour segments, with revenue at assumed prices.
-- Tableau parameters (conversion %, fee, rides per rider) sit on top of this.
DROP MATERIALIZED VIEW IF EXISTS cyclistic.mart_d4_casual_segments CASCADE;
CREATE MATERIALIZED VIEW cyclistic.mart_d4_casual_segments AS
SELECT start_month, season, start_zone_id AS zone_id, bike_type,
       CASE WHEN is_commute_pattern THEN 'Commute pattern (member-like)'
            WHEN is_weekend         THEN 'Weekend leisure'
            ELSE 'Weekday other' END                                   AS casual_segment,
       COUNT(*)                                                        AS rides,
       ROUND(SUM(ride_length_min), 1)                                  AS total_min,
       ROUND(SUM(cyclistic.casual_fare(bike_type, ride_length_min)), 2) AS revenue_as_casual,
       ROUND(SUM(cyclistic.member_fare(bike_type, ride_length_min)), 2) AS usage_revenue_if_member
FROM cyclistic.fact_trips
WHERE rider_type = 'casual'
GROUP BY 1, 2, 3, 4, 5;

/* ================= DASHBOARD 5 — Timing & forecast =================== */
DROP MATERIALIZED VIEW IF EXISTS cyclistic.mart_d5_daily CASCADE;
CREATE MATERIALIZED VIEW cyclistic.mart_d5_daily AS
WITH d AS (
    SELECT start_date,
           COUNT(*)                                          AS rides,
           COUNT(*) FILTER (WHERE rider_type = 'casual')     AS casual_rides,
           COUNT(*) FILTER (WHERE rider_type = 'member')     AS member_rides
    FROM cyclistic.fact_trips GROUP BY start_date
)
SELECT d.*,
       ROUND(casual_rides::NUMERIC / rides, 4)                                     AS casual_share,
       ROUND(AVG(rides) OVER (ORDER BY start_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW), 1) AS rides_7d_avg
FROM d;

/* ================= DASHBOARD 6 — Measurement design ================== */
DROP MATERIALIZED VIEW IF EXISTS cyclistic.mart_d6_zone_daily CASCADE;
CREATE MATERIALIZED VIEW cyclistic.mart_d6_zone_daily AS
SELECT start_date, start_zone_id AS zone_id,
       COUNT(*)                                          AS rides,
       COUNT(*) FILTER (WHERE rider_type = 'casual')     AS casual_rides
FROM cyclistic.fact_trips
WHERE start_zone_id IS NOT NULL
GROUP BY start_date, start_zone_id;

/* ================= DASHBOARD 7 — Operations ========================== */
-- Net flow per station and hour: arrivals minus departures.
-- Negative = station drains (needs bikes delivered), positive = fills up.
DROP MATERIALIZED VIEW IF EXISTS cyclistic.mart_d7_station_flow CASCADE;
CREATE MATERIALIZED VIEW cyclistic.mart_d7_station_flow AS
WITH moves AS (
    SELECT start_station_id AS station_id, start_hour AS hour, is_weekend, -1 AS dir, start_date AS d
    FROM cyclistic.fact_trips WHERE start_station_id IS NOT NULL
    UNION ALL
    SELECT end_station_id, EXTRACT(HOUR FROM ended_at)::INT, EXTRACT(ISODOW FROM ended_at) >= 6, 1, ended_at::DATE
    FROM cyclistic.fact_trips WHERE end_station_id IS NOT NULL
),
days AS (   -- number of weekdays / weekend days in the data, to express flows per day
    SELECT EXTRACT(ISODOW FROM g) >= 6 AS is_weekend, COUNT(*) AS n_days
    FROM generate_series((SELECT MIN(start_date) FROM cyclistic.fact_trips),
                         (SELECT MAX(start_date) FROM cyclistic.fact_trips), INTERVAL '1 day') g
    GROUP BY 1
)
SELECT c.station_name, c.lat, c.lng, c.zone_id, m.station_id,
       CASE WHEN m.is_weekend THEN 'Weekend' ELSE 'Weekday' END       AS day_type,
       m.hour,
       COUNT(*) FILTER (WHERE dir = -1)                               AS departures,
       COUNT(*) FILTER (WHERE dir =  1)                               AS arrivals,
       SUM(dir)                                                       AS net_flow,
       ROUND(SUM(dir)::NUMERIC / MAX(dy.n_days), 2)                   AS net_flow_per_day
FROM moves m
JOIN days dy USING (is_weekend)
JOIN cyclistic.v_station_current c USING (station_id)
GROUP BY c.station_name, c.lat, c.lng, c.zone_id, m.station_id, m.is_weekend, m.hour;

/* ================= DASHBOARD 8 — Data quality & trust ================ */
DROP MATERIALIZED VIEW IF EXISTS cyclistic.mart_d8_dq_funnel CASCADE;
CREATE MATERIALIZED VIEW cyclistic.mart_d8_dq_funnel AS
SELECT outcome,
       SUM(rows)                                                      AS rows,
       ROUND(SUM(rows)::NUMERIC / SUM(SUM(rows)) OVER (), 4)          AS share_of_raw,
       SUM(rows_missing_end_station)                                  AS rows_missing_end_station
FROM cyclistic.data_quality_log
GROUP BY outcome;

DROP MATERIALIZED VIEW IF EXISTS cyclistic.mart_d8_speed CASCADE;
CREATE MATERIALIZED VIEW cyclistic.mart_d8_speed AS
SELECT bike_type,
       LEAST(FLOOR(speed_kmh / 2) * 2, 80)                            AS speed_bucket_kmh,   -- 2 km/h bins, 80+ capped
       COUNT(*)                                                       AS trips,
       BOOL_OR(dq_issue = 'impossible_speed')                         AS includes_flagged
FROM cyclistic.stg_trips
WHERE speed_kmh IS NOT NULL AND distance_km >= cyclistic.a('min_km_for_speed_check')
  AND (dq_issue IS NULL OR dq_issue = 'impossible_speed')
GROUP BY 1, 2;

SELECT 'marts built' AS status, COUNT(*) AS materialized_views
FROM pg_matviews WHERE schemaname = 'cyclistic';
