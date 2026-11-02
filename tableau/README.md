# Tableau

**Tableau Public link:** *coming soon*

The dashboards read the CSVs made by [`sql/05_export_for_tableau.sql`](../sql/05_export_for_tableau.sql). Tableau Public can't connect to PostgreSQL directly, so the summary tables are exported as small files first.

| Dashboard | CSV files |
|---|---|
| 1 Executive overview | `d1_monthly.csv` |
| 2 How the groups differ | `d2_hour_dow.csv`, `d2_profile.csv` |
| 3 Where to target | `d3_stations.csv`, `d3_zones.csv`, `d3_routes.csv` |
| 4 Conversion opportunity | `d4_casual_segments.csv`, `d4_assumptions.csv` |
| 5 Timing and forecast | `d1_monthly.csv`, `d5_daily.csv` |
| 6 Proving it worked | `d6_zone_daily.csv`, `d6_campaign_design.csv` |
| 7 Operations | `d7_station_flow.csv` |
| 8 Data quality | `d8_*.csv` |
