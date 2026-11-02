import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import 'farmer_dashboard_screen.dart';
import 'landing_screen.dart';
import 'marketplace_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = context.read<AuthProvider>();
      await auth.bootstrap();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => _homeFor(auth)),
      );
    });
  }

  Widget _homeFor(AuthProvider auth) {
    if (auth.status != AuthStatus.authenticated) return const LandingScreen();
    return auth.isFarmer ? const FarmerDashboardScreen() : const MarketplaceScreen();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: Center(child: CircularProgressIndicator(color: AppColors.brandGreen)),
    );
  }
}
