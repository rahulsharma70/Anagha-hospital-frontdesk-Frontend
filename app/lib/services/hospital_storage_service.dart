import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/hospital_model.dart';

class HospitalStorageService {
  static const String _pendingHospitalsKey = 'pending_hospitals';
  static const String _approvedHospitalsKey = 'approved_hospitals';

  /// Save pending hospital to local storage
  static Future<void> savePendingHospital(Hospital hospital) async {
    final prefs = await SharedPreferences.getInstance();
    final pendingHospitals = await getPendingHospitals();
    
    // Check if hospital already exists
    final existingIndex = pendingHospitals.indexWhere((h) => h.id == hospital.id);
    if (existingIndex != -1) {
      pendingHospitals[existingIndex] = hospital;
    } else {
      pendingHospitals.add(hospital);
    }
    
    final hospitalsJson = pendingHospitals.map((h) => _hospitalToJson(h)).toList();
    await prefs.setString(_pendingHospitalsKey, jsonEncode(hospitalsJson));
  }

  /// Get all pending hospitals from local storage
  static Future<List<Hospital>> getPendingHospitals() async {
    final prefs = await SharedPreferences.getInstance();
    final hospitalsJson = prefs.getString(_pendingHospitalsKey);
    
    if (hospitalsJson == null) {
      return [];
    }
    
    try {
      final List<dynamic> data = jsonDecode(hospitalsJson);
      return data.map((json) => Hospital.fromJson(json)).toList();
    } catch (e) {
      print('Error parsing pending hospitals: $e');
      return [];
    }
  }

  /// Remove pending hospital (move to approved)
  static Future<void> removePendingHospital(int hospitalId) async {
    final prefs = await SharedPreferences.getInstance();
    final pendingHospitals = await getPendingHospitals();
    pendingHospitals.removeWhere((h) => h.id == hospitalId);
    
    final hospitalsJson = pendingHospitals.map((h) => _hospitalToJson(h)).toList();
    await prefs.setString(_pendingHospitalsKey, jsonEncode(hospitalsJson));
  }

  /// Save approved hospital to local storage
  static Future<void> saveApprovedHospital(Hospital hospital) async {
    final prefs = await SharedPreferences.getInstance();
    final approvedHospitals = await getApprovedHospitals();
    
    // Check if hospital already exists
    final existingIndex = approvedHospitals.indexWhere((h) => h.id == hospital.id);
    if (existingIndex != -1) {
      approvedHospitals[existingIndex] = hospital;
    } else {
      approvedHospitals.add(hospital);
    }
    
    final hospitalsJson = approvedHospitals.map((h) => _hospitalToJson(h)).toList();
    await prefs.setString(_approvedHospitalsKey, jsonEncode(hospitalsJson));
  }

  /// Get all approved hospitals from local storage
  static Future<List<Hospital>> getApprovedHospitals() async {
    final prefs = await SharedPreferences.getInstance();
    final hospitalsJson = prefs.getString(_approvedHospitalsKey);
    
    if (hospitalsJson == null) {
      return [];
    }
    
    try {
      final List<dynamic> data = jsonDecode(hospitalsJson);
      return data.map((json) => Hospital.fromJson(json)).toList();
    } catch (e) {
      print('Error parsing approved hospitals: $e');
      return [];
    }
  }

  /// Convert Hospital to JSON for storage
  static Map<String, dynamic> _hospitalToJson(Hospital hospital) {
    return {
      'id': hospital.id,
      'name': hospital.name,
      'email': hospital.email,
      'mobile': hospital.mobile,
      'status': hospital.status,
      'address_line1': hospital.addressLine1,
      'address_line2': hospital.addressLine2,
      'address_line3': hospital.addressLine3,
      'city': hospital.city,
      'state': hospital.state,
      'pincode': hospital.pincode,
      'whatsapp_enabled': hospital.whatsappEnabled,
      'default_upi_id': hospital.defaultUpiId,
      'google_pay_upi_id': hospital.googlePayUpiId,
      'phonepe_upi_id': hospital.phonePeUpiId,
      'paytm_upi_id': hospital.paytmUpiId,
      'bhim_upi_id': hospital.bhimUpiId,
      'payment_qr_code': hospital.paymentQrCode,
    };
  }
}

