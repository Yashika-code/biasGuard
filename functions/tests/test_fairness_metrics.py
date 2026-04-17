"""
BiasGuard — Test Suite: Fairness Metrics Engine
Run: pytest functions/tests/test_fairness_metrics.py -v
"""

import pandas as pd
import pytest

from helpers.fairness_metrics import (
    calculate_group_stats,
    demographic_parity,
    compute_equity_score,
    run_full_metrics,
)


# ─── Fixtures ─────────────────────────────────────────────────────────────────

@pytest.fixture
def perfectly_fair_df():
    """Dataset with equal approval rates across both groups (50% each)."""
    return pd.DataFrame({
        "group": ["A"] * 100 + ["B"] * 100,
        "marks": [80] * 200,
        "decision": ([1, 0] * 50) + ([1, 0] * 50),
    })


@pytest.fixture
def heavily_biased_df():
    """Dataset with extreme bias: Group A 90%, Group B 10%."""
    return pd.DataFrame({
        "group": ["Urban"] * 100 + ["Rural"] * 100,
        "marks": [80] * 200,
        "decision": ([1] * 90 + [0] * 10) + ([1] * 10 + [0] * 90),
    })


@pytest.fixture
def multigroup_df():
    """Dataset with 4 groups at different approval rates."""
    groups = ["General"] * 100 + ["OBC"] * 100 + ["SC"] * 100 + ["ST"] * 100
    marks = [85] * 400
    decisions = (
        [1] * 88 + [0] * 12 +   # General: 88%
        [1] * 65 + [0] * 35 +   # OBC: 65%
        [1] * 35 + [0] * 65 +   # SC: 35%
        [1] * 20 + [0] * 80     # ST: 20%
    )
    return pd.DataFrame({"group": groups, "marks": marks, "decision": decisions})


@pytest.fixture
def small_df():
    """Minimal 10-row dataset."""
    return pd.DataFrame({
        "group": ["A", "A", "A", "A", "A", "B", "B", "B", "B", "B"],
        "marks": [80, 75, 90, 85, 70, 78, 72, 88, 65, 82],
        "decision": [1, 1, 1, 1, 0, 1, 0, 1, 0, 0],
    })


# ─── Group Stats Tests ────────────────────────────────────────────────────────

class TestCalculateGroupStats:
    def test_basic_counts(self, heavily_biased_df):
        stats = calculate_group_stats(heavily_biased_df, "group", "decision")
        assert stats["groups"]["Urban"]["count"] == 100
        assert stats["groups"]["Rural"]["count"] == 100
        assert stats["groups"]["Urban"]["approved_count"] == 90
        assert stats["groups"]["Rural"]["approved_count"] == 10

    def test_approval_rates(self, heavily_biased_df):
        stats = calculate_group_stats(heavily_biased_df, "group", "decision")
        assert stats["groups"]["Urban"]["approval_rate"] == pytest.approx(90.0)
        assert stats["groups"]["Rural"]["approval_rate"] == pytest.approx(10.0)

    def test_overall_rate(self, perfectly_fair_df):
        stats = calculate_group_stats(perfectly_fair_df, "group", "decision")
        assert stats["overall_approval_rate"] == pytest.approx(50.0)

    def test_single_group(self):
        df = pd.DataFrame({"group": ["A"] * 10, "decision": [1] * 7 + [0] * 3})
        stats = calculate_group_stats(df, "group", "decision")
        assert stats["groups"]["A"]["approval_rate"] == pytest.approx(70.0)

    def test_zero_approvals(self):
        df = pd.DataFrame({
            "group": ["A"] * 5 + ["B"] * 5,
            "decision": [0] * 5 + [1] * 5,
        })
        stats = calculate_group_stats(df, "group", "decision")
        assert stats["groups"]["A"]["approved_count"] == 0
        assert stats["groups"]["A"]["approval_rate"] == pytest.approx(0.0)


# ─── Demographic Parity Tests ─────────────────────────────────────────────────

class TestDemographicParity:
    def test_perfect_parity(self, perfectly_fair_df):
        stats = calculate_group_stats(perfectly_fair_df, "group", "decision")
        dp = demographic_parity(stats)
        assert dp == pytest.approx(0.0, abs=0.01)

    def test_extreme_bias(self, heavily_biased_df):
        stats = calculate_group_stats(heavily_biased_df, "group", "decision")
        dp = demographic_parity(stats)
        assert dp == pytest.approx(0.80, abs=0.01)

    def test_multigroup(self, multigroup_df):
        stats = calculate_group_stats(multigroup_df, "group", "decision")
        dp = demographic_parity(stats)
        # General(88%) - ST(20%) = 0.68
        assert dp == pytest.approx(0.68, abs=0.05)

    def test_single_group_returns_zero(self):
        df = pd.DataFrame({"group": ["A"] * 10, "decision": [1] * 7 + [0] * 3})
        stats = calculate_group_stats(df, "group", "decision")
        dp = demographic_parity(stats)
        assert dp == pytest.approx(0.0)


# ─── Equity Score Tests ───────────────────────────────────────────────────────

class TestEquityScore:
    def test_perfect_score(self):
        score = compute_equity_score(0.0, 0.0, 0.0, 0.0)
        assert score == 100

    def test_worst_score(self):
        score = compute_equity_score(1.0, 1.0, 1.0, 1.0)
        assert score == 0

    def test_clamped_no_negative(self):
        score = compute_equity_score(2.0, 2.0, 2.0, 2.0)
        assert score == 0

    def test_clamped_no_over_100(self):
        score = compute_equity_score(-0.5, 0.0, 0.0, 0.0)
        assert score == 100

    def test_moderate_bias_score(self):
        score = compute_equity_score(0.5, 0.0, 0.0, 0.0)
        assert 80 <= score <= 90

    def test_demo_dataset_score(self):
        score = compute_equity_score(0.85, 0.70, 0.60, 0.50)
        assert score < 50


# ─── Full Metrics Pipeline Tests ──────────────────────────────────────────────

class TestRunFullMetrics:
    def test_returns_all_keys(self, heavily_biased_df):
        result = run_full_metrics(heavily_biased_df, "group", "decision")
        for key in ["group_stats", "overall_approval_rate", "demographic_parity",
                    "equal_opportunity", "equalized_odds", "predictive_parity",
                    "equity_score"]:
            assert key in result

    def test_equity_score_range(self, heavily_biased_df):
        result = run_full_metrics(heavily_biased_df, "group", "decision")
        assert 0 <= result["equity_score"] <= 100

    def test_fair_dataset_high_score(self, perfectly_fair_df):
        result = run_full_metrics(perfectly_fair_df, "group", "decision")
        assert result["equity_score"] >= 85

    def test_biased_dataset_low_score(self, heavily_biased_df):
        result = run_full_metrics(heavily_biased_df, "group", "decision")
        assert result["equity_score"] < 50

    def test_small_dataset(self, small_df):
        result = run_full_metrics(small_df, "group", "decision")
        assert result is not None
        assert "equity_score" in result
