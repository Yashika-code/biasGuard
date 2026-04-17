import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Policy')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('BiasGuard Privacy Commitment', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 24),
            _buildSection(context, '1. Data Integrity', 
              'We prioritize the Sovereign Intelligence of your organization. All datasets uploaded for auditing are processed through encrypted channels. If "Anonymize Data" is enabled, PII is masked locally before transmission.'),
            _buildSection(context, '2. AI Processing', 
              'Our fairness audits utilize Google Gemini 1.5 Pro. Your data is not used for model training; it is only analyzed for the duration of the audit session.'),
            _buildSection(context, '3. Storage', 
              'Audit reports are stored under your unique UID in Firebase. You may delete your history at any time through the dashboard.'),
            const SizedBox(height: 32),
            Text('Contact us at privacy@biasguard-ai.gov for detailed compliance documentation.', 
              style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.primary)),
          const SizedBox(height: 8),
          Text(content, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.6)),
        ],
      ),
    );
  }
}
