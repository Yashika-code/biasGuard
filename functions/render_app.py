"""
Render web entrypoint for BiasGuard backend.

This wraps the existing Firebase-style handlers so they can run as a
standard Flask web service on Render.
"""

import json
import os
from pathlib import Path

from flask import Flask, request


def _configure_google_credentials() -> None:
    """
    Configure Google credentials from env vars when running on Render.

    Supported options:
    1) GOOGLE_APPLICATION_CREDENTIALS points to an uploaded file path
    2) FIREBASE_SERVICE_ACCOUNT_JSON contains raw service account JSON
    """
    if os.environ.get("GOOGLE_APPLICATION_CREDENTIALS"):
        return

    raw_json = os.environ.get("FIREBASE_SERVICE_ACCOUNT_JSON", "").strip()
    if not raw_json:
        return

    creds_path = Path("/tmp/firebase-service-account.json")
    payload = json.loads(raw_json)
    creds_path.write_text(json.dumps(payload), encoding="utf-8")
    os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = str(creds_path)

    if not os.environ.get("FIREBASE_PROJECT_ID") and payload.get("project_id"):
        os.environ["FIREBASE_PROJECT_ID"] = payload["project_id"]


_configure_google_credentials()

from main import (  # noqa: E402
    parseAndCalculateMetrics,
    geminiAnalysisAndMitigation,
    triggerMitigation,
    getDirectFairDecision,
)

app = Flask(__name__)


@app.get("/health")
def health() -> tuple[dict, int]:
    return {
        "status": "ok",
        "service": "biasguard-functions",
    }, 200


@app.post("/parseAndCalculateMetrics")
def parse_and_calculate_metrics():
    return parseAndCalculateMetrics(request)


@app.post("/geminiAnalysisAndMitigation")
def gemini_analysis_and_mitigation():
    return geminiAnalysisAndMitigation(request)


@app.post("/triggerMitigation")
def trigger_mitigation():
    return triggerMitigation(request)


@app.post("/getDirectFairDecision")
def get_direct_fair_decision():
    return getDirectFairDecision(request)


@app.route("/parseAndCalculateMetrics", methods=["OPTIONS"])
@app.route("/geminiAnalysisAndMitigation", methods=["OPTIONS"])
@app.route("/triggerMitigation", methods=["OPTIONS"])
@app.route("/getDirectFairDecision", methods=["OPTIONS"])
def options_routes():
    # Reuse existing CORS preflight handling in CF1.
    return parseAndCalculateMetrics(request)


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", "10000")))
