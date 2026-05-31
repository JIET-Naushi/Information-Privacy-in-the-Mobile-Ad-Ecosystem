# Environment and Software Setup

## Software versions used in the paper

| Component | Version | Notes |
|---|---|---|
| Python | 3.13.1 | Primary scripting language |
| R | 4.4.2 | Statistical analysis |
| FlowDroid | 2.9 | Static analysis (Android) |
| MobSF | 4.0.8 | Static + dynamic app analysis |
| Frida | 16.4.6 | Dynamic instrumentation |
| mitmproxy | 11.0.2 | TLS interception |
| DroidBot | 2024.12 | Automated UI exploration |
| diffprivlib | 0.6.4 | Differential privacy (Python) |
| TenSEAL | 0.3.14 | Homomorphic encryption |
| PyTorch | 2.2.2 | Federated learning |

## Test devices (Study 1)

| Device | OS | Role |
|---|---|---|
| Google Pixel 6 | Android 15 (API 35) | Primary dynamic analysis |
| Samsung Galaxy S22 | Android 15 (API 35) | Secondary / cross-validation |

Both devices were factory-reset at the start of each wave's data collection.
Root access via Magisk was used to deploy Frida server and install the custom CA.

## Setting up the environment

### Python

```bash
python -m venv venv
source venv/bin/activate   # or .\venv\Scripts\activate on Windows
pip install -r requirements.txt
```

### R

```r
install.packages(readLines("requirements_r.txt"), repos = "https://cran.r-project.org")
```

### FlowDroid

```bash
wget https://github.com/secure-software-engineering/FlowDroid/releases/download/v2.9/soot-infoflow-cmd-2.9.0-jar-with-dependencies.jar
export FLOWDROID_JAR=$(pwd)/soot-infoflow-cmd-2.9.0-jar-with-dependencies.jar
export ANDROID_PLATFORMS=/path/to/android/platforms  # from Android SDK
```

### MobSF

```bash
docker run -it --rm -p 8000:8000 opensecurity/mobile-security-framework-mobsf:latest
# Get API key from http://localhost:8000/api_docs
export MOBSF_API_KEY=<your-key>
```

### Frida server (on Android device)

```bash
adb push frida-server-16.4.6-android-arm64 /data/local/tmp/frida-server
adb shell chmod 755 /data/local/tmp/frida-server
adb shell /data/local/tmp/frida-server &
```

### mitmproxy CA installation

```bash
mitmproxy --listen-port 8080 &
# Then on device: Settings > Wi-Fi > Proxy > Manual, host=<computer-IP>, port=8080
# Navigate to mitm.it in device browser and install CA certificate
adb shell settings put global http_proxy <computer-IP>:8080
```

## Compute environment

All benchmarks (Study 3) were run on:
- CPU: Apple M2 Pro, 12-core, 32 GB RAM
- GPU: Not used (all PET benchmarks are CPU-bound at the scale tested)
- OS: macOS 15.2

Study 1 analysis scripts were run on:
- CPU: Intel Xeon E5-2690 v4, 14-core, 128 GB RAM
- OS: Ubuntu 24.04 LTS
- R and Python via conda environment

Approximate wall-clock times for full reproduction:
- Study 1 static analysis (all waves): ~48 hours with Exodus API fallback; ~96 hours with full MobSF
- Study 1 statistical analysis: ~15 minutes
- Study 2 harmonization: ~10 minutes (after downloading datasets)
- Study 2 statistical analysis: ~20 minutes
- Study 3 benchmarks: ~30 minutes (CPU, implemented PETs only)
