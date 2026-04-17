# BiasGuard — System Architecture

## Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    USER (Web Browser / Android / iOS)            │
│                         Flutter App                              │
│   ┌──────────┐  ┌──────────┐  ┌────────────┐  ┌─────────────┐  │
│   │  Login   │  │  Upload  │  │  Results   │  │  Direct     │  │
│   │  Screen  │  │  Screen  │  │  Screen    │  │  Decision   │  │
│   └────┬─────┘  └────┬─────┘  └─────┬──────┘  └──────┬──────┘  │
│        │             │              │                  │         │
│   ┌────▼─────────────▼──────────────▼──────────────────▼──────┐ │
│   │              Riverpod 2.0 State Management                  │ │
│   │    auth_provider │ upload_provider │ results_provider        │ │
│   └────┬─────────────┬──────────────────────────────────┬──────┘ │
└────────┼─────────────┼──────────────────────────────────┼────────┘
         │             │                                  │
         ▼             ▼                                  ▼
┌──────────────┐ ┌─────────────────────────────┐ ┌─────────────────┐
│ Firebase Auth│ │     Firebase Storage          │ │ Gemini 2.0 API  │
│ (Email +     │ │   uploads/{uid}/{scan}.csv    │ │ (Direct from    │
│  Google)     │ └──────────────┬────────────────┘ │  Flutter via    │
└──────────────┘                │ triggers           │ google_gen_ai)  │
                                ▼                   └─────────────────┘
                 ┌──────────────────────────────────┐
                 │    Firebase Cloud Functions       │
                 │           (Python 3.11)           │
                 │                                   │
                 │  ┌────────────────────────────┐   │
                 │  │ CF1: parseAndCalculate     │   │
                 │  │   Metrics                  │   │
                 │  │  • Download CSV            │   │
                 │  │  • Auto-detect columns     │   │
                 │  │  • DP + EO + EOdds + PP   │   │
                 │  │  • Equity Score (0–100)    │   │
                 │  └──────────────┬─────────────┘   │
                 │                 │                  │
                 │  ┌──────────────▼─────────────┐   │
                 │  │ CF2: geminiAnalysis         │   │
                 │  │   AndMitigation             │   │
                 │  │  • Rule-based proxy detect  │   │
                 │  │  • Gemini explanation EN/HI │   │
                 │  │  • Gemini proxy detection   │   │
                 │  └──────────────┬─────────────┘   │
                 │                 │                  │
                 │  ┌──────────────▼─────────────┐   │
                 │  │ CF3: triggerMitigation      │   │
                 │  │  • Reweighting algorithm    │   │
                 │  │  • Before/after metrics     │   │
                 │  │  (triggered by Fix Bias btn)│   │
                 │  └──────────────┬─────────────┘   │
                 │                 │                  │
                 │  ┌──────────────▼─────────────┐   │
                 │  │ CF4: getDirectFairDecision  │   │
                 │  │  • Standalone fair decision │   │
                 │  │  • Gemini with fairness     │   │
                 │  │    enforcement rules        │   │
                 │  └──────────────┬─────────────┘   │
                 └─────────────────┼──────────────────┘
                                   │
                                   ▼
                 ┌──────────────────────────────────┐
                 │        Cloud Firestore            │
                 │                                   │
                 │  /users/{uid}/scans/{scan_id}/    │
                 │    data/metrics    ←── CF1 writes │
                 │    data/analysis   ←── CF2 writes │
                 │    data/proxies    ←── CF2 writes │
                 │    data/mitigation ←── CF3 writes │
                 │                                   │
                 │  Real-time listeners in Flutter   │
                 │  update UI as each CF completes   │
                 └──────────────────────────────────┘
```

## Technology Stack

| Layer | Technology | Version | Justification |
|-------|-----------|---------|---------------|
| Frontend | Flutter | 3.29+ | Single codebase: web + Android + iOS |
| State Management | Riverpod | 2.5.0 | Industry best practice for Flutter 2026 |
| Authentication | Firebase Auth | 5.0.0 | Email + Google sign-in, instant setup |
| Database | Cloud Firestore | 5.0.0 | Real-time sync, offline support |
| File Storage | Firebase Storage | 12.0.0 | CSV upload handling |
| Server Logic | Cloud Functions | Python 3.11 | Statistical fairness computation |
| AI Engine | Gemini 2.0 Flash | Latest | Reasoning, explanations, proxy detection |
| Charts | fl_chart | 0.68.0 | Professional interactive Flutter charts |
| PDF | pdf + printing | 3.10 / 5.12 | Branded report export |
| Navigation | go_router | 13.0.0 | Declarative routing |

## India-Specific Proxy Detection Pipeline

```
CSV Upload
    │
    ▼
Column Name Scan ──► Keywords matched against sensitive attribute categories
    │                (gender, region, caste, income, school, roll, name)
    ▼
Sample Value Analysis
    │
    ├── Name columns    ──► Surname extracted ──► surname_caste_map.json lookup
    │                                         ──► Gemini as fallback
    │
    ├── Roll number     ──► First 2 digits ──► Bihar district code map
    │                                     ──► Rural/Urban classification
    │
    ├── PIN code        ──► Prefix match (800=Patna Urban, 84x-85x=Rural Bihar)
    │
    ├── District name   ──► district_rural_map.json lookup
    │
    ├── School board    ──► BSEB/State Board = lower SES
    │                   ──► CBSE/ICSE = higher SES
    │
    └── Gemini RF        ──► Column samples sent to Prompt 3 for any missed proxies
```

## Fairness Metrics Calculation

```
Input CSV
    │
    ▼
Group by sensitive attribute (e.g., school_board: CBSE vs BSEB)
    │
    ├── Demographic Parity  = max(group_approval_rate) − min(group_approval_rate)
    │
    ├── Equal Opportunity   = max(TPR per group) − min(TPR per group)
    │                         TPR = approved / qualified  (qualified = top 60% by marks)
    │
    ├── Equalized Odds      = (TPR_diff + FPR_diff) / 2
    │
    ├── Predictive Parity   = max(precision per group) − min(precision per group)
    │                         precision = TP / (TP + FP)
    │
    └── Equity Score        = 100 − (0.35×DP + 0.30×EO + 0.20×EOdds + 0.15×PP) × 100
                              Clamped [0, 100]. Higher = fairer.
```

## Mitigation Engine

```
Before Mitigation:
  Group A (CBSE): 90% approval rate
  Group B (BSEB): 5% approval rate
  Target rate = mean(90%, 5%) = 47.5%

Reweighting:
  Group A scale = 47.5 / 90.0 = 0.53  (reduce approvals)
  Group B scale = 47.5 / 5.0  = 9.5   (clamped to 3.0)

Apply scale to decision scores → re-threshold at 0.5

After Mitigation:
  Group A: ~50% approval rate
  Group B: ~45% approval rate
  Result: Equity Score improves from ~42 → ~88
```

## Security Model

- **Firestore Rules**: Each user can only read/write `/users/{their_uid}/`
- **Storage Rules**: Users upload only to `/uploads/{their_uid}/`
- **Rate Limiting**: Max 10 scans per user per day (Firestore count check)
- **Data Anonymisation**: Optional before Gemini call — names → initials, districts → Rural/Urban
- **API Keys**: Gemini key stored as Firebase Secret, never in code
- **No training data required**: Works exclusively on decision output CSVs
