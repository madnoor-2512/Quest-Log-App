import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_colors.dart';

class SettingsMainScreen extends ConsumerWidget {
  const SettingsMainScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsProvider);
    final settings = settingsAsync.valueOrNull ?? const SettingsState();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('ตั้งค่าระบบ'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'เสียงและการสั่น',
              style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
            ),
            SwitchListTile(
              value: settings.soundEnabled,
              title: const Text('เสียงเอฟเฟกต์ (SFX)'),
              onChanged: (_) => ref.read(settingsProvider.notifier).toggleSound(),
            ),
            SwitchListTile(
              value: settings.vibrationEnabled,
              title: const Text('การสั่นเตือน (Haptics)'),
              onChanged: (_) => ref.read(settingsProvider.notifier).toggleVibration(),
            ),
            const SizedBox(height: 16),

            const Text(
              'ธีมและการแสดงผล',
              style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
            ),
            SwitchListTile(
              value: settings.isDarkTheme,
              title: const Text('โหมดมืด (Dark Mode)'),
              onChanged: (_) => ref.read(settingsProvider.notifier).toggleDarkTheme(),
            ),
            const SizedBox(height: 16),

            const Text(
              'การแจ้งเตือน',
              style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
            ),
            SwitchListTile(
              value: settings.morningDigest,
              title: const Text('Morning Digest'),
              onChanged: (_) => ref.read(settingsProvider.notifier).toggleMorningDigest(),
            ),
            SwitchListTile(
              value: settings.focusWindow,
              title: const Text('Focus Window Reminder'),
              onChanged: (_) => ref.read(settingsProvider.notifier).toggleFocusWindow(),
            ),
            SwitchListTile(
              value: settings.eveningRecap,
              title: const Text('Evening Recap'),
              onChanged: (_) => ref.read(settingsProvider.notifier).toggleEveningRecap(),
            ),
          ],
        ),
      ),
    );
  }
}
