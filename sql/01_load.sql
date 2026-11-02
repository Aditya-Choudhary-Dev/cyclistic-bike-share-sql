/* =====================================================================
   CYCLISTIC — 01_load.sql
   Loads the 12 monthly Divvy CSVs (Apr 2021 – Mar 2022) into ONE table,
   cyclistic.raw_trips, tagging each row with the file it came from.

   Run from the folder that holds the CSVs:
       cd path/to/divvy_csvs
       psql -d Portfolio_DB -f path/to/sql/01_load.sql
   \copy reads files from your own computer, so this also works when
   PostgreSQL runs in Docker. Keep the files as raw .csv (don't re-save in Excel).
   ===================================================================== */
\set ON_ERROR_STOP on
TRUNCATE cyclistic.raw_trips;

\echo Loading 202104-divvy-tripdata.csv
TRUNCATE cyclistic.load_buffer;
\copy cyclistic.load_buffer (ride_id,rideable_type,started_at,ended_at,start_station_name,start_station_id,end_station_name,end_station_id,start_lat,start_lng,end_lat,end_lng,member_casual) FROM '202104-divvy-tripdata.csv' WITH (FORMAT csv, HEADER true)
INSERT INTO cyclistic.raw_trips (ride_id,rideable_type,started_at,ended_at,start_station_name,start_station_id,end_station_name,end_station_id,start_lat,start_lng,end_lat,end_lng,member_casual, source_file) SELECT *, '202104-divvy-tripdata.csv' FROM cyclistic.load_buffer;
\echo Loading 202105-divvy-tripdata.csv
TRUNCATE cyclistic.load_buffer;
\copy cyclistic.load_buffer (ride_id,rideable_type,started_at,ended_at,start_station_name,start_station_id,end_station_name,end_station_id,start_lat,start_lng,end_lat,end_lng,member_casual) FROM '202105-divvy-tripdata.csv' WITH (FORMAT csv, HEADER true)
INSERT INTO cyclistic.raw_trips (ride_id,rideable_type,started_at,ended_at,start_station_name,start_station_id,end_station_name,end_station_id,start_lat,start_lng,end_lat,end_lng,member_casual, source_file) SELECT *, '202105-divvy-tripdata.csv' FROM cyclistic.load_buffer;
\echo Loading 202106-divvy-tripdata.csv
TRUNCATE cyclistic.load_buffer;
\copy cyclistic.load_buffer (ride_id,rideable_type,started_at,ended_at,start_station_name,start_station_id,end_station_name,end_station_id,start_lat,start_lng,end_lat,end_lng,member_casual) FROM '202106-divvy-tripdata.csv' WITH (FORMAT csv, HEADER true)
INSERT INTO cyclistic.raw_trips (ride_id,rideable_type,started_at,ended_at,start_station_name,start_station_id,end_station_name,end_station_id,start_lat,start_lng,end_lat,end_lng,member_casual, source_file) SELECT *, '202106-divvy-tripdata.csv' FROM cyclistic.load_buffer;
\echo Loading 202107-divvy-tripdata.csv
TRUNCATE cyclistic.load_buffer;
\copy cyclistic.load_buffer (ride_id,rideable_type,started_at,ended_at,start_station_name,start_station_id,end_station_name,end_station_id,start_lat,start_lng,end_lat,end_lng,member_casual) FROM '202107-divvy-tripdata.csv' WITH (FORMAT csv, HEADER true)
INSERT INTO cyclistic.raw_trips (ride_id,rideable_type,started_at,ended_at,start_station_name,start_station_id,end_station_name,end_station_id,start_lat,start_lng,end_lat,end_lng,member_casual, source_file) SELECT *, '202107-divvy-tripdata.csv' FROM cyclistic.load_buffer;
\echo Loading 202108-divvy-tripdata.csv
TRUNCATE cyclistic.load_buffer;
\copy cyclistic.load_buffer (ride_id,rideable_type,started_at,ended_at,start_station_name,start_station_id,end_station_name,end_station_id,start_lat,start_lng,end_lat,end_lng,member_casual) FROM '202108-divvy-tripdata.csv' WITH (FORMAT csv, HEADER true)
INSERT INTO cyclistic.raw_trips (ride_id,rideable_type,started_at,ended_at,start_station_name,start_station_id,end_station_name,end_station_id,start_lat,start_lng,end_lat,end_lng,member_casual, source_file) SELECT *, '202108-divvy-tripdata.csv' FROM cyclistic.load_buffer;
\echo Loading 202109-divvy-tripdata.csv
TRUNCATE cyclistic.load_buffer;
\copy cyclistic.load_buffer (ride_id,rideable_type,started_at,ended_at,start_station_name,start_station_id,end_station_name,end_station_id,start_lat,start_lng,end_lat,end_lng,member_casual) FROM '202109-divvy-tripdata.csv' WITH (FORMAT csv, HEADER true)
INSERT INTO cyclistic.raw_trips (ride_id,rideable_type,started_at,ended_at,start_station_name,start_station_id,end_station_name,end_station_id,start_lat,start_lng,end_lat,end_lng,member_casual, source_file) SELECT *, '202109-divvy-tripdata.csv' FROM cyclistic.load_buffer;
\echo Loading 202110-divvy-tripdata.csv
TRUNCATE cyclistic.load_buffer;
\copy cyclistic.load_buffer (ride_id,rideable_type,started_at,ended_at,start_station_name,start_station_id,end_station_name,end_station_id,start_lat,start_lng,end_lat,end_lng,member_casual) FROM '202110-divvy-tripdata.csv' WITH (FORMAT csv, HEADER true)
INSERT INTO cyclistic.raw_trips (ride_id,rideable_type,started_at,ended_at,start_station_name,start_station_id,end_station_name,end_station_id,start_lat,start_lng,end_lat,end_lng,member_casual, source_file) SELECT *, '202110-divvy-tripdata.csv' FROM cyclistic.load_buffer;
\echo Loading 202111-divvy-tripdata.csv
TRUNCATE cyclistic.load_buffer;
\copy cyclistic.load_buffer (ride_id,rideable_type,started_at,ended_at,start_station_name,start_station_id,end_station_name,end_station_id,start_lat,start_lng,end_lat,end_lng,member_casual) FROM '202111-divvy-tripdata.csv' WITH (FORMAT csv, HEADER true)
INSERT INTO cyclistic.raw_trips (ride_id,rideable_type,started_at,ended_at,start_station_name,start_station_id,end_station_name,end_station_id,start_lat,start_lng,end_lat,end_lng,member_casual, source_file) SELECT *, '202111-divvy-tripdata.csv' FROM cyclistic.load_buffer;
\echo Loading 202112-divvy-tripdata.csv
TRUNCATE cyclistic.load_buffer;
\copy cyclistic.load_buffer (ride_id,rideable_type,started_at,ended_at,start_station_name,start_station_id,end_station_name,end_station_id,start_lat,start_lng,end_lat,end_lng,member_casual) FROM '202112-divvy-tripdata.csv' WITH (FORMAT csv, HEADER true)
INSERT INTO cyclistic.raw_trips (ride_id,rideable_type,started_at,ended_at,start_station_name,start_station_id,end_station_name,end_station_id,start_lat,start_lng,end_lat,end_lng,member_casual, source_file) SELECT *, '202112-divvy-tripdata.csv' FROM cyclistic.load_buffer;
\echo Loading 202201-divvy-tripdata.csv
TRUNCATE cyclistic.load_buffer;
\copy cyclistic.load_buffer (ride_id,rideable_type,started_at,ended_at,start_station_name,start_station_id,end_station_name,end_station_id,start_lat,start_lng,end_lat,end_lng,member_casual) FROM '202201-divvy-tripdata.csv' WITH (FORMAT csv, HEADER true)
INSERT INTO cyclistic.raw_trips (ride_id,rideable_type,started_at,ended_at,start_station_name,start_station_id,end_station_name,end_station_id,start_lat,start_lng,end_lat,end_lng,member_casual, source_file) SELECT *, '202201-divvy-tripdata.csv' FROM cyclistic.load_buffer;
\echo Loading 202202-divvy-tripdata.csv
TRUNCATE cyclistic.load_buffer;
\copy cyclistic.load_buffer (ride_id,rideable_type,started_at,ended_at,start_station_name,start_station_id,end_station_name,end_station_id,start_lat,start_lng,end_lat,end_lng,member_casual) FROM '202202-divvy-tripdata.csv' WITH (FORMAT csv, HEADER true)
INSERT INTO cyclistic.raw_trips (ride_id,rideable_type,started_at,ended_at,start_station_name,start_station_id,end_station_name,end_station_id,start_lat,start_lng,end_lat,end_lng,member_casual, source_file) SELECT *, '202202-divvy-tripdata.csv' FROM cyclistic.load_buffer;
\echo Loading 202203-divvy-tripdata.csv
TRUNCATE cyclistic.load_buffer;
\copy cyclistic.load_buffer (ride_id,rideable_type,started_at,ended_at,start_station_name,start_station_id,end_station_name,end_station_id,start_lat,start_lng,end_lat,end_lng,member_casual) FROM '202203-divvy-tripdata.csv' WITH (FORMAT csv, HEADER true)
INSERT INTO cyclistic.raw_trips (ride_id,rideable_type,started_at,ended_at,start_station_name,start_station_id,end_station_name,end_station_id,start_lat,start_lng,end_lat,end_lng,member_casual, source_file) SELECT *, '202203-divvy-tripdata.csv' FROM cyclistic.load_buffer;

TRUNCATE cyclistic.load_buffer;

-- Check: expect 12 rows, one per file.
SELECT source_file, COUNT(*) AS rows_loaded FROM cyclistic.raw_trips GROUP BY 1 ORDER BY 1;
