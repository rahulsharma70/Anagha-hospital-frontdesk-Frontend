import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../utils/app_colors.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Profile Header
            CircleAvatar(
              radius: 50,
              backgroundColor: AppColors.primaryColor,
              child: Text(
                user?.name?.substring(0, 1).toUpperCase() ?? 'U',
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              user?.name ?? 'User',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              user?.role?.toUpperCase() ?? '',
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.textLight,
              ),
            ),
            const SizedBox(height: 30),

            // Profile Details
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildProfileRow(Icons.phone, 'Mobile', user?.mobile ?? ''),
                    const Divider(),
                    if (user?.addressLine1 != null)
                      _buildProfileRow(Icons.home, 'Address Line 1', user!.addressLine1!),
                    if (user?.addressLine2 != null) ...[
                      const Divider(),
                      _buildProfileRow(Icons.location_city, 'Address Line 2', user!.addressLine2!),
                    ],
                    if (user?.addressLine3 != null) ...[
                      const Divider(),
                      _buildProfileRow(Icons.pin_drop, 'Address Line 3', user!.addressLine3!),
                    ],
                    if (user?.companyName != null) ...[
                      const Divider(),
                      _buildProfileRow(Icons.business, 'Company', user!.companyName!),
                    ],
                    if (user?.degree != null) ...[
                      const Divider(),
                      _buildProfileRow(Icons.school, 'Degree', user!.degree!),
                    ],
                    if (user?.instituteName != null) ...[
                      const Divider(),
                      _buildProfileRow(Icons.account_balance, 'Institute', user!.instituteName!),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () async {
                  await authService.logout();
                  if (context.mounted) {
                    Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.errorColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Logout',
                  style: TextStyle(
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

  Widget _buildProfileRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primaryColor),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textLight,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}



