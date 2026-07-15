import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/formatters.dart';
import '../core/widgets/glass_container.dart';
import '../data/mock_data.dart';

class StationCard extends StatelessWidget {
  final ChargingStation station;
  final VoidCallback? onTap;

  const StationCard({
    super.key,
    required this.station,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isOccupied = station.availableStalls == 0;
    
    Color statusColor;
    if (isOccupied) {
      statusColor = AppColors.dangerRed;
    } else if (station.availableStalls <= 2) {
      statusColor = AppColors.accentAmber;
    } else {
      statusColor = AppColors.accentGreen;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: GlassContainer(
        borderRadius: 20,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: Station Name and occupancy status
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            station.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            station.location,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: statusColor.withOpacity(0.3), width: 1),
                      ),
                      child: Text(
                        isOccupied ? 'Full' : '${station.availableStalls}/${station.totalStalls} Free',
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Specifications row: Power output, plugs, price, distance
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Power capacity
                    _buildSpecItem(
                      context,
                      Icons.offline_bolt_rounded,
                      AppFormatters.formatPower(station.power),
                      'Speed',
                    ),
                    // Distance
                    _buildSpecItem(
                      context,
                      Icons.place_rounded,
                      AppFormatters.formatDistance(station.distance),
                      'Distance',
                    ),
                    // Pricing
                    _buildSpecItem(
                      context,
                      Icons.monetization_on_rounded,
                      '${AppFormatters.formatCurrency(station.pricePerKWh)}/kWh',
                      'Rate',
                    ),
                  ],
                ),
                
                // Plugs list and compatibility badge
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Plugs badges
                    Wrap(
                      spacing: 8,
                      children: station.plugs.map((plug) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            plug,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    
                    // Tesla compatibility label
                    if (station.isTeslaCompatible)
                      Row(
                        children: [
                          Icon(
                            Icons.check_circle_outline_rounded,
                            size: 14,
                            color: isDark ? AppColors.primaryCyan : AppColors.primaryPurple,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Tesla OK',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppColors.primaryCyan : AppColors.primaryPurple,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSpecItem(BuildContext context, IconData icon, String value, String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: isDark ? AppColors.primaryCyan : AppColors.primaryPurple,
        ),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
