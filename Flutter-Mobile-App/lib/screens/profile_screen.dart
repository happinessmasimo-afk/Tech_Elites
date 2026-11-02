import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../widgets/primary_button.dart';
import 'edit_profile_screen.dart';
import 'login_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  String _initials(String? name) {
    if (name == null || name.trim().isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    final first = parts.first.isNotEmpty ? parts.first[0] : '';
    final last = parts.length > 1 && parts.last.isNotEmpty ? parts.last[0] : '';
    return (first + last).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AuthProvider>().profile;
    final isFarmer = profile?.isFarmer ?? false;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit profile',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EditProfileScreen())),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // --- Header card: avatar, name, role badge ---
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 34,
                  backgroundColor: AppColors.brandGreenLight,
                  child: Text(
                    _initials(profile?.fullName),
                    style: AppFonts.heading(size: 22, color: AppColors.brandGreenDark),
                  ),
                ),
                const SizedBox(height: 14),
                Text(profile?.fullName ?? 'Your account', style: AppFonts.heading(size: 19, color: AppColors.text)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: isFarmer ? AppColors.brandGreenLight : const Color(0xFFEFEFEF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isFarmer ? 'Farmer' : 'Buyer',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isFarmer ? AppColors.brandGreenDark : Colors.black54),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          Text('Contact details', style: AppFonts.headingSemibold(size: 14, color: AppColors.muted)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                _infoRow(Icons.email_outlined, 'Email', profile?.email),
                const Divider(height: 1, color: AppColors.border),
                _infoRow(Icons.phone_outlined, 'Phone', profile?.phone),
                const Divider(height: 1, color: AppColors.border),
                _infoRow(Icons.location_on_outlined, 'Location', profile?.location ?? 'Not set'),
              ],
            ),
          ),

          const SizedBox(height: 28),
          PrimaryButton(
            label: 'Log out',
            outlined: true,
            onPressed: () async {
              await context.read<AuthProvider>().logout();
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.brandGreenDark),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppFonts.body(color: AppColors.muted, size: 12)),
                const SizedBox(height: 2),
                Text(value?.isNotEmpty == true ? value! : 'Not set', style: AppFonts.bodyMedium(size: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
