import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../utils/app_colors.dart';
import '../services/payment_service.dart';
import 'hospital_register_screen.dart';

class PackageSelectionScreen extends StatefulWidget {
  final Map<String, dynamic> hospitalData;

  const PackageSelectionScreen({
    super.key,
    required this.hospitalData,
  });

  @override
  State<PackageSelectionScreen> createState() => _PackageSelectionScreenState();
}

class _PackageSelectionScreenState extends State<PackageSelectionScreen> {
  String? _selectedPackage;
  bool _isLoading = false;

  final Map<String, Map<String, dynamic>> _packages = {
    'small-clinic': {
      'name': 'Small Clinic',
      'installation_price': 5001,
      'monthly_price': 1111,
      'appointments': 50,
      'operations': 5,
      'pharma_appointments': 25,
      'color': Colors.blue,
    },
    'medium': {
      'name': 'Medium (≤5 Drs)',
      'installation_price': 11000,
      'monthly_price': 2111,
      'appointments': 200,
      'operations': 20,
      'pharma_appointments': 100,
      'color': Colors.purple,
    },
    'corporate': {
      'name': 'Corporate',
      'installation_price': 21000,
      'monthly_price': 5111,
      'appointments': 1000,
      'operations': 100,
      'pharma_appointments': 500,
      'color': Colors.orange,
    },
  };

  Future<void> _proceedToPayment() async {
    if (_selectedPackage == null) {
      Fluttertoast.showToast(
        msg: 'Please select a package',
        backgroundColor: AppColors.errorColor,
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final package = _packages[_selectedPackage!]!;
      // For hospital registration, we charge installation fee (one-time)
      final amount = package['installation_price'] as double;

      // Create payment order
      final paymentOrderResponse = await PaymentService.createHospitalRegistrationOrder(
        planName: package['name'] as String,
        amount: amount,
        customerName: widget.hospitalData['name'] ?? '',
        customerPhone: widget.hospitalData['mobile'] ?? '',
        customerEmail: widget.hospitalData['email'] ?? '',
      );

      if (paymentOrderResponse == null || paymentOrderResponse['payment_session_id'] == null) {
        throw Exception('Failed to create payment order');
      }

      final paymentId = paymentOrderResponse['payment_id'] as int?;
      final paymentSessionId = paymentOrderResponse['payment_session_id'] as String?;

      setState(() {
        _isLoading = false;
      });

      // Navigate to payment screen with order ID
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => HospitalRegisterScreen(
              initialPaymentId: paymentId,
              initialPaymentSessionId: paymentSessionId,
              selectedPackage: _selectedPackage!,
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      Fluttertoast.showToast(
        msg: 'Error creating payment order: ${e.toString()}',
        backgroundColor: AppColors.errorColor,
      );
    }
  }

  Widget _buildPackageCard(String packageKey, Map<String, dynamic> package) {
    final isSelected = _selectedPackage == packageKey;
    final color = package['color'] as Color;
    final installationPrice = package['installation_price'] as int;
    final monthlyPrice = package['monthly_price'] as int;

    return Card(
      elevation: isSelected ? 6 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(
          color: isSelected ? color : Colors.transparent,
          width: isSelected ? 3 : 0,
        ),
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedPackage = packageKey;
          });
        },
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.star, color: color, size: 30),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          package['name'] as String,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                        if (isSelected)
                          const Text(
                            'Selected',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.successColor,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    Icon(Icons.check_circle, color: color, size: 30),
                ],
              ),
              const SizedBox(height: 20),
              _buildFeatureRow('Appointments', '${package['appointments']}/month'),
              const SizedBox(height: 10),
              _buildFeatureRow('Operations', '${package['operations']}/month'),
              const SizedBox(height: 10),
              _buildFeatureRow('Pharma Appointments', '${package['pharma_appointments']}/month'),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 15),
              // Show installation and monthly pricing
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'One-Time License:',
                        style: TextStyle(fontSize: 14, color: AppColors.textLight),
                      ),
                      Text(
                        '₹${installationPrice.toString()}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Monthly Maintenance:',
                        style: TextStyle(fontSize: 14, color: AppColors.textLight),
                      ),
                      Text(
                        '₹${monthlyPrice.toString()}/month',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildFeatureRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.textLight),
        ),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Package'),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Choose Your Package',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Select a package that suits your hospital\'s needs',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textLight,
              ),
            ),
            const SizedBox(height: 30),
            ..._packages.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: _buildPackageCard(entry.key, entry.value),
              );
            }),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading || _selectedPackage == null
                    ? null
                    : _proceedToPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        _selectedPackage == null
                            ? 'Select Package'
                            : 'Proceed to Payment',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

