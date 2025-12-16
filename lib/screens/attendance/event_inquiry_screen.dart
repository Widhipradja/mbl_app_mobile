import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../models/event.dart';
import '../../services/api_service.dart';
import '../../widgets/event_card.dart';

class EventInquiryScreen extends StatefulWidget {
  const EventInquiryScreen({super.key});

  @override
  State<EventInquiryScreen> createState() => _EventInquiryScreenState();
}

class _EventInquiryScreenState extends State<EventInquiryScreen> {
  final ApiService _apiService = ApiService();
  List<Event> _ongoingEvents = [];
  List<Event> _completedEvents = [];
  bool _isLoading = false;

  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;

  final List<String> _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  @override
  void initState() {
    super.initState();
    _fetchEvents();
  }

  Future<void> _fetchEvents() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Fetch all events for the selected year/month
      final response = await _apiService.getEventsByYearMonth(
        year: _selectedYear,
        month: _selectedMonth,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data is List
            ? response.data
            : (response.data['events'] ?? []);

        final allEvents = data.map((json) => Event.fromJson(json)).toList();

        // Separate ongoing and completed events
        _ongoingEvents =
            allEvents.where((event) => event.status != 'Completed').toList()
              ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

        _completedEvents =
            allEvents.where((event) => event.status == 'Completed').toList()
              ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching events: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<int> _generateYears() {
    final currentYear = DateTime.now().year;
    return List.generate(10, (index) => currentYear - index);
  }

  @override
  Widget build(BuildContext context) {
    final allEvents = [..._ongoingEvents, ..._completedEvents]
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Event Inquiry'),
      ),
      body: Column(
        children: [
          // Filter Section
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Year Dropdown
                DropdownButtonFormField<int>(
                  value: _selectedYear,
                  decoration: const InputDecoration(
                    labelText: 'Year',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  isExpanded: true,
                  items: _generateYears().map((year) {
                    return DropdownMenuItem<int>(
                      value: year,
                      child: Text(year.toString()),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedYear = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                // Month Dropdown
                DropdownButtonFormField<int>(
                  value: _selectedMonth,
                  decoration: const InputDecoration(
                    labelText: 'Month',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  isExpanded: true,
                  items: List.generate(12, (index) {
                    return DropdownMenuItem<int>(
                      value: index + 1,
                      child: Text(_months[index]),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedMonth = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                // Search Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _fetchEvents,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.search),
                    label: const Text('Search Events'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Results Section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(
                  'Results for ${_months[_selectedMonth - 1]} $_selectedYear',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '${allEvents.length} events',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
          ),

          // Events List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : allEvents.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.event_busy,
                          size: 80,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No events found',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Try selecting a different month or year',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: allEvents.length,
                    itemBuilder: (context, index) {
                      final event = allEvents[index];
                      return EventCard(
                        event: event,
                        onDelete: null, // Disable delete in inquiry screen
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
}
