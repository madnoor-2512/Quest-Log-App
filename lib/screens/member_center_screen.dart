import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/user_provider.dart';
import '../theme/app_avatars.dart';
import '../theme/app_colors.dart';
import 'edit_profile_screen.dart';
import 'settings/settings_main_screen.dart';

class MemberCenterScreen extends ConsumerWidget {
  const MemberCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProvider);
    final user = userAsync.valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('ศูนย์สมาชิก (Guild Hall)')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      heroAvatarIcon(user?.avatarIndex ?? 0),
                      size: 48,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user?.name ?? 'ฮีโร่',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'นักผจญภัยเลเวล ${user?.level ?? 1}',
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            ListTile(
              leading: const Icon(Icons.edit_rounded, color: AppColors.primary),
              title: const Text('แก้ไขโปรไฟล์ (Edit Profile)'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(
                Icons.settings_rounded,
                color: AppColors.primary,
              ),
              title: const Text('ตั้งค่าระบบ (Settings)'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsMainScreen()),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(
                Icons.info_outline_rounded,
                color: AppColors.secondary,
              ),
              title: const Text('เกี่ยวกับ Quest Log'),
              subtitle: const Text('v0.1.0 • RPG Habit & Task Manager'),
            ),
          ],
        ),
      ),
    );
  }
}
