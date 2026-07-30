import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../models/map_marker_model.dart';

/// Factory class for generating and caching professional, high-DPI
/// EV Charging Station map markers for Google Maps.
class ChargerMarkerFactory {
  static BitmapDescriptor? _availableIcon;
  static BitmapDescriptor? _busyIcon;
  static BitmapDescriptor? _offlineIcon;
  static BitmapDescriptor? _unknownIcon;
  static BitmapDescriptor? _verifiedIcon;
  static BitmapDescriptor? _selectedIcon;
  static bool _isInitialized = false;

  /// Getters for pre-cached descriptors
  static BitmapDescriptor? get availableIcon => _availableIcon;
  static BitmapDescriptor? get busyIcon => _busyIcon;
  static BitmapDescriptor? get offlineIcon => _offlineIcon;
  static BitmapDescriptor? get unknownIcon => _unknownIcon;
  static BitmapDescriptor? get verifiedIcon => _verifiedIcon;
  static BitmapDescriptor? get selectedIcon => _selectedIcon;
  static bool get isInitialized => _isInitialized;

  /// Initializes and pre-renders all status marker icons.
  /// Call this once during app startup or map initialization.
  static Future<void> init() async {
    if (_isInitialized) return;

    _availableIcon = await createEVChargerPin(
      color: const Color(0xFF10B981), // EVHub Green
      isSelected: false,
      isVerified: false,
    );
    _busyIcon = await createEVChargerPin(
      color: const Color(0xFFF59E0B), // Amber / Busy
      isSelected: false,
      isVerified: false,
    );
    _offlineIcon = await createEVChargerPin(
      color: const Color(0xFFEF4444), // Red / Offline
      isSelected: false,
      isVerified: false,
    );
    _unknownIcon = await createEVChargerPin(
      color: const Color(0xFF6B7280), // Grey / Unknown
      isSelected: false,
      isVerified: false,
    );
    _verifiedIcon = await createEVChargerPin(
      color: const Color(0xFF10B981), // EVHub Green
      isSelected: false,
      isVerified: true,
    );
    _selectedIcon = await createEVChargerPin(
      color: const Color(0xFF3B82F6), // Electric Blue
      isSelected: true,
      isVerified: false,
    );

    _isInitialized = true;
  }

  /// Selects the appropriate cached [BitmapDescriptor] based on [charger] state.
  static BitmapDescriptor getIconForCharger(MapMarkerModel charger, {bool isSelected = false}) {
    if (isSelected) {
      return _selectedIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
    }

    if (charger.isVerified || charger.source == 'evhub_verified') {
      return _verifiedIcon ?? _availableIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
    }

    switch (charger.status) {
      case MarkerStatus.available:
        return _availableIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
      case MarkerStatus.busy:
        return _busyIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
      case MarkerStatus.offline:
        return _offlineIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
      case MarkerStatus.unknown:
        return _unknownIcon ?? _availableIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet);
    }
  }

  /// Builds a standard Google Maps [Marker] for a given [charger].
  static Marker buildMarker({
    required MapMarkerModel charger,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final icon = getIconForCharger(charger, isSelected: isSelected);

    return Marker(
      markerId: MarkerId(charger.id),
      position: LatLng(charger.latitude, charger.longitude),
      icon: icon,
      anchor: const Offset(0.5, 1.0), // Pin tip anchor at bottom center
      onTap: onTap,
    );
  }

  /// Renders a high-DPI EV charging station map pin onto a Flutter Canvas.
  static Future<BitmapDescriptor> createEVChargerPin({
    required Color color,
    bool isSelected = false,
    bool isVerified = false,
  }) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);

    // Canvas size (High-DPI 2.5x scaling for sharp crisp rendering on Web/Retina)
    final double width = isSelected ? 80.0 : 72.0;
    final double height = isSelected ? 96.0 : 86.0;
    final double cx = width / 2.0;
    final double headRadius = isSelected ? 28.0 : 24.0;
    final double cy = headRadius + (isSelected ? 6.0 : 5.0);

    // 1. Drop shadow path
    final ui.Path pinPath = ui.Path();
    pinPath.addOval(Rect.fromCircle(center: Offset(cx, cy), radius: headRadius));
    // Pointer tip extending to bottom center
    pinPath.moveTo(cx - headRadius * 0.55, cy + headRadius * 0.7);
    pinPath.lineTo(cx, height - 6.0);
    pinPath.lineTo(cx + headRadius * 0.55, cy + headRadius * 0.7);
    pinPath.close();

    // Paint drop shadow
    final Paint shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.35)
      ..maskFilter = const MaskFilter.blur(ui.BlurStyle.normal, 5.0);
    canvas.save();
    canvas.translate(0, 3.0);
    canvas.drawPath(pinPath, shadowPaint);
    canvas.restore();

    // 2. Outer Border (3px White border for high-contrast on dark & satellite maps)
    final Paint borderPaint = Paint()
      ..color = isVerified ? const Color(0xFF10B981) : Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawPath(pinPath, borderPaint);

    // 3. Inner Fill
    final ui.Path innerPath = ui.Path();
    final double innerRadius = headRadius - (isSelected ? 3.5 : 3.0);
    innerPath.addOval(Rect.fromCircle(center: Offset(cx, cy), radius: innerRadius));
    innerPath.moveTo(cx - innerRadius * 0.55, cy + innerRadius * 0.65);
    innerPath.lineTo(cx, height - 10.0);
    innerPath.lineTo(cx + innerRadius * 0.55, cy + innerRadius * 0.65);
    innerPath.close();

    final Paint fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawPath(innerPath, fillPaint);

    // 4. EV Charging Station Symbol (White)
    final Paint symbolPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // Charger Station Pillar Housing
    final double pillarW = isSelected ? 18.0 : 16.0;
    final double pillarH = isSelected ? 22.0 : 19.0;
    final Rect pillarRect = Rect.fromCenter(
      center: Offset(cx - 2.0, cy - 1.0),
      width: pillarW,
      height: pillarH,
    );
    final RRect pillarRRect = RRect.fromRectAndRadius(pillarRect, const Radius.circular(3.5));
    canvas.drawRRect(pillarRRect, symbolPaint);

    // Screen window cutout inside pillar (dark background cutout)
    final Paint screenCutoutPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final Rect screenRect = Rect.fromLTWH(
      pillarRect.left + 3.5,
      pillarRect.top + 3.5,
      pillarW - 7.0,
      4.5,
    );
    canvas.drawRRect(RRect.fromRectAndRadius(screenRect, const Radius.circular(1.5)), screenCutoutPaint);

    // Cable & Plug on the right side
    final Paint cablePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    final ui.Path cablePath = ui.Path();
    cablePath.moveTo(pillarRect.right - 1.0, cy - 2.0);
    cablePath.cubicTo(
      pillarRect.right + 7.0, cy - 2.0,
      pillarRect.right + 7.0, cy + 6.0,
      pillarRect.right + 3.0, cy + 7.0,
    );
    canvas.drawPath(cablePath, cablePaint);

    // Plug head
    final Rect plugHead = Rect.fromCenter(
      center: Offset(pillarRect.right + 3.5, cy + 9.0),
      width: 4.5,
      height: 5.5,
    );
    canvas.drawRect(plugHead, symbolPaint);

    // 5. Lightning bolt emblem in the center of pillar (cutout or drawn in status color)
    final ui.Path lightningPath = ui.Path();
    final double lCx = pillarRect.center.dx;
    final double lCy = pillarRect.center.dy + 2.5;

    lightningPath.moveTo(lCx + 1.0, lCy - 5.5);
    lightningPath.lineTo(lCx - 3.5, lCy + 0.5);
    lightningPath.lineTo(lCx - 0.5, lCy + 0.5);
    lightningPath.lineTo(lCx - 2.0, lCy + 5.5);
    lightningPath.lineTo(lCx + 3.5, lCy - 0.5);
    lightningPath.lineTo(lCx + 0.5, lCy - 0.5);
    lightningPath.close();

    canvas.drawPath(lightningPath, screenCutoutPaint);

    // 6. Verified checkmark badge if verified
    if (isVerified) {
      final Paint badgeBg = Paint()
        ..color = const Color(0xFF10B981)
        ..style = PaintingStyle.fill;
      final Paint badgeBorder = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;

      final Offset badgeCenter = Offset(cx + headRadius * 0.65, cy - headRadius * 0.65);
      canvas.drawCircle(badgeCenter, 6.5, badgeBg);
      canvas.drawCircle(badgeCenter, 6.5, badgeBorder);

      final Paint checkPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round;
      final ui.Path checkPath = ui.Path();
      checkPath.moveTo(badgeCenter.dx - 3.0, badgeCenter.dy);
      checkPath.lineTo(badgeCenter.dx - 0.8, badgeCenter.dy + 2.2);
      checkPath.lineTo(badgeCenter.dx + 3.0, badgeCenter.dy - 2.2);
      canvas.drawPath(checkPath, checkPaint);
    }

    // Convert to Image & Uint8List
    final ui.Image image = await pictureRecorder.endRecording().toImage(
      width.toInt(),
      height.toInt(),
    );
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
  }
}
