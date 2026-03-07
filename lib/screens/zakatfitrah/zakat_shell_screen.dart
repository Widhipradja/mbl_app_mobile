import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/zakat_year.dart';
import '../../providers/zakat_provider.dart';
import 'zakat_dashboard_screen.dart';
import 'muzakki_list_screen.dart';
import 'laporan_screen.dart';
import 'mustahiq_screen.dart';
import 'configuration_screen.dart';

/// Shell / scaffold that hosts the three bottom-navigation tabs for the
/// Zakat Fitrah module:  Beranda ▸ Muzakki ▸ Laporan
///
/// This shell owns the single Scaffold, AppBar (with year selector), and
/// BottomNavigationBar. Each tab widget is a body-only widget (no Scaffold).
class ZakatShellScreen extends StatefulWidget {
  final int initialTab;
  const ZakatShellScreen({super.key, this.initialTab = 0});

  @override
  State<ZakatShellScreen> createState() => _ZakatShellScreenState();
}

class _ZakatShellScreenState extends State<ZakatShellScreen> {
  static const _green = Color(0xFF066046);

  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTab;
    // Fetch years first, then muzakki
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<ZakatProvider>();
      if (provider.years.isEmpty) {
        await provider.fetchYears();
      }
      if (provider.muzakkiList.isEmpty && !provider.isLoading) {
        await provider.fetchMuzakki();
      }
    });
  }

  static const List<String> _tabTitles = [
    'Beranda',
    'Muzakki',
    'Mustahiq',
    'Laporan',
    'Configuration',
  ];

  @override
  Widget build(BuildContext context) {
    return Consumer<ZakatProvider>(
      builder: (context, provider, _) {
        final yearLabel = provider.selectedYear?.label ?? 'Zakat Fitrah';

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) context.go('/dashboard');
          },
          child: Scaffold(
          backgroundColor: const Color(0xFFF4F7F6),
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
              onPressed: () => context.go('/dashboard'),
              tooltip: 'Kembali',
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _tabTitles[_currentIndex],
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                    fontSize: 17,
                  ),
                ),
                Text(
                  yearLabel,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
            actions: [
              // Year selector button
              _YearSelector(
                years: provider.years,
                selectedYear: provider.selectedYear,
                isLoading: provider.isLoadingYears,
                onYearSelected: (year) => provider.selectYear(year),
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: IndexedStack(
            index: _currentIndex,
            children: const [
              ZakatBerandaBody(),
              MuzakkiListBody(),
              MustahiqBody(),
              LaporanBody(),
              ConfigurationBody(),
            ],
          ),
          floatingActionButton: _currentIndex == 1
              ? FloatingActionButton.extended(
                  onPressed: () => context.go('/zakat-fitrah/add'),
                  backgroundColor: _green,
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.person_add_alt_1_outlined),
                  label: const Text(
                    'Tambah',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  elevation: 4,
                )
              : null,
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            selectedItemColor: _green,
            unselectedItemColor: const Color(0xFF94A3B8),
            backgroundColor: Colors.white,
            type: BottomNavigationBarType.fixed,
            selectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
            unselectedLabelStyle: const TextStyle(fontSize: 11),
            elevation: 12,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home),
                label: 'Beranda',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.people_outline),
                activeIcon: Icon(Icons.people),
                label: 'Muzakki',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.diversity_3_outlined),
                activeIcon: Icon(Icons.diversity_3),
                label: 'Mustahiq',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.bar_chart_outlined),
                activeIcon: Icon(Icons.bar_chart),
                label: 'Laporan',
              ),
              
              BottomNavigationBarItem(
                icon: Icon(Icons.settings_outlined),
                activeIcon: Icon(Icons.settings),
                label: 'Config',
              ),
            ],
          ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// Year Selector Widget (AppBar action)
// ─────────────────────────────────────────────
class _YearSelector extends StatelessWidget {
  const _YearSelector({
    required this.years,
    required this.selectedYear,
    required this.isLoading,
    required this.onYearSelected,
  });

  final List<ZakatYear> years;
  final ZakatYear? selectedYear;
  final bool isLoading;
  final ValueChanged<ZakatYear> onYearSelected;

  static const _green = Color(0xFF066046);

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation(_green),
          ),
        ),
      );
    }

    if (years.isEmpty) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: () => _showYearPicker(context),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5F0),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFB2DFDB)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_today_outlined, size: 13, color: _green),
            const SizedBox(width: 5),
            Text(
              selectedYear != null
                  ? '${selectedYear!.hijriYear}H'
                  : 'Pilih Tahun',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _green,
              ),
            ),
            const SizedBox(width: 3),
            const Icon(Icons.arrow_drop_down, size: 16, color: _green),
          ],
        ),
      ),
    );
  }

  void _showYearPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _YearPickerSheet(
        years: years,
        selectedYear: selectedYear,
        onSelected: (year) {
          Navigator.pop(ctx);
          onYearSelected(year);
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Year Picker Bottom Sheet
// ─────────────────────────────────────────────
class _YearPickerSheet extends StatelessWidget {
  const _YearPickerSheet({
    required this.years,
    required this.selectedYear,
    required this.onSelected,
  });

  final List<ZakatYear> years;
  final ZakatYear? selectedYear;
  final ValueChanged<ZakatYear> onSelected;

  static const _green = Color(0xFF066046);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Text(
            'Pilih Tahun Zakat Fitrah',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 16),
          ...years.map((year) {
            final isSelected = selectedYear?.id == year.id;
            return GestureDetector(
              onTap: () => onSelected(year),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(bottom: 10),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFFE8F5F0)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? _green : const Color(0xFFE2E8F0),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isSelected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color: isSelected ? _green : const Color(0xFFCBD5E1),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            year.label,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color:
                                  isSelected ? _green : const Color(0xFF1A1A1A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Rp ${_formatRp(year.riceRatePerSo)} / sha\'',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (year.isActive)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _green,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Aktif',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  String _formatRp(double amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)} jt';
    }
    if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(0)} rb';
    }
    return amount.toStringAsFixed(0);
  }
}
