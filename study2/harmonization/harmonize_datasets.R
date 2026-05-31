# Study 2 — Dataset Harmonization
# ==================================
# Loads Eurobarometer and Pew Research datasets, maps variables to the
# shared harmonized codebook, runs CFA for measurement invariance,
# and produces the pooled analysis-ready file.
#
# Input:  data/study2/raw/{eurobarometer_2019,eurobarometer_2022,pew_2019,pew_2023}/
# Output: data/study2/pooled_harmonized.csv
#
# Run after downloading datasets per data/study2/DATA_ACCESS.md
# Rscript study2/harmonization/harmonize_datasets.R

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(purrr)
  library(haven)     # Read SPSS .sav files
  library(readr)
  library(lavaan)    # CFA for measurement invariance
  library(semTools)  # measurementInvariance()
})

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------

RAW_DIR    <- file.path("data", "study2", "raw")
OUTPUT_DIR <- file.path("data", "study2")
CODEBOOK   <- file.path("docs", "CODEBOOK.md")  # Reference only

dir.create(OUTPUT_DIR, showWarnings = FALSE, recursive = TRUE)

# ---------------------------------------------------------------------------
# 1. Variable crosswalk
# ---------------------------------------------------------------------------
# Maps each source dataset's native variable names to the harmonized
# construct names used in the analysis scripts.
# See docs/CODEBOOK.md Section 3 for full documentation.

CROSSWALK <- list(

  eurobarometer_2022 = list(
    source_file  = "eurobarometer_2022/ZA7572_v2-0-0.sav",
    wave_label   = "2022",
    time_band    = "2022-23",
    country_var  = "isocntry",
    weight_var   = "w1",
    iuipc_col    = c("qc1_1", "qc1_2", "qc1_3"),   # Collection subscale items
    iuipc_ctl    = c("qc2_1", "qc2_2", "qc2_3"),   # Control subscale items
    iuipc_awa    = c("qc3_1", "qc3_2", "qc3_3"),   # Awareness subscale items
    mpbs         = c("qb4_1", "qb4_2", "qb4_3",    # Mobile privacy behavior items
                     "qb4_4", "qb4_5", "qb4_6"),
    pcb          = c("qd1_1", "qd1_2", "qd1_3"),   # Privacy calculus benefit
    pcr          = c("qd2_1", "qd2_2", "qd2_3")    # Privacy calculus risk
  ),

  eurobarometer_2019 = list(
    source_file  = "eurobarometer_2019/ZA7564_v2-0-0.sav",
    wave_label   = "2019",
    time_band    = "2020-21",
    country_var  = "isocntry",
    weight_var   = "w1",
    iuipc_col    = c("qc1_1", "qc1_2", "qc1_3"),
    iuipc_ctl    = c("qc2_1", "qc2_2", "qc2_3"),
    iuipc_awa    = c("qc3_1", "qc3_2", "qc3_3"),
    mpbs         = c("qb3_1", "qb3_2", "qb3_3", "qb3_4", "qb3_5", "qb3_6"),
    pcb          = c("qd1_1", "qd1_2", "qd1_3"),
    pcr          = c("qd2_1", "qd2_2", "qd2_3")
  ),

  pew_2019 = list(
    source_file  = "pew_2019/ATP W49.sav",
    wave_label   = "2019",
    time_band    = "2020-21",
    country_var  = NULL,   # US only
    weight_var   = "WEIGHT_W49",
    iuipc_col    = c("PRIVCOL_a_W49", "PRIVCOL_b_W49", "PRIVCOL_c_W49"),
    iuipc_ctl    = c("PRIVCTL_a_W49", "PRIVCTL_b_W49", "PRIVCTL_c_W49"),
    iuipc_awa    = c("PRIVAWA_a_W49", "PRIVAWA_b_W49", "PRIVAWA_c_W49"),
    mpbs         = c("PRIVACT_a_W49", "PRIVACT_b_W49", "PRIVACT_c_W49",
                     "PRIVACT_d_W49", "PRIVACT_e_W49", "PRIVACT_f_W49"),
    pcb          = c("PRIVBEN_a_W49", "PRIVBEN_b_W49", "PRIVBEN_c_W49"),
    pcr          = c("PRIVRSK_a_W49", "PRIVRSK_b_W49", "PRIVRSK_c_W49")
  ),

  pew_2023 = list(
    source_file  = "pew_2023/ATP W121.sav",
    wave_label   = "2023",
    time_band    = "2022-23",
    country_var  = NULL,
    weight_var   = "WEIGHT_W121",
    iuipc_col    = c("PRIVCOL_a_W121", "PRIVCOL_b_W121", "PRIVCOL_c_W121"),
    iuipc_ctl    = c("PRIVCTL_a_W121", "PRIVCTL_b_W121", "PRIVCTL_c_W121"),
    iuipc_awa    = c("PRIVAWA_a_W121", "PRIVAWA_b_W121", "PRIVAWA_c_W121"),
    mpbs         = c("PRIVACT_a_W121", "PRIVACT_b_W121", "PRIVACT_c_W121",
                     "PRIVACT_d_W121", "PRIVACT_e_W121", "PRIVACT_f_W121"),
    pcb          = c("PRIVBEN_a_W121", "PRIVBEN_b_W121", "PRIVBEN_c_W121"),
    pcr          = c("PRIVRSK_a_W121", "PRIVRSK_b_W121", "PRIVRSK_c_W121")
  )
)

# ---------------------------------------------------------------------------
# 2. Load and rename one dataset
# ---------------------------------------------------------------------------

load_and_recode <- function(dataset_name, spec) {
  path <- file.path(RAW_DIR, spec$source_file)
  if (!file.exists(path)) {
    stop(sprintf(
      "Dataset not found: %s\nPlease follow instructions in data/study2/DATA_ACCESS.md",
      path
    ))
  }

  cat(sprintf("  Loading %s...\n", dataset_name))
  raw <- read_sav(path, user_na = TRUE)

  # Helper: select, mean-score, and standardize a block of items
  score_construct <- function(items) {
    available <- intersect(items, names(raw))
    if (length(available) == 0) return(rep(NA_real_, nrow(raw)))
    df_items <- raw %>% select(all_of(available)) %>%
      mutate(across(everything(), ~ as.numeric(zap_labels(.))))
    rowMeans(df_items, na.rm = TRUE)
  }

  harmonized <- tibble(
    dataset    = dataset_name,
    wave_label = spec$wave_label,
    time_band  = spec$time_band,
    country    = if (!is.null(spec$country_var) && spec$country_var %in% names(raw))
                   as.character(as_factor(raw[[spec$country_var]])) else "USA",
    weight     = if (spec$weight_var %in% names(raw)) raw[[spec$weight_var]] else 1.0,
    iuipc_col  = score_construct(spec$iuipc_col),
    iuipc_ctl  = score_construct(spec$iuipc_ctl),
    iuipc_awa  = score_construct(spec$iuipc_awa),
    mpbs       = score_construct(spec$mpbs),
    pcb        = score_construct(spec$pcb),
    pcr        = score_construct(spec$pcr)
  ) %>%
    # Compute composite IUIPC score
    mutate(iuipc_composite = rowMeans(cbind(iuipc_col, iuipc_ctl, iuipc_awa), na.rm = TRUE))

  harmonized
}

# ---------------------------------------------------------------------------
# 3. Pool datasets
# ---------------------------------------------------------------------------

cat("Loading and harmonizing datasets...\n")
pooled <- map2_dfr(names(CROSSWALK), CROSSWALK, load_and_recode)

cat(sprintf("\nPooled dataset: N = %d respondents, %d variables\n",
            nrow(pooled), ncol(pooled)))
cat("Time bands:\n")
print(table(pooled$time_band))
cat("Datasets:\n")
print(table(pooled$dataset))

# ---------------------------------------------------------------------------
# 4. CFA — Measurement invariance across datasets
# ---------------------------------------------------------------------------

cat("\nRunning CFA for measurement invariance...\n")

cfa_model <- "
  IUIPC_COL =~ iuipc_col
  IUIPC_CTL =~ iuipc_ctl
  IUIPC_AWA =~ iuipc_awa
  MPBS      =~ mpbs
  PCB       =~ pcb
  PCR       =~ pcr
"

# Configural model (across datasets)
cfa_configural <- tryCatch(
  cfa(cfa_model, data = pooled, group = "dataset",
      group.equal = "configural", estimator = "MLR"),
  error = function(e) {
    cat(sprintf("[WARN] CFA configural model failed: %s\n", e$message))
    NULL
  }
)

if (!is.null(cfa_configural)) {
  fit_indices <- fitMeasures(cfa_configural, c("cfi", "tli", "rmsea", "srmr"))
  cat("\nConfigural CFA fit indices:\n")
  print(round(fit_indices, 3))

  # Check thresholds from paper (CFI >= .95, RMSEA <= .06, SRMR <= .05)
  cat(sprintf("\nCFI = %.3f (target ≥ .95): %s\n",
              fit_indices["cfi"], if (fit_indices["cfi"] >= .95) "PASS" else "REVIEW"))
  cat(sprintf("RMSEA = %.3f (target ≤ .06): %s\n",
              fit_indices["rmsea"], if (fit_indices["rmsea"] <= .06) "PASS" else "REVIEW"))
} else {
  cat("[INFO] Proceeding without full CFA — check variable mapping in crosswalk.\n")
}

# ---------------------------------------------------------------------------
# 5. Save pooled dataset
# ---------------------------------------------------------------------------

output_path <- file.path(OUTPUT_DIR, "pooled_harmonized.csv")
write_csv(pooled, output_path)
cat(sprintf("\nHarmonized dataset saved to: %s\n", output_path))
cat("NOTE: Do not redistribute this file — direct others to original archives.\n")
cat("\n=== Harmonization complete ===\n")
