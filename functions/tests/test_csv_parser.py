"""
BiasGuard — Test Suite: CSV Parser & Column Detection
Tests outcome column detection, sensitive attribute detection,
binarization, and the full parse pipeline (with mocked Storage).
Run: pytest functions/tests/test_csv_parser.py -v
"""

import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import io
import pandas as pd
import pytest
from unittest.mock import patch, MagicMock

from helpers.csv_parser import (
    detect_outcome_column,
    detect_sensitive_columns,
    detect_primary_group_column,
    binarise_outcome,
    download_csv_from_storage,
)


# ─── Outcome Column Detection ─────────────────────────────────────────────────

class TestDetectOutcomeColumn:
    def test_detects_decision(self):
        assert detect_outcome_column(["name", "marks", "decision"]) == "decision"

    def test_detects_approved(self):
        assert detect_outcome_column(["id", "score", "approved"]) == "approved"

    def test_detects_status(self):
        assert detect_outcome_column(["roll", "grade", "status"]) == "status"

    def test_detects_selected(self):
        assert detect_outcome_column(["applicant", "selected"]) == "selected"

    def test_returns_none_if_not_found(self):
        assert detect_outcome_column(["applicant_name", "district", "marks"]) is None

    def test_case_insensitive_colname(self):
        # Column names are lowercased before detection
        cols = [c.lower() for c in ["Name", "Marks", "Decision"]]
        assert detect_outcome_column(cols) == "decision"

    def test_partial_match(self):
        # 'approval_status' should match 'approval'
        assert detect_outcome_column(["name", "approval_status"]) == "approval_status"


# ─── Sensitive Column Detection ───────────────────────────────────────────────

class TestDetectSensitiveColumns:
    def test_detects_gender(self):
        result = detect_sensitive_columns(["name", "gender", "marks", "decision"])
        assert "gender" in result
        assert "gender" in result["gender"]

    def test_detects_district(self):
        result = detect_sensitive_columns(["student_name", "district", "score"])
        assert "region" in result

    def test_detects_school_board(self):
        result = detect_sensitive_columns(["roll", "school_board", "marks"])
        assert "school" in result

    def test_detects_roll_number(self):
        result = detect_sensitive_columns(["roll_number", "marks"])
        assert "roll" in result

    def test_detects_caste(self):
        result = detect_sensitive_columns(["caste", "marks", "decision"])
        assert "caste" in result

    def test_empty_columns(self):
        result = detect_sensitive_columns([])
        assert result == {}

    def test_no_sensitive_columns(self):
        result = detect_sensitive_columns(["x1", "x2", "x3"])
        assert result == {}

    def test_multiple_region_columns(self):
        result = detect_sensitive_columns(["district", "pincode", "state", "marks"])
        assert "region" in result
        assert len(result["region"]) >= 2


# ─── Binarise Outcome ─────────────────────────────────────────────────────────

class TestBinariseOutcome:
    def test_approved_string(self):
        df = pd.DataFrame({"decision": ["Approved", "Rejected", "Approved"]})
        result = binarise_outcome(df, "decision")
        assert result["decision"].tolist() == [1, 0, 1]

    def test_yes_no(self):
        df = pd.DataFrame({"decision": ["Yes", "No", "Yes"]})
        result = binarise_outcome(df, "decision")
        assert result["decision"].tolist() == [1, 0, 1]

    def test_numeric_strings(self):
        df = pd.DataFrame({"decision": ["1", "0", "1"]})
        result = binarise_outcome(df, "decision")
        assert result["decision"].tolist() == [1, 0, 1]

    def test_true_false(self):
        df = pd.DataFrame({"decision": ["true", "false", "true"]})
        result = binarise_outcome(df, "decision")
        assert result["decision"].tolist() == [1, 0, 1]

    def test_selected_string(self):
        df = pd.DataFrame({"decision": ["Selected", "Not Selected"]})
        result = binarise_outcome(df, "decision")
        assert result["decision"].tolist() == [1, 0]

    def test_original_df_not_mutated(self):
        df = pd.DataFrame({"decision": ["Approved", "Rejected"]})
        original = df["decision"].copy()
        binarise_outcome(df, "decision")
        pd.testing.assert_series_equal(df["decision"], original)

    def test_mixed_case(self):
        df = pd.DataFrame({"decision": ["APPROVED", "rejected", "Approved"]})
        result = binarise_outcome(df, "decision")
        assert result["decision"].tolist() == [1, 0, 1]


# ─── Mocked Storage Download ──────────────────────────────────────────────────

class TestDownloadCsvFromStorage:
    def test_returns_dataframe(self):
        csv_content = b"name,marks,decision\nRahul,85,Approved\nSunita,78,Rejected\n"
        mock_blob = MagicMock()
        mock_blob.download_as_bytes.return_value = csv_content
        mock_bucket = MagicMock()
        mock_bucket.blob.return_value = mock_blob
        mock_client = MagicMock()
        mock_client.bucket.return_value = mock_bucket

        with patch("helpers.csv_parser.storage.Client", return_value=mock_client):
            df = download_csv_from_storage("test-bucket", "test/path.csv")

        assert isinstance(df, pd.DataFrame)
        assert len(df) == 2
        assert "name" in df.columns

    def test_column_names_lowercased(self):
        csv_content = b"Student Name,Marks Percent,Decision\nRahul,85,Approved\n"
        mock_blob = MagicMock()
        mock_blob.download_as_bytes.return_value = csv_content
        mock_bucket = MagicMock()
        mock_bucket.blob.return_value = mock_blob
        mock_client = MagicMock()
        mock_client.bucket.return_value = mock_bucket

        with patch("helpers.csv_parser.storage.Client", return_value=mock_client):
            df = download_csv_from_storage("bucket", "path.csv")

        assert "student_name" in df.columns
        assert "marks_percent" in df.columns
