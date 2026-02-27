import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../services/api_service.dart';
import '../services/email_service.dart';
import '../services/hospital_storage_service.dart';
import '../services/payment_service.dart';
import '../models/hospital_model.dart';
import '../utils/app_colors.dart';
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/city_autocomplete.dart';
import 'package_selection_screen.dart';

class HospitalRegisterScreen extends StatefulWidget {
  final int? initialPaymentId;
  final String? initialPaymentSessionId;
  final String? selectedPackage;
  final String? selectedBillingPeriod;

  const HospitalRegisterScreen({
    super.key,
    this.initialPaymentId,
    this.initialPaymentSessionId,
    this.selectedPackage,
    this.selectedBillingPeriod,
  });

  @override
  State<HospitalRegisterScreen> createState() => _HospitalRegisterScreenState();
}

class _HospitalRegisterScreenState extends State<HospitalRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _mobileController = TextEditingController();
  final _addressLine1Controller = TextEditingController();
  final _addressLine2Controller = TextEditingController();
  final _addressLine3Controller = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _defaultUpiController = TextEditingController();
  final _googlePayUpiController = TextEditingController();
  final _phonePeUpiController = TextEditingController();
  final _paytmUpiController = TextEditingController();
  final _bhimUpiController = TextEditingController();

  bool _whatsappEnabled = false;
  bool _isLoading = false;
  bool _showPaymentOptions = false;
  int? _paymentId;
  String? _paymentSessionId;
  String? _selectedPackage;
  String? _selectedBillingPeriod;

  @override
  void initState() {
    super.initState();
    // Initialize with provided values if available
    if (widget.initialPaymentId != null) {
      _paymentId = widget.initialPaymentId;
      _showPaymentOptions = true;
    }
    if (widget.initialPaymentSessionId != null) {
      _paymentSessionId = widget.initialPaymentSessionId;
    }
    if (widget.selectedPackage != null) {
      _selectedPackage = widget.selectedPackage;
    }
    if (widget.selectedBillingPeriod != null) {
      _selectedBillingPeriod = widget.selectedBillingPeriod;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _addressLine1Controller.dispose();
    _addressLine2Controller.dispose();
    _addressLine3Controller.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    _defaultUpiController.dispose();
    _googlePayUpiController.dispose();
    _phonePeUpiController.dispose();
    _paytmUpiController.dispose();
    _bhimUpiController.dispose();
    super.dispose();
  }

  Future<void> _initiatePayment() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Create payment order for hospital registration
      // Default to Small Clinic pricing if no package selected
      final paymentAmount = _selectedPackage == 'Medium (≤5 Drs)' 
          ? 11000.0 
          : _selectedPackage == 'Corporate' 
              ? 21000.0 
              : 5001.0; // Small Clinic default
      final paymentOrderResponse = await PaymentService.createHospitalRegistrationOrder(
        planName: _selectedPackage ?? 'Hospital Registration',
        amount: paymentAmount,
        customerName: _nameController.text.trim(),
        customerPhone: _mobileController.text.trim(),
        customerEmail: _emailController.text.trim(),
      );

      if (paymentOrderResponse == null || paymentOrderResponse['payment_session_id'] == null) {
        throw Exception('Failed to create payment order');
      }

      setState(() {
        _paymentId = paymentOrderResponse['payment_id'] as int?;
        _paymentSessionId = paymentOrderResponse['payment_session_id'] as String?;
        _showPaymentOptions = true;
        _isLoading = false;
      });

      Fluttertoast.showToast(
        msg: 'Please complete payment to proceed with registration',
        backgroundColor: AppColors.infoColor,
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      Fluttertoast.showToast(
        msg: 'Error initiating payment: $e',
        backgroundColor: AppColors.errorColor,
      );
    }
  }

  Future<void> _openCashfreeCheckout() async {
    if (_paymentSessionId == null || _paymentSessionId!.isEmpty) {
      Fluttertoast.showToast(
        msg: 'Payment session not ready. Please try again.',
        backgroundColor: AppColors.errorColor,
      );
      return;
    }

    try {
      await PaymentService.openCashfreeCheckout(_paymentSessionId!);
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Unable to open payment gateway',
        backgroundColor: AppColors.errorColor,
      );
    }
  }

  Future<void> _submitRegistration() async {
    // Payment is mandatory - check if payment was completed
    if (_paymentId == null) {
      Fluttertoast.showToast(
        msg: 'Please complete payment first',
        backgroundColor: AppColors.errorColor,
      );
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Prepare hospital data outside try block so it's accessible in catch block
    // Generate hospital ID upfront (before API call) to ensure it's always available
    final hospitalId = DateTime.now().millisecondsSinceEpoch ~/ 1000; // Unix timestamp
    
    final hospitalData = {
      'id': hospitalId, // Always include ID upfront
      'name': _nameController.text.trim(),
      'email': _emailController.text.trim(),
      'mobile': _mobileController.text.trim(),
      'address_line1': _addressLine1Controller.text.trim().isEmpty
          ? null
          : _addressLine1Controller.text.trim(),
      'address_line2': _addressLine2Controller.text.trim().isEmpty
          ? null
          : _addressLine2Controller.text.trim(),
      'address_line3': _addressLine3Controller.text.trim().isEmpty
          ? null
          : _addressLine3Controller.text.trim(),
      'city': _cityController.text.trim().isEmpty
          ? null
          : _cityController.text.trim(),
      'state': _stateController.text.trim().isEmpty
          ? null
          : _stateController.text.trim(),
      'pincode': _pincodeController.text.trim().isEmpty
          ? null
          : _pincodeController.text.trim(),
      'whatsapp_enabled': _whatsappEnabled,
      'upi_id': _defaultUpiController.text.trim().isEmpty
          ? null
          : _defaultUpiController.text.trim(),
      'gpay_upi_id': _googlePayUpiController.text.trim().isEmpty
          ? null
          : _googlePayUpiController.text.trim(),
      'phonepay_upi_id': _phonePeUpiController.text.trim().isEmpty
          ? null
          : _phonePeUpiController.text.trim(),
      'paytm_upi_id': _paytmUpiController.text.trim().isEmpty
          ? null
          : _paytmUpiController.text.trim(),
      'bhim_upi_id': _bhimUpiController.text.trim().isEmpty
          ? null
          : _bhimUpiController.text.trim(),
      'payment_id': _paymentId, // Include payment ID
    };

    // Always include the generated ID in the data sent to API
    hospitalData['id'] = hospitalId;
    int finalHospitalId = hospitalId;

    try {
      // Try to send to API (this will store in server memory for web page access)
      try {
        final response = await ApiService.post(
          '/api/hospitals/register',
          hospitalData,
        );

        // Extract hospital ID from API response if available
        if (response.statusCode == 200 || response.statusCode == 201) {
          try {
            if (response.body.isNotEmpty) {
              final responseData = jsonDecode(response.body);
              final apiHospitalId = responseData['id'] ?? 
                           responseData['hospital_id'] ?? 
                           responseData['hospital']?['id'];
              if (apiHospitalId != null) {
                finalHospitalId = apiHospitalId;
                hospitalData['id'] = finalHospitalId;
              }
            }
          } catch (e) {
            print('Could not extract hospital ID from API: $e');
          }
          
          print('✅ Hospital registered with API - ID: $finalHospitalId');
        } else {
          print('⚠️ API registration returned status: ${response.statusCode}');
        }
      } catch (apiError) {
        print('⚠️ API registration error (will use local storage): $apiError');
        // Continue with local storage even if API fails
      }

      setState(() {
        _isLoading = false;
      });
      
      // Create hospital object for storage (always save locally)
      hospitalData['id'] = finalHospitalId;
      final hospital = Hospital(
        id: finalHospitalId,
        name: hospitalData['name']?.toString() ?? '',
        email: hospitalData['email']?.toString() ?? '',
        mobile: hospitalData['mobile']?.toString() ?? '',
        status: 'pending',
        addressLine1: hospitalData['address_line1']?.toString(),
        addressLine2: hospitalData['address_line2']?.toString(),
        addressLine3: hospitalData['address_line3']?.toString(),
        city: hospitalData['city']?.toString(),
        state: hospitalData['state']?.toString(),
        pincode: hospitalData['pincode']?.toString(),
        whatsappEnabled: hospitalData['whatsapp_enabled'] as bool?,
        defaultUpiId: hospitalData['default_upi_id']?.toString(),
        googlePayUpiId: hospitalData['google_pay_upi_id']?.toString(),
        phonePeUpiId: hospitalData['phonepe_upi_id']?.toString(),
        paytmUpiId: hospitalData['paytm_upi_id']?.toString(),
        bhimUpiId: hospitalData['bhim_upi_id']?.toString(),
      );
      
      // Save to local storage for admin panel (always save)
      await HospitalStorageService.savePendingHospital(hospital);
      print('✅ Hospital saved to local storage: ${hospital.name} (ID: ${hospital.id})');
      
      // Send email with hospital ID (wait for it to ensure ID is included)
      final emailSent = await _sendEmailNotification(hospitalData);
      if (mounted) {
        if (emailSent) {
          Fluttertoast.showToast(
            msg: 'Registration submitted! Approval email sent with Hospital ID: $finalHospitalId',
            backgroundColor: AppColors.successColor,
            toastLength: Toast.LENGTH_LONG,
          );
        } else {
          Fluttertoast.showToast(
            msg: 'Registration submitted! Hospital ID: $finalHospitalId',
            backgroundColor: AppColors.warningColor,
            toastLength: Toast.LENGTH_LONG,
          );
        }
        
        // Always show notification dialog to ensure WhatsApp is sent
        await _showNotificationDialog(hospitalData);
        if (mounted) {
          Navigator.pop(context);
        }
      }
        return;
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      // Even if API fails, save to local storage
      try {
        final hospital = Hospital(
          id: hospitalId,
          name: hospitalData['name']?.toString() ?? '',
          email: hospitalData['email']?.toString() ?? '',
          mobile: hospitalData['mobile']?.toString() ?? '',
          status: 'pending',
          addressLine1: hospitalData['address_line1']?.toString(),
          addressLine2: hospitalData['address_line2']?.toString(),
          addressLine3: hospitalData['address_line3']?.toString(),
          city: hospitalData['city']?.toString(),
          state: hospitalData['state']?.toString(),
          pincode: hospitalData['pincode']?.toString(),
          whatsappEnabled: hospitalData['whatsapp_enabled'] as bool?,
          defaultUpiId: hospitalData['default_upi_id']?.toString(),
          googlePayUpiId: hospitalData['google_pay_upi_id']?.toString(),
          phonePeUpiId: hospitalData['phonepe_upi_id']?.toString(),
          paytmUpiId: hospitalData['paytm_upi_id']?.toString(),
          bhimUpiId: hospitalData['bhim_upi_id']?.toString(),
        );
        await HospitalStorageService.savePendingHospital(hospital);
        print('Hospital saved to local storage after error: ${hospital.name}');
      } catch (storageError) {
        print('Error saving to local storage: $storageError');
      }
      
      // Try to send email notification
      _sendEmailNotification(hospitalData);
      
      // Show error but continue
      if (mounted) {
        Fluttertoast.showToast(
          msg: 'Registration saved locally. API connection failed.',
          backgroundColor: AppColors.warningColor,
          toastLength: Toast.LENGTH_LONG,
        );
        await _showNotificationDialog(hospitalData);
        if (mounted) {
          Navigator.pop(context);
        }
      }
      return;
    }
    
    // Handle non-200/201 responses
    try {
      final response = await ApiService.post(
        '/api/hospitals/register',
        hospitalData,
      );
      
      if (response.statusCode != 200 && response.statusCode != 201) {
        // If API fails but we have the data, still send notifications as fallback
        // This helps when backend is not yet configured
        String errorMessage = 'Registration failed. Please try again.';
        bool shouldSendNotification = false;
        
        try {
          if (response.body.isNotEmpty) {
            final error = jsonDecode(response.body);
            errorMessage = error['detail'] ?? 
                         error['message'] ?? 
                         error['error'] ?? 
                         errorMessage;
          }
        } catch (e) {
          // If JSON parsing fails, use status code message
          if (response.statusCode == 400) {
            errorMessage = 'Invalid data. Please check all fields.';
          } else if (response.statusCode == 409) {
            errorMessage = 'Hospital already registered with this email or mobile.';
          } else if (response.statusCode == 500) {
            errorMessage = 'Server error. Please try again later.';
            shouldSendNotification = true; // Still send notification for manual processing
          } else if (response.statusCode == 404) {
            errorMessage = 'Registration endpoint not found. Sending notification for manual processing.';
            shouldSendNotification = true; // Send notification as fallback
          } else if (response.statusCode >= 500) {
            shouldSendNotification = true; // Server errors - send notification anyway
          }
        }
        
        // If server error, send notification anyway and show success message
        if (shouldSendNotification) {
          // Try to send email in background
          _sendEmailNotification(hospitalData).then((emailSent) {
            if (mounted && emailSent) {
              Fluttertoast.showToast(
                msg: 'Email sent successfully!',
                backgroundColor: AppColors.successColor,
                toastLength: Toast.LENGTH_SHORT,
              );
            }
          }).catchError((e) {
            print('Background email error: $e');
          });
          
          if (mounted) {
            Fluttertoast.showToast(
              msg: 'Registration request submitted!',
              backgroundColor: AppColors.successColor,
              toastLength: Toast.LENGTH_LONG,
            );
            // Always show notification dialog
            await _showNotificationDialog(hospitalData);
            if (mounted) {
              Navigator.pop(context);
            }
            return;
          }
        }
        
        if (mounted) {
          Fluttertoast.showToast(
            msg: errorMessage,
            backgroundColor: AppColors.errorColor,
            toastLength: Toast.LENGTH_LONG,
          );
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      String errorMessage = 'Error submitting registration. Please try again.';
      bool isNetworkError = false;
      
      // Provide more specific error messages
      if (e.toString().contains('SocketException') || 
          e.toString().contains('Failed host lookup') ||
          e.toString().contains('Network is unreachable') ||
          e.toString().contains('Connection refused')) {
        errorMessage = 'No internet connection or server not reachable. Sending notification for manual processing.';
        isNetworkError = true;
      } else if (e.toString().contains('TimeoutException')) {
        errorMessage = 'Request timed out. Sending notification for manual processing.';
        isNetworkError = true;
      } else if (e.toString().contains('FormatException')) {
        errorMessage = 'Invalid response from server. Sending notification for manual processing.';
        isNetworkError = true;
      }
      
      print('Registration error: $e');
      
      // If network error, send notification as fallback
      if (isNetworkError) {
        // Try to send email in background
        _sendEmailNotification(hospitalData).then((emailSent) {
          if (mounted && emailSent) {
            Fluttertoast.showToast(
              msg: 'Email sent successfully!',
              backgroundColor: AppColors.successColor,
              toastLength: Toast.LENGTH_SHORT,
            );
          }
        }).catchError((e) {
          print('Background email error: $e');
        });
        
        if (mounted) {
          Fluttertoast.showToast(
            msg: 'Registration request submitted!',
            backgroundColor: AppColors.successColor,
            toastLength: Toast.LENGTH_LONG,
          );
          // Always show notification dialog
          await _showNotificationDialog(hospitalData);
          if (mounted) {
            Navigator.pop(context);
          }
          return;
        }
      }
      
      if (mounted) {
        Fluttertoast.showToast(
          msg: errorMessage,
          backgroundColor: AppColors.errorColor,
          toastLength: Toast.LENGTH_LONG,
        );
      }
    }
  }

  /// Send email notification automatically via SMTP
  Future<bool> _sendEmailNotification(Map<String, dynamic> hospitalData) async {
    try {
      final emailSent = await EmailService.sendHospitalRegistrationEmail(
        hospitalName: hospitalData['name'] ?? '',
        hospitalEmail: hospitalData['email'] ?? '',
        hospitalMobile: hospitalData['mobile'] ?? '',
        hospitalId: hospitalData['id'],
        addressLine1: hospitalData['address_line1'],
        addressLine2: hospitalData['address_line2'],
        addressLine3: hospitalData['address_line3'],
        city: hospitalData['city'],
        state: hospitalData['state'],
        pincode: hospitalData['pincode'],
        whatsappEnabled: hospitalData['whatsapp_enabled'],
        defaultUpiId: hospitalData['default_upi_id'],
        googlePayUpiId: hospitalData['google_pay_upi_id'],
        phonePeUpiId: hospitalData['phonepe_upi_id'],
        paytmUpiId: hospitalData['paytm_upi_id'],
        bhimUpiId: hospitalData['bhim_upi_id'],
      );
      
      return emailSent;
    } catch (e) {
      print('Email notification error: $e');
      return false;
    }
  }

  Future<void> _sendApprovalNotification(Map<String, dynamic> hospitalData) async {
    // Try to send email automatically first
    final emailSent = await _sendEmailNotification(hospitalData);
    
    // If email failed, show dialog for manual sending
    if (!emailSent && mounted) {
      await _showNotificationDialog(hospitalData);
    }
  }

  Future<void> _showNotificationDialog(Map<String, dynamic> hospitalData) async {
    if (!mounted) return;
    
    final emailSubject = 'New Hospital Registration Request - ${hospitalData['name']}';
    final emailBody = '''
New Hospital Registration Request

Hospital Name: ${hospitalData['name']}
Email: ${hospitalData['email']}
Mobile: ${hospitalData['mobile']}
Address: ${hospitalData['address_line1'] ?? ''}
City: ${hospitalData['city'] ?? ''}
State: ${hospitalData['state'] ?? ''}
Pincode: ${hospitalData['pincode'] ?? ''}

Please review and approve this hospital registration.
    ''';

    final whatsappMessage = '''
*New Hospital Registration Request - Anagha Hospital Solutions*

🏥 *Hospital Details:*
Name: ${hospitalData['name']}
Email: ${hospitalData['email']}
Mobile: ${hospitalData['mobile']}
Address: ${hospitalData['address_line1'] ?? 'N/A'}
City: ${hospitalData['city'] ?? 'N/A'}
State: ${hospitalData['state'] ?? 'N/A'}
Pincode: ${hospitalData['pincode'] ?? 'N/A'}

💬 WhatsApp: ${hospitalData['whatsapp_enabled'] == true ? 'Enabled' : 'Disabled'}

💳 *Payment UPI IDs:*
Default: ${hospitalData['default_upi_id'] ?? 'Not provided'}
Google Pay: ${hospitalData['google_pay_upi_id'] ?? 'Not provided'}
PhonePe: ${hospitalData['phonepe_upi_id'] ?? 'Not provided'}
Paytm: ${hospitalData['paytm_upi_id'] ?? 'Not provided'}
BHIM: ${hospitalData['bhim_upi_id'] ?? 'Not provided'}

⚠️ *Action Required:* Please review and approve this hospital registration.

Thank you!
    ''';

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.notifications_active, color: AppColors.primaryColor),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Send Approval Notification',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.warningColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.warningColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '⚠️ IMPORTANT: Your registration requires administrator approval.',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.successColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.email, size: 16, color: AppColors.successColor),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Email is being sent automatically in the background.',
                                  style: TextStyle(fontSize: 12, color: AppColors.successColor),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Please also send WhatsApp notification using the button below:',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 15),
                  const Text(
                    'Administrator Contact:',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Row(
                    children: [
                      Icon(Icons.email, size: 16, color: AppColors.primaryColor),
                      SizedBox(width: 8),
                      Text('info@uabiotech.in'),
                    ],
                  ),
                  const SizedBox(height: 5),
                  const Row(
                    children: [
                      Icon(Icons.phone, size: 16, color: AppColors.primaryColor),
                      SizedBox(width: 8),
                      Text('+919039939555'),
                    ],
                  ),
                  const SizedBox(height: 15),
                  const Text(
                    'Click the WhatsApp button below to send the notification. The WhatsApp app will open with pre-filled message - please click SEND.',
                    style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: AppColors.textLight),
                  ),
                ],
              ),
            ),
            actions: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // WhatsApp button - most important
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.pop(context);
                        // Try multiple WhatsApp URL formats
                        final whatsappUrls = [
                          'https://wa.me/919039939555?text=${Uri.encodeComponent(whatsappMessage)}',
                          'https://api.whatsapp.com/send?phone=919039939555&text=${Uri.encodeComponent(whatsappMessage)}',
                          'whatsapp://send?phone=919039939555&text=${Uri.encodeComponent(whatsappMessage)}',
                        ];
                        
                        bool whatsappOpened = false;
                        for (final url in whatsappUrls) {
                          try {
                            final whatsappUri = Uri.parse(url);
                            if (await canLaunchUrl(whatsappUri)) {
                              await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
                              whatsappOpened = true;
                              if (mounted) {
                                Fluttertoast.showToast(
                                  msg: 'WhatsApp opened! Please click SEND to complete notification.',
                                  backgroundColor: AppColors.successColor,
                                  toastLength: Toast.LENGTH_LONG,
                                );
                              }
                              break;
                            }
                          } catch (e) {
                            print('WhatsApp URL error: $e');
                            continue;
                          }
                        }
                        
                        if (!whatsappOpened && mounted) {
                          Fluttertoast.showToast(
                            msg: 'Could not open WhatsApp. Please send message manually to +919039939555',
                            backgroundColor: AppColors.errorColor,
                            toastLength: Toast.LENGTH_LONG,
                          );
                        }
                      },
                      icon: const Icon(Icons.chat, color: Colors.white, size: 24),
                      label: const Text('💬 Send WhatsApp (Required)', 
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                        elevation: 3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Email button - as backup
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.pop(context);
                        final emailUri = Uri.parse(
                          'mailto:info@uabiotech.in?subject=${Uri.encodeComponent(emailSubject)}&body=${Uri.encodeComponent(emailBody)}',
                        );
                        try {
                          if (await canLaunchUrl(emailUri)) {
                            await launchUrl(emailUri, mode: LaunchMode.externalApplication);
                            if (mounted) {
                              Fluttertoast.showToast(
                                msg: 'Email app opened. Please click SEND to complete notification.',
                                backgroundColor: AppColors.successColor,
                                toastLength: Toast.LENGTH_LONG,
                              );
                            }
                          } else {
                            if (mounted) {
                              Fluttertoast.showToast(
                                msg: 'Could not open email app. Email is being sent automatically in background.',
                                backgroundColor: AppColors.warningColor,
                                toastLength: Toast.LENGTH_LONG,
                              );
                            }
                          }
                        } catch (e) {
                          if (mounted) {
                            Fluttertoast.showToast(
                              msg: 'Could not open email app. Email is being sent automatically in background.',
                              backgroundColor: AppColors.warningColor,
                              toastLength: Toast.LENGTH_LONG,
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.email, color: Colors.white),
                      label: const Text('📧 Send Email (Backup)', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryColor,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      if (mounted) {
                        Fluttertoast.showToast(
                          msg: '⚠️ Please remember to send approval notification to info@uabiotech.in or WhatsApp +919039939555',
                          backgroundColor: AppColors.warningColor,
                          toastLength: Toast.LENGTH_LONG,
                        );
                      }
                    },
                    child: const Text('I\'ll Send Later'),
                  ),
                ],
              ),
            ],
          );
    },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hospital Registration'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Hospital Registration',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Register your hospital to use our booking system. Approval required.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textLight,
                  ),
                ),
                const SizedBox(height: 30),

                // Hospital Name
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Hospital Name *',
                    prefixIcon: Icon(Icons.local_hospital),
                    hintText: 'Enter hospital name',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter hospital name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Email
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email Address *',
                    prefixIcon: Icon(Icons.email),
                    hintText: 'Enter hospital email',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter email address';
                    }
                    if (!value.contains('@')) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Mobile
                TextFormField(
                  controller: _mobileController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Mobile Number *',
                    prefixIcon: Icon(Icons.phone),
                    hintText: 'Enter hospital contact number',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter mobile number';
                    }
                    if (value.length != 10) {
                      return 'Please enter a valid 10-digit mobile number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Address Line 1
                TextFormField(
                  controller: _addressLine1Controller,
                  decoration: const InputDecoration(
                    labelText: 'Address Line 1',
                    prefixIcon: Icon(Icons.home),
                    hintText: 'Street address',
                  ),
                ),
                const SizedBox(height: 20),

                // Address Line 2
                TextFormField(
                  controller: _addressLine2Controller,
                  decoration: const InputDecoration(
                    labelText: 'Address Line 2',
                    prefixIcon: Icon(Icons.location_city),
                    hintText: 'Area/Locality',
                  ),
                ),
                const SizedBox(height: 20),

                // Address Line 3
                TextFormField(
                  controller: _addressLine3Controller,
                  decoration: const InputDecoration(
                    labelText: 'Address Line 3',
                    prefixIcon: Icon(Icons.pin_drop),
                    hintText: 'City, State, PIN',
                  ),
                ),
                const SizedBox(height: 20),

                // City (Autocomplete)
                CityAutocomplete(
                  controller: _cityController,
                  labelText: 'City *',
                  hintText: 'Start typing city name...',
                  prefixIcon: Icons.location_city,
                  stateController: _stateController, // Auto-fill state when city is selected
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter city name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // State (auto-filled when city is selected)
                TextFormField(
                  controller: _stateController,
                  decoration: const InputDecoration(
                    labelText: 'State *',
                    hintText: 'State will be auto-filled when city is selected',
                    prefixIcon: Icon(Icons.map),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter state name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Pincode
                TextFormField(
                  controller: _pincodeController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Pincode',
                    prefixIcon: Icon(Icons.pin),
                    hintText: 'Enter pincode',
                  ),
                ),
                const SizedBox(height: 30),

                // WhatsApp Integration
                Card(
                  color: AppColors.primaryColor.withOpacity(0.1),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.chat, color: AppColors.primaryColor),
                            const SizedBox(width: 10),
                            const Text(
                              '📱 WhatsApp Integration (Optional)',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Connect your WhatsApp to send automatic appointment confirmations and reminders to patients.',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textLight,
                          ),
                        ),
                        const SizedBox(height: 10),
                        SwitchListTile(
                          title: const Text('Enable WhatsApp notifications'),
                          value: _whatsappEnabled,
                          onChanged: (value) {
                            setState(() {
                              _whatsappEnabled = value;
                            });
                          },
                          contentPadding: EdgeInsets.zero,
                        ),
                        const SizedBox(height: 5),
                        const Text(
                          'You can initialize WhatsApp after registration by clicking the "Initialize WhatsApp" button.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textLight,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 30),

                // Payment UPI IDs
                const Text(
                  'Payment UPI IDs (Optional)',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Add your UPI IDs for different payment apps. These will be used for receiving payments from patients.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textLight,
                  ),
                ),
                const SizedBox(height: 20),

                // Default UPI ID
                TextFormField(
                  controller: _defaultUpiController,
                  decoration: const InputDecoration(
                    labelText: 'Default UPI ID',
                    prefixIcon: Icon(Icons.payment),
                    hintText: 'e.g., hospital@paytm',
                    helperText: 'Universal UPI ID (used if app-specific IDs not provided)',
                  ),
                ),
                const SizedBox(height: 20),

                // Google Pay UPI ID
                TextFormField(
                  controller: _googlePayUpiController,
                  decoration: const InputDecoration(
                    labelText: '📱 Google Pay UPI ID',
                    prefixIcon: Icon(Icons.account_balance_wallet),
                    hintText: 'e.g., hospital@okaxis',
                  ),
                ),
                const SizedBox(height: 20),

                // PhonePe UPI ID
                TextFormField(
                  controller: _phonePeUpiController,
                  decoration: const InputDecoration(
                    labelText: '💳 PhonePe UPI ID',
                    prefixIcon: Icon(Icons.payment),
                    hintText: 'e.g., hospital@ybl',
                  ),
                ),
                const SizedBox(height: 20),

                // Paytm UPI ID
                TextFormField(
                  controller: _paytmUpiController,
                  decoration: const InputDecoration(
                    labelText: '💵 Paytm UPI ID',
                    prefixIcon: Icon(Icons.account_balance),
                    hintText: 'e.g., hospital@paytm',
                  ),
                ),
                const SizedBox(height: 20),

                // BHIM UPI ID
                TextFormField(
                  controller: _bhimUpiController,
                  decoration: const InputDecoration(
                    labelText: '🏦 BHIM UPI ID',
                    prefixIcon: Icon(Icons.account_balance_wallet),
                    hintText: 'e.g., hospital@upi',
                  ),
                ),
                const SizedBox(height: 20),

                // Note
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warningColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.warningColor.withOpacity(0.3)),
                  ),
                  child: const Text(
                    'Note: After registration, an approval request will be sent to the administrator. You will be notified once your hospital is approved. Only approved hospitals can be selected during user registration.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
                const SizedBox(height: 30),

                // Payment Section (if payment initiated)
                if (_showPaymentOptions) ...[
                  Card(
                    color: AppColors.successColor.withOpacity(0.1),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.payment,
                            size: 60,
                            color: AppColors.successColor,
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Complete Payment to Register',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Amount: ₹5,000.00',
                            style: TextStyle(
                              fontSize: 18,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Note: Payment is required for hospital registration. After payment, click below to complete registration.',
                            style: TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: AppColors.textLight,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: _openCashfreeCheckout,
                            icon: const Icon(Icons.payment),
                            label: const Text('Open Payment Gateway'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submitRegistration,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.successColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Complete Registration (After Payment)',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ] else ...[
                  // Submit Button (initiates payment first)
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : () {
                        // Navigate to package selection screen
                        if (!_formKey.currentState!.validate()) {
                          return;
                        }
                        
                        final hospitalData = {
                          'name': _nameController.text.trim(),
                          'email': _emailController.text.trim(),
                          'mobile': _mobileController.text.trim(),
                          'address_line1': _addressLine1Controller.text.trim(),
                          'address_line2': _addressLine2Controller.text.trim(),
                          'address_line3': _addressLine3Controller.text.trim(),
                          'city': _cityController.text.trim(),
                          'state': _stateController.text.trim(),
                          'pincode': _pincodeController.text.trim(),
                          'whatsapp_enabled': _whatsappEnabled,
                          'whatsapp_number': _whatsappEnabled ? _mobileController.text.trim() : null,
                          'upi_id': _defaultUpiController.text.trim().isEmpty ? null : _defaultUpiController.text.trim(),
                          'gpay_upi_id': _googlePayUpiController.text.trim().isEmpty ? null : _googlePayUpiController.text.trim(),
                          'phonepay_upi_id': _phonePeUpiController.text.trim().isEmpty ? null : _phonePeUpiController.text.trim(),
                          'paytm_upi_id': _paytmUpiController.text.trim().isEmpty ? null : _paytmUpiController.text.trim(),
                          'bhim_upi_id': _bhimUpiController.text.trim().isEmpty ? null : _bhimUpiController.text.trim(),
                        };
                        
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PackageSelectionScreen(hospitalData: hospitalData),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'Select Package & Proceed to Payment',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
                const SizedBox(height: 15),

                // Back Button
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text(
                    'Back to Home | User Registration',
                    style: TextStyle(color: AppColors.primaryColor),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

}

