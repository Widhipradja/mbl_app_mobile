import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/event.dart';
import '../../providers/event_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/event_card.dart';
import 'create_event_dialog.dart';

class AttendanceHomeScreen extends StatefulWidget {
  const AttendanceHomeScreen({super.key});

  @override
  State<AttendanceHomeScreen> createState() => _AttendanceHomeScreenState();
}

class _AttendanceHomeScreenState extends State<AttendanceHomeScreen>
    with SingleTickerProviderStateMixin {
  int _selectedTab = 0; // 0: Tambah, 1: Ongoing, 2: Completed
  List<Event> _completedEvents = [];
  bool _isLoadingCompleted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchCurrentMonthEvents();
    });
  }

  Future<void> _fetchCurrentMonthEvents() async {
    final now = DateTime.now();
    try {
      // Fetch ongoing events for current month
      final ongoingResponse = await ApiService().getLatestEvents(
        year: now.year,
        month: now.month,
      );
      if (ongoingResponse.statusCode == 200 && mounted) {
        final List<dynamic> data = ongoingResponse.data is List
            ? ongoingResponse.data
            : (ongoingResponse.data['events'] ?? []);
        context.read<EventProvider>().setEvents(
              data.map((json) => Event.fromJson(json)).toList(),
            );
      }
    } catch (e) {
      debugPrint('Error fetching ongoing events: $e');
    }

    // Fetch completed events for current month
    _fetchCompletedEvents();
  }

  Future<void> _fetchCompletedEvents() async {
    setState(() {
      _isLoadingCompleted = true;
    });

    try {
      final now = DateTime.now();
      final response = await ApiService().getCompletedEvents(
        year: now.year,
        month: now.month,
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data is List
            ? response.data
            : (response.data['events'] ?? []);
        setState(() {
          _completedEvents = data.map((json) => Event.fromJson(json)).toList()
            ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
        });
      }
    } catch (e) {
      debugPrint('Error fetching completed events: $e');
    } finally {
      setState(() {
        _isLoadingCompleted = false;
      });
    }
  }

  void _showCreateEventDialog() {
    showCreateEventDialog(context);
  }

  void _deleteEvent(String id) async {
    final success = await context.read<EventProvider>().deleteEvent(id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Event deleted' : 'Failed to delete event'),
        ),
      );
    }
  }

  Widget _buildEventsList({
    required List<Event> events,
    required bool isLoading,
    required String emptyMessage,
    required bool showCreateButton,
  }) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Events List Header
          if (events.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Daftar Event Bulan Ini',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${events.length} event',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Events List
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : events.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.event_busy,
                                size: 60,
                                color: Colors.grey[400],
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              emptyMessage,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Event akan muncul di sini',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: events.length,
                        itemBuilder: (context, index) {
                          final event = events[index];
                          return EventCard(
                            event: event,
                            onDelete: () => _deleteEvent(event.id!),
                            onTap: () {
                              context.push(
                                '/attendance/event-detail',
                                extra: event,
                              );
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, int index) {
    final isActive = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isActive ? Colors.indigo.shade600 : Colors.white,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Buat Event Baru',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tambahkan event untuk melacak kehadiran',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _showCreateEventDialog,
              icon: const Icon(Icons.add),
              label: const Text('Create New Event'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
            ),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Tips Membuat Event',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildTipItem('Pilih nama event yang sesuai'),
                _buildTipItem('Tentukan lokasi dengan jelas'),
                _buildTipItem('Tambahkan catatan jika diperlukan'),
                _buildTipItem('Pilih tanggal yang tepat'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle, size: 16, color: Colors.blue.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 14, color: Colors.blue.shade900),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOngoingTab(EventProvider eventProvider) {
    final events = eventProvider.events
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

    return _buildEventsList(
      events: events,
      isLoading: eventProvider.isLoading,
      emptyMessage: 'Tidak ada event yang sedang berlangsung',
      showCreateButton: false,
    );
  }

  Widget _buildCompletedTab() {
    return _buildEventsList(
      events: _completedEvents,
      isLoading: _isLoadingCompleted,
      emptyMessage: 'Tidak ada event yang selesai',
      showCreateButton: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final eventProvider = context.watch<EventProvider>();
    final events = eventProvider.events;
    final totalEvents = events.length + _completedEvents.length;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.blue.shade50, Colors.indigo.shade50],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header with gradient
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [Colors.indigo.shade600, Colors.purple.shade600],
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(24),
                    bottomRight: Radius.circular(24),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.indigo.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title Row
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.event_available,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Kehadiran',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Kelola kehadiran event',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.home, color: Colors.white),
                            tooltip: 'Dashboard',
                            onPressed: () => context.go('/dashboard'),
                          ),
                          IconButton(
                            icon: const Icon(Icons.bar_chart,
                                color: Colors.white),
                            tooltip: 'Tren Kehadiran',
                            onPressed: () => context.push('/attendance/trend'),
                          ),
                          IconButton(
                            icon: const Icon(Icons.search, color: Colors.white),
                            tooltip: 'Cari Event',
                            onPressed: () =>
                                context.push('/attendance/inquiry'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Stats Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildHeaderStat(
                                'Total',
                                totalEvents.toString(),
                                Icons.event,
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 40,
                              color: Colors.white.withOpacity(0.3),
                            ),
                            Expanded(
                              child: _buildHeaderStat(
                                'Ongoing',
                                events.length.toString(),
                                Icons.schedule,
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 40,
                              color: Colors.white.withOpacity(0.3),
                            ),
                            Expanded(
                              child: _buildHeaderStat(
                                'Completed',
                                _completedEvents.length.toString(),
                                Icons.check_circle,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Tab Navigation
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            _buildTabButton('Tambah', 0),
                            const SizedBox(width: 4),
                            _buildTabButton('Ongoing', 1),
                            const SizedBox(width: 4),
                            _buildTabButton('Completed', 2),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Tab Content
              Expanded(
                child: _selectedTab == 0
                    ? _buildAddTab()
                    : _selectedTab == 1
                        ? _buildOngoingTab(eventProvider)
                        : _buildCompletedTab(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12),
        ),
      ],
    );
  }
}

class ContactsHomeScreen extends StatelessWidget {
  const ContactsHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Redirect to AttendanceHomeScreen
    return const AttendanceHomeScreen();
  }
}
