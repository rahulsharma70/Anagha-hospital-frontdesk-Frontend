// Helper methods for hospital registration payment flow
// This file contains payment-related methods that can be reused

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/payment_service.dart';
import '../models/hospital_model.dart';
import '../utils/app_colors.dart';

class HospitalPaymentHelper {
  static String? _getUpiIdForMethod(Hospital hospital, String method) {
    switch (method) {
      case 'googlepay':
        return hospital.googlePayUpiId ?? hospital.defaultUpiId;
      case 'phonepe':
        return hospital.phonePeUpiId ?? hospital.defaultUpiId;
      case 'paytm':
        return hospital.paytmUpiId ?? hospital.defaultUpiId;
      case 'bhim':
        return hospital.bhimUpiId ?? hospital.defaultUpiId;
      default:
        return hospital.defaultUpiId;
    }
  }

  static Future<void> openUpiApp(String method, String? upiId) async {
    if (upiId == null || upiId.isEmpty) {
      Fluttertoast.showToast(
        msg: 'UPI ID not configured for this payment method',
        backgroundColor: AppColors.errorColor,
      );
      return;
    }

    String upiUrl = '';
    switch (method) {
      case 'googlepay':
        upiUrl = 'tez://upi/pay?pa=$upiId&pn=Hospital&am=5000&cu=INR';
        break;
      case 'phonepe':
        upiUrl = 'phonepe://pay?pa=$upiId&pn=Hospital&am=5000&cu=INR';
        break;
      case 'paytm':
        upiUrl = 'paytmmp://pay?pa=$upiId&pn=Hospital&am=5000&cu=INR';
        break;
      case 'bhim':
        upiUrl = 'upi://pay?pa=$upiId&pn=Hospital&am=5000&cu=INR';
        break;
    }

    try {
      final uri = Uri.parse(upiUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        Fluttertoast.showToast(
          msg: 'Payment app not installed',
          backgroundColor: AppColors.errorColor,
        );
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Error opening payment app: $e',
        backgroundColor: AppColors.errorColor,
      );
    }
  }

  static Widget buildPaymentOption(
    BuildContext context,
    String title,
    String method,
    IconData icon,
    Color color,
    Hospital? hospital,
    VoidCallback onTap,
  ) {
    final upiId = hospital != null ? _getUpiIdForMethod(hospital, method) : null;
    final hasUpiId = upiId != null && upiId.isNotEmpty;

    return Card(
      elevation: 2,
      child: InkWell(
        onTap: hasUpiId ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (hasUpiId)
                      Text(
                        upiId!,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textLight,
                        ),
                      )
                    else
                      const Text(
                        'Not configured',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.errorColor,
                        ),
                      ),
                  ],
                ),
              ),
              if (hasUpiId)
                const Icon(Icons.arrow_forward_ios, size: 16)
              else
                const Icon(Icons.block, color: AppColors.errorColor),
            ],
          ),
        ),
      ),
    );
  }
}

