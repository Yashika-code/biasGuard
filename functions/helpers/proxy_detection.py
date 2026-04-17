"""
BiasGuard — India-Specific Proxy Detection Engine
Detects caste, rural-urban, socio-economic status, and gender proxies
from column names and sample values using a surname dictionary, pin code maps,
school board heuristics, and Gemini 2.0 as a fallback.
"""

import json
import re
from pathlib import Path
from typing import Dict, List, Any, Optional
import pandas as pd

# ─── Load static data files ────────────────────────────────────────────────────

_DATA_DIR = Path(__file__).parent.parent / "data"

def _load_json(filename: str) -> dict:
    path = _DATA_DIR / filename
    if path.exists():
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)
    return {}

SURNAME_CASTE_MAP: Dict[str, str] = _load_json("surname_caste_map.json")
DISTRICT_RURAL_MAP: Dict[str, str] = _load_json("district_rural_map.json")



# ─── School Board Heuristics ───────────────────────────────────────────────────

STATE_BOARDS = {
    "bseb", "bihar board", "up board", "mp board", "rbse", "tbse",
    "wbbse", "wbchse", "tsbse", "bseap", "gseb", "pseb", "hbse",
    "tn board", "tn matric", "chhattisgarh board", "jharkhand board"
}

PRIVATE_NATIONAL_BOARDS = {
    "cbse", "icse", "isc", "ib", "cambridge", "igcse"
}

def classify_school_board(board_value: str) -> str:
    """Returns 'state_school' (lower SES proxy) or 'private_school' (higher SES proxy)."""
    val = str(board_value).lower().strip()
    for sb in STATE_BOARDS:
        if sb in val:
            return "state_school"
    for pb in PRIVATE_NATIONAL_BOARDS:
        if pb in val:
            return "private_school"
    return "unknown"


# ─── Roll Number District Decoder ─────────────────────────────────────────────

BIHAR_ROLL_PREFIX_MAP = {
    "1": "Patna (Urban)", "2": "Nalanda", "3": "Bhojpur",
    "4": "Rohtas", "5": "Kaimur", "6": "Gaya",
    "7": "Jehanabad", "8": "Aurangabad", "9": "Nawada",
    "10": "Arwal", "11": "Saran", "12": "Siwan",
    "13": "Gopalganj", "14": "West Champaran", "15": "East Champaran",
    "16": "Muzaffarpur", "17": "Sitamarhi", "18": "Sheohar",
    "19": "Vaishali", "20": "Samastipur", "21": "Darbhanga",
    "22": "Madhubani", "23": "Supaul", "24": "Saharsa",
    "25": "Madhepura", "26": "Bhagalpur", "27": "Banka",
    "28": "Munger", "29": "Lakhisarai", "30": "Sheikhpura",
    "31": "Begusarai", "32": "Khagaria", "33": "Purnea",
    "34": "Katihar", "35": "Araria", "36": "Kishanganj",
    "37": "Sehara",
}

URBAN_DISTRICT_CODES = {"1"}  # Patna

def decode_roll_number(roll: str) -> Dict[str, str]:
    """Attempt to decode Bihar-format roll number to district and rural/urban tag."""
    roll = str(roll).strip()
    for prefix in sorted(BIHAR_ROLL_PREFIX_MAP.keys(), key=len, reverse=True):
        if roll.startswith(prefix):
            district = BIHAR_ROLL_PREFIX_MAP[prefix]
            rural_tag = "Urban" if prefix in URBAN_DISTRICT_CODES else "Rural"
            return {"district": district, "rural_urban": rural_tag, "prefix": prefix}
    return {}


# ─── Pin Code Decoder ─────────────────────────────────────────────────────────

def decode_pincode(pin: str) -> str:
    """Basic Bihar pin code rural-urban classification."""
    pin = str(pin).strip()
    if pin.startswith("800") or pin.startswith("801"):
        return "Urban-Patna"
    if re.match(r"^80[2-9]", pin):
        return "Peri-Urban-Bihar"
    if re.match(r"^8[1-5]", pin):
        return "Rural-Bihar"
    if re.match(r"^84|^85", pin):
        return "Rural-North-Bihar"
    return "Unknown"


# ─── Surname Caste Inference ──────────────────────────────────────────────────

def infer_caste_from_name(full_name: str) -> Optional[str]:
    """
    Extract surname from a full name and look it up in the caste map.
    Returns social group tag or None.
    """
    parts = str(full_name).strip().split()
    if not parts:
        return None
    # Try last word as surname, then second-to-last
    candidates = [parts[-1].lower()]
    if len(parts) > 1:
        candidates.append(parts[-2].lower())
    for surname in candidates:
        if surname in SURNAME_CASTE_MAP:
            return SURNAME_CASTE_MAP[surname]
    return None


# ─── DataFrame-Level Proxy Analysis ───────────────────────────────────────────

def analyse_dataframe_proxies(df: pd.DataFrame, sensitive_map: Dict[str, List[str]],
                               outcome_col: str) -> List[Dict[str, Any]]:
    """
    Run rule-based proxy detection on all detected sensitive columns.
    Returns a list of proxy findings.
    """
    findings = []

    # --- Name / caste proxy via surnames ---
    name_cols = sensitive_map.get("name", [])
    for col in name_cols:
        sample_names = df[col].dropna().head(30).tolist()
        inferred = [infer_caste_from_name(n) for n in sample_names]
        inferred = [i for i in inferred if i]
        if inferred:
            unique_groups = list(set(inferred))
            findings.append({
                "column": col,
                "proxy_type": "caste",
                "confidence": min(95, 60 + len(unique_groups) * 5),
                "explanation": (
                    f"'{col}' contains Indian names from which surnames infer social groups: "
                    f"{unique_groups[:5]}. This allows a model to use caste as an implicit signal."
                ),
                "sample_inference": inferred[:5],
            })

    # --- Roll number → district → rural/urban proxy ---
    roll_cols = sensitive_map.get("roll", [])
    for col in roll_cols:
        sample_rolls = df[col].dropna().head(10).tolist()
        decoded = [decode_roll_number(str(r)) for r in sample_rolls]
        decoded = [d for d in decoded if d]
        if decoded:
            findings.append({
                "column": col,
                "proxy_type": "region",
                "confidence": 80,
                "explanation": (
                    f"'{col}' follows Bihar roll number format where the first 1–2 digits "
                    f"encode district codes, effectively revealing rural/urban origin. "
                    f"Example: {decoded[:2]}"
                ),
                "sample_inference": [d.get("rural_urban") for d in decoded[:5]],
            })

    # --- PIN code → rural/urban proxy ---
    region_cols = sensitive_map.get("region", [])
    for col in region_cols:
        if "pin" in col.lower():
            sample_pins = df[col].dropna().head(20).tolist()
            decoded_pins = [decode_pincode(str(p)) for p in sample_pins]
            unique_tags = list(set(decoded_pins))
            findings.append({
                "column": col,
                "proxy_type": "region",
                "confidence": 85,
                "explanation": (
                    f"'{col}' contains Bihar PIN codes that reveal urban/rural location. "
                    f"Detected zones: {unique_tags}. Models trained on this data learn to "
                    f"disadvantage rural applicants."
                ),
                "sample_inference": decoded_pins[:5],
            })

        # District name map lookup
        elif "district" in col.lower():
            sample_districts = df[col].dropna().head(20).str.lower().str.strip().tolist()
            rural_count = sum(1 for d in sample_districts
                              if DISTRICT_RURAL_MAP.get(d, "Unknown") == "Rural")
            if rural_count > 0:
                findings.append({
                    "column": col,
                    "proxy_type": "region",
                    "confidence": 90,
                    "explanation": (
                        f"'{col}' contains district names that serve as a rural/urban proxy. "
                        f"{rural_count} of 20 samples map to rural Bihar districts. "
                        f"AI models use this as an indirect socio-economic signal."
                    ),
                    "sample_inference": [DISTRICT_RURAL_MAP.get(d, "Unknown")
                                         for d in sample_districts[:5]],
                })

    # --- School board → SES proxy ---
    school_cols = sensitive_map.get("school", [])
    for col in school_cols:
        sample_boards = df[col].dropna().head(30).tolist()
        board_types = [classify_school_board(str(b)) for b in sample_boards]
        state_count = board_types.count("state_school")
        pvt_count = board_types.count("private_school")
        if state_count + pvt_count > 0:
            findings.append({
                "column": col,
                "proxy_type": "ses",
                "confidence": 88,
                "explanation": (
                    f"'{col}' contains school board names. State boards (e.g. BSEB) indicate "
                    f"government school background (lower SES). CBSE/ICSE indicate private "
                    f"school background (higher SES). Found {state_count} state-board and "
                    f"{pvt_count} private-board students in sample."
                ),
                "sample_inference": board_types[:5],
            })

    # --- Explicit caste column ---
    caste_cols = sensitive_map.get("caste", [])
    for col in caste_cols:
        sample_vals = df[col].dropna().value_counts().head(5).to_dict()
        findings.append({
            "column": col,
            "proxy_type": "caste",
            "confidence": 99,
            "explanation": (
                f"'{col}' is an explicit caste/category column. "
                f"Distribution: {sample_vals}. Direct use of caste in AI decisions is illegal "
                f"under Indian law and constitutes prohibited discrimination."
            ),
            "sample_inference": list(sample_vals.keys())[:5],
        })

    # --- Gender inference from name salutation ---
    for col in sensitive_map.get("name", []):
        sample_names = df[col].dropna().head(30).str.lower().tolist()
        female_signals = [n for n in sample_names if any(
            kw in n for kw in ["kumari", "devi", "ms ", "mrs ", "smt ", "bai",
                                "priya", "anita", "sunita", "rekha", "pooja"]
        )]
        if len(female_signals) > 2:
            findings.append({
                "column": col,
                "proxy_type": "gender",
                "confidence": 70,
                "explanation": (
                    f"'{col}' contains gender-coded names or salutations (e.g. Devi, Kumari, "
                    f"Smt). A model may infer gender from names, introducing gender bias."
                ),
                "sample_inference": female_signals[:5],
            })

    return findings
