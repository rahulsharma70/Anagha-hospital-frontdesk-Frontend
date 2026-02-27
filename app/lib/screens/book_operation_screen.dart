import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/payment_service.dart';
import '../services/auth_service.dart';
import '../services/doctor_service.dart';
import '../models/hospital_model.dart';
import '../utils/app_colors.dart';
import '../widgets/doctor_autocomplete.dart';
import '../widgets/city_autocomplete.dart';
import 'dart:convert';

class BookOperationScreen extends StatefulWidget {
  const BookOperationScreen({super.key});

  @override
  State<BookOperationScreen> createState() => _BookOperationScreenState();
}

class _BookOperationScreenState extends State<BookOperationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _doctorController = TextEditingController();
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _placeController = TextEditingController();
  final _timeController = TextEditingController();
  
  DateTime _selectedDate = DateTime.now();
  String? _selectedAmPm = 'AM';
  Hospital? _selectedHospital;
  bool _isLoading = false;
  bool _showPaymentOptions = false;
  int? _paymentId;
  String? _paymentSessionId;
  int? _operationId;
  Map<String, dynamic>? _selectedDoctor;
  int? _selectedDoctorId;
  String? _selectedSpecialty;
  List<Hospital> _hospitals = [];

  @override
  void initState() {
    super.initState();
    _loadHospitals();
    _doctorController.addListener(_onDoctorNameChanged);
  }

  @override
  void dispose() {
    _doctorController.removeListener(_onDoctorNameChanged);
    _doctorController.dispose();
    _nameController.dispose();
    _mobileController.dispose();
    _placeController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  Future<void> _loadHospitals() async {
    try {
      final response = await ApiService.get('/api/hospitals/approved');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _hospitals = data.map((json) => Hospital.fromJson(json)).toList();
          if (_hospitals.isNotEmpty) {
            _selectedHospital = _hospitals.first;
          }
        });
      }
    } catch (e) {
      print('Error loading hospitals: $e');
    }
  }

  void _onDoctorNameChanged() {
    final doctorName = _doctorController.text.trim();
    if (doctorName.isNotEmpty && _selectedDoctorId == null) {
      _onDoctorSelected(doctorName);
    } else if (doctorName.isEmpty) {
      setState(() {
        _selectedDoctorId = null;
        _selectedDoctor = null;
      });
    }
  }

  Future<void> _onDoctorSelected(String doctorName) async {
    await _searchDoctorByName(doctorName);
  }

  Future<void> _searchDoctorByName(String doctorName) async {
    try {
      final doctors = await DoctorService.searchDoctors(
        doctorName,
        hospitalId: _selectedHospital?.id,
      );
      if (doctors.isNotEmpty) {
        final doctor = doctors.firstWhere(
          (d) => d['name']?.toString().toLowerCase() == doctorName.toLowerCase(),
          orElse: () => doctors.first,
        );
        setState(() {
          _selectedDoctor = doctor;
          _selectedDoctorId = doctor['id'] as int?;
        });
      }
    } catch (e) {
      print('Error searching doctor: $e');
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

  Future<void> _proceedToPayment() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final authService = Provider.of<AuthService>(context, listen: false);
    if (!authService.isAuthenticated) {
      Fluttertoast.showToast(
        msg: 'Please login to book an operation',
        backgroundColor: AppColors.errorColor,
      );
      return;
    }

    if (_selectedDoctorId == null) {
      Fluttertoast.showToast(
        msg: 'Please select a doctor',
        backgroundColor: AppColors.errorColor,
      );
      return;
    }

    if (_selectedSpecialty == null || _selectedSpecialty!.isEmpty) {
      Fluttertoast.showToast(
        msg: 'Please select a specialty',
        backgroundColor: AppColors.errorColor,
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Step 1: Create operation
      final response = await ApiService.post(
        '/api/operations/book',
        {
          'doctor_id': _selectedDoctorId,
          'specialty': _selectedSpecialty,
          'date': DateFormat('yyyy-MM-dd').format(_selectedDate),
          'notes': _placeController.text.trim().isNotEmpty
              ? '${_placeController.text.trim()} ${_timeController.text.trim()} $_selectedAmPm'.trim()
              : null,
        },
        requiresAuth: true,
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to create operation: ${response.body}');
      }

      final operationResult = jsonDecode(response.body);
      final operationId = operationResult['id'];

      // Step 2: Create payment order
      final paymentAmount = PaymentService.calculateOperationFee(_selectedHospital?.id ?? 0, _selectedSpecialty);
      final paymentOrderResponse = await PaymentService.createPaymentOrder(
        appointmentId: null,
        operationId: operationId,
        amount: paymentAmount,
        authToken: authService.token,
      );

      if (paymentOrderResponse == null || paymentOrderResponse['payment_session_id'] == null) {
        throw Exception('Failed to create payment order. Please try again.');
      }

      setState(() {
        _operationId = operationId as int?;
        _paymentId = paymentOrderResponse['payment_id'] as int?;
        _paymentSessionId = paymentOrderResponse['payment_session_id'] as String?;
        _showPaymentOptions = true;
        _isLoading = false;
      });

      Fluttertoast.showToast(
        msg: 'Payment session created. Please complete payment.',
        backgroundColor: AppColors.infoColor,
      );
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

  Future<void> _confirmPayment() async {
    if (_paymentId == null) {
      Fluttertoast.showToast(
        msg: 'Payment not created. Please try again.',
        backgroundColor: AppColors.errorColor,
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final verified = await PaymentService.verifyPayment(
        _paymentId!,
        authToken: authService.token,
      );

      setState(() {
        _isLoading = false;
      });

      if (verified) {
        Fluttertoast.showToast(
          msg: 'Payment verified successfully!',
          backgroundColor: AppColors.successColor,
        );
        Navigator.pop(context);
      } else {
        Fluttertoast.showToast(
          msg: 'Payment is still pending. Please try again later.',
          backgroundColor: AppColors.warningColor,
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      Fluttertoast.showToast(
        msg: 'Error verifying payment: ${e.toString()}',
        backgroundColor: AppColors.errorColor,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Book Operation'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Patient Name
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name of Patient *',
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter patient name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Mobile Number
              TextFormField(
                controller: _mobileController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Mobile No *',
                  prefixIcon: Icon(Icons.phone),
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

              // Doctor Selection
              DoctorAutocomplete(
                controller: _doctorController,
                labelText: 'Select Doctor *',
                hintText: 'Start typing doctor name...',
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a doctor';
                  }
                  return null;
                },
                hospitalId: _selectedHospital?.id,
              ),
              const SizedBox(height: 20),

              // Specialty Selection
              DropdownButtonFormField<String>(
                value: _selectedSpecialty,
                decoration: const InputDecoration(
                  labelText: 'Select Specialty *',
                  prefixIcon: Icon(Icons.medical_services),
                ),
                items: const [
                  DropdownMenuItem(value: 'surgery', child: Text('Surgery')),
                  DropdownMenuItem(value: 'ortho', child: Text('Orthopedics')),
                  DropdownMenuItem(value: 'gyn', child: Text('Gynecology')),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedSpecialty = value;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a specialty';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Place (City Name) - Autocomplete
              CityAutocomplete(
                controller: _placeController,
                labelText: 'Place (Name of City) *',
                hintText: 'Start typing city name...',
                prefixIcon: Icons.location_city,
              ),
              const SizedBox(height: 20),

              // Calendar
              Card(
                child: TableCalendar(
                  firstDay: DateTime.now(),
                  lastDay: DateTime.now().add(const Duration(days: 365)),
                  focusedDay: _selectedDate,
                  selectedDayPredicate: (day) {
                    return isSameDay(_selectedDate, day);
                  },
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDate = selectedDay;
                    });
                  },
                  calendarStyle: const CalendarStyle(
                    selectedDecoration: BoxDecoration(
                      color: AppColors.primaryColor,
                      shape: BoxShape.circle,
                    ),
                    todayDecoration: BoxDecoration(
                      color: AppColors.secondaryColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  headerStyle: const HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // Time Selection (AM/PM)
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _timeController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Time *',
                        prefixIcon: Icon(Icons.access_time),
                        hintText: 'e.g., 10:30',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter time';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedAmPm,
                      decoration: const InputDecoration(
                        labelText: 'AM/PM *',
                        prefixIcon: Icon(Icons.schedule),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'AM', child: Text('AM')),
                        DropdownMenuItem(value: 'PM', child: Text('PM')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedAmPm = value;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),

              // Hospital Selection
              DropdownButtonFormField<int>(
                value: _selectedHospital?.id,
                decoration: const InputDecoration(
                  labelText: 'Select Hospital *',
                  prefixIcon: Icon(Icons.local_hospital),
                ),
                items: _hospitals.isEmpty
                    ? [
                        const DropdownMenuItem<int>(
                          value: null,
                          child: Text('No hospitals available'),
                          enabled: false,
                        )
                      ]
                    : _hospitals.map((hospital) {
                        return DropdownMenuItem<int>(
                          value: hospital.id,
                          child: Text(hospital.name),
                        );
                      }).toList(),
                onChanged: _hospitals.isEmpty
                    ? null
                    : (value) {
                        setState(() {
                          _selectedHospital = _hospitals.firstWhere((h) => h.id == value);
                          _showPaymentOptions = false;
                          _doctorController.clear();
                          _selectedDoctor = null;
                          _selectedDoctorId = null;
                        });
                      },
                validator: (value) {
                  if (value == null) {
                    return 'Please select a hospital';
                  }
                  return null;
                },
              ),
              if (_hospitals.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0, left: 16.0),
                  child: Text(
                    'No approved hospitals available. Please contact administrator.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.warningColor,
                    ),
                  ),
                ),
              const SizedBox(height: 30),

              // Payment Options Section
              if (_showPaymentOptions) ...[
                const Divider(),
                const SizedBox(height: 20),
                const Text(
                  'Payment - Cashfree',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Tap below to open the payment gateway.',
                  style: TextStyle(color: AppColors.textLight),
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
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.errorColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.errorColor.withOpacity(0.3)),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.warning, color: AppColors.errorColor, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Important Notice',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.errorColor,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 10),
                      Text(
                        'Once payment is done and operation is booked, there will be no refund of the booking amount.',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textDark,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
              ],

              // Proceed to Payment / Book Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : _showPaymentOptions
                          ? _confirmPayment
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
                          _showPaymentOptions ? 'I Have Completed Payment' : 'Proceed to Payment',
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
      ),
    );
  }
}

