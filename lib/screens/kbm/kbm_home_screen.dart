import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:math' as math;
import 'kbm_setup_screen.dart';
import 'kbm_attendance_screen.dart';
import 'kbm_score_screen.dart';
import 'kbm_report_screen.dart';

class KbmHomeScreen extends StatelessWidget {
  const KbmHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Back to Dashboard',
            onPressed: () => context.go('/dashboard'),
          ),
          title: const Text('KBM Module'),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(kToolbarHeight),
            child: Align(
              alignment: Alignment.center,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final maxWidth = math.min(constraints.maxWidth * 0.9, 720.0);
                  return SizedBox(
                    width: maxWidth,
                    child: const TabBar(
                      isScrollable: false,
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.white70,
                      indicatorColor: Colors.white,
                      labelStyle: TextStyle(fontWeight: FontWeight.w600),
                      tabs: [
                        Tab(text: 'Setup'),
                        Tab(text: 'Attendance'),
                        Tab(text: 'Scores'),
                        Tab(text: 'Reporting'),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        body: const TabBarView(
          children: [
            KbmSetupScreen(),
            KbmAttendanceScreen(),
            KbmScoreScreen(),
            KbmReportScreen(),
          ],
        ),
      ),
    );
  }
}
