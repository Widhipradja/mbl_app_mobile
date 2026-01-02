import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/event.dart';
import '../../models/user.dart';
import '../../services/api_service.dart';

class EventDetailScreen extends StatefulWidget {
  final Event event;

  const EventDetailScreen({super.key, required this.event});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final List<User> _users = [];
  final Map<String, bool> _attendance = {};
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';
  late TabController _tabController;
  late Event _currentEvent;

  @override
  void initState() {
    super.initState();
    _currentEvent = widget.event;
    _tabController = TabController(length: 2, vsync: this);
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Load users with attendance data from the attendance endpoint
      final attendanceResponse = await _apiService.getEventAttendance(
        widget.event.id!,
      );

      if (attendanceResponse.statusCode == 200) {
        final List<dynamic> attendanceData = attendanceResponse.data is List
            ? attendanceResponse.data
            : (attendanceResponse.data['attendance'] ?? []);

        // Parse users and their attendance status
        _users.clear();
        _attendance.clear();

        for (var record in attendanceData) {
          // The response contains user fields directly at root level
          final user = User.fromJson(record);
          _users.add(user);

          // Store attendance status using user_id from response
          final userId = record['user_id'] ?? record['id'];
          _attendance[userId] = record['is_attending'] ?? false;
        }
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleAttendance(User user, bool? value) async {
    if (value == null) return;

    setState(() {
      _attendance[user.id] = value;
    });

    try {
      await _apiService.markAttendance(widget.event.id!, user.id, value);
    } catch (e) {
      // Revert on error
      setState(() {
        _attendance[user.id] = !value;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update attendance: $e')),
        );
      }
    }
  }

  Future<void> _syncAttendees() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final response = await _apiService.syncEventAttendees(_currentEvent.id!);

      if (response.statusCode == 200) {
        // Reload the attendance data
        await _loadData();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Attendees synced successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to sync attendees: $e')));
      }
    }
  }

  Future<void> _showRemarkDialog(User user) async {
    final remarkController = TextEditingController(text: user.remark ?? '');

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remark for ${user.name}'),
        content: TextField(
          controller: remarkController,
          decoration: const InputDecoration(
            labelText: 'Remark',
            hintText: 'Add notes about this attendee',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(remarkController.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null) {
      try {
        await _apiService.updateAttendanceRemark(
          _currentEvent.id!,
          user.id,
          result,
        );

        // Update local user remark
        final userIndex = _users.indexWhere((u) => u.id == user.id);
        if (userIndex != -1) {
          setState(() {
            _users[userIndex] = User(
              id: user.id,
              name: user.name,
              email: user.email,
              roles: user.roles,
              gender: user.gender,
              firstname: user.firstname,
              surname: user.surname,
              remark: result.isEmpty ? null : result,
            );
          });
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Remark updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update remark: $e')),
          );
        }
      }
    }
  }

  Future<void> _completeEvent() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Complete Event'),
        content: const Text(
          'Are you sure you want to mark this event as completed? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Complete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final response = await _apiService.updateEventStatus(
        _currentEvent.id!,
        'Completed',
      );

      if (response.statusCode == 200) {
        setState(() {
          _currentEvent = _currentEvent.copyWith(status: 'Completed');
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Event marked as completed'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to complete event: $e')));
      }
    }
  }

  void _showEventSummary() {
    final maleUsers = _users.where((u) => u.gender == 'male').toList();
    final femaleUsers = _users.where((u) => u.gender == 'female').toList();
    final maleAttending = maleUsers
        .where((u) => _attendance[u.id] ?? false)
        .length;
    final femaleAttending = femaleUsers
        .where((u) => _attendance[u.id] ?? false)
        .length;
    final attendingCount = _attendance.values.where((v) => v).length;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Event Summary'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Event Details
              Text(
                _currentEvent.name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                DateFormat(
                  'EEEE, MMMM dd, yyyy',
                ).format(_currentEvent.dateTime),
                style: TextStyle(color: Colors.grey[700]),
              ),
              const SizedBox(height: 4),
              Text(
                _currentEvent.location,
                style: TextStyle(color: Colors.grey[700]),
              ),
              if (_currentEvent.category.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Category: ${_currentEvent.category}',
                  style: TextStyle(color: Colors.grey[700]),
                ),
              ],
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              // Attendance Statistics
              const Text(
                'Attendance Statistics',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _buildSummaryRow(
                'Total Attendees',
                '${_users.length}',
                Colors.blue,
              ),
              _buildSummaryRow(
                'Total Attending',
                '$attendingCount',
                Colors.green,
              ),
              _buildSummaryRow(
                'Attendance Rate',
                '${(_users.isEmpty ? 0 : (attendingCount / _users.length * 100)).toStringAsFixed(1)}%',
                Colors.orange,
              ),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 12),
              _buildSummaryRow(
                'Male',
                '$maleAttending / ${maleUsers.length}',
                Colors.blue[700]!,
              ),
              _buildSummaryRow(
                'Female',
                '$femaleAttending / ${femaleUsers.length}',
                Colors.pink[700]!,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              await _copySummaryToClipboard();
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copy'),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 16, color: Colors.grey[800])),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _copySummaryToClipboard() async {
    final maleUsers = _users.where((u) => u.gender == 'male').toList();
    final femaleUsers = _users.where((u) => u.gender == 'female').toList();
    final maleAttending = maleUsers
        .where((u) => _attendance[u.id] ?? false)
        .length;
    final femaleAttending = femaleUsers
        .where((u) => _attendance[u.id] ?? false)
        .length;
    final attendingCount = _attendance.values.where((v) => v).length;
    final attendanceRate = _users.isEmpty
        ? 0
        : (attendingCount / _users.length * 100);

    final summary =
        '''📊 RINGKASAN ACARA

📅 ${_currentEvent.name}
📆 ${DateFormat('EEEE, MMMM dd, yyyy').format(_currentEvent.dateTime)}
📍 ${_currentEvent.location}${_currentEvent.category.isNotEmpty ? '\n🏷️ ${_currentEvent.category}' : ''}

━━━━━━━━━━━━━━━━━━━━

👥 STATISTIK KEHADIRAN

• Total Jamaah: ${_users.length}
• Total Hadir: $attendingCount
• Rata-rata Kehadiran: ${attendanceRate.toStringAsFixed(1)}%

━━━━━━━━━━━━━━━━━━━━

👨 Pria: $maleAttending / ${maleUsers.length}
👩 Wanita: $femaleAttending / ${femaleUsers.length}''';

    await Clipboard.setData(ClipboardData(text: summary));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Summary copied to clipboard'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _showEditEventDialog() async {
    final formKey = GlobalKey<FormState>();
    final remarkController = TextEditingController(text: _currentEvent.remark);
    DateTime selectedDate = _currentEvent.dateTime;
    String? selectedEventName = _currentEvent.name;
    String? selectedLocation = _currentEvent.location;
    String? selectedCategory = _currentEvent.category;

    // Fetch event types and locations
    List<Map<String, dynamic>> eventTypes = [];
    List<Map<String, dynamic>> eventLocations = [];
    List<Map<String, dynamic>> eventCategories = [];
    bool isLoadingEventTypes = true;
    bool isLoadingLocations = true;
    bool isLoadingCategories = true;

    try {
      final eventResponse = await _apiService.getLookups('EVENT');
      if (eventResponse.statusCode == 200) {
        eventTypes = List<Map<String, dynamic>>.from(eventResponse.data);
      }
    } catch (e) {
      debugPrint('Error loading event types: $e');
    }
    isLoadingEventTypes = false;

    try {
      final locationResponse = await _apiService.getLookups('EVENT_LOC');
      if (locationResponse.statusCode == 200) {
        eventLocations = List<Map<String, dynamic>>.from(locationResponse.data);
      }
    } catch (e) {
      debugPrint('Error loading event locations: $e');
    }
    isLoadingLocations = false;

    try {
      final categoryResponse = await _apiService.getLookups('EVENT_CATEGORY');
      if (categoryResponse.statusCode == 200) {
        eventCategories = List<Map<String, dynamic>>.from(
          categoryResponse.data,
        );
      }
    } catch (e) {
      debugPrint('Error loading event categories: $e');
    }
    isLoadingCategories = false;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Event'),
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
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  Navigator.of(context).pop(true);

                  // Update the event
                  try {
                    final eventDateTime = DateTime(
                      selectedDate.year,
                      selectedDate.month,
                      selectedDate.day,
                    );

                    final response = await _apiService
                        .updateEvent(_currentEvent.id!, {
                          'event_name': selectedEventName!,
                          'location': selectedLocation!,
                          'category': selectedCategory!,
                          'event_date': eventDateTime.toIso8601String(),
                          if (remarkController.text.trim().isNotEmpty)
                            'remark': remarkController.text.trim(),
                        });

                    if (response.statusCode == 200) {
                      setState(() {
                        _currentEvent = _currentEvent.copyWith(
                          name: selectedEventName,
                          location: selectedLocation,
                          category: selectedCategory,
                          dateTime: eventDateTime,
                          remark: remarkController.text.trim().isEmpty
                              ? null
                              : remarkController.text.trim(),
                        );
                      });

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Event updated successfully'),
                          ),
                        );
                      }
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to update event: $e')),
                      );
                    }
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserList(List<User> users) {
    if (users.isEmpty) {
      return Center(
        child: Text(
          'No users found',
          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        final isAttending = _attendance[user.id] ?? false;
        final isCompleted = _currentEvent.status == 'Completed';

        return Card(
          margin: const EdgeInsets.only(bottom: 4),
          child: CheckboxListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 0,
            ),
            dense: true,
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    user.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (user.remark != null && user.remark!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(
                      Icons.note,
                      size: 16,
                      color: const Color.fromARGB(255, 96, 102, 108),
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.more_vert, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _showRemarkDialog(user),
                  tooltip: 'Add remark',
                ),
              ],
            ),
            value: isAttending,
            onChanged: isCompleted
                ? null
                : (value) => _toggleAttendance(user, value),
            activeColor: Colors.green,
            controlAffinity: ListTileControlAffinity.leading,
          ),
        );
      },
    );
  }

  Widget _buildHeaderCard(int attendingCount) {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Event Name
            Text(
              _currentEvent.name,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            // Date
            Row(
              children: [
                Icon(Icons.calendar_today, color: Colors.grey[700]),
                const SizedBox(width: 8),
                Text(
                  DateFormat(
                    'EEEE, MMMM dd, yyyy',
                  ).format(_currentEvent.dateTime),
                  style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Location
            if (_currentEvent.location.isNotEmpty)
              Row(
                children: [
                  Icon(Icons.location_on, color: Colors.grey[700]),
                  const SizedBox(width: 8),
                  Text(
                    _currentEvent.location,
                    style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                  ),
                ],
              ),
            // Remark
            if (_currentEvent.remark != null &&
                _currentEvent.remark!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.note, color: Colors.grey[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _currentEvent.remark!,
                        style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            // Attendance Count
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$attendingCount of ${_users.length} attending',
                style: TextStyle(
                  color: Colors.blue[700],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Complete Event Button
            if (_currentEvent.status != 'Completed')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _completeEvent,
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Complete Event'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            if (_currentEvent.status == 'Completed') ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, color: Colors.green[700]),
                    const SizedBox(width: 8),
                    Text(
                      'Event Completed',
                      style: TextStyle(
                        color: Colors.green[700],
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _showEventSummary,
                  icon: const Icon(Icons.summarize),
                  label: const Text('View Summary'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final attendingCount = _attendance.values.where((v) => v).length;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/attendance'),
        ),
        title: const Text('Event Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _showEditEventDialog,
            tooltip: 'Edit Event',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Pria'),
            Tab(text: 'Wanita'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading data',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _loadData,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                // Male Users
                _buildScrollableContent(
                  _users.where((u) => u.gender == 'male').toList()..sort(
                    (a, b) => (a.firstname ?? a.name).toLowerCase().compareTo(
                      (b.firstname ?? b.name).toLowerCase(),
                    ),
                  ),
                  attendingCount,
                ),
                // Female Users
                _buildScrollableContent(
                  _users.where((u) => u.gender == 'female').toList()..sort(
                    (a, b) => (a.firstname ?? a.name).toLowerCase().compareTo(
                      (b.firstname ?? b.name).toLowerCase(),
                    ),
                  ),
                  attendingCount,
                ),
              ],
            ),
    );
  }

  Widget _buildScrollableContent(List<User> users, int attendingCount) {
    // Filter users based on search query
    final filteredUsers = _searchQuery.isEmpty
        ? users
        : users.where((user) {
            return user.name.toLowerCase().contains(_searchQuery) ||
                (user.firstname?.toLowerCase().contains(_searchQuery) ??
                    false) ||
                (user.surname?.toLowerCase().contains(_searchQuery) ?? false);
          }).toList();

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildHeaderCard(attendingCount)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  'Attendees',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.sync),
                  onPressed: _syncAttendees,
                  tooltip: 'Sync Attendees',
                  iconSize: 20,
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(child: const SizedBox(height: 8)),
        filteredUsers.isEmpty
            ? SliverFillRemaining(
                child: Center(
                  child: Text(
                    _searchQuery.isEmpty
                        ? 'No users found'
                        : 'No matching users',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                ),
              )
            : SliverPadding(
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final user = filteredUsers[index];
                    final isAttending = _attendance[user.id] ?? false;
                    final isCompleted = _currentEvent.status == 'Completed';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 4),
                      child: CheckboxListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 0,
                        ),
                        dense: true,
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                user.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            if (user.remark != null && user.remark!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: Icon(
                                  Icons.note,
                                  size: 16,
                                  color: const Color.fromARGB(
                                    255,
                                    96,
                                    102,
                                    108,
                                  ),
                                ),
                              ),
                            IconButton(
                              icon: const Icon(Icons.more_vert, size: 18),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => _showRemarkDialog(user),
                              tooltip: 'Add remark',
                            ),
                          ],
                        ),
                        value: isAttending,
                        onChanged: isCompleted
                            ? null
                            : (value) => _toggleAttendance(user, value),
                        activeColor: Colors.green,
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                    );
                  }, childCount: filteredUsers.length),
                ),
              ),
      ],
    );
  }
}
