import 'app.dart';
import 'core/api_config.dart';
import 'core/demo_config.dart';
import 'core/invite_config.dart';
import 'package:flutter/material.dart';

void main() {
  _validateRuntimeConfig();
  runApp(const GuruMeetApp());
}

void _validateRuntimeConfig() {
  ApiConfig.apiBaseUrl;
  ApiConfig.enableMocks;
  InviteConfig.baseUrl;
  DemoConfig.isDemoMode;
  if (DemoConfig.isDemoMode) {
    DemoConfig.roomCode;
  }
}
