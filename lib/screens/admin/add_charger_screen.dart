import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_container.dart';
import '../../core/widgets/premium_button.dart';
import '../../models/map_marker_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/admin_charger_provider.dart';
import '../../services/charger_image_service.dart';
import '../../services/maps_service.dart';
import 'location_picker_screen.dart';

class ConnectorEntry {
  String type;
  double powerKw;
  MarkerStatus status;
  double pricePerKwh;

  ConnectorEntry({
    this.type = 'CCS2',
    this.powerKw = 60.0,
    this.status = MarkerStatus.available,
    this.pricePerKwh = 21.0,
  });
}

class AddChargerScreen extends StatefulWidget {
  final MapMarkerModel? initialCharger;

  const AddChargerScreen({super.key, this.initialCharger});

  @override
  State<AddChargerScreen> createState() => _AddChargerScreenState();
}

class _AddChargerScreenState extends State<AddChargerScreen> {
  final _formKey = GlobalKey<FormState>();
  final ChargerImageService _imageService = ChargerImageService();
  final MapsService _mapsService = MapsService();

  // Section 1: Basic Info Controllers
  late TextEditingController _nameController;
  late TextEditingController _customNetworkController;
  late TextEditingController _addressController;
  late TextEditingController _cityController;
  late TextEditingController _stateController;
  late TextEditingController _countryController;

  // Section 2: Location Controllers
  late TextEditingController _latController;
  late TextEditingController _lngController;

  // Section 4: Details Controllers
  late TextEditingController _openingHoursController;
  late TextEditingController _phoneController;
  late TextEditingController _websiteController;
  late TextEditingController _amenitiesController;
  late TextEditingController _descriptionController;
  late TextEditingController _imageUrlController;

  // Form selections & state
  String _selectedNetwork = 'Tata Power';
  bool _isCustomNetwork = false;
  bool _isVerified = true;
  bool _isLocating = false;

  // Section 3: Dynamic Connectors List
  final List<ConnectorEntry> _connectors = [];

  final List<String> _networkOptions = [
    'Tata Power',
    'Statiq',
    'Jio-bp Pulse',
    'ChargeZone',
    'Zeon',
    'Shell Recharge',
    'Kazam',
    'Bolt Earth',
    'Other',
  ];

  final List<String> _connectorTypeOptions = [
    'CCS2',
    'Type 2',
    'CHAdeMO',
    'GB/T',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    final c = widget.initialCharger;

    _nameController = TextEditingController(text: c?.title ?? '');
    
    final initialNet = c?.network ?? 'Tata Power';
    if (_networkOptions.contains(initialNet)) {
      _selectedNetwork = initialNet;
      _isCustomNetwork = false;
      _customNetworkController = TextEditingController();
    } else {
      _selectedNetwork = 'Other';
      _isCustomNetwork = true;
      _customNetworkController = TextEditingController(text: initialNet);
    }

    _addressController = TextEditingController(text: c?.address ?? c?.description ?? '');
    _cityController = TextEditingController(text: c?.city ?? '');
    _stateController = TextEditingController(text: c?.state ?? '');
    _countryController = TextEditingController(text: c?.country ?? 'India');

    _latController = TextEditingController(text: c != null ? c.latitude.toString() : '');
    _lngController = TextEditingController(text: c != null ? c.longitude.toString() : '');

    _openingHoursController = TextEditingController(text: c?.openingHours ?? '24 Hours');
    _phoneController = TextEditingController(text: c?.phoneNumber ?? '');
    _websiteController = TextEditingController(text: c?.website ?? '');
    _amenitiesController = TextEditingController(text: c?.amenities?.join(', ') ?? 'Restroom, Café, Wifi');
    _descriptionController = TextEditingController(text: c?.description ?? '');
    _imageUrlController = TextEditingController(text: c?.photoUrl ?? '');
    _isVerified = c?.isVerified ?? true;

    // Initialize connectors
    if (c != null && c.connectors.isNotEmpty) {
      final double defaultPower = double.tryParse(RegExp(r'[0-9.]+').firstMatch(c.power)?.group(0) ?? '60') ?? 60.0;
      final double defaultPrice = double.tryParse(RegExp(r'[0-9.]+').firstMatch(c.price ?? '21')?.group(0) ?? '21') ?? 21.0;
      for (final type in c.connectors) {
        if (type != 'Details Unavailable') {
          _connectors.add(ConnectorEntry(
            type: _connectorTypeOptions.contains(type) ? type : 'Other',
            powerKw: defaultPower,
            status: c.status,
            pricePerKwh: defaultPrice,
          ));
        }
      }
    }

    if (_connectors.isEmpty) {
      _connectors.add(ConnectorEntry(type: 'CCS2', powerKw: 60.0, status: MarkerStatus.available, pricePerKwh: 21.0));
      _connectors.add(ConnectorEntry(type: 'Type 2', powerKw: 22.0, status: MarkerStatus.available, pricePerKwh: 18.0));
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _customNetworkController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _countryController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _openingHoursController.dispose();
    _phoneController.dispose();
    _websiteController.dispose();
    _amenitiesController.dispose();
    _descriptionController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  Future<void> _pickLocationOnMap() async {
    final double? currentLat = double.tryParse(_latController.text);
    final double? currentLng = double.tryParse(_lngController.text);

    final LocationPickerResult? result = await Navigator.of(context).push<LocationPickerResult>(
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(
          initialLat: currentLat,
          initialLng: currentLng,
          initialAddress: _addressController.text,
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _latController.text = result.latitude.toStringAsFixed(6);
        _lngController.text = result.longitude.toStringAsFixed(6);
        if (_addressController.text.isEmpty || _addressController.text == 'Address not available') {
          _addressController.text = result.address;
        }
      });
    }
  }

  Future<void> _useCurrentGpsLocation() async {
    setState(() {
      _isLocating = true;
    });

    try {
      final loc = await _mapsService.getCurrentLocation();
      final double lat = loc['latitude']!;
      final double lng = loc['longitude']!;

      final address = await _mapsService.getAddressFromCoordinates(lat, lng);

      if (mounted) {
        setState(() {
          _latController.text = lat.toStringAsFixed(6);
          _lngController.text = lng.toStringAsFixed(6);
          if (_addressController.text.isEmpty) {
            _addressController.text = address;
          }
          _isLocating = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('GPS Location fetched successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLocating = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('GPS location failed: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _submitForm(UserModel user) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_latController.text.trim().isEmpty || _lngController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location coordinates are required. Please select a position on map or GPS.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    final double? lat = double.tryParse(_latController.text.trim());
    final double? lng = double.tryParse(_lngController.text.trim());

    if (lat == null || lng == null || lat < -90.0 || lat > 90.0 || lng < -180.0 || lng > 180.0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter valid Latitude (-90 to 90) and Longitude (-180 to 180).'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    if (_connectors.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one connector entry.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    // Determine final Network Name
    final String networkName = _isCustomNetwork
        ? _customNetworkController.text.trim()
        : _selectedNetwork;

    // Connector Totals Computation (Part 3 & Section 3 Requirement)
    final int totalConnectors = _connectors.length;
    final int availableConnectors = _connectors.where((c) => c.status == MarkerStatus.available).length;
    final int occupiedConnectors = _connectors.where((c) => c.status == MarkerStatus.busy).length;

    // Overall Station Status
    MarkerStatus computedStationStatus = MarkerStatus.available;
    if (_connectors.every((c) => c.status == MarkerStatus.offline)) {
      computedStationStatus = MarkerStatus.offline;
    } else if (availableConnectors == 0 && occupiedConnectors > 0) {
      computedStationStatus = MarkerStatus.busy;
    }

    // Power Output
    final double maxPower = _connectors.map((c) => c.powerKw).reduce((a, b) => a > b ? a : b);
    final String powerString = '${maxPower.toStringAsFixed(0)}kW';
    final String powerType = maxPower >= 100.0 ? 'Ultra Fast' : maxPower >= 22.0 ? 'Fast' : 'AC';

    // Price
    final double avgPrice = _connectors.map((c) => c.pricePerKwh).reduce((a, b) => a + b) / totalConnectors;
    final String priceString = '₹${avgPrice.toStringAsFixed(0)}/kWh';

    // Image URL processing
    String photoUrl = _imageUrlController.text.trim();
    if (photoUrl.isEmpty) {
      photoUrl = _imageService.getDefaultPhoto(networkName);
    }

    final String availableStalls = '$availableConnectors/$totalConnectors';
    final String id = widget.initialCharger?.id ?? 'charger_${DateTime.now().millisecondsSinceEpoch}';

    final List<String> connectorTypesList = _connectors.map((c) => c.type).toSet().toList();
    final List<String> amenitiesList = _amenitiesController.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final MapMarkerModel charger = MapMarkerModel(
      id: id,
      title: _nameController.text.trim(),
      description: _descriptionController.text.trim().isNotEmpty
          ? _descriptionController.text.trim()
          : _addressController.text.trim(),
      latitude: lat,
      longitude: lng,
      type: MarkerType.station,
      network: networkName,
      rating: widget.initialCharger?.rating ?? 4.8,
      power: powerString,
      availableStalls: availableStalls,
      status: computedStationStatus,
      photoUrl: photoUrl,
      address: _addressController.text.trim(),
      openStatus: computedStationStatus == MarkerStatus.offline ? 'Offline' : 'Open',
      price: priceString,
      connectorCount: totalConnectors,
      connectors: connectorTypesList,
      powerType: powerType,
      openingHours: _openingHoursController.text.trim(),
      source: _isVerified ? 'evhub_verified' : 'partner_submitted',
      ownerId: widget.initialCharger?.ownerId ?? user.id,
      createdBy: widget.initialCharger?.createdBy ?? user.name,
      verificationStatus: _isVerified ? 'approved' : 'pending',
      isVerified: _isVerified,
      phoneNumber: _phoneController.text.trim(),
      website: _websiteController.text.trim(),
      city: _cityController.text.trim(),
      state: _stateController.text.trim(),
      country: _countryController.text.trim(),
      amenities: amenitiesList,
      createdAt: widget.initialCharger?.createdAt ?? FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    );

    final provider = context.read<AdminChargerProvider>();
    final bool success = widget.initialCharger == null
        ? await provider.createCharger(charger, user)
        : await provider.updateCharger(charger, user);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.initialCharger == null
              ? 'Charger added successfully!'
              : 'Charger updated successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user ?? UserModel.guest();
    final isEditing = widget.initialCharger != null;
    final adminProvider = context.watch<AdminChargerProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          isEditing ? 'Edit EV Charger' : 'Add New EV Charger',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Mode Header Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.primary),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.admin_panel_settings_rounded, color: AppColors.primary, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'Admin Charger Management System',
                      style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ==========================================
              // SECTION 1 — BASIC INFORMATION
              // ==========================================
              _buildSectionHeader('SECTION 1 — Basic Information', HugeIcons.strokeRoundedFlash),
              const SizedBox(height: 12),
              GlassContainer(
                padding: const EdgeInsets.all(20),
                borderRadius: 20,
                child: Column(
                  children: [
                    _buildTextField(
                      controller: _nameController,
                      label: 'Charger Name *',
                      hint: 'e.g. Tata Power EV Station - Aerocity',
                      validator: (val) => val == null || val.trim().isEmpty ? 'Charger name is required' : null,
                    ),
                    const SizedBox(height: 16),

                    // Network Dropdown & Custom Network Field
                    DropdownButtonFormField<String>(
                      value: _selectedNetwork,
                      dropdownColor: AppColors.card,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration('Network *', 'Select network'),
                      items: _networkOptions.map((net) {
                        return DropdownMenuItem(value: net, child: Text(net));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedNetwork = val;
                            _isCustomNetwork = val == 'Other';
                          });
                        }
                      },
                    ),

                    if (_isCustomNetwork) ...[
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _customNetworkController,
                        label: 'Custom Network Name *',
                        hint: 'e.g. Acme ChargeNet',
                        validator: (val) => _isCustomNetwork && (val == null || val.trim().isEmpty) ? 'Please enter custom network name' : null,
                      ),
                    ],
                    const SizedBox(height: 16),

                    _buildTextField(
                      controller: _addressController,
                      label: 'Address *',
                      hint: 'Full street address or landmark',
                      maxLines: 2,
                      validator: (val) => val == null || val.trim().isEmpty ? 'Address is required' : null,
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _cityController,
                            label: 'City',
                            hint: 'e.g. New Delhi',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField(
                            controller: _stateController,
                            label: 'State',
                            hint: 'e.g. Delhi',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    _buildTextField(
                      controller: _countryController,
                      label: 'Country',
                      hint: 'e.g. India',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ==========================================
              // SECTION 2 — LOCATION
              // ==========================================
              _buildSectionHeader('SECTION 2 — Location & Coordinates', HugeIcons.strokeRoundedMapsLocation01),
              const SizedBox(height: 12),
              GlassContainer(
                padding: const EdgeInsets.all(20),
                borderRadius: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickLocationOnMap,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(color: AppColors.primary),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            icon: const HugeIcon(icon: HugeIcons.strokeRoundedMapsLocation01, color: AppColors.primary, size: 18),
                            label: const Text('Pick on Map', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isLocating ? null : _useCurrentGpsLocation,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.secondary,
                              side: const BorderSide(color: AppColors.secondary),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            icon: _isLocating
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.secondary))
                                : const HugeIcon(icon: HugeIcons.strokeRoundedGps01, color: AppColors.secondary, size: 18),
                            label: const Text('Use GPS Location', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _latController,
                            label: 'Latitude *',
                            hint: '28.6304',
                            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) return 'Required';
                              final d = double.tryParse(val.trim());
                              if (d == null || d < -90.0 || d > 90.0) return 'Invalid lat';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField(
                            controller: _lngController,
                            label: 'Longitude *',
                            hint: '77.2177',
                            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) return 'Required';
                              final d = double.tryParse(val.trim());
                              if (d == null || d < -180.0 || d > 180.0) return 'Invalid lng';
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          const HugeIcon(icon: HugeIcons.strokeRoundedInformationCircle, color: AppColors.primary, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _latController.text.isNotEmpty && _lngController.text.isNotEmpty
                                  ? 'Verified GeoPoint: GeoPoint(${_latController.text}, ${_lngController.text})'
                                  : 'Location coordinates must be verified before saving.',
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ==========================================
              // SECTION 3 — CONNECTORS
              // ==========================================
              _buildSectionHeader('SECTION 3 — Connectors & Plugs', HugeIcons.strokeRoundedPlug01),
              const SizedBox(height: 12),
              GlassContainer(
                padding: const EdgeInsets.all(20),
                borderRadius: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total Connectors: ${_connectors.length}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () {
                            setState(() {
                              _connectors.add(ConnectorEntry(
                                type: 'CCS2',
                                powerKw: 60.0,
                                status: MarkerStatus.available,
                                pricePerKwh: 21.0,
                              ));
                            });
                          },
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('+ Add Connector', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _connectors.length,
                      separatorBuilder: (ctx, idx) => const SizedBox(height: 12),
                      itemBuilder: (ctx, index) {
                        final item = _connectors[index];
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Connector #${index + 1}',
                                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  if (_connectors.length > 1)
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: AppColors.danger, size: 18),
                                      onPressed: () {
                                        setState(() {
                                          _connectors.removeAt(index);
                                        });
                                      },
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              Row(
                                children: [
                                  // Connector Type Dropdown
                                  Expanded(
                                    flex: 3,
                                    child: DropdownButtonFormField<String>(
                                      value: _connectorTypeOptions.contains(item.type) ? item.type : 'Other',
                                      dropdownColor: AppColors.card,
                                      style: const TextStyle(color: Colors.white, fontSize: 13),
                                      decoration: _inputDecoration('Type', 'Type'),
                                      items: _connectorTypeOptions.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                                      onChanged: (val) {
                                        if (val != null) setState(() => item.type = val);
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  // Max Power kW
                                  Expanded(
                                    flex: 2,
                                    child: TextFormField(
                                      initialValue: item.powerKw.toStringAsFixed(0),
                                      keyboardType: TextInputType.number,
                                      style: const TextStyle(color: Colors.white, fontSize: 13),
                                      decoration: _inputDecoration('Power kW', '60'),
                                      onChanged: (val) {
                                        item.powerKw = double.tryParse(val) ?? item.powerKw;
                                        setState(() {});
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  // Status Dropdown
                                  Expanded(
                                    flex: 3,
                                    child: DropdownButtonFormField<MarkerStatus>(
                                      value: item.status,
                                      dropdownColor: AppColors.card,
                                      style: const TextStyle(color: Colors.white, fontSize: 12),
                                      decoration: _inputDecoration('Status', 'Status'),
                                      items: const [
                                        DropdownMenuItem(value: MarkerStatus.available, child: Text('⚡ Available')),
                                        DropdownMenuItem(value: MarkerStatus.busy, child: Text('⏳ Busy')),
                                        DropdownMenuItem(value: MarkerStatus.offline, child: Text('🔴 Offline')),
                                        DropdownMenuItem(value: MarkerStatus.unknown, child: Text('❓ Unknown')),
                                      ],
                                      onChanged: (val) {
                                        if (val != null) setState(() => item.status = val);
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              // Price per kWh field
                              TextFormField(
                                initialValue: item.pricePerKwh.toStringAsFixed(0),
                                keyboardType: TextInputType.number,
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                                decoration: _inputDecoration('Price per kWh (₹)', '21'),
                                onChanged: (val) {
                                  item.pricePerKwh = double.tryParse(val) ?? item.pricePerKwh;
                                  setState(() {});
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),

                    // Connector Stats Summary Box
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatItem('Total', '${_connectors.length}', Colors.white),
                          _buildStatItem('Available', '${_connectors.where((c) => c.status == MarkerStatus.available).length}', AppColors.secondary),
                          _buildStatItem('Occupied/Busy', '${_connectors.where((c) => c.status == MarkerStatus.busy).length}', AppColors.warning),
                          _buildStatItem('Offline', '${_connectors.where((c) => c.status == MarkerStatus.offline).length}', AppColors.danger),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ==========================================
              // SECTION 4 — CHARGER DETAILS
              // ==========================================
              _buildSectionHeader('SECTION 4 — Charger Details & Amenities', HugeIcons.strokeRoundedImage01),
              const SizedBox(height: 12),
              GlassContainer(
                padding: const EdgeInsets.all(20),
                borderRadius: 20,
                child: Column(
                  children: [
                    _buildTextField(
                      controller: _openingHoursController,
                      label: 'Opening Hours',
                      hint: 'e.g. 24 Hours or 08:00 AM - 10:00 PM',
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _phoneController,
                            label: 'Phone Number',
                            hint: '+91 1800-123-4567',
                            keyboardType: TextInputType.phone,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField(
                            controller: _websiteController,
                            label: 'Website',
                            hint: 'https://tatapower.com',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    _buildTextField(
                      controller: _amenitiesController,
                      label: 'Amenities (Comma separated)',
                      hint: 'e.g. Restroom, Café, Wifi, Shopping Mall',
                    ),
                    const SizedBox(height: 16),

                    _buildTextField(
                      controller: _imageUrlController,
                      label: 'Image URL',
                      hint: 'https://example.com/charger.jpg',
                    ),
                    const SizedBox(height: 16),

                    _buildTextField(
                      controller: _descriptionController,
                      label: 'Charger Description',
                      hint: 'Location directions, parking instructions or notes',
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ==========================================
              // SECTION 5 — VERIFICATION
              // ==========================================
              _buildSectionHeader('SECTION 5 — Verification Status', HugeIcons.strokeRoundedCheckmarkBadge01),
              const SizedBox(height: 12),
              GlassContainer(
                padding: const EdgeInsets.all(20),
                borderRadius: 20,
                child: Row(
                  children: [
                    Checkbox(
                      value: _isVerified,
                      activeColor: AppColors.secondary,
                      onChanged: (val) {
                        setState(() {
                          _isVerified = val ?? true;
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            '[✓] Mark as EVHub Verified',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Saves charger as source = "evhub_verified" & isVerified = true with server timestamps.',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Submit Button
              PremiumButton(
                text: isEditing ? 'Update Charger Details' : 'Create EVHub Verified Charger',
                icon: isEditing ? Icons.save_rounded : Icons.check_circle_outline,
                isLoading: adminProvider.isLoading,
                onPressed: () => _submitForm(user),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, List<List<dynamic>> icon) {
    return Row(
      children: [
        HugeIcon(icon: icon, color: AppColors.primary, size: 20),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10)),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      validator: validator,
      decoration: _inputDecoration(label, hint),
    );
  }

  InputDecoration _inputDecoration(String label, String hint) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
      hintText: hint,
      hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12),
      filled: true,
      fillColor: Colors.white.withOpacity(0.04),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.danger),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }
}
