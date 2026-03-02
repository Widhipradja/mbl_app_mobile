import 'package:flutter/material.dart';

class KbmAttendanceScreen extends StatelessWidget {
  const KbmAttendanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_available, size: 64, color: Colors.blue),
            SizedBox(height: 12),
            Text(
              'Member Attendance',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8),
            Text('Placeholder for attendance features.'),
          ],
        ),
      ),
    );
  }
}
