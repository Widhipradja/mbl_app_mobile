import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class MemberStatisticsCategoryScreen extends StatefulWidget {
  final String category;
  final int year;
  final String sex;
  final String familyId;
  const MemberStatisticsCategoryScreen({
    super.key,
    required this.category,
    required this.year,
    required this.sex,
    required this.familyId,
  });

  @override
  State<MemberStatisticsCategoryScreen> createState() =>
      _MemberStatisticsCategoryScreenState();
}

class _MemberStatisticsCategoryScreenState
    extends State<MemberStatisticsCategoryScreen> {
  String _filter = '';
  final List<String> _monthNames = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  String getMonthName(int month) {
    if (month < 1 || month > 12) return '';
    return _monthNames[month - 1];
  }

  void _showClickedText(String text) {
    if (text.isEmpty) return;
    // record log
    final log = {
      'text': text,
      'timestamp': DateTime.now().toIso8601String(),
      'category': widget.category,
      'year': _selectedYear,
      'month': _selectedMonth,
    };
    _clickLogs.insert(0, log);
    if (_clickLogs.length > 200) _clickLogs.removeLast();
    debugPrint('ClickLog: $log');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), duration: const Duration(seconds: 2)),
    );
  }

  // simple in-memory click log
  final List<Map<String, dynamic>> _clickLogs = [];

  void _showLogs() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.5,
          minChildSize: 0.25,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Click Logs',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _clickLogs.clear();
                          });
                          Navigator.of(context).pop();
                        },
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _clickLogs.isEmpty
                        ? const Center(child: Text('No logs'))
                        : ListView.builder(
                            controller: scrollController,
                            itemCount: _clickLogs.length,
                            itemBuilder: (context, idx) {
                              final log = _clickLogs[idx];
                              return ListTile(
                                dense: true,
                                title: Text(log['text'] ?? ''),
                                subtitle: Text(
                                  '${log['timestamp']} • ${log['category']} ${log['year']}/${log['month']}',
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  final ApiService _apiService = ApiService();
  late int _selectedYear;
  late int _selectedMonth;
  late List<int> _yearOptions;
  bool _isLoading = true;
  String? _error;
  List<dynamic> _data = [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedYear = now.year;
    _selectedMonth = now.month;
    _yearOptions = List.generate(6, (i) => now.year - 5 + i); // last 6 years
    _fetchStatistics();
  }

  Future<void> _fetchStatistics() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await _apiService.getMemberStatisticsByCategory(
        category: widget.category,
        year: _selectedYear,
        month: _selectedMonth,
        sex: widget.sex,
        familyId: widget.familyId,
      );
      if (response.statusCode == 200) {
        setState(() {
          _data = response.data is List ? response.data : [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to load data';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Statistik ${widget.category} - ${getMonthName(_selectedMonth)} $_selectedYear',
        ),
        actions: [
          IconButton(
            tooltip: 'Lihat Log Klik',
            icon: const Icon(Icons.history),
            onPressed: _showLogs,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Month & Year selectors
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _selectedMonth,
                    decoration: const InputDecoration(labelText: 'Bulan'),
                    items: List.generate(12, (i) => i + 1)
                        .map(
                          (m) => DropdownMenuItem<int>(
                            value: m,
                            child: Text(getMonthName(m)),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() {
                        _selectedMonth = v;
                      });
                      _showClickedText(getMonthName(v));
                      _fetchStatistics();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 140,
                  child: DropdownButtonFormField<int>(
                    value: _selectedYear,
                    decoration: const InputDecoration(labelText: 'Tahun'),
                    items: _yearOptions
                        .map(
                          (y) => DropdownMenuItem<int>(
                            value: y,
                            child: Text(y.toString()),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() {
                        _selectedYear = v;
                      });
                      _showClickedText(v.toString());
                      _fetchStatistics();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Name filter
            TextField(
              decoration: const InputDecoration(
                labelText: 'Filter member name',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _filter = value;
                });
              },
            ),
            const SizedBox(height: 16),

            // Chart / message area
            Expanded(
              child: Builder(
                builder: (context) {
                  if (_isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (_error != null) {
                    return Center(child: Text(_error!));
                  }
                  if (_data.isEmpty) {
                    return const Center(child: Text('No data available'));
                  }
                  return _buildChart();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChart() {
    // Group data by member and count attendance, not attended, permission (remark)
    final Map<String, String> memberNames = {};
    final Map<String, int> attended = {};
    final Map<String, int> notAttended = {};
    final Map<String, int> permission = {};
    final Set<String> eventIds = {};
    final Map<String, String> memberGenders = {};
    for (var item in _data) {
      final String memberId = item['member_id'] ?? '';
      final String name =
          ((item['first_name'] ?? '') + ' ' + (item['last_name'] ?? '')).trim();
      final bool isAttending = item['is_attending'] == true;
      final String eventId = item['event_id']?.toString() ?? '';
      final String remark = (item['remark'] ?? '').toString().trim();
      final String gender = (item['sex'] ?? '').toString().toLowerCase();
      if (!memberNames.containsKey(memberId)) {
        memberNames[memberId] = name;
        attended[memberId] = 0;
        notAttended[memberId] = 0;
        permission[memberId] = 0;
        memberGenders[memberId] = gender;
      }
      if (eventId.isNotEmpty) eventIds.add(eventId);
      if (isAttending) {
        attended[memberId] = attended[memberId]! + 1;
      } else {
        notAttended[memberId] = notAttended[memberId]! + 1;
        if (remark.isNotEmpty) {
          permission[memberId] = permission[memberId]! + 1;
        }
      }
    }
    final members =
        memberNames.keys
            .where(
              (id) =>
                  _filter.isEmpty ||
                  (memberNames[id]?.toLowerCase().contains(
                        _filter.toLowerCase(),
                      ) ??
                      false),
            )
            .toList()
          ..sort(
            (a, b) => (memberNames[a] ?? '').toLowerCase().compareTo(
              (memberNames[b] ?? '').toLowerCase(),
            ),
          );
    final totalEvents = eventIds.length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double screenWidth = constraints.maxWidth;
        return Padding(
          padding: const EdgeInsets.only(bottom: 32.0),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: screenWidth),
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: DataTable(
                        columns: [
                          DataColumn(
                            label: Flexible(
                              child: InkWell(
                                onTap: () => _showClickedText('Nama'),
                                child: const Text(
                                  'Nama',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ),
                          DataColumn(
                            label: Flexible(
                              child: InkWell(
                                onTap: () => _showClickedText('Kehadiran'),
                                child: const Text(
                                  'Kehadiran',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ),
                          DataColumn(
                            label: Flexible(
                              child: InkWell(
                                onTap: () => _showClickedText('%'),
                                child: const Text(
                                  '%',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ),
                        ],
                        rows: [
                          for (final memberId in members)
                            DataRow(
                              color: WidgetStateProperty.resolveWith<Color?>((
                                states,
                              ) {
                                final gender = memberGenders[memberId] ?? '';
                                if (gender == 'm') {
                                  return Colors.blue.withOpacity(0.08);
                                } else if (gender == 'f') {
                                  return Colors.pink.withOpacity(0.08);
                                }
                                return null;
                              }),
                              cells: [
                                DataCell(
                                  Text(memberNames[memberId] ?? ''),
                                  onTap: () => _showClickedText(
                                    memberNames[memberId] ?? '',
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    '${attended[memberId] ?? 0}/$totalEvents',
                                  ),
                                  onTap: () => _showClickedText(
                                    '${attended[memberId] ?? 0}/$totalEvents',
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    totalEvents > 0
                                        ? '${((attended[memberId]! / totalEvents) * 100).toStringAsFixed(1)}%'
                                        : '0%',
                                  ),
                                  onTap: () => _showClickedText(
                                    totalEvents > 0
                                        ? '${((attended[memberId]! / totalEvents) * 100).toStringAsFixed(1)}%'
                                        : '0%',
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 48), // Extra space at the bottom
                ],
              ),
            ),
          ),
        );
      },
    );

    // Removed the old month names list and replaced it with the new _monthNames list
    // and the getMonthName method above.
  }
}
