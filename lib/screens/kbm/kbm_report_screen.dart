import 'package:flutter/material.dart';

class KbmReportScreen extends StatelessWidget {
  const KbmReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.insert_chart_outlined, size: 64, color: Colors.purple),
            SizedBox(height: 12),
            Text(
              'Reporting',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8),
            Text('Placeholder for reporting and exports.'),
          ],
        ),
      ),
    );
  }
}
