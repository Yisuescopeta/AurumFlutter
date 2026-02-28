import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;

    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      context.go('/home');
    } else {
      context.go('/onboarding');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.navyBlue,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'A',
              style: GoogleFonts.playfairDisplay(
                fontSize: 96,
                fontWeight: FontWeight.bold,
                color: AppTheme.gold,
              ),
            ).animate().fadeIn(duration: 800.ms).scale(delay: 300.ms),
            const SizedBox(height: 16),
            Text(
              'AURUM',
              style: GoogleFonts.playfairDisplay(
                fontSize: 40,
                letterSpacing: 8,
                color: AppTheme.gold,
              ),
            ).animate().fadeIn(delay: 500.ms, duration: 800.ms),
            Text(
              'MODA MASCULINA',
              style: GoogleFonts.inter(
                fontSize: 14,
                letterSpacing: 4,
                color: AppTheme.gold.withOpacity(0.7),
              ),
            ).animate().fadeIn(delay: 1000.ms, duration: 800.ms),
          ],
        ),
      ),
    );
  }
}
