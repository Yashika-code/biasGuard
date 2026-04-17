"""
BiasGuard — CSV Parser & Column Auto-Detection
Downloads CSV from Firebase Storage, loads into pandas, auto-detects
sensitive attribute columns and the outcome (decision) column.
"""

import os
import io
import pandas as pd
from typing import Dict, List, Optional
from google.cloud import storage

# ─── Keywords for auto-detection ──────────────────────────────────────────────

OUTCOME_KEYWORDS = [
    "decision", "approved", "approval", "outcome", "result", "status",
    "selected", "admitted", "granted", "sanctioned", "passed", "cleared"
]

SENSITIVE_KEYWORDS = {
    "gender":  ["gender", "sex", "salutation", "title"],
    "region":  ["district", "pincode", "pin_code", "pin", "state", "region",
                "zone", "area", "village", "block", "taluka", "mandal"],
    "caste":   ["caste", "category", "sc_st", "reservation", "social_group",
                "community"],
    "income":  ["income", "salary", "bpl", "apl", "economic", "family_income",
                "annual_income"],
    "school":  ["school_board", "board", "school_type", "medium", "institute"],
    "name":    ["name", "student_name", "applicant_name", "full_name"],
    "roll":    ["roll", "roll_number", "roll_no", "application_no",
                "application_id", "reg_no"],
    "marks":   ["marks", "percentage", "score", "cgpa", "gpa", "grade",
                "percentile"],
}


# ─── Storage Download ──────────────────────────────────────────────────────────
def download_csv_from_storage(bucket_name: str, blob_path: str) -> pd.DataFrame:

    # Try LOCAL file first
    if os.path.exists(blob_path):
        print("Reading LOCAL CSV:", blob_path)
        df = pd.read_csv(blob_path, encoding="utf-8", dtype=str)

    else:
        print("Local file not found. Trying Firebase Storage...")
        client = storage.Client()
        bucket = client.bucket(bucket_name)
        blob = bucket.blob(blob_path)
        content = blob.download_as_bytes()
        df = pd.read_csv(io.BytesIO(content), encoding="utf-8", dtype=str)

    df.columns = [c.strip().lower().replace(" ", "_") for c in df.columns]

    return df

# ─── Column Detection ──────────────────────────────────────────────────────────

def detect_outcome_column(columns: List[str]) -> Optional[str]:
    """
    Find the most likely outcome/decision column.
    Returns the column name or None if not found.
    """
    for col in columns:
        for keyword in OUTCOME_KEYWORDS:
            if keyword in col.lower():
                return col
    return None


def detect_sensitive_columns(columns: List[str]) -> Dict[str, List[str]]:
    """
    Detect which columns map to which sensitive attribute category.
    Returns dict: {category: [list of matching column names]}
    """
    found: Dict[str, List[str]] = {}
    for category, keywords in SENSITIVE_KEYWORDS.items():
        matches = []
        for col in columns:
            for kw in keywords:
                if kw in col.lower():
                    matches.append(col)
                    break
        if matches:
            found[category] = matches
    return found


def detect_primary_group_column(df: pd.DataFrame, sensitive_map: Dict[str, List[str]],
                                 outcome_col: str) -> Optional[str]:
    """
    Among detected sensitive columns, pick the one most likely to show bias.
    Priority: caste > region > gender > income > school > others.
    Falls back to the column with the highest group variance in approval rate.
    """
    priority_order = ["caste", "region", "gender", "income", "school"]
    for category in priority_order:
        if category in sensitive_map and sensitive_map[category]:
            return sensitive_map[category][0]

    # Fallback: try all low-cardinality string columns
    string_cols = df.select_dtypes(include="object").columns.tolist()
    candidates = [c for c in string_cols if c != outcome_col and df[c].nunique() <= 15]

    best_col, best_var = None, -1.0
    for col in candidates:
        group_rates = df.groupby(col).apply(
            lambda x: pd.to_numeric(x[outcome_col], errors="coerce").mean()
        )
        if group_rates.std() > best_var:
            best_var = group_rates.std()
            best_col = col

    return best_col


def binarise_outcome(df: pd.DataFrame, outcome_col: str) -> pd.DataFrame:
    """
    Convert outcome column to binary (1 = approved/selected, 0 = rejected).
    Handles string labels like 'Yes'/'No', 'Approved'/'Rejected', '1'/'0'.
    """
    df = df.copy()
    col = df[outcome_col].str.strip().str.lower()

    positive_labels = {"1", "yes", "true", "approved", "selected", "admitted",
                       "granted", "sanctioned", "passed", "cleared", "accept"}
    df[outcome_col] = col.apply(lambda x: 1 if x in positive_labels else 0)
    return df


# ─── Full Parse Pipeline ───────────────────────────────────────────────────────

def parse_csv(bucket_name: str, blob_path: str) -> Dict:
    """
    Full CSV parse pipeline. Returns dict with:
    - df: cleaned DataFrame
    - outcome_col: detected decision column
    - group_col: primary sensitive attribute column
    - sensitive_map: all detected sensitive columns by category
    - row_count, column_names
    - parse_warnings: list of any issues noted
    """
    df = download_csv_from_storage(bucket_name, blob_path)
    columns = df.columns.tolist()
    warnings = []

    outcome_col = detect_outcome_column(columns)
    if outcome_col is None:
        # Last resort: pick the column with fewest unique values (likely binary)
        col_uniq = {c: df[c].nunique() for c in columns}
        outcome_col = min(col_uniq, key=col_uniq.get)
        warnings.append(f"No clear decision column found — using '{outcome_col}' as proxy.")

    df = binarise_outcome(df, outcome_col)
    sensitive_map = detect_sensitive_columns(columns)
    group_col = detect_primary_group_column(df, sensitive_map, outcome_col)

    if group_col is None:
        warnings.append("Could not detect a clear sensitive attribute column.")

    return {
        "df": df,
        "outcome_col": outcome_col,
        "group_col": group_col,
        "sensitive_map": sensitive_map,
        "row_count": len(df),
        "column_names": columns,
        "parse_warnings": warnings,
    }
