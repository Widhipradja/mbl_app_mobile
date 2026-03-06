import 'package:flutter/material.dart';
import '../models/mustahiq_asnaf_summary.dart';
import '../models/muzakki.dart';
import '../models/zakat_external_data.dart';
import '../models/zakat_report_summary.dart';
import '../models/zakat_transaction.dart';
import '../models/zakat_year.dart';
import '../services/api_service.dart';

class ZakatProvider extends ChangeNotifier {
  // ── Years ────────────────────────────────────────────────────────────────
  List<ZakatYear> _years = [];
  ZakatYear? _selectedYear;
  bool isLoadingYears = false;
  String? yearsError;

  List<ZakatYear> get years => List.unmodifiable(_years);
  ZakatYear? get selectedYear => _selectedYear;

  // ── Muzakki ──────────────────────────────────────────────────────────────
  final List<Muzakki> _muzakkiList = [];
  final Map<String, FamilyExternalData> _externalByFamily = {};
  bool isLoading = false;
  String? errorMessage;

  List<Muzakki> get muzakkiList => List.unmodifiable(_muzakkiList);
  Map<String, FamilyExternalData> get externalByFamily =>
      Map.unmodifiable(_externalByFamily);
  FamilyExternalData? getExternalByFamilyId(String familyId) =>
      _externalByFamily[familyId];

  int get totalMuzakki => _muzakkiList.length;
  int get totalJiwa => _muzakkiList.fold(0, (sum, m) => sum + m.numberOfPeople);
  double get totalRiceKg => _muzakkiList.fold(
        0.0,
        (sum, m) =>
            sum + (m.paymentType == PaymentType.beras ? m.amountSo : 0.0),
      );
  double get totalMoneyRp => _muzakkiList.fold(
        0.0,
        (sum, m) =>
            sum + (m.paymentType == PaymentType.uang ? m.amountRp : 0.0),
      );

  // ── Recent Transactions ──────────────────────────────────────────────────
  final List<ZakatTransaction> _recentTransactions = [];
  bool isLoadingRecent = false;
  String? recentError;
  ZakatReportSummary? _reportSummary;
  bool isLoadingReportSummary = false;
  String? reportSummaryError;
  final List<MustahiqAsnafSummary> _mustahiqAsnafSummary = [];
  bool isLoadingMustahiqAsnafSummary = false;
  String? mustahiqAsnafSummaryError;

  List<ZakatTransaction> get recentTransactions =>
      List.unmodifiable(_recentTransactions);
  ZakatReportSummary? get reportSummary => _reportSummary;
  List<MustahiqAsnafSummary> get mustahiqAsnafSummary =>
      List.unmodifiable(_mustahiqAsnafSummary);

  // ── Year operations ──────────────────────────────────────────────────────

  /// Fetch the list of available Zakat Fitrah years.
  Future<void> fetchYears() async {
    isLoadingYears = true;
    yearsError = null;
    notifyListeners();

    try {
      final api = ApiService();
      final response = await api.getZakatYears();
      final List<dynamic> data = response.data as List<dynamic>;
      _years = data
          .map((j) => ZakatYear.fromJson(j as Map<String, dynamic>))
          .toList();

      // Auto-select active year, or first if none active
      _selectedYear ??= _years.firstWhere(
        (y) => y.isActive,
        orElse: () => _years.isNotEmpty ? _years.first : _selectedYear!,
      );

      yearsError = null;
    } catch (e) {
      yearsError = 'Gagal memuat tahun zakat.';
      debugPrint('ZakatProvider.fetchYears error: $e');
    } finally {
      isLoadingYears = false;
      notifyListeners();
    }
  }

  /// Create a new Zakat Fitrah year and refresh the list.
  Future<bool> createYear(Map<String, dynamic> payload) async {
    try {
      final api = ApiService();
      await api.createZakatYear(payload);
      await fetchYears();
      return true;
    } catch (e) {
      debugPrint('ZakatProvider.createYear error: $e');
      return false;
    }
  }

  /// Update an existing Zakat Fitrah year and refresh the list.
  Future<bool> updateYear(String id, Map<String, dynamic> payload) async {
    try {
      final api = ApiService();
      await api.updateZakatYear(id, payload);
      await fetchYears();
      return true;
    } catch (e) {
      debugPrint('ZakatProvider.updateYear error: $e');
      return false;
    }
  }

  /// Change the selected year and re-fetch data.
  Future<void> selectYear(ZakatYear year) async {
    if (_selectedYear?.id == year.id) return;
    _selectedYear = year;
    notifyListeners();
    await Future.wait([
      fetchMuzakki(),
      fetchRecentTransactions(),
      fetchLaporanSummary(),
      fetchMustahiqAsnafSummary(),
    ]);
  }

  /// Fetch Ramadhan recap summary for the selected year.
  Future<void> fetchLaporanSummary() async {
    final yearId = _selectedYear?.id;
    if (yearId == null || yearId.isEmpty) return;

    isLoadingReportSummary = true;
    reportSummaryError = null;
    notifyListeners();

    try {
      final api = ApiService();
      final response = await api.getZakatReportSummary(yearId);
      final raw = response.data;
      final map = raw is Map<String, dynamic> ? raw : <String, dynamic>{};
      final data = map['data'] is Map<String, dynamic>
          ? map['data'] as Map<String, dynamic>
          : map;

      _reportSummary = ZakatReportSummary.fromJson(data);
      reportSummaryError = null;
    } catch (e) {
      _reportSummary = null;
      reportSummaryError = 'Gagal memuat ringkasan laporan.';
      debugPrint('ZakatProvider.fetchLaporanSummary error: $e');
    } finally {
      isLoadingReportSummary = false;
      notifyListeners();
    }
  }

  /// Fetch mustahiq summary by asnaf for the selected year.
  Future<void> fetchMustahiqAsnafSummary() async {
    final yearId = _selectedYear?.id;
    if (yearId == null || yearId.isEmpty) return;

    isLoadingMustahiqAsnafSummary = true;
    mustahiqAsnafSummaryError = null;
    notifyListeners();

    try {
      final api = ApiService();
      final response = await api.getZakatMustahiqSummaryAsnaf(yearId: yearId);
      final raw = response.data;

      final List<dynamic> list = raw is List
          ? raw
          : (raw is Map<String, dynamic>
              ? (raw['data'] as List<dynamic>? ?? const [])
              : const []);

      _mustahiqAsnafSummary
        ..clear()
        ..addAll(
          list
              .whereType<Map<String, dynamic>>()
              .map(MustahiqAsnafSummary.fromJson)
              .where((item) => item.asnafType.isNotEmpty),
        );

      mustahiqAsnafSummaryError = null;
    } catch (e) {
      _mustahiqAsnafSummary.clear();
      mustahiqAsnafSummaryError = 'Gagal memuat rincian asnaf.';
      debugPrint('ZakatProvider.fetchMustahiqAsnafSummary error: $e');
    } finally {
      isLoadingMustahiqAsnafSummary = false;
      notifyListeners();
    }
  }

  /// Fetch the 10 most recent zakat transactions for the selected year.
  Future<void> fetchRecentTransactions() async {
    isLoadingRecent = true;
    recentError = null;
    notifyListeners();

    try {
      final api = ApiService();
      final response = await api.getZakatRecentTransactions(limit: 10);
      final raw = response.data;
      final List<dynamic> list = raw is List
          ? raw
          : (raw as Map<String, dynamic>)['data'] as List<dynamic>? ?? [];
      _recentTransactions
        ..clear()
        ..addAll(list
            .map((j) => ZakatTransaction.fromJson(j as Map<String, dynamic>)));
      recentError = null;
    } catch (e) {
      recentError = 'Gagal memuat transaksi terbaru.';
      debugPrint('ZakatProvider.fetchRecentTransactions error: $e');
    } finally {
      isLoadingRecent = false;
      notifyListeners();
    }
  }

  // ── Muzakki operations ───────────────────────────────────────────────────

  /// Total count from the server (for pagination awareness).
  int totalMuzakkiServer = 0;

  /// Fetch muzakki with payment status for the currently selected year.
  Future<void> fetchMuzakki() async {
    final yearId = _selectedYear?.id;
    if (yearId == null || yearId.isEmpty) {
      debugPrint('ZakatProvider.fetchMuzakki: no year selected, skipping.');
      return;
    }

    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final api = ApiService();
      final response = await api.getZakatMuzakkiStatus(yearId);

      // Response is a paginated wrapper: { data: [...], limit, offset, total }
      final Map<String, dynamic> body = response.data as Map<String, dynamic>;
      final List<dynamic> rawList = body['data'] as List<dynamic>? ?? [];
      final List<dynamic> externalRawList =
          body['external_data'] as List<dynamic>? ?? [];
      totalMuzakkiServer = body['total'] as int? ?? rawList.length;

      _muzakkiList
        ..clear()
        ..addAll(
            rawList.map((j) => Muzakki.fromJson(j as Map<String, dynamic>)));

      _externalByFamily
        ..clear()
        ..addEntries(
          externalRawList
              .map(
                  (j) => FamilyExternalData.fromJson(j as Map<String, dynamic>))
              .map((ext) => MapEntry(ext.familyId, ext)),
        );
      errorMessage = null;
    } catch (e) {
      errorMessage =
          'Gagal memuat data muzakki. Tarik ke bawah untuk coba lagi.';
      debugPrint('ZakatProvider.fetchMuzakki error: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void addMuzakki(Muzakki muzakki) {
    _muzakkiList.insert(0, muzakki);
    notifyListeners();
  }

  Future<void> deleteMuzakki(String id) async {
    // Optimistic removal
    final index = _muzakkiList.indexWhere((m) => m.id == id);
    Muzakki? removed;
    if (index != -1) {
      removed = _muzakkiList.removeAt(index);
      notifyListeners();
    }
    try {
      final api = ApiService();
      await api.deleteMuzakki(id);
    } catch (e) {
      // Rollback on failure
      if (removed != null) {
        _muzakkiList.insert(index, removed);
      }
      errorMessage = 'Gagal menghapus muzakki.';
      notifyListeners();
      debugPrint('ZakatProvider.deleteMuzakki error: $e');
    }
  }

  void updateMuzakki(Muzakki updated) {
    final index = _muzakkiList.indexWhere((m) => m.id == updated.id);
    if (index != -1) {
      _muzakkiList[index] = updated;
      notifyListeners();
    }
  }

  /// Set [id] as the new head of their family.
  /// Calls `PATCH /api/zakat-fitrah/muzakki/{id}/family-head`, then re-fetches.
  Future<void> setFamilyHead(String id) async {
    try {
      final api = ApiService();
      await api.setFamilyHead(id);
      await fetchMuzakki(); // refresh so is_head_of_family is updated
    } catch (e) {
      errorMessage = 'Gagal mengubah kepala keluarga.';
      notifyListeners();
      debugPrint('ZakatProvider.setFamilyHead error: $e');
    }
  }

  /// Reset all cached zakat data. Call this on logout or when switching users
  /// so stale data from a previous group_name is not shown to the new user.
  void reset() {
    _years = [];
    _selectedYear = null;
    isLoadingYears = false;
    yearsError = null;

    _muzakkiList.clear();
    _externalByFamily.clear();
    isLoading = false;
    errorMessage = null;
    totalMuzakkiServer = 0;

    _recentTransactions.clear();
    isLoadingRecent = false;
    recentError = null;

    _reportSummary = null;
    isLoadingReportSummary = false;
    reportSummaryError = null;

    _mustahiqAsnafSummary.clear();
    isLoadingMustahiqAsnafSummary = false;
    mustahiqAsnafSummaryError = null;

    notifyListeners();
  }
}
