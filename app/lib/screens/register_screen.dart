import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../services/hospital_storage_service.dart';
import '../models/hospital_model.dart';
import 'dashboard_screen.dart';
import '../utils/app_colors.dart';
import 'dart:convert';
import 'hospital_register_screen.dart'; // Import this
import '../widgets/city_autocomplete.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _addressLine1Controller = TextEditingController();
  final _addressLine2Controller = TextEditingController();
  final _addressLine3Controller = TextEditingController();

  // Role-specific controllers
  final _companyNameController = TextEditingController();
  final _product1Controller = TextEditingController();
  final _product2Controller = TextEditingController();
  final _product3Controller = TextEditingController();
  final _product4Controller = TextEditingController();

  // Old doctor fields (keeping for backward compatibility)
  final _degreeController = TextEditingController();
  final _instituteController = TextEditingController();
  final _experience1Controller = TextEditingController();
  final _experience2Controller = TextEditingController();
  final _experience3Controller = TextEditingController();
  final _experience4Controller = TextEditingController();

  // New doctor fields
  final _doctorNameController = TextEditingController();
  final _placeController = TextEditingController();
  final _patientReferredNameController = TextEditingController();
  final _problemController = TextEditingController();
  final _patientMobileController = TextEditingController();
  final _refNoController = TextEditingController();

  String _selectedRole = 'pharma';
  int? _selectedHospitalId;
  List<Hospital> _hospitals = [];
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadHospitals();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _addressLine1Controller.dispose();
    _addressLine2Controller.dispose();
    _addressLine3Controller.dispose();
    _companyNameController.dispose();
    _product1Controller.dispose();
    _product2Controller.dispose();
    _product3Controller.dispose();
    _product4Controller.dispose();
    _degreeController.dispose();
    _instituteController.dispose();
    _experience1Controller.dispose();
    _experience2Controller.dispose();
    _experience3Controller.dispose();
    _experience4Controller.dispose();
    _doctorNameController.dispose();
    _placeController.dispose();
    _patientReferredNameController.dispose();
    _problemController.dispose();
    _patientMobileController.dispose();
    _refNoController.dispose();
    super.dispose();
  }

  Future<void> _loadHospitals() async {
    // First, load from local storage (always available)
    List<Hospital> localApproved = [];
    try {
      localApproved = await HospitalStorageService.getApprovedHospitals();
      print(
          'Loaded ${localApproved.length} approved hospitals from local storage');

      // Set local hospitals first
      setState(() {
        _hospitals = localApproved;
      });
    } catch (e) {
      print('Error loading from local storage: $e');
    }

    // Then try to load from API and merge
    try {
      final response = await ApiService.get('/api/hospitals/approved');
      if (response.statusCode == 200) {
        try {
          final responseText = response.body;
          if (responseText.isNotEmpty) {
            final List<dynamic> data = jsonDecode(responseText);
            final apiApproved =
                data.map((json) => Hospital.fromJson(json)).toList();
            print('Loaded ${apiApproved.length} approved hospitals from API');

            // Merge API and local storage (API takes precedence, but add local ones not in API)
            final mergedHospitals = <Hospital>[];
            final allIds = <int>{};

            // Add API hospitals first
            for (var hospital in apiApproved) {
              mergedHospitals.add(hospital);
              allIds.add(hospital.id);
            }

            // Add local hospitals that aren't in API
            for (var hospital in localApproved) {
              if (!allIds.contains(hospital.id)) {
                mergedHospitals.add(hospital);
              }
            }

            setState(() {
              _hospitals = mergedHospitals;
            });

            print('Total approved hospitals available: ${_hospitals.length}');
          }
        } catch (parseError) {
          print('Error parsing API response: $parseError');
          // Keep local storage data
        }
      } else {
        print('API returned status: ${response.statusCode}');
        // Keep local storage data
      }
    } catch (e) {
      print('Error loading hospitals from API: $e');
      // Keep local storage data already loaded
    }

    // Log final count
    print('Final approved hospitals count: ${_hospitals.length}');
    if (_hospitals.isEmpty) {
      print(
          '⚠️ No approved hospitals found! Make sure hospitals are approved first.');
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      Fluttertoast.showToast(
        msg: 'Passwords do not match',
        backgroundColor: AppColors.errorColor,
      );
      return;
    }

    if (_selectedRole == 'pharma' && _selectedHospitalId == null) {
      Fluttertoast.showToast(
        msg: 'Please select a hospital',
        backgroundColor: AppColors.errorColor,
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final userData = <String, dynamic>{
      'name': _nameController.text.trim(),
      'mobile': _mobileController.text.trim(),
      'role': _selectedRole,
      'password': _passwordController.text,
      'address_line1': _addressLine1Controller.text.trim().isEmpty
          ? null
          : _addressLine1Controller.text.trim(),
      'address_line2': _addressLine2Controller.text.trim().isEmpty
          ? null
          : _addressLine2Controller.text.trim(),
      'address_line3': _addressLine3Controller.text.trim().isEmpty
          ? null
          : _addressLine3Controller.text.trim(),
    };

    if (_selectedHospitalId != null) {
      userData['hospital_id'] = _selectedHospitalId;
    }

    // Pharma fields removed - now collected during appointment booking

    // Add doctor fields (new format)
    if (_selectedRole == 'doctor') {
      userData['doctor_name'] = _doctorNameController.text.trim();
      userData['place'] = _placeController.text.trim();
      userData['patient_referred_name'] =
          _patientReferredNameController.text.trim();
      userData['problem'] = _problemController.text.trim();
      userData['patient_mobile'] = _patientMobileController.text.trim();
      userData['ref_no'] = _refNoController.text.trim();
      // Keep old fields for backward compatibility
      userData['degree'] = _degreeController.text.trim();
      userData['institute_name'] = _instituteController.text.trim();
      userData['experience1'] = _experience1Controller.text.trim();
      userData['experience2'] = _experience2Controller.text.trim();
      userData['experience3'] = _experience3Controller.text.trim();
      userData['experience4'] = _experience4Controller.text.trim();
    }

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final success = await authService.register(userData);

      setState(() {
        _isLoading = false;
      });

      if (success && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const DashboardScreen()),
        );
        Fluttertoast.showToast(
          msg: 'Registration successful!',
          backgroundColor: AppColors.successColor,
        );
      } else if (mounted) {
        Fluttertoast.showToast(
          msg:
              'Registration failed. Please check your connection and try again.',
          backgroundColor: AppColors.errorColor,
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        Fluttertoast.showToast(
          msg: 'Registration error: ${e.toString()}',
          backgroundColor: AppColors.errorColor,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Register'),
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
                  'Create Account',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 30),

                // Role Selection
                DropdownButtonFormField<String>(
                  value: _selectedRole,
                  decoration: const InputDecoration(
                    labelText: 'Select Role',
                    prefixIcon: Icon(Icons.person),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'patient', child: Text('Patient')),
                    DropdownMenuItem(
                        value: 'pharma', child: Text('Pharma Professional')),
                    DropdownMenuItem(value: 'doctor', child: Text('Doctor')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedRole = value!;
                      _selectedHospitalId = null;
                    });
                  },
                ),
                const SizedBox(height: 20),

                // Hospital Selection (for Pharma)
                if (_selectedRole == 'pharma')
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              value: _selectedHospitalId,
                              decoration: const InputDecoration(
                                labelText: 'Select Hospital *',
                                prefixIcon: Icon(Icons.local_hospital),
                              ),
                              items: _hospitals.isEmpty
                                  ? [
                                      const DropdownMenuItem<int>(
                                        value: null,
                                        child: Text(
                                            'No approved hospitals available'),
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
                                        _selectedHospitalId = value;
                                      });
                                    },
                              validator: (value) {
                                if (_selectedRole == 'pharma' &&
                                    value == null) {
                                  return 'Please select a hospital';
                                }
                                return null;
                              },
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.refresh),
                            onPressed: _loadHospitals,
                            tooltip: 'Refresh hospitals',
                          ),
                        ],
                      ),
                      if (_hospitals.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0, left: 16.0),
                          child: InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                        const HospitalRegisterScreen()),
                              );
                            },
                            child: RichText(
                              text: TextSpan(
                                style: const TextStyle(
                                    fontSize: 12, color: AppColors.textLight),
                                children: [
                                  const TextSpan(
                                      text: 'No approved hospitals. '),
                                  TextSpan(
                                    text: 'Register a new hospital here.',
                                    style: TextStyle(
                                      color: AppColors.primaryColor,
                                      fontWeight: FontWeight.bold,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0, left: 16.0),
                          child: Row(
                            children: [
                              Text(
                                '${_hospitals.length} approved hospital(s) available. ',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textLight,
                                ),
                              ),
                              InkWell(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) =>
                                            const HospitalRegisterScreen()),
                                  );
                                },
                                child: Text(
                                  'Register New',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.primaryColor,
                                    fontWeight: FontWeight.bold,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                if (_selectedRole == 'pharma') const SizedBox(height: 20),

                // Basic Fields
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name *',
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _mobileController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Mobile Number *',
                    prefixIcon: Icon(Icons.phone),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your mobile number';
                    }
                    if (value.length != 10) {
                      return 'Please enter a valid 10-digit mobile number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password *',
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a password';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password *',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureConfirmPassword = !_obscureConfirmPassword;
                        });
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please confirm your password';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Address Fields
                TextFormField(
                  controller: _addressLine1Controller,
                  decoration: const InputDecoration(
                    labelText: 'Address Line 1',
                    prefixIcon: Icon(Icons.home),
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _addressLine2Controller,
                  decoration: const InputDecoration(
                    labelText: 'Address Line 2',
                    prefixIcon: Icon(Icons.location_city),
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _addressLine3Controller,
                  decoration: const InputDecoration(
                    labelText: 'Address Line 3',
                    prefixIcon: Icon(Icons.pin_drop),
                  ),
                ),
                const SizedBox(height: 20),

                // Pharma Professional Fields
                // Pharma fields removed - now collected during appointment booking in Book Pharma Appointment screen

                // Doctor Fields (New Format)
                if (_selectedRole == 'doctor') ...[
                  const Divider(),
                  const Text(
                    'Doctor Registration Details',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _doctorNameController,
                    decoration: const InputDecoration(
                      labelText: 'Name of Dr *',
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (value) {
                      if (_selectedRole == 'doctor' &&
                          (value == null || value.isEmpty)) {
                        return 'Please enter doctor name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  CityAutocomplete(
                    controller: _placeController,
                    labelText: 'Place - City Name *',
                    hintText: 'Start typing city name...',
                    prefixIcon: Icons.location_city,
                    validator: (value) {
                      if (_selectedRole == 'doctor' &&
                          (value == null || value.isEmpty)) {
                        return 'Please enter place/city name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _patientReferredNameController,
                    decoration: const InputDecoration(
                      labelText: 'Name of Patient Referred *',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (value) {
                      if (_selectedRole == 'doctor' &&
                          (value == null || value.isEmpty)) {
                        return 'Please enter patient referred name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _problemController,
                    decoration: const InputDecoration(
                      labelText: 'Problem *',
                      prefixIcon: Icon(Icons.medical_information),
                    ),
                    maxLines: 3,
                    validator: (value) {
                      if (_selectedRole == 'doctor' &&
                          (value == null || value.isEmpty)) {
                        return 'Please enter problem description';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _patientMobileController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Mobile no of patient *',
                      prefixIcon: Icon(Icons.phone),
                    ),
                    validator: (value) {
                      if (_selectedRole == 'doctor' &&
                          (value == null || value.isEmpty)) {
                        return 'Please enter patient mobile number';
                      }
                      if (value != null && value.length != 10) {
                        return 'Please enter a valid 10-digit mobile number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _refNoController,
                    decoration: const InputDecoration(
                      labelText: 'Ref No *',
                      prefixIcon: Icon(Icons.numbers),
                    ),
                    validator: (value) {
                      if (_selectedRole == 'doctor' &&
                          (value == null || value.isEmpty)) {
                        return 'Please enter reference number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                ],

                const SizedBox(height: 30),
                Container(
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: AppColors.gradientCta,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: AppColors.shadowSoft,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _isLoading ? null : _register,
                      borderRadius: BorderRadius.circular(12),
                      child: Center(
                        child: _isLoading
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2.5),
                              )
                            : const Text(
                                'Register',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text(
                    'Already have an account? Login',
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
