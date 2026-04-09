# Tableau Dashboard Build Guide

## Data Import

Connect to these two CSV files from the `data/` folder:

1. **pipeline_deals.csv** — One row per deal (primary table)
2. **stage_history.csv** — One row per stage transition (join on `deal_id`)

### Relationship Setup
- Primary: `pipeline_deals`
- Related: `stage_history` on `deal_id` (left join)

---

## Key Fields Reference

### pipeline_deals.csv

| Field | Type | Description |
|-------|------|-------------|
| deal_id | String | Unique deal identifier |
| company_name | String | Synthetic company name |
| industry | String | Healthcare, Education, Technology-Enabled Services |
| focus_area | String | Sub-sector specialty |
| deal_type | String | Platform or Add-On |
| source | String | Intermediary, Proprietary, Conference, Direct Outreach, Referral |
| intermediary | String | Bank/advisor name (nullable) |
| deal_stage | String | Current stage: Reviewed, Indication, Offer, Closed - Won/Lost, Passed |
| deal_owner | String | Investment team member |
| date_sourced | Date | When the deal entered the pipeline |
| revenue_usd | Number | Company annual revenue |
| ebitda_usd | Number | Company EBITDA (nullable) |
| deal_size_usd | Number | Estimated transaction value |
| sourced_quarter | String | "Q1 2024" format for time filters |
| sourced_year | Number | Year for time filters |
| sourced_month | Date | First of month for trend lines |
| days_in_pipeline | Number | Total days from sourced to current stage |
| stages_reached | Number | Count of stages the deal progressed through |
| is_won | Boolean | Closed - Won flag |
| is_active | Boolean | Still in pipeline (Reviewed/Indication/Offer) |
| is_closed | Boolean | Closed - Won or Closed - Lost |
| deal_outcome | String | Won, Lost, Passed, or Active |
| revenue_band | String | Under $20M, $20M-$50M, $50M-$100M, $100M+ |
| ebitda_margin | Number | EBITDA / Revenue (%) where available |
| reached_indication | Boolean | Deal made it past Reviewed |
| reached_offer | Boolean | Deal reached Offer stage |

### stage_history.csv

| Field | Type | Description |
|-------|------|-------------|
| deal_id | String | Links to pipeline_deals |
| stage | String | Stage name |
| stage_date | Date | Date this stage was reached |
| stage_order | Number | Sequence within this deal's progression |
| days_in_stage | Number | Days before transitioning to next stage (null for final stage) |

---

## Suggested Dashboard Layout (4 sheets)

### Sheet 1: Pipeline Overview
- **KPI bar** across the top: Total Deals, Active Deals, Won, Win Rate, Avg Days to Close, Total Pipeline Value ($M)
- **Funnel chart**: Horizontal bars for Reviewed → Indication → Offer → Closed-Won, with stage-to-stage conversion % labels
- **Filters**: Industry, Deal Type, Source, Date Range

### Sheet 2: Conversion & Segmentation
- **Stacked bar**: Deal outcomes by Industry
- **Grouped bar**: Win rate by Source
- **Heat map**: Win rate by Industry x Deal Type
- **Scatter**: Deal size vs. days in pipeline, colored by outcome

### Sheet 3: Time Analysis
- **Area chart**: Deals sourced per quarter (trend line)
- **Line chart**: Pipeline value over time
- **Box plot**: Days in pipeline by deal stage
- **Bar chart**: Average time-in-stage for each transition

### Sheet 4: Source & Intermediary Performance
- **Lollipop or bar**: Source composite score with win rate annotation
- **Table**: Top intermediaries by deal count and win rate
- **Bar chart**: Deal owner workload (active vs. closed deals)

---

## Calculated Fields (Create in Tableau)

```
// Win Rate
SUM(IF [Is Won] THEN 1 ELSE 0 END) / SUM(IF [Is Closed] THEN 1 ELSE 0 END)

// Stage Conversion Rate (use with stage_history)
// Compare COUNTD(deal_id) at Stage N vs Stage N-1

// Pipeline Velocity
SUM([Deal Size Usd]) / AVG([Days In Pipeline])

// Weighted Pipeline Value
SUM(IF [Deal Stage] = "Offer" THEN [Deal Size Usd] * 0.55
    ELSEIF [Deal Stage] = "Indication" THEN [Deal Size Usd] * 0.14
    ELSE 0 END)
```

---

## Publishing to Tableau Public

1. Build the dashboard in Tableau Desktop (Public Edition is free)
2. File → Save to Tableau Public
3. Set the viz to "Show" (visible) on your profile
4. Copy the embed URL for your README and portfolio site
