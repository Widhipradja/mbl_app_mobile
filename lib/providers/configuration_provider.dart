import 'package:flutter/foundation.dart';

import '../models/app_configuration.dart';
import '../services/api_service.dart';

class ConfigurationProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  static const String moduleZakatFitrah = 'ZAKATFITRAH';

  final List<AppConfiguration> _configurations = [];
  bool isLoading = false;
  bool isSaving = false;
  String? errorMessage;

  List<AppConfiguration> get configurations =>
      List.unmodifiable(_configurations);

  Future<void> fetchConfigurations({String? module}) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final targetModule =
          (module == null || module.isEmpty) ? moduleZakatFitrah : module;
      final response = await _api.getConfigurationsByModule(targetModule);

      final raw = response.data;
      final List<dynamic> list = raw is List
          ? raw
          : (raw as Map<String, dynamic>)['data'] as List<dynamic>? ?? [];

      _configurations
        ..clear()
        ..addAll(
          list.map((j) => AppConfiguration.fromJson(j as Map<String, dynamic>)),
        );
      _configurations.sort((a, b) {
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
    _configurations.clear();
    isLoading = false;
    isSaving = false;
    errorMessage = null;
    notifyListeners();
  }
}
