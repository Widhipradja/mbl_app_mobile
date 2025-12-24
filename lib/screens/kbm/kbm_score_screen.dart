import 'package:flutter/material.dart';

class KbmScoreScreen extends StatelessWidget {
  const KbmScoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.score, size: 64, color: Colors.green),
            SizedBox(height: 12),
            Text(
              'Member Scores',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8),
            Text('Placeholder for score management features.'),
          ],
        ),
      ),
    );
  }
}
