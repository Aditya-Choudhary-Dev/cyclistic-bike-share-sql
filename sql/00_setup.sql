/* =====================================================================
   CYCLISTIC BIKE-SHARE — 00_setup.sql
   Creates the schema, the single raw landing table, business assumptions
   and helper functions. Safe to re-run (drops and recreates everything).

   Run order:  00_setup (or 00_setup_keep_raw) → 01_load → 02_pipeline → 03_marts
               → 04_answers (analysis) → 05_export_for_tableau
   Run with:   psql -d Portfolio_DB -f 00_setup.sql
   ===================================================================== */

DROP SCHEMA IF EXISTS cyclistic CASCADE;
CREATE SCHEMA cyclistic;
SET search_path = cyclistic, public;

/* ---------------------------------------------------------------------
   RAW LAYER — one table for all monthly files.
   Every column is TEXT on purpose: the raw layer never rejects a row.
   source_file gives row-level lineage back to the monthly CSV.
   --------------------------------------------------------------------- */
CREATE TABLE cyclistic.raw_trips (
    ride_id            TEXT,
    rideable_type      TEXT,
    started_at         TEXT,
    ended_at           TEXT,
    start_station_name TEXT,
    start_station_id   TEXT,
    end_station_name   TEXT,
    end_station_id     TEXT,
    start_lat          TEXT,
    start_lng          TEXT,
    end_lat            TEXT,
    end_lng            TEXT,
    member_casual      TEXT,
    source_file        TEXT NOT NULL,
    loaded_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Buffer that each CSV lands in before being tagged and moved to raw_trips.
CREATE TABLE cyclistic.load_buffer (
    ride_id TEXT, rideable_type TEXT, started_at TEXT, ended_at TEXT,
    start_station_name TEXT, start_station_id TEXT, end_station_name TEXT, end_station_id TEXT,
    start_lat TEXT, start_lng TEXT, end_lat TEXT, end_lng TEXT, member_casual TEXT
);

/* ---------------------------------------------------------------------
   BUSINESS ASSUMPTIONS — every number that is NOT in the data lives here,
   so the analysis is transparent and one UPDATE changes every answer.
   PRICES ARE PLACEHOLDERS: check divvybikes.com/pricing and update.
   The same values become Tableau parameters on Dashboard 4.
   --------------------------------------------------------------------- */
CREATE TABLE cyclistic.assumptions (
    key   TEXT PRIMARY KEY,
    value NUMERIC NOT NULL,
    note  TEXT
);

INSERT INTO cyclistic.assumptions (key, value, note) VALUES
 ('casual_unlock_fee',          1.00, 'USD per casual ride (placeholder - verify)'),
 ('casual_per_min_classic',     0.18, 'USD per minute, casual, classic bike (placeholder)'),
 ('casual_per_min_ebike',       0.44, 'USD per minute, casual, e-bike (placeholder)'),
 ('member_annual_fee',        143.90, 'USD per year, annual membership (placeholder)'),
 ('member_free_min_classic',   45,    'Minutes included per member classic ride'),
 ('member_per_min_over',        0.18, 'USD per minute after included minutes, member classic'),
 ('member_per_min_ebike',       0.18, 'USD per minute, member e-bike (placeholder)'),
 ('rides_per_casual_rider',    20,    'ASSUMED rides/year per commute-pattern casual rider. Data has no rider ID.'),
 ('max_plausible_speed_kmh',   40,    'Above this straight-line speed a trip is physically implausible'),
 ('min_km_for_speed_check',     0.5,  'Speed only checked above this distance (coordinate rounding noise)'),
 ('station_move_threshold_km',  0.15, 'A station whose location shifts more than this gets a new SCD2 version'),
 ('campaign_days',             60,    'Planned campaign length in days (Q15 measurement design)'),
 ('treatment_zones',            3,    'How many top casual zones get the campaign (Q15)'),
 ('zone_cell_deg_lat',         0.01, 'Zone grid cell height in degrees (~1.1 km)'),
 ('zone_cell_deg_lng',          0.013,'Zone grid cell width in degrees (~1.1 km at Chicago latitude)');

-- Short accessor:  SELECT cyclistic.a('member_annual_fee');
CREATE FUNCTION cyclistic.a(k TEXT) RETURNS NUMERIC
LANGUAGE sql STABLE AS $$ SELECT value FROM cyclistic.assumptions WHERE key = k $$;

/* ---------------------------------------------------------------------
   HELPER FUNCTIONS
   --------------------------------------------------------------------- */

-- Great-circle (straight-line) distance in km. Pure SQL, no PostGIS needed.
-- With PostGIS installed, ST_DistanceSphere(ST_MakePoint(lng1,lat1), ST_MakePoint(lng2,lat2))/1000 is equivalent.
CREATE FUNCTION cyclistic.haversine_km(lat1 FLOAT8, lng1 FLOAT8, lat2 FLOAT8, lng2 FLOAT8)
RETURNS FLOAT8 LANGUAGE sql IMMUTABLE PARALLEL SAFE AS $$
  SELECT 2 * 6371 * ASIN(SQRT(
           POWER(SIN(RADIANS(lat2 - lat1) / 2), 2)
         + COS(RADIANS(lat1)) * COS(RADIANS(lat2)) * POWER(SIN(RADIANS(lng2 - lng1) / 2), 2)))
$$;

-- What a ride costs a CASUAL rider under the assumed pricing.
CREATE FUNCTION cyclistic.casual_fare(bike TEXT, mins NUMERIC) RETURNS NUMERIC
LANGUAGE sql STABLE AS $$
  SELECT cyclistic.a('casual_unlock_fee')
       + mins * CASE WHEN bike = 'electric_bike' THEN cyclistic.a('casual_per_min_ebike')
                     ELSE cyclistic.a('casual_per_min_classic') END
$$;

-- What the same ride costs a MEMBER (usage charges only, excluding the annual fee).
CREATE FUNCTION cyclistic.member_fare(bike TEXT, mins NUMERIC) RETURNS NUMERIC
LANGUAGE sql STABLE AS $$
  SELECT CASE WHEN bike = 'electric_bike' THEN mins * cyclistic.a('member_per_min_ebike')
              ELSE GREATEST(mins - cyclistic.a('member_free_min_classic'), 0) * cyclistic.a('member_per_min_over') END
$$;

-- Geographic zone for a point: a ~1.1 km grid cell. (PostGIS alternative: ST_ClusterKMeans.)
CREATE FUNCTION cyclistic.zone_id(lat FLOAT8, lng FLOAT8) RETURNS TEXT
LANGUAGE sql STABLE AS $$
  SELECT 'Z' || FLOOR(lat / cyclistic.a('zone_cell_deg_lat'))::INT
       || '_' || FLOOR(lng / cyclistic.a('zone_cell_deg_lng'))::INT
$$;
