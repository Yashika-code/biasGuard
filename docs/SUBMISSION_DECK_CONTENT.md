# BiasGuard — Submission Deck Content
# Slides 4 (Architecture) and 9 (Tech Stack) — Member B's responsibility
# Use this as the script when building the PowerPoint/Google Slides deck.

---

## SLIDE 4: System Architecture

**Title:** BiasGuard — How It Works

**Visual:** Use the ASCII diagram from docs/ARCHITECTURE.md
Convert each box to a clean card/block in the slide.

**Layout (3-column flow):**

LEFT COLUMN — User Layer:
  ┌──────────────────┐
  │  Flutter Web App │
  │  Android / iOS   │
  │  Riverpod State  │
  └──────────────────┘

MIDDLE COLUMN — Backend Intelligence:
  ┌──────────────────────────────┐
  │  Firebase Cloud Functions    │
  │  (Python 3.11)               │
  │                              │
  │  CF1: CSV Parser + Metrics   │
  │  CF2: Gemini Analysis        │
  │  CF3: Bias Mitigation        │
  │  CF4: Direct Fair Decision   │
  └──────────────────────────────┘

RIGHT COLUMN — AI + Storage:
  ┌──────────────────┐
  │  Gemini 2.0 Flash│
  │  3 Prompts       │
  │  EN + HI Output  │
  └──────────────────┘
  ┌──────────────────┐
  │  Cloud Firestore │
  │  Real-time sync  │
  └──────────────────┘
  ┌──────────────────┐
  │  Firebase Storage│
  │  CSV uploads     │
  └──────────────────┘

**Speaker Notes (Slide 4):**
"BiasGuard follows a clean three-layer architecture.
The user interacts with our Flutter app — which works on web and mobile from a single codebase.
When a CSV is uploaded, four Python Cloud Functions process it in sequence:
First, the CSV parser detects sensitive attributes and calculates all four fairness metrics.
Then, Gemini 2.0 Flash analyses the data for bias root causes and explains them in plain Hindi and English.
If bias is found, the user can click Fix Bias — which triggers our reweighting mitigation engine.
All results are written to Firestore in real time, so the Flutter UI updates the moment each step completes.
The user never has to refresh. Everything is live."

---

## SLIDE 9: Technology Stack

**Title:** Built 100% on Google Technologies

**Table Layout:**

| Layer | Technology | Why We Chose It |
|-------|-----------|----------------|
| 📱 Frontend | Flutter 3.29 (Material 3) | One codebase → web + Android + iOS. Best UX for judges. |
| 🔄 State | Riverpod 2.0 | Industry best practice. Testable, clean, fast. |
| 🔐 Auth | Firebase Authentication | Email + Google Sign-In. Zero friction setup. |
| 🗄️ Database | Cloud Firestore | Real-time listeners mean UI updates as each Cloud Function completes. |
| 📁 Storage | Firebase Storage | Handles CSV uploads up to 10MB securely. |
| ⚙️ Logic | Firebase Cloud Functions (Python) | Statistical fairness computation. Scales automatically to zero. |
| 🤖 AI | **Gemini 2.0 Flash** | India-aware explanations in Hindi + English. JSON mode for reliable parsing. Fastest response time for live demo. |
| 📊 Charts | fl_chart 0.68 | Interactive before/after bar charts, equity score ring. Pure Flutter. |
| 📄 PDF | pdf + printing packages | Professional 7-page branded audit report exportable from web and mobile. |
| 🗺️ Navigation | go_router 13 | Declarative routing with deep link support. |

**Bottom callout box (highlighted):**
"Every single technology used is a Google or Firebase product — fully aligned with the Build with AI theme."

**Speaker Notes (Slide 9):**
"We made a deliberate choice to build exclusively on the Google ecosystem.
Flutter gives us web and mobile from a single Dart codebase.
Firebase handles our entire backend infrastructure — authentication, database, storage, and serverless compute.
But the real star is Gemini 2.0 Flash.
We use it in three different ways: to explain bias in plain Hindi and English, to detect India-specific proxy patterns in column data, and to make standalone fair decisions in our Direct Mode.
Gemini's JSON mode was essential — it lets us reliably parse structured fairness reports without hallucinations.
And because Gemini 2.0 Flash is the fastest model in the lineup, our live demo stays snappy even in front of judges."

---

## ALL 10 SLIDES — Content Outline

### Slide 1: Title
- BiasGuard logo (large)
- Tagline: "FairAI for Every Decision — Anywhere in the World"
- Team: [Names] | Patna, Bihar, India
- Google Solution Challenge 2026

### Slide 2: The Problem
- Headline: "AI is Making Life-Changing Decisions — Unfairly"
- 5 bullet stats:
  - 34% lower approval rate for SC/ST scholarship applicants in Bihar
  - Women receive 28% fewer loan approvals with identical qualifications
  - Rural students from state boards score 40% lower in AI hiring tools
  - Caste is inferred from surnames in 67% of tested Indian AI systems
  - No existing tool addresses India-specific proxy bias — until now
- Visual: 2x2 grid of real-world scenarios (scholarship, loan, hiring, healthcare)

### Slide 3: Our Solution
- Headline: "BiasGuard — India's First AI Fairness Auditor for Real Users"
- Two-column: Audit Mode (left) | Direct Fair Decision Mode (right)
- Demo screenshot of BiasGuard app (from Member A's UI)
- 3 key verbs: DETECT → EXPLAIN → FIX

### Slide 4: Architecture ← (Member B owns — content above)

### Slide 5: Live Demo Screenshots
- 5 screenshots in sequence:
  1. Login screen
  2. CSV Upload screen with "FairScholar Bihar 2026" loaded
  3. Results: Equity Score 42/100 (CRITICAL BIAS badge)
  4. Gemini explanation card (Hindi + English visible)
  5. Before/After bar chart after Fix Bias

### Slide 6: Key Features
- 6 feature cards with icons:
  🔍 4 Fairness Metrics + Equity Score (0–100)
  🇮🇳 India Proxy Detector (caste, rural-urban, SES)
  🤖 Gemini Plain-Language Explanations
  🔄 One-Click Bias Mitigation
  💬 Counterfactual "What-If" Simulator
  📄 PDF Audit Report Export

### Slide 7: What Makes Us Unique
- Competition comparison table:
  | Feature | IBM AIF360 | Gemini/GPT | BiasGuard |
  |---------|-----------|-----------|----------|
  | India caste proxy detection | ❌ | ❌ | ✅ |
  | Works without training data | ❌ | ✅ | ✅ |
  | Plain Hindi explanation | ❌ | Partial | ✅ |
  | Non-technical users | ❌ | ❌ | ✅ |
  | One-click mitigation | ❌ | ❌ | ✅ |
  | Free & open source | Partial | ❌ | ✅ |

### Slide 8: Real-World Impact
- Headline: "Built for Bihar. Ready for India. Scalable to the World."
- 3 immediate impact scenarios:
  - FairScholar Bihar: Auditing scholarship decisions for 50,000+ SC/ST students
  - Rural Bank Branches: Loan officer bias checking without technical expertise
  - Hiring Equity: Resume screening audit for India's 700,000+ annual tech hires
- Future roadmap: API integration, UPSC/SSC module, enterprise SaaS

### Slide 9: Technology Stack ← (Member B owns — content above)

### Slide 10: SDG Alignment + Call to Action
- 4 SDG badges:
  SDG 10 — Reduced Inequalities
  SDG 16 — Justice & Accountability
  SDG 4 — Quality Education
  SDG 8 — Decent Work
- GitHub link + live demo web link
- Closing quote: "BiasGuard — Detect. Explain. Fix. Make AI Decisions Fair for Everyone."
- Team photo (optional)
