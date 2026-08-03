# 🛡️ ResilienceMesh — Tactical First-Aid & Disaster Response Node

> **Offline-first, multimodal triage system for disaster zones.**
> Combines on-device Gemma 4 edge inference with laptop-hosted expert RAG + opportunistic web agents — all over air-gapped local mesh Wi-Fi.

---

## 📥 Quick Download & One-Click Start

> [!TIP]
> **No build environment required!** Precompiled release binaries and one-click startup scripts are ready for deployment.

### 1. Android Mobile App (Tier 1 Edge Node)
* Download the precompiled APK: **[resiliencemesh-multimodal-v9.apk](https://github.com/yadav-aryan18/resilience-mesh/releases/latest)** (`254.2 MB`).
* Install on any Android device running Android 7.0+ (API Level 24+):
  ```bash
  adb install -r resiliencemesh-multimodal-v9.apk
  ```

### 2. Laptop Command Node (Tier 2 Heavy Compute)
Start the entire laptop command stack (Ollama, Gemma 4, ChromaDB RAG, FastAPI, and Vite Glassmorphic Dashboard) with a single click:

* **Linux / macOS**:
  ```bash
  ./start_command_node.sh
  ```
* **Windows**:
  Double-click `start_command_node.bat`.

---

## 🏗️ Architecture Overview

```text
┌──────────────────────────────────────────────────────────────────────────────┐
│  TIER 1: MOBILE EDGE NODE (Offline — Standalone / Airplane Mode)             │
│  ┌─────────────────┐      ┌──────────────────────────────────────────────┐   │
│  │  Input Layer    │      │  Gemma 4 E2B (LiteRT-LM / OpenCL)            │   │
│  │  • Camera Photo │  =>  │  • Native Multimodal (Text, Vision, Audio)   │   │
│  │  • Voice Note   │      │  • Local Triage Engine (Offline)             │   │
│  │  • Text Query   │      │  • Urgency: Red / Yellow / Green             │   │
│  └─────────────────┘      └──────────────────────────────────────────────┘   │
│                              │                                               │
│                              ▼                                               │
│                    [ Expert Mode Toggle ]                                    │
│                    OFF → Execute local Gemma 4 E2B                           │
│                    ON  → Serialize payload → Local Wi-Fi Mesh                │
└──────────────────────────────┬───────────────────────────────────────────────┘
                               │ HTTP POST (air-gapped local subnet)
                               ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│  TIER 2: LAPTOP COMMAND NODE (Portable Heavy Compute)                        │
│  ┌────────────────────────────────────────────────────────────────────────┐  │
│  │  FastAPI (0.0.0.0:8000) → Ollama + Gemma 4 12B/26B/31B                │  │
│  │  • Local Vector RAG (ChromaDB + Red Cross / WHO manuals)               │  │
│  │  • Step-by-Step Chain-of-Thought Reasoning                             │  │
│  │  • Opportunistic Web Agent (OpenMeteo + DuckDuckGo when online)        │  │
│  │  • Vite + React Glassmorphic Command Center Dashboard                  │  │
│  └────────────────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

## 🌟 Key Features

* **📱 Native On-Device Multimodal AI**: Runs Google Gemma 4 E2B directly on Android mobile GPUs via LiteRT-LM (`addImage` and `addAudio` native byte streaming).
* **🖥️ SOTA Glassmorphic Command Center**: Modern Vite + React 18 dashboard (`http://localhost:8000`) with dynamic glowing cyber-mesh background, live activity stream, high-res image lightroom, voice note playback, and AI reasoning trace inspector.
* **📚 Red Cross & WHO Protocol RAG**: ChromaDB vector store (`all-MiniLM-L6-v2`) providing instant document citations for first-aid protocols.
* **🌐 Air-Gapped Local Subnet Auto-Discovery**: Automatic network discovery across Wi-Fi Direct (`192.168.49.1`), Mobile Hotspot (`192.168.43.x`), Linux AP (`10.42.0.1`), and LAN gateways.
* **🌐 Opportunistic Web Agent**: Automatically fetches live weather (OpenMeteo) and search snippets (DuckDuckGo) when internet connectivity flickers on during disasters.

---

## 📁 Repository Structure

```text
resiliencemesh/
├── start_command_node.sh            # One-click launcher for Linux / macOS
├── start_command_node.bat           # One-click launcher for Windows
│
├── mobile/                          # Flutter app — Tier 1 Edge Node
│   ├── lib/
│   │   ├── main.dart
│   │   ├── models/                  # Triage models and enums
│   │   ├── services/                # Gemma local inference, Mesh client, Audio, Camera
│   │   ├── screens/                 # Home screen and Triage result view
│   │   └── widgets/                 # UI components and urgency banners
│   ├── android/                     # Android native project and Gradle setup
│   ├── assets/                      # Tokenizer and UI assets
│   └── pubspec.yaml                 # Flutter packages & metadata
│
├── backend/                         # FastAPI — Tier 2 Command Node
│   ├── main.py                      # FastAPI server entrypoint & static mounts
│   ├── api/                         # API routes (/health, /expert-triage, /activities, /stats)
│   ├── models/                      # Pydantic schemas
│   ├── services/                    # Inference, RAG, Web Agent, and Activity services
│   ├── frontend/                    # Vite + React SOTA Command Dashboard
│   │   ├── src/                     # React components, Glassmorphism CSS design tokens
│   │   ├── package.json
│   │   └── vite.config.js
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
└── README.md                        # Documentation
```

---

## 📱 On-Device Gemma 4 Model Setup (Mobile)

To run **Offline Edge Mode** directly on your phone:

1. Download the Gemma 4 LiteRT mobile binary (`gemma-4-E2B-it.litertlm` ~2.58 GB) from Hugging Face / Kaggle (`litert-community/gemma-4-E2B-it-litert-lm`).
2. Open **ResilienceMesh** on your phone.
3. Tap the **Model Selection Banner** or folder icon at the top of the main screen.
4. Select `gemma-4-E2B-it.litertlm`. The app streams the model into its sandbox and prepares on-device GPU inference.

---

## 💻 Manual Laptop Command Node Setup (Tier 2)

If you prefer launching components manually instead of using `./start_command_node.sh`:

### Step 1: Python Virtual Environment

```bash
cd resiliencemesh
python3 -m venv venv
source venv/bin/activate
pip install -r backend/requirements.txt
```

### Step 2: Ollama & Gemma 4 Setup

```bash
curl -fsSL https://ollama.com/install.sh | sh
ollama serve &
ollama pull gemma4:12b
```

### Step 3: Build Web Dashboard Frontend

```bash
cd backend/frontend
npm install
npm run build
cd ../..
```

### Step 4: Run Command Server

```bash
cd backend
python3 main.py
```

Open `http://localhost:8000` in your web browser.

---

## 📱 Mobile APK Reproduction Guide

Follow these steps to compile the release APK from source:

### Prerequisites

| Tool | Required Version | Verification Command |
| :--- | :--- | :--- |
| **Flutter SDK** | 3.22.0+ (3.44.8 recommended) | `flutter --version` |
| **Java JDK** | OpenJDK 17 | `java -version` |
| **Android SDK** | API Level 34 (Android 14) | `sdkmanager --list_installed` |

### Compilation Commands

```bash
# 1. Environment exports
export JAVA_HOME="/usr/lib/jvm/java-17-openjdk-amd64"
export ANDROID_HOME="$HOME/Android/Sdk"
export PATH="$JAVA_HOME/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"

# 2. Build Release APK
cd mobile
flutter pub get
flutter build apk --release
```

Output APK will be generated at:
`mobile/build/app/outputs/flutter-apk/app-release.apk`

---

## 📡 API Endpoints Reference

| Endpoint | Method | Description |
| :--- | :---: | :--- |
| `/api/health` | `GET` | Discovery & readiness health check |
| `/api/expert-triage` | `POST` | Submit field payload for RAG + LLM analysis |
| `/api/activities` | `GET` | Retrieve recent field reports for command dashboard |
| `/api/stats` | `GET` | Real-time node telemetry & urgency distribution stats |
| `/api/rag-docs` | `GET` | List indexed Red Cross / WHO document chunks |

### Example Curl Test

```bash
curl -X POST http://localhost:8000/api/expert-triage \
  -F "payload={\"text_query\":\"Victim with severe leg bleeding in Sector 4\"}"
```

---

## 🧪 Running Automated Test Suites

### Backend Unit Tests
```bash
PYTHONPATH=backend python3 -m unittest discover -s backend/tests
```

### Mobile App Static Analysis
```bash
cd mobile
flutter analyze
```

---

## 📜 License

MIT License — free for open use by disaster response teams, emergency paramedics, and humanitarian organizations worldwide.
