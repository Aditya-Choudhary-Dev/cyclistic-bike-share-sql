# The 21 Business Questions

Each question is written the way a manager would ask it. Each one ties to money (revenue, cost or marketing spend), can be answered from the trip data, and feeds a Tableau dashboard. The SQL for every question is in [`sql/04_answers.sql`](../sql/04_answers.sql), under a comment with its number.

---

## A. Marketing targeting: who and where

**Q1. "Where should we spend our marketing budget? Show me the stations with the most casual riders."**
Ranks stations by number of casual trips and casual share. *Chart: map, bubbles sized by trips, coloured by casual share.*

**Q2. "Which casual riders are basically members who haven't signed up yet?"**
Finds casual trips that look like commutes: weekday, starting 7–9am or 4–6pm, one-way, 30 minutes or less. This is the group most likely to convert. Members are shown alongside as a benchmark. *Chart: KPI tiles and a map of where these trips start.*

**Q3. "What are the top routes casual riders take? I want billboards and partnerships on them."**
Most common casual start → end station pairs. *Chart: route map and ranked bar.*

**Q4. "Which stations are member strongholds, casual hotspots, or up for grabs?"**
Labels every station by trip volume and casual share. *Chart: scatter with four quadrants.*

**Q5. "Forget single stations. Which areas should we buy ads in?"**
Groups stations into ~1 km grid cells and ranks the areas. Marketing teams buy ads by area, not from a list of 800 stations. *Chart: area map coloured by casual share.*

## B. Timing and forecasting: when to act

**Q6. "When exactly should we launch the membership campaign?"**
Finds the month when casual riding ramps up fastest. The campaign should start just before it. *Chart: monthly line.*

**Q7. "Show me the hour-by-day pattern for each rider type."**
Shows commute peaks (members) against afternoon and weekend leisure riding (casual). *Chart: two heatmaps side by side.*

**Q8. "Is our casual share growing or shrinking?"**
Monthly casual share with a 3-month rolling average, and the same month last year when a second year is loaded. *Chart: line with trend.*

**Q9. "What casual demand should we expect next season, and how much should we trust it?"**
A simple "same month last year × growth" forecast, with a low/high range. **Needs two years of data.** With one year, the query returns nothing, which is the honest answer. *Chart: forecast with range bands.*

## C. Revenue and pricing

**Q10. "If we converted some of those riders, how much money are we talking?"**
Revenue at 5%, 10% and 20% conversion. Shows both the naive figure (new membership fees) and the net figure (fees minus the casual fares those riders stop paying). *Chart: what-if dashboard with sliders.*

**Q11. "Does converting them actually make us money, or do we lose riders who pay more as casual?"**
A rider who takes many trips pays more as casual than a membership costs. This finds the break-even number of rides per year: above it, converting that rider loses money. *Chart: break-even line, "profitable" vs "loses money".*

**Q12. "Casual riders take long rides. Are we pricing that properly?"**
Trips and revenue by ride length (0–15, 15–30, 30–60, 60+ minutes). *Chart: bars by length.*

**Q13. "Is there demand for a weekend-only or summer membership?"**
Sizes casual riding by season and weekend vs. weekday. *Chart: stacked bars.*

**Q14. "Who's using e-bikes, and should e-bike prices differ by rider type?"**
Bike type mix, ride length, distance and revenue per trip, by rider type. *Chart: 100% stacked bars.*

## D. Measurement: proving it worked

**Q15. "How would we know the campaign worked, and not just weather or the season?"**
Picks the top casual areas as test zones and matches each to a control zone that moved most like it over the past year. After the campaign, compare the change in the test zone with the change in the control zone (difference-in-differences). Also works out the smallest effect this setup could reliably spot, and runs a fake-launch-date check that should show no effect. *Chart: test vs. control lines before launch.*

## E. Operations: cost savings

**Q16. "Which stations always run empty or overflow, and when?"**
Arrivals minus departures per station, per hour, per day. Tells rebalancing crews where and when to move bikes. *Chart: red/blue map with an hour slider.*

**Q17. "Where do we need new docks or more bikes next year?"**
Ranks stations on peak-hour demand plus year-on-year growth. **Growth needs two years of data.** *Chart: ranked bars and map.*

## F. Data quality and data modelling

**Q18. "How much are we losing to bad trips, missing bikes or broken data?"**
Counts each type of bad record per month, plus the stations where trips most often never reach a station. *Chart: monthly bars.*

**Q19. "Are there trips too fast to be physically possible?"**
Straight-line distance ÷ trip time. Above 40 km/h is flagged (e-bikes assist up to about 32 km/h). Only trips over 0.5 km are checked, because rounded coordinates make short trips look odd. *Chart: speed histogram with the flagged tail.*

**Q20. "Are there unusual days distorting our trends that we should flag?"**
Compares each day with the same weekday in the same month, using median-based scores so one extreme day doesn't hide itself. *Chart: daily line with markers, labelled afterwards (holidays, storms).*

**Q21. "Station names and IDs change over time. How do we keep trends accurate?"**
Finds stations that were renamed or moved, and stores each version with its dates (SCD Type 2), so a renamed station doesn't look like it crashed halfway through the year. *Chart: small table of changed stations.*

---

## Dashboards

| # | Dashboard | Questions |
|---|---|---|
| 1 | Executive overview | 8 |
| 2 | How casual riders and members differ | 7, 12, 14 |
| 3 | Where to target | 1–5 |
| 4 | The conversion opportunity (honest version) | 2, 10, 11, 13 |
| 5 | Timing and forecast | 6, 9 |
| 6 | How we'll prove it worked | 15 |
| 7 | Operations | 16, 17 |
| 8 | Data quality and trust | 18–21 |
