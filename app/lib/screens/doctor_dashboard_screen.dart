import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../models/appointment_model.dart';
import '../utils/app_colors.dart';
import 'dart:convert';

class DoctorDashboardScreen extends StatefulWidget {
  const DoctorDashboardScreen({super.key});

  @override
  State<DoctorDashboardScreen> createState() => _DoctorDashboardScreenState();
}

class _DoctorDashboardScreenState extends State<DoctorDashboardScreen> {
  List<Appointment> _appointments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAppointments();
  }

  Future<void> _loadAppointments() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await ApiService.get('/api/appointments/doctor-appointments', requiresAuth: true);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _appointments = data.map((json) => Appointment.fromJson(json)).toList();
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

  Future<void> _markVisited(int appointmentId, {DateTime? followupDate}) async {
    try {
      String url = '/api/appointments/$appointmentId/mark-visited';
      if (followupDate != null) {
        url += '?followup_date=${DateFormat('yyyy-MM-dd').format(followupDate)}';
      }

      final response = await ApiService.put(url, {}, requiresAuth: true);
      
      if (response.statusCode == 200) {
        _loadAppointments();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Appointment marked as visited')),
          );
        }
      }
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _showMarkVisitedDialog(Appointment appointment) async {
    DateTime? selectedFollowupDate;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark as Visited'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Patient: ${appointment.userName ?? "Unknown"}'),
            const SizedBox(height: 20),
            const Text('Set follow-up date (optional):'),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now().add(const Duration(days: 7)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (date != null) {
                  selectedFollowupDate = date;
                }
              },
              child: const Text('Select Follow-up Date'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _markVisited(appointment.id, followupDate: selectedFollowupDate);
            },
            child: const Text('Mark Visited'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.user;

    final pendingAppointments = _appointments.where((a) => a.status == 'pending' || a.status == 'confirmed').toList();
    final visitedAppointments = _appointments.where((a) => a.status == 'visited').toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Doctor Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await authService.logout();
              if (mounted) {
                Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Welcome Card
                  Card(
                    color: AppColors.primaryColor,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Dr. ${user?.name ?? "Doctor"}',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Manage your appointments',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Statistics
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Pending',
                          pendingAppointments.length.toString(),
                          AppColors.warningColor,
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: _buildStatCard(
                          'Visited',
                          visitedAppointments.length.toString(),
                          AppColors.successColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),

                  // Pending Appointments
                  const Text(
                    'Pending Appointments',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 15),
                  pendingAppointments.isEmpty
                      ? const Card(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: Center(child: Text('No pending appointments')),
                          ),
                        )
                      : Column(
                          children: pendingAppointments.map((appointment) {
                            return Card(
                              margin: const EdgeInsets.only(bottom: 15),
                              child: ListTile(
                                leading: const CircleAvatar(
                                  child: Icon(Icons.person),
                                ),
                                title: Text(appointment.userName ?? 'Patient'),
                                subtitle: Text(
                                  '${DateFormat('dd MMM yyyy').format(appointment.date)} at ${appointment.timeSlot}',
                                ),
                                trailing: ElevatedButton(
                                  onPressed: () => _showMarkVisitedDialog(appointment),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.successColor,
                                  ),
                                  child: const Text('Mark Visited'),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}



