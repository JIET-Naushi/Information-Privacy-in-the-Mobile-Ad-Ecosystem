# Codebook — All Variables

## Section 1: Study 1 — Android App Measurement

### App-level identifiers

| Variable | Type | Description |
|---|---|---|
| `package_name` | string | Android app package name (e.g. `com.example.app`) |
| `app_id` | integer | Internal numeric ID assigned during sampling |
| `wave` | string | Measurement wave: W1–W6 |
| `wave_num` | integer | Wave index 1–6 |
| `wave_date` | float | Decimal year of wave (e.g. W1 = 2020.0) |
| `category` | string | Google Play Store category |
| `stratum` | string | Popularity stratum: top / middle / long-tail |
| `available_{wave}` | 0/1 | Whether app was still listed in this wave |

### Outcome variables (Study 1)

| Variable | Type | Range | Description |
|---|---|---|---|
| `tracker_count` | integer | 0–∞ | Number of distinct A&A SDKs detected (static + dynamic) |
| `identifier_exposure_score` | float | 0–10 | Weighted sum of stable identifier categories exposed |
| `fingerprint_entropy` | float | bits | Bits of identifying information per device session |
| `uses_topics_api` | 0/1 | — | App invokes Topics API (Privacy Sandbox) |
| `uses_protected_audience` | 0/1 | — | App invokes Protected Audience / Custom Audience API |
| `tracker_names` | string | — | Pipe-separated list of detected tracker SDK names |
| `source` | string | — | Data source: `mobsf`, `exodus_only`, `exodus_fallback` |

### Identifier-exposure score weights (Section 7.2.4)

| Permission / Signal | Weight |
|---|---|
| `android.permission.READ_PHONE_STATE` (IMEI) | 2.0 |
| `com.google.android.gms.permission.AD_ID` (GAID) | 2.0 |
| `android.permission.READ_CONTACTS` | 1.5 |
| `android.permission.ACCESS_FINE_LOCATION` | 1.5 |
| `android.permission.GET_ACCOUNTS` | 1.0 |
| `android.permission.ACCESS_COARSE_LOCATION` | 1.0 |
| `android.permission.READ_CALL_LOG` | 2.0 |
| `android.permission.RECORD_AUDIO` | 0.5 |
| `android.permission.CAMERA` | 0.5 |
| **Maximum score** | **10.0** |

---

## Section 2: Study 3 — PET Benchmark Variables

| Variable | Type | Description |
|---|---|---|
| `pet_name` | string | Name of the Privacy-Enhancing Technology |
| `run` | integer | Benchmark run index |
| `latency_ms` | float | End-to-end operation latency in milliseconds |
| `energy_mj` | float | Estimated energy consumption in millijoules |
| `comm_cost_kb` | float | Data transmitted per operation in kilobytes |
| `epsilon` | float or null | Differential privacy budget ε (null if not applicable) |
| `adversarial_robustness` | float | 0.0–1.0; proportion of adversarial inputs resisted |

### PET ε values and sources

| PET | ε | Source |
|---|---|---|
| Differential Privacy (RAPPOR) | 1.0 | Standard; Erlingsson et al. (2014) |
| Federated Learning + DP-SGD | 4.0 | Typical production; Abadi et al. (2016) |
| Privacy Sandbox (Topics API) | 14.2 | Desfontaines et al. (2023) |
| Homomorphic Encryption | N/A | Cryptographic guarantee |
| SMPC | N/A | Information-theoretic guarantee |

---

## Section 3: Study 2 — Harmonized Survey Variables

### Core constructs (pooled from Eurobarometer + Pew Research)

All constructs are mean-scored on their native Likert scale before pooling.
Scales are NOT standardized before analysis unless noted.

| Variable | Items | Source scale | Range | Description |
|---|---|---|---|---|
| `iuipc_col` | 3 | IUIPC-10 | 1–5 | Information privacy concern — Collection subscale |
| `iuipc_ctl` | 3 | IUIPC-10 | 1–5 | Information privacy concern — Control subscale |
| `iuipc_awa` | 3 | IUIPC-10 | 1–5 | Information privacy concern — Awareness subscale |
| `iuipc_composite` | 9 | IUIPC-10 | 1–5 | Mean of all three IUIPC subscales |
| `mpbs` | 6 | MPBS | 1–5 | Mobile Privacy Behavior Scale — protective action frequency |
| `pcb` | 3 | Privacy Calculus | 1–5 | Perceived benefit of data sharing |
| `pcr` | 3 | Privacy Calculus | 1–5 | Perceived risk of data sharing |

### Administrative variables

| Variable | Description |
|---|---|
| `dataset` | Source dataset identifier |
| `wave_label` | Survey year (e.g. "2022") |
| `time_band` | Three-band grouping: "2020-21", "2022-23", "2024-25" |
| `year_mid` | Mid-point year for regression (2020.5, 2022.5, 2024.5) |
| `country` | ISO country code or "USA" |
| `weight` | Survey post-stratification weight provided by originating archive |

### Variable crosswalk (native → harmonized)

See `study2/harmonization/harmonize_datasets.R`, section `CROSSWALK`,
for the full mapping from each source dataset's native variable names
to the harmonized construct names above.

---

## Section 4: Missing data conventions

| Code | Meaning |
|---|---|
| `NA` | Not available / not applicable for this wave or dataset |
| `NULL` | Not collected in this dataset (e.g. ε for non-DP PETs) |
| `0` | Binary flag: feature not present / behavior not taken |
| `1` | Binary flag: feature present / behavior taken |

All analyses use `na.rm = TRUE` or listwise deletion as specified in
the statistical analysis plan (Section 7.4 of the paper).
