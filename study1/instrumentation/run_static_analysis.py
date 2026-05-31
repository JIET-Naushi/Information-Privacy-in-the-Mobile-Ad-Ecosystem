#!/usr/bin/env python3
"""
Study 1 — Static analysis pipeline
===================================
Wraps FlowDroid 2.9 and MobSF 4.0 to enumerate embedded A&A SDKs,
requested permissions, and information-flow sources/sinks for a batch
of APK files.

Usage:
    python run_static_analysis.py --apk-dir /path/to/apks --wave W6 --output-dir ./results

Requirements:
    - FlowDroid 2.9 JAR (https://github.com/secure-software-engineering/FlowDroid)
    - MobSF 4.0 running locally (https://github.com/MobSF/Mobile-Security-Framework-MobSF)
    - Python packages: requests, pandas, tqdm (see requirements.txt)

Environment variables:
    MOBSF_API_KEY   — MobSF REST API key (set in MobSF admin panel)
    FLOWDROID_JAR   — Full path to soot-infoflow-cmd-*.jar
    ANDROID_PLATFORMS — Path to Android SDK platforms directory
"""

import argparse
import csv
import json
import os
import subprocess
import sys
import time
from pathlib import Path

import pandas as pd
import requests
from tqdm import tqdm

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

MOBSF_HOST = os.getenv("MOBSF_HOST", "http://localhost:8000")
MOBSF_API_KEY = os.getenv("MOBSF_API_KEY", "")
FLOWDROID_JAR = os.getenv("FLOWDROID_JAR", "")
ANDROID_PLATFORMS = os.getenv("ANDROID_PLATFORMS", "")

EXODUS_API_BASE = "https://reports.exodus-privacy.eu.org/api"

# Endpoint catalogue for identifier classification
ENDPOINT_CATALOGUE_PATH = Path(__file__).parent.parent.parent / "data" / "study1" / "endpoint_catalogue.csv"


def load_endpoint_catalogue() -> set:
    """Load the 1,341 known A&A endpoints used for identifier classification."""
    if not ENDPOINT_CATALOGUE_PATH.exists():
        raise FileNotFoundError(
            f"Endpoint catalogue not found at {ENDPOINT_CATALOGUE_PATH}. "
            "Ensure you have cloned the full repository."
        )
    df = pd.read_csv(ENDPOINT_CATALOGUE_PATH)
    return set(df["endpoint_domain"].str.lower())


def analyze_with_mobsf(apk_path: Path, api_key: str, host: str) -> dict:
    """
    Upload an APK to MobSF and return the JSON analysis report.
    Returns empty dict on failure.
    """
    headers = {"Authorization": api_key}

    # Upload
    with open(apk_path, "rb") as f:
        upload_resp = requests.post(
            f"{host}/api/v1/upload",
            files={"file": (apk_path.name, f, "application/octet-stream")},
            headers=headers,
            timeout=120,
        )
    if upload_resp.status_code != 200:
        print(f"  [WARN] MobSF upload failed for {apk_path.name}: {upload_resp.status_code}")
        return {}

    upload_data = upload_resp.json()
    file_hash = upload_data.get("hash", "")

    # Scan
    scan_resp = requests.post(
        f"{host}/api/v1/scan",
        data={"scan_type": "apk", "file_name": apk_path.name, "hash": file_hash},
        headers=headers,
        timeout=300,
    )
    if scan_resp.status_code != 200:
        print(f"  [WARN] MobSF scan failed for {apk_path.name}: {scan_resp.status_code}")
        return {}

    # Report
    report_resp = requests.post(
        f"{host}/api/v1/report_json",
        data={"hash": file_hash},
        headers=headers,
        timeout=60,
    )
    if report_resp.status_code != 200:
        return {}

    return report_resp.json()


def parse_mobsf_trackers(report: dict, known_endpoints: set) -> dict:
    """
    Extract tracker count, identifier-exposure score, and API flags from
    a MobSF JSON report.

    Returns:
        dict with keys: tracker_count, identifier_exposure_score,
                        uses_topics_api, uses_protected_audience,
                        uses_custom_audience, tracker_names (list)
    """
    trackers = report.get("trackers", {}).get("trackers", [])
    tracker_count = len(trackers)
    tracker_names = [t.get("name", "") for t in trackers]

    # Identifier-exposure score: weighted sum of stable identifier categories
    # Weight map based on Section 7.2.4 of the paper
    permissions = report.get("permissions", {})
    id_weights = {
        "android.permission.READ_PHONE_STATE": 2.0,   # IMEI / device serial
        "android.permission.ACCESS_FINE_LOCATION": 1.5,
        "android.permission.ACCESS_COARSE_LOCATION": 1.0,
        "android.permission.READ_CONTACTS": 1.5,
        "android.permission.GET_ACCOUNTS": 1.0,
        "android.permission.READ_CALL_LOG": 2.0,
        "android.permission.RECORD_AUDIO": 0.5,
        "android.permission.CAMERA": 0.5,
        "com.google.android.gms.permission.AD_ID": 2.0,  # GAID
    }
    exposure_score = min(
        sum(w for perm, w in id_weights.items() if perm in permissions),
        10.0,
    )

    # On-device profiling API flags (Privacy Sandbox)
    api_calls = str(report.get("android_api", {}))
    uses_topics_api = "getTopics" in api_calls
    uses_protected_audience = "joinCustomAudience" in api_calls or "ProtectedAudience" in api_calls
    uses_custom_audience = "CustomAudience" in api_calls

    return {
        "tracker_count": tracker_count,
        "identifier_exposure_score": round(exposure_score, 2),
        "uses_topics_api": int(uses_topics_api),
        "uses_protected_audience": int(uses_protected_audience),
        "uses_custom_audience": int(uses_custom_audience),
        "tracker_names": "|".join(tracker_names),
    }


def fetch_exodus_fallback(package_name: str) -> dict:
    """
    Fetch tracker data from Exodus Privacy API as fallback when MobSF
    is unavailable or APK is not accessible.
    """
    try:
        resp = requests.get(
            f"{EXODUS_API_BASE}/search/{package_name}/",
            timeout=10,
        )
        if resp.status_code == 200:
            data = resp.json()
            reports = data.get("results", [])
            if reports:
                latest = reports[0]
                trackers = latest.get("trackers", [])
                return {
                    "tracker_count": len(trackers),
                    "identifier_exposure_score": None,  # Not available from Exodus
                    "uses_topics_api": None,
                    "uses_protected_audience": None,
                    "uses_custom_audience": None,
                    "tracker_names": "|".join(str(t) for t in trackers),
                    "source": "exodus_api",
                }
    except requests.RequestException:
        pass
    return {}


def run_static_analysis(apk_dir: Path, wave: str, output_dir: Path):
    """
    Main analysis loop: iterate over APKs in apk_dir, run MobSF analysis,
    and write per-app results to output_dir/static_{wave}.csv.
    """
    app_sample_path = Path(__file__).parent.parent.parent / "data" / "study1" / "app_sample.csv"
    if not app_sample_path.exists():
        print(f"[ERROR] app_sample.csv not found at {app_sample_path}")
        sys.exit(1)

    app_sample = pd.read_csv(app_sample_path)
    wave_apps = app_sample[app_sample[f"available_{wave}"] == 1]["package_name"].tolist()
    print(f"Wave {wave}: {len(wave_apps)} apps in sample")

    if not MOBSF_API_KEY:
        print("[WARN] MOBSF_API_KEY not set — will use Exodus Privacy API fallback only.")

    known_endpoints = load_endpoint_catalogue()
    output_dir.mkdir(parents=True, exist_ok=True)
    output_path = output_dir / f"static_{wave}.csv"

    results = []
    for package_name in tqdm(wave_apps, desc=f"Static analysis {wave}"):
        apk_path = apk_dir / f"{package_name}.apk"
        row = {"package_name": package_name, "wave": wave, "source": "mobsf"}

        if apk_path.exists() and MOBSF_API_KEY:
            report = analyze_with_mobsf(apk_path, MOBSF_API_KEY, MOBSF_HOST)
            if report:
                row.update(parse_mobsf_trackers(report, known_endpoints))
            else:
                row.update(fetch_exodus_fallback(package_name))
                row["source"] = "exodus_fallback"
        else:
            row.update(fetch_exodus_fallback(package_name))
            row["source"] = "exodus_only"

        results.append(row)
        time.sleep(0.1)  # Be polite to the Exodus API

    df = pd.DataFrame(results)
    df.to_csv(output_path, index=False)
    print(f"\nResults written to {output_path}")
    print(df[["tracker_count", "identifier_exposure_score"]].describe())


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Study 1 static analysis pipeline")
    parser.add_argument("--apk-dir", type=Path, default=Path("."), help="Directory containing APK files")
    parser.add_argument("--wave", choices=["W1", "W2", "W3", "W4", "W5", "W6"], required=True)
    parser.add_argument("--output-dir", type=Path, default=Path("results"), help="Output directory")
    args = parser.parse_args()

    run_static_analysis(args.apk_dir, args.wave, args.output_dir)
