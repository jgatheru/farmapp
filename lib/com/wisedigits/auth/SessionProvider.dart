import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class User {
  final String username;
  final String fullName;
  final String role;
  final bool isAgent;
  final String userid;
  final String employeeid;
  final String token;
  final String? avatar; // Optional field
  final String email;
  final String levelid;

  User({
    required this.username,
    required this.fullName,
    required this.role,
    required this.isAgent,
    required this.userid,
    required this.employeeid,
    required this.token,
    this.avatar,
    required this.email,
    required this.levelid,
  });

  // Convert User object to JSON for SharedPreferences
  Map<String, dynamic> toJson() => {
    'username': username,
    'fullName': fullName,
    'rolw': role,
    'isAgent': isAgent,
    'userid': userid,
    'employeeid': employeeid,
    'token': token,
    'avatar': avatar,
    'email': email,
    'levelid': levelid,
  };

  // Create User object from JSON
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      username: json['username'],
      fullName: json['fullName'],
      role: json['role'],
      isAgent: json['isAgent'],
      userid: json['userid'],
      employeeid: json['employeeid'],
      token: json['token'],
      avatar: json['avatar'],
      email: json['email'],
      levelid: json['levelid'],
    );
  }
}

class SessionProvider with ChangeNotifier {
  User? _currentUser;
  bool _isLoggedIn = false;
  DateTime? _loginTimestamp; // Store login timestamp

  User? get currentUser => _currentUser;
  bool get isLoggedIn => _isLoggedIn;
  String? get token => _currentUser?.token;

  SessionProvider() {
    _loadUserFromPrefs(); // Load user session on startup
  }

  // Load user data and timestamp from SharedPreferences
  Future<void> _loadUserFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final userDataString = prefs.getString('userData');
    final loginTimestampString = prefs.getString('loginTimestamp');

    if (userDataString != null && loginTimestampString != null) {
      _currentUser = User.fromJson(jsonDecode(userDataString));
      _loginTimestamp = DateTime.parse(loginTimestampString);
      _isLoggedIn = await _isSessionValid();
      if (!_isLoggedIn) {
        await logout(); // Clear session if expired
      }
    }
    notifyListeners();
  }

  // Check if session is valid (before midnight of login day)
  Future<bool> _isSessionValid() async {
    if (_loginTimestamp == null) return false;

    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day, 23, 59, 59);

    // Session is valid if current time is before midnight of the login day
    return now.isBefore(midnight) && _loginTimestamp!.day == now.day;
  }

  // Login and save timestamp
  Future<void> login({
    required String username,
    required String fullName,
    required String role,
    required bool isAgent,
    required String userid,
    required String employeeid,
    required String token,
    String? avatar,
    required String email,
    required String levelid,
  }) async {
    _currentUser = User(
      username: username,
      fullName: fullName,
      role: role,
      isAgent: isAgent,
      userid: userid,
      employeeid: employeeid,
      token: token,
      avatar: avatar,
      email: email,
      levelid: levelid,
    );
    _isLoggedIn = true;
    _loginTimestamp = DateTime.now();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userData', jsonEncode(_currentUser!.toJson()));
    await prefs.setString('loginTimestamp', _loginTimestamp!.toIso8601String());
    notifyListeners();
  }

  // Logout and clear session data
  Future<void> logout() async {
    _currentUser = null;
    _isLoggedIn = false;
    _loginTimestamp = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userData');
    await prefs.remove('loginTimestamp');
    notifyListeners();
  }

  // Check session validity (used when app resumes)
  Future<void> checkSession() async {
    _isLoggedIn = await _isSessionValid();
    if (!_isLoggedIn) {
      await logout();
    }
    notifyListeners();
  }
}