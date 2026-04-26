"""
Render web entrypoint for BiasGuard backend.

This wraps the existing Firebase-style handlers so they can run as a
standard Flask web service on Render.
"""

import json
import os
from functools import lru_cache
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


@lru_cache(maxsize=1)
def _handlers():
    from main import (  # noqa: E402
        parseAndCalculateMetrics,
        geminiAnalysisAndMitigation,
        triggerMitigation,
        getDirectFairDecision,
    )
    return (
        parseAndCalculateMetrics,
        geminiAnalysisAndMitigation,
        triggerMitigation,
        getDirectFairDecision,
    )

app = Flask(__name__)
app.url_map.strict_slashes = False


def _usage_response(endpoint: str, required_fields: list[str]) -> tuple[dict, int]:
    return {
        "endpoint": endpoint,
        "status": "ready",
        "allowed_methods": ["POST"],
        "accepted_non_post_methods": ["GET", "OPTIONS", "PUT", "PATCH", "DELETE"],
        "how_to_use": "Send a JSON body via POST. Other methods return this usage response.",
        "required_fields": required_fields,
    }, 200


@app.errorhandler(405)
def method_not_allowed(_error):
    return {
        "status": "ready",
        "message": "Method not supported for this path. Use POST for analysis endpoints.",
        "routes": {
            "/": ["GET"],
            "/health": ["GET"],
            "/api/docs": ["GET"],
            "/parseAndCalculateMetrics": ["GET", "POST", "OPTIONS", "PUT", "PATCH", "DELETE"],
            "/geminiAnalysisAndMitigation": ["GET", "POST", "OPTIONS", "PUT", "PATCH", "DELETE"],
            "/triggerMitigation": ["GET", "POST", "OPTIONS", "PUT", "PATCH", "DELETE"],
            "/getDirectFairDecision": ["GET", "POST", "OPTIONS", "PUT", "PATCH", "DELETE"],
        },
    }, 200


@app.get("/")
def index() -> tuple[dict, int]:
    return {
        "service": "BiasGuard backend",
        "status": "running",
        "message": "API is live. Use /health or the POST endpoints for analysis.",
        "routes": [
            "/health",
            "/api/docs",
            "/parseAndCalculateMetrics",
            "/geminiAnalysisAndMitigation",
            "/triggerMitigation",
            "/getDirectFairDecision",
        ],
    }, 200


@app.get("/api/docs")
def api_docs() -> str:
    return """
<!doctype html>
<html lang=\"en\">
<head>
    <meta charset=\"utf-8\" />
    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\" />
    <title>BiasGuard API Docs</title>
    <style>
        :root {
            --bg: #f2efe9;
            --card: #fffdf8;
            --ink: #1a1f24;
            --muted: #586170;
            --accent: #d9480f;
            --accent2: #0b7285;
            --line: #d9d2c8;
            --ok: #2b8a3e;
            --err: #c92a2a;
        }
        * { box-sizing: border-box; }
        body {
            margin: 0;
            font-family: \"Segoe UI\", Tahoma, Geneva, Verdana, sans-serif;
            color: var(--ink);
            background:
                radial-gradient(circle at 10% 0%, #ffd8a8 0, transparent 40%),
                radial-gradient(circle at 100% 80%, #c5f6fa 0, transparent 45%),
                var(--bg);
        }
        .wrap {
            max-width: 980px;
            margin: 0 auto;
            padding: 28px 16px 48px;
        }
        h1 {
            margin: 0;
            letter-spacing: 0.2px;
            font-size: 2rem;
        }
        p.sub {
            color: var(--muted);
            margin-top: 8px;
            margin-bottom: 18px;
        }
        .card {
            background: var(--card);
            border: 1px solid var(--line);
            border-radius: 14px;
            padding: 16px;
            margin: 12px 0;
            box-shadow: 0 8px 20px rgba(0, 0, 0, 0.04);
        }
        .path {
            font-weight: 700;
            font-size: 1.05rem;
            margin-bottom: 6px;
        }
        .hint {
            color: var(--muted);
            margin-bottom: 10px;
            font-size: 0.92rem;
        }
        textarea {
            width: 100%;
            min-height: 120px;
            border-radius: 10px;
            border: 1px solid var(--line);
            padding: 10px;
            resize: vertical;
            font: 13px/1.4 Consolas, Monaco, monospace;
            background: #fff;
        }
        .actions {
            margin-top: 10px;
            display: flex;
            flex-wrap: wrap;
            gap: 8px;
        }
        button {
            border: 0;
            border-radius: 9px;
            padding: 8px 12px;
            font-weight: 600;
            cursor: pointer;
            color: #fff;
            transition: transform .1s ease, opacity .2s ease;
        }
        button:hover { transform: translateY(-1px); }
        .btn-get { background: var(--accent2); }
        .btn-options { background: #495057; }
        .btn-post { background: var(--accent); }
        pre {
            margin-top: 10px;
            background: #101418;
            color: #f1f3f5;
            border-radius: 10px;
            padding: 12px;
            overflow: auto;
            min-height: 84px;
            font: 12.5px/1.45 Consolas, Monaco, monospace;
            border: 1px solid #1d252d;
        }
        .status-ok { color: var(--ok); font-weight: 700; }
        .status-err { color: var(--err); font-weight: 700; }
    </style>
</head>
<body>
    <main class=\"wrap\">
        <h1>BiasGuard API Route Tester</h1>
        <p class=\"sub\">Test every backend route from one page. Use POST with JSON for real processing.</p>

        <section class=\"card\">
            <div class=\"path\">/health</div>
            <div class=\"actions\">
                <button class=\"btn-get\" onclick=\"callApi('/health', 'GET', '', 'out-health')\">GET</button>
            </div>
            <pre id=\"out-health\">Click GET to test /health</pre>
        </section>

        <section class=\"card\">
            <div class=\"path\">/parseAndCalculateMetrics</div>
            <div class=\"hint\">Required: uid, storage_path</div>
            <textarea id=\"body-cf1\">{
    \"uid\": \"demo_user\",
    \"storage_path\": \"uploads/demo_user/file.csv\",
    \"dataset_name\": \"Demo Dataset\",
    \"use_case\": \"Scholarship Selection\",
    \"anonymise\": false
}</textarea>
            <div class=\"actions\">
                <button class=\"btn-get\" onclick=\"callApi('/parseAndCalculateMetrics', 'GET', '', 'out-cf1')\">GET</button>
                <button class=\"btn-options\" onclick=\"callApi('/parseAndCalculateMetrics', 'OPTIONS', '', 'out-cf1')\">OPTIONS</button>
                <button class=\"btn-post\" onclick=\"callApi('/parseAndCalculateMetrics', 'POST', 'body-cf1', 'out-cf1')\">POST</button>
            </div>
            <pre id=\"out-cf1\">Ready</pre>
        </section>

        <section class=\"card\">
            <div class=\"path\">/geminiAnalysisAndMitigation</div>
            <div class=\"hint\">Required: uid, scan_id, storage_path (plus CF2 context fields)</div>
            <textarea id=\"body-cf2\">{
    \"uid\": \"demo_user\",
    \"scan_id\": \"scan_123\",
    \"storage_path\": \"uploads/demo_user/file.csv\",
    \"use_case\": \"General\",
    \"outcome_col\": \"decision\",
    \"sensitive_map\": {\"gender\": [\"gender\"]},
    \"overall_rate\": 50.0,
    \"group_stats\": {},
    \"demographic_parity\": 0.2,
    \"equity_score\": 60,
    \"column_names\": [\"decision\", \"gender\"],
    \"anonymise\": false
}</textarea>
            <div class=\"actions\">
                <button class=\"btn-get\" onclick=\"callApi('/geminiAnalysisAndMitigation', 'GET', '', 'out-cf2')\">GET</button>
                <button class=\"btn-options\" onclick=\"callApi('/geminiAnalysisAndMitigation', 'OPTIONS', '', 'out-cf2')\">OPTIONS</button>
                <button class=\"btn-post\" onclick=\"callApi('/geminiAnalysisAndMitigation', 'POST', 'body-cf2', 'out-cf2')\">POST</button>
            </div>
            <pre id=\"out-cf2\">Ready</pre>
        </section>

        <section class=\"card\">
            <div class=\"path\">/triggerMitigation</div>
            <div class=\"hint\">Required: uid, scan_id, storage_path, group_col, outcome_col</div>
            <textarea id=\"body-cf3\">{
    \"uid\": \"demo_user\",
    \"scan_id\": \"scan_123\",
    \"storage_path\": \"uploads/demo_user/file.csv\",
    \"group_col\": \"district\",
    \"outcome_col\": \"decision\"
}</textarea>
            <div class=\"actions\">
                <button class=\"btn-get\" onclick=\"callApi('/triggerMitigation', 'GET', '', 'out-cf3')\">GET</button>
                <button class=\"btn-options\" onclick=\"callApi('/triggerMitigation', 'OPTIONS', '', 'out-cf3')\">OPTIONS</button>
                <button class=\"btn-post\" onclick=\"callApi('/triggerMitigation', 'POST', 'body-cf3', 'out-cf3')\">POST</button>
            </div>
            <pre id=\"out-cf3\">Ready</pre>
        </section>

        <section class=\"card\">
            <div class=\"path\">/getDirectFairDecision</div>
            <div class=\"hint\">Required: scenario (uid optional)</div>
            <textarea id=\"body-cf4\">{
    \"uid\": \"demo_user\",
    \"scenario\": \"Candidate has strong marks and low-income background.\",
    \"save_to_firestore\": false
}</textarea>
            <div class=\"actions\">
                <button class=\"btn-get\" onclick=\"callApi('/getDirectFairDecision', 'GET', '', 'out-cf4')\">GET</button>
                <button class=\"btn-options\" onclick=\"callApi('/getDirectFairDecision', 'OPTIONS', '', 'out-cf4')\">OPTIONS</button>
                <button class=\"btn-post\" onclick=\"callApi('/getDirectFairDecision', 'POST', 'body-cf4', 'out-cf4')\">POST</button>
            </div>
            <pre id=\"out-cf4\">Ready</pre>
        </section>
    </main>

    <script>
        async function callApi(path, method, bodyId, outId) {
            const out = document.getElementById(outId);
            out.textContent = 'Loading...';
            try {
                const opts = { method, headers: {} };
                if (method === 'POST') {
                    let payload = {};
                    try {
                        payload = JSON.parse(document.getElementById(bodyId).value || '{}');
                    } catch (e) {
                        out.innerHTML = '<span class="status-err">Invalid JSON in request body.</span>';
                        return;
                    }
                    opts.headers['Content-Type'] = 'application/json';
                    opts.body = JSON.stringify(payload);
                }

                const res = await fetch(path, opts);
                const text = await res.text();
                let parsed = text;
                try {
                    parsed = JSON.stringify(JSON.parse(text), null, 2);
                } catch (_err) {
                    // Keep plain text when response is not JSON.
                }

                const cls = res.ok ? 'status-ok' : 'status-err';
                out.innerHTML = '<span class="' + cls + '">HTTP ' + res.status + ' ' + res.statusText + '</span>\\n\\n' + parsed;
            } catch (err) {
                out.innerHTML = '<span class="status-err">Request failed:</span> ' + err;
            }
        }
    </script>
</body>
</html>
"""


@app.get("/health")
def health() -> tuple[dict, int]:
    return {
        "status": "ok",
        "service": "biasguard-functions",
    }, 200


@app.route("/parseAndCalculateMetrics", methods=["GET", "POST", "OPTIONS", "PUT", "PATCH", "DELETE"])
def parse_and_calculate_metrics():
    if request.method != "POST":
        return _usage_response(
            "/parseAndCalculateMetrics",
            ["uid", "storage_path"],
        )

    parseAndCalculateMetrics, _, _, _ = _handlers()
    return parseAndCalculateMetrics(request)


@app.route("/geminiAnalysisAndMitigation", methods=["GET", "POST", "OPTIONS", "PUT", "PATCH", "DELETE"])
def gemini_analysis_and_mitigation():
    if request.method != "POST":
        return _usage_response(
            "/geminiAnalysisAndMitigation",
            ["uid", "scan_id", "storage_path"],
        )

    _, geminiAnalysisAndMitigation, _, _ = _handlers()
    return geminiAnalysisAndMitigation(request)


@app.route("/triggerMitigation", methods=["GET", "POST", "OPTIONS", "PUT", "PATCH", "DELETE"])
def trigger_mitigation():
    if request.method != "POST":
        return _usage_response(
            "/triggerMitigation",
            ["uid", "scan_id", "storage_path", "group_col", "outcome_col"],
        )

    _, _, triggerMitigation, _ = _handlers()
    return triggerMitigation(request)


@app.route("/getDirectFairDecision", methods=["GET", "POST", "OPTIONS", "PUT", "PATCH", "DELETE"])
def get_direct_fair_decision():
    if request.method != "POST":
        return _usage_response(
            "/getDirectFairDecision",
            ["scenario"],
        )

    _, _, _, getDirectFairDecision = _handlers()
    return getDirectFairDecision(request)


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", "10000")))
