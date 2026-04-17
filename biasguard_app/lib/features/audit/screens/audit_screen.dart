import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/locale_provider.dart';
import '../../../core/services/auth_service.dart';

class AuditScreen extends ConsumerStatefulWidget {
  const AuditScreen({super.key});

  @override
  ConsumerState<AuditScreen> createState() => _AuditScreenState();
}

class _AuditScreenState extends ConsumerState<AuditScreen> {
  bool _isDragging = false;
  bool _isUploading = false;
  bool _anonymizeData = true; // Default to true for safety
  PlatformFile? _selectedFile;

  void _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      allowMultiple: false,
    );

    if (result != null && result.files.isNotEmpty) {
      if (mounted) {
        setState(() {
          _selectedFile = result.files.first;
        });
        _startScan();
      }
    }
  }

  void _useDemoData(String name) {
    if (mounted) {
      context.pushNamed('processing', extra: {
        'fileName': name,
        'scanId': 'demo-${DateTime.now().millisecondsSinceEpoch}',
        'storagePath': 'demo_datasets/$name',
        'isDemo': true,
        'anonymize': false, // Demo data is already safe
      });
    }
  }

  Future<void> _startScan() async {
    if (_selectedFile == null || !mounted) return;

    setState(() => _isUploading = true);

    try {
      final scanId = 'scan-${DateTime.now().millisecondsSinceEpoch}';
      
      // 1. Read file bytes locally (Works on Web and Mobile)
      final bytes = _selectedFile!.bytes;
      if (bytes == null) {
        throw Exception("File data is not available.");
      }
      
      final csvString = utf8.decode(bytes);

      // 2. Navigate to processing with the actual CSV string
      if (mounted) {
        context.pushNamed('processing', extra: {
          'fileName': _selectedFile!.name,
          'scanId': scanId,
          'csvData': csvString, // NEW: Pass data directly
          'isDemo': false,
          'anonymize': _anonymizeData,
          'useCase': 'General Audit',
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Processing failed: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isHindi = ref.watch(localeProvider.notifier).isHindi;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isHindi ? 'नया पूर्वाग्रह ऑडिट' : AppStrings.uploadTitle,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            isHindi 
              ? 'संरचनात्मक पूर्वाग्रहों का पता लगाने के लिए एक डेटासेट अपलोड करें' 
              : AppStrings.uploadSubtitle,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: 48),

          // Privacy Toggle
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary.withOpacity(0.1)),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield_outlined, color: AppColors.primary),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isHindi ? 'डेटा गुमनामी लागू करें' : 'Enforce Data Anonymization',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Text(
                        isHindi 
                          ? 'नाम और व्यक्तिगत आईडी जैसे PII को अपलोड करने से पहले मास्क करें।' 
                          : 'Mask PII like names and IDs before cloud processing.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _anonymizeData,
                  activeColor: AppColors.primary,
                  onChanged: (val) => setState(() => _anonymizeData = val),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Drop zone
          MouseRegion(
            onEnter: (_) => setState(() => _isDragging = true),
            onExit: (_) => setState(() => _isDragging = false),
            child: GestureDetector(
              onTap: _pickFile,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(64),
                decoration: BoxDecoration(
                  color: _isDragging
                      ? AppColors.surfaceContainerLow
                      : AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: _isDragging
                        ? AppColors.primary
                        : AppColors.outlineVariant,
                    width: _isDragging ? 2 : 1,
                  ),
                ),
                child: Center(
                  child: _isUploading
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text(isHindi ? 'डेटासेट अपलोड हो रहा है...' : 'Uploading dataset...'),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: const BoxDecoration(
                              color: AppColors.surfaceContainerHigh,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.upload_file,
                              size: 48,
                              color: _isDragging ? AppColors.primary : AppColors.onSurface,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            isHindi ? 'डेटा फ़ाइल यहाँ खींचें' : AppStrings.dragDrop,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            AppStrings.uploadFormat,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: AppColors.onSurfaceVariant),
                          ),
                          const SizedBox(height: 32),
                          ElevatedButton.icon(
                            onPressed: _isUploading ? null : _pickFile,
                            icon: const Icon(Icons.folder_open),
                            label: Text(isHindi ? 'फ़ाइलें ब्राउज़ करें' : AppStrings.browseFiles),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryContainer,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                            ),
                          ),
                        ],
                      ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 64),
          Text(
            isHindi ? 'या एक डेमो डेटासेट आज़माएं:' : 'Or try a demo dataset:',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          
          Row(
            children: [
              _DemoCard(
                title: 'Bihar Scholarship 2026',
                rows: '10,000',
                icon: Icons.school,
                onTap: () => _useDemoData('bihar_scholarship_2026.csv'),
              ),
              const SizedBox(width: 16),
              _DemoCard(
                title: 'AI Hiring Algorithm',
                rows: '5,000',
                icon: Icons.work,
                onTap: () => _useDemoData('hiring_bias_demo.csv'),
              ),
              const SizedBox(width: 16),
              _DemoCard(
                title: 'Loan Applications',
                rows: '2,500',
                icon: Icons.real_estate_agent,
                onTap: () => _useDemoData('loan_application_demo.csv'),
              ),
            ],
          ),

          // ─── Why Audit Section (from Stitch) ───────────────
          const SizedBox(height: 64),
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.bolt, color: AppColors.primary, size: 28),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isHindi ? 'आपके डेटा का ऑडिट क्यों?' : 'Why Audit Your Data?',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        isHindi
                            ? 'हमारी सर्वोच्च बुद्धिमत्ता लिंग, जातीयता और सामाजिक-आर्थिक संकेतकों में छिपे पूर्वाग्रह की पहचान करती है।'
                            : 'Our sovereign intelligence identifies latent bias across gender, ethnicity, and socio-economic indicators that standard statistical tests miss. Upload your CSV to generate a comprehensive Sentinel Report.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: AppColors.onSurfaceVariant,
                              height: 1.6,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ─── Bottom Status Bar ──────────────────────────────
          const SizedBox(height: 32),
          Center(
            child: Text(
              'Sovereign Intelligence • Data Privacy Encrypted',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.outline,
                    letterSpacing: 1.5,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DemoCard extends StatelessWidget {
  final String title;
  final String rows;
  final IconData icon;
  final VoidCallback onTap;

  const _DemoCard({
    required this.title,
    required this.rows,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        color: AppColors.surfaceContainerLow,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.surfaceContainerHigh),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: AppColors.primary),
                const SizedBox(height: 16),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text('$rows rows · .csv', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.onSurfaceVariant)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
