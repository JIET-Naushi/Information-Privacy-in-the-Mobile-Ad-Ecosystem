# Ethics and Data Governance Statement

## Study 1 — Android Application Measurement

**Data type:** Automated analysis of publicly listed Android applications.

**Human participants:** None. The study instrumented only applications published on the Google Play Store. No data from app users, app-user devices, or private communications was collected at any point.

**Ethics classification:** This component does not meet the regulatory definition of human-subjects research. Under the U.S. Common Rule (45 CFR 46.102(e)), "human subjects research" requires the involvement of living individuals about whom a researcher obtains data through intervention or interaction, or identifiable private information. Automated analysis of publicly distributed software artefacts meets neither condition.

**Equivalent international provisions:**
- EU: GDPR Recital 26 (processing of non-personal / publicly available information)
- UK: ICO guidance on research exemptions (DPA 2018 Schedule 2 para. 4)
- India: DPDP Act 2023 Section 4 (publicly available personal data exception)

**Network traffic:** TLS decryption was performed on a closed, air-gapped testbed using devices under the researchers' sole control. No traffic from third parties was intercepted.

---

## Study 2 — Secondary Analysis of Existing Survey Datasets

**Data type:** Pre-existing, fully de-identified survey microdata obtained from established public data archives.

**Human participants:** None at the point of research. Data was previously collected by the originating survey organisations under their own ethics approvals and informed consent procedures. This study performed secondary analysis only — no new recruitment, intervention, or interaction with individuals was undertaken.

**Ethics classification:** Exempt under:
- U.S. Common Rule: 45 CFR 46.104(d)(4) — research involving the collection or study of existing data that are publicly available.
- EU: GDPR Article 89 — processing for scientific research purposes with appropriate safeguards; records are fully de-identified.
- UK: MRC/ESRC framework for secondary data analysis — no new consent required when data is publicly archived and de-identified.

**Data sources and their original ethics coverage:**

| Dataset | Archive | Original ethics | Licence |
|---|---|---|---|
| Eurobarometer EB97.1 (Data Protection 2022) | GESIS ZA7572 | European Commission / Kantar | GESIS open access |
| Eurobarometer EB91.2 (Data Protection 2019) | GESIS ZA7572 | European Commission / Kantar | GESIS open access |
| Pew Research "Americans and Privacy" 2019 | Pew Research Center | Pew IRB | Pew open access |
| Pew Research "Americans and Privacy" 2023 | Pew Research Center | Pew IRB | Pew open access |
| Additional datasets | See DATA_ACCESS.md | Per originating institution | Per archive licence |

**De-identification:** All records were de-identified at source by the originating organisations before archiving. No re-identification was attempted or possible; all direct identifiers (name, address, device ID) were removed prior to deposit.

---

## Study 3 — PET Benchmarking

No human participants. Benchmarks were conducted on researcher-controlled hardware using open-source implementations of published cryptographic protocols. No personal data was processed.

---

## Data minimisation and security

- Raw network-traffic payloads (412 GB) captured during Study 1 are retained on encrypted storage under the institutional data management plan and are not distributed publicly, consistent with responsible disclosure principles.
- Only aggregated, app-level summary statistics are released in this repository.
- Secondary survey data for Study 2 is not redistributed; researchers are directed to obtain data directly from the originating archives under their own licence agreements.

---

## Contact

For questions about research ethics compliance, contact the corresponding author or the institutional research integrity office.
