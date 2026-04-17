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

  const ResultsScreen({super.key, required this.scanId, this.scanData});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = AuthService().currentUid ?? 'anonymous';
    final isHindi = ref.watch(localeProvider.notifier).isHindi;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(isHindi ? 'ऑडिट परिणाम' : 'Audit Results'),
        actions: [
          ElevatedButton.icon(
            onPressed: () => context.pushNamed('report', extra: {'scanId': scanId}),
            icon: const Icon(Icons.picture_as_pdf),
            label: Text(isHindi ? 'रिपोर्ट डाउनलोड करें' : AppStrings.downloadReport),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.surfaceContainerHigh,
              foregroundColor: AppColors.onSurface,
              elevation: 0,
            ),
          ),
          const SizedBox(width: 16),
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
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const ResultSkeleton();
                }

                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return _buildNotFound(context);
                }

                final data = snapshot.data!.data() as Map<String, dynamic>;
                return _buildResultsContent(context, data, isHindi);
              },
            ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(24),
        color: AppColors.surfaceContainerLow,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            OutlinedButton(
              onPressed: () => context.goNamed('dashboard'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                foregroundColor: AppColors.onSurface,
                side: const BorderSide(color: AppColors.outlineVariant),
              ),
              child: Text(isHindi ? 'डैशबोर्ड पर लौटें' : 'Return to Dashboard'),
            ),
            const SizedBox(width: 16),
            ElevatedButton(
              onPressed: () => context.pushNamed('counterfactual', extra: {'scanId': scanId}),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                backgroundColor: AppColors.gradientStart,
                foregroundColor: Colors.white,
              ),
              child: Text(
                isHindi ? 'पूर्वाग्रह सुधारें' : AppStrings.fixBias,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsContent(BuildContext context, Map<String, dynamic> data, bool isHindi) {
    final metrics = data['metrics'] as Map<String, dynamic>? ?? {};
    final analysis = data['analysis'] as Map<String, dynamic>? ?? {};
    final proxies = (data['proxies'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Section: Score & Status
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildEquityScoreCard(context, metrics, isHindi),
              const SizedBox(width: 24),
              Expanded(child: _buildBiasStatusCard(context, metrics, isHindi)),
            ],
          ),
          const SizedBox(height: 32),

          // Middle Section: Proxy Detection & AI Explanation
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 1, child: _buildProxyDetection(context, proxies, isHindi)),
              const SizedBox(width: 24),
              Expanded(flex: 2, child: _buildAiAnalysis(context, analysis, isHindi)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNotFound(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: AppColors.error),
          const SizedBox(height: 16),
          Text('Audit Data Not Found', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text('Scan ID: $scanId'),
        ],
      ),
    );
  }

  Widget _buildEquityScoreCard(BuildContext context, Map<String, dynamic> metrics, bool isHindi) {
    final score = (metrics['equity_score'] ?? 0).toInt();
    final severity = (metrics['severity'] as String?)?.toUpperCase() ?? 'PENDING';
    
    Color scoreColor = AppColors.tertiary;
    if (score < 70) scoreColor = AppColors.moderateAmber;
    if (score < 50) scoreColor = AppColors.error;

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
            isHindi ? 'इक्विटी स्कोर' : AppStrings.equityScore,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 32),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 160,
                height: 160,
                child: CircularProgressIndicator(
                  value: score / 100,
                  strokeWidth: 16,
                  backgroundColor: AppColors.surfaceContainerHighest,
                  color: scoreColor,
                  strokeCap: StrokeCap.round,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$score',
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                          color: scoreColor,
                          height: 1.0,
                        ),
                  ),
                  Text(
                    '/ 100',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: scoreColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: scoreColor.withOpacity(0.5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shield_outlined, color: scoreColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  severity == 'LOW' ? (isHindi ? 'निष्पक्ष' : 'FAIR') : severity,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: scoreColor,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBiasStatusCard(BuildContext context, Map<String, dynamic> metrics, bool isHindi) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isHindi ? 'निष्पक्षता मेट्रिक्स विवरण' : 'Fairness Metrics Breakdown',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 24),
          _MetricRow(
            label: isHindi ? 'जनसांख्यिकीय समानता' : AppStrings.demographicParity,
            value: metrics['demographic_parity'] ?? 0.0,
            threshold: 0.8,
          ),
          const Divider(height: 32),
          _MetricRow(
            label: isHindi ? 'समान अवसर' : 'Equal Opportunity',
            value: metrics['equal_opportunity'] ?? 0.0,
            threshold: 0.8,
          ),
          const Divider(height: 32),
          _MetricRow(
            label: isHindi ? 'समूह दर निरंतरता' : 'Group Rate Consistency',
            value: metrics['consistency'] ?? 1.0,
            threshold: 0.9,
          ),
        ],
      ),
    );
  }

  Widget _buildProxyDetection(BuildContext context, List<Map<String, dynamic>> proxies, bool isHindi) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isHindi ? 'प्रॉक्सी सुविधाएँ' : AppStrings.proxyFeatures,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 24),
          if (proxies.isEmpty)
             Padding(
               padding: const EdgeInsets.symmetric(vertical: 24),
               child: Center(child: Text(isHindi ? 'कोई महत्वपूर्ण प्रॉक्सी नहीं मिली।' : "No significant proxies detected.")),
             ),
          ...proxies.map((p) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _ProxyCard(
              feature: p['column'] ?? 'Unknown',
              proxyFor: p['reason'] ?? 'Hidden Factor',
              correlation: p['correlation']?.toString() ?? '0.0',
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildAiAnalysis(BuildContext context, Map<String, dynamic> analysis, bool isHindi) {
    final summary = isHindi 
        ? (analysis['explanation_hi'] ?? "हमारे एआई मॉडल आपके डेटासेट के अंतिम निहितार्थों को संसाधित कर रहे हैं।")
        : (analysis['explanation_en'] ?? "Our AI models are processing the final implications of your dataset.");
    
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                isHindi ? 'एआई विश्लेषण' : AppStrings.aiAnalysis,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.primary,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
              border: const Border(
                left: BorderSide(color: AppColors.primaryContainer, width: 4),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isHindi ? 'पूर्वावलोकन सारांश' : "Analysis Summary",
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.primary,
                      ),
                ),
                const SizedBox(height: 16),
                Text(
                  summary,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.6),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  final String label;
  final dynamic value;
  final double threshold;

  const _MetricRow({
    required this.label,
    required this.value,
    required this.threshold,
  });

  @override
  Widget build(BuildContext context) {
    final double val = (value is num) ? value.toDouble() : 0.0;
    final bool passed = val >= threshold;
    final statusColor = passed ? AppColors.tertiary : (val < 0.5 ? AppColors.error : AppColors.moderateAmber);
    final statusText = passed ? 'Passed' : (val < 0.5 ? 'Failed' : 'Warning');

    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        Expanded(
          flex: 3,
          child: Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: val.clamp(0.0, 1.0),
                  backgroundColor: AppColors.surfaceContainerHighest,
                  color: statusColor,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 16),
              Text(
                '${(val * 100).toInt()}%',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        SizedBox(
          width: 100,
          child: Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                statusText,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProxyCard extends StatelessWidget {
  final String feature;
  final String proxyFor;
  final String correlation;

  const _ProxyCard({
    required this.feature,
    required this.proxyFor,
    required this.correlation,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceContainerHighest),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                feature,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontFamily: 'monospace',
                    ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.errorContainer.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'r = $correlation',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.error,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Proxies for: $proxyFor',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

