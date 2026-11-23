import 'package:flutter/foundation.dart';

import '../models/app_configuration.dart';
import '../services/api_service.dart';

class ConfigurationProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  static const String moduleZakatFitrah = 'ZAKATFITRAH';

  /// Codes whose value differs per Zakat year (everything else is global).
  static const Set<String> perYearCodes = {'TITIP_UANG', 'IKRAR_ZAKAT'};

  final List<AppConfiguration> _rows = [];
  String _yearId = '';
  bool isLoading = false;
  bool isSaving = false;
  String? errorMessage;

  /// Rows effective for the loaded year: a year-specific row replaces the
  /// global row with the same code; rows of other years are dropped.
  List<AppConfiguration> get configurations => List.unmodifiable(
        effective(_rows, _yearId),
      );

  static List<AppConfiguration> effective(
      List<AppConfiguration> rows, String yearId) {
    final forYear = rows
        .where((c) => c.yearId.isNotEmpty && c.yearId == yearId)
        .map((c) => c.code)
        .toSet();
    return rows.where((c) {
      if (c.yearId.isNotEmpty) return c.yearId == yearId;
      return !forYear.contains(c.code);
    }).toList();
  }

  /// Value of [code] for [yearId]: the year's own row, else the global one.
  static String? resolveValue(
      List<AppConfiguration> rows, String code, String yearId) {
    final match = effective(rows, yearId).where((c) => c.code == code);
    return match.isEmpty ? null : match.first.value;
  }

  /// Fetches the configuration rows and resolves [code] for [yearId]. Done
  /// client-side so it also works while the backend ignores `year_id`.
  Future<String?> fetchEffectiveValue(String code, String yearId) async {
    final response =
        await _api.getConfigurationsByModule(moduleZakatFitrah, yearId: yearId);
    final raw = response.data;
    final List<dynamic> list = raw is List
        ? raw
        : (raw as Map<String, dynamic>)['data'] as List<dynamic>? ?? [];
    final rows = list
        .whereType<Map<String, dynamic>>()
        .map(AppConfiguration.fromJson)
        .toList();
    return resolveValue(rows, code, yearId);
  }

  Future<void> fetchConfigurations({String? module, String? yearId}) async {
    if (yearId != null) _yearId = yearId;
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final targetModule =
          (module == null || module.isEmpty) ? moduleZakatFitrah : module;
      final response =
          await _api.getConfigurationsByModule(targetModule, yearId: _yearId);

      final raw = response.data;
      final List<dynamic> list = raw is List
          ? raw
          : (raw as Map<String, dynamic>)['data'] as List<dynamic>? ?? [];

      _rows
        ..clear()
        ..addAll(
          list.map((j) => AppConfiguration.fromJson(j as Map<String, dynamic>)),
        );
      _rows.sort((a, b) {
        final byModule = a.module.compareTo(b.module);
        if (byModule != 0) return byModule;
        return a.code.compareTo(b.code);
      });
      errorMessage = null;
    } catch (e) {
      errorMessage = 'Gagal memuat konfigurasi.';
      debugPrint('ConfigurationProvider.fetchConfigurations error: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createConfiguration(AppConfiguration config) async {
    isSaving = true;
    errorMessage = null;
    notifyListeners();

    try {
      await _api.createConfiguration(
        config.copyWith(module: moduleZakatFitrah).toCreateJson(),
      );
      await fetchConfigurations(module: moduleZakatFitrah);
      return true;
    } catch (e) {
      errorMessage = 'Gagal menambah konfigurasi.';
      debugPrint('ConfigurationProvider.createConfiguration error: $e');
      isSaving = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateConfiguration(AppConfiguration config) async {
    if (config.oid.isEmpty) return false;

    isSaving = true;
    errorMessage = null;
    notifyListeners();

    try {
      await _api.updateConfiguration(
        config.oid,
        config.copyWith(module: moduleZakatFitrah).toUpdateJson(),
      );
      await fetchConfigurations(module: moduleZakatFitrah);
      return true;
    } catch (e) {
      errorMessage = 'Gagal mengubah konfigurasi.';
      debugPrint('ConfigurationProvider.updateConfiguration error: $e');
      isSaving = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteConfiguration(String oid) async {
    if (oid.isEmpty) return false;

    isSaving = true;
    errorMessage = null;
    notifyListeners();

    try {
      await _api.deleteConfiguration(oid);
      await fetchConfigurations(module: moduleZakatFitrah);
      return true;
    } catch (e) {
      errorMessage = 'Gagal menghapus konfigurasi.';
      debugPrint('ConfigurationProvider.deleteConfiguration error: $e');
      isSaving = false;
      notifyListeners();
      return false;
    }
  }

  /// Reset all cached configuration data. Call this on logout or when
  /// switching users so stale data is not shown to the new user.
  void reset() {
    _rows.clear();
    _yearId = '';
    isLoading = false;
    isSaving = false;
    errorMessage = null;
    notifyListeners();
  }
}
