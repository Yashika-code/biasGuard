"""
BiasGuard — Member A Handoff Package
This file documents everything Member A needs to integrate with Member B's backend.
Read this before starting Day 2 Flutter work.
"""

# ══════════════════════════════════════════════════════════
# 1. FIREBASE SETUP (Do this first — both members need it)
# ══════════════════════════════════════════════════════════

# After Member B creates the Firebase project (biasguard-2026):
# In the Flutter project root (biasguard/):
#
#   flutterfire configure
#   → Select project: biasguard-2026
#   → This generates: lib/core/config/firebase_options.dart
#   → Commit that file to the repo

# ══════════════════════════════════════════════════════════
# 2. CLOUD FUNCTION URLs (after firebase deploy --only functions)
# ══════════════════════════════════════════════════════════

# Member B will share exact URLs at 10 PM sync. Format will be:
CF_BASE = "https://us-central1-biasguard-2026.cloudfunctions.net"
CF_PARSE_AND_CALCULATE  = f"{CF_BASE}/parseAndCalculateMetrics"
CF_GEMINI_ANALYSIS      = f"{CF_BASE}/geminiAnalysisAndMitigation"
CF_TRIGGER_MITIGATION   = f"{CF_BASE}/triggerMitigation"
CF_DIRECT_DECISION      = f"{CF_BASE}/getDirectFairDecision"

# ══════════════════════════════════════════════════════════
# 3. CSV UPLOAD FLOW — How to trigger CF1
# ══════════════════════════════════════════════════════════

# Step 1: Upload CSV to Firebase Storage
#   Path MUST be: uploads/{uid}/{scan_id}.csv
#   scan_id: generate a UUID in Flutter before upload
#
#   final scanId = const Uuid().v4();
#   final ref = FirebaseStorage.instance
#       .ref('uploads/${user.uid}/$scanId.csv');
#   await ref.putFile(file);

# Step 2: Call CF1 via HTTP POST
#   POST CF_PARSE_AND_CALCULATE
#   Body: {
#     "uid": "firebase_user_uid",
#     "scan_id": "the_uuid_you_generated",
#     "storage_path": "uploads/{uid}/{scan_id}.csv",
#     "dataset_name": "Bihar Scholarship 2026",
#     "use_case": "Scholarship Selection",
#     "anonymise": false
#   }

# Step 3: Start listening to Firestore immediately after upload
#   (CF1 writes results in ~5-10 seconds)
#   Listen to: /users/{uid}/scans/{scan_id}/data/metrics
#   Listen to: /users/{uid}/scans/{scan_id}/data/analysis
#   Listen to: /users/{uid}/scans/{scan_id}/data/proxies
#
#   Use scanId as the document ID — you already have it!

# Step 4: Call CF2 with the _cf2_context returned by CF1
#   POST CF_GEMINI_ANALYSIS
#   Body: response["_cf2_context"]  (just forward the whole object)

# ══════════════════════════════════════════════════════════
# 4. FIRESTORE FIELD NAMES — Wire these in Riverpod providers
# ══════════════════════════════════════════════════════════

METRICS_FIELDS = {
    "dataset_name":                  "String",
    "uploaded_at":                   "Timestamp",
    "row_count":                     "int",
    "detected_sensitive_columns":    "List<String>",
    "group_stats":                   "Map<String, Map>",  # {group: {count, approved_count, approval_rate}}
    "overall_approval_rate":         "double",
    "demographic_parity":            "double",   # 0.0 = fair, 1.0 = totally biased
    "equal_opportunity":             "double",
    "equalized_odds":                "double",
    "predictive_parity":             "double",
    "equity_score":                  "int",      # 0–100, higher = fairer
    "status":                        "String",   # 'processing' | 'complete' | 'error'
}

ANALYSIS_FIELDS = {
    "explanation_en":        "String",   # Plain English Gemini explanation
    "explanation_hi":        "String",   # Same in Hindi
    "root_causes":           "List<String>",
    "proxy_features":        "List<String>",   # Column names acting as proxies
    "mitigation_suggestion": "String",
    "severity":              "String",   # 'low' | 'medium' | 'high' | 'critical'
    "india_specific_flags":  "List<String>",
    "rule_based_proxies":    "List<Map>",  # Detailed proxy objects
    "status":                "String",
}

PROXIES_FIELDS = {
    "proxy_columns":  "List<Map>",   # [{column, proxy_type, confidence, explanation}]
    "proxy_count":    "int",
    "status":         "String",
}

MITIGATION_FIELDS = {
    "before_equity_score":       "int",
    "after_equity_score":        "int",
    "before_demographic_parity": "double",
    "after_demographic_parity":  "double",
    "before_equal_opportunity":  "double",
    "after_equal_opportunity":   "double",
    "before_approval_rates":     "Map<String, double>",  # {group: rate}
    "after_approval_rates":      "Map<String, double>",
    "decisions_changed_count":   "int",
    "status":                    "String",
}

# ══════════════════════════════════════════════════════════
# 5. FIX BIAS BUTTON — How to call CF3
# ══════════════════════════════════════════════════════════

# POST CF_TRIGGER_MITIGATION
# Body: {
#   "uid": "firebase_user_uid",
#   "scan_id": "the_scan_id",
#   "storage_path": "uploads/{uid}/{scan_id}.csv",
#   "group_col": "district",      ← from CF1 response or Firestore metrics
#   "outcome_col": "decision"     ← from CF1 response
# }
#
# Listen to Firestore /data/mitigation for real-time chart update

# ══════════════════════════════════════════════════════════
# 6. DIRECT FAIR DECISION — How to call CF4
# ══════════════════════════════════════════════════════════

# Option A: Call CF4 (Python/Firestore, saves history)
# POST CF_DIRECT_DECISION
# Body: {
#   "uid": "firebase_user_uid",
#   "scenario": "Applicant has 78% marks from rural Bihar...",
#   "save_to_firestore": true
# }

# Option B: Call Gemini directly from Flutter (faster, no history)
# Use: lib/services/gemini_service.dart → GeminiService().getDirectFairDecision(scenario)
# This is the recommended approach for the counterfactual simulator

# ══════════════════════════════════════════════════════════
# 7. GEMINI_SERVICE.DART — Drop into lib/services/
# ══════════════════════════════════════════════════════════

# File location in repo: flutter_handoff/lib/services/gemini_service.dart
# Copy it to: biasguard/lib/services/gemini_service.dart
#
# Provides:
#   GeminiService().getDirectFairDecision(scenario)
#   GeminiService().getCounterfactualResult(original, changes, decision, useCase)
#   GeminiService().getAuditCounterfactual(groupColumn, fromValue, toValue, rate, useCase)

# ══════════════════════════════════════════════════════════
# 8. DEMO DATASET BUTTON
# ══════════════════════════════════════════════════════════

# The demo CSV is at: assets/demo/bihar_scholarship_2026.csv
# For the "Use Demo Dataset" button, Member B will also upload it to Firebase Storage:
#   gs://biasguard-2026.appspot.com/demo/bihar_scholarship_2026.csv
# Flutter: use this hardcoded storage path + a fixed scan_id ('demo-bihar-2026')
# Member A just needs to pass storage_path = "demo/bihar_scholarship_2026.csv"

# ══════════════════════════════════════════════════════════
# 9. EQUITY SCORE DISPLAY GUIDELINES
# ══════════════════════════════════════════════════════════

EQUITY_SCORE_COLORS = {
    "0-30":   "#FF3B3B",  # Critical — red
    "31-50":  "#FF8C00",  # High — orange
    "51-70":  "#FFD700",  # Medium — yellow
    "71-85":  "#6FCF97",  # Low — light green
    "86-100": "#27AE60",  # Fair — green
}

EQUITY_SCORE_LABELS = {
    "0-30":   "CRITICAL BIAS",
    "31-50":  "HIGH BIAS",
    "51-70":  "MODERATE BIAS",
    "71-85":  "LOW BIAS",
    "86-100": "FAIR",
}
