# ============================================================
# Extend Project 1 CRM Data for Pipeline Analytics
# ============================================================
# Reads the cleaned CRM dataset from Project 1 and enriches it
# with realistic stage progression history, timestamps, and
# conversion metrics needed for funnel & pipeline analysis.
#
# Output: data/pipeline_deals.csv (Tableau-ready)
# ============================================================

library(tidyverse)
library(lubridate)
library(jsonlite)

set.seed(42)

# ============================================================
# Configuration
# ============================================================

# Stage progression order (PE deal lifecycle)
STAGE_ORDER <- c("Reviewed", "Indication", "Offer", "Closed - Won", "Closed - Lost", "Passed")

# Average days between stages (with some variance)
STAGE_DURATION <- tribble(
  ~from_stage,    ~to_stage,        ~mean_days, ~sd_days,
  "Reviewed",     "Indication",     21,         10,
  "Reviewed",     "Passed",         14,          7,
  "Indication",   "Offer",          35,         15,
  "Indication",   "Closed - Lost",  28,         12,
  "Indication",   "Passed",         21,          9,
  "Offer",        "Closed - Won",   45,         20,
  "Offer",        "Closed - Lost",  30,         14
)

# Conversion probabilities by stage (approximate PE funnel rates)
CONVERSION_RATES <- tribble(
  ~current_stage,  ~next_stage,       ~probability,
  "Reviewed",      "Indication",      0.35,
  "Reviewed",      "Passed",          0.65,
  "Indication",    "Offer",           0.40,
  "Indication",    "Closed - Lost",   0.35,
  "Indication",    "Passed",          0.25,
  "Offer",         "Closed - Won",    0.55,
  "Offer",         "Closed - Lost",   0.45
)


# ============================================================
# Load Project 1 Cleaned Data
# ============================================================

load_project1_data <- function(project1_path) {
  df <- read_csv(
    file.path(project1_path, "data", "crm_deals_cleaned.csv"),
    show_col_types = FALSE
  )
  cat(sprintf("Loaded %d records from Project 1\n", nrow(df)))
  df
}


# ============================================================
# Generate Stage Progression History
# ============================================================

generate_stage_history <- function(deal_id, date_sourced, final_stage) {
  # Every deal starts at Reviewed

  history <- tibble(
    deal_id    = deal_id,
    stage      = "Reviewed",
    stage_date = as.Date(date_sourced),
    stage_order = 1L
  )

  current_stage <- "Reviewed"
  current_date  <- as.Date(date_sourced)
  order_idx     <- 1L

  # Walk the deal through stages until it reaches its final stage
  while (current_stage != final_stage) {
    # Determine next stage
    possible <- CONVERSION_RATES %>% filter(current_stage == !!current_stage)

    if (nrow(possible) == 0) break

    # If final_stage is reachable from current, go there
    if (final_stage %in% possible$next_stage) {
      next_stage <- final_stage
    } else {
      # Must advance through the pipeline toward final_stage
      advancing <- possible %>%
        filter(next_stage %in% c("Indication", "Offer", "Closed - Won"))
      if (nrow(advancing) == 0) break
      next_stage <- advancing$next_stage[1]
    }

    # Get duration for this transition
    duration_row <- STAGE_DURATION %>%
      filter(from_stage == !!current_stage, to_stage == !!next_stage)

    if (nrow(duration_row) > 0) {
      days <- max(3, round(rnorm(1, duration_row$mean_days, duration_row$sd_days)))
    } else {
      days <- max(3, round(rnorm(1, 25, 10)))
    }

    current_date  <- current_date + days(days)
    current_stage <- next_stage
    order_idx     <- order_idx + 1L

    history <- bind_rows(history, tibble(
      deal_id     = deal_id,
      stage       = next_stage,
      stage_date  = current_date,
      stage_order = order_idx
    ))
  }

  history
}


# ============================================================
# Enrich Dataset
# ============================================================

enrich_pipeline_data <- function(df) {
  cat("Generating stage progression history...\n")

  # Generate full history for each deal
  stage_history <- pmap_dfr(
    list(df$deal_id, df$date_sourced, df$deal_stage),
    generate_stage_history
  )

  cat(sprintf("  Generated %d stage transition records\n", nrow(stage_history)))

  # Compute derived metrics per deal
  deal_metrics <- stage_history %>%
    group_by(deal_id) %>%
    summarise(
      stages_reached     = n(),
      first_stage_date   = min(stage_date),
      last_stage_date    = max(stage_date),
      days_in_pipeline   = as.integer(max(stage_date) - min(stage_date)),
      reached_indication = any(stage == "Indication"),
      reached_offer      = any(stage == "Offer"),
      .groups = "drop"
    )

  # Compute time-in-stage for each transition
  stage_durations <- stage_history %>%
    group_by(deal_id) %>%
    arrange(stage_order) %>%
    mutate(
      days_in_stage = as.integer(lead(stage_date) - stage_date)
    ) %>%
    ungroup()

  # Add quarter and year fields for time-based analysis
  enriched <- df %>%
    left_join(deal_metrics, by = "deal_id") %>%
    mutate(
      sourced_quarter = paste0("Q", quarter(date_sourced), " ", year(date_sourced)),
      sourced_year    = year(date_sourced),
      sourced_month   = floor_date(date_sourced, "month"),
      is_won          = deal_stage == "Closed - Won",
      is_active       = deal_stage %in% c("Reviewed", "Indication", "Offer"),
      is_closed       = deal_stage %in% c("Closed - Won", "Closed - Lost"),
      is_passed       = deal_stage == "Passed",
      deal_outcome    = case_when(
        is_won    ~ "Won",
        is_closed ~ "Lost",
        is_passed ~ "Passed",
        TRUE      ~ "Active"
      ),
      # Revenue band for segmentation
      revenue_band = case_when(
        is.na(revenue_usd)    ~ "Unknown",
        revenue_usd < 20e6    ~ "Under $20M",
        revenue_usd < 50e6    ~ "$20M - $50M",
        revenue_usd < 100e6   ~ "$50M - $100M",
        TRUE                  ~ "$100M+"
      ),
      revenue_band = factor(revenue_band, levels = c(
        "Under $20M", "$20M - $50M", "$50M - $100M", "$100M+", "Unknown"
      )),
      # EBITDA margin where available
      ebitda_margin = if_else(
        !is.na(ebitda_usd) & !is.na(revenue_usd) & revenue_usd > 0,
        round(ebitda_usd / revenue_usd * 100, 1),
        NA_real_
      )
    )

  list(
    deals          = enriched,
    stage_history  = stage_durations,
    deal_metrics   = deal_metrics
  )
}


# ============================================================
# Export Tableau-Ready Files
# ============================================================

export_data <- function(result, output_dir, data_dir) {
  # Main deals table (one row per deal, enriched)
  write_csv(result$deals, file.path(data_dir, "pipeline_deals.csv"))
  cat(sprintf("  Saved: pipeline_deals.csv (%d records)\n", nrow(result$deals)))

  # Stage history table (one row per stage transition)
  write_csv(result$stage_history, file.path(data_dir, "stage_history.csv"))
  cat(sprintf("  Saved: stage_history.csv (%d records)\n", nrow(result$stage_history)))

  # Summary stats for quick reference
  summary_stats <- list(
    total_deals       = nrow(result$deals),
    won               = sum(result$deals$is_won),
    lost              = sum(result$deals$deal_stage == "Closed - Lost"),
    passed            = sum(result$deals$is_passed),
    active            = sum(result$deals$is_active),
    win_rate          = round(mean(result$deals$is_won[result$deals$is_closed]) * 100, 1),
    avg_days_pipeline = round(mean(result$deal_metrics$days_in_pipeline, na.rm = TRUE), 0),
    median_days       = round(median(result$deal_metrics$days_in_pipeline, na.rm = TRUE), 0),
    by_industry       = result$deals %>%
      count(industry, deal_outcome) %>%
      pivot_wider(names_from = deal_outcome, values_from = n, values_fill = 0),
    by_source         = result$deals %>%
      count(source, deal_outcome) %>%
      pivot_wider(names_from = deal_outcome, values_from = n, values_fill = 0)
  )

  jsonlite::write_json(summary_stats, file.path(output_dir, "pipeline_summary.json"),
                       pretty = TRUE, auto_unbox = TRUE)
  cat("  Saved: pipeline_summary.json\n")
}


# ============================================================
# Main
# ============================================================

if (sys.nframe() == 0) {
  project2_dir <- dirname(dirname(rstudioapi::getSourceEditorContext()$path))
  # project2_dir <- "path/to/project-2-deal-pipeline-dashboard"  # manual override

  project1_dir <- file.path(dirname(project2_dir), "project-1-crm-data-quality-audit")

  data_dir   <- file.path(project2_dir, "data")
  output_dir <- file.path(project2_dir, "output")

  cat("=== Extending Project 1 Data for Pipeline Analytics ===\n\n")

  df <- load_project1_data(project1_dir)
  result <- enrich_pipeline_data(df)
  export_data(result, output_dir, data_dir)

  cat("\nDone! Data ready for Tableau import.\n")
}
