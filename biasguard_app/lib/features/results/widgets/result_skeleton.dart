import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/theme/app_theme.dart';

class ResultSkeleton extends StatelessWidget {
  const ResultSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _shimmerBox(320, 300), // Score Card
              const SizedBox(width: 24),
              Expanded(child: _shimmerBox(double.infinity, 300)), // Metrics Card
            ],
          ),
          const SizedBox(height: 32),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _shimmerBox(400, 400), // Proxies
              const SizedBox(width: 24),
              Expanded(child: _shimmerBox(double.infinity, 400)), // AI Analysis
            ],
          ),
        ],
      ),
    );
  }

  Widget _shimmerBox(double width, double height) {
    return Shimmer.fromColors(
      baseColor: AppColors.surfaceContainerHigh,
      highlightColor: AppColors.surfaceContainerHighest,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}
