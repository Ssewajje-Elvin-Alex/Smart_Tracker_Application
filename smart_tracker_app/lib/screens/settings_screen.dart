import 'package:flutter/material.dart';
import '../services/api_services.dart';

/// Lets the guardian set the phone number the bracelet texts/calls, and
/// the geofence center + radius. Saved settings are written to the
/// backend; the ESP32 polls /api/config/ and applies them on its own.
class SettingsScreen extends StatefulWidget {
  // Optional: pass the tracker's last known position so the guardian can
  // one-tap "use current tracker location" as the geofence center instead
  // of typing coordinates by hand.
  final double? currentTrackerLatitude;
  final double? currentTrackerLongitude;

  const SettingsScreen({
    super.key,
    this.currentTrackerLatitude,
    this.currentTrackerLongitude,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();

  final _phoneController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  final _radiusController = TextEditingController();

  bool loading = true;
  bool saving = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _radiusController.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    setState(() {
      loading = true;
      errorMessage = null;
    });

    try {
      final config = await ApiService.getDeviceConfig();
      _phoneController.text = config["guardian_phone"] ?? "";
      _latController.text = config["geofence_latitude"].toString();
      _lngController.text = config["geofence_longitude"].toString();
      _radiusController.text = config["geofence_radius_m"].toString();
    } catch (e) {
      setState(() => errorMessage = e.toString());
    }

    setState(() => loading = false);
  }

  void _useCurrentTrackerLocation() {
    if (widget.currentTrackerLatitude == null ||
        widget.currentTrackerLongitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No tracker location available yet.")),
      );
      return;
    }

    setState(() {
      _latController.text = widget.currentTrackerLatitude!.toStringAsFixed(6);
      _lngController.text = widget.currentTrackerLongitude!.toStringAsFixed(6);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => saving = true);

    try {
      await ApiService.updateDeviceConfig(
        guardianPhone: _phoneController.text.trim(),
        geofenceLatitude: double.parse(_latController.text.trim()),
        geofenceLongitude: double.parse(_lngController.text.trim()),
        geofenceRadiusM: double.parse(_radiusController.text.trim()),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Settings saved.")),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    }

    if (mounted) setState(() => saving = false);
  }

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) return "Required";
    return null;
  }

  String? _numberValidator(String? value) {
    if (value == null || value.trim().isEmpty) return "Required";
    if (double.tryParse(value.trim()) == null) return "Enter a number";
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Device Settings")),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          "Couldn't load current settings: $errorMessage",
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    const Text(
                      "Guardian phone number",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "The bracelet texts and can be called back on this number.",
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: "+2567XXXXXXXX",
                      ),
                      validator: _requiredValidator,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      "Safe zone (geofence)",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "Center point and radius the bracelet is allowed to stay within.",
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _latController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true, signed: true),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: "Latitude",
                      ),
                      validator: _numberValidator,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _lngController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true, signed: true),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: "Longitude",
                      ),
                      validator: _numberValidator,
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _useCurrentTrackerLocation,
                      icon: const Icon(Icons.my_location),
                      label: const Text("Use current tracker location"),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _radiusController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: "Radius (metres)",
                      ),
                      validator: _numberValidator,
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: saving ? null : _save,
                        child: Text(saving ? "Saving..." : "Save settings"),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
