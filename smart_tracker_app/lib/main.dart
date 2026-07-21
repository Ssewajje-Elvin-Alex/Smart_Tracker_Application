import 'dart:async';
import 'splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'screens/settings_screen.dart';
import 'services/api_services.dart';

const Map<String, String> eventTypeLabels = {
  "LOCATION_UPDATE": "Live location update",
  "EMERGENCY_BUTTON": "Emergency button pressed",
  "GEOFENCE_EXIT": "Left safe zone",
  "GEOFENCE_RETURN": "Returned to safe zone",
  "BACKEND_TEST": "Test ping",
};

void main() {
  runApp(const SmartTrackerApp());
}

class SmartTrackerApp extends StatelessWidget {
  const SmartTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Smart Tracker",
      theme: ThemeData(primarySwatch: Colors.blue),
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

  bool loading = false;
  String? errorMessage;
  Timer? pollTimer;

  GoogleMapController? mapController;
  LatLng currentPosition = const LatLng(0.332201, 32.570472);

  String get trackerSimNumber =>
      (deviceConfig?["device_phone"] ?? "").toString().trim();

  DateTime? get latestTimestamp {
    final value = locationData?["timestamp"]?.toString();
    return value == null ? null : DateTime.tryParse(value)?.toLocal();
  }

  bool get dataIsStale {
    final timestamp = latestTimestamp;
    if (timestamp == null) return true;
    return DateTime.now().difference(timestamp) > const Duration(minutes: 2);
  }

  @override
  void initState() {
    super.initState();
    _loadInitialData();

    // Polling is used until Firebase push/realtime delivery is added.
    pollTimer = Timer.periodic(
      const Duration(seconds: 15),
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

  Future<void> getLocation({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() => loading = true);
    }

    try {
      final data = await ApiService.getLatestLocation();
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
    } catch (e) {
      if (!mounted) return;

      setState(() => errorMessage = e.toString());

      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    } finally {
      if (!silent && mounted) {
        setState(() => loading = false);
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

  @override
  Widget build(BuildContext context) {
    final bool emergency = locationData?["emergency"] ?? false;
    final String eventType = locationData?["event_type"] ?? "";
    final String eventLabel = eventTypeLabels[eventType] ?? "No data yet";

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
                    "Smart Tracker", style: TextStyle(fontSize: 22,fontWeight: FontWeight.bold,),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
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
                      Text(
                        eventLabel,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
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
                      onPressed: loading ? null : () => getLocation(),
                      icon: const Icon(Icons.refresh),
                      label: Text(loading ? "Loading..." : "Refresh"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.hearing, color: Colors.white),
                      label: const Text(
                        "Listen Live",
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
