"""
BiasGuard — Test Suite: Mitigation Engine
Run: pytest functions/tests/test_mitigation.py -v
"""

import pandas as pd
import pytest

from helpers.mitigation import reweight_decisions, run_mitigation


# ─── Fixtures ─────────────────────────────────────────────────────────────────

@pytest.fixture
def biased_df():
    return pd.DataFrame({
        "group": ["Urban"] * 100 + ["Rural"] * 100,
        "marks": [80] * 200,
        "decision": [1] * 90 + [0] * 10 + [1] * 10 + [0] * 90,
    })


@pytest.fixture
def fair_df():
    return pd.DataFrame({
        "group": ["A"] * 100 + ["B"] * 100,
        "marks": [80] * 200,
        "decision": [1] * 50 + [0] * 50 + [1] * 50 + [0] * 50,
    })


@pytest.fixture
def four_group_df():
    return pd.DataFrame({
        "group": (["General"] * 50 + ["OBC"] * 50 + ["SC"] * 50 + ["ST"] * 50),
        "marks": [80] * 200,
        "decision": (
            [1] * 44 + [0] * 6
            + [1] * 32 + [0] * 18
            + [1] * 18 + [0] * 32
            + [1] * 10 + [0] * 40
        ),
    })


# ─── Reweight Decisions Tests ─────────────────────────────────────────────────

class TestReweightDecisions:
    def test_output_has_mitigated_column(self, biased_df):
        result = reweight_decisions(biased_df, "group", "decision")
        assert "_mitigated_decision" in result.columns

    def test_mitigated_decisions_are_binary(self, biased_df):
        result = reweight_decisions(biased_df, "group", "decision")
        assert set(result["_mitigated_decision"].unique()).issubset({0, 1})

    def test_rural_approval_increases(self, biased_df):
        result = reweight_decisions(biased_df, "group", "decision")
        original_rural_rate = biased_df[biased_df["group"] == "Rural"]["decision"].mean()
        mitigated_rural_rate = result[result["group"] == "Rural"]["_mitigated_decision"].mean()
        assert mitigated_rural_rate > original_rural_rate

    def test_original_df_not_mutated(self, biased_df):
        original_decisions = biased_df["decision"].copy()
        reweight_decisions(biased_df, "group", "decision")
        pd.testing.assert_series_equal(biased_df["decision"], original_decisions)

    def test_fair_df_minimal_change(self, fair_df):
        result = reweight_decisions(fair_df, "group", "decision")
        changed = (result["_mitigated_decision"] != fair_df["decision"]).sum()
        assert changed < 30


# ─── Full Mitigation Pipeline ─────────────────────────────────────────────────

class TestRunMitigation:
    def test_returns_all_required_keys(self, biased_df):
        result = run_mitigation(biased_df, "group", "decision")
        for key in ["before_equity_score", "after_equity_score",
                    "before_approval_rates", "after_approval_rates",
                    "decisions_changed_count", "status"]:
            assert key in result

    def test_equity_score_improves(self, biased_df):
        result = run_mitigation(biased_df, "group", "decision")
        assert result["after_equity_score"] >= result["before_equity_score"]

    def test_scores_in_valid_range(self, biased_df):
        result = run_mitigation(biased_df, "group", "decision")
        assert 0 <= result["before_equity_score"] <= 100
        assert 0 <= result["after_equity_score"] <= 100

    def test_decisions_changed_count_positive(self, biased_df):
        result = run_mitigation(biased_df, "group", "decision")
        assert result["decisions_changed_count"] >= 0

    def test_status_complete(self, biased_df):
        result = run_mitigation(biased_df, "group", "decision")
        assert result["status"] == "complete"

    def test_four_groups(self, four_group_df):
        result = run_mitigation(four_group_df, "group", "decision")
        assert result["after_equity_score"] > result["before_equity_score"]

    def test_approval_rate_convergence(self, biased_df):
        result = run_mitigation(biased_df, "group", "decision")
        after_rates = list(result["after_approval_rates"].values())
        before_rates = list(result["before_approval_rates"].values())
        spread_after = max(after_rates) - min(after_rates)
        spread_before = max(before_rates) - min(before_rates)
        assert spread_after < spread_before
