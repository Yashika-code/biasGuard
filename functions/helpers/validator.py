"""
BiasGuard — Input Validator
Validates all Cloud Function request bodies before processing.
Centralises error messaging for consistent 400/422 error responses.
"""

from typing import Dict, Any, Tuple, Optional


# ─── CF1 Validator ────────────────────────────────────────────────────────────

def validate_cf1_request(body: Dict[str, Any]) -> Tuple[bool, Optional[str]]:
    """
    Validate the request body for parseAndCalculateMetrics.
    Returns (is_valid, error_message).
    """
    if not body:
        return False, "Request body is empty or not valid JSON."

    uid = body.get("uid", "").strip()
    if not uid:
        return False, "Missing required field: 'uid' (Firebase user ID)."

    if len(uid) < 10 or len(uid) > 128:
        return False, "Invalid 'uid': must be 10–128 characters."

    storage_path = body.get("storage_path", "").strip()
    if not storage_path:
        return False, "Missing required field: 'storage_path'."

    if not (storage_path.endswith(".csv") or storage_path.endswith(".CSV")):
        return False, "Invalid 'storage_path': must point to a .csv file."

    if ".." in storage_path or storage_path.startswith("/"):
        return False, "Invalid 'storage_path': path traversal not allowed."

    dataset_name = body.get("dataset_name", "")
    if dataset_name and len(dataset_name) > 200:
        return False, "'dataset_name' must be under 200 characters."

    use_case = body.get("use_case", "")
    if use_case and len(use_case) > 200:
        return False, "'use_case' must be under 200 characters."

    return True, None


# ─── CF2 Validator ────────────────────────────────────────────────────────────

def validate_cf2_request(body: Dict[str, Any]) -> Tuple[bool, Optional[str]]:
    """
    Validate the request body for geminiAnalysisAndMitigation.
    """
    if not body:
        return False, "Request body is empty."

    for field in ["uid", "scan_id"]:
        if not body.get(field, "").strip():
            return False, f"Missing required field: '{field}'."

    storage_path = body.get("storage_path", "").strip()
    if not storage_path:
        return False, "Missing required field: 'storage_path'."

    if ".." in storage_path:
        return False, "Invalid 'storage_path': path traversal not allowed."

    return True, None


# ─── CF3 Validator ────────────────────────────────────────────────────────────

def validate_cf3_request(body: Dict[str, Any]) -> Tuple[bool, Optional[str]]:
    """
    Validate the request body for triggerMitigation.
    """
    if not body:
        return False, "Request body is empty."

    for field in ["uid", "scan_id", "storage_path", "group_col", "outcome_col"]:
        if not body.get(field, "").strip():
            return False, f"Missing required field: '{field}'."

    return True, None


# ─── CF4 Validator ────────────────────────────────────────────────────────────

def validate_cf4_request(body: Dict[str, Any]) -> Tuple[bool, Optional[str]]:
    """
    Validate the request body for getDirectFairDecision.
    """
    if not body:
        return False, "Request body is empty."

    scenario = body.get("scenario", "").strip()
    if not scenario:
        return False, "Missing required field: 'scenario'."

    if len(scenario) < 20:
        return False, ("'scenario' is too short (minimum 20 characters). "
                       "Please describe the decision scenario in more detail.")

    if len(scenario) > 5000:
        return False, ("'scenario' is too long (maximum 5000 characters). "
                       "Please provide a shorter description.")

    return True, None


# ─── Content Safety ───────────────────────────────────────────────────────────

_BLOCKED_PATTERNS = [
    "ignore previous instructions",
    "ignore all instructions",
    "you are now",
    "disregard your",
    "forget your instructions",
    "jailbreak",
    "pretend you are",
    "act as if",
    "system prompt",
]


def is_prompt_safe(text: str) -> Tuple[bool, Optional[str]]:
    """
    Basic prompt injection guard for user-submitted scenario text.
    Returns (is_safe, reason_if_unsafe).
    """
    text_lower = text.lower()
    for pattern in _BLOCKED_PATTERNS:
        if pattern in text_lower:
            return False, (f"The scenario contains disallowed content: '{pattern}'. "
                           f"Please describe a genuine decision scenario.")
    return True, None
