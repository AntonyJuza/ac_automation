import 'package:flutter/material.dart';
import 'package:ac_automation/app.dart';

/// Set to true to run the app with a simulated BLE device (no hardware needed).
const bool kUseFakeBLE = true;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ACAutomationApp(useFakeBLE: kUseFakeBLE));
}
