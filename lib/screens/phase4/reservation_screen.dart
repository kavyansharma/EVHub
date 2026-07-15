import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/reservation_provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_container.dart';
import '../../models/reservation_model.dart';
import 'package:intl/intl.dart';

class ReservationScreen extends StatefulWidget {
  const ReservationScreen({super.key});

  @override
  State<ReservationScreen> createState() => _ReservationScreenState();
}

class _ReservationScreenState extends State<ReservationScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = context.read<AuthProvider>().user?.id ?? 'guest';
      context.read<ReservationProvider>().listenToReservations(userId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReservationProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('My Reservations')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Placeholder for booking flow
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a station on the map to book a slot.')));
        },
        backgroundColor: AppColors.primaryCyan,
        icon: const Icon(Icons.add, color: Colors.black),
        label: const Text('New Booking', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : provider.reservations.isEmpty
              ? Center(child: Text('No active reservations.', style: TextStyle(color: isDark ? Colors.white70 : Colors.black54)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: provider.reservations.length,
                  itemBuilder: (context, index) {
                    final res = provider.reservations[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: GlassContainer(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Station ID: ${res.stationId}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                _buildStatusBadge(res.status),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Icon(Icons.access_time, size: 16, color: AppColors.primaryCyan),
                                const SizedBox(width: 8),
                                Text('${DateFormat('MMM dd, hh:mm a').format(res.startTime)} - ${DateFormat('hh:mm a').format(res.endTime)}'),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.currency_rupee, size: 16, color: AppColors.primaryCyan),
                                const SizedBox(width: 8),
                                Text('Est. Cost: ₹${res.estimatedCost.toStringAsFixed(2)}'),
                              ],
                            ),
                            if (res.status == ReservationStatus.pending || res.status == ReservationStatus.active)
                              Padding(
                                padding: const EdgeInsets.only(top: 16),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent, side: const BorderSide(color: Colors.redAccent)),
                                    onPressed: () => provider.cancelReservation(res.id),
                                    child: const Text('Cancel Reservation'),
                                  ),
                                ),
                              )
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildStatusBadge(ReservationStatus status) {
    Color color;
    switch (status) {
      case ReservationStatus.active:
        color = Colors.green;
        break;
      case ReservationStatus.pending:
        color = Colors.orange;
        break;
      case ReservationStatus.cancelled:
        color = Colors.red;
        break;
      case ReservationStatus.completed:
        color = Colors.grey;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(12), border: Border.all(color: color)),
      child: Text(status.name.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}
