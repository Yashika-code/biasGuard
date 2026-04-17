"""
BiasGuard — Firestore Writer
All Firestore read/write helpers with structured paths matching Member A's schema.
"""

import logging
from datetime import datetime, timezone
from typing import Dict, Any, Optional

from google.cloud import firestore

logger = logging.getLogger(__name__)

db = firestore.Client(project="biasguard-42ac2")


# ─── Path helpers ─────────────────────────────────────────────────────────────

def _scan_ref(uid: str, scan_id: str):
    return db.collection("users").document(uid).collection("scans").document(scan_id)


def _metrics_ref(uid: str, scan_id: str):
    return _scan_ref(uid, scan_id).collection("data").document("metrics")


def _analysis_ref(uid: str, scan_id: str):
    return _scan_ref(uid, scan_id).collection("data").document("analysis")


def _proxies_ref(uid: str, scan_id: str):
    return _scan_ref(uid, scan_id).collection("data").document("proxies")


def _mitigation_ref(uid: str, scan_id: str):
    return _scan_ref(uid, scan_id).collection("data").document("mitigation")


# ─── Status helpers ───────────────────────────────────────────────────────────

def set_scan_status(uid: str, scan_id: str, status: str, error: str = None):
    """Update the top-level scan document with processing status."""
    data = {"status": status, "updated_at": datetime.now(timezone.utc)}
    if error:
        data["error"] = error
    _scan_ref(uid, scan_id).set(data, merge=True)


# ─── Writers ──────────────────────────────────────────────────────────────────

def write_metrics(uid: str, scan_id: str, dataset_name: str, row_count: int,
                   detected_sensitive_columns: list, metrics: Dict[str, Any]):
    """
    Write CF1 (parse_and_calculate_metrics) output to Firestore.
    Path: /users/{uid}/scans/{scan_id}/data/metrics
    """
    doc = {
        "dataset_name": dataset_name,
        "uploaded_at": datetime.now(timezone.utc),
        "row_count": row_count,
        "detected_sensitive_columns": detected_sensitive_columns,
        "group_stats": metrics.get("group_stats", {}),
        "overall_approval_rate": metrics.get("overall_approval_rate", 0),
        "demographic_parity": metrics.get("demographic_parity", 0),
        "equal_opportunity": metrics.get("equal_opportunity", 0),
        "equalized_odds": metrics.get("equalized_odds", 0),
        "predictive_parity": metrics.get("predictive_parity", 0),
        "equity_score": metrics.get("equity_score", 0),
        "status": "complete",
    }
    _metrics_ref(uid, scan_id).set(doc)
    set_scan_status(uid, scan_id, "metrics_complete")
    logger.info(f"Metrics written for scan {scan_id}")


def write_analysis(uid: str, scan_id: str, gemini_result: Dict[str, Any],
                    proxy_findings: list):
    """
    Write CF2 (gemini_analysis) output to Firestore.
    Path: /users/{uid}/scans/{scan_id}/data/analysis
    """
    doc = {
        "explanation_en": gemini_result.get("explanation_en", ""),
        "explanation_hi": gemini_result.get("explanation_hi", ""),
        "root_causes": gemini_result.get("root_causes", []),
        "proxy_features": gemini_result.get("proxy_features", []),
        "mitigation_suggestion": gemini_result.get("mitigation_suggestion", ""),
        "counterfactual_hint": gemini_result.get("counterfactual_hint", ""),
        "severity": gemini_result.get("severity", "medium"),
        "india_specific_flags": gemini_result.get("india_specific_flags", []),
        "rule_based_proxies": proxy_findings,
        "status": "complete",
    }
    _analysis_ref(uid, scan_id).set(doc)
    set_scan_status(uid, scan_id, "analysis_complete")
    logger.info(f"Analysis written for scan {scan_id}")


def write_proxies(uid: str, scan_id: str, proxy_findings: list,
                   gemini_proxies: Optional[list] = None):
    """
    Write combined proxy detection results to Firestore.
    Path: /users/{uid}/scans/{scan_id}/data/proxies
    """
    all_proxies = proxy_findings.copy()
    if gemini_proxies:
        # Merge Gemini-detected proxies (deduplicate by column name)
        existing_cols = {p["column"] for p in proxy_findings}
        for gp in gemini_proxies:
            if gp.get("column") not in existing_cols:
                all_proxies.append(gp)

    doc = {
        "proxy_columns": all_proxies,
        "proxy_count": len(all_proxies),
        "status": "complete",
    }
    _proxies_ref(uid, scan_id).set(doc)
    logger.info(f"Proxies written for scan {scan_id}: {len(all_proxies)} found")


def write_mitigation(uid: str, scan_id: str, mitigation_result: Dict[str, Any]):
    """
    Write mitigation engine output to Firestore.
    Path: /users/{uid}/scans/{scan_id}/data/mitigation
    """
    _mitigation_ref(uid, scan_id).set(mitigation_result)
    set_scan_status(uid, scan_id, "mitigation_complete")
    logger.info(f"Mitigation written for scan {scan_id}")


# ─── Readers ──────────────────────────────────────────────────────────────────

def read_metrics(uid: str, scan_id: str) -> Optional[Dict]:
    """Read metrics document from Firestore."""
    doc = _metrics_ref(uid, scan_id).get()
    return doc.to_dict() if doc.exists else None


def read_scan_metadata(uid: str, scan_id: str) -> Optional[Dict]:
    """Read the top-level scan document."""
    doc = _scan_ref(uid, scan_id).get()
    return doc.to_dict() if doc.exists else None


def check_scan_count_today(uid: str) -> int:
    """Count scans created by user today for rate limiting."""
    today = datetime.now(timezone.utc).date()
    scans = (db.collection("users").document(uid)
               .collection("scans")
               .where("uploaded_at", ">=", datetime(today.year, today.month, today.day,
                                                     tzinfo=timezone.utc))
               .stream())
    return sum(1 for _ in scans)
