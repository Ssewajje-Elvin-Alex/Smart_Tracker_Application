import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl =
      "https://smart-tracker-a4mu.onrender.com/api";

  static const Duration requestTimeout = Duration(seconds: 25);

  static Future<Map<String, dynamic>> getLatestLocation() async {
    final response = await http
        .get(Uri.parse("$baseUrl/location/latest/"))
        .timeout(requestTimeout);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    if (response.statusCode == 404) {
      throw Exception("No tracker data received yet");
    }

    throw Exception(
      "Failed to load location (status ${response.statusCode})",
    );
  }

  static Future<Map<String, dynamic>> getDeviceConfig() async {
    final response = await http
        .get(Uri.parse("$baseUrl/config/"))
        .timeout(requestTimeout);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    throw Exception(
      "Failed to load settings (status ${response.statusCode})",
    );
  }

  static Future<Map<String, dynamic>> updateDeviceConfig({
    required String guardianPhone,
    required String devicePhone,
    required double geofenceLatitude,
    required double geofenceLongitude,
    required double geofenceRadiusM,
  }) async {
    final response = await http
        .patch(
          Uri.parse("$baseUrl/config/"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "guardian_phone": guardianPhone,
            "device_phone": devicePhone,
            "geofence_latitude": geofenceLatitude,
            "geofence_longitude": geofenceLongitude,
            "geofence_radius_m": geofenceRadiusM,
          }),
        )
        .timeout(requestTimeout);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    throw Exception(
      "Failed to save settings (status ${response.statusCode}): "
      "${response.body}",
    );
  }
}
