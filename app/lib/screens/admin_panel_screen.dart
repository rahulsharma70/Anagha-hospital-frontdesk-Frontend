import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../services/api_service.dart';
import '../services/email_service.dart';
import '../services/hospital_storage_service.dart';
import '../models/hospital_model.dart';
import '../utils/app_colors.dart';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  List<Hospital> _pendingHospitals = [];
  List<Hospital> _approvedHospitals = [];
  bool _isLoading = false;
  int _selectedTab = 0; // 0 = Pending, 1 = Approved

  @override
  void initState() {
    super.initState();
    // Load hospitals immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadHospitals();
    });
  }

  Future<void> _loadHospitals() async {
    setState(() {
      _isLoading = true;
    });

    // First, load from local storage (always available)
    List<Hospital> localPending = [];
    List<Hospital> localApproved = [];
    
    try {
      localPending = await HospitalStorageService.getPendingHospitals();
      localApproved = await HospitalStorageService.getApprovedHospitals();
      
      print('Loaded from local storage - Pending: ${localPending.length}, Approved: ${localApproved.length}');
      
      setState(() {
        _pendingHospitals = localPending;
        _approvedHospitals = localApproved;
      });
    } catch (e) {
      print('Error loading from local storage: $e');
      setState(() {
        _pendingHospitals = [];
        _approvedHospitals = [];
      });
    }

    // Then try to load from API and merge
    try {
      // Load pending hospitals from API
      try {
        final pendingResponse = await ApiService.get('/api/hospitals/pending');
        if (pendingResponse.statusCode == 200) {
          final List<dynamic> pendingData = jsonDecode(pendingResponse.body);
          final apiPending = pendingData.map((json) => Hospital.fromJson(json)).toList();
          
          // Merge with local storage (API takes precedence)
          final mergedPending = <Hospital>[];
          final allIds = <int>{};
          
          // Add API hospitals first
          for (var hospital in apiPending) {
            mergedPending.add(hospital);
            allIds.add(hospital.id);
          }
          
          // Add local hospitals that aren't in API
          for (var hospital in localPending) {
            if (!allIds.contains(hospital.id)) {
              mergedPending.add(hospital);
            }
          }
          
          setState(() {
            _pendingHospitals = mergedPending;
          });
        }
      } catch (e) {
        print('Error loading pending hospitals from API: $e');
        // Keep local storage data
      }

      // Load approved hospitals from API
      try {
        final approvedResponse = await ApiService.get('/api/hospitals/approved');
        if (approvedResponse.statusCode == 200) {
          final List<dynamic> approvedData = jsonDecode(approvedResponse.body);
          final apiApproved = approvedData.map((json) => Hospital.fromJson(json)).toList();
          
          // Merge with local storage
          final mergedApproved = <Hospital>[];
          final allIds = <int>{};
          
          // Add API hospitals first
          for (var hospital in apiApproved) {
            mergedApproved.add(hospital);
            allIds.add(hospital.id);
          }
          
          // Add local hospitals that aren't in API
          for (var hospital in localApproved) {
            if (!allIds.contains(hospital.id)) {
              mergedApproved.add(hospital);
            }
          }
          
          setState(() {
            _approvedHospitals = mergedApproved;
          });
        }
      } catch (e) {
        print('Error loading approved hospitals from API: $e');
        // Keep local storage data
      }
    } catch (e) {
      print('Error loading hospitals from API: $e');
      // Keep local storage data already loaded
    } finally {
      setState(() {
        _isLoading = false;
      });
      
      // Log final counts for debugging
      print('Final counts - Pending: ${_pendingHospitals.length}, Approved: ${_approvedHospitals.length}');
    }
  }

  Future<void> _approveHospital(Hospital hospital) async {
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Hospital'),
        content: Text('Are you sure you want to approve ${hospital.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.successColor,
            ),
            child: const Text('Approve', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Show loading
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    try {
      // Try to call API to approve hospital
      bool apiSuccess = false;
      try {
        final response = await ApiService.put(
          '/api/hospitals/${hospital.id}/approve',
          {'status': 'approved'},
        );

        if (response.statusCode == 200 || response.statusCode == 204) {
          apiSuccess = true;
        }
      } catch (e) {
        print('API approval error: $e');
        // Continue to send email even if API fails
        apiSuccess = false;
      }

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
      }

      // Update local storage - move from pending to approved
      final approvedHospital = Hospital(
        id: hospital.id,
        name: hospital.name,
        email: hospital.email,
        mobile: hospital.mobile,
        status: 'approved',
        addressLine1: hospital.addressLine1,
        addressLine2: hospital.addressLine2,
        addressLine3: hospital.addressLine3,
        city: hospital.city,
        state: hospital.state,
        pincode: hospital.pincode,
        whatsappEnabled: hospital.whatsappEnabled,
        defaultUpiId: hospital.defaultUpiId,
        googlePayUpiId: hospital.googlePayUpiId,
        phonePeUpiId: hospital.phonePeUpiId,
        paytmUpiId: hospital.paytmUpiId,
        bhimUpiId: hospital.bhimUpiId,
        paymentQrCode: hospital.paymentQrCode,
      );
      
      await HospitalStorageService.saveApprovedHospital(approvedHospital);
      await HospitalStorageService.removePendingHospital(hospital.id);
      
      // Send confirmation email to hospital (always send, even if API fails)
      bool emailSent = false;
      try {
        emailSent = await EmailService.sendHospitalApprovalConfirmationEmail(
          hospitalName: hospital.name,
          hospitalEmail: hospital.email,
          hospitalMobile: hospital.mobile,
        );
      } catch (e) {
        print('Error sending confirmation email: $e');
      }

      if (mounted) {
        if (apiSuccess && emailSent) {
          Fluttertoast.showToast(
            msg: 'Hospital approved successfully! Confirmation email sent.',
            backgroundColor: AppColors.successColor,
            toastLength: Toast.LENGTH_LONG,
          );
        } else if (emailSent) {
          Fluttertoast.showToast(
            msg: 'Hospital approved! Confirmation email sent.',
            backgroundColor: AppColors.successColor,
            toastLength: Toast.LENGTH_LONG,
          );
        } else {
          Fluttertoast.showToast(
            msg: 'Hospital approved! Please verify email was sent.',
            backgroundColor: AppColors.warningColor,
            toastLength: Toast.LENGTH_LONG,
          );
        }
      }

      // Reload hospitals
      _loadHospitals();
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        Fluttertoast.showToast(
          msg: 'Error: ${e.toString()}',
          backgroundColor: AppColors.errorColor,
        );
      }
    }
  }

  Widget _buildHospitalCard(Hospital hospital, bool isPending) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    hospital.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
                if (isPending)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.warningColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Pending',
                      style: TextStyle(
                        color: AppColors.warningColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.successColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Approved',
                      style: TextStyle(
                        color: AppColors.successColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.tag, 'ID: ${hospital.id}'),
            _buildInfoRow(Icons.email, hospital.email),
            _buildInfoRow(Icons.phone, hospital.mobile),
            if (hospital.addressLine1 != null && hospital.addressLine1!.isNotEmpty)
              _buildInfoRow(Icons.location_on, hospital.addressLine1!),
            if (hospital.city != null && hospital.state != null)
              _buildInfoRow(Icons.map, '${hospital.city}, ${hospital.state}'),
            if (hospital.pincode != null && hospital.pincode!.isNotEmpty)
              _buildInfoRow(Icons.pin, 'PIN: ${hospital.pincode}'),
            if (hospital.defaultUpiId != null && hospital.defaultUpiId!.isNotEmpty)
              _buildInfoRow(Icons.account_balance_wallet, 'Default UPI: ${hospital.defaultUpiId}'),
            if (hospital.googlePayUpiId != null && hospital.googlePayUpiId!.isNotEmpty)
              _buildInfoRow(Icons.payment, 'Google Pay: ${hospital.googlePayUpiId}'),
            if (hospital.phonePeUpiId != null && hospital.phonePeUpiId!.isNotEmpty)
              _buildInfoRow(Icons.payment, 'PhonePe: ${hospital.phonePeUpiId}'),
            if (hospital.paytmUpiId != null && hospital.paytmUpiId!.isNotEmpty)
              _buildInfoRow(Icons.payment, 'Paytm: ${hospital.paytmUpiId}'),
            if (hospital.bhimUpiId != null && hospital.bhimUpiId!.isNotEmpty)
              _buildInfoRow(Icons.payment, 'BHIM: ${hospital.bhimUpiId}'),
            if (hospital.whatsappEnabled == true)
              _buildInfoRow(Icons.chat, 'WhatsApp: Enabled'),
            if (isPending) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _approveHospital(hospital),
                  icon: const Icon(Icons.check_circle, color: Colors.white),
                  label: const Text(
                    'Approve Hospital',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.successColor,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    if (text.isEmpty || text == 'N/A' || text == 'null') {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textLight),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String serverUrl = "127.0.0.1:8000";
    if (!kIsWeb) {
      if (Platform.isAndroid) {
        serverUrl = "10.0.2.2:8000";
      }
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadHospitals,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Navigator.pop(context);
            },
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.grey[200],
            width: double.infinity,
            child: Text(
              'Connected to: $serverUrl',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ),
          // Tab Bar
          Container(
            color: Colors.grey[100],
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _selectedTab = 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: _selectedTab == 0 ? AppColors.primaryColor : Colors.transparent,
                        border: Border(
                          bottom: BorderSide(
                            color: _selectedTab == 0 ? AppColors.primaryColor : Colors.transparent,
                            width: 3,
                          ),
                        ),
                      ),
                      child: Text(
                        'Pending (${_pendingHospitals.length})',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _selectedTab == 0 ? Colors.white : AppColors.textDark,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _selectedTab = 1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: _selectedTab == 1 ? AppColors.primaryColor : Colors.transparent,
                        border: Border(
                          bottom: BorderSide(
                            color: _selectedTab == 1 ? AppColors.primaryColor : Colors.transparent,
                            width: 3,
                          ),
                        ),
                      ),
                      child: Text(
                        'Approved (${_approvedHospitals.length})',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _selectedTab == 1 ? Colors.white : AppColors.textDark,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _selectedTab == 0
                    ? _pendingHospitals.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.inbox,
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No pending hospitals',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadHospitals,
                            child: ListView.builder(
                              itemCount: _pendingHospitals.length,
                              itemBuilder: (context, index) {
                                return _buildHospitalCard(_pendingHospitals[index], true);
                              },
                            ),
                          )
                    : _approvedHospitals.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.check_circle_outline,
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No approved hospitals',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadHospitals,
                            child: ListView.builder(
                              itemCount: _approvedHospitals.length,
                              itemBuilder: (context, index) {
                                return _buildHospitalCard(_approvedHospitals[index], false);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}
