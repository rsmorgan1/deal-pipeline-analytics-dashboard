# ============================================================
# Deal Pipeline Analytics & KPI Engine
# ============================================================
# Computes funnel metrics, conversion rates, time-to-close,
# intermediary/source scoring, and segmented KPIs.
#
# Reads: data/pipeline_deals.csv, data/stage_history.csv
# Writes: output/funnel_analysis.csv, output/kpi_summary.json,
#         output/source_scorecard.csv, output/intermediary_scorecard.csv
# ============================================================

library(tidyverse)
library(jsonlite)
library(lubridate)


# ============================================================
# 1. Funnel Analysis
# ============================================================

compute_funnel <- function(deals, stage_history) {
  # Count deals reaching each stage
  stages_ordered <- c("Reviewed", "Indication", "Offer", "Closed - Won")

  funnel <- tibble(stage = stages_ordered) %>%
    mutate(
      deals_reached = map_int(stage, function(s) {
        if (s == "Reviewed") {
          nrow(deals)  # all deals enter at Reviewed
        } else {
          stage_history %>%
            filter(stage == s) %>%
            distinct(deal_id) %>%
            nrow()
        }
      }),
      stage_order = row_number()
    ) %>%
    mutate(
      pct_of_total       = round(deals_reached / first(deals_reached) * 100, 1),
      stage_conversion   = round(deals_reached / lag(deals_reached) * 100, 1),
      deals_dropped      = lag(deals_reached) - deals_reached
    )

  funnel
}


# ============================================================
# 2. Conversion Rates by Segment
# ============================================================

conversion_by_segment <- function(deals, segment_col) {
  seg_sym <- sym(segment_col)

  deals %>%
    filter(is_closed | is_passed) %>%
    group_by(!!seg_sym) %>%
    summarise(
      total_deals   = n(),
      won           = sum(is_won),
      lost          = sum(deal_stage == "Closed - Lost"),
      passed        = sum(is_passed),
      win_rate      = round(won / max(sum(is_closed), 1) * 100, 1),
      avg_days      = round(mean(days_in_pipeline, na.rm = TRUE), 0),
      avg_deal_size = round(mean(deal_size_usd, na.rm = TRUE) / 1e6, 1),
      .groups = "drop"
    ) %>%
    arrange(desc(win_rate))
}


# ============================================================
# 3. Source & Intermediary Scoring
# ============================================================

score_sources <- function(deals) {
  deals %>%
    group_by(source) %>%
    summarise(
      total_deals     = n(),
      won             = sum(is_won),
      reached_offer   = sum(reached_offer, na.rm = TRUE),
      win_rate        = round(won / max(sum(is_closed), 1) * 100, 1),
      avg_days        = round(mean(days_in_pipeline, na.rm = TRUE), 0),
      avg_revenue     = round(mean(revenue_usd, na.rm = TRUE) / 1e6, 1),
      total_deal_value = round(sum(deal_size_usd, na.rm = TRUE) / 1e6, 1),
      .groups = "drop"
    ) %>%
    mutate(
      # Composite score: 40% win rate + 30% volume + 30% deal value
      vol_score   = round(total_deals / max(total_deals) * 100, 1),
      value_score = round(total_deal_value / max(total_deal_value) * 100, 1),
      composite   = round(win_rate * 0.4 + vol_score * 0.3 + value_score * 0.3, 1)
    ) %>%
    arrange(desc(composite))
}

score_intermediaries <- function(deals) {
  deals %>%
    filter(!is.na(intermediary) & intermediary != "") %>%
    group_by(intermediary) %>%
    summarise(
      total_deals     = n(),
      won             = sum(is_won),
      reached_offer   = sum(reached_offer, na.rm = TRUE),
      win_rate        = round(won / max(sum(is_closed), 1) * 100, 1),
      avg_days        = round(mean(days_in_pipeline, na.rm = TRUE), 0),
      avg_deal_size   = round(mean(deal_size_usd, na.rm = TRUE) / 1e6, 1),
      .groups = "drop"
    ) %>%
    filter(total_deals >= 2) %>%   # minimum threshold
    arrange(desc(win_rate), desc(total_deals))
}


# ============================================================
# 4. Time-Based Trends
# ============================================================

compute_trends <- function(deals) {
  deals %>%
    group_by(sourced_quarter) %>%
    summarise(
      deals_sourced   = n(),
      won             = sum(is_won),
      avg_days        = round(mean(days_in_pipeline, na.rm = TRUE), 0),
      total_value     = round(sum(deal_size_usd, na.rm = TRUE) / 1e6, 1),
      platform_pct    = round(mean(deal_type == "Platform") * 100, 1),
      .groups = "drop"
    ) %>%
    arrange(sourced_quarter)
}


# ============================================================
# 5. Deal Owner Performance
# ============================================================

score_deal_owners <- function(deals) {
  deals %>%
    group_by(deal_owner) %>%
    summarise(
      total_deals   = n(),
      won           = sum(is_won),
      active        = sum(is_active),
      win_rate      = round(won / max(sum(is_closed), 1) * 100, 1),
      avg_days      = round(mean(days_in_pipeline, na.rm = TRUE), 0),
      total_value   = round(sum(deal_size_usd, na.rm = TRUE) / 1e6, 1),
      .groups = "drop"
    ) %>%
    arrange(desc(win_rate))
}


# ============================================================
# Main
# ============================================================

if (sys.nframe() == 0) {
  project_dir <- dirname(dirname(rstudioapi::getSourceEditorContext()$path))
  # project_dir <- "path/to/project-2-deal-pipeline-dashboard"  # manual override

  data_dir   <- file.path(project_dir, "data")
  output_dir <- file.path(project_dir, "output")

  cat("=== Deal Pipeline Analytics ===\n\n")

  deals <- read_csv(file.path(data_dir, "pipeline_deals.csv"), show_col_types = FALSE)
  stage_history <- read_csv(file.path(data_dir, "stage_history.csv"), show_col_types = FALSE)

  cat(sprintf("Loaded %d deals and %d stage records\n\n", nrow(deals), nrow(stage_history)))

  # --- Funnel ---
  funnel <- compute_funnel(deals, stage_history)
  write_csv(funnel, file.path(output_dir, "funnel_analysis.csv"))
  cat("Funnel Analysis:\n")
  print(funnel, n = Inf)

  # --- Conversions by segment ---
  conv_industry <- conversion_by_segment(deals, "industry")
  conv_type     <- conversion_by_segment(deals, "deal_type")
  conv_source   <- conversion_by_segment(deals, "source")
  write_csv(conv_industry, file.path(output_dir, "conversion_by_industry.csv"))
  write_csv(conv_type,     file.path(output_dir, "conversion_by_deal_type.csv"))
  write_csv(conv_source,   file.path(output_dir, "conversion_by_source.csv"))

  cat("\nConversion by Industry:\n")
  print(conv_industry, n = Inf)
  cat("\nConversion by Deal Type:\n")
  print(conv_type, n = Inf)

  # --- Source & Intermediary Scoring ---
  src_scores <- score_sources(deals)
  int_scores <- score_intermediaries(deals)
  write_csv(src_scores, file.path(output_dir, "source_scorecard.csv"))
  write_csv(int_scores, file.path(output_dir, "intermediary_scorecard.csv"))

  cat("\nSource Scorecard:\n")
  print(src_scores, n = Inf)
  cat(sprintf("\nIntermediary Scorecard: %d intermediaries with 2+ deals\n", nrow(int_scores)))

  # --- Trends ---
  trends <- compute_trends(deals)
  write_csv(trends, file.path(output_dir, "quarterly_trends.csv"))

  # --- Deal Owner Performance ---
  owner_perf <- score_deal_owners(deals)
  write_csv(owner_perf, file.path(output_dir, "deal_owner_performance.csv"))

  # --- KPI Summary ---
  closed_deals <- deals %>% filter(is_closed)
  kpi <- list(
    total_deals         = nrow(deals),
    active_deals        = sum(deals$is_active),
    closed_won          = sum(deals$is_won),
    closed_lost         = sum(deals$deal_stage == "Closed - Lost"),
    passed              = sum(deals$is_passed),
    overall_win_rate    = round(mean(closed_deals$is_won) * 100, 1),
    avg_days_to_close   = round(mean(closed_deals$days_in_pipeline, na.rm = TRUE), 0),
    median_days_to_close = round(median(closed_deals$days_in_pipeline, na.rm = TRUE), 0),
    total_pipeline_value = round(sum(deals$deal_size_usd, na.rm = TRUE) / 1e6, 1),
    avg_deal_size       = round(mean(deals$deal_size_usd, na.rm = TRUE) / 1e6, 1),
    platform_pct        = round(mean(deals$deal_type == "Platform") * 100, 1),
    healthcare_pct      = round(mean(deals$industry == "Healthcare") * 100, 1)
  )

  write_json(kpi, file.path(output_dir, "kpi_summary.json"), pretty = TRUE, auto_unbox = TRUE)
  cat("\nKPI Summary saved.\n")

  cat("\nAll analytics exported to output/\n")
}
