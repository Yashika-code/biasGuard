import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/providers/locale_provider.dart';
import '../../../core/providers/settings_provider.dart';
import 'package:go_router/go_router.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final appLocale = ref.watch(localeProvider);
    final settings = ref.watch(settingsProvider);
    final isHindi = appLocale == AppLocale.hi;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: ListView(
        padding: const EdgeInsets.all(32),
        children: [
          Text(
            isHindi ? 'सिस्टम सेटिंग्स' : 'System Settings',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 32),

          // ── Appearance & Language ─────────────────────────────────────────
          _sectionHeader(context, isHindi ? 'दिखावट और भाषा' : 'Appearance & Language'),
          const SizedBox(height: 16),

          _buildSwitchTile(
            context,
            isHindi ? 'डार्क मोड' : 'Dark Mode',
            isHindi
                ? 'Sentinel Obsidian उच्च-कंट्रास्ट डार्क थीम सक्षम करें।'
                : 'Enable high-contrast dark theme (Sentinel Obsidian).',
            themeMode == ThemeMode.dark,
            (_) => ref.read(themeProvider.notifier).toggleTheme(),
          ),
          const Divider(),

          _buildDropdownTile(
            context,
            isHindi ? 'भाषा' : 'Application Language',
            isHindi
                ? 'अपनी पसंदीदा इंटरफ़ेस भाषा चुनें।'
                : 'Select your preferred interface language.',
            isHindi ? 'Hindi' : 'English',
            ['English', 'Hindi'],
            (val) {
              if (val == null) return;
              final currentlyHindi = ref.read(localeProvider.notifier).isHindi;
              final selectingHindi = val == 'Hindi';
              // Only toggle if the selection is different from current
              if (selectingHindi != currentlyHindi) {
                ref.read(localeProvider.notifier).toggleLocale();
              }
            },
          ),
          const SizedBox(height: 40),

          // ── Preferences ───────────────────────────────────────────────────
          _sectionHeader(context, isHindi ? 'वरीयताएँ' : 'Preferences'),
          const SizedBox(height: 16),

          _buildSwitchTile(
            context,
            isHindi ? 'सख्त समानता मोड' : 'Strict Parity Mode',
            isHindi
                ? 'Equal Opportunity पर उच्चतम बाधाएं स्वचालित रूप से लागू करें।'
                : 'Enforce highest constraints on Equal Opportunity automatically.',
            settings.strictParityMode,
            (_) => ref.read(settingsProvider.notifier).toggleStrictParity(),
          ),
          const Divider(),

          _buildSwitchTile(
            context,
            isHindi ? 'डेटा अनामीकरण' : 'Data Anonymization',
            isHindi
                ? 'Gemini API को भेजने से पहले PII को स्वचालित रूप से छुपाएं।'
                : 'Automatically obfuscate PII before sending to Gemini API.',
            settings.dataAnonymization,
            (_) => ref.read(settingsProvider.notifier).toggleDataAnonymization(),
          ),
          const Divider(),

          _buildSwitchTile(
            context,
            isHindi ? 'GCP में रिपोर्ट निर्यात करें' : 'Export Reports to GCP',
            isHindi
                ? 'उत्पन्न PDF रिपोर्ट को Google Cloud Storage बकेट में स्वचालित रूप से बैकअप करें।'
                : 'Automatically backup generated PDF reports to Google Cloud Storage bucket.',
            settings.exportToGcp,
            (_) => ref.read(settingsProvider.notifier).toggleExportToGcp(),
          ),
          const SizedBox(height: 40),

          // ── Legal & Privacy ───────────────────────────────────────────────
          _sectionHeader(context, isHindi ? 'कानूनी और गोपनीयता' : 'Legal & Privacy'),
          const SizedBox(height: 16),

          ListTile(
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
            title: Text(isHindi ? 'गोपनीयता नीति' : 'Privacy Policy',
                style: Theme.of(context).textTheme.titleMedium),
            subtitle: Text(
              isHindi ? 'हम आपके डेटा को कैसे सुरक्षित रखते हैं' : 'How we protect your data integrity.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.onSurfaceVariant),
            ),
            trailing: const Icon(Icons.chevron_right, color: AppColors.onSurfaceVariant),
            onTap: () => context.push('/settings/privacy'),
          ),
          const Divider(),

          ListTile(
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
            title: Text(isHindi ? 'सेवा की शर्तें' : 'Terms of Service',
                style: Theme.of(context).textTheme.titleMedium),
            subtitle: Text(
              isHindi ? 'उपयोग की शर्तें और कानूनी सीमाएं' : 'Usage conditions and legal boundaries.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.onSurfaceVariant),
            ),
            trailing: const Icon(Icons.chevron_right, color: AppColors.onSurfaceVariant),
            onTap: () => context.push('/settings/terms'),
          ),

          const SizedBox(height: 64),
          Center(
            child: Text(
              'BiasGuard v1.0.0+1\nGoogle Solution Challenge 2026',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w600,
          ),
    );
  }

  Widget _buildSwitchTile(
    BuildContext context,
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppColors.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownTile(
    BuildContext context,
    String title,
    String subtitle,
    String current,
    List<String> options,
    ValueChanged<String?> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppColors.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          DropdownButton<String>(
            value: current,
            dropdownColor: AppColors.surfaceContainerHigh,
            underline: const SizedBox(),
            onChanged: onChanged,
            items: options
                .map((opt) => DropdownMenuItem(
                      value: opt,
                      child: Text(opt, style: Theme.of(context).textTheme.bodyLarge),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}
