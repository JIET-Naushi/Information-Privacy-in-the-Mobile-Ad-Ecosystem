# Study 1 — App Measurement Data

## What is included in this repository

| File | Description |
|---|---|
| `app_sample.csv` | List of 2,500 app package names with category, Play Store stratum, and wave-level availability flags |
| `endpoint_catalogue.csv` | 1,341 known A&A endpoints used for identifier classification (validated against Exodus Privacy and Tracker Control databases) |
| `wave_summary_stats.csv` | Per-wave aggregated summary statistics (means, SDs, medians, proportions) as reported in Table 4 and Table 5 of the paper |

## What is NOT included

- Raw network-traffic payloads (412 GB total): retained on encrypted institutional storage per the data management plan; contact the corresponding author for access under a data-sharing agreement.
- Per-app raw tracker counts at the record level: available on request under the same agreement.
- Decrypted TLS payloads: not released publicly, consistent with responsible disclosure.

## Reproducing Study 1 from scratch

If you wish to replicate the full data-collection pipeline rather than use the summary statistics:

1. **Obtain APKs** for the apps listed in `app_sample.csv`. APKBackup or gplaydl can be used for archival research purposes.
2. **Run static analysis:**
   ```bash
   python ../../study1/instrumentation/run_static_analysis.py \
       --apk-dir /path/to/apks \
       --wave W6 \
       --output-dir .
   ```
3. **Run dynamic analysis** (Android device required):
   ```bash
   python ../../study1/instrumentation/run_dynamic_analysis.py \
       --wave W6 \
       --device-serial <adb-serial>
   ```
4. **Run network capture** (mitmproxy with custom CA):
   ```bash
   python ../../study1/instrumentation/run_network_capture.py \
       --wave W6 \
       --proxy-port 8080
   ```

For historical waves (W1–W5) the instrumentation code is the same; APK versions for those dates
can be sourced from androzoo.uni.lu (academic access) using the SHA256 hashes in `app_sample.csv`.

## Accessing Exodus Privacy data as an alternative

The Exodus Privacy public API provides static-analysis tracker data for many of the same apps.
This is a legitimate alternative or supplement to running the full pipeline:

```bash
python ../../study1/instrumentation/fetch_exodus_data.py \
    --app-list app_sample.csv \
    --output exodus_trackers.csv
```

API documentation: https://reports.exodus-privacy.eu.org/en/api/
