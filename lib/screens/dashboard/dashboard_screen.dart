import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_container.dart';
import '../../providers/auth_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/charging_session_provider.dart';
import '../ai/ai_assistant_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final authProvider = context.watch<AuthProvider>();
    final walletProvider = context.watch<WalletProvider>();
    final chargingProvider = context.watch<ChargingSessionProvider>();
    final brandColor = theme.colorScheme.primary;
    
    final hasActiveSession = chargingProvider.activeSession != null;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            const CircleAvatar(
              radius: 16,
              backgroundImage: NetworkImage('https://i.pravatar.cc/150?img=11'),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Good Morning,', style: TextStyle(fontSize: 12, color: isDark ? Colors.grey : Colors.grey[700])),
                Text(authProvider.user?.name ?? 'Driver', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () {},
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              brandColor.withOpacity(0.15),
              AppColors.background,
            ],
            stops: const [0.0, 0.3],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Active Charging or Quick Actions
                if (hasActiveSession)
                  _buildActiveChargingCard(context, chargingProvider, brandColor)
                else
                  _buildWalletCard(context, walletProvider, brandColor),
                  
                const SizedBox(height: 24),
                
                // AI Assistant Widget
                _buildAIAssistantWidget(context, brandColor),
                
                const SizedBox(height: 24),
                
                // Recent Stations
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Recent Stations', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    TextButton(
                      onPressed: () {},
                      child: Text('See All', style: TextStyle(color: brandColor)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                SizedBox(
                  height: 180,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: 3,
                    itemBuilder: (context, index) {
                      return _buildRecentStationCard(context, index, brandColor);
                    },
                  ),
                ),
                
                const SizedBox(height: 100), // Bottom nav padding
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWalletCard(BuildContext context, WalletProvider walletProvider, Color brandColor) {
    return GlassContainer(
      padding: const EdgeInsets.all(24),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -20,
            child: Icon(Icons.account_balance_wallet, size: 100, color: Colors.white.withOpacity(0.05)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Universal Wallet Balance', style: TextStyle(color: Colors.grey, fontSize: 14)),
              const SizedBox(height: 8),
              Text(
                '₹${walletProvider.balance.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: brandColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {},
                      icon: const Icon(Icons.add),
                      label: const Text('Add Money'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: brandColor,
                        side: BorderSide(color: brandColor),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {},
                      icon: const Icon(Icons.history),
                      label: const Text('History'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActiveChargingCard(BuildContext context, ChargingSessionProvider provider, Color brandColor) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.glassFill(Theme.of(context).brightness),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.success.withOpacity(0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.success.withOpacity(0.2),
            blurRadius: 30,
            offset: const Offset(0, 10),
          )
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Currently Charging', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('Live', style: TextStyle(color: AppColors.success, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              SizedBox(
                width: 80,
                height: 80,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: provider.activeSession!.batteryPercentage / 100,
                      strokeWidth: 8,
                      backgroundColor: Colors.grey.withOpacity(0.2),
                      color: AppColors.success,
                    ),
                    Center(
                      child: Text(
                        '${provider.activeSession!.batteryPercentage.toInt()}%',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Tata Power EZ Charge', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(height: 4),
                    Text('Power: ${provider.activeSession!.currentKw} kW', style: const TextStyle(color: Colors.grey)),
                    Text('Cost: ₹${provider.activeSession!.currentCost.toStringAsFixed(2)}', style: const TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.dangerRed,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => provider.stopSession(),
              icon: const Icon(Icons.stop),
              label: const Text('Stop Charging'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAIAssistantWidget(BuildContext context, Color brandColor) {
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const AIAssistantScreen()));
      },
      child: GlassContainer(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: brandColor.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.auto_awesome, color: brandColor, size: 28),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('EVHub AI Assistant', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('Ask me to find chargers, plan trips, or check battery health.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentStationCard(BuildContext context, int index, Color brandColor) {
    final names = ['Statiq CP', 'Tata Power Mall', 'Jio-bp Pulse'];
    final distances = ['1.2 km', '3.5 km', '5.0 km'];
    
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.glassFill(Theme.of(context).brightness),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.glassBorder(Theme.of(context).brightness)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.ev_station, color: brandColor, size: 32),
          const Spacer(),
          Text(names[index], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.directions_car, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Text(distances[index], style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}
