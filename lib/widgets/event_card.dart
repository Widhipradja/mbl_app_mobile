import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/event.dart';

class EventCard extends StatelessWidget {
  final Event event;
  final VoidCallback? onDelete;
  final VoidCallback onTap;

  const EventCard({
    super.key,
    required this.event,
    this.onDelete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final eventDate = event.dateTime;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final eventDay = DateTime(eventDate.year, eventDate.month, eventDate.day);

    final isToday = eventDay.isAtSameMomentAs(today);
    final isUpcoming = eventDate.isAfter(now);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: (isUpcoming || isToday) ? Colors.blue[50] : Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                DateFormat('MMM').format(eventDate),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: (isUpcoming || isToday)
                      ? Colors.blue[700]
                      : Colors.grey[600],
                ),
              ),
              Text(
                DateFormat('dd').format(eventDate),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: (isUpcoming || isToday)
                      ? Colors.blue[700]
                      : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        title: Text(
          event.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            // Location
            if (event.location.isNotEmpty)
              Row(
                children: [
                  Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      event.location,
                      style: TextStyle(color: Colors.grey[600]),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 4),
            // Date
            Row(
              children: [
                Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    DateFormat('EEEE, MMM dd, yyyy').format(eventDate),
                    style: TextStyle(color: Colors.grey[600]),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Category
            Row(
              children: [
                Icon(Icons.category, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    event.category,
                    style: TextStyle(color: Colors.grey[600]),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            // Remark
            if (event.remark != null && event.remark!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.note, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      event.remark!,
                      style: TextStyle(color: Colors.grey[600]),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 4),
            // Status
            Row(
              children: [
                Icon(
                  isToday
                      ? Icons.today
                      : (isUpcoming ? Icons.upcoming : Icons.history),
                  size: 14,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Text(
                  isToday ? 'Today' : (isUpcoming ? 'Upcoming' : 'Past'),
                  style: TextStyle(
                    color: (isToday || isUpcoming)
                        ? Colors.blue[700]
                        : Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: onDelete != null
            ? PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) {
                  if (value == 'delete') {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Delete Event'),
                        content: const Text(
                          'Are you sure you want to delete this event?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              onDelete!();
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Delete'),
                      ],
                    ),
                  ),
                ],
              )
            : null,
        onTap: onTap,
      ),
    );
  }
}
