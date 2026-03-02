import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/event.dart';
import '../../providers/event_provider.dart';
import '../../services/api_service.dart';
import '../../services/storage_service.dart';

/// Shows the "Create New Event" dialog.
/// Pass [parentContext] — the screen's BuildContext — so provider lookups
/// and SnackBars work correctly after the dialog is dismissed.

/// Format a [TimeOfDay] without needing a BuildContext.
String _fmtTime(TimeOfDay t) {
  final hour = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
  final minute = t.minute.toString().padLeft(2, '0');
  final period = t.period == DayPeriod.am ? 'AM' : 'PM';
  return '$hour:$minute $period';
}

Future<void> showCreateEventDialog(BuildContext parentContext) async {
  final formKey = GlobalKey<FormState>();
  final remarkController = TextEditingController();
  DateTime selectedDate = DateTime.now();
  TimeOfDay selectedTimeFrom = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay selectedTimeTo = const TimeOfDay(hour: 10, minute: 0);
  bool isSubmitting = false;

  // Fetch lookups
  List<Map<String, dynamic>> eventTypes = [];
  List<Map<String, dynamic>> eventLevels = [];
  List<Map<String, dynamic>> eventLocations = [];
  List<Map<String, dynamic>> eventCategories = [];
  List<Map<String, dynamic>> ageGroupOptions = [];
  String? selectedEventName;
  String? selectedLevel;
  String? selectedLocation;
  String? selectedCategory;
  List<String> selectedAgeGroups = [];
  bool isLoadingEventTypes = true;
  bool isLoadingLevels = true;
  bool isLoadingLocations = true;
  bool isLoadingCategories = true;
  bool isLoadingAgeGroups = true;

  try {
    final eventResponse = await ApiService().getLookups('EVENT');
    if (eventResponse.statusCode == 200) {
      debugPrint('eventResponse.data: ${eventResponse.data}');
      eventTypes = List<Map<String, dynamic>>.from(eventResponse.data);
      eventTypes.sort((a, b) {
        final ao = (a['order'] as num?)?.toInt() ?? 0;
        final bo = (b['order'] as num?)?.toInt() ?? 0;
        return ao.compareTo(bo);
      });
    }
  } catch (e) {
    debugPrint('Error loading event types: $e');
  }
  isLoadingEventTypes = false;

  try {
    final levelResponse = await ApiService().getLookups('LEVEL');
    if (levelResponse.statusCode == 200) {
      eventLevels = List<Map<String, dynamic>>.from(levelResponse.data);
      eventLevels.sort((a, b) {
        final ao = (a['order'] as num?)?.toInt() ?? 0;
        final bo = (b['order'] as num?)?.toInt() ?? 0;
        return ao.compareTo(bo);
      });
      if (eventLevels.isNotEmpty) {
        selectedLevel = eventLevels[0]['value']?.toString();
      }
    }
  } catch (e) {
    debugPrint('Error loading levels: $e');
  }
  isLoadingLevels = false;

  try {
    final locationResponse = await ApiService().getLookups('EVENT_LOC');
    if (locationResponse.statusCode == 200) {
      eventLocations = List<Map<String, dynamic>>.from(locationResponse.data);
      eventLocations.sort((a, b) {
        final ao = (a['order'] as num?)?.toInt() ?? 0;
        final bo = (b['order'] as num?)?.toInt() ?? 0;
        return ao.compareTo(bo);
      });
    }
  } catch (e) {
    debugPrint('Error loading event locations: $e');
  }
  isLoadingLocations = false;

  try {
    final categoryResponse = await ApiService().getLookups('EVENT_CATEGORY');
    if (categoryResponse.statusCode == 200) {
      eventCategories = List<Map<String, dynamic>>.from(categoryResponse.data);
      eventCategories.sort((a, b) {
        final ao = (a['order'] as num?)?.toInt() ?? 0;
        final bo = (b['order'] as num?)?.toInt() ?? 0;
        return ao.compareTo(bo);
      });
    }
  } catch (e) {
    debugPrint('Error loading event categories: $e');
  }
  isLoadingCategories = false;

  try {
    final ageGroupResponse = await ApiService().getLookups('AGE_GROUP');
    if (ageGroupResponse.statusCode == 200) {
      const order = [
        'Dewasa',
        'Usia Nikah',
        'Remaja',
        'Pra Remaja',
        'CR',
        'Lansia',
      ];
      final all = List<Map<String, dynamic>>.from(ageGroupResponse.data);
      ageGroupOptions =
          all.where((o) => order.contains(o['value']?.toString())).toList()
            ..sort((a, b) {
              final ai = order.indexOf(a['value']?.toString() ?? '');
              final bi = order.indexOf(b['value']?.toString() ?? '');
              return ai.compareTo(bi);
            });
    }
  } catch (e) {
    debugPrint('Error loading age groups: $e');
  }
  isLoadingAgeGroups = false;

  // Obtain the provider before entering the dialog so we can use it
  // safely after showDialog() returns (when the dialog is fully gone).
  final eventProvider =
      Provider.of<EventProvider>(parentContext, listen: false);

  // showDialog<bool> resolves only after the exit animation completes,
  // so any code after the await runs with a fully-clean widget tree.
  final bool? created = await showDialog<bool>(
    context: parentContext,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('Create New Event'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Event Name ──────────────────────────────
                  isLoadingEventTypes
                      ? const Center(child: CircularProgressIndicator())
                      : DropdownButtonFormField<String>(
                          value: selectedEventName,
                          isExpanded: true,
                          isDense: true,
                          decoration: const InputDecoration(
                            labelText: 'Event Name',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                          hint: const Text('Select event type'),
                          items: eventTypes
                              .map((e) => DropdownMenuItem<String>(
                                    value: e['value'],
                                    child: Text(e['value'],
                                        overflow: TextOverflow.ellipsis),
                                  ))
                              .toList(),
                          onChanged: (v) =>
                              setDialogState(() => selectedEventName = v),
                          validator: (v) =>
                              (v == null || v.isEmpty) ? 'Required' : null,
                        ),
                  const SizedBox(height: 10),

                  // ── Level + Category (side by side) ─────────
                  Row(
                    children: [
                      Expanded(
                        child: isLoadingLevels
                            ? const Center(child: CircularProgressIndicator())
                            : DropdownButtonFormField<String>(
                                value: selectedLevel,
                                isExpanded: true,
                                isDense: true,
                                decoration: const InputDecoration(
                                  labelText: 'Level',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                ),
                                hint: const Text('Level'),
                                items: eventLevels
                                    .map((e) => DropdownMenuItem<String>(
                                          value: e['value'],
                                          child: Text(
                                            e['value'],
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ))
                                    .toList(),
                                onChanged: (v) =>
                                    setDialogState(() => selectedLevel = v),
                              ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: isLoadingCategories
                            ? const Center(child: CircularProgressIndicator())
                            : DropdownButtonFormField<String>(
                                value: selectedCategory,
                                isExpanded: true,
                                isDense: true,
                                decoration: const InputDecoration(
                                  labelText: 'Category',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                ),
                                hint: const Text('Category'),
                                items: eventCategories
                                    .map((e) => DropdownMenuItem<String>(
                                          value: e['value'],
                                          child: Text(
                                            e['value'],
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ))
                                    .toList(),
                                onChanged: (v) =>
                                    setDialogState(() => selectedCategory = v),
                                validator: (v) => (v == null || v.isEmpty)
                                    ? 'Required'
                                    : null,
                              ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // ── Location ─────────────────────────────────
                  isLoadingLocations
                      ? const Center(child: CircularProgressIndicator())
                      : DropdownButtonFormField<String>(
                          value: selectedLocation,
                          isExpanded: true,
                          isDense: true,
                          decoration: const InputDecoration(
                            labelText: 'Location',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                          hint: const Text('Select location'),
                          items: eventLocations
                              .map((e) => DropdownMenuItem<String>(
                                    value: e['value'],
                                    child: Text(e['value'],
                                        overflow: TextOverflow.ellipsis),
                                  ))
                              .toList(),
                          onChanged: (v) =>
                              setDialogState(() => selectedLocation = v),
                          validator: (v) =>
                              (v == null || v.isEmpty) ? 'Required' : null,
                        ),
                  const SizedBox(height: 10),

                  // ── Date ─────────────────────────────────────
                  InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now().add(
                          const Duration(days: 365),
                        ),
                      );
                      if (date != null) {
                        setDialogState(() => selectedDate = date);
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Date',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        suffixIcon: Icon(Icons.calendar_today, size: 18),
                      ),
                      child: Text(
                        DateFormat('EEE, dd MMM yyyy').format(selectedDate),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // ── Time From / To ────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final t = await showTimePicker(
                              context: context,
                              initialTime: selectedTimeFrom,
                            );
                            if (t != null) {
                              setDialogState(() => selectedTimeFrom = t);
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Time From',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              suffixIcon: Icon(Icons.access_time, size: 18),
                            ),
                            child: Text(
                              _fmtTime(selectedTimeFrom),
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final t = await showTimePicker(
                              context: context,
                              initialTime: selectedTimeTo,
                            );
                            if (t != null) {
                              setDialogState(() => selectedTimeTo = t);
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Time To',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              suffixIcon: Icon(Icons.access_time, size: 18),
                            ),
                            child: Text(
                              _fmtTime(selectedTimeTo),
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // ── Age Group ────────────────────────────────
                  isLoadingAgeGroups
                      ? const Center(child: CircularProgressIndicator())
                      : FormField<List<String>>(
                          initialValue: selectedAgeGroups,
                          validator: (_) => selectedAgeGroups.isEmpty
                              ? 'Select at least one age group'
                              : null,
                          builder: (field) => Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: field.hasError
                                        ? Colors.red
                                        : Colors.grey.shade400,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Age Group *',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: field.hasError
                                            ? Colors.red
                                            : Colors.grey.shade600,
                                      ),
                                    ),
                                    Wrap(
                                      spacing: 4,
                                      runSpacing: 0,
                                      children: ageGroupOptions.map((option) {
                                        final val =
                                            option['value']?.toString() ?? '';
                                        final isSelected =
                                            selectedAgeGroups.contains(val);
                                        return FilterChip(
                                          label: Text(
                                            val,
                                            style:
                                                const TextStyle(fontSize: 12),
                                          ),
                                          selected: isSelected,
                                          materialTapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                          padding: EdgeInsets.zero,
                                          visualDensity: VisualDensity.compact,
                                          onSelected: (checked) {
                                            setDialogState(() {
                                              if (checked) {
                                                selectedAgeGroups.add(val);
                                              } else {
                                                selectedAgeGroups.remove(val);
                                              }
                                            });
                                            field.didChange(selectedAgeGroups);
                                          },
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ),
                              ),
                              if (field.hasError)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    top: 4,
                                    left: 12,
                                  ),
                                  child: Text(
                                    field.errorText!,
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                  const SizedBox(height: 10),

                  // ── Remark ───────────────────────────────────
                  TextFormField(
                    controller: remarkController,
                    decoration: const InputDecoration(
                      labelText: 'Remark (Optional)',
                      hintText: 'Additional details…',
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    maxLines: 2,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: isSubmitting
                ? null
                : () async {
                    if (formKey.currentState!.validate()) {
                      final eventDateTime = DateTime(
                        selectedDate.year,
                        selectedDate.month,
                        selectedDate.day,
                        selectedTimeFrom.hour,
                        selectedTimeFrom.minute,
                      );

                      final event = Event(
                        name: [
                          selectedEventName!,
                          if (selectedLevel != null &&
                              selectedLevel!.isNotEmpty)
                            selectedLevel!
                        ].join(' - '),
                        dateTime: eventDateTime,
                        location: selectedLocation!,
                        category: selectedCategory!,
                        level: selectedLevel,
                        timeFrom: selectedTimeFrom,
                        timeTo: selectedTimeTo,
                        remark: remarkController.text.trim().isEmpty
                            ? null
                            : remarkController.text.trim(),
                        groupName:
                            StorageService.getUser()?.groupName ?? 'MBL 1',
                        ageGroups: selectedAgeGroups.isEmpty
                            ? null
                            : selectedAgeGroups,
                      );

                      debugPrint(
                        'Creating event with groupName: ${event.groupName}',
                      );

                      setDialogState(() => isSubmitting = true);
                      final success = await eventProvider.createEvent(event);
                      // Pop with the bool result. showDialog<bool> won't resolve
                      // until the exit animation finishes, so fetchLatestEvents
                      // and the SnackBar (handled below, outside showDialog) run
                      // only after the widget tree is fully clean.
                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext, success);
                      }
                    }
                  },
            child: isSubmitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Create'),
          ),
        ],
      ),
    ),
  );

  // showDialog<bool> resolves when Navigator.pop() is called, but the dialog's
  // exit animation still runs for ~150ms. Post-dialog logic runs first, then
  // we defer the dispose past the animation to avoid "controller used after
  // being disposed" errors from the still-animating TextFormField.
  if (created != null && parentContext.mounted) {
    if (created) {
      eventProvider.fetchLatestEvents();
    }
    ScaffoldMessenger.of(parentContext).showSnackBar(
      SnackBar(
        content: Text(
          created ? 'Event created successfully' : 'Failed to create event',
        ),
      ),
    );
  }

  // Defer dispose past the dialog exit animation (~150ms default).
  Future.delayed(const Duration(milliseconds: 300), remarkController.dispose);
}
