# ============================================================
# Reference Visualizations (ggplot2)
# ============================================================
# Static reference charts for the README and GitHub. The
# interactive dashboard lives in Tableau Public.
#
# Charts:
#   1. Deal funnel (horizontal waterfall)
#   2. Conversion rates by industry (grouped bar)
#   3. Source scorecard (lollipop chart)
#   4. Pipeline volume over time (area + bar combo)
#   5. Deal outcome sunburst (treemap proxy)
#   6. Time-to-close distribution by outcome
# ============================================================

library(tidyverse)
library(patchwork)
library(jsonlite)


# ============================================================
# Color Palette
# ============================================================

NAVY      <- "#1B3A5C"
BLUE      <- "#2E75B6"
GREEN     <- "#2D8B46"
RED       <- "#C0392B"
AMBER     <- "#D4832F"
GRAY      <- "#888888"
TEAL      <- "#1ABC9C"
PURPLE    <- "#8E44AD"
LIGHT_BG  <- "#FAFAFA"

OUTCOME_COLORS <- c(
  "Won"    = GREEN,
  "Lost"   = RED,
  "Passed" = GRAY,
  "Active" = BLUE
)

theme_pipeline <- function() {
  theme_minimal(base_size = 11, base_family = "sans") +
    theme(
      plot.title       = element_text(face = "bold", size = 14, color = NAVY),
      plot.subtitle    = element_text(size = 10, color = GRAY),
      axis.title       = element_text(size = 11),
      panel.background = element_rect(fill = LIGHT_BG, color = NA),
      panel.grid.major = element_line(color = "#CCCCCC", linewidth = 0.3),
      panel.grid.minor = element_blank(),
      legend.position  = "bottom"
    )
}


# ============================================================
# Chart 1: Deal Funnel
# ============================================================

chart_funnel <- function(output_dir) {
  funnel <- read_csv(file.path(output_dir, "funnel_analysis.csv"), show_col_types = FALSE)

  funnel <- funnel %>%
    mutate(
      stage = factor(stage, levels = rev(stage)),
      fill_color = case_when(
        stage == "Closed - Won" ~ GREEN,
        stage == "Offer"        ~ TEAL,
        stage == "Indication"   ~ BLUE,
        TRUE                    ~ NAVY
      )
    )

  p <- ggplot(funnel, aes(x = deals_reached, y = stage, fill = fill_color)) +
    geom_col(width = 0.6, show.legend = FALSE) +
    geom_text(aes(label = sprintf("%d (%.0f%%)", deals_reached, pct_of_total)),
              hjust = -0.05, fontface = "bold", size = 3.5, color = NAVY) +
    scale_fill_identity() +
    coord_cartesian(xlim = c(0, max(funnel$deals_reached) * 1.25)) +
    labs(
      title    = "Deal Pipeline Funnel",
      subtitle = "Deals reaching each stage (% of total sourced)",
      x = "Number of Deals", y = NULL
    ) +
    theme_pipeline()

  ggsave(file.path(output_dir, "01_deal_funnel.png"),
         plot = p, width = 10, height = 5, dpi = 150)
  cat("  Saved: 01_deal_funnel.png\n")
}


# ============================================================
# Chart 2: Conversion by Industry
# ============================================================

chart_conversion_by_industry <- function(output_dir) {
  conv <- read_csv(file.path(output_dir, "conversion_by_industry.csv"), show_col_types = FALSE)

  conv_long <- conv %>%
    select(industry, won, lost, passed) %>%
    pivot_longer(-industry, names_to = "outcome", values_to = "count") %>%
    mutate(outcome = str_to_title(outcome))

  p <- ggplot(conv_long, aes(x = industry, y = count, fill = outcome)) +
    geom_col(position = "dodge", width = 0.7, alpha = 0.85) +
    geom_text(
      data = conv,
      aes(x = industry, y = won + lost + passed + 3,
          label = sprintf("Win: %.0f%%", win_rate)),
      inherit.aes = FALSE, fontface = "bold", size = 3.2, color = NAVY
    ) +
    scale_fill_manual(values = c(Won = GREEN, Lost = RED, Passed = GRAY)) +
    labs(
      title    = "Deal Outcomes by Industry",
      subtitle = "Win rate shown above each group",
      x = NULL, y = "Number of Deals", fill = NULL
    ) +
    theme_pipeline()

  ggsave(file.path(output_dir, "02_conversion_by_industry.png"),
         plot = p, width = 10, height = 6, dpi = 150)
  cat("  Saved: 02_conversion_by_industry.png\n")
}


# ============================================================
# Chart 3: Source Scorecard (Lollipop)
# ============================================================

chart_source_scorecard <- function(output_dir) {
  src <- read_csv(file.path(output_dir, "source_scorecard.csv"), show_col_types = FALSE)

  src <- src %>%
    mutate(source = fct_reorder(source, composite))

  p <- ggplot(src, aes(x = composite, y = source)) +
    geom_segment(aes(xend = 0, yend = source), color = BLUE, linewidth = 1.2) +
    geom_point(size = 6, color = BLUE) +
    geom_text(aes(label = sprintf("%.0f", composite)),
              color = "white", size = 2.8, fontface = "bold") +
    geom_text(aes(label = sprintf("  %d deals | %.0f%% win rate", total_deals, win_rate)),
              hjust = -0.05, size = 3, color = GRAY) +
    coord_cartesian(xlim = c(0, max(src$composite) * 1.5)) +
    labs(
      title    = "Deal Source Scorecard",
      subtitle = "Composite score: 40% win rate + 30% volume + 30% deal value",
      x = "Composite Score", y = NULL
    ) +
    theme_pipeline()

  ggsave(file.path(output_dir, "03_source_scorecard.png"),
         plot = p, width = 10, height = 5, dpi = 150)
  cat("  Saved: 03_source_scorecard.png\n")
}


# ============================================================
# Chart 4: Pipeline Volume Over Time
# ============================================================

chart_pipeline_trends <- function(output_dir) {
  trends <- read_csv(file.path(output_dir, "quarterly_trends.csv"), show_col_types = FALSE) %>%
    mutate(sourced_quarter = fct_inorder(sourced_quarter))

  p1 <- ggplot(trends, aes(x = sourced_quarter, y = deals_sourced)) +
    geom_col(fill = BLUE, alpha = 0.7, width = 0.6) +
    geom_text(aes(label = deals_sourced), vjust = -0.5, size = 3, fontface = "bold", color = NAVY) +
    labs(title = "Deals Sourced per Quarter", x = NULL, y = "Deals") +
    theme_pipeline() +
    theme(axis.text.x = element_text(angle = 45, hjust = 1))

  p2 <- ggplot(trends, aes(x = sourced_quarter, y = total_value, group = 1)) +
    geom_area(fill = TEAL, alpha = 0.3) +
    geom_line(color = TEAL, linewidth = 1.2) +
    geom_point(color = TEAL, size = 3) +
    labs(title = "Total Pipeline Value ($M)", x = NULL, y = "$M") +
    theme_pipeline() +
    theme(axis.text.x = element_text(angle = 45, hjust = 1))

  combined <- p1 / p2 +
    plot_annotation(
      title = "Pipeline Trends Over Time",
      theme = theme(plot.title = element_text(face = "bold", size = 14, color = NAVY, hjust = 0.5))
    )

  ggsave(file.path(output_dir, "04_pipeline_trends.png"),
         plot = combined, width = 12, height = 8, dpi = 150)
  cat("  Saved: 04_pipeline_trends.png\n")
}


# ============================================================
# Chart 5: Deal Outcome Distribution (Treemap-style)
# ============================================================

chart_outcome_distribution <- function(deals, output_dir) {
  outcome_counts <- deals %>%
    count(deal_outcome) %>%
    mutate(
      pct   = round(n / sum(n) * 100, 1),
      label = sprintf("%s\n%d deals (%.0f%%)", deal_outcome, n, pct),
      x     = c(1, 3, 1, 3),
      y     = c(2, 2, 1, 1)
    )

  p <- ggplot(outcome_counts, aes(x = x, y = y)) +
    geom_tile(aes(fill = deal_outcome), width = 1.8, height = 0.85, alpha = 0.8,
              color = "white", linewidth = 2, show.legend = FALSE) +
    geom_text(aes(label = label), color = "white", fontface = "bold", size = 4.5) +
    scale_fill_manual(values = OUTCOME_COLORS) +
    coord_cartesian(xlim = c(-0.2, 4.2), ylim = c(0.3, 2.8)) +
    labs(title = "Deal Outcome Distribution") +
    theme_void() +
    theme(plot.title = element_text(face = "bold", size = 14, color = NAVY, hjust = 0.5))

  ggsave(file.path(output_dir, "05_outcome_distribution.png"),
         plot = p, width = 10, height = 5, dpi = 150)
  cat("  Saved: 05_outcome_distribution.png\n")
}


# ============================================================
# Chart 6: Time-to-Close Distribution
# ============================================================

chart_time_to_close <- function(deals, output_dir) {
  closed <- deals %>%
    filter(is_closed) %>%
    mutate(outcome = if_else(is_won, "Won", "Lost"))

  medians <- closed %>%
    group_by(outcome) %>%
    summarise(med = median(days_in_pipeline, na.rm = TRUE), .groups = "drop")

  p <- ggplot(closed, aes(x = days_in_pipeline, fill = outcome)) +
    geom_histogram(bins = 20, alpha = 0.7, color = "white", linewidth = 0.3,
                   position = "identity") +
    geom_vline(data = medians, aes(xintercept = med, color = outcome),
               linetype = "dashed", linewidth = 1, show.legend = FALSE) +
    scale_fill_manual(values = c(Won = GREEN, Lost = RED)) +
    scale_color_manual(values = c(Won = GREEN, Lost = RED)) +
    facet_wrap(~ outcome, ncol = 2) +
    labs(
      title    = "Time-to-Close Distribution",
      subtitle = "Dashed line = median days in pipeline",
      x = "Days in Pipeline", y = "Number of Deals", fill = NULL
    ) +
    theme_pipeline() +
    theme(strip.text = element_text(face = "bold", size = 12))

  ggsave(file.path(output_dir, "06_time_to_close.png"),
         plot = p, width = 12, height = 5, dpi = 150)
  cat("  Saved: 06_time_to_close.png\n")
}


# ============================================================
# Main
# ============================================================

if (sys.nframe() == 0) {
  project_dir <- dirname(dirname(rstudioapi::getSourceEditorContext()$path))
  # project_dir <- "path/to/project-2-deal-pipeline-dashboard"  # manual override

  data_dir   <- file.path(project_dir, "data")
  output_dir <- file.path(project_dir, "output")

  cat("=== Generating Reference Visualizations ===\n\n")

  deals <- read_csv(file.path(data_dir, "pipeline_deals.csv"), show_col_types = FALSE)

  chart_funnel(output_dir)
  chart_conversion_by_industry(output_dir)
  chart_source_scorecard(output_dir)
  chart_pipeline_trends(output_dir)
  chart_outcome_distribution(deals, output_dir)
  chart_time_to_close(deals, output_dir)

  cat("\nAll reference charts saved to output/\n")
}
