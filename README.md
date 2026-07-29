# 🛡️ ResilienceMesh — Tactical First-Aid & Disaster Response Node

> **Offline-first, multimodal triage system for disaster zones.**
> Combines on-device Gemma 4 edge inference with laptop-hosted expert RAG + opportunistic web agents — all over air-gapped local mesh Wi-Fi.

---

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  TIER 1: MOBILE EDGE NODE (Offline — Airplane Mode)                         │
│  ┌─────────────────┐      ┌──────────────────────────────────────────────┐  │
│  │  Input Layer    │      │  Gemma 4 E4B (LiteRT / WebGPU)               │  │
│  │  • Camera       │  =>  │  • Native Multimodal Perception              │  │
│  │  • Voice Note   │      │  • Local Triage Engine (<1s)                 │  │
│  │  • Text Entry   │      │  • Urgency: Red / Yellow / Green             │  │
│  └─────────────────┘      └──────────────────────────────────────────────┘  │
│                              │                                              │
│                              ▼                                              │
│                    [ Expert Mode Toggle ]                                   │
│                    OFF → Show local result                                  │
│                    ON  → Serialize payload → Wi-Fi Direct                   │
└──────────────────────────────┬──────────────────────────────────────────────┘
                               │ HTTP POST (air-gapped)
                               ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  TIER 2: LAPTOP COMMAND NODE (Portable Heavy Compute)                       │
│  ┌────────────────────────────────────────────────────────────────────────┐  │
│  │  FastAPI (0.0.0.0:8000)  →  Ollama + Gemma 4 12B/26B/31B/A4B          │  │
│  │  • Local Vector RAG (ChromaDB + Red Cross / WHO manuals)              │  │
│  │  • <|think|> Chain-of-Thought Reasoning                                │  │
│  │  • Opportunistic Web Agent (if internet flickers on)                    │  │
│  │  • 90% GPU Offload (AMD RX 6600M / ROCm / Vulkan)                     │  │
│  └────────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 📁 Repository Structure

```
resiliencemesh/
├── mobile/                          # Flutter app — Tier 1 Edge Node
│   ├── lib/
│   │   ├── main.dart
│   │   ├── models/                  # Triage models and enums
│   │   ├── services/                # Gemma local inference, Mesh HTTP client, Audio, Camera
│   │   ├── screens/                 # Home screen and Triage result view
│   │   └── widgets/                 # UI components and urgency banners
│   ├── android/                     # Android native project and Gradle setup
│   ├── test/                        # Flutter test suite
│   ├── test_stubs/                  # Dependency stub for cross-platform support
│   ├── assets/                      # Offline models and UI assets
│   └── pubspec.yaml                 # Flutter packages & metadata
│
├── backend/                         # FastAPI — Tier 2 Command Node
│   ├── main.py                      # FastAPI server entrypoint
│   ├── config.py                    # Environment settings
│   ├── requirements.txt             # Pinned Python backend dependencies
│   ├── api/                         # API routes (/health, /expert-triage)
│   ├── models/                      # Pydantic schemas
│   ├── services/                    # Inference, RAG, and Web Agent services
│   └── tests/                       # Backend test suite
│
├── rag/                             # Vector DB setup & medical documents
│   ├── ingest.py                    # Document indexing script
│   └── documents/                   # Red Cross & WHO emergency manuals
│
├── docker/                          # Container configuration
│   ├── Dockerfile.backend
│   └── docker-compose.yml
│
├── scripts/                         # Operational & test scripts
│   ├── setup_backend.sh
│   ├── setup_mobile.sh
│   ├── run_tests.sh
│   └── start_mesh.sh
│
├── .gitignore                       # Repository ignore rules
└── README.md                        # Documentation
```

---

## 📱 Step-by-Step Android APK Reproduction Guide

Follow these exact steps to reproduce the release APK (`app-release.apk`) cleanly and without build errors.

### Prerequisites

| Tool | Required Version | Verification Command |
|------|------------------|----------------------|
| **Flutter SDK** | 3.22.0+ (3.44.8 recommended) | `flutter --version` |
| **Java JDK** | OpenJDK 17 | `java -version` |
| **Android SDK** | API Level 34 (Android 14) | `sdkmanager --list_installed` |
| **Android Build-Tools** | 34.0.0 | `$ANDROID_HOME/build-tools/34.0.0` |

---

### Step 1: Environment Setup

Ensure `JAVA_HOME` and `ANDROID_HOME` are set in your environment:

```bash
# Set Java 17 path
export JAVA_HOME="/usr/lib/jvm/java-17-openjdk-amd64"   # Adjust path to your JDK 17 installation

# Set Android SDK path
export ANDROID_HOME="$HOME/Android/Sdk"                 # Adjust path to your Android SDK

# Update PATH
export PATH="$JAVA_HOME/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"
```

---

### Step 2: Accept Android SDK Licenses

Accept all official Android SDK and NDK licenses:

```bash
yes | $ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager --licenses
```

---

### Step 3: Install Required Android SDK Platform & Build-Tools

If not already installed, run:

```bash
$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager "platforms;android-34" "build-tools;34.0.0"
```

---

### Step 4: Configure Flutter Android SDK Location

Link Flutter to your Android SDK installation:

```bash
flutter config --android-sdk $ANDROID_HOME
flutter doctor
```

Verify that both **Flutter** and **Android toolchain** show green checkmarks `[✓]`.

---

### Step 5: Resolve Mobile App Dependencies

Navigate to the `mobile/` directory and fetch dependencies:

```bash
cd mobile
flutter pub get
```

---

### Step 6: Build the Release APK

Execute the release build command:

```bash
flutter build apk --release
```

---

### Step 7: Verify Output APK Binary

Upon successful completion, the compiled APK will be generated at:

```
mobile/build/app/outputs/flutter-apk/app-release.apk
```

**Binary Details:**
- **Target Architecture**: `arm64-v8a`, `armeabi-v7a`, `x86_64`
- **Minimum Android Version**: Android 7.0 (API Level 24)
- **Target Android Version**: Android 14 (API Level 34)

---

## 💻 Step-by-Step Laptop Command Node Setup (Tier 2)

### Step 1: Python Environment & Dependencies

```bash
# Navigate to repository root
cd resiliencemesh

# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install backend dependencies
pip install -r backend/requirements.txt
```

---

### Step 2: Install & Pull Ollama Gemma Model

```bash
# Install Ollama (https://ollama.com)
curl -fsSL https://ollama.com/install.sh | sh

# Start Ollama service
ollama serve &

# Pull Gemma 4 12B model
ollama pull gemma4:12b
```

---

### Step 3: Ingest Medical RAG Knowledge Base

```bash
cd rag
python ingest.py --reset
cd ..
```

---

### Step 4: Start Command Node Server

```bash
cd backend
uvicorn main:app --host 0.0.0.0 --port 8000
```

The API server will run at `http://0.0.0.0:8000`.

---

## 🌐 Docker Deployment (Alternative)

To launch the Command Node server and Ollama using Docker Compose:

```bash
cd docker
docker-compose up --build -d
```

---

## 🧪 Running Automated Test Suites

### Backend Unit Tests

```bash
PYTHONPATH=backend python3 -m unittest discover -s backend/tests
```

### Mobile App Static Analysis & Tests

```bash
cd mobile
flutter analyze
flutter test
```

---

## 📡 API Endpoints Reference

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/health` | GET | Discovery & readiness health check |
| `/api/expert-triage` | POST | Submit field payload for RAG + LLM analysis |

### Example Curl Test

```bash
curl -X POST http://localhost:8000/api/expert-triage \
  -F "payload={\"text_query\":\"2 victims, severe leg bleeding, water rising in Sector 4\"}"
```

---

## 🛠️ Common Build Troubleshooting

| Issue | Root Cause | Solution |
|-------|------------|----------|
| `JAVA_HOME is not set` | Missing Java 17 env var | Set `export JAVA_HOME="/path/to/jdk-17"` |
| `License for package ... not accepted` | Unaccepted SDK licenses | Run `yes \| sdkmanager --licenses` |
| `record_linux` version mismatch | Transitive desktop plugin error | Standard dependency override is included in `mobile/pubspec.yaml` and `mobile/test_stubs/record_linux` |
| `Missing classes detected while running R8` | R8 code shrinking rules | Handled by `mobile/android/app/proguard-rules.pro` |

---

## 📜 License

MIT License — free for open use by disaster response teams, paramedics, and humanitarian organizations worldwide.
