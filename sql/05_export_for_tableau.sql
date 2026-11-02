/* =====================================================================
   CYCLISTIC — 05_export_for_tableau.sql
   Tableau PUBLIC cannot connect to PostgreSQL, only to files.
   This writes every mart to a CSV in the current folder.
   Run from the folder you want the CSVs in:
       mkdir tableau_data && cd tableau_data
       psql -d Portfolio_DB -f path/to/05_export_for_tableau.sql
   (With Tableau Desktop / Creator you can connect live instead and skip this.)
   ===================================================================== */
\set ON_ERROR_STOP on

\copy (SELECT * FROM cyclistic.mart_d1_monthly          ORDER BY 1, 2) TO 'd1_monthly.csv'            WITH (FORMAT csv, HEADER true)
\copy (SELECT * FROM cyclistic.mart_d2_hour_dow                      ) TO 'd2_hour_dow.csv'           WITH (FORMAT csv, HEADER true)
\copy (SELECT * FROM cyclistic.mart_d2_profile                       ) TO 'd2_profile.csv'            WITH (FORMAT csv, HEADER true)
\copy (SELECT * FROM cyclistic.mart_d3_stations                      ) TO 'd3_stations.csv'           WITH (FORMAT csv, HEADER true)
\copy (SELECT * FROM cyclistic.mart_d3_zones                         ) TO 'd3_zones.csv'              WITH (FORMAT csv, HEADER true)
\copy (SELECT * FROM cyclistic.mart_d3_routes                        ) TO 'd3_routes.csv'             WITH (FORMAT csv, HEADER true)
\copy (SELECT * FROM cyclistic.mart_d4_casual_segments               ) TO 'd4_casual_segments.csv'    WITH (FORMAT csv, HEADER true)
\copy (SELECT * FROM cyclistic.assumptions                           ) TO 'd4_assumptions.csv'        WITH (FORMAT csv, HEADER true)
\copy (SELECT * FROM cyclistic.mart_d5_daily            ORDER BY 1   ) TO 'd5_daily.csv'              WITH (FORMAT csv, HEADER true)
\copy (SELECT * FROM cyclistic.mart_d6_zone_daily                    ) TO 'd6_zone_daily.csv'         WITH (FORMAT csv, HEADER true)
\copy (SELECT * FROM cyclistic.campaign_design                       ) TO 'd6_campaign_design.csv'    WITH (FORMAT csv, HEADER true)
\copy (SELECT * FROM cyclistic.mart_d7_station_flow                  ) TO 'd7_station_flow.csv'       WITH (FORMAT csv, HEADER true)
\copy (SELECT * FROM cyclistic.mart_d8_dq_funnel                     ) TO 'd8_dq_funnel.csv'          WITH (FORMAT csv, HEADER true)
\copy (SELECT * FROM cyclistic.mart_d8_speed                         ) TO 'd8_speed.csv'              WITH (FORMAT csv, HEADER true)
\copy (SELECT * FROM cyclistic.daily_anomalies          ORDER BY 1   ) TO 'd8_daily_anomalies.csv'    WITH (FORMAT csv, HEADER true)
\copy (SELECT * FROM cyclistic.dim_stations             ORDER BY 2, 3) TO 'd8_dim_stations.csv'       WITH (FORMAT csv, HEADER true)
\copy (SELECT * FROM cyclistic.data_quality_log         ORDER BY 1, 2) TO 'd8_data_quality_log.csv'   WITH (FORMAT csv, HEADER true)

\echo Exported 17 CSVs for Tableau.
