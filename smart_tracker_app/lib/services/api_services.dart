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
}
