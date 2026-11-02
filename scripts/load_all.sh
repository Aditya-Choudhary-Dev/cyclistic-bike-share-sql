#!/usr/bin/env bash
# Alternative to 01_load.sql: loads EVERY *.csv in a folder, whatever the months.
# Usage:  ./load_all.sh path/to/divvy_csvs  [database]
set -euo pipefail
DIR="${1:?folder with CSVs}"; DB="${2:-Portfolio_DB}"
COLS="ride_id,rideable_type,started_at,ended_at,start_station_name,start_station_id,end_station_name,end_station_id,start_lat,start_lng,end_lat,end_lng,member_casual"
psql -d "$DB" -v ON_ERROR_STOP=1 -c "TRUNCATE cyclistic.raw_trips"
for f in "$DIR"/*.csv; do
  name="$(basename "$f")"; echo "Loading $name"
  psql -d "$DB" -v ON_ERROR_STOP=1 \
    -c "TRUNCATE cyclistic.load_buffer" \
    -c "\copy cyclistic.load_buffer ($COLS) FROM '$f' WITH (FORMAT csv, HEADER true)" \
    -c "INSERT INTO cyclistic.raw_trips ($COLS, source_file) SELECT *, '$name' FROM cyclistic.load_buffer"
done
psql -d "$DB" -c "SELECT source_file, COUNT(*) FROM cyclistic.raw_trips GROUP BY 1 ORDER BY 1"
