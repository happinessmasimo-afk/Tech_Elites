import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/theme.dart';
import 'providers/auth_provider.dart';
import 'screens/splash_screen.dart';

void main() {
  runApp(const AgricastLiteApp());
}

class AgricastLiteApp extends StatelessWidget {
  const AgricastLiteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: MaterialApp(
        title: 'Agricast Livestock',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: const SplashScreen(),
      ),
    );
  }
}
