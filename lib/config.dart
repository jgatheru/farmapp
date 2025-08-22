// lib/config.dart

import 'package:flutter/material.dart';

class Config {
  static const String baseUrl = _isProduction
      ? 'http://213.136.81.123:8092/api'
      : 'http://213.136.81.123:8092/api';

  static const String sisiUrl = 'http://45.94.58.148/wisedigits_20230828/modules/api';

  static const bool _isProduction = false; // Toggle for environments

  static final Color themeColor = Colors.green;
  static final Color? backgroundColor = Colors.green[700];

  static const int system = 1;
  // static const String clientTitle = "Sisi Pharmaceuticals";
  static const String clientTitle = "Wonnie Farm";

}