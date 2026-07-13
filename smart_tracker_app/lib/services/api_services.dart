import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String url =
      //"http://10.52.58.48:8000/api/location/latest/";
      "http://127.0.0.1:8000/api/location/latest/";

  static Future<Map<String, dynamic>> getLatestLocation() async {
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Failed to load location");
    }
  }
}