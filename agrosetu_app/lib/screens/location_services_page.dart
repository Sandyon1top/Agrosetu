import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../l10n/app_translations.dart';
import '../services/user_preferences_service.dart';

class LocationServicesPage extends StatefulWidget {
  const LocationServicesPage({super.key});

  @override
  State<LocationServicesPage> createState() => _LocationServicesPageState();
}

class _LocationServicesPageState extends State<LocationServicesPage> {
  bool _enabled = false;
  bool _isLoading = true;
  bool _osLocationEnabled = false;
  LocationPermission _permission = LocationPermission.denied;
  Position? _lastPosition;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _refreshStatus();
  }

  Future<void> _refreshStatus() async {
    setState(() => _isLoading = true);
    final prefs = await UserPreferencesService.load();
    final osEnabled = await Geolocator.isLocationServiceEnabled();
    final perm = await Geolocator.checkPermission();
    if (!mounted) return;
    setState(() {
      _enabled = prefs.locationServicesEnabled;
      _osLocationEnabled = osEnabled;
      _permission = perm;
      _isLoading = false;
    });
  }

  Future<void> _toggle(bool turnOn) async {
    if (!turnOn) {
      await UserPreferencesService.update(locationServicesEnabled: false);
      if (!mounted) return;
      setState(() {
        _enabled = false;
        _statusMessage = 'loc.turned_off'.tr;
      });
      return;
    }

    // Turning on: validate OS-level service + permission first.
    final osEnabled = await Geolocator.isLocationServiceEnabled();
    if (!osEnabled) {
      _showSnack('loc.enable_first'.tr);
      await Geolocator.openLocationSettings();
      return;
    }

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }

    if (perm == LocationPermission.deniedForever) {
      _showSnack('loc.denied_forever'.tr);
      await _safeOpenAppSettings();
      return;
    }
    if (perm == LocationPermission.denied) {
      _showSnack('loc.denied'.tr);
      return;
    }

    Position? pos;
    try {
      pos = await Geolocator.getCurrentPosition(
        // ignore: deprecated_member_use
        desiredAccuracy: LocationAccuracy.medium,
      ).timeout(const Duration(seconds: 10));
    } catch (e) {
      _showSnack('${'loc.cant_get'.tr} $e');
    }

    await UserPreferencesService.update(locationServicesEnabled: true);
    if (!mounted) return;
    setState(() {
      _enabled = true;
      _permission = perm;
      _lastPosition = pos;
      _statusMessage = pos != null
          ? 'loc.enabled_msg'.tr
          : 'loc.enabled_no_fix'.tr;
    });
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _safeOpenAppSettings() async {
    try {
      await openAppSettings();
    } on MissingPluginException {
      _showSnack('loc.open_settings_hint'.tr);
    } catch (e) {
      _showSnack('${'loc.cant_get'.tr} $e');
    }
  }

  String _permLabel(LocationPermission p) {
    switch (p) {
      case LocationPermission.always:
        return 'Always';
      case LocationPermission.whileInUse:
        return 'While in use';
      case LocationPermission.denied:
        return 'Denied';
      case LocationPermission.deniedForever:
        return 'Denied permanently';
      case LocationPermission.unableToDetermine:
        return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Iconsax.arrow_left, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'loc.title'.tr,
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Iconsax.refresh, color: Colors.black),
            onPressed: _refreshStatus,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildToggleCard(),
                  const SizedBox(height: 16),
                  _buildStatusCard(),
                  if (_lastPosition != null) ...[
                    const SizedBox(height: 16),
                    _buildLastFixCard(),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    'loc.help_text'.tr,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildToggleCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Iconsax.location,
              color: Color(0xFF2E7D32),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'loc.features'.tr,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  _enabled ? 'settings.on'.tr : 'settings.off'.tr,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: _enabled,
            onChanged: _toggle,
            activeThumbColor: const Color(0xFF2E7D32),
            activeTrackColor: const Color(0xFF2E7D32).withValues(alpha: 0.5),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _statusRow('loc.device'.tr, _osLocationEnabled ? 'loc.enabled'.tr : 'loc.disabled'.tr,
              _osLocationEnabled ? Colors.green : Colors.red),
          const Divider(height: 16),
          _statusRow('loc.permission'.tr, _permLabel(_permission),
              _permission == LocationPermission.always ||
                      _permission == LocationPermission.whileInUse
                  ? Colors.green
                  : Colors.orange),
          if (_statusMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              _statusMessage!,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey.shade700,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Geolocator.openLocationSettings(),
                  icon: const Icon(Iconsax.setting_2, size: 16),
                  label: Text(
                    'loc.device_settings'.tr,
                    style: GoogleFonts.poppins(fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _safeOpenAppSettings,
                  icon: const Icon(Iconsax.shield_tick, size: 16),
                  label: Text(
                    'loc.app_permissions'.tr,
                    style: GoogleFonts.poppins(fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusRow(String label, String value, Color color) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Colors.grey.shade700,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLastFixCard() {
    final pos = _lastPosition!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'loc.last_position'.tr,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Lat ${pos.latitude.toStringAsFixed(5)}, Lon ${pos.longitude.toStringAsFixed(5)}',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }
}
