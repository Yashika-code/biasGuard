# BiasGuard 🛡️

**FairAI for Every Decision — Anywhere in the World**

> Google Solution Challenge 2026 · Theme: Unbiased AI Decision Making
> Build with AI · Hack2Skill x GDG India · Team from Patna, Bihar, India

[![Firebase](https://img.shields.io/badge/Firebase-FFCA28?style=flat&logo=firebase&logoColor=black)](https://firebase.google.com)
[![Flutter](https://img.shields.io/badge/Flutter-02569B?style=flat&logo=flutter&logoColor=white)](https://flutter.dev)
[![Gemini](https://img.shields.io/badge/Gemini%202.0-4285F4?style=flat&logo=google&logoColor=white)](https://ai.google.dev)
[![Python](https://img.shields.io/badge/Python%203.11-3776AB?style=flat&logo=python&logoColor=white)](https://python.org)

---

## 🎯 What is BiasGuard?

BiasGuard is a professional-grade **AI Fairness Auditing and Decision Assistant** platform. It uses Google Gemini 2.0 to detect, explain in plain language, and actively fix bias in AI-driven decisions — with a special focus on India's unique socio-cultural challenges (caste proxies, rural-urban divide, regional bias).

### Two Modes
| Mode | What it does |
|------|-------------|
| **Audit Mode** | Upload any AI decision CSV → instant bias scan → Gemini explanation in Hindi/English → one-click mitigation with before/after charts |
| **Direct Fair Decision Mode** | Input any decision scenario → Gemini delivers a transparent, fair recommendation with zero protected-attribute bias |

---

## 🏗️ Architecture

```
User (Flutter Web/Mobile App)
   ↓ Riverpod Providers
Presentation Layer (Screens, Widgets)
   ↓ HTTP calls
Firebase Cloud Functions (Python)
   ├── CF1: parseAndCalculateMetrics  — CSV parsing + 4 fairness metrics
   ├── CF2: geminiAnalysisAndMitigation — Gemini explanation + proxy detection
   ├── CF3: triggerMitigation          — Reweighting engine + before/after output
   └── CF4: getDirectFairDecision      — Standalone fair decision via Gemini
   ↓ Firestore real-time sync
Flutter UI updates in real time
   ↓
Google Gemini 2.0 Flash API (reasoning, explanations, proxy detection, multilingual)
```

---

## ⚖️ Fairness Metrics Implemented

| Metric | Definition |
|--------|-----------|
| **Demographic Parity** | Max − min approval rate across groups (0 = fair) |
| **Equal Opportunity** | Difference in true positive rates (qualified candidates approved) |
| **Equalized Odds** | Average of TPR and FPR differences across groups |
| **Predictive Parity** | Difference in precision (PPV) across groups |
| **Equity Score (0–100)** | India-weighted composite: `100 − (0.35×DP + 0.30×EO + 0.20×EOdds + 0.15×PP) × 100` |

---

## 🧠 India-Specific Proxy Detection

BiasGuard detects bias proxies specific to Indian socio-cultural context:

- **Surname → Caste Inference** — 80+ Indian surnames mapped to social groups (SC/ST/OBC/General)
- **Roll Number → District → Rural/Urban** — Bihar BSEB roll number prefix decodes to district
- **PIN Code → Rural/Urban** — Bihar PIN code ranges classify urban (800x) vs rural (84x–85x)
- **School Board → SES** — State boards (BSEB) = lower SES proxy; CBSE/ICSE = higher SES
- **District Name → Rural/Urban** — All 38 Bihar districts classified
- **Name/Salutation → Gender** — Female-coded names and salutations (Devi, Kumari, Smt) detected

---

## 🗂️ Project Structure

```
biasguard-solution-challenge-2026/
├── biasguard/                    # Flutter app (Member A)
│   ├── lib/
│   │   ├── core/                 # Theme, constants, config
│   │   ├── features/             # auth, dashboard, audit_mode, direct_mode
│   │   ├── models/               # Dart data models
│   │   ├── providers/            # Riverpod providers
│   │   └── services/             # Gemini service, CSV parser
│   └── pubspec.yaml
├── functions/                    # Firebase Cloud Functions (Member B — YOU)
│   ├── main.py                   # 4 HTTP Cloud Functions
│   ├── helpers/
│   │   ├── csv_parser.py         # CSV download + column auto-detection
│   │   ├── fairness_metrics.py   # DP, EO, EOdds, PP, Equity Score
│   │   ├── proxy_detection.py    # India-specific proxy detection
│   │   ├── mitigation.py         # Reweighting engine
│   │   ├── gemini_client.py      # Gemini API wrapper (3 prompts)
│   │   ├── firestore_writer.py   # All Firestore read/write helpers
│   │   └── anonymizer.py         # PII anonymisation
│   ├── data/
│   │   ├── surname_caste_map.json
│   │   └── district_rural_map.json
│   └── requirements.txt
├── assets/
│   └── demo/
│       └── bihar_scholarship_2026.csv  # Synthetic 200-row demo dataset
├── firestore.rules
├── storage.rules
├── firestore.indexes.json
└── firebase.json
```

---

## 🚀 Setup & Deployment

### Prerequisites
- Python 3.11+
- Node.js 18+ (for Firebase CLI)
- Firebase CLI: `npm install -g firebase-tools`
- Flutter 3.29+ (for Member A's frontend)

### Step 1: Clone & Firebase Login
```bash
git clone https://github.com/YOUR_USERNAME/biasguard-solution-challenge-2026.git
cd biasguard-solution-challenge-2026
firebase login
firebase use biasguard-2026
```

### Step 2: Set Gemini API Key
```bash
firebase functions:secrets:set GEMINI_API_KEY
# Paste your key from https://aistudio.google.com/app/apikey
```

### Step 3: Deploy Cloud Functions
```bash
cd functions
pip install -r requirements.txt  # local testing only
cd ..
firebase deploy --only functions
```

### Step 4: Deploy Security Rules
```bash
firebase deploy --only firestore:rules,storage
```

### Step 5: Flutter App (Member A)
```bash
cd biasguard
flutter pub get
flutterfire configure
flutter run -d chrome  # web
flutter run            # Android/iOS
```

---

## 📊 Firestore Data Schema

All field names shared with Member A for Riverpod provider alignment:

```
/users/{uid}/scans/{scan_id}/
  ├── [document]         → status, updated_at
  └── data/
      ├── metrics        → equity_score, demographic_parity, equal_opportunity,
      │                    equalized_odds, predictive_parity, group_stats,
      │                    detected_sensitive_columns, row_count, dataset_name
      ├── analysis       → explanation_en, explanation_hi, root_causes,
      │                    proxy_features, mitigation_suggestion, severity
      ├── proxies        → proxy_columns (list with column, proxy_type, confidence, explanation)
      └── mitigation     → before/after_equity_score, before/after_approval_rates,
                           decisions_changed_count, new_demographic_parity
```

---

## 🌐 Cloud Function API Reference

### CF1: `parseAndCalculateMetrics`
```
POST /parseAndCalculateMetrics
Content-Type: application/json

{
  "uid": "firebase_user_id",
  "scan_id": "optional_custom_id",
  "storage_path": "uploads/{uid}/filename.csv",
  "dataset_name": "Bihar Scholarship 2026",
  "use_case": "Scholarship Selection",
  "anonymise": false
}
```

### CF2: `geminiAnalysisAndMitigation`
```
POST /geminiAnalysisAndMitigation
# Body: the _cf2_context object returned by CF1
```

### CF3: `triggerMitigation`
```
POST /triggerMitigation
{
  "uid": "firebase_user_id",
  "scan_id": "scan_id",
  "storage_path": "uploads/{uid}/filename.csv",
  "group_col": "district",
  "outcome_col": "decision"
}
```

### CF4: `getDirectFairDecision`
```
POST /getDirectFairDecision
{
  "uid": "firebase_user_id",
  "scenario": "Applicant has 78% marks from a rural Bihar school...",
  "save_to_firestore": true
}
```

---

## 🎭 Demo Dataset

`assets/demo/bihar_scholarship_2026.csv` — 200 synthetic student records:
- **Columns**: student_name, roll_number, district, school_board, stream, marks_percent, decision
- **Bias pattern**: Urban CBSE students (Patna) approved at ~90%; Rural BSEB SC/ST students approved at ~35%
- **Detected proxies**: surname → caste, school_board → SES, district → rural/urban, roll_number → district prefix
- **Expected equity score**: ~42/100 (triggers 'High Bias' flag)

---

## 🌍 UN SDG Alignment

| SDG | Alignment |
|-----|-----------|
| **SDG 10** — Reduced Inequalities | Directly audits and fixes digital discrimination against SC/ST and rural applicants |
| **SDG 16** — Justice & Accountability | Makes AI decisions transparent and auditable |
| **SDG 4** — Quality Education | Fairer scholarship and admission systems |
| **SDG 8** — Decent Work | Unbiased hiring tools |

---

## 👥 Team

| Member | Role | Location |
|--------|------|----------|
| Member A | Flutter UI, Riverpod, Charts, PDF, Demo Video | Patna, Bihar |
| Member B (You) | Firebase, Cloud Functions, Gemini, Fairness Metrics | Patna, Bihar |

**Sprint:** 13–16 April 2026 | **Submission:** 24 April 2026

---

## 📄 License

Apache 2.0 — See [LICENSE](LICENSE)

---

*BiasGuard — "Detect. Explain. Fix. Make AI Decisions Fair for Everyone."*
