import pandas as pd

def run_full_metrics(df, group_col, outcome_col):
    df = df.copy()

    df[outcome_col] = pd.to_numeric(df[outcome_col], errors="coerce").fillna(0)

    groups = df[group_col].dropna().unique()

    stats = {}

    rates = []

    for g in groups:
        sub = df[df[group_col] == g]

        count = len(sub)
        approved = int(sub[outcome_col].sum())

        rate = approved / count if count > 0 else 0

        rates.append(rate)

        stats[str(g)] = {
            "count": count,
            "approved_count": approved,
            "rejected_count": count - approved,
            "approval_rate": round(rate * 100, 2),
        }

    dp = max(rates) - min(rates) if len(rates) >= 2 else 0

    score = int(max(0, min(100, round(100 - dp * 100))))

    return {
        "group_stats": stats,
        "overall_approval_rate": round(df[outcome_col].mean() * 100, 2),
        "total_count": len(df),
        "demographic_parity": round(dp, 4),
        "equal_opportunity": round(dp, 4),
        "equalized_odds": round(dp, 4),
        "predictive_parity": round(dp, 4),
        "equity_score": score,
    }