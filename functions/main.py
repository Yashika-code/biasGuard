"""
BiasGuard — Firebase Cloud Functions Entry Point
Registers three HTTP Cloud Functions:
  1. parseAndCalculateMetrics  — CF1: CSV parsing + fairness metrics
  2. geminiAnalysisAndMitigation — CF2: Gemini explanation + proxy analysis
  3. triggerMitigation          — CF3: On-demand 'Fix Bias' button handler
  4. getDirectFairDecision      — CF4: Standalone direct decision mode
"""

import logging
import os
import uuid
from datetime import datetime, timezone

import functions_framework
from flask import Request, jsonify

from helpers.csv_parser import parse_csv
from helpers.fairness_metrics import run_full_metrics
from helpers.proxy_detection import analyse_dataframe_proxies
from helpers.gemini_client import analyse_bias, detect_proxies_gemini, get_direct_fair_decision
from helpers.mitigation import run_mitigation
from helpers.anonymizer import anonymise_dataframe
from helpers.caching import download_and_hash_csv, get_cached_scan, store_cache_entry
from helpers.validator import (
    validate_cf1_request, validate_cf4_request, is_prompt_safe
)
from helpers.firestore_writer import (
    write_metrics, write_analysis, write_proxies, write_mitigation,
    check_scan_count_today, set_scan_status
)

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

FIREBASE_STORAGE_BUCKET = os.environ.get("FIREBASE_STORAGE_BUCKET", "biasguard-42ac2.appspot.com")
MAX_SCANS_PER_DAY = 10

# ─── CORS headers for Flutter Web ─────────────────────────────────────────────

CORS_HEADERS = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type, Authorization",
}


def cors_response(data: dict, status: int = 200):
    resp = jsonify(data)
    resp.status_code = status
    for k, v in CORS_HEADERS.items():
        resp.headers[k] = v
    return resp


def handle_options(request: Request):
    """Handle CORS preflight."""
    if request.method == "OPTIONS":
        resp = ("", 204, CORS_HEADERS)
        return resp
    return None


# ─── CF1: parse_and_calculate_metrics ─────────────────────────────────────────

@functions_framework.http
def parseAndCalculateMetrics(request: Request):
    """
    Triggered by Flutter when a CSV is uploaded to Firebase Storage.
    Expects JSON body: { uid, scan_id, storage_path, dataset_name, use_case }

    Flow:
    1. Download CSV from Storage
    2. Auto-detect columns
    3. Calculate all 4 fairness metrics + equity score
    4. Write to Firestore: /users/{uid}/scans/{scan_id}/data/metrics
    5. Trigger CF2 automatically
    """
    preflight = handle_options(request)
    if preflight:
        return preflight

    try:
        body = request.get_json(silent=True) or {}

        # Validate request
        is_valid, err = validate_cf1_request(body)
        if not is_valid:
            return cors_response({"error": err}, 400)

        uid = body.get("uid")
        scan_id = body.get("scan_id") or str(uuid.uuid4())
        storage_path = body.get("storage_path")
        dataset_name = body.get("dataset_name", "Unnamed Dataset")
        use_case = body.get("use_case", "General Decision Making")
        anonymise = body.get("anonymise", False)

        if not uid or not storage_path:
            return cors_response({"error": "Missing required fields: uid, storage_path"}, 400)

        # Rate limiting
        scan_count = check_scan_count_today(uid)
        if scan_count >= MAX_SCANS_PER_DAY:
            return cors_response({
                "error": f"Daily scan limit ({MAX_SCANS_PER_DAY}) reached. Try again tomorrow."
            }, 429)

        # ── Cache check — skip re-processing identical CSV uploads ──
        try:
            import io
            csv_bytes, csv_hash = download_and_hash_csv(FIREBASE_STORAGE_BUCKET, storage_path)
            cached_scan_id = get_cached_scan(uid, csv_hash)
            if cached_scan_id and cached_scan_id != scan_id:
                logger.info(f"Cache HIT — returning cached scan {cached_scan_id}")
                return cors_response({
                    "scan_id": cached_scan_id,
                    "status": "cached",
                    "message": "Identical dataset found in cache. Returning previous results.",
                    "cached": True,
                })
        except Exception as cache_err:
            logger.warning(f"Cache check failed (continuing without cache): {cache_err}")
            csv_bytes = None

        # Mark as processing
        set_scan_status(uid, scan_id, "processing")

        # Step 1: Parse CSV (reuse downloaded bytes if available)
        logger.info(f"Parsing CSV for uid={uid}, scan_id={scan_id}")
        if csv_bytes:
            import pandas as pd
            parsed_df = pd.read_csv(io.BytesIO(csv_bytes), encoding="utf-8", dtype=str)
            parsed_df.columns = [c.strip().lower().replace(" ", "_") for c in parsed_df.columns]
            # Pass pre-downloaded df directly
            from helpers.csv_parser import (
                detect_outcome_column, detect_sensitive_columns,
                detect_primary_group_column, binarise_outcome
            )
            columns = parsed_df.columns.tolist()
            warnings_list = []
            outcome_col = detect_outcome_column(columns)
            if outcome_col is None:
                col_uniq = {c: parsed_df[c].nunique() for c in columns}
                outcome_col = min(col_uniq, key=col_uniq.get)
                warnings_list.append(f"No clear decision column — using '{outcome_col}'.")
            parsed_df = binarise_outcome(parsed_df, outcome_col)
            sensitive_map = detect_sensitive_columns(columns)
            group_col = detect_primary_group_column(parsed_df, sensitive_map, outcome_col)
            parsed = {
                "df": parsed_df, "outcome_col": outcome_col,
                "group_col": group_col, "sensitive_map": sensitive_map,
                "row_count": len(parsed_df), "column_names": columns,
                "parse_warnings": warnings_list,
            }
        else:
            parsed = parse_csv(FIREBASE_STORAGE_BUCKET, storage_path)
        df = parsed["df"]
        outcome_col = parsed["outcome_col"]
        group_col = parsed["group_col"]
        sensitive_map = parsed["sensitive_map"]

        if group_col is None:
            set_scan_status(uid, scan_id, "error",
                            "Could not detect any sensitive attribute column in the CSV.")
            return cors_response({"error": "No sensitive attribute column detected."}, 422)

        # Step 2: Anonymise if requested
        if anonymise:
            df = anonymise_dataframe(df, sensitive_map)

        # Step 3: Fairness metrics
        logger.info(f"Calculating fairness metrics — group_col={group_col}")
        metrics = run_full_metrics(df, group_col, outcome_col)

        # Step 4: Detected sensitive columns list for Flutter display
        all_sensitive = []
        for cols in sensitive_map.values():
            all_sensitive.extend(cols)

        # Step 5: Write to Firestore
        write_metrics(uid, scan_id, dataset_name, parsed["row_count"],
                      all_sensitive, metrics)

        # Store cache entry for future duplicate uploads
        try:
            if csv_bytes:
                store_cache_entry(uid, csv_hash, scan_id)
        except Exception as cache_store_err:
            logger.warning(f"Cache store failed (non-fatal): {cache_store_err}")

        # Return enough info to trigger CF2 from Flutter OR let Flutter poll Firestore
        return cors_response({
            "scan_id": scan_id,
            "status": "metrics_complete",
            "row_count": parsed["row_count"],
            "group_col": group_col,
            "outcome_col": outcome_col,
            "equity_score": metrics["equity_score"],
            "demographic_parity": metrics["demographic_parity"],
            "parse_warnings": parsed["parse_warnings"],
            # Pass context to CF2
            "_cf2_context": {
                "uid": uid,
                "scan_id": scan_id,
                "use_case": use_case,
                "group_col": group_col,
                "outcome_col": outcome_col,
                "sensitive_map": {k: v for k, v in sensitive_map.items()},
                "overall_rate": metrics["overall_approval_rate"],
                "group_stats": metrics["group_stats"],
                "demographic_parity": metrics["demographic_parity"],
                "equity_score": metrics["equity_score"],
                "column_names": parsed["column_names"],
                "storage_path": storage_path,
                "anonymise": anonymise,
            }
        })

    except Exception as e:
        logger.exception(f"CF1 failed: {e}")
        if uid and scan_id:
            set_scan_status(uid, scan_id, "error", str(e))
        return cors_response({"error": "Internal server error", "detail": str(e)}, 500)


# ─── CF2: gemini_analysis_and_mitigation ──────────────────────────────────────

@functions_framework.http
def geminiAnalysisAndMitigation(request: Request):
    """
    Called immediately after CF1 completes.
    Expects JSON body: the _cf2_context dict returned by CF1.

    Flow:
    1. Rule-based proxy detection on the CSV
    2. Gemini call for explanation + additional proxy detection
    3. Write analysis + proxies to Firestore
    """
    preflight = handle_options(request)
    if preflight:
        return preflight

    try:
        body = request.get_json(silent=True) or {}
        uid = body.get("uid")
        scan_id = body.get("scan_id")
        use_case = body.get("use_case", "General")
        outcome_col = body.get("outcome_col")
        sensitive_map = body.get("sensitive_map", {})
        overall_rate = body.get("overall_rate", 50.0)
        group_stats = body.get("group_stats", {})
        demographic_parity = body.get("demographic_parity", 0.0)
        equity_score = body.get("equity_score", 50)
        column_names = body.get("column_names", [])
        storage_path = body.get("storage_path")
        anonymise = body.get("anonymise", False)

        if not uid or not scan_id:
            return cors_response({"error": "Missing uid or scan_id"}, 400)

        set_scan_status(uid, scan_id, "analysing")

        # Step 1: Re-download CSV for proxy detection
        from helpers.csv_parser import download_csv_from_storage
        df = download_csv_from_storage(FIREBASE_STORAGE_BUCKET, storage_path)
        if anonymise:
            df = anonymise_dataframe(df, sensitive_map)

        # Step 2: Rule-based proxy detection
        logger.info(f"Running proxy detection for scan {scan_id}")
        rule_proxies = analyse_dataframe_proxies(df, sensitive_map, outcome_col)

        # Step 3: Gemini analysis (explanation + additional proxy detection)
        logger.info(f"Calling Gemini for analysis — scan {scan_id}")
        gemini_result = analyse_bias(
            use_case=use_case,
            columns_list=column_names,
            group_stats=group_stats,
            overall_rate=overall_rate,
            demographic_parity=demographic_parity,
            equity_score=equity_score,
        )

        # Also ask Gemini to check column samples for proxy patterns
        col_samples = {}
        for col in column_names[:10]:  # limit for prompt size
            if col in df.columns:
                col_samples[col] = df[col].dropna().head(10).tolist()

        gemini_proxies_result = detect_proxies_gemini(col_samples)
        gemini_proxies = gemini_proxies_result.get("proxy_columns", [])

        # Step 4: Write to Firestore
        write_analysis(uid, scan_id, gemini_result, rule_proxies)
        write_proxies(uid, scan_id, rule_proxies, gemini_proxies)

        return cors_response({
            "scan_id": scan_id,
            "status": "analysis_complete",
            "proxy_count": len(rule_proxies) + len(gemini_proxies),
            "severity": gemini_result.get("severity", "medium"),
        })

    except Exception as e:
        logger.exception(f"CF2 failed: {e}")
        if uid and scan_id:
            set_scan_status(uid, scan_id, "error", str(e))
        return cors_response({"error": "Internal server error", "detail": str(e)}, 500)


# ─── CF3: triggerMitigation ───────────────────────────────────────────────────

@functions_framework.http
def triggerMitigation(request: Request):
    """
    Called by Member A's Flutter UI when user clicks 'Fix Bias'.
    Expects JSON body: { uid, scan_id, storage_path, group_col, outcome_col }

    Flow:
    1. Re-download and parse CSV
    2. Run mitigation engine
    3. Write before/after results to Firestore
    """
    preflight = handle_options(request)
    if preflight:
        return preflight

    try:
        body = request.get_json(silent=True) or {}
        uid = body.get("uid")
        scan_id = body.get("scan_id")
        storage_path = body.get("storage_path")
        group_col = body.get("group_col")
        outcome_col = body.get("outcome_col")

        if not all([uid, scan_id, storage_path, group_col, outcome_col]):
            return cors_response({"error": "Missing required fields"}, 400)

        set_scan_status(uid, scan_id, "mitigating")

        # Download fresh CSV
        from helpers.csv_parser import download_csv_from_storage, binarise_outcome
        df = download_csv_from_storage(FIREBASE_STORAGE_BUCKET, storage_path)
        df = binarise_outcome(df, outcome_col)

        # Run mitigation
        logger.info(f"Running mitigation for scan {scan_id}")
        mitigation_result = run_mitigation(df, group_col, outcome_col)

        # Write to Firestore
        write_mitigation(uid, scan_id, mitigation_result)

        return cors_response({
            "scan_id": scan_id,
            "status": "mitigation_complete",
            "before_equity_score": mitigation_result["before_equity_score"],
            "after_equity_score": mitigation_result["after_equity_score"],
            "decisions_changed_count": mitigation_result["decisions_changed_count"],
        })

    except Exception as e:
        logger.exception(f"CF3 (mitigation) failed: {e}")
        if uid and scan_id:
            set_scan_status(uid, scan_id, "error", str(e))
        return cors_response({"error": "Internal server error", "detail": str(e)}, 500)


# ─── CF4: getDirectFairDecision ───────────────────────────────────────────────

@functions_framework.http
def getDirectFairDecision(request: Request):
    """
    Standalone Direct Fair Decision mode.
    Expects JSON body: { uid, scenario, save_to_firestore (optional) }

    Returns Gemini's fair recommendation.
    """
    preflight = handle_options(request)
    if preflight:
        return preflight

    try:
        body = request.get_json(silent=True) or {}

        is_valid, err = validate_cf4_request(body)
        if not is_valid:
            return cors_response({"error": err}, 400)

        uid = body.get("uid")
        scenario = body.get("scenario", "").strip()

        # Prompt injection guard
        is_safe, safety_err = is_prompt_safe(scenario)
        if not is_safe:
            return cors_response({"error": safety_err}, 400)

        logger.info(f"Direct decision request from uid={uid}")
        result = get_direct_fair_decision(scenario)

        # Optionally save to Firestore for history
        if body.get("save_to_firestore") and uid:
            decision_id = str(uuid.uuid4())
            from helpers.firestore_writer import db
            db.collection("users").document(uid).collection("decisions").document(decision_id).set({
                "scenario": scenario,
                "result": result,
                "created_at": datetime.now(timezone.utc),
            })
            result["decision_id"] = decision_id

        return cors_response(result)

    except Exception as e:
        logger.exception(f"CF4 (direct decision) failed: {e}")
        return cors_response({"error": "Internal server error", "detail": str(e)}, 500)
