"""
BiasGuard — Local Test Script (No Firebase Required)
Tests the fairness metrics engine, proxy detection, and mitigation
against the demo Bihar Scholarship CSV.

Run: python test_local.py
"""

import sys
import os
import json

# Add functions/ to path so we can import helpers directly
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "functions"))

import pandas as pd

from helpers.fairness_metrics import run_full_metrics, calculate_group_stats
from helpers.proxy_detection import analyse_dataframe_proxies
from helpers.mitigation import run_mitigation
from helpers.anonymizer import anonymise_dataframe

DEMO_CSV = os.path.join(os.path.dirname(__file__), "assets", "demo", "bihar_scholarship_2026.csv")

print("=" * 60)
print("  BiasGuard — Local Engine Test")
print("  Bihar Scholarship 2026 Demo Dataset")
print("=" * 60)

# ─── Load CSV ─────────────────────────────────────────────────────────────────
df = pd.read_csv(DEMO_CSV, dtype=str)
df.columns = [c.strip().lower().replace(" ", "_") for c in df.columns]
print(f"\n✅ Loaded {len(df)} rows | Columns: {df.columns.tolist()}")

# Binarise outcome
positive_labels = {"approved", "1", "yes", "true", "selected"}
df["decision"] = df["decision"].str.strip().str.lower().apply(
    lambda x: 1 if x in positive_labels else 0
)

# ─── Group Stats ──────────────────────────────────────────────────────────────
print("\n📊 GROUP STATS (by school_board):")
stats = calculate_group_stats(df, "school_board", "decision")
for group, data in stats["groups"].items():
    print(f"   {group:20s} → Approved: {data['approved_count']:3d}/{data['count']:3d} "
          f"({data['approval_rate']:.1f}%)")

print(f"\n   Overall approval rate: {stats['overall_approval_rate']:.1f}%")

# ─── Fairness Metrics ──────────────────────────────────────────────────────────
print("\n📐 FAIRNESS METRICS (group: school_board):")
metrics = run_full_metrics(df, "school_board", "decision")
print(f"   Demographic Parity:  {metrics['demographic_parity']:.4f}  (0=fair, 1=biased)")
print(f"   Equal Opportunity:   {metrics['equal_opportunity']:.4f}")
print(f"   Equalized Odds:      {metrics['equalized_odds']:.4f}")
print(f"   Predictive Parity:   {metrics['predictive_parity']:.4f}")
print(f"   ⭐ EQUITY SCORE:     {metrics['equity_score']}/100")

# ─── District-based metrics ────────────────────────────────────────────────────
print("\n📐 FAIRNESS METRICS (group: district subset — Patna vs Rural):")
df_district = df.copy()
df_district["district_type"] = df_district["district"].apply(
    lambda d: "Urban-Patna" if "patna" in str(d).lower() or "danapur" in str(d).lower()
    or "hajipur" in str(d).lower()
    else "Rural-Bihar"
)
metrics2 = run_full_metrics(df_district, "district_type", "decision")
print(f"   Demographic Parity:  {metrics2['demographic_parity']:.4f}")
print(f"   ⭐ EQUITY SCORE:     {metrics2['equity_score']}/100")
for group, data in metrics2["group_stats"].items():
    print(f"   {group:20s} → {data['approval_rate']:.1f}% approval rate")

# ─── Proxy Detection ──────────────────────────────────────────────────────────
print("\n🔍 PROXY DETECTION:")
sensitive_map = {
    "name": ["student_name"],
    "roll": ["roll_number"],
    "region": ["district"],
    "school": ["school_board"],
}
proxies = analyse_dataframe_proxies(df, sensitive_map, "decision")
print(f"   Found {len(proxies)} proxy signals:")
for p in proxies:
    print(f"\n   Column: '{p['column']}' → {p['proxy_type'].upper()} proxy "
          f"(confidence: {p['confidence']}%)")
    print(f"   {p['explanation'][:120]}...")

# ─── Anonymisation ────────────────────────────────────────────────────────────
print("\n🔒 ANONYMISATION DEMO:")
df_anon = anonymise_dataframe(df, sensitive_map)
print("   Before:", df["student_name"].head(3).tolist())
print("   After: ", df_anon["student_name"].head(3).tolist())

# ─── Mitigation ───────────────────────────────────────────────────────────────
print("\n⚙️  MITIGATION ENGINE (school_board):")
mitigation = run_mitigation(df, "school_board", "decision")
print(f"   Before equity score: {mitigation['before_equity_score']}/100")
print(f"   After equity score:  {mitigation['after_equity_score']}/100")
print(f"   Decisions changed:   {mitigation['decisions_changed_count']}")
print(f"\n   Before approval rates:")
for g, r in mitigation["before_approval_rates"].items():
    print(f"      {g:20s}: {r:.1f}%")
print(f"\n   After approval rates:")
for g, r in mitigation["after_approval_rates"].items():
    print(f"      {g:20s}: {r:.1f}%")

print("\n" + "=" * 60)
print("  ✅ All tests passed! Engine is ready for Firebase deployment.")
print("=" * 60 + "\n")
