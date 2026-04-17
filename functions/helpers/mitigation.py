"""
BiasGuard — Mitigation Engine
Implements reweighting-based bias mitigation:
1. Compute per-group approval rates.
2. Compute target rate (mean of all group rates).
3. Reweight each group's decision probabilities toward the target.
4. Re-threshold at 0.5 to produce new binary decisions.
5. Return before/after metrics for comparison.
"""

import numpy as np
import pandas as pd
from typing import Dict, Any

from helpers.fairness_metrics import run_full_metrics


def reweight_decisions(df: pd.DataFrame, group_col: str, outcome_col: str) -> pd.DataFrame:
    """
    Apply group reweighting to reduce disparity.

    For each group:
        scale_factor = target_rate / current_rate (clamped [0.1, 3.0])
    Then re-threshold scaled probabilities at 0.5.

    Args:
        df: DataFrame with binary outcome column
        group_col: sensitive attribute column
        outcome_col: binary decision column (0/1)

    Returns:
        New DataFrame with mitigated decisions in outcome_col.
    """
    df = df.copy()
    groups = df[group_col].unique()

    # Calculate current approval rate per group
    group_rates = df.groupby(group_col)[outcome_col].mean()
    target_rate = group_rates.mean()  # Equalized target

    # Build a continuous score: 1 → approved probability, 0 → rejected probability
    # We simulate a soft probability by adding small noise so reweighting has effect
    np.random.seed(42)
    score = df[outcome_col].astype(float) + np.random.normal(0, 0.1, len(df))
    score = score.clip(0.01, 0.99)
    df["_score"] = score

    # Reweight
    mitigated_scores = df["_score"].copy()
    for group in groups:
        mask = df[group_col] == group
        current_rate = group_rates.get(group, 0.5)
        if current_rate < 0.001:
            continue
        scale = target_rate / current_rate
        scale = max(0.1, min(3.0, scale))  # clamp
        mitigated_scores[mask] = (df.loc[mask, "_score"] * scale).clip(0, 1)

    df["_mitigated_decision"] = (mitigated_scores >= 0.5).astype(int)
    df.drop(columns=["_score"], inplace=True)

    return df


def run_mitigation(df: pd.DataFrame, group_col: str, outcome_col: str) -> Dict[str, Any]:
    """
    Full mitigation pipeline — returns before/after metrics for Firestore.

    Returns:
        Dict with all fields required by Member A's Flutter mitigation schema.
    """
    # Before metrics
    before_metrics = run_full_metrics(df, group_col, outcome_col)

    # Apply reweighting
    df_mitigated = reweight_decisions(df, group_col, outcome_col)

    # Swap in mitigated decisions
    df_new = df_mitigated.copy()
    original_decisions = df_new[outcome_col].copy()
    df_new[outcome_col] = df_new["_mitigated_decision"]
    df_new.drop(columns=["_mitigated_decision"], inplace=True)

    # After metrics
    after_metrics = run_full_metrics(df_new, group_col, outcome_col)

    # Count changed decisions
    decisions_changed = int((df_new[outcome_col] != original_decisions).sum())

    # Build before/after approval rates per group
    before_rates = {
        g: stats["approval_rate"]
        for g, stats in before_metrics["group_stats"].items()
    }
    after_rates = {
        g: stats["approval_rate"]
        for g, stats in after_metrics["group_stats"].items()
    }

    return {
        "before_equity_score": before_metrics["equity_score"],
        "after_equity_score": after_metrics["equity_score"],
        "before_demographic_parity": before_metrics["demographic_parity"],
        "after_demographic_parity": after_metrics["demographic_parity"],
        "before_equal_opportunity": before_metrics["equal_opportunity"],
        "after_equal_opportunity": after_metrics["equal_opportunity"],
        "before_equalized_odds": before_metrics["equalized_odds"],
        "after_equalized_odds": after_metrics["equalized_odds"],
        "before_predictive_parity": before_metrics["predictive_parity"],
        "after_predictive_parity": after_metrics["predictive_parity"],
        "before_approval_rates": before_rates,
        "after_approval_rates": after_rates,
        "decisions_changed_count": decisions_changed,
        "total_count": len(df),
        "group_col": group_col,
        "status": "complete",
    }
