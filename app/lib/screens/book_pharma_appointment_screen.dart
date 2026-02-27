import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../services/api_service.dart';
import '../services/payment_service.dart';
import '../services/auth_service.dart';
import '../services/doctor_service.dart';
import '../models/hospital_model.dart';
import '../utils/app_colors.dart';
import '../widgets/doctor_autocomplete.dart';
import '../widgets/city_autocomplete.dart';
import 'dart:convert';

class BookPharmaAppointmentScreen extends StatefulWidget {
  const BookPharmaAppointmentScreen({super.key});

  @override
  State<BookPharmaAppointmentScreen> createState() => _BookPharmaAppointmentScreenState();
}

class _BookPharmaAppointmentScreenState extends State<BookPharmaAppointmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _doctorController = TextEditingController();
  final _placeController = TextEditingController();
  final _timeController = TextEditingController();
  final _companyNameController = TextEditingController();
  final _product1Controller = TextEditingController();
  final _product2Controller = TextEditingController();
  final _product3Controller = TextEditingController();
  final _product4Controller = TextEditingController();
  
  DateTime _selectedDate = DateTime.now();
  String? _selectedAmPm = 'AM';
  Hospital? _selectedHospital;
  bool _isLoading = false;
  bool _showPaymentOptions = false;
  int? _paymentId;
  String? _paymentSessionId;
  int? _appointmentId;
  List<Hospital> _hospitals = [];
  Map<String, dynamic>? _selectedDoctor;
  int? _selectedDoctorId;

  @override
  void initState() {
    super.initState();
    _loadHospitals();
    // Listen to doctor controller changes to update doctor ID
    _doctorController.addListener(_onDoctorNameChanged);
  }
  
  void _onDoctorNameChanged() {
    final doctorName = _doctorController.text.trim();
    if (doctorName.isNotEmpty && _selectedDoctorId == null) {
      // Search for doctor when name is entered
      _onDoctorSelected(doctorName);
    } else if (doctorName.isEmpty) {
      setState(() {
        _selectedDoctorId = null;
        _selectedDoctor = null;
      });
    }
  }
  
  // Callback to handle doctor selection
  Future<void> _onDoctorSelected(String doctorName) async {
    // Search for doctor by name to get ID
    await _searchDoctorByName(doctorName);
  }
  
  Future<void> _searchDoctorByName(String doctorName) async {
    try {
      final doctors = await DoctorService.searchDoctors(doctorName);
      if (doctors.isNotEmpty) {
        final doctor = doctors.firstWhere(
          (d) => d['doctor_name']?.toString().toLowerCase() == doctorName.toLowerCase(),
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

  @override
  void dispose() {
    _doctorController.removeListener(_onDoctorNameChanged);
    _doctorController.dispose();
    _placeController.dispose();
    _timeController.dispose();
    _companyNameController.dispose();
    _product1Controller.dispose();
    _product2Controller.dispose();
    _product3Controller.dispose();
    _product4Controller.dispose();
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

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        final hour = picked.hour;
        final minute = picked.minute;
        _selectedAmPm = hour >= 12 ? 'PM' : 'AM';
        final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
        _timeController.text = '${displayHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
      });
    }
  }

  Future<void> _submitBooking() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final authService = Provider.of<AuthService>(context, listen: false);
    if (!authService.isAuthenticated || authService.user?.role != 'pharma') {
      Fluttertoast.showToast(
        msg: 'Only pharma professionals can book appointments',
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

    if (_selectedHospital == null) {
      Fluttertoast.showToast(
        msg: 'Please select a hospital',
        backgroundColor: AppColors.errorColor,
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Step 1: Create appointment
      final timeString = _timeController.text.trim();
      final timeSlot = timeString.contains(':') ? timeString.substring(0, 5) : timeString;
      final reasonParts = <String>[
        if (_companyNameController.text.trim().isNotEmpty) 'Company: ${_companyNameController.text.trim()}',
        if (_product1Controller.text.trim().isNotEmpty) 'Product 1: ${_product1Controller.text.trim()}',
        if (_product2Controller.text.trim().isNotEmpty) 'Product 2: ${_product2Controller.text.trim()}',
        if (_product3Controller.text.trim().isNotEmpty) 'Product 3: ${_product3Controller.text.trim()}',
        if (_product4Controller.text.trim().isNotEmpty) 'Product 4: ${_product4Controller.text.trim()}',
        if (_placeController.text.trim().isNotEmpty) 'Place: ${_placeController.text.trim()}',
      ];
      final reasonText = reasonParts.isNotEmpty ? reasonParts.join(' | ') : null;

      final appointmentResponse = await ApiService.post(
        '/api/appointments/book',
        {
          'doctor_id': _selectedDoctorId,
          'date': DateFormat('yyyy-MM-dd').format(_selectedDate),
          'time_slot': timeSlot,
          'reason': reasonText,
        },
        requiresAuth: true,
      );

      if (appointmentResponse.statusCode != 200 && appointmentResponse.statusCode != 201) {
        throw Exception('Failed to create appointment: ${appointmentResponse.body}');
      }

      final appointmentResult = jsonDecode(appointmentResponse.body);
      final appointmentId = appointmentResult['id'];

      // Step 2: Create payment order
      final paymentAmount = 500.0; // Fixed fee for pharma appointments
      final paymentOrderResponse = await PaymentService.createPaymentOrder(
        appointmentId: appointmentId,
        operationId: null,
        amount: paymentAmount,
        authToken: authService.token,
      );

      if (paymentOrderResponse == null) {
        throw Exception('Failed to create payment order');
      }

      // Step 3: Show payment options
      setState(() {
        _showPaymentOptions = true;
        _appointmentId = appointmentId as int?;
        _paymentId = paymentOrderResponse['payment_id'] as int?;
        _paymentSessionId = paymentOrderResponse['payment_session_id'] as String?;
        _isLoading = false;
      });

      Fluttertoast.showToast(
        msg: 'Please complete payment to confirm appointment',
        backgroundColor: AppColors.infoColor,
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      Fluttertoast.showToast(
        msg: 'Error booking appointment: $e',
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
        title: const Text('Book Pharma Appointment'),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!_showPaymentOptions) ...[
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

                // Place (City)
                CityAutocomplete(
                  controller: _placeController,
                  labelText: 'Place (Name of City) *',
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter place/city name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Hospital Selection
                DropdownButtonFormField<Hospital>(
                  value: _selectedHospital,
                  decoration: const InputDecoration(
                    labelText: 'Select Hospital *',
                    prefixIcon: Icon(Icons.local_hospital),
                  ),
                  items: _hospitals.map((hospital) {
                    return DropdownMenuItem(
                      value: hospital,
                      child: Text(hospital.name),
                    );
                  }).toList(),
                  onChanged: (hospital) {
                    setState(() {
                      _selectedHospital = hospital;
                      _doctorController.clear();
                      _selectedDoctorId = null;
                      _selectedDoctor = null;
                    });
                  },
                  validator: (value) {
                    if (value == null) {
                      return 'Please select a hospital';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Date Selection
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Select Date *',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TableCalendar(
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
                          calendarFormat: CalendarFormat.month,
                          startingDayOfWeek: StartingDayOfWeek.monday,
                          headerStyle: const HeaderStyle(
                            formatButtonVisible: false,
                            titleCentered: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Time Selection
                TextFormField(
                  controller: _timeController,
                  decoration: InputDecoration(
                    labelText: 'Time *',
                    prefixIcon: const Icon(Icons.access_time),
                    suffixIcon: DropdownButton<String>(
                      value: _selectedAmPm,
                      items: ['AM', 'PM'].map((ampm) {
                        return DropdownMenuItem(
                          value: ampm,
                          child: Text(ampm),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedAmPm = value;
                        });
                      },
                    ),
                  ),
                  readOnly: true,
                  onTap: _selectTime,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select time';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 30),

                // Pharma Professional Details
                const Divider(),
                const Text(
                  'Pharma Professional Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryColor,
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _companyNameController,
                  decoration: const InputDecoration(
                    labelText: 'Company Name *',
                    prefixIcon: Icon(Icons.business),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter company name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _product1Controller,
                  decoration: const InputDecoration(
                    labelText: 'Product 1 (for reminders if appointment cancelled by Dr)',
                    prefixIcon: Icon(Icons.inventory),
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _product2Controller,
                  decoration: const InputDecoration(
                    labelText: 'Product 2',
                    prefixIcon: Icon(Icons.inventory),
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _product3Controller,
                  decoration: const InputDecoration(
                    labelText: 'Product 3',
                    prefixIcon: Icon(Icons.inventory),
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _product4Controller,
                  decoration: const InputDecoration(
                    labelText: 'Product 4',
                    prefixIcon: Icon(Icons.inventory),
                  ),
                ),
                const SizedBox(height: 30),

                // Submit Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _submitBooking,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Book Appointment',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ] else ...[
                // Payment Section
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
                          'Complete Payment',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Amount: ₹500.00',
                          style: TextStyle(
                            fontSize: 18,
                            color: AppColors.textDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _openCashfreeCheckout,
                  icon: const Icon(Icons.payment),
                  label: const Text('Open Payment Gateway'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _isLoading ? null : _confirmPayment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.successColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'I Have Completed Payment',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Note: Once payment is done and appointment is booked, there will be no refund of the booking amount.',
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: AppColors.textLight,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

}

