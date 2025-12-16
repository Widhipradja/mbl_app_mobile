import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/event.dart';
import '../../providers/event_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/event_card.dart';

class AttendanceHomeScreen extends StatefulWidget {
  const AttendanceHomeScreen({super.key});

  @override
  State<AttendanceHomeScreen> createState() => _AttendanceHomeScreenState();
}

class _AttendanceHomeScreenState extends State<AttendanceHomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Event> _completedEvents = [];
  bool _isLoadingCompleted = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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

  void _showCreateEventDialog() async {
    final formKey = GlobalKey<FormState>();
    final remarkController = TextEditingController();
    DateTime selectedDate = DateTime.now();

    // Fetch event types and locations
    List<Map<String, dynamic>> eventTypes = [];
    List<Map<String, dynamic>> eventLocations = [];
    List<Map<String, dynamic>> eventCategories = [];
    String? selectedEventName = 'Pengajian Kelompok';
    String? selectedLocation = 'MBL';
    String? selectedCategory = 'Umum';
    bool isLoadingEventTypes = true;
    bool isLoadingLocations = true;
    bool isLoadingCategories = true;

    try {
      final eventResponse = await ApiService().getLookups('EVENT');
      if (eventResponse.statusCode == 200) {
        eventTypes = List<Map<String, dynamic>>.from(eventResponse.data);
      }
    } catch (e) {
      debugPrint('Error loading event types: $e');
    }
    isLoadingEventTypes = false;

    try {
      final locationResponse = await ApiService().getLookups('EVENT_LOC');
      if (locationResponse.statusCode == 200) {
        eventLocations = List<Map<String, dynamic>>.from(locationResponse.data);
      }
    } catch (e) {
      debugPrint('Error loading event locations: $e');
    }
    isLoadingLocations = false;

    try {
      final categoryResponse = await ApiService().getLookups('EVENT_CATEGORY');
      if (categoryResponse.statusCode == 200) {
        eventCategories = List<Map<String, dynamic>>.from(
          categoryResponse.data,
        );
      }
    } catch (e) {
      debugPrint('Error loading event categories: $e');
    }
    isLoadingCategories = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create New Event'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Event Name Dropdown
                  isLoadingEventTypes
                      ? const Center(child: CircularProgressIndicator())
                      : DropdownButtonFormField<String>(
                          initialValue: selectedEventName,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Event Name',
                            border: OutlineInputBorder(),
                          ),
                          hint: const Text('Select event type'),
                          items: eventTypes.map((eventType) {
                            return DropdownMenuItem<String>(
                              value: eventType['value'],
                              child: Text(eventType['value']),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setDialogState(() {
                              selectedEventName = value;
                            });
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please select an event type';
                            }
                            return null;
                          },
                        ),
                  const SizedBox(height: 16),
                  // Location Dropdown
                  isLoadingLocations
                      ? const Center(child: CircularProgressIndicator())
                      : DropdownButtonFormField<String>(
                          initialValue: selectedLocation,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Location',
                            border: OutlineInputBorder(),
                          ),
                          hint: const Text('Select event location'),
                          items: eventLocations.map((location) {
                            return DropdownMenuItem<String>(
                              value: location['value'],
                              child: Text(location['value']),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setDialogState(() {
                              selectedLocation = value;
                            });
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please select a location';
                            }
                            return null;
                          },
                        ),
                  const SizedBox(height: 16),
                  // Category Dropdown
                  isLoadingCategories
                      ? const Center(child: CircularProgressIndicator())
                      : DropdownButtonFormField<String>(
                          initialValue: selectedCategory,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Category',
                            border: OutlineInputBorder(),
                          ),
                          hint: const Text('Select event category'),
                          items: eventCategories.map((category) {
                            return DropdownMenuItem<String>(
                              value: category['value'],
                              child: Text(category['value']),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setDialogState(() {
                              selectedCategory = value;
                            });
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please select a category';
                            }
                            return null;
                          },
                        ),
                  const SizedBox(height: 16),
                  // Date Picker
                  InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date != null) {
                        setDialogState(() {
                          selectedDate = date;
                        });
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Event Date',
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.calendar_today),
                      ),
                      child: Text(
                        DateFormat('EEEE, MMM dd, yyyy').format(selectedDate),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Remark Field
                  TextFormField(
                    controller: remarkController,
                    decoration: const InputDecoration(
                      labelText: 'Remark (Optional)',
                      hintText: 'Add additional details about this event',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final eventDateTime = DateTime(
                    selectedDate.year,
                    selectedDate.month,
                    selectedDate.day,
                  );

                  final event = Event(
                    name: selectedEventName!,
                    dateTime: eventDateTime,
                    location: selectedLocation!,
                    category: selectedCategory!,
                    remark: remarkController.text.trim().isEmpty
                        ? null
                        : remarkController.text.trim(),
                  );

                  Navigator.pop(context);

                  final success = await context
                      .read<EventProvider>()
                      .createEvent(event);

                  if (mounted) {
                    if (success) {
                      // Refresh the event list
                      context.read<EventProvider>().fetchLatestEvents();
                    }

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          success
                              ? 'Event created successfully'
                              : 'Failed to create event',
                        ),
                      ),
                    );
                  }
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
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
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Create Event Button (only for ongoing tab)
          if (showCreateButton) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _showCreateEventDialog,
                icon: const Icon(Icons.add),
                label: const Text('Create New Event'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Events List Header
          if (events.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Events (${events.length})',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
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
                        Icon(
                          Icons.event_busy,
                          size: 80,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          emptyMessage,
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                        if (showCreateButton) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Create your first event to get started',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
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

  @override
  Widget build(BuildContext context) {
    final eventProvider = context.watch<EventProvider>();
    final events = eventProvider.events
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.home),
          tooltip: 'Back to Dashboard',
          onPressed: () => context.go('/dashboard'),
        ),
        title: const Text('Attendance'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search Events',
            onPressed: () => context.push('/attendance/inquiry'),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Ongoing'),
            Tab(text: 'Completed'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Ongoing Events Tab
          _buildEventsList(
            events: events,
            isLoading: eventProvider.isLoading,
            emptyMessage: 'No ongoing events',
            showCreateButton: true,
          ),
          // Completed Events Tab
          _buildEventsList(
            events: _completedEvents,
            isLoading: _isLoadingCompleted,
            emptyMessage: 'No completed events',
            showCreateButton: false,
          ),
        ],
      ),
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
