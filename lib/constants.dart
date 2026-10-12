import 'package:naija_go/theme/app_theme.dart';
// lib/constants.dart
// This file holds constant values, such as your backend API base URL.

import 'package:flutter/material.dart';

// Backend API Base URL. Override locally with:
// --dart-define=API_BASE_URL=http://10.0.2.2:5000
const String baseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://naijago-backend.onrender.com',
);
const String customerSupportWhatsAppUrl = 'https://wa.me/7044332895';
const String customerSupportPhoneNumber = '7044332895';
const String serverConnectionHelpMessage =
    'Connecting to server…\n'
    '• Check your internet connection.\n'
    '• Wait a moment, then try again.\n'
    '• Tap Retry if this continues.';

// Cloudinary Config
const String cloudinaryUploadUrl =
    'https://api.cloudinary.com/v1_1/dbwxnt91x/image/upload';
const String cloudinaryUploadPreset =
    'unsigned_preset_here'; // Replace with your actual unsigned preset

// Colors
const Color primaryNavy = AppTheme.primaryNavy;
const Color secondaryBlack = AppTheme.secondaryBlack;
const Color accentGreen = AppTheme.brightBlue;
const Color softGrey = AppTheme.softGrey;
const Color lightGrey = Color(0xFF9E9E9E);
const Color white = Colors.white;
