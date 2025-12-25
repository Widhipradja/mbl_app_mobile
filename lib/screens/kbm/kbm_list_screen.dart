import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/kbm_provider.dart';

class KbmListScreen extends StatelessWidget {
  const KbmListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<KbmProvider>(context);
    final items = provider.kbmConfigs;

    return Scaffold(
      appBar: AppBar(title: const Text('KBM List')),
      body: items.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('No KBM configurations yet.'),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => context.go('/kbm/setup'),
                    child: const Text('Add KBM'),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = items[index];
                return Card(
                  child: ListTile(
                    title: Text(item['className'] ?? 'KBM ${index + 1}'),
                    subtitle: Text(item['subject'] ?? ''),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (item['date'] != null)
                          Text(item['date'].toString().split('T').first),
                        if (item['startTime'] != null)
                          Text(
                            '${item['startTime']} - ${item['endTime'] ?? ''}',
                          ),
                      ],
                    ),
                    onTap: () {
                      // For now, navigate to setup to create new; editing not implemented
                      context.go('/kbm/setup');
                    },
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/kbm/setup'),
        child: const Icon(Icons.add),
      ),
    );
  }
}
