import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/user_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/rpg_button.dart';
import 'dashboard_screen.dart';
import 'onboarding_screen.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App Logo
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primaryDark, width: 4),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33000000),
                        offset: Offset(0, 6),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.shield_rounded,
                    size: 56,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),

                // Title
                Text(
                  'QUEST LOG',
                  style: GoogleFonts.pressStart2p(
                    fontSize: 22,
                    color: AppColors.textPrimary,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'เปลี่ยนชีวิตประจำวันของคุณให้เป็นการผจญภัย RPG',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: AppColors.textMuted,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 48),

                // Primary Start Adventure button
                RpgButton(
                  text: 'เริ่มการผจญภัย (Start Adventure)',
                  icon: Icons.play_arrow_rounded,
                  backgroundColor: AppColors.secondary,
                  borderColor: AppColors.secondaryDark,
                  onPressed: () async {
                    final user = userAsync.valueOrNull;
                    if (user != null) {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => const DashboardScreen(),
                        ),
                      );
                      return;
                    }

                    final restoredUser = await ref
                        .read(userProvider.notifier)
                        .resumeLocalUser();
                    if (!context.mounted) return;
                    if (restoredUser != null) {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => const DashboardScreen(),
                        ),
                      );
                    } else {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const OnboardingScreen(),
                        ),
                      );
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Secondary Buttons
                RpgButton(
                  text: 'เข้าสู่ระบบด้วย Google',
                  icon: Icons.g_mobiledata_rounded,
                  backgroundColor: Colors.white,
                  borderColor: AppColors.border,
                  textColor: AppColors.textPrimary,
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('เข้าสู่ระบบด้วย Google เร็วๆ นี้!'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                RpgButton(
                  text: 'เข้าใช้งานแบบ Guest',
                  icon: Icons.person_outline_rounded,
                  backgroundColor: AppColors.cardSurface,
                  borderColor: AppColors.border,
                  textColor: AppColors.textSecondary,
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const OnboardingScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
