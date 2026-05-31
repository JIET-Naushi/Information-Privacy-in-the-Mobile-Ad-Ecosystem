# Study 2 — Main Statistical Analysis
# ======================================
# Multilevel meta-regression of privacy concern over time,
# pooled random-effects concern–behavior correlations (RQ3 / H3).
#
# Input:  data/study2/pooled_harmonized.csv
#         (produced by study2/harmonization/harmonize_datasets.R)
# Output: tables/table6.csv, tables/correlations.csv
#
# Rscript study2/analysis/study2_main_analysis.R

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(purrr)
  library(readr)
  library(metafor)    # Random-effects meta-analysis
  library(lme4)       # Multilevel regression
  library(lmerTest)   # p-values for lmer
  library(broom.mixed)
})

# ---------------------------------------------------------------------------
# Load
# ---------------------------------------------------------------------------

POOLED_PATH <- file.path("data", "study2", "pooled_harmonized.csv")
OUTPUT_DIR  <- "tables"
dir.create(OUTPUT_DIR, showWarnings = FALSE)

if (!file.exists(POOLED_PATH)) {
  stop(sprintf(
    "Pooled dataset not found at %s\n",
    "Run study2/harmonization/harmonize_datasets.R first (after downloading data per DATA_ACCESS.md)"
  ))
}

cat("Loading pooled harmonized dataset...\n")
pooled <- read_csv(POOLED_PATH, show_col_types = FALSE)
cat(sprintf("N = %d respondents across %d datasets\n",
            nrow(pooled), n_distinct(pooled$dataset)))

# Recode time_band to numeric year for regression
pooled <- pooled %>%
  mutate(
    year_mid = case_when(
      time_band == "2020-21" ~ 2020.5,
      time_band == "2022-23" ~ 2022.5,
      time_band == "2024-25" ~ 2024.5,
      TRUE ~ as.numeric(NA)
    )
  )

# ---------------------------------------------------------------------------
# 1. Table 6 — Descriptive statistics per time band and construct
# ---------------------------------------------------------------------------

cat("\nComputing Table 6: Descriptive statistics by time band\n")

constructs <- c("iuipc_col", "iuipc_ctl", "iuipc_awa", "mpbs", "pcb", "pcr")

table6 <- pooled %>%
  group_by(time_band) %>%
  summarise(
    n = n(),
    across(all_of(constructs), list(
      M  = ~ round(weighted.mean(., w = weight, na.rm = TRUE), 2),
      SD = ~ round(sqrt(sum(weight * (. - weighted.mean(., w = weight, na.rm = TRUE))^2,
                            na.rm = TRUE) / (sum(weight[!is.na(.)]) - 1)), 2)
    ), .names = "{.col}_{.fn}")
  ) %>%
  arrange(time_band)

print(table6)
write_csv(table6, file.path(OUTPUT_DIR, "table6.csv"))

# ---------------------------------------------------------------------------
# 2. Multilevel meta-regression — Privacy concern trajectory (RQ3)
# ---------------------------------------------------------------------------

cat("\nFitting multilevel meta-regression: IUIPC ~ year\n")

# Aggregate to dataset level for meta-regression
ds_level <- pooled %>%
  group_by(dataset, time_band, year_mid) %>%
  summarise(
    iuipc_mean = weighted.mean(iuipc_composite, w = weight, na.rm = TRUE),
    iuipc_se   = sd(iuipc_composite, na.rm = TRUE) / sqrt(n()),
    n          = n(),
    .groups = "drop"
  ) %>%
  filter(!is.na(year_mid), !is.na(iuipc_mean))

cat(sprintf("Dataset-level observations for meta-regression: %d\n", nrow(ds_level)))

if (nrow(ds_level) >= 3) {
  meta_fit <- rma(
    yi = iuipc_mean,
    sei = iuipc_se,
    mods = ~ year_mid,
    data = ds_level,
    method = "REML"
  )
  cat("\nMeta-regression results (IUIPC ~ year):\n")
  print(summary(meta_fit))
  write_csv(
    tidy(meta_fit, conf.int = TRUE),
    file.path(OUTPUT_DIR, "meta_regression_iuipc.csv")
  )
} else {
  cat("[WARN] Too few datasets for meta-regression; increase dataset pool.\n")
}

# Multilevel model with respondents nested in datasets
mlm_fit <- tryCatch(
  lmer(iuipc_composite ~ year_mid + (1 | dataset),
       data    = pooled,
       weights = weight,
       REML    = TRUE),
  error = function(e) { cat(sprintf("[WARN] MLM failed: %s\n", e$message)); NULL }
)

if (!is.null(mlm_fit)) {
  cat("\nMultilevel model (IUIPC ~ year, random intercept by dataset):\n")
  print(summary(mlm_fit))
  write_csv(tidy(mlm_fit, conf.int = TRUE),
            file.path(OUTPUT_DIR, "mlm_iuipc.csv"))
}

# ---------------------------------------------------------------------------
# 3. Pooled concern–behavior correlations
# ---------------------------------------------------------------------------

cat("\nComputing concern-behavior correlations per time band\n")

# Pearson r between IUIPC composite and MPBS, with bootstrap CI
compute_weighted_r <- function(df, x_col, y_col, weight_col = "weight") {
  complete <- df %>% filter(!is.na(.data[[x_col]]), !is.na(.data[[y_col]]))
  if (nrow(complete) < 10) return(tibble(r = NA, lower = NA, upper = NA, n = 0))

  w  <- complete[[weight_col]]
  x  <- complete[[x_col]]
  y  <- complete[[y_col]]

  # Weighted Pearson correlation
  mx <- sum(w * x) / sum(w)
  my <- sum(w * y) / sum(w)
  cov_xy <- sum(w * (x - mx) * (y - my)) / sum(w)
  sd_x   <- sqrt(sum(w * (x - mx)^2) / sum(w))
  sd_y   <- sqrt(sum(w * (y - my)^2) / sum(w))
  r      <- cov_xy / (sd_x * sd_y)

  # Fisher Z bootstrap CI
  set.seed(42)
  boot_r <- replicate(2000, {
    idx <- sample(nrow(complete), replace = TRUE)
    wb  <- complete[[weight_col]][idx]
    xb  <- x[idx]; yb <- y[idx]
    mxb <- sum(wb * xb) / sum(wb); myb <- sum(wb * yb) / sum(wb)
    cov_b <- sum(wb * (xb - mxb) * (yb - myb)) / sum(wb)
    sdx_b <- sqrt(sum(wb * (xb - mxb)^2) / sum(wb))
    sdy_b <- sqrt(sum(wb * (yb - myb)^2) / sum(wb))
    cov_b / (sdx_b * sdy_b)
  })
  ci <- quantile(boot_r, c(0.025, 0.975), na.rm = TRUE)
  tibble(r = round(r, 3), lower = round(ci[1], 3), upper = round(ci[2], 3), n = nrow(complete))
}

cor_results <- pooled %>%
  group_by(time_band) %>%
  group_map(~ compute_weighted_r(.x, "iuipc_composite", "mpbs"), .keep = TRUE) %>%
  bind_rows(.id = "group") %>%
  mutate(time_band = unique(pooled$time_band)[as.integer(group)]) %>%
  select(time_band, r, lower, upper, n)

cat("\nConcern-behavior correlations (IUIPC vs MPBS):\n")
print(cor_results)
write_csv(cor_results, file.path(OUTPUT_DIR, "concern_behavior_correlations.csv"))

# ---------------------------------------------------------------------------
# 4. Privacy paradox summary
# ---------------------------------------------------------------------------

cat("\nPrivacy paradox check (concern up, behavior flat?)\n")
concern_trend <- pooled %>%
  group_by(time_band) %>%
  summarise(mean_concern  = weighted.mean(iuipc_composite, w = weight, na.rm = TRUE),
            mean_behavior = weighted.mean(mpbs, w = weight, na.rm = TRUE),
            .groups = "drop")
print(concern_trend)

cat("\n=== Study 2 analysis complete ===\n")
cat(sprintf("Output tables written to: %s/\n", OUTPUT_DIR))
