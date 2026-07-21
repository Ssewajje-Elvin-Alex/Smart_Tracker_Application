import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl =
      "https://smart-tracker-a4mu.onrender.com/api";
      //"http://10.177.149.48:8000/api";
      //"http://127.0.0.1:8000/api";

  static Future<Map<String, dynamic>> getLatestLocation() async {
    final response = await http.get(Uri.parse("$baseUrl/location/latest/"));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else if (response.statusCode == 404) {
      throw Exception("No tracker data received yet");
    } else {
      throw Exception(
        "Failed to load location (status ${response.statusCode})",
      );
    }
  }

  static Future<Map<String, dynamic>> getDeviceConfig() async {
    final response = await http.get(Uri.parse("$baseUrl/config/"));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(
        "Failed to load settings (status ${response.statusCode})",
      );
    }
  }

  static Future<Map<String, dynamic>> updateDeviceConfig({
    required String guardianPhone,
    required double geofenceLatitude,
    required double geofenceLongitude,
    required double geofenceRadiusM,
  }) async {
    final response = await http.patch(
      Uri.parse("$baseUrl/config/"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "guardian_phone": guardianPhone,
        "geofence_latitude": geofenceLatitude,
        "geofence_longitude": geofenceLongitude,
        "geofence_radius_m": geofenceRadiusM,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(
        "Failed to save settings (status ${response.statusCode})",
      );
    }
  }
}
