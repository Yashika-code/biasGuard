"""
BiasGuard — Fairness Metrics Engine
Calculates Demographic Parity, Equal Opportunity, Equalized Odds,
Predictive Parity, and a composite Equity Score (0–100).
"""

import pandas as pd
import numpy as np
from typing import Dict, Any


def calculate_group_stats(df: pd.DataFrame, group_col: str, outcome_col: str) -> Dict[str, Any]:
    """
    Calculate per-group approval counts and rates.

    Args:
        df: DataFrame with decision data
        group_col: column name for the sensitive attribute group
        outcome_col: column name for the binary decision (1 = approved, 0 = rejected)

    Returns:
        Dict with per-group stats and overall baseline
    """
    groups = df[group_col].unique()
    group_stats = {}

    for group in groups:
        mask = df[group_col] == group
        subset = df[mask]
        count = len(subset)
        approved = int(subset[outcome_col].sum())
        approval_rate = round(approved / count * 100, 2) if count > 0 else 0.0
        group_stats[str(group)] = {
            "count": count,
            "approved_count": approved,
            "rejected_count": count - approved,
            "approval_rate": approval_rate,
        }

    overall_approved = int(df[outcome_col].sum())
    overall_count = len(df)
    overall_rate = round(overall_approved / overall_count * 100, 2) if overall_count > 0 else 0.0

    return {
        "groups": group_stats,
        "overall_approval_rate": overall_rate,
        "total_count": overall_count,
        "total_approved": overall_approved,
    }


def demographic_parity(group_stats: Dict) -> float:
    """
    Demographic Parity Difference: max approval rate minus min approval rate across groups.
    0.0 = perfectly fair, higher = more biased.
    """
    rates = [g["approval_rate"] / 100.0 for g in group_stats["groups"].values()]
    if len(rates) < 2:
        return 0.0
    return round(max(rates) - min(rates), 4)


def equal_opportunity(
        df: pd.DataFrame, group_col: str, outcome_col: str,
        ground_truth_col: str = None) -> float:
    """
    Equal Opportunity Difference: difference in true positive rates (TPR) across groups.
    If no ground truth column, approximates using overall approval as proxy for qualification.
    """
    if ground_truth_col and ground_truth_col in df.columns:
        pos_mask = df[ground_truth_col] == 1
    else:
        # Approximate: top 60% by any numeric feature as "qualified" proxy
        numeric_cols = df.select_dtypes(include=[np.number]).columns.tolist()
        numeric_cols = [c for c in numeric_cols if c != outcome_col]
        if numeric_cols:
            score_col = numeric_cols[0]
            threshold = df[score_col].quantile(0.4)
            pos_mask = df[score_col] >= threshold
        else:
            # No usable ground truth — return demographic parity as proxy
            return 0.0

    groups = df[group_col].unique()
    tprs = []
    for group in groups:
        subset = df[df[group_col] == group]
        pos_subset = subset[pos_mask[subset.index]]
        if len(pos_subset) == 0:
            continue
        tpr = pos_subset[outcome_col].mean()
        tprs.append(tpr)

    if len(tprs) < 2:
        return 0.0
    return round(max(tprs) - min(tprs), 4)


def equalized_odds(
        df: pd.DataFrame, group_col: str, outcome_col: str,
        ground_truth_col: str = None) -> float:
    """
    Equalized Odds: average of TPR diff and FPR diff across groups.
    """
    if ground_truth_col and ground_truth_col in df.columns:
        pos_mask = df[ground_truth_col] == 1
        neg_mask = df[ground_truth_col] == 0
    else:
        numeric_cols = df.select_dtypes(include=[np.number]).columns.tolist()
        numeric_cols = [c for c in numeric_cols if c != outcome_col]
        if numeric_cols:
            score_col = numeric_cols[0]
            threshold = df[score_col].quantile(0.4)
            pos_mask = df[score_col] >= threshold
            neg_mask = ~pos_mask
        else:
            return 0.0

    groups = df[group_col].unique()
    tprs, fprs = [], []

    for group in groups:
        subset = df[df[group_col] == group]
        pos_subset = subset[pos_mask[subset.index]]
        neg_subset = subset[neg_mask[subset.index]]

        if len(pos_subset) > 0:
            tprs.append(pos_subset[outcome_col].mean())
        if len(neg_subset) > 0:
            fprs.append(neg_subset[outcome_col].mean())

    tpr_diff = round(max(tprs) - min(tprs), 4) if len(tprs) >= 2 else 0.0
    fpr_diff = round(max(fprs) - min(fprs), 4) if len(fprs) >= 2 else 0.0
    return round((tpr_diff + fpr_diff) / 2, 4)


def predictive_parity(
        df: pd.DataFrame, group_col: str, outcome_col: str,
        ground_truth_col: str = None) -> float:
    """
    Predictive Parity: difference in precision (PPV) across groups.
    Precision = TP / (TP + FP) = among those approved, fraction actually qualified.
    """
    if ground_truth_col and ground_truth_col in df.columns:
        qualified_col = ground_truth_col
    else:
        numeric_cols = df.select_dtypes(include=[np.number]).columns.tolist()
        numeric_cols = [c for c in numeric_cols if c != outcome_col]
        if numeric_cols:
            score_col = numeric_cols[0]
            threshold = df[score_col].quantile(0.4)
            df = df.copy()
            df["_qualified"] = (df[score_col] >= threshold).astype(int)
            qualified_col = "_qualified"
        else:
            return 0.0

    groups = df[group_col].unique()
    precisions = []

    for group in groups:
        subset = df[df[group_col] == group]
        approved_subset = subset[subset[outcome_col] == 1]
        if len(approved_subset) == 0:
            continue
        precision = approved_subset[qualified_col].mean()
        precisions.append(precision)

    if len(precisions) < 2:
        return 0.0
    return round(max(precisions) - min(precisions), 4)


def compute_equity_score(dp: float, eo: float, eodds: float, pp: float) -> int:
    """
    Composite India-weighted Equity Score (0–100).
    Higher = fairer. Weights: DP 35%, EO 30%, EOdds 20%, PP 15%.
    """
    weighted_disparity = (dp * 0.35) + (eo * 0.30) + (eodds * 0.20) + (pp * 0.15)
    score = 100 - (weighted_disparity * 100)
    return max(0, min(100, int(round(score))))


def run_full_metrics(
        df: pd.DataFrame, group_col: str, outcome_col: str,
        ground_truth_col: str = None) -> Dict[str, Any]:
    """
    Run all four fairness metrics and compute the equity score.

    Returns a dict ready to be written to Firestore.
    """
    stats = calculate_group_stats(df, group_col, outcome_col)

    dp = demographic_parity(stats)
    eo = equal_opportunity(df, group_col, outcome_col, ground_truth_col)
    eodds = equalized_odds(df, group_col, outcome_col, ground_truth_col)
    pp = predictive_parity(df, group_col, outcome_col, ground_truth_col)
    eq_score = compute_equity_score(dp, eo, eodds, pp)

    return {
        "group_stats": stats["groups"],
        "overall_approval_rate": stats["overall_approval_rate"],
        "total_count": stats["total_count"],
        "demographic_parity": dp,
        "equal_opportunity": eo,
        "equalized_odds": eodds,
        "predictive_parity": pp,
        "equity_score": eq_score,
    }
