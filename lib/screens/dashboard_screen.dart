import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/quest_enums.dart';
import '../models/quest_model.dart';
import '../models/user_model.dart';
import '../providers/core_providers.dart';
import '../providers/focus_providers.dart';
import '../providers/quest_providers.dart';
import '../providers/user_provider.dart';
import '../theme/app_avatars.dart';
import '../theme/app_colors.dart';
import '../widgets/level_up_overlay.dart';
import '../widgets/quest_card.dart';
import '../widgets/quest_progress_path.dart';
import '../widgets/stat_badge.dart';
import 'achievements_screen.dart';
import 'add_focus_quest_screen.dart';
import 'add_quest_type_sheet.dart';
import 'add_quick_quest_screen.dart';
import 'focus_screen.dart';
import 'member_center_screen.dart';
import 'rewards_screen.dart';
import 'settings/settings_main_screen.dart';
import 'stats_screen.dart';
import 'tutorials_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with SingleTickerProviderStateMixin {
  int _currentBottomNav = 0;
  int? _showingLevelUp;

  // Daily quest filter for the "หน้าหลัก" tab (0=ทั้งหมด, 1=ค้างอยู่, 2=เสร็จแล้ว)
  int _dailyFilterIndex = 0;

  // Countdown timer for daily quest reset
  Timer? _resetTimer;
  Duration _timeUntilReset = Duration.zero;

  // Critical HP pulse animation
  late AnimationController _criticalHpController;
  late Animation<double> _criticalHpAnimation;

  @override
  void initState() {
    super.initState();
    _calculateTimeUntilReset();
    _resetTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _calculateTimeUntilReset();
    });

    _criticalHpController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _criticalHpAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _criticalHpController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _resetTimer?.cancel();
    _criticalHpController.dispose();
    super.dispose();
  }

  void _calculateTimeUntilReset() {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    setState(() {
      _timeUntilReset = tomorrow.difference(now);
    });
  }

  String _formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  void _listenForLevelUp() {
    ref.listen<AsyncValue<int>>(levelUpEventProvider, (_, next) {
      next.whenData((lvl) {
        if (mounted) {
          setState(() {
            _showingLevelUp = lvl;
          });
        }
      });
    });
    ref.listen(userProvider, (previous, next) {
      final oldUser = previous?.valueOrNull;
      final newUser = next.valueOrNull;
      if (oldUser != null && newUser != null && newUser.level > oldUser.level) {
        if (mounted && _showingLevelUp != newUser.level) {
          setState(() {
            _showingLevelUp = newUser.level;
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    _listenForLevelUp();
    final userAsync = ref.watch(userProvider);
    final user = userAsync.valueOrNull;

    final screens = [
      _buildHomeDashboard(user),
      const FocusScreen(),
      // Index 2 (ปุ่ม +) ไม่ใช่แท็บที่ค้างอยู่บนหน้าจออีกต่อไป — กดแล้ว
      // จะเปิดป๊อปอัปเลือกประเภทเควสต์ผ่าน showAddQuestTypeSheet() แทน
      // (ดู onDestinationSelected ด้านล่าง) ช่องนี้จึงไม่ถูกแสดงจริง
      const SizedBox.shrink(),
      const StatsScreen(),
      const RewardsScreen(),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: _buildSideDrawer(context, user),
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu_rounded, color: AppColors.textPrimary),
            tooltip: 'เปิดเมนู',
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: Text(
          user?.name ?? 'ฮีโร่',
          style: GoogleFonts.prompt(
            fontWeight: FontWeight.bold,
            fontSize: 17,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          if (user != null) ...[
            // 💎 เพชรพรีเมียม (Hard Currency)
            StatBadge(type: StatBadgeType.gem, value: user.gems, compact: true),
            const SizedBox(width: 6),
            // 🪙 เหรียญทอง (Soft Currency)
            StatBadge(
              type: StatBadgeType.gold,
              value: user.gold,
              compact: true,
            ),
            const SizedBox(width: 8),
            // 🔔 กระดิ่งแจ้งเตือน (Notifications & Mindfulness Nudge)
            GestureDetector(
              onTap: () => _showNotificationCenter(context, user),
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.cardSurface,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.shadow,
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Center(
                      child: Icon(
                        Icons.notifications_none_rounded,
                        size: 18,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: AppColors.secondary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
        ],
      ),
      body: Stack(
        children: [
          IndexedStack(index: _currentBottomNav, children: screens),
          if (_showingLevelUp != null)
            LevelUpOverlay(
              newLevel: _showingLevelUp!,
              onDismiss: () => setState(() => _showingLevelUp = null),
            ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentBottomNav,
        onDestinationSelected: (i) {
          // ปุ่ม (+) ตรงกลาง — เปิดป๊อปอัปเลือกประเภทภารกิจแทนการสลับแท็บ
          // ค้างไว้ เพราะ "สร้างเควสต์" เป็นการกระทำครั้งเดียว ไม่ใช่หน้า
          // ที่ควรอยู่ใน bottom navigation
          if (i == 2) {
            showAddQuestTypeSheet(context);
            return;
          }
          setState(() => _currentBottomNav = i);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'หน้าหลัก',
          ),
          NavigationDestination(
            icon: Icon(Icons.timer_outlined),
            selectedIcon: Icon(Icons.timer_rounded),
            label: 'โฟกัส',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_circle_outline_rounded),
            selectedIcon: Icon(Icons.add_circle_rounded),
            label: 'เพิ่มเควส',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart_rounded),
            label: 'ภาพรวม',
          ),
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront_rounded),
            label: 'รางวัล',
          ),
        ],
      ),
    );
  }

  // ─── Side Drawer ────────────────────────────────────────────────────────────

  Widget _buildSideDrawer(BuildContext context, UserModel? user) {
    final classTitle = user?.rpgClass?.classTitle ?? 'ยังไม่ได้เลือกสาย';
    return Drawer(
      backgroundColor: AppColors.background,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          children: [
            // User profile header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.shadow,
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primary, width: 2),
                    ),
                    child: Icon(
                      heroAvatarIcon(user?.avatarIndex ?? 0),
                      size: 28,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.name ?? 'ฮีโร่',
                          style: GoogleFonts.prompt(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Lv. ${user?.level ?? 1} • $classTitle',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Wallet quick stats
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF7DD3FC)),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.diamond_rounded,
                          size: 18,
                          color: Color(0xFF0284C7),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${user?.gems ?? 0} เพชร',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0369A1),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.goldLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.monetization_on_rounded,
                          size: 18,
                          color: Color(0xFFB45309),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${user?.gold ?? 0} Gold',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFB45309),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),
            const Divider(color: AppColors.border),
            const SizedBox(height: 10),

            _buildDrawerItem(
              icon: Icons.shield_rounded,
              title: 'ศูนย์สมาชิก (Guild Hall)',
              color: AppColors.primary,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MemberCenterScreen()),
                );
              },
            ),
            _buildDrawerItem(
              icon: Icons.emoji_events_rounded,
              title: 'ความสำเร็จ (Achievements)',
              color: AppColors.levelGold,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AchievementsScreen()),
                );
              },
            ),
            _buildDrawerItem(
              icon: Icons.storefront_rounded,
              title: 'ร้านค้ารางวัล (Shop & Rewards)',
              color: AppColors.secondary,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const RewardsScreen(initialTabIndex: 0),
                  ),
                );
              },
            ),
            _buildDrawerItem(
              icon: Icons.inventory_2_rounded,
              title: 'คลังไอเทม (Inventory)',
              color: const Color(0xFF7C3AED),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const RewardsScreen(initialTabIndex: 1),
                  ),
                );
              },
            ),
            _buildDrawerItem(
              icon: Icons.menu_book_rounded,
              title: 'คู่มือการเล่น (Tutorials)',
              color: const Color(0xFF0D9488),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TutorialsScreen()),
                );
              },
            ),
            _buildDrawerItem(
              icon: Icons.settings_rounded,
              title: 'ตั้งค่าระบบ (Settings)',
              color: AppColors.textSecondary,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsMainScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withAlpha(25),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        size: 18,
        color: AppColors.textMuted,
      ),
      onTap: onTap,
    );
  }

  // ─── Notification Center Modal ─────────────────────────────────────────────

  void _showNotificationCenter(BuildContext context, UserModel user) {
    final dailyQuests =
        ref.read(questListProvider(QuestFilter.daily)).valueOrNull ?? [];
    final pendingCount = dailyQuests.where((q) => !q.isCompleted).length;
    final completedCount = dailyQuests.where((q) => q.isCompleted).length;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withAlpha(25),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.notifications_active_rounded,
                    color: AppColors.secondary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'ศูนย์แจ้งเตือนและเตือนสติ',
                  style: GoogleFonts.prompt(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 1. สรุปผลประจำวัน
            _buildNotificationCard(
              icon: Icons.analytics_outlined,
              iconColor: AppColors.primary,
              title: 'สรุปผลประจำวัน (Daily Summary)',
              desc:
                  'วันนี้สำเร็จแล้ว $completedCount ภารกิจ (คงเหลือ $pendingCount) • สตรีคไฟ ${user.streakDays} วัน • พลังชีวิต ${user.currentHp}/${user.maxHp} HP',
            ),
            const SizedBox(height: 10),

            // 2. การแจ้งเตือนเควสต์
            _buildNotificationCard(
              icon: Icons.hourglass_top_rounded,
              iconColor: const Color(0xFFD97706),
              title: 'การแจ้งเตือนเควสต์ (Quest Reminders)',
              desc: pendingCount > 0
                  ? 'เหลือเวลาอีก ${_formatDuration(_timeUntilReset)} ก่อนรีเซ็ตประจำวัน รีบทำเควสต์ที่ค้างอยู่เพื่อรักษาสตรีคและป้องกันการเสีย HP!'
                  : 'ยอดเยี่ยมมาก! คุณทำเควสต์ประจำวันครบทุกภารกิจแล้ว รักษาสตรีคไฟไว้ได้สำเร็จ!',
            ),
            const SizedBox(height: 10),

            // 3. การเตือนสติ (Mindfulness Nudge)
            _buildNotificationCard(
              icon: Icons.self_improvement_rounded,
              iconColor: const Color(0xFF7C3AED),
              title: 'การเตือนสติ (Mindfulness & Well-being)',
              desc:
                  'อย่าลืมดื่มน้ำสักแก้ว พักสายตา 5 นาที และฝึกหายใจเข้าออกลึกๆ วินัยที่ดีต้องมาพร้อมกับสุขภาพจิตที่ผ่อนคลายนะนักผจญภัย!',
            ),
            const SizedBox(height: 18),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryDark,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('รับทราบการแจ้งเตือน'),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String desc,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: iconColor,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  desc,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Home Dashboard Body ───────────────────────────────────────────────────

  Widget _buildHomeDashboard(UserModel? user) {
    final dailyQuestsAsync = ref.watch(questListProvider(QuestFilter.daily));
    final allQuestsAsync = ref.watch(questListProvider(QuestFilter.all));

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),

          // ── Section 2: Character Card ──────────────────────────────────────
          if (user != null) _buildCharacterCard(user),

          const SizedBox(height: 14),

          // ── Section 3: Chapter / Story Progress Card ───────────────────────
          _buildChapterCard(dailyQuestsAsync, allQuestsAsync),

          const SizedBox(height: 14),

          // ── Section 4: Daily Quests Section ────────────────────────────────
          _buildDailyQuestsSection(dailyQuestsAsync),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ─── Section 2: Hero Status & Progression Card ─────────────────────────────

  Widget _buildCharacterCard(UserModel user) {
    final classTitle = user.rpgClass?.classTitle ?? 'ยังไม่ได้เลือกสาย';
    final currentHp = user.currentHp;
    final maxHp = user.maxHp;
    final hpRatio = maxHp > 0 ? (currentHp / maxHp).clamp(0.0, 1.0) : 0.0;
    final isCriticalHp = hpRatio < 0.3;

    return AnimatedBuilder(
      animation: _criticalHpAnimation,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isCriticalHp
                  ? AppColors.error.withAlpha(
                      (255 * _criticalHpAnimation.value).toInt(),
                    )
                  : AppColors.border,
              width: isCriticalHp ? 2.5 : 2,
            ),
            boxShadow: [
              BoxShadow(
                color: isCriticalHp
                    ? AppColors.error.withAlpha(
                        (80 * _criticalHpAnimation.value).toInt(),
                      )
                    : AppColors.shadow,
                blurRadius: isCriticalHp ? 12 : 8,
                spreadRadius: isCriticalHp ? 1 : 0,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: Avatar + Stats
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar with level badge
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isCriticalHp
                                ? AppColors.error
                                : AppColors.primary,
                            width: 3,
                          ),
                        ),
                        child: Icon(
                          heroAvatarIcon(user.avatarIndex),
                          size: 38,
                          color: AppColors.primaryDark,
                        ),
                      ),
                      // Level badge
                      Positioned(
                        bottom: -4,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isCriticalHp
                                  ? AppColors.error
                                  : AppColors.primary,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isCriticalHp
                                    ? const Color(0xFF991B1B)
                                    : AppColors.primaryDark,
                                width: 1.5,
                              ),
                            ),
                            child: Text(
                              'Lv. ${user.level}',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  // HP & EXP Bars
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ❤️ พลังชีวิต (HP) Bar
                        _buildStatBar(
                          label: 'พลังชีวิต (HP)',
                          icon: Icons.favorite_rounded,
                          iconColor: AppColors.error,
                          current: currentHp,
                          max: maxHp,
                          barColor: isCriticalHp
                              ? AppColors.error
                              : const Color(0xFFEF4444),
                          barBgColor: const Color(0xFFFEE2E2),
                          isCritical: isCriticalHp,
                        ),
                        const SizedBox(height: 8),
                        // ⭐ ประสบการณ์ (EXP) Bar
                        _buildStatBar(
                          label: 'ประสบการณ์ (EXP)',
                          icon: Icons.star_rounded,
                          iconColor: AppColors.primary,
                          current: user.currentExp,
                          max: user.maxExp,
                          barColor: AppColors.primary,
                          barBgColor: AppColors.expBarBg,
                        ),
                        const SizedBox(height: 6),
                        // Level up info
                        Row(
                          children: [
                            const Icon(
                              Icons.auto_awesome_rounded,
                              size: 12,
                              color: AppColors.info,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'ปลดล็อกเลเวล ${user.level + 1} (ขยาย Max HP + รับ 💎 5 เพชร)',
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.info,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Critical HP Warning Banner
              if (isCriticalHp) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFF87171)),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 16,
                        color: Color(0xFFDC2626),
                      ),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '⚠️ HP วิกฤต (< 30%)! รีบทำเควสต์เพื่อฟื้นฟูก่อนโดนลดเลเวล 1 ขั้น',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFDC2626),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const Divider(height: 18),

              // Bottom status info: Class + Active Buff / Debuff
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 🌱 สายอาชีพ (Class)
                  Row(
                    children: [
                      const Icon(
                        Icons.eco_rounded,
                        size: 15,
                        color: Color(0xFF16A34A),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'สาย: $classTitle',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),

                  // 🔥 แบดจ์สตรีคไฟ (Login/Action Streak) + Active Buff / Debuff
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      StatBadge(
                        type: StatBadgeType.streak,
                        value: user.streakDays,
                        compact: true,
                      ),
                      if (user.streakCount >= 3) ...[
                        const SizedBox(width: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFF59E0B)),
                          ),
                          child: const Text(
                            '🛡️ ฮีล x1.25',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFB45309),
                            ),
                          ),
                        ),
                      ] else if (user.hasStreakDebuff) ...[
                        const SizedBox(width: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFEF4444)),
                          ),
                          child: const Text(
                            '⚠️ ไฟดับ',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFB91C1C),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatBar({
    required String label,
    required IconData icon,
    required Color iconColor,
    required int current,
    required int max,
    required Color barColor,
    required Color barBgColor,
    bool isCritical = false,
  }) {
    final ratio = max > 0 ? (current / max).clamp(0.0, 1.0) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, size: 13, color: iconColor),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isCritical
                        ? AppColors.error
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            Text(
              '$current / $max',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: barColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Container(
          height: 10,
          decoration: BoxDecoration(
            color: barBgColor,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
              color: isCritical ? AppColors.error : AppColors.border,
              width: 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: ratio),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) {
                return FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: value,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [barColor, barColor.withAlpha(190)],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  // ─── Section 3: World Map & Chapter Progress Card ──────────────────────────

  Widget _buildChapterCard(
    AsyncValue<List<QuestModel>> dailyQuestsAsync,
    AsyncValue<List<QuestModel>> allQuestsAsync,
  ) {
    final dailyQuests = dailyQuestsAsync.valueOrNull ?? [];
    final completed = dailyQuests.where((q) => q.isCompleted).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Chapter header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.explore_rounded,
                        size: 18,
                        color: AppColors.primaryDark,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'บทที่ 1 : ป่าแห่งความมุ่งมั่น',
                        style: GoogleFonts.prompt(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 24),
                    child: Text(
                      'Whispering Woods • ด่าน ${(completed >= 5) ? 5 : (completed + 1)}/5 ${completed >= 5 ? 'พิชิตสำเร็จแล้ว 🎉' : 'กำลังท้าทาย'}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
              // Progress badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: completed >= 5
                      ? const Color(0xFFFEF3C7)
                      : AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: completed >= 5
                        ? const Color(0xFFF59E0B)
                        : AppColors.primary,
                    width: 1,
                  ),
                ),
                child: Text(
                  completed >= 5 ? 'พิชิตสำเร็จ! 👑' : 'สำเร็จ $completed/5',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: completed >= 5
                        ? const Color(0xFFB45309)
                        : AppColors.primaryDark,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Interactive Checkpoint Nodes Path
          dailyQuestsAsync.when(
            loading: () => const SizedBox(
              height: 160,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, st) => SizedBox(
              height: 160,
              child: Center(child: Text('ข้อผิดพลาด: $e')),
            ),
            data: (quests) => QuestProgressPath(quests: quests),
          ),
        ],
      ),
    );
  }

  // ─── Section 4: Daily Quests List ──────────────────────────────────────────

  Widget _buildDailyQuestsSection(
    AsyncValue<List<QuestModel>> dailyQuestsAsync,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header + Reset Timer
        Row(
          children: [
            Text(
              'ภารกิจประจำวัน (Daily Quests)',
              style: GoogleFonts.prompt(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 6),
            // Count badge
            dailyQuestsAsync.when(
              data: (quests) => Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  color: AppColors.secondary,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${quests.length}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            ),
            const Spacer(),
            // Reset Countdown Timer
            Row(
              children: [
                const Icon(
                  Icons.hourglass_bottom_rounded,
                  size: 14,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 3),
                const Text(
                  'รีเซ็ตใน',
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
                const SizedBox(width: 4),
                Text(
                  _formatDuration(_timeUntilReset),
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _timeUntilReset.inHours < 3
                        ? AppColors.error
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 10),

        // Status Filter tabs
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterTab('ทั้งหมด', 0, dailyQuestsAsync),
              const SizedBox(width: 8),
              _buildFilterTab('ค้างอยู่', 1, null),
              const SizedBox(width: 8),
              _buildFilterTab('เสร็จแล้ว', 2, null),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Quest list
        dailyQuestsAsync.when(
          loading: () => const SizedBox(
            height: 100,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, st) => Center(child: Text('เกิดข้อผิดพลาด: $e')),
          data: (quests) {
            final filtered = _filterQuests(quests);
            if (filtered.isEmpty) {
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 36),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _dailyFilterIndex == 2
                            ? 'ยังไม่มีเควสที่เสร็จวันนี้'
                            : 'ไม่มีเควสที่เปิดอยู่ — กดปุ่ม "+" ด้านล่างเพื่อเพิ่มเควส',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Column(
              children: filtered.map((quest) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GestureDetector(
                    onTap: () => _showQuestDetailsBottomSheet(quest),
                    child: QuestCard(
                      quest: quest,
                      onStartFocus: quest.goalType == QuestGoalType.focus
                          ? () {
                              ref.read(focusSelectionProvider.notifier).clear();
                              ref
                                  .read(focusSelectionProvider.notifier)
                                  .add(quest);
                              setState(() => _currentBottomNav = 1);
                            }
                          : null,
                      onComplete: quest.goalType == QuestGoalType.dailyHabit
                          ? () async {
                              await _executeCompleteQuest(quest);
                            }
                          : null,
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  // ─── Quest Completion Logic (เควสต์ทันใจ / Daily Habit เท่านั้น) ──────────
  // เควสต์โฟกัสจบได้เฉพาะผ่าน Focus Timer ในหน้าโฟกัส (ดู
  // FocusScreen._completeSessionQuest / _completeDueQuests) ฟังก์ชันนี้จึง
  // เหลือแค่เส้นทางเช็กอินของ Daily Habit เท่านั้น

  void _showQuestDetailsBottomSheet(QuestModel quest) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _QuestDetailsSheet(quest: quest),
    );
  }

  Future<void> _executeCompleteQuest(QuestModel quest) async {
    if (quest.goalType != QuestGoalType.dailyHabit) return;
    try {
      final result = await ref
          .read(questActionsProvider.notifier)
          .checkInHabit(quest.id!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'เช็กอินสำเร็จ วันที่ ${result.day}! ได้รับ '
            '+${result.exp} EXP, +${result.gold} Gold (❤️ ฟื้นฟู HP)'
            '${result.completed ? ' เควสต์ Habit สำเร็จครบเป้าหมายแล้ว!' : ''}',
          ),
          backgroundColor: AppColors.primaryDark,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เช็กอินไม่สำเร็จ: $error'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  List<QuestModel> _filterQuests(List<QuestModel> quests) {
    switch (_dailyFilterIndex) {
      case 1:
        return quests.where((q) => !q.isCompleted).toList();
      case 2:
        return quests.where((q) => q.isCompleted).toList();
      default:
        return quests;
    }
  }

  Widget _buildFilterTab(
    String label,
    int index,
    AsyncValue<List<QuestModel>>? questsAsync,
  ) {
    final isSelected = _dailyFilterIndex == index;
    String? countText;
    if (questsAsync != null) {
      final quests = questsAsync.valueOrNull;
      if (quests != null) {
        countText = '(${quests.length})';
      }
    }

    return GestureDetector(
      onTap: () => setState(() => _dailyFilterIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.cardSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primaryDark : AppColors.border,
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withAlpha(50),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : AppColors.textPrimary,
              ),
            ),
            if (countText != null) ...[
              const SizedBox(width: 4),
              Text(
                countText,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white70 : AppColors.textMuted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _QuestDetailsSheet extends ConsumerStatefulWidget {
  final QuestModel quest;
  const _QuestDetailsSheet({required this.quest});

  @override
  ConsumerState<_QuestDetailsSheet> createState() => _QuestDetailsSheetState();
}

class _QuestDetailsSheetState extends ConsumerState<_QuestDetailsSheet> {
  int? _checkinCount;

  @override
  void initState() {
    super.initState();
    _loadCheckinCount();
  }

  Future<void> _loadCheckinCount() async {
    final db = ref.read(databaseHelperProvider);
    final count = await db.getHabitCheckinCount(widget.quest.id!);
    if (mounted) {
      setState(() => _checkinCount = count);
    }
  }

  void _abandonQuest() async {
    final isCampaign = widget.quest.isCampaign;
    if (isCampaign) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'ยอมรับความพ่ายแพ้?',
            style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
          ),
          content: const Text(
            'คุณแน่ใจหรือไม่ที่จะละทิ้งแคมเปญนี้? หากยกเลิก ความคืบหน้าบนแผนที่ทั้งหมดจะหายไป และฮีโร่จะสูญเสีย 20 HP จากการหลบหนี 🏳️',
            style: TextStyle(color: Color(0xFF991B1B), fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('ฮึดสู้ต่อ! (กลับไปทำเควสต์)', style: TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
              ),
              child: const Text('ยอมรับความพ่ายแพ้ (เสีย -20 HP)'),
            ),
          ],
        ),
      );

      if (confirm == true) {
        await ref.read(userProvider.notifier).applyHpDamage(20);
        await ref.read(questActionsProvider.notifier).deleteQuest(widget.quest.id!);
        if (mounted) Navigator.of(context).pop();
      }
    } else {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('ลบภารกิจ', style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text('ต้องการลบเควสต์นี้ใช่หรือไม่?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('ยกเลิก', style: TextStyle(color: AppColors.textMuted)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
              ),
              child: const Text('ลบภารกิจ'),
            ),
          ],
        ),
      );

      if (confirm == true) {
        await ref.read(questActionsProvider.notifier).deleteQuest(widget.quest.id!);
        if (mounted) Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.quest;
    final isCampaign = q.isCampaign;
    final isFocus = q.goalType == QuestGoalType.focus;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 48,
              height: 6,
              decoration: BoxDecoration(
                color: AppColors.borderLight,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isFocus ? const Color(0xFFFEF3C7) : AppColors.primaryLight,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isFocus ? Icons.hourglass_bottom_rounded : Icons.bolt_rounded,
                          color: isFocus ? const Color(0xFFD97706) : AppColors.primaryDark,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isCampaign ? const Color(0xFFFEF3C7) : AppColors.surface,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: isCampaign ? const Color(0xFFF59E0B) : AppColors.borderLight),
                              ),
                              child: Text(
                                isCampaign ? '👑 แคมเปญ' : (isFocus ? '⏳ เควสต์โฟกัส' : '⚡ เควสต์ทันใจ'),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isCampaign ? const Color(0xFFB45309) : AppColors.textSecondary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              q.title,
                              style: GoogleFonts.prompt(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  const Text(
                    'ข้อมูลภารกิจ',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.cardSurface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: Column(
                      children: [
                        if (isCampaign) ...[
                          Row(
                            children: [
                              const Icon(Icons.map_rounded, size: 20, color: AppColors.primary),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _checkinCount == null
                                    ? const Text('กำลังโหลดความคืบหน้า...')
                                    : Text(
                                        'เดินทางมาแล้ว $_checkinCount/${q.habitTargetDays} วัน',
                                        style: const TextStyle(fontWeight: FontWeight.w600),
                                      ),
                              ),
                            ],
                          ),
                          if (_checkinCount != null) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.pest_control_rounded, size: 20, color: Color(0xFFEA580C)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'มินิบอสครั้งถัดไปในอีก ${5 - ((_checkinCount! + 1) % 5)} วัน',
                                    style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFFEA580C)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ] else ...[
                          Row(
                            children: [
                              const Icon(Icons.repeat_rounded, size: 20, color: AppColors.primary),
                              const SizedBox(width: 12),
                              Text(
                                q.habitFrequency == HabitFrequency.daily ? 'ทำทุกวัน' : 'กำหนดเอง',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 12),
                        const Divider(height: 1),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.star_rounded, size: 20, color: AppColors.gold),
                            const SizedBox(width: 12),
                            Text(
                              'รางวัลพื้นฐาน: +${q.expReward} EXP, +${q.goldReward} Gold',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            if (widget.quest.goalType == QuestGoalType.dailyHabit) {
                              Navigator.of(context).push(MaterialPageRoute(
                                builder: (context) => AddQuickQuestScreen(questToEdit: widget.quest),
                              ));
                            } else if (widget.quest.goalType == QuestGoalType.focus) {
                              Navigator.of(context).push(MaterialPageRoute(
                                builder: (context) => AddFocusQuestScreen(questToEdit: widget.quest),
                              ));
                            }
                          },
                          icon: const Icon(Icons.edit_rounded, size: 18),
                          label: const Text('แก้ไขภารกิจ'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: const BorderSide(color: AppColors.border, width: 2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            foregroundColor: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _abandonQuest,
                          icon: const Icon(Icons.flag_outlined, size: 18),
                          label: Text(isCampaign ? 'ยอมแพ้' : 'ลบภารกิจ'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: const Color(0xFFDC2626),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
