import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/theme_provider.dart';
import '../../core/widgets/premium_button.dart';

class VehicleOnboardingScreen extends StatefulWidget {
  const VehicleOnboardingScreen({super.key});

  @override
  State<VehicleOnboardingScreen> createState() => _VehicleOnboardingScreenState();
}

class _VehicleOnboardingScreenState extends State<VehicleOnboardingScreen> {
  String? _selectedBrand;
  final List<Map<String, dynamic>> _brands = [
    {'name': 'Tata', 'color': AppColors.brandTata, 'logo': 'T'},
    {'name': 'MG', 'color': AppColors.brandMG, 'logo': 'M'},
    {'name': 'Hyundai', 'color': AppColors.brandHyundai, 'logo': 'H'},
    {'name': 'Mahindra', 'color': AppColors.brandMahindra, 'logo': 'M'},
    {'name': 'BYD', 'color': AppColors.brandBYD, 'logo': 'B'},
    {'name': 'Tesla', 'color': AppColors.brandTesla, 'logo': 'T'},
    {'name': 'Mercedes', 'color': AppColors.brandMercedes, 'logo': 'M'},
    {'name': 'Other', 'color': AppColors.primaryCyan, 'logo': 'O'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Your Vehicle'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Personalize Your Experience',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Select your EV brand. We will adapt the app theme to match your vehicle.',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
              const SizedBox(height: 32),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.5,
                  ),
                  itemCount: _brands.length,
                  itemBuilder: (context, index) {
                    final brand = _brands[index];
                    final isSelected = _selectedBrand == brand['name'];
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedBrand = brand['name'];
                        });
                        // Preview theme dynamically
                        context.read<ThemeProvider>().setBrandTheme(_selectedBrand!);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        decoration: BoxDecoration(
                          color: isSelected ? brand['color'].withOpacity(0.2) : AppColors.glassFill(Theme.of(context).brightness),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected ? brand['color'] : AppColors.glassBorder(Theme.of(context).brightness),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircleAvatar(
                              backgroundColor: brand['color'],
                              radius: 20,
                              child: Text(brand['logo'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(height: 8),
                            Text(brand['name'], style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              PremiumButton(
                text: 'Continue to App',
                icon: Icons.arrow_forward,
                onPressed: _selectedBrand == null
                    ? () {} // Disabled
                    : () {
                        // In a real app, save vehicle to Garage repository here
                        Navigator.pushNamedAndRemoveUntil(context, AppRoutes.home, (route) => false);
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
