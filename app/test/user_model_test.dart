import 'package:flutter_test/flutter_test.dart';
import 'package:anagha_hospital/models/user_model.dart';

void main() {
  group('User Model Tests', () {
    test('User.fromJson creates a valid object', () {
      final Map<String, dynamic> json = {
        'id': 1,
        'name': 'Test User',
        'mobile': '1234567890',
        'role': 'patient',
        'address_line1': '123 Main St',
        'address_line2': null,
        'address_line3': null,
        'hospital_id': null,
      };

      final user = User.fromJson(json);

      expect(user.id, 1);
      expect(user.name, 'Test User');
      expect(user.mobile, '1234567890');
      expect(user.role, 'patient');
      expect(user.addressLine1, '123 Main St');
      expect(user.addressLine2, isNull);
    });

    test('User.toJson returns a valid map', () {
      final user = User(
        id: 2,
        name: 'Doctor Who',
        mobile: '9876543210',
        role: 'doctor',
        degree: 'MD',
        instituteName: 'Gallifrey Medical',
      );

      final json = user.toJson();

      expect(json['id'], 2);
      expect(json['name'], 'Doctor Who');
      expect(json['mobile'], '9876543210');
      expect(json['role'], 'doctor');
      expect(json['degree'], 'MD');
      expect(json['institute_name'], 'Gallifrey Medical');
      expect(json['hospital_id'], isNull);
    });
  });
}
