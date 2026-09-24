import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../providers/achievements_providers.dart';
// import '../providers/auth_provider.dart';
import '../providers/inventory_providers.dart';
import '../providers/quest_providers.dart';
import '../providers/user_provider.dart';
import '../theme/app_avatars.dart';
import '../theme/app_colors.dart';
import 'achievements_screen.dart';
import 'edit_profile_screen.dart';
import 'login_screen.dart';
import 'rewards_screen.dart';
import 'settings/settings_main_screen.dart';
import 'tutorials_screen.dart';

class MemberCenterScreen extends ConsumerWidget {
  const MemberCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProvider);
    final user = userAsync.valueOrNull;

    final achievementsCount =
        ref.watch(unlockedAchievementCodesProvider).valueOrNull?.length ?? 0;
    final incompleteQuestsCount =
        ref
            .watch(questListProvider(QuestFilter.incomplete))
            .valueOrNull
            ?.length ??
        0;
    final inventoryCount = ref.watch(inventoryUsedSlotsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('ศูนย์สมาชิก (Guild Hall)')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _ProfileHeader(user: user),
            const SizedBox(height: 28),

            const _SectionLabel('การผจญภัยในแดนอารมณ์ดี'),
            const SizedBox(height: 8),
            _MenuTile(
              icon: Icons.emoji_events_rounded,
              iconColor: AppColors.levelGold,
              title: 'ความสำเร็จ (Achievements)',
              badgeCount: achievementsCount,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AchievementsScreen()),
              ),
            ),
            _MenuTile(
              icon: Icons.storefront_rounded,
              iconColor: AppColors.secondary,
              title: 'ร้านค้า (Shop)',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const RewardsScreen(initialTabIndex: 0),
                ),
              ),
            ),
            _MenuTile(
              icon: Icons.assignment_rounded,
              iconColor: AppColors.primary,
              title: 'ภารกิจ (Quests)',
              badgeCount: incompleteQuestsCount,
              onTap: () => Navigator.of(context).pop(),
            ),
            _MenuTile(
              icon: Icons.inventory_2_rounded,
              iconColor: const Color(0xFF7C3AED),
              title: 'คลังไอเทม (Inventory)',
              badgeCount: inventoryCount,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const RewardsScreen(initialTabIndex: 1),
                ),
              ),
            ),
            const SizedBox(height: 20),

            const _SectionLabel('ระบบและความช่วยเหลือ'),
            const SizedBox(height: 8),
            _MenuTile(
              icon: Icons.menu_book_rounded,
              iconColor: AppColors.goldRewardDark,
              title: 'คู่มือการเล่น (Tutorials)',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TutorialsScreen()),
              ),
            ),
            _MenuTile(
              icon: Icons.settings_rounded,
              iconColor: AppColors.textSecondary,
              title: 'ตั้งค่าระบบ (Settings)',
              showChevron: true,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsMainScreen()),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(
                Icons.info_outline_rounded,
                color: AppColors.textMuted,
              ),
              title: const Text('เกี่ยวกับ Quest Log'),
              subtitle: const Text('v0.1.0 • RPG Habit & Task Manager'),
            ),
            const SizedBox(height: 20),

            _LogoutButton(onConfirmed: () => _confirmLogout(context, ref)),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('ออกจากระบบ?'),
        content: const Text('คุณจะต้องเข้าสู่ระบบใหม่เพื่อกลับมาเล่นต่อ'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'ออกจากระบบ',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await ref.read(userProvider.notifier).logout();

    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final UserModel? user;
  const _ProfileHeader({required this.user});

  @override
  Widget build(BuildContext context) {
    final classPath = user?.rpgClass;

    return Center(
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 84,
                height: 84,
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
              // ป้ายเลเวลเล็กๆ มุมล่างขวาของ avatar ตาม mockup
              Positioned(
                bottom: -4,
                right: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.levelGold,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.cardSurface, width: 2),
                  ),
                  child: Text(
                    '★${user?.level ?? 1}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                user?.name ?? 'ฮีโร่',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                ),
                child: const Row(
                  children: [
                    Text(
                      'แก้ไข',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),
            ],
          ),
          Text(
            classPath != null
                ? 'Lv.${user?.level ?? 1} ${classPath.classTitle}'
                : 'นักผจญภัยเลเวล ${user?.level ?? 1}',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _StatPill(
                icon: Icons.local_fire_department_rounded,
                color: AppColors.secondary,
                label: '${user?.streakDays ?? 0} วันติด',
              ),
              const SizedBox(width: 8),
              _StatPill(
                icon: Icons.monetization_on_rounded,
                color: AppColors.goldRewardDark,
                label: '${user?.gold ?? 0} G',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  const _StatPill({
    required this.icon,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: AppColors.textMuted,
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final int? badgeCount;
  final bool showChevron;
  final VoidCallback onTap;

  const _MenuTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.onTap,
    this.badgeCount,
    this.showChevron = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight, width: 1.5),
      ),
      child: ListTile(
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: iconColor.withAlpha(35),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
        trailing: badgeCount != null && badgeCount! > 0
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$badgeCount',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryDark,
                  ),
                ),
              )
            : (showChevron ? const Icon(Icons.chevron_right_rounded) : null),
        onTap: onTap,
      ),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  final VoidCallback onConfirmed;
  const _LogoutButton({required this.onConfirmed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.error,
          side: const BorderSide(color: AppColors.error, width: 2),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: onConfirmed,
        icon: const Icon(Icons.logout_rounded),
        label: const Text(
          'ออกจากระบบ (Logout)',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
