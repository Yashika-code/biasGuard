import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Settings State ──────────────────────────────────────────────────────────

class AppSettings {
  final bool strictParityMode;
  final bool dataAnonymization;
  final bool exportToGcp;

  const AppSettings({
    this.strictParityMode = true,
    this.dataAnonymization = true,
    this.exportToGcp = false,
  });

  AppSettings copyWith({
    bool? strictParityMode,
    bool? dataAnonymization,
    bool? exportToGcp,
  }) {
    return AppSettings(
      strictParityMode: strictParityMode ?? this.strictParityMode,
      dataAnonymization: dataAnonymization ?? this.dataAnonymization,
      exportToGcp: exportToGcp ?? this.exportToGcp,
    );
  }
}

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier() : super(const AppSettings()) {
    _load();
  }

  static const _strictParityKey = 'strict_parity';
  static const _anonymizeKey = 'data_anonymize';
  static const _gcpKey = 'export_gcp';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = AppSettings(
      strictParityMode: prefs.getBool(_strictParityKey) ?? true,
      dataAnonymization: prefs.getBool(_anonymizeKey) ?? true,
      exportToGcp: prefs.getBool(_gcpKey) ?? false,
    );
  }

  Future<void> toggleStrictParity() async {
    final prefs = await SharedPreferences.getInstance();
    state = state.copyWith(strictParityMode: !state.strictParityMode);
    await prefs.setBool(_strictParityKey, state.strictParityMode);
  }

  Future<void> toggleDataAnonymization() async {
    final prefs = await SharedPreferences.getInstance();
    state = state.copyWith(dataAnonymization: !state.dataAnonymization);
    await prefs.setBool(_anonymizeKey, state.dataAnonymization);
  }

  Future<void> toggleExportToGcp() async {
    final prefs = await SharedPreferences.getInstance();
    state = state.copyWith(exportToGcp: !state.exportToGcp);
    await prefs.setBool(_gcpKey, state.exportToGcp);
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier();
});
