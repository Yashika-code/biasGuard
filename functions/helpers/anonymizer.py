"""
BiasGuard — Data Anonymiser
Replaces personally identifiable information in the DataFrame before Gemini analysis.
Only applied when user enables the privacy toggle.
"""

import hashlib
import pandas as pd
from typing import List


def _hash_id(value: str, prefix: str = "ID") -> str:
    """Create a one-way hashed anonymised ID."""
    digest = hashlib.sha256(str(value).encode()).hexdigest()[:8].upper()
    return f"{prefix}-{digest}"


def anonymise_names(df: pd.DataFrame, name_cols: List[str]) -> pd.DataFrame:
    """Replace full names with initials (e.g. 'Rahul Kumar Paswan' → 'R.K.P.')."""
    df = df.copy()
    for col in name_cols:
        def to_initials(name):
            parts = str(name).strip().split()
            return ".".join(p[0].upper() for p in parts if p) + "." if parts else "ANON"
        df[col] = df[col].apply(to_initials)
    return df


def anonymise_roll_numbers(df: pd.DataFrame, roll_cols: List[str]) -> pd.DataFrame:
    """Replace roll numbers with hashed IDs, preserving the first 2 digits (district prefix)."""
    df = df.copy()
    for col in roll_cols:
        def partial_hash(roll):
            roll = str(roll).strip()
            prefix = roll[:2] if len(roll) >= 2 else roll
            hashed = hashlib.sha256(roll.encode()).hexdigest()[:6].upper()
            return f"{prefix}-{hashed}"
        df[col] = df[col].apply(partial_hash)
    return df


def anonymise_districts(df: pd.DataFrame, district_cols: List[str]) -> pd.DataFrame:
    """Replace exact district names with Rural/Urban/Peri-Urban tags."""
    RURAL_DISTRICTS = {
        "sitamarhi", "sheohar", "supaul", "madhepura", "araria", "kishanganj",
        "katihar", "purnea", "saharsa", "khagaria", "sheikhpura", "lakhisarai",
        "arwal", "jehanabad", "banka", "jamui", "nawada", "gaya rural",
    }
    URBAN_DISTRICTS = {"patna", "muzaffarpur", "bhagalpur", "gaya", "darbhanga"}

    df = df.copy()
    for col in district_cols:
        def tag_district(d):
            d_lower = str(d).lower().strip()
            if d_lower in RURAL_DISTRICTS:
                return "Rural"
            if d_lower in URBAN_DISTRICTS:
                return "Urban"
            return "Peri-Urban"
        df[col] = df[col].apply(tag_district)
    return df


def anonymise_dataframe(df: pd.DataFrame, sensitive_map: dict) -> pd.DataFrame:
    """
    Apply full anonymisation pipeline based on the detected sensitive columns.

    Args:
        df: Input DataFrame
        sensitive_map: Output from csv_parser.detect_sensitive_columns()

    Returns:
        Anonymised DataFrame safe for Gemini sample sharing
    """
    df = df.copy()

    if "name" in sensitive_map:
        df = anonymise_names(df, sensitive_map["name"])

    if "roll" in sensitive_map:
        df = anonymise_roll_numbers(df, sensitive_map["roll"])

    if "region" in sensitive_map:
        district_cols = [c for c in sensitive_map["region"] if "district" in c.lower()]
        if district_cols:
            df = anonymise_districts(df, district_cols)

    return df
