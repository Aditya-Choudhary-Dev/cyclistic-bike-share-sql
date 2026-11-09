# Results: Key Findings

Data: Divvy trips, **April 2021 – March 2022**. After cleaning: **5,629,342 trips** (2,507,643 casual · 3,121,699 member).
Full output of all 21 queries: [`answers_output.txt`](answers_output.txt)

> **Dollar figures use placeholder prices** from the `cyclistic.assumptions` table, not Divvy's real price list. Treat them as "what the method shows", not a forecast. The trip counts and patterns are real.

---

## The short version

1. **There are two kinds of casual rider, and they need different campaigns.** Most casual riding is lakefront leisure (Streeter Dr & Grand Ave, Millennium Park, Shedd Aquarium). But the casual riders who *ride like members* (weekday commuters) are in the business districts: River North, the West Loop and the Loop.
2. **Converting riders is worth less than it looks.** At a 10% conversion rate, membership fees bring in about $210k, but those riders stop paying casual fares, so the real gain is about $99k, **less than half**.
3. **Converting heavy riders loses money.** Above about **38 rides a year**, a rider pays more as casual than a membership costs. Target occasional commuters, not the heaviest casual riders.
4. **Launch in April.** Casual riding nearly doubles from April to May and peaks in July. Summer alone is 48% of the year's casual rides.
5. **The data needs care.** 1.6% of trips were removed as broken, 13.6% of kept trips have no end station, and 23 stations were renamed or moved during the year.

---

## A. Who and where

**Q1. Top casual stations.** **Streeter Dr & Grand Ave** is far ahead, with 66,502 casual rides (80% of its rides). Next come DuSable Lake Shore Dr & Monroe St (34,912), Millennium Park (32,837), Michigan Ave & Oak St and DuSable Lake Shore Dr & North Blvd. At tourist spots, 80%+ of rides are casual (Shedd Aquarium 83%).

**Q2. Casual riders who already ride like members.** **291,247 casual rides (11.6%)** follow a commute pattern: weekday, 7–9am or 4–6pm, one-way, 30 minutes or less. Members do this on 22.9% of rides. This conversion pool is **spread out**: the top station holds only 1.6% of it. Apart from Streeter Dr, the leading stations are business-district ones (Wells St & Elm St, Clark St & Elm St, Kingsbury St & Kinzie St, Clinton St & Washington Blvd).

**Q3. Top casual routes.** All of the top 15 are lakefront leisure loops. The #1 route, **DuSable Lake Shore Dr & Monroe St → Streeter Dr & Grand Ave** (5,691 rides, ~30 min), runs along the lake from the Museum Campus to Navy Pier. These routes suit tourism partnerships, not commuter ads.

**Q4. Station segments.** **367 "up for grabs" stations** (high volume, mixed riders) carry **59% of all trips**, with a 43% casual share. That's where most of the opportunity sits. 174 casual hotspots average 67% casual, and 96 member strongholds average 28%.

**Q5. Best areas to buy ads (about 1 km zones).**
| Goal | Best zone | Why |
|---|---|---|
| Reach the most casual riders | River North / Streeter Dr (Wabash & Grand, Dearborn & Erie…) | 138,495 casual rides |
| Reach likely converters | **West Loop** (Kingsbury & Kinzie, Clinton & Madison…) | Most commute-pattern casual rides among the top 10 zones (16,303), even though only 33% of its riders are casual |

## B. When

**Q6. Campaign timing.** Casual rides climb from 88k in March to 135k in April, **253k in May** (+88%) and **435k in July** (the peak). Launch in **April**, so the campaign is running when riders come back.

**Q7. Riding hours.** On weekdays, **both groups peak at 5pm**: casual riders also commute home. On weekends, casual riding peaks from 1pm to 3pm. Weekday 4–6pm is the window for "ride home for less" messaging.

**Q8. Casual share.** Casual riders made up **54% of trips in July 2021** and **18% in January 2022**. Their share swings much more with the season than members' share does.

**Q9. Forecast.** Not possible with one year of data. The query correctly returns no forecast. Loading April 2022 – March 2023 would fill it in.

## C. Money

**Q10. Revenue from converting the commute-pattern pool** (assuming 20 rides per rider per year):
| Conversion | New members | Fees only (naive) | Real gain (fees minus lost casual fares) |
|---|---|---|---|
| 5% | 728 | $104,776 | $49,485 |
| 10% | 1,456 | $209,552 | **$98,969** |
| 20% | 2,912 | $419,104 | $197,938 |

**Q11. When converting loses money.** Break-even is **37.9 rides a year**. A rider who takes 20 rides brings in about $68 more as a member. A rider who takes 50 rides brings in about $46 *less*. So the campaign should aim at occasional commuters.

**Q12. Long casual rides.** 24% of casual rides last over 30 minutes, against 7% for members. Rides over 60 minutes are only **9% of casual rides but 31% of casual fare revenue**. Any pricing change on long rides affects a large share of income.

**Q13. Weekend or summer pass.** About 40% of casual rides fall on weekends, rising to 44% in spring. Summer brings 48% of casual rides and winter only 4%. This makes a strong case for a **summer membership** rather than a weekend-only one.

**Q14. Bikes.** **Docked bikes are used only by casual riders** (12% of their rides, averaging 50 minutes, the longest of any group). Casual riders choose e-bikes more often than members do (38% vs 37%) but ride them for shorter trips (20 min).

## D. Proving the campaign worked

**Q15. Measurement plan.** The three biggest casual zones were each paired with a control zone whose daily pattern matches closely (correlation 0.93–0.97). The design could detect a change of **1.8–3.1 percentage points** in casual share. **However, the fake-launch check passed for only 1 of the 3 pairs.** The other two pairs drifted apart with no campaign at all, so they need better control zones before a real launch. Finding this before money is spent is exactly the point of the check.

## E. Operations

**Q16. Stations that run empty or overflow.** **DuSable Lake Shore Dr & North Blvd gains about 20 bikes every weekday**, and Sheffield Ave & Waveland Ave gains about 11. **Columbus Dr & Randolph St loses about 9.5.** Riders take bikes one way along the lakefront and leave them there, so crews need to move bikes back regularly.

**Q17. Expansion.** Needs a second year to measure growth. The query returns nothing for now.

## F. Data quality

**Q18. Broken trips.** **94,190 trips (1.6%) were removed**:
| Reason | Trips |
|---|---|
| Under 1 minute (false starts) | 88,716 |
| Over 24 hours | 4,138 |
| Too fast to be possible | 677 |
| Ended before it started | 659 |

A further **766,110 kept trips (13.6%) have no end station**. These are mostly e-bikes parked away from a dock. At some outer-area stations (e.g. Long Ave & Belden Ave), **over 80% of trips never end at a station**.

**Q19. Impossible speeds.** 677 trips, **672 of them on e-bikes**. The worst is a trip at a *test charging station* that "travelled" 1,190 km in 2.6 minutes, showing that test and maintenance records are mixed in with real trips. Normal median speeds are 9.9 km/h on classic bikes and 12.7 km/h on e-bikes.

**Q20. Unusual days.** 20 days were flagged, including:
- **17 Mar 2022** (St Patrick's Day): 15,900 rides vs ~6,900 typical
- **5 Mar 2022**: 3.4× a normal March Saturday
- **2 Feb 2022**: only 685 rides vs ~5,100 typical, likely winter-storm weather

Causes still need confirming against weather and event records before these days are excluded from trends.

**Q21. Station renames and moves.** **23 of 850 stations changed** during the year (909 versions in total). The biggest real change: on **19 July 2021**, every "Lake Shore Dr" station was renamed **"DuSable Lake Shore Dr"**. Without the station history table, these stations would look like they lost all their riders halfway through the year. Some recorded "moves" of 20+ km are **bad coordinates or warehouse/test locations**, not real moves. These are worth filtering out in the next version.

---

## Next steps
- Load April 2022 – March 2023 to unlock the forecast (Q9), growth ranking (Q17) and year-on-year trends (Q8).
- Replace placeholder prices with Divvy's real price list.
- Filter test, warehouse and charging stations out of the pipeline.
- Re-pair the control zones in Q15 until the fake-launch check passes for all three.
