/* =====================================================================
   CYCLISTIC — 04_answers.sql
   The 21 business questions, each answered with one (or two) queries.
   "Current" = latest 12 months in the data, "prior" = the 12 before.
   Money figures use cyclistic.assumptions — UPDATE that table, re-run.
   ===================================================================== */
SET search_path = cyclistic, public;


/* =====================================================================
   A. MARKETING TARGETING — WHO AND WHERE            (Dashboard 3)
   ===================================================================== */

-- Q1. "Where should we spend our marketing budget? Show me the stations with the most casual riders."
SELECT casual_volume_rank AS rank, station_name, zone_id,
       rides, casual_rides, casual_share, segment
FROM cyclistic.mart_d3_stations
ORDER BY casual_rides DESC
LIMIT 20;


-- Q2. "Which casual riders are basically members who haven't signed up yet?"
--     Commute pattern = weekday, 7-9am or 4-6pm start, one-way, 30 min or less.
--     Members are shown as the benchmark: how "commute-like" are real members?
SELECT rider_type,
       COUNT(*)                                                    AS rides,
       COUNT(*) FILTER (WHERE is_commute_pattern)                  AS commute_pattern_rides,
       ROUND(AVG(is_commute_pattern::INT), 4)                      AS commute_pattern_share
FROM cyclistic.fact_trips f, cyclistic.v_periods p
WHERE f.start_month >= p.current_start
GROUP BY rider_type;

--     Q2b. Where the conversion pool starts its trips (map layer)
SELECT s.station_name, s.zone_id, s.casual_commute_rides,
       ROUND(s.casual_commute_rides::NUMERIC / SUM(s.casual_commute_rides) OVER (), 4) AS share_of_pool
FROM cyclistic.mart_d3_stations s
ORDER BY s.casual_commute_rides DESC
LIMIT 15;


-- Q3. "What are the top routes casual riders take? I want billboards and partnerships on them."
SELECT route_rank, route, rides, avg_ride_min
FROM cyclistic.mart_d3_routes
WHERE rider_type = 'casual' AND point_order = 1
ORDER BY route_rank
LIMIT 15;


-- Q4. "Which stations are member strongholds, casual hotspots, or up for grabs?"
SELECT segment,
       COUNT(*)                                        AS stations,
       SUM(rides)                                      AS rides,
       ROUND(SUM(casual_rides)::NUMERIC / SUM(rides), 4) AS casual_share
FROM cyclistic.mart_d3_stations
GROUP BY segment
ORDER BY rides DESC;


-- Q5. "Forget individual stations. Which geographic zones should we buy ads in?"
--     ~1.1 km grid cells. Ranked by casual volume, with the member-like pool alongside.
SELECT RANK() OVER (ORDER BY casual_rides DESC)  AS rank,
       zone_id, zone_lat, zone_lng, stations,
       rides, casual_rides, casual_share, casual_commute_rides,
       LEFT(stations_in_zone, 120)               AS main_stations
FROM cyclistic.mart_d3_zones
ORDER BY casual_rides DESC
LIMIT 10;


/* =====================================================================
   B. TIMING AND FORECASTING — WHEN TO ACT            (Dashboard 5, 2, 1)
   ===================================================================== */

-- Q6. "When exactly should we launch the membership campaign?"
--     Average casual rides per calendar month across the years loaded, and how
--     sharply each month ramps up. Launch just before the steepest ramp.
WITH m AS (
    SELECT EXTRACT(MONTH FROM start_month)::INT AS month_no, AVG(rides) AS avg_casual_rides
    FROM cyclistic.mart_d1_monthly
    WHERE rider_type = 'casual'
    GROUP BY 1
),
g AS (
    SELECT m.*,
           avg_casual_rides / SUM(avg_casual_rides) OVER ()                         AS share_of_year,
           avg_casual_rides / LAG(avg_casual_rides) OVER (ORDER BY month_no) - 1    AS growth_vs_prev_month
    FROM m
)
SELECT month_no,
       TO_CHAR(MAKE_DATE(2000, month_no, 1), 'Mon')          AS month,
       ROUND(avg_casual_rides)                               AS avg_casual_rides,
       ROUND(share_of_year, 4)                               AS share_of_year,
       ROUND(growth_vs_prev_month, 3)                        AS growth_vs_prev_month,
       RANK() OVER (ORDER BY growth_vs_prev_month DESC NULLS LAST)
           AS ramp_rank   -- 1 = steepest month-on-month ramp: launch ~4 weeks before it
FROM g
ORDER BY month_no;


-- Q7. "Show me the hour-by-day pattern for each rider type."
--     Full grid for the heatmap lives in mart_d2_hour_dow; this is the peak summary.
WITH h AS (
    SELECT rider_type,
           CASE WHEN iso_dow >= 6 THEN 'Weekend' ELSE 'Weekday' END AS day_type,
           start_hour, SUM(rides) AS rides
    FROM cyclistic.mart_d2_hour_dow
    GROUP BY 1, 2, 3
)
SELECT rider_type, day_type, start_hour, rides,
       ROUND(rides::NUMERIC / SUM(rides) OVER (PARTITION BY rider_type, day_type), 4) AS share_of_day_type,
       peak_rank
FROM (SELECT h.*, RANK() OVER (PARTITION BY rider_type, day_type ORDER BY rides DESC) AS peak_rank FROM h) x
WHERE peak_rank <= 3
ORDER BY rider_type, day_type, peak_rank;


-- Q8. "Is our casual share growing or shrinking?"
--     Monthly share, 3-month rolling average, and the same month last year.
WITH s AS (
    SELECT start_month, share_of_month AS casual_share
    FROM cyclistic.mart_d1_monthly WHERE rider_type = 'casual'
)
SELECT start_month, casual_share,
       ROUND(AVG(casual_share) OVER (ORDER BY start_month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 4) AS rolling_3m,
       LAG(casual_share, 12) OVER (ORDER BY start_month)                                            AS same_month_last_year,
       ROUND(casual_share - LAG(casual_share, 12) OVER (ORDER BY start_month), 4)                   AS yoy_change_pts
FROM s
ORDER BY start_month;


-- Q9. "What's our casual ridership forecast for next season, and how much should we trust it?"
--     Seasonal-naive forecast: same month last year x overall year-on-year growth.
--     Low/high band uses the weakest and strongest monthly YoY ratio observed.
--     With 2 years of data each season has been seen only twice: treat as directional.
WITH m AS (
    SELECT start_month, rides FROM cyclistic.mart_d1_monthly WHERE rider_type = 'casual'
),
yoy AS (
    SELECT cur.start_month, cur.rides::NUMERIC / prev.rides AS ratio, cur.rides AS cur_rides, prev.rides AS prev_rides
    FROM m cur JOIN m prev ON prev.start_month = cur.start_month - INTERVAL '12 months'
),
g AS (
    SELECT SUM(cur_rides) / SUM(prev_rides) AS growth, MIN(ratio) AS low_ratio,
           MAX(ratio) AS high_ratio, COUNT(*) AS months_compared
    FROM yoy
)
SELECT (m.start_month + INTERVAL '12 months')::DATE AS forecast_month,
       m.rides                                      AS same_month_last_year,
       ROUND(m.rides * g.growth)                    AS forecast_casual_rides,
       ROUND(m.rides * g.low_ratio)                 AS low,
       ROUND(m.rides * g.high_ratio)                AS high,
       ROUND(g.growth - 1, 3)                       AS yoy_growth_used,
       g.months_compared
FROM m, g, cyclistic.v_periods p
WHERE m.start_month BETWEEN (p.last_month - INTERVAL '11 months') AND (p.last_month - INTERVAL '6 months')
ORDER BY forecast_month;


/* =====================================================================
   C. REVENUE AND PRICING                              (Dashboard 4)
   ===================================================================== */

-- Q10. "If we converted some of those riders, how much money are we talking?"
--      Naive view = new membership fees. Honest view = fees + members' usage charges
--      MINUS the casual fares those riders stop paying. Rider counts are estimated:
--      pool rides / assumed rides per rider (no rider ID in the data).
WITH pool AS (
    SELECT SUM(rides)                    AS pool_rides,
           SUM(revenue_as_casual)        AS casual_revenue,
           SUM(usage_revenue_if_member)  AS member_usage_revenue
    FROM cyclistic.mart_d4_casual_segments s, cyclistic.v_periods p
    WHERE s.casual_segment = 'Commute pattern (member-like)' AND s.start_month >= p.current_start
),
riders AS (SELECT pool.*, pool_rides / cyclistic.a('rides_per_casual_rider') AS est_riders FROM pool)
SELECT conversion_rate,
       ROUND(est_riders * conversion_rate)                                    AS new_members,
       ROUND(est_riders * conversion_rate * cyclistic.a('member_annual_fee')) AS naive_revenue_fees_only,
       ROUND(est_riders * conversion_rate * cyclistic.a('member_annual_fee')
             + conversion_rate * (member_usage_revenue - casual_revenue))     AS net_revenue_change
FROM riders, (VALUES (0.05), (0.10), (0.20)) AS c(conversion_rate)
ORDER BY conversion_rate;


-- Q11. "Does converting them actually make us money, or do we cannibalise riders who pay more as casual?"
--      Revenue per rider per year: as casual vs as member, by how often they ride.
--      Break-even: above this many rides a year, converting LOSES us money.
WITH per_ride AS (
    SELECT SUM(revenue_as_casual) / SUM(rides)       AS casual_rev_per_ride,
           SUM(usage_revenue_if_member) / SUM(rides) AS member_usage_per_ride
    FROM cyclistic.mart_d4_casual_segments s, cyclistic.v_periods p
    WHERE s.casual_segment = 'Commute pattern (member-like)' AND s.start_month >= p.current_start
)
SELECT n AS rides_per_year,
       ROUND(n * casual_rev_per_ride, 2)                                        AS revenue_as_casual,
       ROUND(cyclistic.a('member_annual_fee') + n * member_usage_per_ride, 2)   AS revenue_as_member,
       ROUND(cyclistic.a('member_annual_fee') + n * member_usage_per_ride - n * casual_rev_per_ride, 2) AS gain_from_converting,
       CASE WHEN cyclistic.a('member_annual_fee') + n * member_usage_per_ride >= n * casual_rev_per_ride
            THEN 'Profitable to convert' ELSE 'Cannibalising' END              AS verdict,
       ROUND(cyclistic.a('member_annual_fee') / (casual_rev_per_ride - member_usage_per_ride), 1) AS break_even_rides
FROM per_ride, (VALUES (5), (10), (20), (30), (50), (75), (100), (150)) AS v(n)
ORDER BY n;


-- Q12. "Casual riders take long rides. Are we pricing that properly?"
SELECT rider_type, duration_bucket,
       COUNT(*)                                                                   AS rides,
       ROUND(COUNT(*)::NUMERIC / SUM(COUNT(*)) OVER (PARTITION BY rider_type), 4) AS share_of_rides,
       ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY ride_length_min)::NUMERIC, 1) AS median_min,
       ROUND(AVG(cyclistic.casual_fare(bike_type, ride_length_min)), 2)           AS avg_fare_at_casual_price,
       ROUND(SUM(cyclistic.casual_fare(bike_type, ride_length_min))
             / SUM(SUM(cyclistic.casual_fare(bike_type, ride_length_min))) OVER (PARTITION BY rider_type), 4)
                                                                                  AS share_of_casual_price_revenue
FROM cyclistic.fact_trips f, cyclistic.v_periods p
WHERE f.start_month >= p.current_start
GROUP BY rider_type, duration_bucket
ORDER BY rider_type, duration_bucket;


-- Q13. "Is there demand for a weekend-only or summer membership?"
SELECT season,
       SUM(rides) FILTER (WHERE casual_segment = 'Weekend leisure')            AS weekend_casual_rides,
       SUM(rides) FILTER (WHERE casual_segment <> 'Weekend leisure')           AS weekday_casual_rides,
       ROUND(SUM(rides) FILTER (WHERE casual_segment = 'Weekend leisure')::NUMERIC / SUM(rides), 4) AS weekend_share,
       ROUND(SUM(rides)::NUMERIC / SUM(SUM(rides)) OVER (), 4)                 AS share_of_annual_casual,
       ROUND(SUM(revenue_as_casual))                                           AS casual_revenue
FROM cyclistic.mart_d4_casual_segments s, cyclistic.v_periods p
WHERE s.start_month >= p.current_start
GROUP BY season
ORDER BY share_of_annual_casual DESC;


-- Q14. "Who's using e-bikes, and should e-bike pricing differ by rider type?"
SELECT rider_type, bike_type,
       COUNT(*)                                                                   AS rides,
       ROUND(COUNT(*)::NUMERIC / SUM(COUNT(*)) OVER (PARTITION BY rider_type), 4) AS share_of_rider_type,
       ROUND(AVG(ride_length_min), 1)                                             AS avg_min,
       ROUND(AVG(distance_km) FILTER (WHERE NOT is_round_trip), 2)                AS avg_km_one_way,
       ROUND(AVG(CASE WHEN rider_type = 'casual' THEN cyclistic.casual_fare(bike_type, ride_length_min)
                      ELSE cyclistic.member_fare(bike_type, ride_length_min) END), 2) AS avg_revenue_per_ride
FROM cyclistic.fact_trips f, cyclistic.v_periods p
WHERE f.start_month >= p.current_start
GROUP BY rider_type, bike_type
ORDER BY rider_type, bike_type;


/* =====================================================================
   D. MEASUREMENT — PROVING IT WORKED                  (Dashboard 6)
   ===================================================================== */

-- Q15. "How would we know the campaign worked, and not just weather or seasonality?"
--      Design: treatment zones = top casual zones. Each gets a matched control zone
--      whose daily casual share moved most like it over the last 12 months.
--      Result is read as difference-in-differences:
--      (treatment post - treatment pre) - (control post - control pre).
DROP TABLE IF EXISTS cyclistic.campaign_design;
CREATE TABLE cyclistic.campaign_design AS
WITH p AS (SELECT * FROM cyclistic.v_periods),
zd AS (
    SELECT z.start_date, z.zone_id, z.casual_rides::NUMERIC / z.rides AS casual_share
    FROM cyclistic.mart_d6_zone_daily z, p WHERE z.start_date >= p.current_start
),
eligible AS (            -- zones active on at least 80% of days
    SELECT zone_id FROM zd GROUP BY zone_id
    HAVING COUNT(*) >= 0.8 * (SELECT COUNT(DISTINCT start_date) FROM zd)
),
treat AS (
    SELECT z.zone_id FROM cyclistic.mart_d3_zones z JOIN eligible USING (zone_id)
    ORDER BY z.casual_rides DESC LIMIT (SELECT cyclistic.a('treatment_zones')::INT)
),
pairs AS (
    SELECT t.zone_id AS treatment_zone, c.zone_id AS control_zone,
           CORR(a.casual_share, b.casual_share)        AS pre_period_correlation,
           STDDEV_SAMP(a.casual_share - b.casual_share) AS sd_daily_gap,
           COUNT(*)                                     AS days_compared
    FROM treat t
    JOIN eligible c ON c.zone_id NOT IN (SELECT zone_id FROM treat)
    JOIN zd a ON a.zone_id = t.zone_id
    JOIN zd b ON b.zone_id = c.zone_id AND b.start_date = a.start_date
    GROUP BY t.zone_id, c.zone_id
)
SELECT treatment_zone, control_zone,
       ROUND(pre_period_correlation::NUMERIC, 3) AS pre_period_correlation,
       days_compared,
       -- Minimum detectable effect (80% power, 5% significance), in percentage points of casual share.
       -- Ignores day-to-day autocorrelation, so treat as optimistic.
       ROUND((100 * 2.8 * sd_daily_gap * SQRT(1.0 / days_compared + 1.0 / cyclistic.a('campaign_days')))::NUMERIC, 2)
           AS min_detectable_effect_pts
FROM (SELECT pairs.*, ROW_NUMBER() OVER (PARTITION BY treatment_zone ORDER BY pre_period_correlation DESC) AS rn
      FROM pairs) x
WHERE rn = 1;

SELECT * FROM cyclistic.campaign_design;

--      Q15b. Placebo test: run the DiD at a fake launch date (no campaign happened).
--      A sound design shows an effect near zero. After the real campaign, swap in the
--      real launch date for fake_launch and this same query is the readout.
WITH launch AS (
    SELECT (p.last_month - INTERVAL '3 months')::DATE AS fake_launch,
           cyclistic.a('campaign_days')::INT          AS days
    FROM cyclistic.v_periods p
),
periods AS (
    SELECT d.zone_id, d.start_date,
           d.casual_rides, d.rides,
           CASE WHEN d.start_date >= l.fake_launch THEN 'post' ELSE 'pre' END AS phase
    FROM cyclistic.mart_d6_zone_daily d, launch l
    WHERE d.start_date >= l.fake_launch - l.days AND d.start_date < l.fake_launch + l.days
),
share AS (
    SELECT zone_id, phase, SUM(casual_rides)::NUMERIC / SUM(rides) AS casual_share
    FROM periods GROUP BY zone_id, phase
)
SELECT cd.treatment_zone, cd.control_zone,
       ROUND(100 * ((tp.casual_share - tr.casual_share) - (cp.casual_share - cr.casual_share)), 2) AS did_effect_pts,
       cd.min_detectable_effect_pts,
       CASE WHEN ABS(100 * ((tp.casual_share - tr.casual_share) - (cp.casual_share - cr.casual_share)))
                 < cd.min_detectable_effect_pts THEN 'Within noise (placebo passes)'
            ELSE 'Exceeds noise: check pairing' END AS placebo_check
FROM cyclistic.campaign_design cd
JOIN share tp ON tp.zone_id = cd.treatment_zone AND tp.phase = 'post'
JOIN share tr ON tr.zone_id = cd.treatment_zone AND tr.phase = 'pre'
JOIN share cp ON cp.zone_id = cd.control_zone   AND cp.phase = 'post'
JOIN share cr ON cr.zone_id = cd.control_zone   AND cr.phase = 'pre';


/* =====================================================================
   E. OPERATIONS — COST SAVINGS                        (Dashboard 7)
   ===================================================================== */

-- Q16. "Which stations are always empty or overflowing, and when?"
--      Weekday net flow per day. Negative = drains (deliver bikes), positive = fills (collect).
WITH st AS (
    SELECT station_name, zone_id,
           SUM(net_flow_per_day)                                         AS net_bikes_per_weekday,
           (ARRAY_AGG(hour ORDER BY net_flow_per_day ASC))[1]            AS worst_drain_hour,
           (ARRAY_AGG(hour ORDER BY net_flow_per_day DESC))[1]           AS worst_fill_hour
    FROM cyclistic.mart_d7_station_flow
    WHERE day_type = 'Weekday'
    GROUP BY station_name, zone_id
)
(SELECT 'Drains' AS problem, * FROM st ORDER BY net_bikes_per_weekday ASC  LIMIT 10)
UNION ALL
(SELECT 'Fills'  AS problem, * FROM st ORDER BY net_bikes_per_weekday DESC LIMIT 10);


-- Q17. "Where do we need new docks or more bikes next year?"
--      Ranks stations on peak-hour demand and year-on-year growth together.
WITH p AS (SELECT * FROM cyclistic.v_periods),
yr AS (
    SELECT start_station_id AS station_id,
           COUNT(*) FILTER (WHERE start_month >= p.current_start)                             AS rides_current,
           COUNT(*) FILTER (WHERE start_month >= p.prior_start AND start_month < p.current_start) AS rides_prior
    FROM cyclistic.fact_trips, p
    WHERE start_station_id IS NOT NULL
    GROUP BY start_station_id
),
peak AS (
    SELECT start_station_id AS station_id, MAX(cnt)::NUMERIC / 365 AS peak_hour_rides_per_day
    FROM (SELECT start_station_id, start_hour, COUNT(*) AS cnt
          FROM cyclistic.fact_trips, p WHERE start_month >= p.current_start AND start_station_id IS NOT NULL
          GROUP BY 1, 2) h
    GROUP BY start_station_id
),
scored AS (
    SELECT c.station_name, c.zone_id, yr.rides_current, yr.rides_prior,
           ROUND(yr.rides_current::NUMERIC / NULLIF(yr.rides_prior, 0) - 1, 3) AS yoy_growth,
           ROUND(pk.peak_hour_rides_per_day, 2)                                AS peak_hour_rides_per_day,
           RANK() OVER (ORDER BY pk.peak_hour_rides_per_day DESC)              AS demand_rank,
           RANK() OVER (ORDER BY yr.rides_current::NUMERIC / NULLIF(yr.rides_prior, 0) DESC NULLS LAST) AS growth_rank
    FROM yr JOIN peak pk USING (station_id) JOIN cyclistic.v_station_current c USING (station_id)
    WHERE yr.rides_prior >= 50                     -- needs a real baseline
)
SELECT RANK() OVER (ORDER BY demand_rank + growth_rank) AS expansion_priority, *
FROM scored
ORDER BY expansion_priority
LIMIT 15;


/* =====================================================================
   F. DATA QUALITY AND DATA MODELLING                  (Dashboard 8)
   ===================================================================== */

-- Q18. "How much are we losing to bad trips, missing bikes, or broken data?"
SELECT start_month,
       COUNT(*)                                                         AS raw_rides,
       COUNT(*) FILTER (WHERE dq_issue = 'non_positive_duration')      AS non_positive_duration,
       COUNT(*) FILTER (WHERE dq_issue = 'under_1_min')                AS false_starts_under_1_min,
       COUNT(*) FILTER (WHERE dq_issue = 'over_24_hours')              AS over_24_hours,
       COUNT(*) FILTER (WHERE dq_issue = 'impossible_speed')           AS impossible_speed,
       COUNT(*) FILTER (WHERE dq_issue IS NULL AND no_end_station)     AS kept_but_no_end_station,
       ROUND(AVG((dq_issue IS NOT NULL)::INT), 4)                      AS removed_share
FROM cyclistic.stg_trips
GROUP BY start_month
ORDER BY start_month;

--      Q18b. Stations where trips most often never reach a station (lost / stolen / dockless left)
SELECT COALESCE(c.station_name, s.start_station_name)       AS start_station,
       COUNT(*)                                             AS trips,
       COUNT(*) FILTER (WHERE s.no_end_station)             AS no_end_station,
       ROUND(AVG(s.no_end_station::INT), 4)                 AS no_end_rate
FROM cyclistic.stg_trips s
LEFT JOIN cyclistic.v_station_current c ON c.station_id = s.start_station_id
WHERE s.dq_issue IS NULL AND s.start_station_id IS NOT NULL
GROUP BY 1
HAVING COUNT(*) >= 200
ORDER BY no_end_rate DESC
LIMIT 10;


-- Q19. "Are there physically impossible trips, with speeds no bike could reach?"
SELECT bike_type,
       COUNT(*) FILTER (WHERE distance_km >= cyclistic.a('min_km_for_speed_check'))      AS trips_checked,
       COUNT(*) FILTER (WHERE dq_issue = 'impossible_speed')                              AS impossible,
       ROUND(COUNT(*) FILTER (WHERE dq_issue = 'impossible_speed')::NUMERIC
             / NULLIF(COUNT(*) FILTER (WHERE distance_km >= cyclistic.a('min_km_for_speed_check')), 0), 4) AS impossible_rate,
       ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY speed_kmh)
              FILTER (WHERE dq_issue IS NULL AND distance_km >= cyclistic.a('min_km_for_speed_check')))::NUMERIC, 1) AS median_speed_kmh_clean
FROM cyclistic.stg_trips
WHERE dq_issue IS NULL OR dq_issue = 'impossible_speed'
GROUP BY bike_type;

--      Q19b. The 10 most extreme examples (for the DQ appendix)
SELECT ride_id, bike_type, rider_type, start_station_name, end_station_name,
       ROUND(distance_km::NUMERIC, 2) AS straight_line_km,
       ROUND(ride_length_min::NUMERIC, 1) AS minutes,
       ROUND(speed_kmh::NUMERIC, 0)   AS implied_kmh
FROM cyclistic.stg_trips
WHERE dq_issue = 'impossible_speed'
ORDER BY speed_kmh DESC
LIMIT 10;


-- Q20. "Are there anomalous days distorting our trends that we should flag or exclude?"
--      Each day is compared with the same weekday in the same calendar month
--      (median and MAD, robust to the outlier itself). |robust z| > 3.5 = anomaly.
DROP TABLE IF EXISTS cyclistic.daily_anomalies;
CREATE TABLE cyclistic.daily_anomalies AS
WITH d AS (
    SELECT start_date, rides,
           EXTRACT(MONTH FROM start_date)::INT  AS month_no,
           EXTRACT(ISODOW FROM start_date)::INT AS iso_dow
    FROM cyclistic.mart_d5_daily
),
med AS (
    SELECT month_no, iso_dow, PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY rides) AS median_rides
    FROM d GROUP BY 1, 2
),
mad AS (
    SELECT d.month_no, d.iso_dow,
           PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY ABS(d.rides - m.median_rides)) AS mad
    FROM d JOIN med m USING (month_no, iso_dow) GROUP BY 1, 2
)
SELECT d.start_date, TO_CHAR(d.start_date, 'Dy') AS weekday, d.rides,
       m.median_rides AS typical_rides,
       ROUND((0.6745 * (d.rides - m.median_rides) / NULLIF(a.mad, 0))::NUMERIC, 2) AS robust_z,
       ABS(0.6745 * (d.rides - m.median_rides) / NULLIF(a.mad, 0)) > 3.5           AS is_anomaly,
       NULL::TEXT AS explanation   -- fill in after checking: holiday, storm, event…
FROM d JOIN med m USING (month_no, iso_dow) JOIN mad a USING (month_no, iso_dow);

SELECT * FROM cyclistic.daily_anomalies WHERE is_anomaly ORDER BY ABS(robust_z) DESC LIMIT 20;


-- Q21. "Station names and IDs change over time. How do we keep trends accurate?"
--      a) Stations with more than one SCD2 version: what changed, and when.
SELECT v.station_id, v.version_no, v.station_name, v.valid_from, v.valid_to,
       CASE WHEN v.version_no = 1 THEN 'original'
            WHEN v.station_name <> LAG(v.station_name) OVER w THEN 'renamed'
            ELSE 'relocated' END                                                         AS change_type,
       ROUND(cyclistic.haversine_km(v.lat, v.lng, LAG(v.lat) OVER w, LAG(v.lng) OVER w)::NUMERIC * 1000)
                                                                                         AS moved_metres
FROM cyclistic.dim_stations v
WHERE v.station_id IN (SELECT station_id FROM cyclistic.dim_stations GROUP BY 1 HAVING COUNT(*) > 1)
WINDOW w AS (PARTITION BY v.station_id ORDER BY v.version_no)
ORDER BY v.station_id, v.version_no;

--      b) The reverse problem: one name used by several station IDs.
SELECT start_station_name, COUNT(DISTINCT start_station_id) AS ids, STRING_AGG(DISTINCT start_station_id, ', ') AS station_ids
FROM cyclistic.stg_trips
WHERE start_station_name IS NOT NULL AND start_station_id IS NOT NULL
GROUP BY start_station_name
HAVING COUNT(DISTINCT start_station_id) > 1
ORDER BY ids DESC;

--      c) Headline for the README.
SELECT COUNT(DISTINCT station_id)                                      AS stations,
       COUNT(*)                                                        AS station_versions,
       COUNT(DISTINCT station_id) FILTER (WHERE version_no > 1)        AS stations_with_drift
FROM cyclistic.dim_stations;
