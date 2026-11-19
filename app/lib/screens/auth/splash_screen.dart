import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/api_service.dart';
import '../../theme/app_colors.dart';

/// Screen 1 of the list. Design: navy page, "Welcome", "Tap to Continue.....".
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  Future<void> _continue(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final seenOnboarding = prefs.getBool('onboarding_seen') ?? false;
    if (!context.mounted) return;
    String route;
    if (!seenOnboarding) {
      route = '/onboarding';
    } else if (ApiService.instance.isLoggedIn) {
      route = '/home';
    } else {
      route = '/login';
    }
    Navigator.of(context).pushReplacementNamed(route);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _continue(context),
        child: SafeArea(
          child: Column(
            children: [
              const Expanded(
                child: Center(
                  child: Text(
                    'Welcome',
                    style: TextStyle(
                      fontFamily: 'casual',
                      fontSize: 56,
                      fontWeight: FontWeight.bold,
                      color: AppColors.snow,
                    ),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 28),
                child: Text(
                  'Tap to Continue.....',
                  style: TextStyle(
                    fontFamily: 'cursive',
                    fontStyle: FontStyle.italic,
                    fontSize: 24,
                    color: AppColors.snow,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
