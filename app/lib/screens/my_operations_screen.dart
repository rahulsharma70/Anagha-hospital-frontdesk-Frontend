import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../utils/app_colors.dart';
import 'dart:convert';

class Operation {
  final int id;
  final int patientId;
  final String specialty;
  final DateTime date; // Backend returns 'date' (mapped from 'operation_date')
  final int doctorId;
  final int hospitalId; // Required (not nullable)
  final String status;
  final String? notes; // Backend returns 'notes' for operations
  final DateTime createdAt;
  final String? patientName;
  final String? doctorName;
  final String? hospitalName; // Hospital name from backend

  Operation({
    required this.id,
    required this.patientId,
    required this.specialty,
    required this.date,
    required this.doctorId,
    required this.hospitalId, // Required now
    required this.status,
    this.notes,
    required this.createdAt,
    this.patientName,
    this.doctorName,
    this.hospitalName,
  });

  factory Operation.fromJson(Map<String, dynamic> json) {
    // Backend returns 'date' (mapped from 'operation_date' in DB)
    // Handle both 'date' and 'operation_date' for backward compatibility
    String dateStr = json['date'] ?? json['operation_date'] ?? DateTime.now().toIso8601String();
    
    return Operation(
      id: json['id'],
      patientId: json['patient_id'],
      specialty: json['specialty'] ?? '',
      date: DateTime.parse(dateStr),
      doctorId: json['doctor_id'],
      hospitalId: json['hospital_id'] ?? 0, // Default to 0 if null (should not happen)
      status: json['status'] ?? 'pending',
      notes: json['notes'], // Backend returns 'notes', not 'reason'
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      patientName: json['patient_name'],
      doctorName: json['doctor_name'],
      hospitalName: json['hospital_name'], // Backend returns 'hospital_name'
    );
  }
}

class MyOperationsScreen extends StatefulWidget {
  const MyOperationsScreen({super.key});

  @override
  State<MyOperationsScreen> createState() => _MyOperationsScreenState();
}

class _MyOperationsScreenState extends State<MyOperationsScreen> {
  List<Operation> _operations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOperations();
  }

  Future<void> _loadOperations() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await ApiService.get('/api/operations/my-operations', requiresAuth: true);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _operations = data.map((json) => Operation.fromJson(json)).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return AppColors.successColor;
      case 'pending':
        return AppColors.warningColor;
      case 'cancelled':
        return AppColors.errorColor;
      case 'completed':
        return AppColors.infoColor;
      default:
        return AppColors.textLight;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Operations'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadOperations,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _operations.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.medical_services, size: 80, color: AppColors.textLight),
                      const SizedBox(height: 20),
                      const Text(
                        'No Operations',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textLight,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadOperations,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(15),
                    itemCount: _operations.length,
                    itemBuilder: (context, index) {
                      final operation = _operations[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 15),
                        child: Padding(
                          padding: const EdgeInsets.all(15),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      operation.doctorName ?? 'Doctor',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(operation.status).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      operation.status.toUpperCase(),
                                      style: TextStyle(
                                        color: _getStatusColor(operation.status),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 15),
                              _buildInfoRow(Icons.medical_services, 'Specialty', operation.specialty.toUpperCase()),
                              const SizedBox(height: 10),
                              _buildInfoRow(Icons.calendar_today, 'Date', DateFormat('dd MMM yyyy').format(operation.date)),
                              if (operation.notes != null && operation.notes!.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                _buildInfoRow(Icons.note, 'Notes', operation.notes!),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textLight),
        const SizedBox(width: 10),
        Text(
          '$label: ',
          style: const TextStyle(color: AppColors.textLight),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
        ),
      ],
    );
  }
}



