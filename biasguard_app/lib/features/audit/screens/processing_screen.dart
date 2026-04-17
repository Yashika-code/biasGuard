import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/gemini_service.dart';
import '../../../core/services/fairness_engine.dart';
import 'dart:math' as math;

class ProcessingScreen extends StatefulWidget {
  final String scanId;
  final String fileName;
  final String? csvData; // Changed from storagePath
  final bool isDemo;
  final String? useCase;

  const ProcessingScreen({
    super.key,
    required this.scanId,
    required this.fileName,
    this.csvData,
    this.isDemo = false,
    this.useCase,
    // Keep backward compatibility for demo routes if needed
    String? storagePath, 
  });

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  int _currentStep = 0;
  final AuthService _auth = AuthService();
  final FairnessEngine _engine = FairnessEngine();
  
  final List<String> _steps = [
    AppStrings.processingStep1, // Data validation
    AppStrings.processingStep2, // Detecting Sensitive Groups
    AppStrings.processingStep3, // Calculating Metrics
    AppStrings.processingStep4, // AI Analysis
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _runLocalProcessing();
  }

  void _runLocalProcessing() async {
    try {
      final uid = _auth.currentUid ?? 'anonymous';
      String dataToProcess = widget.csvData ?? '';

      // Step 0: Handle Demo Data
      if (widget.isDemo) {
        setState(() => _currentStep = 0);
        // Map common demo file names to their asset paths
        final assetPath = 'assets/demo/${widget.fileName}';
        try {
          dataToProcess = await rootBundle.loadString(assetPath);
        } catch (e) {
          throw Exception("Could not load demo data: ${widget.fileName}. Ensure it exists in assets.");
        }
        await Future.delayed(const Duration(milliseconds: 1000));
      }

      if (dataToProcess.isEmpty) {
        throw Exception("No data provides for processing.");
      }

      // Step 1: Validation
      setState(() => _currentStep = 0);
      await Future.delayed(const Duration(milliseconds: 800));

      // Step 2 & 3: Run Fairness Engine Locally
      setState(() => _currentStep = 1);
      await Future.delayed(const Duration(milliseconds: 500));
      
      setState(() => _currentStep = 2);
      final results = _engine.runFullMetrics(dataToProcess, null);
      
      // Step 4: Local AI Analysis
      setState(() => _currentStep = 3);
      final analysis = await geminiService.analyseAuditResults(
        useCase: widget.useCase ?? 'General Audit',
        columns: results['column_names'],
        groupStats: results['group_stats'],
        overallRate: results['overall_approval_rate'],
        demographicParity: results['demographic_parity'],
        equityScore: results['equity_score'],
      );

      // Final Step: Write to Firestore (Persistence)
      final scanRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('scans')
          .doc(widget.scanId);

      final scanData = {
        'fileName': widget.fileName,
        'dataset_name': widget.fileName,
        'status': 'analysis_complete',
        'use_case': 'General',
        'updated_at': FieldValue.serverTimestamp(),
        'created_at': FieldValue.serverTimestamp(),
        // Core Metrics
        'metrics': {
          'equity_score': results['equity_score'] ?? 0,
          'demographic_parity': results['demographic_parity'] ?? 0,
          'equal_opportunity': results['equal_opportunity'] ?? 0,
          'equalized_odds': results['equalized_odds'] ?? 0,
          'predictive_parity': results['predictive_parity'] ?? 0,
          'consistency': results['consistency'] ?? 0,
          'severity': results['severity'] ?? 'LOW',
          'row_count': results['total_count'],
          'group_stats': results['group_stats'],
        },
        // AI Analysis
        'analysis': analysis,
        // Proxies (if any)
        'proxies': results['proxies'] ?? [],
      };

      // Fire-and-forget to Firestore (DO NOT await) so UI doesn't hang if backend is unreachable
      scanRef.set(scanData).catchError((_) => null);

      if (mounted) {
        context.goNamed('results', extra: {
          'scanId': widget.scanId,
          'scanData': scanData,
        });
      }
    } catch (e) {
      _handleError(e.toString());
    }
  }

  void _handleError(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Processing Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: const Text('Go Back'),
          ),
        ],
      ),
    ).then((_) {
      if (mounted) context.pop();
    });
  }


  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Spinning Core with Pulse
              AnimatedBuilder(
                animation: _animController,
                builder: (context, child) {
                  final pulseValue = 1.0 + (math.sin(_animController.value * 2 * math.pi) * 0.1);
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      // Pulse effect circles
                      ...List.generate(3, (i) {
                        final waveValue = (_animController.value + (i * 0.33)) % 1.0;
                        return Container(
                          width: 120 + (100 * waveValue),
                          height: 120 + (100 * waveValue),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.primary.withOpacity((1.0 - waveValue) * 0.3),
                              width: 2,
                            ),
                          ),
                        );
                      }),
                      
                      // Central Rotating Core
                      Transform.rotate(
                        angle: _animController.value * 2 * math.pi,
                        child: Transform.scale(
                          scale: pulseValue,
                          child: Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const SweepGradient(
                                colors: [
                                  AppColors.gradientStart,
                                  AppColors.gradientEnd,
                                  Colors.transparent,
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.4),
                                  blurRadius: 40,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: Container(
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.surfaceContainerHigh,
                                ),
                                child: const Icon(Icons.auto_awesome, color: AppColors.primary, size: 56),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 64),
              
              // Status Text
              Text(
                'Scanning ${widget.fileName}...',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 48),

              // Steps List
              ...List.generate(_steps.length, (index) {
                final isPast = index < _currentStep;
                final isCurrent = index == _currentStep;
                final isFuture = index > _currentStep;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 32.0),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isPast 
                              ? AppColors.tertiary
                              : isCurrent 
                                  ? AppColors.primaryContainer
                                  : AppColors.surfaceContainerHigh,
                        ),
                        child: Icon(
                          isPast ? Icons.check : (isCurrent ? Icons.circle : null),
                          size: 14,
                          color: isPast ? AppColors.onTertiary : Colors.white,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        _steps[index],
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: isPast || isCurrent 
                              ? AppColors.onSurface 
                              : AppColors.onSurfaceVariant,
                          fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      if (isCurrent)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        )
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
