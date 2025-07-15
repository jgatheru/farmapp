import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class User {
  final String username;
  final String fullName;
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

  User? get currentUser => _currentUser;
  bool get isLoggedIn => _isLoggedIn;

  SessionProvider() {
    _loadUserFromPrefs(); // Load user session on startup
  }

  String? get token => _currentUser?.token;

  Future<void> _loadUserFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final userDataString = prefs.getString('userData');
    if (userDataString != null) {
      _currentUser = User.fromJson(jsonDecode(userDataString));
      _isLoggedIn = true;
    }
    notifyListeners(); // Notify widgets if user data was loaded
  }

  Future<void> login({
    required String username,
    required String fullName,
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
      isAgent: isAgent,
      userid: userid,
      employeeid: employeeid,
      token: token,
      avatar: avatar,
      email: email,
      levelid: levelid,
    );
    _isLoggedIn = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userData', jsonEncode(_currentUser!.toJson()));
    notifyListeners();
  }

  Future<void> logout() async {
    _currentUser = null;
    _isLoggedIn = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userData'); // Remove user data from preferences
    notifyListeners();
  }
}