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
  int _currentStep = 0;
  
  // Form State
  String? _selectedBrand;
  String _model = '';
  String _variant = '';
  String _color = 'White';
  String _connector = 'CCS2';
  double _batteryCapacity = 60.0;
  double _currentBattery = 80.0;
  final int _wheelSize = 18;
  String _drivingStyle = 'Normal';
  
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

  void _nextStep() {
    if (_currentStep < 2) {
      setState(() => _currentStep++);
    } else {
      // Finalize and save
      debugPrint('Saving Vehicle: $_model $_variant $_wheelSize');
      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.home, (route) => false);
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brandColor = theme.colorScheme.primary;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: _currentStep > 0 ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: _prevStep) : null,
        title: Text('Step ${_currentStep + 1} of 3', style: const TextStyle(fontSize: 14, color: Colors.grey)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
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
            stops: const [0.0, 0.4],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Progress Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: LinearProgressIndicator(
                  value: (_currentStep + 1) / 3,
                  backgroundColor: AppColors.card,
                  valueColor: AlwaysStoppedAnimation<Color>(brandColor),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: IndexedStack(
                  index: _currentStep,
                  children: [
                    _buildStep1Brand(brandColor),
                    _buildStep2Specs(brandColor),
                    _buildStep3Preferences(brandColor),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(24.0),
        child: PremiumButton(
          text: _currentStep == 2 ? 'Complete Setup' : 'Continue',
          icon: _currentStep == 2 ? Icons.check_circle : Icons.arrow_forward,
          onPressed: (_currentStep == 0 && _selectedBrand == null) ? () {} : _nextStep,
        ),
      ),
    );
  }

  Widget _buildStep1Brand(Color brandColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Select Manufacturer', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, height: 1.2)),
          const SizedBox(height: 8),
          const Text('We will adapt the app theme to match your vehicle.', style: TextStyle(color: Colors.grey, fontSize: 16)),
          const SizedBox(height: 32),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.2,
            ),
            itemCount: _brands.length,
            itemBuilder: (context, index) {
              final brand = _brands[index];
              final isSelected = _selectedBrand == brand['name'];
              return GestureDetector(
                onTap: () {
                  setState(() => _selectedBrand = brand['name']);
                  context.read<ThemeProvider>().setBrandTheme(_selectedBrand!);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  decoration: BoxDecoration(
                    color: isSelected ? brand['color'].withOpacity(0.2) : AppColors.card.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? brand['color'] : Colors.transparent,
                      width: 2,
                    ),
                    boxShadow: isSelected ? [BoxShadow(color: brand['color'].withOpacity(0.3), blurRadius: 15)] : [],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        backgroundColor: brand['color'],
                        radius: 24,
                        child: Text(brand['logo'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
                      ),
                      const SizedBox(height: 12),
                      Text(brand['name'], style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 16)),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStep2Specs(Color brandColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Vehicle Specs', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
          const SizedBox(height: 32),
          _buildTextField('Model', 'e.g., Nexon EV, Model 3', (val) => _model = val),
          const SizedBox(height: 16),
          _buildTextField('Variant', 'e.g., Long Range, Performance', (val) => _variant = val),
          const SizedBox(height: 24),
          Text('Battery Capacity: ${_batteryCapacity.toInt()} kWh', style: const TextStyle(fontWeight: FontWeight.bold)),
          Slider(
            value: _batteryCapacity,
            min: 10,
            max: 120,
            activeColor: brandColor,
            onChanged: (val) => setState(() => _batteryCapacity = val),
          ),
          const SizedBox(height: 16),
          const Text('Connector Type', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            children: ['CCS2', 'Type 2', 'CHAdeMO', 'NACS'].map((type) {
              final isSelected = _connector == type;
              return ChoiceChip(
                label: Text(type),
                selected: isSelected,
                selectedColor: brandColor.withOpacity(0.2),
                backgroundColor: AppColors.card,
                onSelected: (val) => setState(() => _connector = type),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStep3Preferences(Color brandColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Current Status', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
          const SizedBox(height: 32),
          
          Text('Current Battery: ${_currentBattery.toInt()}%', style: const TextStyle(fontWeight: FontWeight.bold)),
          Slider(
            value: _currentBattery,
            min: 0,
            max: 100,
            activeColor: brandColor,
            onChanged: (val) => setState(() => _currentBattery = val),
          ),
          const SizedBox(height: 24),
          
          const Text('Vehicle Color', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            children: ['White', 'Black', 'Red', 'Blue', 'Silver'].map((type) {
              final isSelected = _color == type;
              return ChoiceChip(
                label: Text(type),
                selected: isSelected,
                selectedColor: brandColor.withOpacity(0.2),
                backgroundColor: AppColors.card,
                onSelected: (val) => setState(() => _color = type),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          
          const Text('Driving Style', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            children: ['Eco', 'Normal', 'Sport'].map((type) {
              final isSelected = _drivingStyle == type;
              return ChoiceChip(
                label: Text(type),
                selected: isSelected,
                selectedColor: brandColor.withOpacity(0.2),
                backgroundColor: AppColors.card,
                onSelected: (val) => setState(() => _drivingStyle = type),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, String hint, Function(String) onChanged) {
    return TextField(
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: AppColors.card.withOpacity(0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
