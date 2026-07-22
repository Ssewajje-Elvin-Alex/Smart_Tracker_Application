import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'screens/settings_screen.dart';
import 'services/alert_service.dart';
import 'services/api_services.dart';
import 'splash_screen.dart';

const Map<String, String> eventTypeLabels = {
  "LOCATION_UPDATE": "Live location update",
  "EMERGENCY_BUTTON": "Emergency button pressed",
  "GEOFENCE_EXIT": "Left safe zone",
  "GEOFENCE_RETURN": "Returned to safe zone",
  "BACKEND_TEST": "Test ping",
};

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AlertService.instance.initialize();
  runApp(const SmartTrackerApp());
}

class SmartTrackerApp extends StatelessWidget {
  const SmartTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Smart Tracker",
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}

class TrackerHome extends StatefulWidget {
  const TrackerHome({super.key});

  @override
  State<TrackerHome> createState() => _TrackerHomeState();
}

class _TrackerHomeState extends State<TrackerHome> {
  Map<String, dynamic>? locationData;
  Map<String, dynamic>? deviceConfig;
  Map<String, dynamic>? activeAlertData;

  bool loading = false;
  bool requestingFreshLocation = false;
  bool alertDialogOpen = false;
  String? activeAlertKind;
  String? errorMessage;
  Timer? pollTimer;

  GoogleMapController? mapController;
  LatLng currentPosition = const LatLng(0.332201, 32.570472);

  String get trackerSimNumber =>
      (deviceConfig?["device_phone"] ?? "").toString().trim();

  int get batteryLevel {
    final rawValue = locationData?["battery_level"];
    final parsed = int.tryParse(rawValue?.toString() ?? "");
    return (parsed ?? 0).clamp(0, 100).toInt();
  }

  DateTime? get latestTimestamp {
    final value = locationData?["timestamp"]?.toString();
    return value == null ? null : DateTime.tryParse(value)?.toLocal();
  }

  bool get dataIsStale {
    final timestamp = latestTimestamp;
    if (timestamp == null) return true;
    return DateTime.now().difference(timestamp) > const Duration(minutes: 2);
  }

  bool get emergencyButtonActive =>
      locationData?["emergency_active"] == true ||
      locationData?["event_type"] == "EMERGENCY_BUTTON";

  bool get geofenceOutside =>
      locationData?["geofence_outside"] == true ||
      locationData?["event_type"] == "GEOFENCE_EXIT";

  @override
  void initState() {
    super.initState();
    _loadInitialData();

    // Fast polling keeps the dashboard responsive while Firebase push is not
    // yet configured. True terminated-app delivery still requires FCM.
    pollTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => getLocation(silent: true),
    );
  }

  Future<void> _loadInitialData() async {
    await Future.wait([
      getLocation(),
      getDeviceConfig(silent: true),
    ]);
  }

  @override
  void dispose() {
    pollTimer?.cancel();
    mapController?.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>?> getLocation({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() => loading = true);
    }

    try {
      final data = await ApiService.getLatestLocation();
      await _applyLocationData(data);
      return data;
    } catch (e) {
      if (!mounted) return null;

      setState(() => errorMessage = e.toString());

      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
      return null;
    } finally {
      if (!silent && mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> _applyLocationData(Map<String, dynamic> data) async {
    final latitude = double.parse(data["latitude"].toString());
    final longitude = double.parse(data["longitude"].toString());

    if (!mounted) return;

    setState(() {
      locationData = data;
      errorMessage = null;
      currentPosition = LatLng(latitude, longitude);
    });

    await mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(currentPosition, 15),
    );

    await _processEmergencyState(data);
  }

  Future<void> _processEmergencyState(Map<String, dynamic> data) async {
    final bool emergencyActive = data["emergency_active"] == true ||
        data["event_type"] == "EMERGENCY_BUTTON";
    final bool outside = data["geofence_outside"] == true ||
        data["event_type"] == "GEOFENCE_EXIT";

    if (!emergencyActive) {
      await AlertService.instance.resetAcknowledgement("EMERGENCY");
    }
    if (!outside) {
      await AlertService.instance.resetAcknowledgement("GEOFENCE");
    }

    String? kind;
    String? title;
    String? message;

    if (emergencyActive) {
      kind = "EMERGENCY";
      title = "EMERGENCY BUTTON ACTIVATED";
      message =
          "The wearer pressed the Smart Guardian emergency button. Check the location immediately.";
    } else if (outside) {
      kind = "GEOFENCE";
      title = "SAFE-ZONE ALERT";
      message =
          "The Smart Guardian device has moved outside the configured safe zone.";
    }

    if (kind == null) return;

    final acknowledged = await AlertService.instance.isAcknowledged(kind);

    if (acknowledged) {
      if (mounted && activeAlertKind == kind) {
        setState(() {
          activeAlertKind = null;
          activeAlertData = null;
        });
      }
      return;
    }

    if (activeAlertKind == kind || !mounted) return;

    setState(() {
      activeAlertKind = kind;
      activeAlertData = data;
    });

    await AlertService.instance.startAlarm(
      alertKind: kind,
      title: title!,
      body: message!,
    );

    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showEmergencyDialog(title!, message!);
      });
    }
  }

  Future<void> _showEmergencyDialog(String title, String message) async {
    if (!mounted || alertDialogOpen || activeAlertData == null) return;

    alertDialogOpen = true;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 48),
          title: Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Text(
                "Lat ${currentPosition.latitude.toStringAsFixed(6)}, "
                "Lon ${currentPosition.longitude.toStringAsFixed(6)}",
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton.icon(
              onPressed: openCurrentLocationInMaps,
              icon: const Icon(Icons.map),
              label: const Text("Open Maps"),
            ),
            FilledButton.icon(
              onPressed: () async {
                await acknowledgeActiveAlert();
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
              },
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              icon: const Icon(Icons.notifications_off),
              label: const Text("Stop alarm"),
            ),
          ],
        );
      },
    );

    alertDialogOpen = false;
  }

  Future<void> acknowledgeActiveAlert() async {
    final kind = activeAlertKind;
    if (kind == null) return;

    // When both emergency states are active, one acknowledgement silences the
    // current alarm episode for both until the device reports them cleared.
    if (emergencyButtonActive) {
      await AlertService.instance.acknowledge("EMERGENCY");
    }
    if (geofenceOutside) {
      await AlertService.instance.acknowledge("GEOFENCE");
    }

    await AlertService.instance.stopAlarm();

    if (mounted) {
      setState(() {
        activeAlertKind = null;
        activeAlertData = null;
      });
    }
  }

  Future<void> requestMostRecentLocation() async {
    if (requestingFreshLocation) return;

    setState(() => requestingFreshLocation = true);

    try {
      final request = await ApiService.requestLocationRefresh();
      final requestId = int.parse(request["location_request_id"].toString());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Fresh location requested from the ESP32."),
          ),
        );
      }

      // Wait for a new tracker POST that carries this exact request ID.
      for (int attempt = 0; attempt < 15; attempt++) {
        await Future<void>.delayed(const Duration(seconds: 2));
        final data = await ApiService.getLatestLocation();
        await _applyLocationData(data);

        final responseRequestId =
            int.tryParse(data["location_request_id"]?.toString() ?? "");

        if (responseRequestId == requestId) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Fresh device location received.")),
            );
          }
          return;
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "The ESP32 did not answer within 30 seconds. Check its Wi-Fi and GPS.",
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Refresh request failed: $e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() => requestingFreshLocation = false);
      }
    }
  }

  Future<void> getDeviceConfig({bool silent = false}) async {
    try {
      final config = await ApiService.getDeviceConfig();
      if (!mounted) return;
      setState(() => deviceConfig = config);
    } catch (e) {
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Could not load device settings: $e")),
        );
      }
    }
  }

  Future<void> callTrackerDevice() async {
    final number = trackerSimNumber;

    if (number.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Set the tracker SIM number in Device Settings first.",
          ),
        ),
      );
      return;
    }

    final uri = Uri(scheme: "tel", path: number);

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not open the phone dialer.")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Could not start the call: $e")),
        );
      }
    }
  }

  Future<void> openCurrentLocationInMaps() async {
    final uri = Uri.parse(
      "https://www.google.com/maps/search/?api=1&query="
      "${currentPosition.latitude},${currentPosition.longitude}",
    );

    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not open Google Maps.")),
      );
    }
  }

  Future<void> openSettings() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          currentTrackerLatitude: currentPosition.latitude,
          currentTrackerLongitude: currentPosition.longitude,
        ),
      ),
    );

    if (saved == true) {
      await getDeviceConfig();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Settings saved. The ESP32 should receive them within about 5 seconds.",
            ),
          ),
        );
      }
    }
  }

  String formatLastUpdate() {
    final timestamp = latestTimestamp;
    if (timestamp == null) return "No update received";

    final age = DateTime.now().difference(timestamp);
    if (age.inSeconds < 60) return "Updated ${age.inSeconds}s ago";
    if (age.inMinutes < 60) return "Updated ${age.inMinutes}m ago";
    return "Updated ${age.inHours}h ago";
  }

  IconData batteryIconForLevel(int level) {
    if (level >= 90) return Icons.battery_full;
    if (level >= 60) return Icons.battery_5_bar;
    if (level >= 30) return Icons.battery_3_bar;
    if (level > 10) return Icons.battery_1_bar;
    return Icons.battery_alert;
  }

  @override
  Widget build(BuildContext context) {
    final bool emergency = locationData?["emergency"] ?? false;
    final String eventType = locationData?["event_type"] ?? "";

    final String eventLabel = emergencyButtonActive
        ? "Emergency button active"
        : geofenceOutside
            ? "Device outside safe zone"
            : eventTypeLabels[eventType] ?? "No data yet";

    final String statusText = locationData == null
        ? "NO DATA"
        : dataIsStale
            ? "STALE"
            : emergency
                ? "EMERGENCY"
                : "SAFE";

    final Color statusColor = locationData == null || dataIsStale
        ? Colors.orange
        : emergency
            ? Colors.red
            : Colors.green;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Smart Tracker",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        batteryIconForLevel(batteryLevel),
                        size: 19,
                        color: batteryLevel <= 15 ? Colors.red : Colors.grey[700],
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          statusText,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.settings),
                        onPressed: openSettings,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (activeAlertData != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  border: Border.all(color: Colors.red, width: 2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_rounded, color: Colors.red, size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "ACTIVE EMERGENCY ALERT",
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            activeAlertKind == "EMERGENCY"
                                ? "Emergency button pressed"
                                : "Device left the safe zone",
                          ),
                        ],
                      ),
                    ),
                    FilledButton(
                      onPressed: acknowledgeActiveAlert,
                      style: FilledButton.styleFrom(backgroundColor: Colors.red),
                      child: const Text("Stop"),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(16),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: currentPosition,
                    zoom: 15,
                  ),
                  onMapCreated: (controller) => mapController = controller,
                  markers: {
                    Marker(
                      markerId: const MarkerId("tracker"),
                      position: currentPosition,
                      infoWindow: const InfoWindow(
                        title: "Smart Guardian device",
                        snippet: "Latest reported location",
                      ),
                    ),
                  },
                  myLocationEnabled: false,
                  zoomControlsEnabled: true,
                ),
              ),
            ),
            if (errorMessage != null && locationData == null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            if (locationData != null)
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                child: Padding(
                  padding: const EdgeInsets.all(15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              eventLabel,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: emergency ? Colors.red : null,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: "Open current location in Google Maps",
                            onPressed: openCurrentLocationInMaps,
                            icon: const Icon(Icons.open_in_new),
                          ),
                        ],
                      ),
                      Text("Latitude: ${locationData!['latitude']}"),
                      Text("Longitude: ${locationData!['longitude']}"),
                      if (locationData!["distance_metres"] != null)
                        Text(
                          "Distance from safe-zone centre: "
                          "${locationData!['distance_metres']} m",
                        ),
                      if (locationData!["satellites"] != null)
                        Text("Satellites: ${locationData!['satellites']}"),
                      Text("Battery: ${locationData!['battery_level']}%"),
                      const SizedBox(height: 4),
                      Text(
                        formatLastUpdate(),
                        style: TextStyle(
                          color: dataIsStale ? Colors.orange : Colors.grey[700],
                          fontWeight:
                              dataIsStale ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: requestingFreshLocation
                          ? null
                          : requestMostRecentLocation,
                      icon: requestingFreshLocation
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh),
                      label: Text(
                        requestingFreshLocation
                            ? "Requesting..."
                            : "Refresh",
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.phone, color: Colors.white),
                      label: const Text(
                        "Call Device",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: callTrackerDevice,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
