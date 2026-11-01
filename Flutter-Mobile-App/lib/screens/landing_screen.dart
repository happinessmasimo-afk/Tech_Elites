import 'package:flutter/material.dart';
import '../config/theme.dart';
import 'login_screen.dart';
import 'marketplace_screen.dart';
import 'register_screen.dart';

/// Matches the original app's app/(auth)/index.tsx: full-bleed hero image,
/// a dark overlay for legibility, and three actions stacked at the bottom.
class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/hero.jpg', fit: BoxFit.cover),
          Container(color: Colors.black.withOpacity(0.15)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.white,
                      foregroundColor: AppColors.brandGreenDark,
                    ),
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoginScreen())),
                    child: Text('Login', style: AppFonts.headingSemibold(color: AppColors.brandGreenDark)),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.white,
                      side: const BorderSide(color: AppColors.white, width: 1.5),
                    ),
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RegisterScreen())),
                    child: Text('Register', style: AppFonts.headingSemibold(color: AppColors.white)),
                  ),
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const MarketplaceScreen(guest: true)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('I am just exploring', style: AppFonts.headingSemibold(size: 16, color: AppColors.white)),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward, size: 18, color: AppColors.white),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
