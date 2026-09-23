import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/focus_providers.dart';
import '../providers/quest_providers.dart';
import '../providers/user_provider.dart';
import '../theme/app_avatars.dart';
import '../theme/app_colors.dart';
import '../widgets/exp_bar.dart';
import '../widgets/level_up_overlay.dart';
import '../widgets/quest_card.dart';
import '../widgets/quest_progress_path.dart';
import '../widgets/stat_badge.dart';
import 'add_quest_screen.dart';
import 'focus_screen.dart';
import 'member_center_screen.dart';
import 'rewards_screen.dart';
import 'stats_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with SingleTickerProviderStateMixin {
  int _currentBottomNav = 0;
  late TabController _tabController;
  int? _showingLevelUp;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _listenForLevelUp() {
    ref.listen(userProvider, (previous, next) {
      final oldUser = previous?.valueOrNull;
      final newUser = next.valueOrNull;
      if (oldUser != null && newUser != null && newUser.level > oldUser.level) {
        setState(() {
          _showingLevelUp = newUser.level;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    _listenForLevelUp();
    final userAsync = ref.watch(userProvider);
    final user = userAsync.valueOrNull;

    final screens = [
      _buildQuestDashboard(user),
      const FocusScreen(),
      AddQuestScreen(
        showAppBar: false,
        onSaved: () => setState(() => _currentBottomNav = 0),
      ),
      const StatsScreen(),
      const RewardsScreen(),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded, color: AppColors.textPrimary),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MemberCenterScreen()),
            );
          },
        ),
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: Icon(
                heroAvatarIcon(user?.avatarIndex ?? 0),
                size: 20,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              user?.name ?? 'ฮีโร่',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        actions: [
          if (user != null) ...[
            StatBadge(type: StatBadgeType.level, value: user.level),
            const SizedBox(width: 6),
            StatBadge(type: StatBadgeType.gold, value: user.gold),
            const SizedBox(width: 6),
            StatBadge(type: StatBadgeType.streak, value: user.streakDays),
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
        onDestinationSelected: (i) => setState(() => _currentBottomNav = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment_rounded),
            label: 'เควส',
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
            label: 'สถิติ',
          ),
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront_rounded),
            label: 'ร้านค้า',
          ),
        ],
      ),
    );
  }

  Widget _buildQuestDashboard(dynamic user) {
    final dailyQuestsAsync = ref.watch(questListProvider(QuestFilter.daily));

    return Column(
      children: [
        // EXP Bar Header
        if (user != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: AppColors.cardSurface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'LV. ${user.level}',
                      style: GoogleFonts.pressStart2p(
                        fontSize: 12,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '${user.currentExp} / ${user.maxExp} EXP',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ExpBar(
                  currentExp: user.currentExp,
                  maxExp: user.maxExp,
                  height: 12,
                ),
              ],
            ),
          ),

        // Progress Path — เส้นทางคดเคี้ยวแบบ RPG ของเควสวันนี้ (QuestFilter.daily)
        // node สีเขียว = ทำสำเร็จแล้ว, สีส้ม = ยังไม่ทำ ตรงตาม mockup
        Container(
          color: AppColors.cardSurface,
          padding: const EdgeInsets.only(bottom: 8),
          child: dailyQuestsAsync.when(
            loading: () => const SizedBox(
              height: 150,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, st) => SizedBox(
              height: 150,
              child: Center(child: Text('ข้อผิดพลาด: $e')),
            ),
            data: (dailyQuests) => QuestProgressPath(quests: dailyQuests),
          ),
        ),

        // Tabs for Quests
        TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textMuted,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'เควสหลัก'),
            Tab(text: 'เควสรอง'),
            Tab(text: 'ประจำวัน'),
            Tab(text: 'เสร็จแล้ว'),
          ],
        ),

        // Tab views with quest list — ผูกตรงกับ QuestFilter preset ที่มีอยู่แล้ว
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildQuestList(QuestFilter.main),
              _buildQuestList(QuestFilter.side),
              _buildQuestList(QuestFilter.daily),
              _buildQuestList(QuestFilter.completed),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuestList(QuestFilter filter) {
    final questsAsync = ref.watch(questListProvider(filter));

    return questsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('เกิดข้อผิดพลาด: $e')),
      data: (quests) {
        if (quests.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.shield_outlined,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 12),
                const Text(
                  'ไม่มีเควสที่เปิดอยู่',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'กดแท็บ "เพิ่มเควส" ด้านล่างเพื่อเพิ่มเควสใหม่',
                  style: TextStyle(color: AppColors.textMuted),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: quests.length,
          itemBuilder: (context, index) {
            final quest = quests[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: QuestCard(
                quest: quest,
                onStartFocus: () {
                  // pre-select เฉพาะเควสนี้เข้า focusSelectionProvider แล้ว
                  // สลับไปแท็บโฟกัส ตาม spec Phase 3 — clear() ก่อนกัน
                  // selection ค้างจากการเลือกครั้งก่อนหน้ามาปนกัน
                  ref.read(focusSelectionProvider.notifier).clear();
                  ref.read(focusSelectionProvider.notifier).add(quest);
                  setState(() => _currentBottomNav = 1);
                },
                onComplete: () async {
                  final result = await ref
                      .read(questActionsProvider.notifier)
                      .completeQuest(quest.id!);
                  if (!context.mounted) return;
                  final capNote = result.wasCapped
                      ? ' (ถึงเพดานรางวัลวันนี้แล้ว ได้น้อยกว่าปกติ)'
                      : '';
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'สำเร็จเควส "${quest.title}"! ได้รับ +${result.exp} EXP, '
                        '+${result.gold} Gold$capNote',
                      ),
                      backgroundColor: result.wasCapped
                          ? AppColors.secondary
                          : AppColors.primaryDark,
                      duration: const Duration(seconds: 3),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}
