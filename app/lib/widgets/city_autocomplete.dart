import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../services/city_service.dart';
import '../utils/app_colors.dart';

class AddCityDialog extends StatefulWidget {
  final String cityName;
  final Function(String cityName, String? stateName, String? districtName, String? pincode) onAdd;

  const AddCityDialog({
    super.key,
    required this.cityName,
    required this.onAdd,
  });

  @override
  State<AddCityDialog> createState() => _AddCityDialogState();
}

class _AddCityDialogState extends State<AddCityDialog> {
  final _formKey = GlobalKey<FormState>();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _districtController = TextEditingController();
  final _pincodeController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _cityController.text = widget.cityName;
  }

  @override
  void dispose() {
    _cityController.dispose();
    _stateController.dispose();
    _districtController.dispose();
    _pincodeController.dispose();
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
        _cityController.text.trim(),
        _stateController.text.trim().isEmpty ? null : _stateController.text.trim(),
        _districtController.text.trim().isEmpty ? null : _districtController.text.trim(),
        _pincodeController.text.trim().isEmpty ? null : _pincodeController.text.trim(),
      );

      if (mounted) {
        Navigator.of(context).pop(true);
        Fluttertoast.showToast(
          msg: 'City added successfully!',
          backgroundColor: AppColors.successColor,
        );
      }
    } catch (e) {
      if (mounted) {
        Fluttertoast.showToast(
          msg: 'Error adding city: ${e.toString()}',
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
      title: const Text('Add New City'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _cityController,
                decoration: const InputDecoration(
                  labelText: 'City Name *',
                  prefixIcon: Icon(Icons.location_city),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter city name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _stateController,
                decoration: const InputDecoration(
                  labelText: 'State (Optional)',
                  prefixIcon: Icon(Icons.map),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _districtController,
                decoration: const InputDecoration(
                  labelText: 'District (Optional)',
                  prefixIcon: Icon(Icons.location_on),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _pincodeController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Pincode (Optional)',
                  prefixIcon: Icon(Icons.pin),
                ),
                maxLength: 10,
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
              : const Text('Add City'),
        ),
      ],
    );
  }
}

class CityAutocomplete extends StatefulWidget {
  final TextEditingController controller;
  final String? labelText;
  final String? hintText;
  final IconData? prefixIcon;
  final String? Function(String?)? validator;
  final TextEditingController? stateController; // Optional state controller to auto-fill
  final Function(String? stateName)? onCitySelected; // Callback when city is selected

  const CityAutocomplete({
    super.key,
    required this.controller,
    this.labelText,
    this.hintText,
    this.prefixIcon,
    this.validator,
    this.stateController,
    this.onCitySelected,
  });

  @override
  State<CityAutocomplete> createState() => _CityAutocompleteState();
}

class _CityAutocompleteState extends State<CityAutocomplete> {
  List<Map<String, dynamic>> _suggestions = []; // Changed to support Map format with city_name and state_name
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
        _searchCities(query);
      } else if (query.isEmpty) {
        _loadPopularCities();
      }
    } else {
      // Delay removal to allow tap on suggestion
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted && !_focusNode.hasFocus) {
          _removeOverlay();
        }
      });
    }
  }

  void _onTextChanged() {
    final query = widget.controller.text.trim();
    
    // Cancel previous timer
    _debounceTimer?.cancel();
    
    if (query.isEmpty) {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
        _isLoading = false;
      });
      _removeOverlay();
      _lastQuery = '';
      if (_focusNode.hasFocus) {
        _loadPopularCities();
      }
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
    
    // Only search if query changed
    if (query == _lastQuery) {
      return;
    }
    
    _lastQuery = query;
    
    // Debounce: Wait 300ms after user stops typing (reduced to 200ms for better responsiveness)
    _debounceTimer = Timer(const Duration(milliseconds: 200), () {
      final currentText = widget.controller.text.trim();
      if (mounted && currentText == query && _focusNode.hasFocus) {
        _searchCities(query);
      }
    });
  }

  Future<void> _loadPopularCities() async {
    if (!_focusNode.hasFocus) return;
    
    setState(() {
      _isLoading = true;
      _showSuggestions = false;
    });
    _removeOverlay();

    try {
      final cityNames = await CityService.getPopularCities();
      // Convert to map format for consistency
      final cities = cityNames.map((name) => <String, dynamic>{'city_name': name, 'state_name': ''}).toList();
      if (mounted && _focusNode.hasFocus && widget.controller.text.isEmpty) {
        setState(() {
          _suggestions = cities;
          _isLoading = false;
          _showSuggestions = cities.isNotEmpty;
        });
        if (_showSuggestions) {
          _updateOverlay();
        }
      }
    } catch (e) {
      print('Error loading popular cities: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _showSuggestions = false;
        });
      }
    }
  }

  Future<void> _searchCities(String query) async {
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
      print('Searching cities for: $query');
      final cities = await CityService.searchCities(query);
      print('Found ${cities.length} cities');
      
      final currentText = widget.controller.text.trim();
      if (mounted && currentText == query && _focusNode.hasFocus) {
        setState(() {
          _suggestions = cities;
          _isLoading = false;
          _showSuggestions = true; // Always show overlay (for "Add new city" option)
        });
        _updateOverlay(); // Always update overlay (shows suggestions or "Add new city")
      }
    } catch (e) {
      print('Error in _searchCities: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _showSuggestions = false;
        });
      }
    }
  }

  void _selectCity(Map<String, dynamic> city) {
    // Extract city name and state name from map
    final cityName = city['city_name']?.toString() ?? '';
    final stateName = city['state_name']?.toString();
    
    widget.controller.text = cityName;
    
    // Auto-fill state if stateController is provided
    if (widget.stateController != null && stateName != null && stateName.isNotEmpty) {
      widget.stateController!.text = stateName;
    }
    
    // Call callback if provided
    if (widget.onCitySelected != null) {
      widget.onCitySelected!(stateName);
    }
    
    _focusNode.unfocus();
    _removeOverlay();
    setState(() {
      _showSuggestions = false;
    });
  }

  Future<void> _showAddCityDialog() async {
    _removeOverlay();
    _focusNode.unfocus();
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AddCityDialog(
        cityName: widget.controller.text.trim(),
        onAdd: (cityName, stateName, districtName, pincode) async {
          try {
            final response = await CityService.addNewCity(
              cityName: cityName,
              stateName: stateName,
              districtName: districtName,
              pincode: pincode,
            );
            
            // Update the controller with the added city
            widget.controller.text = cityName;
            
            return response;
          } catch (e) {
            throw Exception('Failed to add city: $e');
          }
        },
      ),
    );

    if (result == true && mounted) {
      // City was added successfully, refresh suggestions
      final query = widget.controller.text.trim();
      if (query.length >= 2) {
        await _searchCities(query);
      }
    }
  }

  void _updateOverlay() {
    if (!mounted || !_focusNode.hasFocus) return;
    
    _removeOverlay();
    
    // Show overlay if:
    // 1. We have suggestions, OR
    // 2. We have no suggestions but user has typed something (for "Add new city" option)
    final hasText = widget.controller.text.trim().length >= 2;
    final shouldShow = (_showSuggestions && _suggestions.isNotEmpty) || 
                       (_showSuggestions && _suggestions.isEmpty && hasText && !_isLoading);
    
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
                                'No cities found',
                                style: TextStyle(color: AppColors.textLight),
                              ),
                            ),
                            Divider(height: 1),
                            ListTile(
                              dense: true,
                              leading: const Icon(Icons.add_circle_outline, color: AppColors.primaryColor),
                              title: Text(
                                'Add "${widget.controller.text}" as new city',
                                style: const TextStyle(
                                  color: AppColors.primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              onTap: () => _showAddCityDialog(),
                              hoverColor: AppColors.primaryColor.withOpacity(0.1),
                            ),
                          ],
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: _suggestions.length,
                          itemBuilder: (context, index) {
                            final city = _suggestions[index];
                            // Extract city name and state name from map
                            final cityName = city['city_name']?.toString() ?? '';
                            final stateName = city['state_name']?.toString();
                            
                            return ListTile(
                              dense: true,
                              title: Text(cityName),
                              subtitle: stateName != null && stateName.isNotEmpty 
                                  ? Text(stateName, style: const TextStyle(fontSize: 12, color: AppColors.textLight))
                                  : null,
                              onTap: () => _selectCity(city),
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
              labelText: widget.labelText ?? 'Place (Name of City) *',
              hintText: widget.hintText ?? 'Start typing city name...',
              prefixIcon: widget.prefixIcon != null
                  ? Icon(widget.prefixIcon)
                  : const Icon(Icons.location_city),
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
                    return 'Please enter city name';
                  }
                  return null;
                },
            onTap: () {
              if (widget.controller.text.isEmpty) {
                _loadPopularCities();
              } else if (widget.controller.text.length >= 2) {
                _lastQuery = ''; // Reset to force search
                _searchCities(widget.controller.text.trim());
              }
            },
          ),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 16.0, right: 16.0),
          child: Text(
            'The city autocomplete feature is powered by publicly available government datasets that are indexed internally for fast and reliable search.',
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

