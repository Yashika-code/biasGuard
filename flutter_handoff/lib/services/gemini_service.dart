/// BiasGuard — Gemini Service (Flutter)
/// Direct Gemini 2.0 Flash calls from the Flutter app.
/// Used for: Counterfactual What-If Simulator + Direct Fair Decision Mode.
///
/// Member A: Drop this file into lib/services/gemini_service.dart
/// Add to pubspec.yaml: google_generative_ai: ^0.4.0
///
/// Usage:
///   final service = GeminiService();
///   final result = await service.getCounterfactualResult(original, changes);
///   final decision = await service.getDirectFairDecision(scenario);

import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiService {
  static const String _modelName = 'gemini-2.0-flash';

  // TODO: Store this in flutter_dotenv or --dart-define, never hardcode in prod
  // Member B will share the key at the 10 PM sync
  static const String _apiKey = 'YOUR_GEMINI_API_KEY';

  late final GenerativeModel _model;

  GeminiService() {
    _model = GenerativeModel(
      model: _modelName,
      apiKey: _apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.2,
        responseMimeType: 'application/json',
      ),
    );
  }

  // ─── Counterfactual What-If Simulator ────────────────────────────────────────

  /// Called by the Counterfactual Simulator sliders.
  /// [originalRecord] — the original student/applicant attributes (Map)
  /// [changedAttributes] — only the changed attributes (e.g. {district: 'Patna'})
  /// [originalDecision] — 'Approved' or 'Rejected'
  /// [useCase] — e.g. 'Scholarship Selection', 'Loan Application'
  ///
  /// Returns [CounterfactualResult] with new decision + explanation.
  Future<CounterfactualResult> getCounterfactualResult({
    required Map<String, String> originalRecord,
    required Map<String, String> changedAttributes,
    required String originalDecision,
    required String useCase,
  }) async {
    final mergedRecord = Map<String, String>.from(originalRecord)
      ..addAll(changedAttributes);

    final prompt = '''
You are a fair AI decision simulation engine for BiasGuard.

Original applicant profile: ${jsonEncode(originalRecord)}
Original decision: $originalDecision

Modified profile (what-if): ${jsonEncode(mergedRecord)}
Changed attributes: ${jsonEncode(changedAttributes)}
Use case: $useCase

Based ONLY on merit-relevant factors, what would the fair decision be for the modified profile?
Ignore caste, surname, religion, gender, and region as decision factors.

Return ONLY this JSON:
{
  "new_decision": "Approved|Rejected|Review",
  "decision_changed": true,
  "confidence": 0-100,
  "reason_en": "One sentence explaining why the decision changed or stayed the same",
  "reason_hi": "Same in Hindi",
  "key_factor": "The single most important factor that drove this outcome"
}''';

    return _callWithRetry(
      prompt: prompt,
      parse: CounterfactualResult.fromJson,
      fallback: CounterfactualResult.fallback(originalDecision),
    );
  }

  // ─── Direct Fair Decision Mode ────────────────────────────────────────────────

  /// Called when the user submits a scenario in Direct Fair Decision Mode.
  /// [scenario] — Free text or structured form converted to string.
  ///
  /// Returns [DirectDecisionResult] with recommendation + explanation.
  Future<DirectDecisionResult> getDirectFairDecision(String scenario) async {
    final prompt = '''
You are a fair decision assistant for BiasGuard. Make decisions based ONLY on merit
and contextually relevant factors. You must EXPLICITLY IGNORE caste, surname, gender,
religion, region, language, and any other protected attributes. Respond ONLY with valid JSON.

Scenario: $scenario

Return ONLY this JSON:
{
  "recommendation": "APPROVE|REJECT|REVIEW",
  "confidence": 0-100,
  "factors_considered": ["list of merit-based factors you used"],
  "factors_explicitly_ignored": ["list of bias-prone factors you ignored"],
  "what_if": [
    {"change": "description", "new_recommendation": "APPROVE|REJECT|REVIEW", "reasoning": "why"},
    {"change": "description 2", "new_recommendation": "APPROVE|REJECT|REVIEW", "reasoning": "why"},
    {"change": "description 3", "new_recommendation": "APPROVE|REJECT|REVIEW", "reasoning": "why"}
  ],
  "explanation_en": "Clear explanation of the recommendation (2-3 sentences)",
  "explanation_hi": "Same explanation in Hindi",
  "fairness_note": "One sentence on how this decision upholds fairness principles"
}''';

    return _callWithRetry(
      prompt: prompt,
      parse: DirectDecisionResult.fromJson,
      fallback: DirectDecisionResult.fallback(),
    );
  }

  // ─── Bias Counterfactual (Audit Mode sliders) ─────────────────────────────────

  /// Lightweight call for the Audit Mode counterfactual panel.
  /// Shows what happens if ONE sensitive attribute changes (e.g. district → Urban).
  Future<AuditCounterfactualResult> getAuditCounterfactual({
    required String groupColumn,
    required String fromValue,
    required String toValue,
    required double currentApprovalRate,
    required String useCase,
  }) async {
    final prompt = '''
In an AI decision system for $useCase, changing the "$groupColumn" attribute
from "$fromValue" to "$toValue" is being analysed.

Current approval rate for "$fromValue" group: ${currentApprovalRate.toStringAsFixed(1)}%

Based on typical India-specific bias patterns (rural-urban divide, caste proxies,
school board SES), estimate the impact of this counterfactual change.

Return ONLY this JSON:
{
  "estimated_new_approval_rate": 0-100,
  "direction": "increase|decrease|no_change",
  "bias_type_implicated": "caste|region|gender|ses|none",
  "impact_explanation_en": "One sentence explaining the expected change",
  "impact_explanation_hi": "Same in Hindi",
  "is_proxy_change": true
}''';

    return _callWithRetry(
      prompt: prompt,
      parse: AuditCounterfactualResult.fromJson,
      fallback: AuditCounterfactualResult.fallback(currentApprovalRate),
    );
  }

  // ─── Core Gemini caller with retry ───────────────────────────────────────────

  Future<T> _callWithRetry<T>({
    required String prompt,
    required T Function(Map<String, dynamic>) parse,
    required T fallback,
    int maxRetries = 3,
  }) async {
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        final response = await _model.generateContent([Content.text(prompt)]);
        final text = response.text ?? '';

        // Strip markdown fences if Gemini adds them
        String cleaned = text.trim();
        if (cleaned.startsWith('```')) {
          cleaned = cleaned.replaceAll(RegExp(r'```json|```'), '').trim();
        }

        final json = jsonDecode(cleaned) as Map<String, dynamic>;
        return parse(json);
      } catch (e) {
        if (attempt == maxRetries - 1) {
          // All retries exhausted — return fallback
          return fallback;
        }
        // Exponential backoff
        await Future.delayed(Duration(seconds: (attempt + 1) * 2));
      }
    }
    return fallback;
  }
}

// ─── Result Models ─────────────────────────────────────────────────────────────

class CounterfactualResult {
  final String newDecision;
  final bool decisionChanged;
  final int confidence;
  final String reasonEn;
  final String reasonHi;
  final String keyFactor;

  const CounterfactualResult({
    required this.newDecision,
    required this.decisionChanged,
    required this.confidence,
    required this.reasonEn,
    required this.reasonHi,
    required this.keyFactor,
  });

  factory CounterfactualResult.fromJson(Map<String, dynamic> json) =>
      CounterfactualResult(
        newDecision: json['new_decision'] as String? ?? 'Review',
        decisionChanged: json['decision_changed'] as bool? ?? false,
        confidence: (json['confidence'] as num?)?.toInt() ?? 50,
        reasonEn: json['reason_en'] as String? ?? '',
        reasonHi: json['reason_hi'] as String? ?? '',
        keyFactor: json['key_factor'] as String? ?? '',
      );

  factory CounterfactualResult.fallback(String originalDecision) =>
      CounterfactualResult(
        newDecision: originalDecision,
        decisionChanged: false,
        confidence: 50,
        reasonEn: 'Analysis temporarily unavailable. Please try again.',
        reasonHi: 'विश्लेषण अस्थायी रूप से अनुपलब्ध है। कृपया पुनः प्रयास करें।',
        keyFactor: 'Unknown',
      );
}

class DirectDecisionResult {
  final String recommendation; // APPROVE | REJECT | REVIEW
  final int confidence;
  final List<String> factorsConsidered;
  final List<String> factorsIgnored;
  final List<WhatIfScenario> whatIf;
  final String explanationEn;
  final String explanationHi;
  final String fairnessNote;

  const DirectDecisionResult({
    required this.recommendation,
    required this.confidence,
    required this.factorsConsidered,
    required this.factorsIgnored,
    required this.whatIf,
    required this.explanationEn,
    required this.explanationHi,
    required this.fairnessNote,
  });

  factory DirectDecisionResult.fromJson(Map<String, dynamic> json) =>
      DirectDecisionResult(
        recommendation: json['recommendation'] as String? ?? 'REVIEW',
        confidence: (json['confidence'] as num?)?.toInt() ?? 50,
        factorsConsidered:
            (json['factors_considered'] as List?)?.cast<String>() ?? [],
        factorsIgnored:
            (json['factors_explicitly_ignored'] as List?)?.cast<String>() ?? [],
        whatIf: (json['what_if'] as List?)
                ?.map((e) => WhatIfScenario.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        explanationEn: json['explanation_en'] as String? ?? '',
        explanationHi: json['explanation_hi'] as String? ?? '',
        fairnessNote: json['fairness_note'] as String? ?? '',
      );

  factory DirectDecisionResult.fallback() => const DirectDecisionResult(
        recommendation: 'REVIEW',
        confidence: 50,
        factorsConsidered: [],
        factorsIgnored: ['All protected attributes (caste, gender, region, religion)'],
        whatIf: [],
        explanationEn:
            'The AI assistant is temporarily unavailable. Please review this application manually using only merit-based criteria.',
        explanationHi:
            'AI सिस्टम अभी उपलब्ध नहीं है। कृपया केवल योग्यता-आधारित मानदंडों का उपयोग करके इस आवेदन की मैन्युअल समीक्षा करें।',
        fairnessNote:
            'All decisions should be based solely on merit and relevant qualifications.',
      );
}

class WhatIfScenario {
  final String change;
  final String newRecommendation;
  final String reasoning;

  const WhatIfScenario({
    required this.change,
    required this.newRecommendation,
    required this.reasoning,
  });

  factory WhatIfScenario.fromJson(Map<String, dynamic> json) => WhatIfScenario(
        change: json['change'] as String? ?? '',
        newRecommendation: json['new_recommendation'] as String? ?? 'REVIEW',
        reasoning: json['reasoning'] as String? ?? '',
      );
}

class AuditCounterfactualResult {
  final double estimatedNewApprovalRate;
  final String direction; // increase | decrease | no_change
  final String biasTypeImplicated;
  final String impactExplanationEn;
  final String impactExplanationHi;
  final bool isProxyChange;

  const AuditCounterfactualResult({
    required this.estimatedNewApprovalRate,
    required this.direction,
    required this.biasTypeImplicated,
    required this.impactExplanationEn,
    required this.impactExplanationHi,
    required this.isProxyChange,
  });

  factory AuditCounterfactualResult.fromJson(Map<String, dynamic> json) =>
      AuditCounterfactualResult(
        estimatedNewApprovalRate:
            (json['estimated_new_approval_rate'] as num?)?.toDouble() ?? 50.0,
        direction: json['direction'] as String? ?? 'no_change',
        biasTypeImplicated: json['bias_type_implicated'] as String? ?? 'none',
        impactExplanationEn: json['impact_explanation_en'] as String? ?? '',
        impactExplanationHi: json['impact_explanation_hi'] as String? ?? '',
        isProxyChange: json['is_proxy_change'] as bool? ?? false,
      );

  factory AuditCounterfactualResult.fallback(double currentRate) =>
      AuditCounterfactualResult(
        estimatedNewApprovalRate: currentRate,
        direction: 'no_change',
        biasTypeImplicated: 'none',
        impactExplanationEn: 'Analysis temporarily unavailable.',
        impactExplanationHi: 'विश्लेषण अस्थायी रूप से अनुपलब्ध है।',
        isProxyChange: false,
      );
}
