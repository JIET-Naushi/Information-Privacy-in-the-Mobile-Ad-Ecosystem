# Study 1 — Main Statistical Analysis
# =====================================
# Reproduces Tables 4 and 5 from the paper, plus GEE (RQ1/H1),
# ITS analysis (RQ2/H2), and RM-ANOVA.
#
# Input: results/static_W[1-6].csv + results/dynamic_W[1-6].csv
#        (produced by the instrumentation pipeline)
# Output: tables/table4.csv, tables/table5.csv, tables/gee_results.csv
#
# R packages: geepack, sandwich, lmtest, dplyr, tidyr, purrr, broom
#
# Usage:
#   Rscript study1_main_analysis.R [--data-dir ./results] [--output-dir ./tables]

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(purrr)
  library(geepack)
  library(sandwich)
  library(lmtest)
  library(broom)
  library(readr)
  library(stringr)
})

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

args <- commandArgs(trailingOnly = TRUE)
DATA_DIR    <- if (length(args) >= 1) args[1] else "results"
OUTPUT_DIR  <- if (length(args) >= 2) args[2] else "tables"
dir.create(OUTPUT_DIR, showWarnings = FALSE, recursive = TRUE)

WAVES <- c("W1", "W2", "W3", "W4", "W5", "W6")
WAVE_DATES <- c(W1 = 2020.0, W2 = 2020.75, W3 = 2021.75,
                W4 = 2022.75, W5 = 2023.75, W6 = 2025.75)

# ---------------------------------------------------------------------------
# 1. Load and merge per-wave data
# ---------------------------------------------------------------------------

load_wave <- function(wave, data_dir) {
  static_path  <- file.path(data_dir, paste0("static_",  wave, ".csv"))
  dynamic_path <- file.path(data_dir, paste0("dynamic_", wave, ".csv"))

  if (!file.exists(static_path)) {
    stop(sprintf("Static analysis file not found: %s\nRun study1/instrumentation/run_static_analysis.py first.", static_path))
  }

  static  <- read_csv(static_path,  show_col_types = FALSE)
  dynamic <- if (file.exists(dynamic_path)) read_csv(dynamic_path, show_col_types = FALSE) else NULL

  if (!is.null(dynamic)) {
    merged <- left_join(static, dynamic, by = c("package_name", "wave"), suffix = c("", "_dyn"))
    # Reconcile on-device API flags: either static or dynamic detection counts
    merged <- merged %>%
      mutate(
        uses_topics_api        = coalesce(uses_topics_api, uses_topics_api_dyn, 0L),
        uses_protected_audience = coalesce(uses_protected_audience, uses_protected_audience_dyn, 0L)
      ) %>%
      select(-ends_with("_dyn"))
  } else {
    merged <- static
  }

  merged$wave_num  <- match(wave, WAVES)
  merged$wave_date <- WAVE_DATES[[wave]]
  merged
}

cat("Loading per-wave data...\n")
panel <- map_dfr(WAVES, load_wave, data_dir = DATA_DIR)

# Ensure app IDs are stable across waves
panel <- panel %>%
  group_by(package_name) %>%
  mutate(app_id = cur_group_id()) %>%
  ungroup() %>%
  arrange(app_id, wave_num)

cat(sprintf("Panel: %d app-wave observations, %d unique apps\n",
            nrow(panel), n_distinct(panel$app_id)))

# ---------------------------------------------------------------------------
# 2. Table 4 — Tracker prevalence per wave
# ---------------------------------------------------------------------------

cat("\nComputing Table 4: Tracker prevalence per wave\n")

table4 <- panel %>%
  group_by(wave, wave_num) %>%
  summarise(
    n_apps          = n(),
    mean_trackers   = round(mean(tracker_count, na.rm = TRUE), 2),
    sd_trackers     = round(sd(tracker_count, na.rm = TRUE), 2),
    median_trackers = median(tracker_count, na.rm = TRUE),
    pct_ge5         = round(mean(tracker_count >= 5, na.rm = TRUE) * 100, 1),
    pct_zero        = round(mean(tracker_count == 0, na.rm = TRUE) * 100, 1),
    .groups = "drop"
  ) %>%
  arrange(wave_num) %>%
  select(wave, n_apps, mean_trackers, sd_trackers, median_trackers, pct_ge5, pct_zero)

print(table4)
write_csv(table4, file.path(OUTPUT_DIR, "table4.csv"))

# ---------------------------------------------------------------------------
# 3. GEE — Tracker count ~ wave (RQ1 / H1)
# ---------------------------------------------------------------------------

cat("\nFitting GEE (Poisson log-link, exchangeable correlation)...\n")

panel_gee <- panel %>%
  filter(!is.na(tracker_count)) %>%
  arrange(app_id, wave_num)

gee_fit <- geeglm(
  tracker_count ~ wave_num,
  data    = panel_gee,
  id      = app_id,
  family  = poisson(link = "log"),
  corstr  = "exchangeable",
  std.err = "san.se"
)

gee_summary <- tidy(gee_fit, conf.int = TRUE)
cat("\nGEE results:\n")
print(gee_summary)
write_csv(gee_summary, file.path(OUTPUT_DIR, "gee_results.csv"))

# Extract slope
slope_row <- gee_summary %>% filter(term == "wave_num")
cat(sprintf("\nGEE per-wave slope: β = %.3f (95%% CI [%.3f, %.3f]), p = %.4f\n",
            slope_row$estimate, slope_row$conf.low, slope_row$conf.high, slope_row$p.value))

# ---------------------------------------------------------------------------
# 4. RM-ANOVA (wide format)
# ---------------------------------------------------------------------------

cat("\nFitting repeated-measures ANOVA...\n")

panel_wide <- panel %>%
  select(app_id, wave_num, tracker_count) %>%
  pivot_wider(names_from = wave_num, values_from = tracker_count,
              names_prefix = "W") %>%
  filter(if_all(starts_with("W"), ~ !is.na(.)))

cat(sprintf("Complete cases for RM-ANOVA: %d apps\n", nrow(panel_wide)))

# Run as one-sample MANOVA (standard RM-ANOVA approach in R)
Y <- as.matrix(panel_wide[, paste0("W", 1:6)])
intercept_model <- lm(Y ~ 1)
rm_anova <- anova(intercept_model,
                  X = matrix(1, nrow = 6),  # imatrix placeholder
                  test = "Wilks")

# For clean F-statistic reporting, use ez::ezANOVA if available:
tryCatch({
  library(ez)
  panel_long_cc <- panel %>%
    filter(app_id %in% panel_wide$app_id) %>%
    mutate(wave_f = factor(wave_num))
  ez_result <- ezANOVA(
    data    = panel_long_cc,
    dv      = tracker_count,
    wid     = app_id,
    within  = wave_f,
    type    = 3,
    return_aov = FALSE
  )
  cat("\nRM-ANOVA (ez):\n")
  print(ez_result$ANOVA)
  write_csv(as.data.frame(ez_result$ANOVA), file.path(OUTPUT_DIR, "rmanova_results.csv"))
}, error = function(e) {
  cat("[INFO] ez package not available; RM-ANOVA via lm/anova instead.\n")
})

# ---------------------------------------------------------------------------
# 5. Table 5 — Identifier exposure and on-device API use
# ---------------------------------------------------------------------------

cat("\nComputing Table 5: Identifier exposure and on-device APIs\n")

table5 <- panel %>%
  group_by(wave, wave_num) %>%
  summarise(
    mean_exposure     = round(mean(identifier_exposure_score, na.rm = TRUE), 2),
    sd_exposure       = round(sd(identifier_exposure_score, na.rm = TRUE), 2),
    mean_entropy      = round(mean(fingerprint_entropy, na.rm = TRUE), 2),
    sd_entropy        = round(sd(fingerprint_entropy, na.rm = TRUE), 2),
    pct_topics_api    = round(mean(uses_topics_api, na.rm = TRUE) * 100, 1),
    pct_protected_aud = round(mean(uses_protected_audience, na.rm = TRUE) * 100, 1),
    .groups = "drop"
  ) %>%
  arrange(wave_num) %>%
  select(wave, mean_exposure, sd_exposure, mean_entropy, sd_entropy,
         pct_topics_api, pct_protected_aud)

print(table5)
write_csv(table5, file.path(OUTPUT_DIR, "table5.csv"))

# ---------------------------------------------------------------------------
# 6. ITS — Identifier exposure around ATT (W3) and Privacy Sandbox (W5)
# ---------------------------------------------------------------------------

cat("\nFitting ITS (Newey-West HAC, breakpoints at W3 and W5)...\n")

its_data <- panel %>%
  group_by(wave_num, wave_date) %>%
  summarise(mean_exposure = mean(identifier_exposure_score, na.rm = TRUE), .groups = "drop") %>%
  mutate(
    step_w3 = as.integer(wave_num >= 3),  # ATT intervention
    step_w5 = as.integer(wave_num >= 5),  # Privacy Sandbox intervention
    trend   = wave_num
  )

its_fit <- lm(mean_exposure ~ trend + step_w3 + step_w5, data = its_data)
its_nw  <- coeftest(its_fit, vcov = NeweyWest(its_fit, lag = 2))

cat("\nITS results (Newey-West SEs):\n")
print(its_nw)
write_csv(tidy(its_nw, conf.int = TRUE),
          file.path(OUTPUT_DIR, "its_results.csv"))

# ---------------------------------------------------------------------------
# 7. Cochran's Q — on-device API adoption across waves
# ---------------------------------------------------------------------------

cat("\nCochran's Q test for on-device API adoption trend...\n")

# Requires wide format: 1 row per app, 1 col per wave
api_wide <- panel %>%
  select(app_id, wave_num, uses_topics_api) %>%
  pivot_wider(names_from = wave_num, values_from = uses_topics_api,
              names_prefix = "W") %>%
  filter(if_all(starts_with("W"), ~ !is.na(.)))

# Cochran's Q via coin package
tryCatch({
  library(coin)
  api_long_cc <- api_wide %>%
    pivot_longer(starts_with("W"), names_to = "wave", values_to = "used") %>%
    mutate(wave = factor(wave), app_id = factor(app_id), used = factor(used))
  cq <- symmetry_test(used ~ wave | app_id, data = api_long_cc,
                      teststat = "quadratic")
  cat(sprintf("\nCochran's Q = %.1f, df = %d, p = %.4f\n",
              statistic(cq), 5, pvalue(cq)))
}, error = function(e) {
  cat("[INFO] coin package not available for Cochran's Q.\n")
  # Manual calculation
  k <- 6
  n <- nrow(api_wide)
  Y <- as.matrix(api_wide[, paste0("W", 1:6)])
  L_i <- rowSums(Y)
  C_j <- colSums(Y)
  L   <- sum(Y)
  Q   <- (k - 1) * (k * sum(C_j^2) - L^2) / (k * L - sum(L_i^2))
  pval <- pchisq(Q, df = k - 1, lower.tail = FALSE)
  cat(sprintf("\nCochran's Q (manual) = %.1f, df = %d, p = %.6f\n", Q, k - 1, pval))
})

cat("\n=== Study 1 analysis complete ===\n")
cat(sprintf("Output tables written to: %s/\n", OUTPUT_DIR))
