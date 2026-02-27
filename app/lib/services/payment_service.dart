import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'api_service.dart';

class PaymentService {
  static String get baseUrl => ApiService.baseUrl;
  static const String _cashfreeSandboxCheckoutUrl = 'https://sandbox.cashfree.com/pg/view/sessions/checkout';
  static const String _cashfreeProductionCheckoutUrl = 'https://payments.cashfree.com/pg/view/sessions/checkout';
  
  static String get cashfreeCheckoutBaseUrl {
    const mode = String.fromEnvironment('CASHFREE_MODE', defaultValue: 'production');
    return mode.toLowerCase() == 'sandbox'
        ? _cashfreeSandboxCheckoutUrl
        : _cashfreeProductionCheckoutUrl;
  }
  
  /// Create a payment order for appointment/operation (authenticated users)
  static Future<Map<String, dynamic>?> createPaymentOrder({
    required int? appointmentId,
    required int? operationId,
    required double amount,
    String currency = 'INR',
    String? authToken,
  }) async {
    try {
      print('Creating payment order: appointmentId=$appointmentId, operationId=$operationId, amount=$amount');
      
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      
      if (authToken != null) {
        headers['Authorization'] = 'Bearer $authToken';
      }
      
      final response = await http.post(
        Uri.parse('$baseUrl/api/payments/create-order'),
        headers: headers,
        body: jsonEncode({
          'appointment_id': appointmentId,
          'operation_id': operationId,
          'amount': amount,
          'currency': currency,
        }),
      ).timeout(const Duration(seconds: 30));

      print('Payment order response status: ${response.statusCode}');
      print('Payment order response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        print('Payment order created successfully: ${data['payment_session_id'] ?? data['order_id']}');
        return data;
      } else {
        print('Payment order creation failed: Status ${response.statusCode}, Body: ${response.body}');
        try {
          final error = jsonDecode(response.body);
          throw Exception(error['detail'] ?? 'Failed to create payment order');
        } catch (e) {
          throw Exception('Failed to create payment order: ${response.statusCode}');
        }
      }
    } catch (e) {
      print('Error creating payment order: $e');
      rethrow;
    }
  }

  /// Create a payment order for guest bookings (no auth required)
  static Future<Map<String, dynamic>?> createGuestPaymentOrder({
    required int? appointmentId,
    required int? operationId,
    required double amount,
    String currency = 'INR',
  }) async {
    try {
      print('Creating guest payment order: appointmentId=$appointmentId, operationId=$operationId, amount=$amount');
      
      final response = await http.post(
        Uri.parse('$baseUrl/api/payments/create-order-guest'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'appointment_id': appointmentId,
          'operation_id': operationId,
          'amount': amount,
          'currency': currency,
        }),
      ).timeout(const Duration(seconds: 30));

      print('Guest payment order response status: ${response.statusCode}');
      print('Guest payment order response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        print('Guest payment order created successfully: ${data['payment_session_id'] ?? data['order_id']}');
        return data;
      } else {
        print('Guest payment order creation failed: Status ${response.statusCode}, Body: ${response.body}');
        try {
          final error = jsonDecode(response.body);
          throw Exception(error['detail'] ?? 'Failed to create payment order');
        } catch (e) {
          throw Exception('Failed to create payment order: ${response.statusCode}');
        }
      }
    } catch (e) {
      print('Error creating guest payment order: $e');
      rethrow;
    }
  }

  /// Create a payment order for hospital registration
  static Future<Map<String, dynamic>?> createHospitalRegistrationOrder({
    required String planName,
    required double amount,
    String? customerName,
    String? customerPhone,
    String? customerEmail,
    String currency = 'INR',
  }) async {
    try {
      print('Creating hospital registration payment order: planName=$planName, amount=$amount');
      
      final response = await http.post(
        Uri.parse('$baseUrl/api/payments/create-order-hospital'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'hospital_registration': true,
          'plan_name': planName,
          'amount': amount,
          'currency': currency,
          'customer_name': customerName,
          'customer_phone': customerPhone,
          'customer_email': customerEmail,
        }),
      ).timeout(const Duration(seconds: 30));

      print('Hospital payment order response status: ${response.statusCode}');
      print('Hospital payment order response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        print('Hospital payment order created successfully: ${data['payment_session_id'] ?? data['order_id']}');
        return data;
      } else {
        print('Hospital payment order creation failed: Status ${response.statusCode}, Body: ${response.body}');
        try {
          final error = jsonDecode(response.body);
          throw Exception(error['detail'] ?? 'Failed to create payment order');
        } catch (e) {
          throw Exception('Failed to create payment order: ${response.statusCode}');
        }
      }
    } catch (e) {
      print('Error creating hospital payment order: $e');
      rethrow;
    }
  }

  /// Verify payment after completion (uses payment_id, not order_id)
  static Future<bool> verifyPayment(int paymentId, {String? authToken}) async {
    try {
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      
      if (authToken != null) {
        headers['Authorization'] = 'Bearer $authToken';
      }
      
      final response = await http.post(
        Uri.parse('$baseUrl/api/payments/verify/$paymentId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['verified'] == true || data['status'] == 'COMPLETED';
      }
      return false;
    } catch (e) {
      print('Error verifying payment: $e');
      return false;
    }
  }

  /// Get payment status (uses payment_id, not order_id)
  static Future<Map<String, dynamic>?> getPaymentStatus(int paymentId, {String? authToken}) async {
    try {
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      
      if (authToken != null) {
        headers['Authorization'] = 'Bearer $authToken';
      }
      
      final response = await http.get(
        Uri.parse('$baseUrl/api/payments/$paymentId/status'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('Error getting payment status: $e');
      return null;
    }
  }

  /// Get payment details by payment_id
  static Future<Map<String, dynamic>?> getPayment(int paymentId, {String? authToken}) async {
    try {
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      
      if (authToken != null) {
        headers['Authorization'] = 'Bearer $authToken';
      }
      
      final response = await http.get(
        Uri.parse('$baseUrl/api/payments/$paymentId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('Error getting payment: $e');
      return null;
    }
  }

  /// Open Cashfree Checkout in external browser
  static Future<void> openCashfreeCheckout(String paymentSessionId) async {
    final checkoutUrl = '$cashfreeCheckoutBaseUrl?payment_session_id=$paymentSessionId';
    final uri = Uri.parse(checkoutUrl);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Unable to open payment gateway');
    }
  }

  /// Get payment history for a patient
  static Future<List<Map<String, dynamic>>> getPaymentHistory(String patientMobile) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/payments/history/$patientMobile'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['payments'] ?? []);
      }
      return [];
    } catch (e) {
      print('Error getting payment history: $e');
      return [];
    }
  }

  /// Request refund
  static Future<Map<String, dynamic>?> requestRefund({
    required String paymentId,
    required double amount,
    String? reason,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/payments/refund'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'payment_id': paymentId,
          'amount': amount,
          'reason': reason,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('Error requesting refund: $e');
      return null;
    }
  }

  /// Calculate appointment fee
  static double calculateAppointmentFee(int hospitalId, {double? customAmount}) {
    // Default appointment fee - can be customized per hospital
    // In production, fetch from hospital settings
    return customAmount ?? 500.0; // Default ₹500
  }

  /// Calculate operation fee
  static double calculateOperationFee(int hospitalId, String? specialty, {double? customAmount}) {
    // Default operation fee - can be customized per hospital/specialty
    // In production, fetch from hospital settings
    double baseFee = customAmount ?? 5000.0; // Default ₹5000
    
    // Specialty-based pricing (example)
    switch (specialty?.toLowerCase()) {
      case 'surgery':
        return baseFee * 1.5; // 1.5x for surgery
      case 'ortho':
        return baseFee * 1.3; // 1.3x for ortho
      default:
        return baseFee;
    }
  }
}
