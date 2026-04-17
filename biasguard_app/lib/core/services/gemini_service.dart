import 'dart:async';
import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'auth_service.dart';

class GeminiService {
  // API key injected at build time via: --dart-define=GEMINI_API_KEY=your_key
  static const String _apiKey = String.fromEnvironment('GEMINI_API_KEY');

  late final GenerativeModel _model;

  GeminiService() {
    _model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: _apiKey,
    );
  }

  /// Refactored Direct Fair Decision using local SDK
  Future<Map<String, dynamic>> getDirectFairDecision(String scenario) async {
    final prompt = '''
Make a fair recommendation for this scenario:
$scenario

Respond ONLY with this JSON:
{
  "recommendation": "APPROVE|REJECT|REVIEW",
  "confidence": 0-100,
  "factors_considered": ["list of merit-based factors you used"],
  "factors_explicitly_ignored": ["list of bias-prone factors you ignored"],
  "what_if": [
    {"change": "description of change", "new_recommendation": "APPROVE|REJECT|REVIEW", "reasoning": "..."}
  ],
  "explanation_en": "Clear explanation (2-3 sentences)",
  "explanation_hi": "Same in Hindi",
  "fairness_note": "How this upholds fairness"
}''';

    try {
      final response = await _model
          .generateContent([Content.text(prompt)])
          .timeout(const Duration(seconds: 20));
      final text = response.text ?? '{}';
      return _parseJson(text);
    } catch (e) {
      return _errorResponse('AI Error: ${e.toString()}');
    }
  }

  /// NEW: Local Audit Analysis (previously done by Cloud Function CF2)
  Future<Map<String, dynamic>> analyseAuditResults({
    required String useCase,
    required List<String> columns,
    required Map<String, dynamic> groupStats,
    required double overallRate,
    required double demographicParity,
    required int equityScore,
  }) async {
    final prompt = '''
Analyse this decision dataset for an AI system used in $useCase.
Detected sensitive columns: ${columns.join(', ')}.
Group statistics: ${jsonEncode(groupStats)}.
Overall approval rate: $overallRate%.
Demographic Parity: $demographicParity (0=fair, 1=biased).
Equity Score: $equityScore/100.

Return ONLY this JSON:
{
  "explanation_en": "Plain English explanation of bias found",
  "explanation_hi": "Same in Hindi",
  "root_causes": ["list of causes"],
  "proxy_features": ["columns acting as proxies"],
  "mitigation_suggestion": "Actionable recommendation",
  "severity": "low|medium|high|critical",
  "india_specific_flags": ["India-specific bias patterns"]
}''';

    try {
      final response = await _model
          .generateContent([Content.text(prompt)])
          .timeout(const Duration(seconds: 20));
      return _parseJson(response.text ?? '{}');
    } catch (e) {
      // Timeout or API error — return a meaningful local fallback
      final severity = equityScore >= 80 ? 'low' : (equityScore >= 50 ? 'medium' : 'high');
      return {
        'explanation_en': 'AI analysis could not be completed (${e.runtimeType}). '
            'Equity Score: $equityScore/100. Demographic Parity: $demographicParity. '
            'A score below 70 indicates significant disparities across groups.',
        'explanation_hi': 'AI विश्लेषण पूरा नहीं हो सका। इक्विटी स्कोर: $equityScore/100।',
        'root_causes': ['Automated analysis unavailable — review group statistics manually'],
        'proxy_features': [],
        'mitigation_suggestion': 'Review the group-level approval rates for disparities.',
        'severity': severity,
        'india_specific_flags': [],
      };
    }
  }

  Map<String, dynamic> _parseJson(String text) {
    try {
      // Clean up markdown code blocks if the model includes them
      String cleaned = text.trim();
      if (cleaned.startsWith('```')) {
        cleaned = cleaned.split('```')[1];
        if (cleaned.startsWith('json')) {
          cleaned = cleaned.substring(4);
        }
      }
      return jsonDecode(cleaned) as Map<String, dynamic>;
    } catch (e) {
      return _errorResponse('JSON Parse Error');
    }
  }

  Map<String, dynamic> _errorResponse(String msg) {
    return {
      'recommendation': 'ERROR',
      'explanation_en': msg,
      'factors_considered': ['Error Handling'],
    };
  }
}

final geminiService = GeminiService();
