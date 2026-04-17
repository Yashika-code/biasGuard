"""
BiasGuard — Test Suite: Anonymizer
Run: pytest functions/tests/test_anonymizer.py -v
"""

import pandas as pd

from helpers.anonymizer import (
    anonymise_names,
    anonymise_roll_numbers,
    anonymise_districts,
    anonymise_dataframe,
)


class TestAnonymiseNames:
    def test_basic_initials(self):
        df = pd.DataFrame({"name": ["Rahul Kumar Sharma"]})
        result = anonymise_names(df, ["name"])
        assert result["name"].iloc[0] == "R.K.S."

    def test_single_name(self):
        df = pd.DataFrame({"name": ["Sunita"]})
        result = anonymise_names(df, ["name"])
        assert result["name"].iloc[0] == "S."

    def test_original_not_mutated(self):
        df = pd.DataFrame({"name": ["Rahul Paswan"]})
        original = df["name"].copy()
        anonymise_names(df, ["name"])
        pd.testing.assert_series_equal(df["name"], original)

    def test_uppercase_initials(self):
        df = pd.DataFrame({"name": ["amit singh"]})
        result = anonymise_names(df, ["name"])
        assert result["name"].iloc[0] == "A.S."


class TestAnonymiseRollNumbers:
    def test_preserves_district_prefix(self):
        df = pd.DataFrame({"roll": ["10234"]})
        result = anonymise_roll_numbers(df, ["roll"])
        assert result["roll"].iloc[0].startswith("10")

    def test_output_is_hashed(self):
        df = pd.DataFrame({"roll": ["10234"]})
        result = anonymise_roll_numbers(df, ["roll"])
        assert result["roll"].iloc[0] != "10234"

    def test_same_input_same_output(self):
        df1 = pd.DataFrame({"roll": ["10234"]})
        df2 = pd.DataFrame({"roll": ["10234"]})
        r1 = anonymise_roll_numbers(df1, ["roll"])
        r2 = anonymise_roll_numbers(df2, ["roll"])
        assert r1["roll"].iloc[0] == r2["roll"].iloc[0]

    def test_different_inputs_different_outputs(self):
        df = pd.DataFrame({"roll": ["10234", "10235"]})
        result = anonymise_roll_numbers(df, ["roll"])
        assert result["roll"].iloc[0] != result["roll"].iloc[1]


class TestAnonymiseDistricts:
    def test_patna_is_urban(self):
        df = pd.DataFrame({"district": ["Patna"]})
        result = anonymise_districts(df, ["district"])
        assert result["district"].iloc[0] == "Urban"

    def test_sitamarhi_is_rural(self):
        df = pd.DataFrame({"district": ["Sitamarhi"]})
        result = anonymise_districts(df, ["district"])
        assert result["district"].iloc[0] == "Rural"

    def test_case_insensitive(self):
        df1 = pd.DataFrame({"district": ["PATNA"]})
        df2 = pd.DataFrame({"district": ["patna"]})
        r1 = anonymise_districts(df1, ["district"])
        r2 = anonymise_districts(df2, ["district"])
        assert r1["district"].iloc[0] == r2["district"].iloc[0]

    def test_unknown_district_peri_urban(self):
        df = pd.DataFrame({"district": ["XYZUnknown"]})
        result = anonymise_districts(df, ["district"])
        assert result["district"].iloc[0] == "Peri-Urban"


class TestAnonymiseDataframe:
    def test_full_pipeline(self):
        df = pd.DataFrame({
            "student_name": ["Rahul Kumar Sharma", "Sunita Paswan"],
            "roll_number": ["10234", "84012"],
            "district": ["Patna", "Sitamarhi"],
            "decision": [1, 0],
        })
        sensitive_map = {
            "name": ["student_name"],
            "roll": ["roll_number"],
            "region": ["district"],
        }
        result = anonymise_dataframe(df, sensitive_map)
        assert result["student_name"].iloc[0] != "Rahul Kumar Sharma"
        assert result["roll_number"].iloc[0] != "10234"
        assert result["district"].iloc[0] in ["Urban", "Rural", "Peri-Urban"]
        assert result["decision"].tolist() == [1, 0]
