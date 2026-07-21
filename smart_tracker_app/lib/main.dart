import 'dart:async';
import 'package:flutter/material.dart';
import 'services/api_services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'screens/settings_screen.dart';

// Must match PHONE_NUMBER in the ESP32 sketch — this is who the bracelet
// itself already texts on emergency/geofence events.
const String guardianContactNumber = "+256748649671";

const Map<String, String> eventTypeLabels = {
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
      home: const TrackerHome(),
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
  bool loading = false;
  String? errorMessage;
  Timer? pollTimer;

  GoogleMapController? mapController;

  LatLng currentPosition = const LatLng(0.332201, 32.570472);

  @override
  void initState() {
    super.initState();
    getLocation();
    // Auto-refresh so a real emergency shows up without the user tapping
    // anything.
    pollTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => getLocation(silent: true),
    );
  }

  @override
  void dispose() {
    pollTimer?.cancel();
    super.dispose();
  }

  Future<void> getLocation({bool silent = false}) async {
    if (!silent) {
      setState(() => loading = true);
    }

    try {
      final data = await ApiService.getLatestLocation();
      setState(() {
        locationData = data;
        errorMessage = null;
        currentPosition = LatLng(
          double.parse(data["latitude"].toString()),
          double.parse(data["longitude"].toString()),
        );
      });

      mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(currentPosition, 15),
      );
    } catch (e) {
      setState(() => errorMessage = e.toString());

      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    }

    if (!silent) {
      setState(() => loading = false);
    }
  }

  Future<void> callGuardianContact() async {
    final uri = Uri(scheme: "tel", path: guardianContactNumber);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not open the phone dialer.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool emergency = locationData?["emergency"] ?? false;
    final String eventType = locationData?["event_type"] ?? "";
    final String eventLabel = eventTypeLabels[eventType] ?? "No data yet";

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
                  const Row(
                    children: [
                      Icon(Icons.shield, color: Colors.blue, size: 30),
                      SizedBox(width: 8),
                      Text(
                        "Smart Tracker",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
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
                          color: emergency ? Colors.red[100] : Colors.green[100],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          emergency ? "EMERGENCY" : "SAFE",
                          style: TextStyle(
                            color: emergency ? Colors.red : Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.settings),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => SettingsScreen(
                                currentTrackerLatitude: currentPosition.latitude,
                                currentTrackerLongitude: currentPosition.longitude,
                              ),
                            ),
                          );
                        },
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
                        title: "Guardian Bracelet",
                        snippet: "Current location",
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
                      if (locationData!['distance_metres'] != null)
                        Text(
                          "Distance from safe zone: "
                          "${locationData!['distance_metres']} m",
                        ),
                      if (locationData!['satellites'] != null)
                        Text("Satellites: ${locationData!['satellites']}"),
                      Text("Battery: ${locationData!['battery_level']}%"),
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
                      icon: const Icon(Icons.call, color: Colors.white),
                      label: const Text(
                        "Call Guardian",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: callGuardianContact,
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
