import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/maintenance_provider.dart';
import '../../models/maintenance_model.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_container.dart';

class MaintenanceScreen extends StatefulWidget {
  const MaintenanceScreen({super.key});

  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MaintenanceProvider>().loadTasks('demo_vehicle_123', null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MaintenanceProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Predictive Maintenance')),
      body: provider.tasks.isEmpty
          ? const Center(child: Text('No maintenance tasks pending.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: provider.tasks.length,
              itemBuilder: (context, index) {
                final task = provider.tasks[index];
                return _buildTaskCard(task, isDark, provider);
              },
            ),
    );
  }

  Widget _buildTaskCard(MaintenanceModel task, bool isDark, MaintenanceProvider provider) {
    Color urgencyColor;
    switch (task.urgency) {
      case MaintenanceUrgency.critical:
        urgencyColor = Colors.red;
        break;
      case MaintenanceUrgency.high:
        urgencyColor = Colors.orange;
        break;
      case MaintenanceUrgency.medium:
        urgencyColor = Colors.amber;
        break;
      case MaintenanceUrgency.low:
        urgencyColor = Colors.green;
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GlassContainer(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.build_circle, color: urgencyColor, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    task.component,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                if (task.isCompleted)
                  const Icon(Icons.check_circle, color: Colors.green)
              ],
            ),
            const SizedBox(height: 12),
            Text(task.description, style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)),
            const SizedBox(height: 12),
            Text('Due: ${task.estimatedDueDate.toString().split(' ')[0]}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
            if (!task.isCompleted) ...[
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: () => provider.completeTask(task),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryPurple,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Mark Completed'),
                ),
              )
            ]
          ],
        ),
      ),
    );
  }
}
