import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../services/doctor_service.dart';
import '../utils/app_colors.dart';

class AddDoctorDialog extends StatefulWidget {
  final String doctorName;
  final Function(
    String doctorName,
    String? mobile,
    String? email,
    String? degree,
    String? specialization,
    String? instituteName,
  ) onAdd;

  const AddDoctorDialog({
    super.key,
    required this.doctorName,
    required this.onAdd,
  });

  @override
  State<AddDoctorDialog> createState() => _AddDoctorDialogState();
}

class _AddDoctorDialogState extends State<AddDoctorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _doctorNameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _emailController = TextEditingController();
  final _degreeController = TextEditingController();
  final _specializationController = TextEditingController();
  final _instituteController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _doctorNameController.text = widget.doctorName;
  }

  @override
  void dispose() {
    _doctorNameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _degreeController.dispose();
    _specializationController.dispose();
    _instituteController.dispose();
    super.dispose();
  }

  Future<void> _handleAdd() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await widget.onAdd(
        _doctorNameController.text.trim(),
        _mobileController.text.trim().isEmpty ? null : _mobileController.text.trim(),
        _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        _degreeController.text.trim().isEmpty ? null : _degreeController.text.trim(),
        _specializationController.text.trim().isEmpty ? null : _specializationController.text.trim(),
        _instituteController.text.trim().isEmpty ? null : _instituteController.text.trim(),
      );

      if (mounted) {
        Navigator.of(context).pop(true);
        Fluttertoast.showToast(
          msg: 'Doctor added successfully!',
          backgroundColor: AppColors.successColor,
        );
      }
    } catch (e) {
      if (mounted) {
        Fluttertoast.showToast(
          msg: 'Error adding doctor: ${e.toString()}',
          backgroundColor: AppColors.errorColor,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add New Doctor'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _doctorNameController,
                decoration: const InputDecoration(
                  labelText: 'Doctor Name *',
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter doctor name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _mobileController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Mobile *',
                  prefixIcon: Icon(Icons.phone),
                ),
                maxLength: 10,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Mobile number is required';
                  }
                  if (value.length != 10) {
                    return 'Please enter a valid 10-digit mobile number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email (Optional)',
                  prefixIcon: Icon(Icons.email),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _degreeController,
                decoration: const InputDecoration(
                  labelText: 'Degree/Qualification *',
                  prefixIcon: Icon(Icons.school),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Degree is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _instituteController,
                decoration: const InputDecoration(
                  labelText: 'Institute Name *',
                  prefixIcon: Icon(Icons.apartment),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Institute name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _specializationController,
                decoration: const InputDecoration(
                  labelText: 'Specialization (Optional)',
                  prefixIcon: Icon(Icons.medical_services),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleAdd,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Add Doctor'),
        ),
      ],
    );
  }
}

class DoctorAutocomplete extends StatefulWidget {
  final TextEditingController controller;
  final String? labelText;
  final String? hintText;
  final IconData? prefixIcon;
  final String? Function(String?)? validator;
  final int? hospitalId; // Optional: filter by hospital

  const DoctorAutocomplete({
    super.key,
    required this.controller,
    this.labelText,
    this.hintText,
    this.prefixIcon,
    this.validator,
    this.hospitalId,
  });

  @override
  State<DoctorAutocomplete> createState() => _DoctorAutocompleteState();
}

class _DoctorAutocompleteState extends State<DoctorAutocomplete> {
  List<Map<String, dynamic>> _suggestions = [];
  bool _isLoading = false;
  bool _showSuggestions = false;
  String _lastQuery = '';
  final FocusNode _focusNode = FocusNode();
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _focusNode.removeListener(_onFocusChange);
    widget.controller.removeListener(_onTextChanged);
    _focusNode.dispose();
    _removeOverlay();
    super.dispose();
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      final query = widget.controller.text.trim();
      if (query.length >= 2) {
        _searchDoctors(query);
      }
    } else {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted && !_focusNode.hasFocus) {
          _removeOverlay();
        }
      });
    }
  }

  void _onTextChanged() {
    final query = widget.controller.text.trim();
    
    _debounceTimer?.cancel();
    
    if (query.isEmpty) {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
        _isLoading = false;
      });
      _removeOverlay();
      _lastQuery = '';
      return;
    }
    
    if (query.length < 2) {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
        _isLoading = false;
      });
      _removeOverlay();
      _lastQuery = query;
      return;
    }
    
    if (query == _lastQuery) {
      return;
    }
    
    _lastQuery = query;
    
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted && widget.controller.text.trim() == query) {
        _searchDoctors(query);
      }
    });
  }

  Future<void> _searchDoctors(String query) async {
    if (query.length < 2) {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
      });
      _removeOverlay();
      return;
    }

    setState(() {
      _isLoading = true;
      _showSuggestions = false;
    });
    _removeOverlay();

    try {
      print('Searching doctors for: $query');
      final doctors = await DoctorService.searchDoctors(query, hospitalId: widget.hospitalId);
      print('Found ${doctors.length} doctors');
      
      final currentText = widget.controller.text.trim();
      if (mounted && currentText == query && _focusNode.hasFocus) {
        setState(() {
          _suggestions = doctors;
          _isLoading = false;
          _showSuggestions = true;
        });
        _updateOverlay();
      }
    } catch (e) {
      print('Error in _searchDoctors: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _showSuggestions = false;
        });
      }
    }
  }

  void _selectDoctor(Map<String, dynamic> doctor) {
    widget.controller.text = doctor['doctor_name'] ?? '';
    _focusNode.unfocus();
    _removeOverlay();
    setState(() {
      _showSuggestions = false;
    });
  }

  Future<void> _showAddDoctorDialog() async {
    _removeOverlay();
    _focusNode.unfocus();
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AddDoctorDialog(
        doctorName: widget.controller.text.trim(),
        onAdd: (doctorName, mobile, email, degree, specialization, instituteName) async {
          try {
            if (widget.hospitalId == null) {
              throw Exception('Please select a hospital before adding a doctor');
            }
            final response = await DoctorService.addNewDoctor(
              doctorName: doctorName,
              mobile: mobile ?? '',
              email: email,
              degree: degree ?? '',
              specialization: specialization,
              instituteName: instituteName ?? '',
              hospitalId: widget.hospitalId!,
            );
            
            widget.controller.text = doctorName;
            
            return response;
          } catch (e) {
            throw Exception('Failed to add doctor: $e');
          }
        },
      ),
    );

    if (result == true && mounted) {
      final query = widget.controller.text.trim();
      if (query.length >= 2) {
        await _searchDoctors(query);
      }
    }
  }

  void _updateOverlay() {
    if (!mounted || !_focusNode.hasFocus) return;
    
    _removeOverlay();
    
    final hasText = widget.controller.text.trim().length >= 2;
    final shouldShow = _showSuggestions && (hasText || _suggestions.isNotEmpty);
    
    if (shouldShow) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _focusNode.hasFocus) {
          try {
            _overlayEntry = _createOverlay();
            Overlay.of(context).insert(_overlayEntry!);
          } catch (e) {
            print('Error creating overlay: $e');
          }
        }
      });
    }
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  OverlayEntry _createOverlay() {
    RenderBox renderBox = context.findRenderObject() as RenderBox;
    Size size = renderBox.size;

    return OverlayEntry(
      builder: (context) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0.0, size.height + 5.0),
          child: Material(
            elevation: 4.0,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.borderColor),
              ),
              child: _isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : _suggestions.isEmpty
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Text(
                                'No doctors found',
                                style: TextStyle(color: AppColors.textLight),
                              ),
                            ),
                            Divider(height: 1),
                            ListTile(
                              dense: true,
                              leading: const Icon(Icons.add_circle_outline, color: AppColors.primaryColor),
                              title: Text(
                                'Add "${widget.controller.text}" as new doctor',
                                style: const TextStyle(
                                  color: AppColors.primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              onTap: () => _showAddDoctorDialog(),
                              hoverColor: AppColors.primaryColor.withOpacity(0.1),
                            ),
                          ],
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: _suggestions.length,
                          itemBuilder: (context, index) {
                            final doctor = _suggestions[index];
                            final doctorName = doctor['doctor_name'] ?? '';
                            final place = doctor['place'] ?? '';
                            final degree = doctor['degree'] ?? '';
                            return ListTile(
                              dense: true,
                              leading: const Icon(Icons.person, color: AppColors.primaryColor),
                              title: Text(doctorName),
                              subtitle: place.isNotEmpty || degree.isNotEmpty
                                  ? Text('${place.isNotEmpty ? place : ''}${place.isNotEmpty && degree.isNotEmpty ? ' • ' : ''}${degree.isNotEmpty ? degree : ''}')
                                  : null,
                              onTap: () => _selectDoctor(doctor),
                              hoverColor: AppColors.primaryColor.withOpacity(0.1),
                            );
                          },
                        ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CompositedTransformTarget(
          link: _layerLink,
          child: TextFormField(
            controller: widget.controller,
            focusNode: _focusNode,
            decoration: InputDecoration(
              labelText: widget.labelText ?? 'Select Doctor *',
              hintText: widget.hintText ?? 'Start typing doctor name...',
              prefixIcon: widget.prefixIcon != null
                  ? Icon(widget.prefixIcon)
                  : const Icon(Icons.person),
              suffixIcon: _isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : widget.controller.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            widget.controller.clear();
                            _suggestions = [];
                            _removeOverlay();
                          },
                        )
                      : null,
            ),
            validator: widget.validator ??
                (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a doctor';
                  }
                  return null;
                },
            onTap: () {
              final text = widget.controller.text.trim();
              if (text.length >= 2) {
                _lastQuery = '';
                _searchDoctors(text);
              }
            },
          ),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 16.0, right: 16.0),
          child: Text(
            'Doctor database is crowdsourced. If doctor not found, you can add them.',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textLight,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }
}

