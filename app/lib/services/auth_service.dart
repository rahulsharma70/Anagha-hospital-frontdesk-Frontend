import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import '../models/user_model.dart';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService extends ChangeNotifier {
  User? _user;
  String? _token;
  bool _isLoading = false;
  static const _storage = FlutterSecureStorage();

  User? get user => _user;
  String? get token => _token;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _token != null && _user != null;

  AuthService() {
    _loadUser();
  }

  Future<void> _loadUser() async {
    // Migrate to secure storage if still in shared prefs, then use secure storage
    final prefs = await SharedPreferences.getInstance();
    final oldToken = prefs.getString('auth_token');
    final oldUserJson = prefs.getString('user_data');

    if (oldToken != null) {
      // Migrate to secure storage
      await ApiService.saveToken(oldToken);
      if (oldUserJson != null) {
        await _storage.write(key: 'user_data', value: oldUserJson);
      }
      // Clean up old storage
      await prefs.remove('auth_token');
      await prefs.remove('user_data');
    }

    // Now read from secure storage
    _token = await ApiService.getToken();
    final userJson = await _storage.read(key: 'user_data');

    if (_token != null && userJson != null) {
      try {
        _user = User.fromJson(jsonDecode(userJson));
        notifyListeners();
      } catch (e) {
        print("Error parsing user data: $e");
        logout();
      }
    }
  }

  Future<bool> login(String mobile, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await ApiService.post('/api/users/login', {
        'mobile': mobile,
        'password': password,
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _token = data['access_token'];
        _user = User.fromJson(data['user']);

        // Save to secure storage
        await ApiService.saveToken(_token!);
        await _storage.write(key: 'user_data', value: jsonEncode(_user!.toJson()));

        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(Map<String, dynamic> userData) async {
    _isLoading = true;
    notifyListeners();

    try {
      final role = userData['role']?.toString().toLowerCase();
      final endpoint = (role == 'doctor') 
          ? '/api/users/register-doctor' 
          : '/api/users/register';
      
      final response = await ApiService.post(endpoint, userData);

      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          final data = jsonDecode(response.body);
          _token = data['access_token'];
          
          if (data['user'] != null) {
            _user = User.fromJson(data['user']);
          } else if (data['doctor'] != null) {
            final doctorData = data['doctor'];
            _user = User.fromJson({
              'id': doctorData['id'] ?? doctorData['user_id'],
              'name': doctorData['name'],
              'mobile': doctorData['mobile'],
              'role': 'doctor',
              'degree': doctorData['degree'],
              'institute_name': doctorData['institute_name'],
              'hospital_id': doctorData['hospital_id'],
            });
          }

          // Save to secure storage
          if (_token != null && _user != null) {
            await ApiService.saveToken(_token!);
            await _storage.write(key: 'user_data', value: jsonEncode(_user!.toJson()));

            _isLoading = false;
            notifyListeners();
            return true;
          } else {
            _isLoading = false;
            notifyListeners();
            return false;
          }
        } catch (parseError) {
          _isLoading = false;
          notifyListeners();
          return false;
        }
      } else {
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    _user = null;
    _token = null;

    await ApiService.removeToken();
    await _storage.delete(key: 'user_data');

    notifyListeners();
  }

  Future<User?> getCurrentUser() async {
    if (_user != null) return _user;

    try {
      final response = await ApiService.get('/api/users/me', requiresAuth: true);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _user = User.fromJson(data);
        // Update stored user data
        await _storage.write(key: 'user_data', value: jsonEncode(_user!.toJson()));
        notifyListeners();
        return _user;
      }
    } catch (e) {
      // Handle error
    }
    return null;
  }
}
