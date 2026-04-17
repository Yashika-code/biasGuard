import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('About BiasGuard'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [AppColors.gradientStart, AppColors.gradientEnd],
                ),
              ),
              child: const Icon(Icons.balance, size: 80, color: Colors.white),
            ),
            const SizedBox(height: 48),
            Text('BiasGuard', style: Theme.of(context).textTheme.displayMedium),
            const SizedBox(height: 16),
            Text('Version 1.0.0 (Sentinel Release)', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.onSurfaceVariant)),
            const SizedBox(height: 48),
            SizedBox(
              width: 500,
              child: Text(
                'BiasGuard is an enterprise-grade web application built to audit and mitigate systemic bias in demographic datasets and algorithmic decision making. Powered by Google Gemini and advanced demographic parity algorithms.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.6, color: AppColors.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
