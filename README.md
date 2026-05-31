# Information Privacy in the Mobile Ad Ecosystem: A Longitudinal Survey

**Replication repository** for the paper submitted to the *Journal of Information Security and Applications* (2026).

---

## Overview

This repository contains all instrumentation code, analysis scripts, and data-access documentation needed to replicate the three empirical components of the paper:

| Component | Description | Data source |
|---|---|---|
| **Study 1** | Six-wave longitudinal measurement of 2,500 Android apps (2020–2025) | Collected via the instrumentation pipeline in `study1/instrumentation/` |
| **Study 2** | Secondary analysis of existing public privacy-attitude datasets (pooled N ≈ 14,800) | Eurobarometer (GESIS) + Pew Research Center (see `data/study2/DATA_ACCESS.md`) |
| **Study 3** | PET benchmarking against ISO/IEC 29100:2024, NIST PF v1.0, EU AI Act | Benchmarks reproducible via scripts in `study3/` |

---

## Repository structure

```
.
├── study1/
│   ├── instrumentation/      # FlowDroid wrappers, Frida hooks, mitmproxy add-ons
│   └── analysis/             # GEE, ITS, RM-ANOVA scripts (R + Python)
├── study2/
│   ├── harmonization/        # Dataset crosswalk, CFA, pooling scripts (R)
│   └── analysis/             # Multilevel meta-regression, correlation analysis
├── study3/
│   ├── benchmarks/           # PET latency / energy / DP-budget measurement scripts
│   └── analysis/             # PES scoring, ISO/NIST/EU AI Act mapping
├── data/
│   ├── study1/               # App sample list + endpoint catalogue (no raw payloads)
│   └── study2/               # DATA_ACCESS.md — links to original archives
├── docs/
│   ├── CODEBOOK.md           # Variable definitions for all three studies
│   ├── ETHICS.md             # Ethics and data-governance statement
│   └── ENVIRONMENT.md        # Software versions and environment setup
├── requirements.txt          # Python dependencies
├── requirements_r.txt        # R package dependencies
├── LICENSE                   # CC-BY 4.0
└── README.md                 # This file
```

---

## Reproducing the results

### Prerequisites

- Python 3.13+ with packages in `requirements.txt`
- R 4.4+ with packages in `requirements_r.txt`
- Android test devices (Pixel 6 / Galaxy S22, Android 15) **or** Exodus Privacy API access for Study 1 static-analysis results
- Registered accounts at GESIS Data Archive and Pew Research Center (free) for Study 2 data

### Step 1 — Environment setup

```bash
git clone https://github.com/[authors]/mobile-ad-privacy-longitudinal.git
cd mobile-ad-privacy-longitudinal
pip install -r requirements.txt
Rscript -e "install.packages(readLines('requirements_r.txt'), repos='https://cran.r-project.org')"
```

### Step 2 — Study 1: App measurement

```bash
# Run static analysis on the app sample
python study1/instrumentation/run_static_analysis.py --wave W6 --apk-dir /path/to/apks

# Run dynamic analysis (requires connected Android device)
python study1/instrumentation/run_dynamic_analysis.py --wave W6 --device pixel6

# Reproduce Table 4, Table 5, GEE and ITS results
Rscript study1/analysis/study1_main_analysis.R
```

See `study1/instrumentation/README.md` for full device setup instructions.

### Step 3 — Study 2: Secondary survey analysis

```bash
# After downloading datasets per data/study2/DATA_ACCESS.md:
Rscript study2/harmonization/harmonize_datasets.R   # produces data/study2/pooled_harmonized.csv
Rscript study2/analysis/study2_main_analysis.R       # reproduces Table 6, correlations
```

### Step 4 — Study 3: PET benchmarking

```bash
python study3/benchmarks/run_pet_benchmarks.py       # reproduces Table 7 latency/energy
Rscript study3/analysis/pes_scoring.R                # Privacy Efficacy Score computation
```

---

## Ethics and data governance

Neither study component involved new collection of data from human participants:

- **Study 1** instrumented only publicly listed Android applications. No data from app users was collected.
- **Study 2** re-analysed previously collected, fully de-identified survey data from established public archives.

Under 45 CFR 46.104(d)(4) (U.S. Common Rule) and equivalent EU/UK provisions, both components are exempt from ethics-committee review. Full statement: `docs/ETHICS.md`.

---

## Citation

```bibtex
@article{authors2026mobileprivacy,
  title   = {Information Privacy in the Mobile Ad Ecosystem: A Longitudinal Survey},
  author  = {[Author names]},
  journal = {Journal of Information Security and Applications},
  year    = {2026},
  note    = {Under review}
}
```

---

## Licence

Code: [CC-BY 4.0](LICENSE).  
Secondary datasets: governed by their original archive licences (see `data/study2/DATA_ACCESS.md`).
