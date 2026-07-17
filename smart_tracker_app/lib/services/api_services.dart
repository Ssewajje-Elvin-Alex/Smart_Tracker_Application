import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String url =
      "https://smart-tracker-a4mu.onrender.com/api/location/latest/";
      //"http://10.177.149.48:8000/api/location/latest/";
      //"http://127.0.0.1:8000/api/location/latest/"; 

  static Future<Map<String, dynamic>> getLatestLocation() async {
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      print (response.body);
      return jsonDecode(response.body);
    } else {
      print (response.statusCode);
      print (response.body);
      throw Exception("Failed to load location");
    }
  }
}