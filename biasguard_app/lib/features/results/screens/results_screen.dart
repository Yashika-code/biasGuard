import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';

import '../widgets/result_skeleton.dart';
import '../../../core/providers/locale_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/services/auth_service.dart';

class ResultsScreen extends ConsumerWidget {
  final String scanId;
  final Map<String, dynamic>? scanData;

  const ResultsScreen({
    super.key,
    required this.scanId,
    this.scanData,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = AuthService().currentUid ?? 'anonymous';
    final isHindi = ref.watch(localeProvider.notifier).isHindi;

    return Scaffold(
      backgroundColor: AppColors.background,

      appBar: AppBar(
        title: Text(isHindi ? 'ऑडिट परिणाम' : 'Audit Results'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              onPressed: () =>
                  context.pushNamed('report', extra: {'scanId': scanId}),
              icon: const Icon(Icons.picture_as_pdf),
              label: Text(
                isHindi
                    ? 'रिपोर्ट डाउनलोड करें'
                    : AppStrings.downloadReport,
              ),
            ),
          ),
        ],
      ),

      body: scanData != null
          ? _buildResultsContent(context, scanData!, isHindi)
          : StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .collection('scans')
                  .doc(scanId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const ResultSkeleton();
                }

                if (!snapshot.hasData ||
                    !snapshot.data!.exists ||
                    snapshot.data!.data() == null) {
                  return _buildNotFound(context, isHindi);
                }

                final data =
                    snapshot.data!.data() as Map<String, dynamic>;

                return _buildResultsContent(
                  context,
                  data,
                  isHindi,
                );
              },
            ),

      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(24),
        color: AppColors.surfaceContainerLow,
        child: Wrap(
          spacing: 16,
          runSpacing: 12,
          alignment: WrapAlignment.end,
          children: [
            OutlinedButton(
              onPressed: () => context.goNamed('dashboard'),
              child: Text(
                isHindi
                    ? 'डैशबोर्ड पर लौटें'
                    : 'Return to Dashboard',
              ),
            ),
            ElevatedButton(
              onPressed: () => context.pushNamed(
                'counterfactual',
                extra: {'scanId': scanId},
              ),
              child: Text(
                isHindi
                    ? 'पूर्वाग्रह सुधारें'
                    : AppStrings.fixBias,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsContent(
    BuildContext context,
    Map<String, dynamic> data,
    bool isHindi,
  ) {
    final metrics =
        (data['metrics'] as Map<String, dynamic>?) ?? {};

    final analysis =
        (data['analysis'] as Map<String, dynamic>?) ?? {};

    final proxiesRaw = data['proxies'] ?? [];

    final proxies = (proxiesRaw is List)
        ? proxiesRaw
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
        : <Map<String, dynamic>>[];

    return LayoutBuilder(
      builder: (context, constraints) {
        final mobile = constraints.maxWidth < 1000;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              mobile
                  ? Column(
                      children: [
                        _buildEquityScoreCard(
                          context,
                          metrics,
                          isHindi,
                        ),
                        const SizedBox(height: 24),
                        _buildBiasStatusCard(
                          context,
                          metrics,
                        ),
                      ],
                    )
                  : Row(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        _buildEquityScoreCard(
                          context,
                          metrics,
                          isHindi,
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: _buildBiasStatusCard(
                            context,
                            metrics,
                          ),
                        ),
                      ],
                    ),

              const SizedBox(height: 32),

              mobile
                  ? Column(
                      children: [
                        _buildProxyDetection(
                          context,
                          proxies,
                          isHindi,
                        ),
                        const SizedBox(height: 24),
                        _buildAiAnalysis(
                          context,
                          analysis,
                          isHindi,
                        ),
                      ],
                    )
                  : Row(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildProxyDetection(
                            context,
                            proxies,
                            isHindi,
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          flex: 2,
                          child: _buildAiAnalysis(
                            context,
                            analysis,
                            isHindi,
                          ),
                        ),
                      ],
                    ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNotFound(
    BuildContext context,
    bool isHindi,
  ) {
    return Center(
      child: Column(
        mainAxisAlignment:
            MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 64,
            color: AppColors.error,
          ),
          const SizedBox(height: 16),
          Text(
            isHindi
                ? 'डेटा नहीं मिला'
                : 'Audit Data Not Found',
          ),
          const SizedBox(height: 8),
          Text('Scan ID: $scanId'),
        ],
      ),
    );
  }

  Widget _buildEquityScoreCard(
    BuildContext context,
    Map<String, dynamic> metrics,
    bool isHindi,
  ) {
    final score =
        ((metrics['equity_score'] ?? 0) as num)
            .toInt()
            .clamp(0, 100);

    Color color = AppColors.tertiary;

    if (score < 70) color = AppColors.moderateAmber;
    if (score < 50) color = AppColors.error;

    final status = score >= 80
        ? (isHindi ? 'निष्पक्ष' : 'FAIR')
        : score >= 60
            ? (isHindi ? 'चेतावनी' : 'WARNING')
            : (isHindi ? 'असफल' : 'FAILED');

    return Container(
      width: 320,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            isHindi
                ? 'इक्विटी स्कोर'
                : AppStrings.equityScore,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: 160,
            height: 160,
            child: CircularProgressIndicator(
              value: score / 100,
              strokeWidth: 14,
              color: color,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '$score / 100',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 16),
          Chip(label: Text(status)),
        ],
      ),
    );
  }

  Widget _buildBiasStatusCard(
    BuildContext context,
    Map<String, dynamic> metrics,
  ) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _MetricRow(
            label: 'Demographic Parity',
            value: metrics['demographic_parity'],
          ),
          const Divider(),
          _MetricRow(
            label: 'Equal Opportunity',
            value: metrics['equal_opportunity'],
          ),
          const Divider(),
          _MetricRow(
            label: 'Equalized Odds',
            value: metrics['equalized_odds'],
          ),
          const Divider(),
          _MetricRow(
            label: 'Predictive Parity',
            value: metrics['predictive_parity'],
          ),
        ],
      ),
    );
  }

  Widget _buildProxyDetection(
    BuildContext context,
    List<Map<String, dynamic>> proxies,
    bool isHindi,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            isHindi
                ? 'प्रॉक्सी सुविधाएँ'
                : AppStrings.proxyFeatures,
          ),
          const SizedBox(height: 20),

          if (proxies.isEmpty)
            Text(
              isHindi
                  ? 'कोई महत्वपूर्ण प्रॉक्सी नहीं मिली।'
                  : 'No significant proxies detected.',
            ),

          ...proxies.map(
            (e) => Padding(
              padding:
                  const EdgeInsets.only(bottom: 12),
              child: _ProxyCard(
                feature: e['column'] ?? 'Unknown',
                proxyFor:
                    e['reason'] ?? 'Hidden Factor',
                correlation:
                    '${e['correlation'] ?? 0}',
                isHindi: isHindi,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiAnalysis(
    BuildContext context,
    Map<String, dynamic> analysis,
    bool isHindi,
  ) {
    final summary = isHindi
        ? (analysis['explanation_hi'] ??
            'विश्लेषण उपलब्ध नहीं है।')
        : (analysis['explanation_en'] ??
            'Analysis unavailable.');

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            isHindi
                ? 'एआई विश्लेषण'
                : AppStrings.aiAnalysis,
          ),
          const SizedBox(height: 20),
          Text(summary),
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  final String label;
  final dynamic value;

  const _MetricRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    double fairness = 0;

    if (value is num) {
      fairness = 1.0 - value.toDouble();

      if (fairness < 0) fairness = 0;
      if (fairness > 1) fairness = 1;
    }

    Color color = AppColors.tertiary;

    if (fairness < 0.8) {
      color = AppColors.moderateAmber;
    }

    if (fairness < 0.5) {
      color = AppColors.error;
    }

    return Padding(
      padding:
          const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(label),
          ),
          Expanded(
            flex: 5,
            child: LinearProgressIndicator(
              value: fairness,
              minHeight: 10,
              color: color,
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 60,
            child: Text(
              '${(fairness * 100).toInt()}%',
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProxyCard extends StatelessWidget {
  final String feature;
  final String proxyFor;
  final String correlation;
  final bool isHindi;

  const _ProxyCard({
    required this.feature,
    required this.proxyFor,
    required this.correlation,
    required this.isHindi,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius:
            BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            feature,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isHindi
                ? 'इसके लिए प्रॉक्सी: $proxyFor'
                : 'Proxies for: $proxyFor',
          ),
          const SizedBox(height: 6),
          Text('r = $correlation'),
        ],
      ),
    );
  }
}