# Study 2 — Data Access Instructions

The secondary survey datasets used in this study are publicly available from established data archives.
**This repository does not redistribute the microdata.** Download each dataset directly from its source.

---

## Dataset 1 — Eurobarometer Special Survey on Data Protection (EB97.1, 2022)

**GESIS Study Number:** ZA7572  
**Title:** Special Eurobarometer 532 — Data Protection  
**Archive:** GESIS Data Archive, Cologne  
**Access:** Free with registration (academic or personal)  
**URL:** https://search.gesis.org/research_data/ZA7572  
**Format:** SPSS (.sav) and Stata (.dta) available  
**Licence:** GESIS open access for non-commercial research  

**Variables used in this study:**
- `v7` — Trust in institutions to protect personal data (5-point Likert)
- `v8` — Awareness of data protection rights
- `v10a–v10f` — Behavioral items (privacy-protective actions)
- `v12` — Concern about online profiling

**Download steps:**
1. Register at https://login.gesis.org
2. Search for ZA7572 or navigate to the URL above
3. Download SPSS format to `data/study2/raw/eurobarometer_2022/`

---

## Dataset 2 — Eurobarometer Special Survey on Data Protection (EB91.2, 2019)

**GESIS Study Number:** ZA7564  
**Title:** Special Eurobarometer 487a — Data Protection  
**Archive:** GESIS Data Archive, Cologne  
**URL:** https://search.gesis.org/research_data/ZA7564  
**Access:** Free with registration  

**Download to:** `data/study2/raw/eurobarometer_2019/`

---

## Dataset 3 — Pew Research Center: Americans and Privacy (2019)

**Title:** American Trends Panel Wave 49 — Privacy and Surveillance  
**URL:** https://www.pewresearch.org/internet/dataset/american-trends-panel-wave-49/  
**Access:** Free with Pew account registration  
**Format:** CSV + codebook PDF  

**Variables used:**
- `PRIVTRUST_*` — Trust in companies to handle data responsibly
- `PRIVACT_*` — Privacy-protective behaviors taken in past 12 months
- `PRIVCONCERN` — Overall privacy concern index

**Download to:** `data/study2/raw/pew_2019/`

---

## Dataset 4 — Pew Research Center: Americans and Privacy (2023)

**Title:** American Trends Panel Wave 121 — Privacy, Surveillance and Reputation  
**URL:** https://www.pewresearch.org/internet/dataset/american-trends-panel-wave-121/  
**Access:** Free with Pew account registration  

**Download to:** `data/study2/raw/pew_2023/`

---

## Dataset 5 & 6 — Additional datasets (supplementary waves)

See Table S1 in the paper's online supplement for the two additional national datasets
(UK ICO Consumer Tracking 2021; Japan MIC Privacy Survey 2022) and their access URLs.
These are used only in the robustness / sensitivity checks reported in Supplementary Table S3.

---

## After downloading

Once all files are in place, run the harmonization pipeline:

```bash
Rscript study2/harmonization/harmonize_datasets.R
```

This script will:
1. Load each dataset from `data/study2/raw/`
2. Map variables to the harmonized codebook (`docs/CODEBOOK.md`, Section 3)
3. Run confirmatory factor analysis (CFA) for measurement invariance
4. Produce `data/study2/pooled_harmonized.csv` — the input to all Study 2 analyses

The harmonized file contains **no direct identifiers** and is safe to retain locally.
It should not be publicly redistributed; direct others to the original archives.

---

## Licence reminder

Each dataset is governed by its originating archive's licence. Summary:

| Dataset | Licence | Commercial use? |
|---|---|---|
| GESIS Eurobarometer | GESIS Data Use Agreement | Non-commercial only |
| Pew Research | Pew Data Use Agreement | Non-commercial only |

By downloading these datasets you agree to the respective licence terms.
This repository's CC-BY 4.0 licence covers **code only**, not the underlying data.
