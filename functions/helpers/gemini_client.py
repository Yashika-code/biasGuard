"""
BiasGuard — Gemini Client
Python wrapper around the Google Genai SDK for all three BiasGuard prompts:
  1. Bias Analysis & Explanation (Audit Mode)
  2. India-Specific Proxy Detection (Column-level)
  3. Direct Fair Decision (Standalone Mode)
"""

import json
import os
import time
import logging
from typing import Dict, Any

from google import genai
from google.genai import types

logger = logging.getLogger(__name__)

# ─── Configure Gemini ─────────────────────────────────────────────────────────

_GEMINI_MODEL = "gemini-2.0-flash"
_MAX_RETRIES = 3
_RETRY_DELAY = 2  # seconds (doubles on each retry)


def _get_client() -> genai.Client:
    api_key = os.environ.get("GEMINI_API_KEY")
    if not api_key:
        raise EnvironmentError("GEMINI_API_KEY environment variable not set.")
    return genai.Client(api_key=api_key)


def _call_gemini(prompt: str, system_instruction: str) -> Dict[str, Any]:
    """
    Call Gemini with retry logic. Returns parsed JSON dict.
    Raises ValueError if JSON cannot be parsed after all retries.
    """
    client = _get_client()
    last_error = None

    for attempt in range(_MAX_RETRIES):
        try:
            response = client.models.generate_content(
                model=_GEMINI_MODEL,
                contents=prompt,
                config=types.GenerateContentConfig(
                    system_instruction=system_instruction,
                    temperature=0.2,
                    response_mime_type="application/json",
                ),
            )
            raw_text = response.text.strip()

            # Handle markdown code fences if present
            if raw_text.startswith("```"):
                raw_text = raw_text.split("```")[1]
                if raw_text.startswith("json"):
                    raw_text = raw_text[4:].strip()

            return json.loads(raw_text)

        except (json.JSONDecodeError, Exception) as e:
            last_error = e
            logger.warning(f"Gemini attempt {attempt + 1} failed: {e}")
            time.sleep(_RETRY_DELAY * (2 ** attempt))

    logger.error(f"All Gemini retries failed: {last_error}")
    raise ValueError(f"Gemini call failed after {_MAX_RETRIES} retries: {last_error}")


# ─── Prompt 1: Bias Analysis ──────────────────────────────────────────────────

BIAS_ANALYSIS_SYSTEM = """You are an expert AI fairness auditor specialising in India-specific
socio-cultural bias including caste, region, gender, and income proxies.
Always respond ONLY with valid JSON. No preamble, no markdown, no explanation outside the JSON.
Missing fields must be empty strings or empty lists, never null."""

BIAS_ANALYSIS_TEMPLATE = """Analyse this decision dataset for an AI system used in {use_case}.
Detected sensitive columns: {columns_list}.
Group statistics (approval rates by group): {group_stats}.
Overall approval rate: {overall_rate}%.
Demographic Parity score: {demographic_parity} (0=fair, 1=biased).
Equity Score: {equity_score}/100.

Return ONLY this JSON:
{{
  "explanation_en": "Plain English explanation of the bias found (2-3 sentences, accessible to non-technical users)",
  "explanation_hi": "Same explanation in Hindi (2-3 sentences)",
  "root_causes": ["list of specific root causes identified"],
  "proxy_features": ["column names that act as indirect bias proxies"],
  "mitigation_suggestion": "One clear, actionable mitigation recommendation",
  "counterfactual_hint": "One specific what-if scenario that illustrates bias",
  "severity": "low|medium|high|critical",
  "india_specific_flags": ["list of India-specific bias patterns detected"]
}}"""


def analyse_bias(use_case: str, columns_list: list, group_stats: dict,
                  overall_rate: float, demographic_parity: float,
                  equity_score: int) -> Dict[str, Any]:
    """Call Gemini for bias explanation and root cause analysis."""
    prompt = BIAS_ANALYSIS_TEMPLATE.format(
        use_case=use_case,
        columns_list=json.dumps(columns_list),
        group_stats=json.dumps(group_stats, ensure_ascii=False),
        overall_rate=round(overall_rate, 1),
        demographic_parity=round(demographic_parity, 4),
        equity_score=equity_score,
    )
    try:
        return _call_gemini(prompt, BIAS_ANALYSIS_SYSTEM)
    except Exception as e:
        logger.error(f"Bias analysis Gemini call failed: {e}")
        return _fallback_bias_analysis(equity_score, demographic_parity)


def _fallback_bias_analysis(equity_score: int, dp: float) -> Dict[str, Any]:
    """Pre-written fallback if Gemini is unavailable."""
    severity = "critical" if dp > 0.3 else "high" if dp > 0.15 else "medium" if dp > 0.05 else "low"
    return {
        "explanation_en": (
            f"The AI system shows a {round(dp * 100, 1)}% disparity in approval rates across groups, "
            f"resulting in an Equity Score of {equity_score}/100. "
            f"This level of disparity could lead to systematic discrimination against lower-scoring groups."
        ),
        "explanation_hi": (
            f"इस AI सिस्टम में समूहों के बीच {round(dp * 100, 1)}% का अनुमोदन दर असमानता पाई गई है, "
            f"जिससे इक्विटी स्कोर {equity_score}/100 आया है।"
        ),
        "root_causes": ["Unequal approval rates across demographic groups"],
        "proxy_features": [],
        "mitigation_suggestion": "Apply group reweighting to equalise approval rates across all demographic groups.",
        "counterfactual_hint": "Changing the group attribute may significantly alter the decision outcome.",
        "severity": severity,
        "india_specific_flags": [],
    }


# ─── Prompt 2: India Proxy Detection ─────────────────────────────────────────

PROXY_DETECTION_SYSTEM = """You are an expert in Indian socio-cultural patterns, caste inference,
and data bias. You specialise in recognising how column names and values in Indian administrative
datasets can serve as proxies for protected attributes. Respond ONLY with valid JSON."""

PROXY_DETECTION_TEMPLATE = """Analyse these column names and sample values from an Indian dataset:
{columns_and_samples}

For each column, identify if it could act as an indirect proxy for:
- caste/social group: via surnames, district names, school names, roll number patterns
- region: rural vs urban via pin codes, district codes, school boards
- ses (socio-economic status): via school type, medium of instruction, bank branch
- gender: via names, salutation patterns

Return ONLY this JSON:
{{
  "proxy_columns": [
    {{
      "column": "column_name",
      "proxy_type": "caste|region|gender|ses",
      "confidence": 0,
      "explanation": "Short explanation of how this column serves as a proxy"
    }}
  ]
}}"""


def detect_proxies_gemini(columns_and_samples: dict) -> Dict[str, Any]:
    """Call Gemini for India-specific proxy detection on column samples."""
    prompt = PROXY_DETECTION_TEMPLATE.format(
        columns_and_samples=json.dumps(columns_and_samples, ensure_ascii=False, default=str)
    )
    try:
        return _call_gemini(prompt, PROXY_DETECTION_SYSTEM)
    except Exception as e:
        logger.error(f"Proxy detection Gemini call failed: {e}")
        return {"proxy_columns": []}


# ─── Prompt 3: Direct Fair Decision ──────────────────────────────────────────

DIRECT_DECISION_SYSTEM = """You are a fair decision assistant for BiasGuard. You make decisions
based ONLY on merit and contextually relevant factors. You must EXPLICITLY IGNORE caste, surname,
gender, religion, region, language, and any other protected attributes.
Every decision must be transparent, explainable, and free of bias.
Respond ONLY with valid JSON."""

DIRECT_DECISION_TEMPLATE = """Make a fair recommendation for this scenario:
{scenario}

Respond ONLY with this JSON:
{{
  "recommendation": "APPROVE|REJECT|REVIEW",
  "confidence": 0,
  "factors_considered": ["list of merit-based factors you used"],
  "factors_explicitly_ignored": ["list of bias-prone factors you ignored"],
  "what_if": [
    {{"change": "description of change", "new_recommendation": "APPROVE|REJECT|REVIEW", "reasoning": "why this changes the outcome"}},
    {{"change": "description of change 2", "new_recommendation": "APPROVE|REJECT|REVIEW", "reasoning": "..."}},
    {{"change": "description of change 3", "new_recommendation": "APPROVE|REJECT|REVIEW", "reasoning": "..."}}
  ],
  "explanation_en": "Clear explanation of the recommendation (2-3 sentences)",
  "explanation_hi": "Same explanation in Hindi",
  "fairness_note": "One sentence on how this decision upholds fairness principles"
}}"""


def get_direct_fair_decision(scenario: str) -> Dict[str, Any]:
    """Call Gemini for a standalone fair decision in Direct Mode."""
    prompt = DIRECT_DECISION_TEMPLATE.format(scenario=scenario)
    try:
        return _call_gemini(prompt, DIRECT_DECISION_SYSTEM)
    except Exception as e:
        logger.error(f"Direct fair decision Gemini call failed: {e}")
        return {
            "recommendation": "REVIEW",
            "confidence": 50,
            "factors_considered": ["Unable to complete AI analysis at this time"],
            "factors_explicitly_ignored": ["All protected attributes (caste, gender, region, religion)"],
            "what_if": [],
            "explanation_en": "The AI assistant is temporarily unavailable. Please review this application manually using only merit-based criteria.",
            "explanation_hi": "AI सिस्टम अभी उपलब्ध नहीं है। कृपया केवल योग्यता-आधारित मानदंडों का उपयोग करके इस आवेदन की मैन्युअल समीक्षा करें।",
            "fairness_note": "All decisions should be based solely on merit and relevant qualifications.",
        }