import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_service.dart';

class CityService {
  static String get baseUrl => ApiService.baseUrl;
  
  /// Search cities dynamically as user types
  /// Returns list of maps with city_name and state_name
  static Future<List<Map<String, dynamic>>> searchCities(String query) async {
    if (query.isEmpty || query.length < 2) {
      return [];
    }
    
    try {
      final url = '$baseUrl/api/cities/search?q=${Uri.encodeComponent(query)}';
      print('CityService: Searching cities at $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 5));

      print('CityService: Response status: ${response.statusCode}');
      print('CityService: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final cities = List<Map<String, dynamic>>.from(data['cities'] ?? []);
        final source = data['source'] ?? 'unknown';
        final cached = data['cached'] ?? false;
        print('CityService: Found ${cities.length} cities (source: $source, cached: $cached)');
        return cities;
      } else {
        print('CityService: Error status ${response.statusCode}: ${response.body}');
        return [];
      }
    } catch (e) {
      print('CityService: Error searching cities: $e');
      return [];
    }
  }
  
  /// Get city names only (for backward compatibility)
  static Future<List<String>> searchCityNames(String query) async {
    final cities = await searchCities(query);
    return cities.map((c) => c['city_name'] as String? ?? '').where((name) => name.isNotEmpty).toList();
  }

  /// Get popular cities (for initial suggestions)
  /// Returns list of city names (for backward compatibility)
  static Future<List<String>> getPopularCities() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/cities/popular'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final cities = data['cities'] ?? [];
        // Handle both old format (List<String>) and new format (List<Map>)
        if (cities.isNotEmpty && cities[0] is Map) {
          return cities.map((c) => c['city_name'] ?? '').where((name) => name.isNotEmpty).cast<String>().toList();
        } else {
          return List<String>.from(cities);
        }
      }
      return _getDefaultCities();
    } catch (e) {
      return _getDefaultCities();
    }
  }

  /// Add a new city to the database
  static Future<Map<String, dynamic>> addNewCity({
    required String cityName,
    String? stateName,
    String? districtName,
    String? pincode,
  }) async {
    try {
      final url = '$baseUrl/api/cities/add';
      print('CityService: Adding city at $url');
      
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'city_name': cityName,
          'state_name': stateName,
          'district_name': districtName,
          'pincode': pincode,
        }),
      ).timeout(const Duration(seconds: 10));

      print('CityService: Add city response status: ${response.statusCode}');
      print('CityService: Add city response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        print('CityService: City added successfully: ${data['city_name']}');
        return data;
      } else {
        // Try to parse error message
        String errorMessage = 'Failed to add city';
        try {
          if (response.body.isNotEmpty) {
            final error = jsonDecode(response.body);
            errorMessage = error['detail'] ?? error['message'] ?? errorMessage;
          } else {
            // Empty response body
            if (response.statusCode == 404) {
              errorMessage = 'API endpoint not found. Please check if server is running at $baseUrl';
            } else if (response.statusCode == 500) {
              errorMessage = 'Server error. Please try again later.';
            } else {
              errorMessage = 'Failed to add city (Status: ${response.statusCode})';
            }
          }
        } catch (e) {
          // If JSON parsing fails, use status code message
          if (response.statusCode == 404) {
            errorMessage = 'API endpoint not found. Please check if server is running at $baseUrl';
          } else if (response.statusCode == 500) {
            errorMessage = 'Server error. Please try again later.';
          } else {
            errorMessage = 'Failed to add city (Status: ${response.statusCode})';
          }
        }
        print('CityService: Error: $errorMessage');
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('CityService: Error adding city: $e');
      rethrow;
    }
  }

  /// Default cities if API fails
  static List<String> _getDefaultCities() {
    return [
      'Mumbai',
      'Delhi',
      'Bangalore',
      'Hyderabad',
      'Chennai',
      'Kolkata',
      'Pune',
      'Ahmedabad',
      'Jaipur',
      'Surat',
    ];
  }
}
