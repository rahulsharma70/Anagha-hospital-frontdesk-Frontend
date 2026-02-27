import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_service.dart';

class DoctorService {
  static String get baseUrl => ApiService.baseUrl;
  
  /// Get all doctors (public endpoint - no auth required)
  static Future<List<Map<String, dynamic>>> getAllDoctors({int? hospitalId}) async {
    try {
      print('DoctorService: Fetching all doctors from public endpoint');
      
      final response = await http.get(
        Uri.parse('$baseUrl/api/users/doctors/public'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      print('DoctorService: Response status: ${response.statusCode}');
      print('DoctorService: Response body length: ${response.body.length}');

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        List<Map<String, dynamic>> doctors = List<Map<String, dynamic>>.from(data);
        
        // Filter by hospital if provided
        if (hospitalId != null) {
          doctors = doctors.where((d) => d['hospital_id'] == hospitalId).toList();
        }
        
        print('DoctorService: Found ${doctors.length} doctors');
        return doctors;
      } else {
        print('DoctorService: Error status ${response.statusCode}: ${response.body}');
        return [];
      }
    } catch (e) {
      print('DoctorService: Error fetching doctors: $e');
      return [];
    }
  }

  /// Search doctors dynamically as user types (client-side filtering)
  static Future<List<Map<String, dynamic>>> searchDoctors(String query, {int? hospitalId}) async {
    try {
      // Get all doctors first, then filter client-side
      final allDoctors = await getAllDoctors(hospitalId: hospitalId);
      
      if (query.isEmpty || query.length < 2) {
        return allDoctors;
      }
      
      final queryLower = query.toLowerCase();
      final filtered = allDoctors.where((doctor) {
        final name = (doctor['name'] ?? '').toString().toLowerCase();
        final specialization = (doctor['specialization'] ?? '').toString().toLowerCase();
        final degree = (doctor['degree'] ?? '').toString().toLowerCase();
        return name.contains(queryLower) || 
               specialization.contains(queryLower) || 
               degree.contains(queryLower);
      }).toList();
      
      print('DoctorService: Found ${filtered.length} doctors matching "$query"');
      return filtered;
    } catch (e) {
      print('DoctorService: Error searching doctors: $e');
      return [];
    }
  }

  /// Add a new doctor to the database (uses doctor registration endpoint)
  /// Note: This requires authentication and creates a full doctor profile
  static Future<Map<String, dynamic>> addNewDoctor({
    required String doctorName,
    required String mobile,
    required String degree,
    required String instituteName,
    required int hospitalId,
    String? email,
    String? specialization,
    String? experience1,
    String? experience2,
    String? experience3,
    String? experience4,
    String? password, // Required for doctor registration
  }) async {
    try {
      // Use doctor registration endpoint which requires auth token
      final url = '$baseUrl/api/users/register-doctor';
      print('DoctorService: Registering doctor at $url');
      
      // Get auth token
      final token = await ApiService.getToken();
      if (token == null) {
        throw Exception('Authentication required to add doctor. Please login first.');
      }
      
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'name': doctorName,
          'mobile': mobile,
          'email': email,
          'role': 'doctor',
          'degree': degree,
          'institute_name': instituteName,
          'specialization': specialization,
          'hospital_id': hospitalId,
          'password': password ?? 'default123', // Should be provided
          'experience1': experience1,
          'experience2': experience2,
          'experience3': experience3,
          'experience4': experience4,
        }),
      ).timeout(const Duration(seconds: 10));

      print('DoctorService: Register doctor response status: ${response.statusCode}');
      print('DoctorService: Register doctor response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        print('DoctorService: Doctor registered successfully: ${data['doctor']?['name'] ?? data['user']?['name']}');
        return data;
      } else {
        String errorMessage = 'Failed to register doctor';
        try {
          if (response.body.isNotEmpty) {
            final error = jsonDecode(response.body);
            errorMessage = error['detail'] ?? error['message'] ?? errorMessage;
          }
        } catch (e) {
          if (response.statusCode == 404) {
            errorMessage = 'API endpoint not found. Please check if server is running at $baseUrl';
          } else if (response.statusCode == 500) {
            errorMessage = 'Server error. Please try again later.';
          } else {
            errorMessage = 'Failed to register doctor (Status: ${response.statusCode})';
          }
        }
        print('DoctorService: Error: $errorMessage');
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('DoctorService: Error registering doctor: $e');
      rethrow;
    }
  }
}

