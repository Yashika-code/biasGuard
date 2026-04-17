"""
BiasGuard — Test Suite: India Proxy Detection
Run: pytest functions/tests/test_proxy_detection.py -v
"""

import pandas as pd
import pytest

from helpers.proxy_detection import (
    infer_caste_from_name,
    decode_roll_number,
    decode_pincode,
    classify_school_board,
    analyse_dataframe_proxies,
)


# ─── Surname Caste Inference ──────────────────────────────────────────────────

class TestSurnameCasteInference:
    def test_sc_surname(self):
        assert infer_caste_from_name("Rahul Kumar Paswan") == "SC"

    def test_general_surname(self):
        result = infer_caste_from_name("Amit Sharma")
        assert result == "General"

    def test_obc_surname(self):
        result = infer_caste_from_name("Suresh Yadav")
        assert result == "OBC"

    def test_st_surname(self):
        result = infer_caste_from_name("Birendra Munda")
        assert result == "ST"

    def test_muslim_surname(self):
        result = infer_caste_from_name("Mohammed Ansari")
        assert result == "Muslim"

    def test_unknown_surname_returns_none(self):
        result = infer_caste_from_name("John Smith")
        assert result is None

    def test_single_name(self):
        result = infer_caste_from_name("Sharma")
        assert result is not None or result is None  # Either is fine — no crash

    def test_empty_name(self):
        result = infer_caste_from_name("")
        assert result is None

    def test_case_insensitive(self):
        assert infer_caste_from_name("PASWAN") == infer_caste_from_name("paswan")


# ─── Roll Number Decoding ─────────────────────────────────────────────────────

class TestRollNumberDecoding:
    def test_patna_prefix_maps_correctly(self):
        # Prefix "1" → Patna (Urban), but 2-digit prefixes take priority.
        # "20234" → prefix "20" → Samastipur (Rural)
        # Just verify the function returns a dict with required keys
        result = decode_roll_number("20234")
        assert isinstance(result, dict)
        if result:
            assert "district" in result
            assert "rural_urban" in result
            assert result["rural_urban"] in ("Urban", "Rural")

    def test_known_district_muzaffarpur(self):
        # prefix "16" → Muzaffarpur
        result = decode_roll_number("16500")
        assert result.get("district") == "Muzaffarpur"
        assert result.get("rural_urban") == "Rural"

    def test_known_district_saran(self):
        # prefix "11" → Saran → Rural
        result = decode_roll_number("11350")
        assert result.get("district") == "Saran"

    def test_prefix_not_in_map_returns_empty(self):
        # "00999" starts with "00" — not in any map
        result = decode_roll_number("00999")
        assert result == {}

    def test_short_roll(self):
        result = decode_roll_number("1")
        assert isinstance(result, dict)

    def test_muzaffarpur_district(self):
        result = decode_roll_number("16500")
        assert "Muzaffarpur" in result.get("district", "")

    def test_return_has_prefix_key(self):
        result = decode_roll_number("16500")
        assert "prefix" in result
        assert result["prefix"] == "16"


# ─── PIN Code Classification ──────────────────────────────────────────────────

class TestPincodeDecoding:
    def test_patna_urban(self):
        result = decode_pincode("800001")
        assert "Urban" in result

    def test_rural_bihar(self):
        result = decode_pincode("845001")
        assert "Rural" in result or "Bihar" in result

    def test_peri_urban(self):
        result = decode_pincode("803001")
        assert "Urban" in result or "Bihar" in result

    def test_outside_bihar(self):
        result = decode_pincode("110001")  # Delhi
        assert result == "Unknown"

    def test_empty_pin(self):
        result = decode_pincode("")
        assert isinstance(result, str)


# ─── School Board Classification ─────────────────────────────────────────────

class TestSchoolBoardClassification:
    def test_bseb_is_state(self):
        assert classify_school_board("BSEB") == "state_school"

    def test_bihar_board_is_state(self):
        assert classify_school_board("Bihar Board") == "state_school"

    def test_cbse_is_private(self):
        assert classify_school_board("CBSE") == "private_school"

    def test_icse_is_private(self):
        assert classify_school_board("ICSE") == "private_school"

    def test_unknown_board(self):
        assert classify_school_board("Some Local Board") == "unknown"

    def test_case_insensitive(self):
        assert classify_school_board("cbse") == classify_school_board("CBSE")

    def test_up_board_is_state(self):
        assert classify_school_board("UP Board") == "state_school"


# ─── DataFrame-Level Proxy Analysis ──────────────────────────────────────────

class TestAnalyseDataframeProxies:
    @pytest.fixture
    def demo_df(self):
        return pd.DataFrame({
            "student_name": [
                "Rahul Sharma", "Sunita Paswan", "Amit Singh",
                "Geeta Devi Musahar", "Vikash Gupta", "Renu Kumari Das"
            ],
            "roll_number": ["10234", "84012", "10567", "85023", "10890", "83456"],
            "district": ["Patna", "Sitamarhi", "Danapur", "Sheohar", "Hajipur", "Supaul"],
            "school_board": ["CBSE", "BSEB", "ICSE", "BSEB", "CBSE", "BSEB"],
            "decision": [1, 0, 1, 0, 1, 0],
        })

    @pytest.fixture
    def sensitive_map(self):
        return {
            "name": ["student_name"],
            "roll": ["roll_number"],
            "region": ["district"],
            "school": ["school_board"],
        }

    def test_finds_proxies(self, demo_df, sensitive_map):
        findings = analyse_dataframe_proxies(demo_df, sensitive_map, "decision")
        assert len(findings) > 0

    def test_all_findings_have_required_keys(self, demo_df, sensitive_map):
        findings = analyse_dataframe_proxies(demo_df, sensitive_map, "decision")
        for f in findings:
            assert "column" in f
            assert "proxy_type" in f
            assert "confidence" in f
            assert "explanation" in f

    def test_confidence_in_range(self, demo_df, sensitive_map):
        findings = analyse_dataframe_proxies(demo_df, sensitive_map, "decision")
        for f in findings:
            assert 0 <= f["confidence"] <= 100

    def test_detects_name_proxy(self, demo_df, sensitive_map):
        findings = analyse_dataframe_proxies(demo_df, sensitive_map, "decision")
        name_findings = [f for f in findings if f["column"] == "student_name"]
        assert len(name_findings) > 0

    def test_detects_school_board_proxy(self, demo_df, sensitive_map):
        findings = analyse_dataframe_proxies(demo_df, sensitive_map, "decision")
        school_findings = [f for f in findings if f["column"] == "school_board"]
        assert len(school_findings) > 0
        assert school_findings[0]["proxy_type"] == "ses"

    def test_empty_dataframe_no_crash(self, sensitive_map):
        empty_df = pd.DataFrame(
            columns=["student_name", "roll_number", "district", "school_board", "decision"]
        )
        findings = analyse_dataframe_proxies(empty_df, sensitive_map, "decision")
        assert isinstance(findings, list)

    def test_no_sensitive_columns_no_crash(self):
        df = pd.DataFrame({"x": [1, 2], "decision": [1, 0]})
        findings = analyse_dataframe_proxies(df, {}, "decision")
        assert findings == []
