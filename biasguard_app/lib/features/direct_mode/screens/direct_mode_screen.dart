import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/gemini_service.dart';
import '../../../core/services/auth_service.dart';

class DirectModeScreen extends StatefulWidget {
  const DirectModeScreen({super.key});

  @override
  State<DirectModeScreen> createState() => _DirectModeScreenState();
}

class _DirectModeScreenState extends State<DirectModeScreen> {
  String _selectedUseCase = AppStrings.useCaseTypes.first;
  final _scenarioController = TextEditingController();
  bool _isLoading = false;
  bool _showResult = false;
  Map<String, dynamic>? _apiResult;

  void _getRecommendation() async {
    if (_scenarioController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please describe the scenario before requesting a decision.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _showResult = false;
      _apiResult = null;
    });

    final result = await geminiService.getDirectFairDecision(
      'Use Case: $_selectedUseCase\nScenario: ${_scenarioController.text}',
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        _apiResult = result;
        _showResult = true;
      });

      // Persistent History Log
      if (result != null) {
        final uid = AuthService().currentUid ?? 'anonymous';
        FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('direct_queries')
            .add({
          'use_case': _selectedUseCase,
          'scenario': _scenarioController.text,
          'recommendation': result['recommendation'],
          'created_at': FieldValue.serverTimestamp(),
        });
      }
    }
  }

  @override
  void dispose() {
    _scenarioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Direct Mode'),
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left side: Input Context
          Expanded(
            flex: 2,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.directTitle,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppStrings.directSubtitle,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 48),
                  Text(
                    AppStrings.useCaseType,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedUseCase,
                        isExpanded: true,
                        dropdownColor: AppColors.surfaceContainerHigh,
                        icon: const Icon(Icons.arrow_drop_down, color: AppColors.outline),
                        items: AppStrings.useCaseTypes
                            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedUseCase = val);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    AppStrings.describeScenario,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 8),
                   ValueListenableBuilder(
                    valueListenable: _scenarioController,
                    builder: (context, value, child) {
                      return TextField(
                        controller: _scenarioController,
                        maxLines: 8,
                        style: const TextStyle(color: AppColors.onSurface),
                        decoration: InputDecoration(
                          hintText: 'E.g., Candidate has 5 years of experience in Java, a degree from a state university, and requested 80k salary...',
                          errorText: value.text.isEmpty && _showResult == false ? null : null, // Future: add semantic error state
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _getRecommendation,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.psychology),
                      label: Text(_isLoading ? 'Analyzing...' : AppStrings.getFairDecision),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.gradientStart,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Right side: Results
          Expanded(
            flex: 3,
            child: Container(
              margin: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.surfaceContainerHighest),
              ),
              child: _showResult
                  ? _buildResultView(context)
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.balance,
                            size: 64,
                            color: AppColors.outlineVariant.withOpacity(0.5),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Await AI Recommendation',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  color: AppColors.outlineVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultView(BuildContext context) {
    if (_apiResult == null) return const SizedBox.shrink();

    final recommendation = _apiResult!['recommendation'] as String? ?? 'REVIEW';
    final explanation = _apiResult!['explanation_en'] as String? ?? '';
    final factorsConsidered = (_apiResult!['factors_considered'] as List?)?.cast<String>() ?? [];
    final factorsIgnored = (_apiResult!['factors_explicitly_ignored'] as List?)?.cast<String>() ?? [];

    Color verdictColor = AppColors.moderateAmber;
    if (recommendation == 'APPROVE') verdictColor = AppColors.tertiary;
    if (recommendation == 'REJECT') verdictColor = AppColors.error;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_outline, color: AppColors.primary, size: 32),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recommendation Ready',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppColors.primary),
                  ),
                  Text(
                    'Powered by Gemini FairAI Model',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.onSurfaceVariant),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 48),
          
          Text(
            'The Verdict',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.onSurfaceVariant,
                  letterSpacing: 2,
                ),
          ),
          const SizedBox(height: 16),
          Text(
            recommendation,
            style: Theme.of(context).textTheme.displaySmall?.copyWith(color: verdictColor),
          ),
          const SizedBox(height: 24),
          Text(
            explanation,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.6),
          ),
          const SizedBox(height: 48),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildFactorList(
                  context,
                  title: 'Factors Considered',
                  icon: Icons.done_all,
                  color: AppColors.primary,
                  items: factorsConsidered,
                ),
              ),
              const SizedBox(width: 32),
              Expanded(
                child: _buildFactorList(
                  context,
                  title: 'Factors Ignored',
                  icon: Icons.visibility_off,
                  color: AppColors.error,
                  items: factorsIgnored,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFactorList(BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required List<String> items,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 16),
          ...items.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('• ', style: TextStyle(color: color, fontSize: 18)),
                Expanded(
                  child: Text(e, style: Theme.of(context).textTheme.bodyMedium),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
}
