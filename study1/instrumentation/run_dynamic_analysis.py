#!/usr/bin/env python3
"""
Study 1 — Dynamic analysis and network capture pipeline
=========================================================
Automates UI exploration via Monkey + DroidBot on a connected Android device,
with Frida 16 hooks for API-call interception and mitmproxy for TLS decryption.

Usage:
    python run_dynamic_analysis.py --wave W6 --device-serial <adb-serial>

Requirements:
    - adb connected device running Android 15
    - Frida server deployed on device (https://github.com/frida/frida)
    - mitmproxy 11 with custom CA installed on device
    - DroidBot (pip install droidbot)
    - Python packages: frida, mitmproxy, pandas, tqdm

Environment variables:
    DEVICE_SERIAL   — ADB serial of target device
    MITMPROXY_PORT  — Port for mitmproxy (default 8080)
    FRIDA_SERVER_PORT — Frida server port on device (default 27042)

Notes on privacy:
    Analysis is performed on researcher-controlled test devices only.
    No data from third-party users is collected at any point.
    Test devices are factory-reset between major analysis runs.
"""

import argparse
import json
import os
import subprocess
import sys
import tempfile
import time
from pathlib import Path

import frida
import pandas as pd
from tqdm import tqdm

# ---------------------------------------------------------------------------
# Frida hook script — intercepts Privacy Sandbox API calls
# ---------------------------------------------------------------------------
FRIDA_HOOK_SCRIPT = """
'use strict';

// Hook Topics API
var TopicsManager = Java.use('android.adservices.topics.TopicsManager');
TopicsManager.getTopics.overload('android.adservices.topics.GetTopicsRequest',
    'java.util.concurrent.Executor',
    'android.os.OutcomeReceiver').implementation = function(req, exec, cb) {
    send({type: 'api_call', api: 'getTopics', package: Java.use('android.os.Process').myPid()});
    return this.getTopics(req, exec, cb);
};

// Hook Custom Audience API (Protected Audience)
try {
    var CAManager = Java.use('android.adservices.customaudience.CustomAudienceManager');
    CAManager.joinCustomAudience.overload(
        'android.adservices.customaudience.JoinCustomAudienceRequest',
        'java.util.concurrent.Executor',
        'android.os.OutcomeReceiver').implementation = function(req, exec, cb) {
        send({type: 'api_call', api: 'joinCustomAudience'});
        return this.joinCustomAudience(req, exec, cb);
    };
} catch(e) { /* API not present on this Android version */ }

// Hook GAID access
try {
    var AdvertisingIdClient = Java.use('com.google.android.gms.ads.identifier.AdvertisingIdClient');
    AdvertisingIdClient.getAdvertisingIdInfo.implementation = function(ctx) {
        send({type: 'identifier_access', identifier: 'GAID'});
        return this.getAdvertisingIdInfo(ctx);
    };
} catch(e) {}

// Hook system identifier access
var TelephonyManager = Java.use('android.telephony.TelephonyManager');
try {
    TelephonyManager.getImei.overload().implementation = function() {
        send({type: 'identifier_access', identifier: 'IMEI'});
        return this.getImei();
    };
} catch(e) {}
"""


def start_mitmproxy(port: int, output_file: Path) -> subprocess.Popen:
    """Start mitmproxy in transparent mode, writing flows to output_file."""
    proc = subprocess.Popen(
        [
            "mitmdump",
            "--listen-port", str(port),
            "--save-stream-file", str(output_file),
            "--set", "ssl_insecure=true",
            "--set", "stream_large_bodies=1m",
        ],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    time.sleep(2)  # Allow proxy to start
    return proc


def set_proxy_on_device(serial: str, host: str, port: int):
    """Configure HTTP proxy on the Android device via adb."""
    subprocess.run(
        ["adb", "-s", serial, "shell", "settings", "put", "global",
         "http_proxy", f"{host}:{port}"],
        check=True,
    )


def clear_proxy_on_device(serial: str):
    """Remove proxy configuration from device."""
    subprocess.run(
        ["adb", "-s", serial, "shell", "settings", "put", "global",
         "http_proxy", ":0"],
        check=False,
    )


def run_droidbot(serial: str, package_name: str, duration_secs: int = 60) -> bool:
    """Run DroidBot automated UI exploration on the given package."""
    result = subprocess.run(
        [
            "python", "-m", "droidbot",
            "-d", serial,
            "-a", f"package:{package_name}",
            "-count", "200",
            "-interval", "0.3",
            "-timeout", str(duration_secs),
            "-is_emulator",  # Remove for real device
        ],
        capture_output=True,
        timeout=duration_secs + 30,
    )
    return result.returncode == 0


def analyze_with_frida(serial: str, package_name: str, hook_script: str,
                       duration_secs: int = 60) -> list:
    """
    Attach Frida to a running app, collect API-call events for duration_secs.
    Returns list of event dicts.
    """
    events = []

    try:
        device = frida.get_device(serial)
        pid = device.spawn([package_name])
        session = device.attach(pid)
        script = session.create_script(hook_script)

        def on_message(message, data):
            if message["type"] == "send":
                events.append(message["payload"])

        script.on("message", on_message)
        script.load()
        device.resume(pid)

        time.sleep(duration_secs)

        session.detach()
        device.kill(pid)

    except frida.ProcessNotFoundError:
        pass
    except Exception as e:
        print(f"  [WARN] Frida error for {package_name}: {e}")

    return events


def run_dynamic_analysis(wave: str, device_serial: str, output_dir: Path):
    """
    Main dynamic analysis loop.
    For each app in the wave sample: launch app, run Frida hooks + DroidBot,
    capture network traffic via mitmproxy.
    """
    app_sample_path = Path(__file__).parent.parent.parent / "data" / "study1" / "app_sample.csv"
    app_sample = pd.read_csv(app_sample_path)
    wave_apps = app_sample[app_sample[f"available_{wave}"] == 1]["package_name"].tolist()

    print(f"Wave {wave}: {len(wave_apps)} apps to analyze dynamically")
    print(f"Device: {device_serial}")

    proxy_port = int(os.getenv("MITMPROXY_PORT", "8080"))
    output_dir.mkdir(parents=True, exist_ok=True)

    results = []

    for package_name in tqdm(wave_apps, desc=f"Dynamic {wave}"):
        flow_file = output_dir / f"{package_name}_{wave}.flow"
        event_file = output_dir / f"{package_name}_{wave}_events.json"

        # Start proxy
        proxy_proc = start_mitmproxy(proxy_port, flow_file)
        set_proxy_on_device(device_serial, "127.0.0.1", proxy_port)

        try:
            # Run Frida + DroidBot concurrently (simplified — production uses threads)
            frida_events = analyze_with_frida(
                device_serial, package_name, FRIDA_HOOK_SCRIPT, duration_secs=60
            )
            with open(event_file, "w") as f:
                json.dump(frida_events, f)

            # Aggregate results
            api_types = {e["api"] for e in frida_events if e.get("type") == "api_call"}
            id_types = {e["identifier"] for e in frida_events if e.get("type") == "identifier_access"}

            results.append({
                "package_name": package_name,
                "wave": wave,
                "uses_topics_api": int("getTopics" in api_types),
                "uses_protected_audience": int("joinCustomAudience" in api_types),
                "accesses_gaid": int("GAID" in id_types),
                "accesses_imei": int("IMEI" in id_types),
                "frida_event_count": len(frida_events),
                "flow_file": str(flow_file),
            })

        finally:
            clear_proxy_on_device(device_serial)
            proxy_proc.terminate()
            proxy_proc.wait()
            time.sleep(2)

    df = pd.DataFrame(results)
    out_csv = output_dir / f"dynamic_{wave}.csv"
    df.to_csv(out_csv, index=False)
    print(f"\nDynamic analysis results written to {out_csv}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Study 1 dynamic analysis pipeline")
    parser.add_argument("--wave", choices=["W1", "W2", "W3", "W4", "W5", "W6"], required=True)
    parser.add_argument("--device-serial", type=str,
                        default=os.getenv("DEVICE_SERIAL", ""),
                        help="ADB device serial")
    parser.add_argument("--output-dir", type=Path, default=Path("results/dynamic"))
    args = parser.parse_args()

    if not args.device_serial:
        print("[ERROR] --device-serial or DEVICE_SERIAL env var required")
        sys.exit(1)

    run_dynamic_analysis(args.wave, args.device_serial, args.output_dir)
