import 'package:flutter/material.dart';
import 'package:ac_automation/utils/constants.dart';
import 'package:ac_automation/screens/home_screen.dart';
import 'package:ac_automation/screens/control_screen.dart';
import 'package:ac_automation/screens/setup_screen.dart';
import 'package:ac_automation/screens/learn_screen.dart';
import 'package:go_router/go_router.dart';

import 'package:provider/provider.dart';
import 'package:ac_automation/services/ac_provider.dart';
import 'package:ac_automation/services/ble_service.dart';

class ACAutomationApp extends StatelessWidget {
  const ACAutomationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ACProvider()),
        ChangeNotifierProvider(create: (_) => BLEService()),
      ],
      child: Builder(
        builder: (context) {
          final GoRouter router = GoRouter(
            initialLocation: '/',
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const HomeScreen(),
              ),
              GoRoute(
                path: '/control',
                builder: (context, state) => const ControlScreen(),
              ),
              GoRoute(
                path: '/setup',
                builder: (context, state) => const SetupScreen(),
              ),
              GoRoute(
                path: '/learn',
                builder: (context, state) {
                  final extra = state.extra as Map<String, dynamic>;
                  return LearnScreen(
                    name: extra['name'],
                    brand: extra['brand'],
                    model: extra['model'],
                  );
                },
              ),
            ],
          );

          return MaterialApp.router(
      title: 'AC Automation',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.primaryBackground,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primaryBrand,
          primary: AppColors.primaryBrand,
          secondary: AppColors.secondaryAccent,
          surface: AppColors.primaryBackground,
          onSurface: AppColors.textPrimary,
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
          bodyLarge: TextStyle(color: AppColors.textPrimary),
          bodyMedium: TextStyle(color: AppColors.textSecondary),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.primaryBackground,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      routerConfig: router,
          );
        },
      ),
    );
  }
}
