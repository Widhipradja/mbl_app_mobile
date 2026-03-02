import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../models/attendance_trend.dart';
import '../../services/api_service.dart';

class AttendanceTrendScreen extends StatefulWidget {
  const AttendanceTrendScreen({super.key});

  @override
  State<AttendanceTrendScreen> createState() => _AttendanceTrendScreenState();
}

class _AttendanceTrendScreenState extends State<AttendanceTrendScreen> {
  final ApiService _apiService = ApiService();
  List<AttendanceTrend> _data = [];
  bool _isLoading = true;
  String? _error;
  int _touchedIndex = -1;

  @override
  void initState() {
    super.initState();
    _loadTrend();
  }

  Future<void> _loadTrend() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final res = await _apiService.getAttendanceTrend();
      if (res.statusCode == 200) {
        final List<dynamic> raw = res.data is List
            ? res.data
            : (res.data['data'] ?? res.data['trends'] ?? []);
        setState(() {
          _data = raw
              .map((e) => AttendanceTrend.fromJson(e as Map<String, dynamic>))
              .toList();
          _data.sort((a, b) {
            if (a.year != b.year) return a.year.compareTo(b.year);
            final monthOrder = ['January','February','March','April','May',
              'June','July','August','September','October','November','December'];
            final monthCompare = monthOrder.indexOf(a.month)
                .compareTo(monthOrder.indexOf(b.month));
            if (monthCompare != 0) return monthCompare;
            return a.day.compareTo(b.day);
          });
          _isLoading = false;
        });
      } else {
        throw Exception('Status ${res.statusCode}');
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  // Group data by month label
  Map<String, List<AttendanceTrend>> get _byMonth {
    final result = <String, List<AttendanceTrend>>{};
    for (final d in _data) {
      final key = '${d.month} ${d.year}';
      result.putIfAbsent(key, () => []).add(d);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tren Kehadiran'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTrend,
            tooltip: 'Muat ulang',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 56, color: Colors.red),
                  const SizedBox(height: 12),
                  Text('Gagal memuat data', style: TextStyle(color: Colors.grey[600])),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _loadTrend,
                    child: const Text('Coba Lagi'),
                  ),
                ],
              ),
            )
          : _data.isEmpty
          ? Center(
              child: Text(
                'Tidak ada data tren',
                style: TextStyle(color: Colors.grey[600], fontSize: 16),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadTrend,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Monthly summary cards
                  ..._byMonth.entries.map((entry) =>
                      _buildMonthSummaryCard(entry.key, entry.value)),
                  const SizedBox(height: 8),
                  // Line chart card
                  _buildLineChartCard(),
                  const SizedBox(height: 8),
                  // Bar chart card
                  _buildBarChartCard(),
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }

  Widget _buildMonthSummaryCard(String monthLabel, List<AttendanceTrend> items) {
    final totalAttended = items.fold(0, (s, e) => s + e.totalAttended);
    final totalExpected = items.fold(0, (s, e) => s + e.totalExpected);
    final totalEvents = items.fold(0, (s, e) => s + e.totalEvents);
    final totalRemarks = items.fold(0, (s, e) => s + e.totalRemarks);
    final avgRate = items.isEmpty
        ? 0.0
        : items.fold(0.0, (s, e) => s + e.attendanceRate) / items.length;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_month, color: Colors.indigo.shade600),
                const SizedBox(width: 8),
                Text(
                  monthLabel,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildStatChip('Event', '$totalEvents', Colors.indigo),
                const SizedBox(width: 8),
                // _buildStatChip('Hadir', '$totalAttended', Colors.green),
                // const SizedBox(width: 8),
                // _buildStatChip('Undangan', '$totalExpected', Colors.blue),
                // const SizedBox(width: 8),
                // _buildStatChip('Izin', '$totalRemarks', Colors.orange),
                // const SizedBox(width: 8),
                _buildStatChip(
                  'Rata-rata',
                  '${avgRate.toStringAsFixed(1)}%',
                  _rateColor(avgRate),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLineChartCard() {
    final spots = _data.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.attendanceRate);
    }).toList();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tingkat Kehadiran Harian (%)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: 100,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 25,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: Colors.grey.shade200,
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 25,
                        reservedSize: 36,
                        getTitlesWidget: (value, _) => Text(
                          '${value.toInt()}%',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: (_data.length / 4).ceilToDouble().clamp(1, double.infinity),
                        getTitlesWidget: (value, _) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= _data.length) return const SizedBox();
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              _data[idx].label,
                              style: TextStyle(fontSize: 9, color: Colors.grey[600]),
                            ),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: Colors.indigo.shade500,
                      barWidth: 2.5,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, _, __, ___) =>
                            FlDotCirclePainter(
                              radius: 3,
                              color: Colors.indigo.shade500,
                              strokeWidth: 0,
                            ),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.indigo.shade200.withOpacity(0.4),
                            Colors.indigo.shade50.withOpacity(0.0),
                          ],
                        ),
                      ),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (spots) => spots.map((s) {
                        final idx = s.x.toInt();
                        if (idx < 0 || idx >= _data.length) return null;
                        final d = _data[idx];
                        return LineTooltipItem(
                          '${d.label}\n${d.attendanceRate.toStringAsFixed(1)}%\n${d.totalAttended}/${d.totalExpected} hadir\n${d.totalRemarks} izin',
                          const TextStyle(color: Colors.white, fontSize: 11),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarChartCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Hadir vs Undangan per Hari',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildLegendDot(Colors.green.shade400, 'Hadir'),
                const SizedBox(width: 12),
                _buildLegendDot(Colors.blue.shade200, 'Undangan'),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  barTouchData: BarTouchData(
                    touchCallback: (event, response) {
                      setState(() {
                        if (response?.spot != null &&
                            event is! FlTapUpEvent &&
                            event is! FlPanEndEvent) {
                          _touchedIndex = response!.spot!.touchedBarGroupIndex;
                        } else {
                          _touchedIndex = -1;
                        }
                      });
                    },
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, _, rod, rodIndex) {
                        final d = _data[group.x];
                        if (rodIndex == 0) {
                          return BarTooltipItem(
                            '${d.label}\nHadir: ${d.totalAttended}\nUndangan: ${d.totalExpected}\nIzin: ${d.totalRemarks}',
                            const TextStyle(color: Colors.white, fontSize: 11),
                          );
                        }
                        return null;
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: (_data.length / 4).ceilToDouble().clamp(1, double.infinity),
                        getTitlesWidget: (value, _) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= _data.length) return const SizedBox();
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              _data[idx].label,
                              style: TextStyle(fontSize: 9, color: Colors.grey[600]),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        getTitlesWidget: (value, _) => Text(
                          value.toInt().toString(),
                          style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                        ),
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: Colors.grey.shade200,
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: _data.asMap().entries.map((e) {
                    final isTouched = e.key == _touchedIndex;
                    return BarChartGroupData(
                      x: e.key,
                      barRods: [
                        BarChartRodData(
                          toY: e.value.totalExpected.toDouble(),
                          color: Colors.blue.shade200,
                          width: isTouched ? 12 : 8,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                        ),
                        BarChartRodData(
                          toY: e.value.totalAttended.toDouble(),
                          color: Colors.green.shade400,
                          width: isTouched ? 12 : 8,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
      ],
    );
  }

  Color _rateColor(double rate) {
    if (rate >= 75) return Colors.green;
    if (rate >= 50) return Colors.orange;
    return Colors.red;
  }
}
