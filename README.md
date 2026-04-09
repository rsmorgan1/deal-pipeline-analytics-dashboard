# Deal Pipeline Analytics Dashboard

An interactive analytics dashboard for a simulated private equity deal pipeline. This project demonstrates funnel analysis, conversion rate tracking, source/intermediary scoring, and time-to-close metrics using R for data engineering and Tableau Public for interactive visualization.

**All data is entirely synthetic.** No proprietary or confidential information is used. Dataset extends [Project 1: CRM Data Quality Audit](../project-1-crm-data-quality-audit/) with stage progression history.

---

## Business Context

Private equity firms evaluate hundreds of potential investments each year. Deals flow through a structured pipeline: Reviewed → Indication of Interest → Offer → Close (Won or Lost), with many deals passed on early. Understanding conversion rates, time-in-pipeline, and which deal sources produce the best outcomes is critical for optimizing the investment process and allocating team resources.

This project takes 500 cleaned CRM records and enriches them with realistic stage timestamps, then builds a full analytics suite answering questions like:

- Where in the funnel are we losing the most deals?
- Which deal sources and intermediaries produce the highest win rates?
- How long does it take to close a deal, and does it vary by industry or type?
- How has pipeline volume and value trended over time?

---

## Key Metrics

| Metric | Value |
|--------|-------|
| Total Deals | 500 |
| Pipeline Stages | 4 (Reviewed → Indication → Offer → Close) |
| Deal Sources | 5 (Intermediary, Proprietary, Conference, Direct Outreach, Referral) |
| Industries | 3 (Healthcare, Education, Technology-Enabled Services) |
| Deal Types | 2 (Platform, Add-On) |

> *Exact KPIs (win rate, avg days to close, pipeline value) are computed dynamically when the R scripts run.*

---

## Visualizations

### Static Reference Charts (ggplot2)

| Chart | Description |
|-------|-------------|
| `01_deal_funnel.png` | Horizontal funnel showing deals reaching each stage |
| `02_conversion_by_industry.png` | Deal outcomes grouped by industry with win rates |
| `03_source_scorecard.png` | Composite scoring of deal sources (lollipop chart) |
| `04_pipeline_trends.png` | Quarterly volume and value trends |
| `05_outcome_distribution.png` | Won/Lost/Passed/Active breakdown |
| `06_time_to_close.png` | Days-in-pipeline distribution for Won vs. Lost |

### Interactive Dashboard (Tableau Public)

> *Link will be added after Tableau build and publish.*

The Tableau dashboard includes: pipeline overview with KPI bar, funnel visualization, conversion analysis by segment, time-based trends, and source/intermediary performance scoring.

---

## Project Structure

```
project-2-deal-pipeline-dashboard/
├── README.md
├── data/
│   ├── pipeline_deals.csv          # Enriched deal data (one row per deal)
│   └── stage_history.csv           # Stage progression records (one row per transition)
├── scripts_r/
│   ├── 01_extend_pipeline_data.R   # Extend Project 1 data with stage history
│   ├── 02_pipeline_analytics.R     # Funnel analysis, KPIs, scoring
│   └── 03_reference_visualizations.R  # ggplot2 charts for README/GitHub
├── tableau/
│   └── TABLEAU_BUILD_GUIDE.md      # Field reference and dashboard layout guide
└── output/
    ├── funnel_analysis.csv          # Stage-by-stage funnel counts
    ├── conversion_by_industry.csv   # Win rates by industry
    ├── conversion_by_deal_type.csv  # Win rates by deal type
    ├── conversion_by_source.csv     # Win rates by source
    ├── source_scorecard.csv         # Composite source scoring
    ├── intermediary_scorecard.csv   # Intermediary performance
    ├── quarterly_trends.csv         # Pipeline volume/value over time
    ├── deal_owner_performance.csv   # Team member workload and win rates
    ├── kpi_summary.json             # Headline KPI values
    ├── pipeline_summary.json        # High-level pipeline stats
    └── *.png                        # Reference visualizations
```

---

## How to Run

### R Scripts

```r
# 1. Install dependencies
install.packages(c("tidyverse", "jsonlite", "lubridate", "patchwork"))

# 2. Extend Project 1 data with pipeline history
source("scripts_r/01_extend_pipeline_data.R")

# 3. Compute funnel metrics, KPIs, and scorecards
source("scripts_r/02_pipeline_analytics.R")

# 4. Generate reference visualizations
source("scripts_r/03_reference_visualizations.R")
```

> **Note:** Scripts use `rstudioapi::getSourceEditorContext()$path` for path detection in RStudio. If running from the terminal, uncomment and set `project_dir` manually in each script.

> **Prerequisite:** Project 1's cleaned data (`crm_deals_cleaned.csv`) must exist in the sibling `project-1-crm-data-quality-audit/data/` folder.

### Tableau Dashboard

See [`tableau/TABLEAU_BUILD_GUIDE.md`](tableau/TABLEAU_BUILD_GUIDE.md) for the complete field reference, suggested layout, calculated fields, and publishing instructions.

---

## Methodology

### Data Extension
The cleaned 500-record CRM dataset from Project 1 is enriched with stage progression history. Each deal is walked through the pipeline stages with realistic transition probabilities (e.g., ~35% of Reviewed deals advance to Indication, ~55% of Offer deals close as Won) and time intervals drawn from normal distributions calibrated to PE deal timelines.

### Funnel Analysis
Counts distinct deals reaching each pipeline stage and computes stage-to-stage conversion rates and cumulative drop-off percentages.

### Source & Intermediary Scoring
A composite score weights three factors: win rate (40%), deal volume (30%), and total deal value (30%). Intermediary scoring requires a minimum of 2 deals to reduce noise from one-off transactions.

### Time-to-Close
Pipeline duration is measured from `date_sourced` to the final stage date. Distributions are segmented by outcome (Won vs. Lost) and by deal type/industry to identify patterns.

---

## Skills Demonstrated

R (tidyverse, ggplot2, lubridate) · Tableau Public · Data Visualization · Funnel Analysis · KPI Design · Pipeline Analytics · Source/Intermediary Scoring · Synthetic Data Engineering

---

## Related Projects

- [Project 1: CRM Data Quality Audit](../project-1-crm-data-quality-audit/) — The source dataset and quality framework
