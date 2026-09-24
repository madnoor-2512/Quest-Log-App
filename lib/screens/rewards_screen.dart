import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/reward_model.dart';
import '../models/user_model.dart';
import '../providers/inventory_providers.dart';
import '../providers/rewards_providers.dart';
import '../providers/user_provider.dart';
import '../services/gamification_config.dart';
import '../theme/app_colors.dart';
import '../widgets/rpg_button.dart';
import 'add_reward_screen.dart';

Color _rarityColor(ItemRarity rarity) {
  switch (rarity) {
    case ItemRarity.epic:
      return const Color(0xFF7C3AED);
    case ItemRarity.rare:
      return const Color(0xFF3B82F6);
    case ItemRarity.common:
      return AppColors.textMuted;
  }
}

class RewardsScreen extends ConsumerWidget {
  final int initialTabIndex;
  const RewardsScreen({super.key, this.initialTabIndex = 0});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProvider);
    final user = userAsync.valueOrNull;

    return DefaultTabController(
      length: 2,
      initialIndex: initialTabIndex,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'ร้านค้ารางวัล (Shop)',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.goldReward.withAlpha(40),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.goldReward),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.monetization_on_rounded,
                            color: AppColors.goldReward,
                            size: 20,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${user?.gold ?? 0} Gold',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AddRewardScreen(),
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.add_circle_outline_rounded,
                      size: 18,
                    ),
                    label: const Text('เพิ่มของรางวัล'),
                  ),
                ),
                const SizedBox(height: 6),

                const TabBar(
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textMuted,
                  indicatorColor: AppColors.primary,
                  tabs: [
                    Tab(text: 'ร้านค้า'),
                    Tab(text: 'คลังไอเทม'),
                  ],
                ),

                Expanded(
                  child: TabBarView(
                    children: [
                      _ShopTab(user: user),
                      const _InventoryTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shop Tab
// ---------------------------------------------------------------------------

class _ShopTab extends ConsumerWidget {
  final UserModel? user;
  const _ShopTab({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rewardsAsync = ref.watch(rewardsListProvider);

    return rewardsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('ข้อผิดพลาด: $e')),
      data: (rewards) {
        if (rewards.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.storefront_outlined,
                  size: 64,
                  color: Colors.grey,
                ),
                const SizedBox(height: 12),
                const Text('ยังไม่มีของรางวัลในร้านค้า'),
                const SizedBox(height: 12),
                RpgButton(
                  text: 'เพิ่มของรางวัลตัวอย่าง',
                  backgroundColor: AppColors.primary,
                  borderColor: AppColors.primaryDark,
                  onPressed: () async {
                    final notifier = ref.read(rewardsListProvider.notifier);
                    // ตัวอย่างครบ 3 หมวดตาม mockup — equipment (มีผลจริง
                    // ตอนเริ่ม Focus session), consumable (ใช้แล้วหมด
                    // ครั้งเดียว มีผลจริง), collectible (แค่เก็บสะสม)
                    await notifier.addReward(
                      const RewardModel(
                        title: 'หูฟัง Lo-Fi',
                        goldCost: 200,
                        description: 'เพิ่ม Focus Time +10%',
                        iconName: 'headphones',
                        itemCategory: RewardCategory.equipment,
                        rarity: ItemRarity.rare,
                        effectType: ItemEffectType.focusTimeBonusPercent,
                        effectValue: 0.10,
                      ),
                    );
                    await notifier.addReward(
                      const RewardModel(
                        title: 'คัมภีร์ยืดเวลา',
                        goldCost: 60,
                        description:
                            'เพิ่มเวลาภารกิจโฟกัส +15 นาที (ใช้ตอนมีเซสชันทำงานอยู่)',
                        iconName: 'auto_stories',
                        itemCategory: RewardCategory.consumable,
                        rarity: ItemRarity.common,
                        effectType: ItemEffectType.extendFocusMinutes,
                        effectValue: 15,
                      ),
                    );
                    await notifier.addReward(
                      const RewardModel(
                        title: 'เหรียญกล้าหาญ',
                        goldCost: 500,
                        description: 'ของสะสมความสำเร็จครบ 7 วันติดต่อกัน',
                        iconName: 'military_tech',
                        itemCategory: RewardCategory.collectible,
                        rarity: ItemRarity.epic,
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(top: 12),
          itemCount: rewards.length,
          itemBuilder: (context, index) {
            final r = rewards[index];
            final canAfford = (user?.gold ?? 0) >= r.goldCost;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border, width: 2),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.card_giftcard_rounded,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                r.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _rarityColor(r.rarity).withAlpha(35),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: _rarityColor(r.rarity),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                r.rarity.displayName,
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: _rarityColor(r.rarity),
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          r.itemCategory.displayName,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                        if (r.description != null)
                          Text(
                            r.description!,
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        const SizedBox(height: 4),
                        Text(
                          '${r.goldCost} Gold',
                          style: const TextStyle(
                            color: AppColors.goldRewardDark,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  RpgButton(
                    text: 'แลกรางวัล',
                    height: 38,
                    fontSize: 13,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    backgroundColor: AppColors.secondary,
                    borderColor: const Color(0xFFD97706),
                    bounceOnTap: true,
                    onPressed: canAfford
                        ? () async {
                            final outcome = await ref
                                .read(rewardsListProvider.notifier)
                                .redeem(r.id!);
                            if (!context.mounted) return;
                            final message = switch (outcome) {
                              RedeemOutcome.success =>
                                'แลก "${r.title}" สำเร็จ! เพลิดเพลินกับรางวัลของคุณ',
                              RedeemOutcome.notEnoughGold =>
                                'เหรียญทองไม่เพียงพอ',
                              RedeemOutcome.inventoryFull =>
                                'คลังไอเทมเต็มแล้ว ไปขยายช่องคลังที่แท็บ "คลังไอเทม" ก่อน',
                            };
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(message),
                                backgroundColor:
                                    outcome == RedeemOutcome.success
                                    ? AppColors.primaryDark
                                    : AppColors.error,
                              ),
                            );
                          }
                        : null,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Inventory Tab
// ---------------------------------------------------------------------------

class _InventoryTab extends ConsumerStatefulWidget {
  const _InventoryTab();

  @override
  ConsumerState<_InventoryTab> createState() => _InventoryTabState();
}

class _InventoryTabState extends ConsumerState<_InventoryTab> {
  RewardCategory? _filter; // null = ทั้งหมด

  IconData _categoryIcon(RewardCategory category) {
    switch (category) {
      case RewardCategory.equipment:
        return Icons.shield_rounded;
      case RewardCategory.consumable:
        return Icons.science_rounded;
      case RewardCategory.collectible:
        return Icons.emoji_events_rounded;
    }
  }

  Future<void> _handleUse(InventoryEntry entry) async {
    try {
      final message = await ref.read(inventoryProvider.notifier).use(entry);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.primaryDark,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e is StateError ? e.message : 'ใช้ไอเทมไม่สำเร็จ: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _handleEquip(InventoryEntry entry) async {
    await ref.read(inventoryProvider.notifier).equip(entry);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('สวมใส่ "${entry.reward.title}" แล้ว'),
        backgroundColor: AppColors.primaryDark,
      ),
    );
  }

  Future<void> _handleExpand() async {
    final ok = await ref.read(inventoryProvider.notifier).expandCapacity();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'ขยายคลังเพิ่ม ${GamificationConfig.inventoryExpandAmount} ช่องแล้ว!'
              : 'Gold ไม่พอสำหรับขยายคลัง (ต้องใช้ ${GamificationConfig.inventoryExpandCost} Gold)',
        ),
        backgroundColor: ok ? AppColors.primaryDark : AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inventoryAsync = ref.watch(inventoryProvider);
    final user = ref.watch(userProvider).valueOrNull;
    final capacity = user?.inventoryCapacity ?? 20;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        // Capacity header
        Row(
          children: [
            Expanded(
              child: inventoryAsync.when(
                data: (entries) => Text(
                  'ความจุคลัง: ${entries.length} / $capacity ช่อง',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                loading: () => const Text('ความจุคลัง: ...'),
                error: (_, _) => const Text('ความจุคลัง: -'),
              ),
            ),
            TextButton.icon(
              onPressed: _handleExpand,
              icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
              label: Text(
                'ขยายช่องคลัง (${GamificationConfig.inventoryExpandCost}G)',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Category filter chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _FilterChip(
                label: 'ทั้งหมด',
                selected: _filter == null,
                onTap: () => setState(() => _filter = null),
              ),
              const SizedBox(width: 8),
              for (final cat in RewardCategory.values) ...[
                _FilterChip(
                  label: cat.displayName,
                  selected: _filter == cat,
                  onTap: () => setState(() => _filter = cat),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),

        Expanded(
          child: inventoryAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(child: Text('ข้อผิดพลาด: $e')),
            data: (entries) {
              final filtered = _filter == null
                  ? entries
                  : entries
                        .where((e) => e.reward.itemCategory == _filter)
                        .toList();

              if (filtered.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 64,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 12),
                      Text('ยังไม่มีไอเทมในคลัง — ไปแลกที่แท็บ "ร้านค้า" ก่อน'),
                    ],
                  ),
                );
              }

              return ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final entry = filtered[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.cardSurface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border, width: 1.5),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: _rarityColor(
                              entry.reward.rarity,
                            ).withAlpha(35),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _rarityColor(entry.reward.rarity),
                              width: 1.5,
                            ),
                          ),
                          child: Icon(
                            _categoryIcon(entry.reward.itemCategory),
                            color: _rarityColor(entry.reward.rarity),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      entry.reward.title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (entry.item.quantity > 1) ...[
                                    const SizedBox(width: 6),
                                    Text(
                                      'x${entry.item.quantity}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              if (entry.reward.description != null)
                                Text(
                                  entry.reward.description!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textMuted,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildAction(entry),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAction(InventoryEntry entry) {
    switch (entry.reward.itemCategory) {
      case RewardCategory.equipment:
        if (entry.item.isEquipped) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.primary),
            ),
            child: const Text(
              'กำลังใช้งาน',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryDark,
              ),
            ),
          );
        }
        return RpgButton(
          text: 'สวมใส่',
          height: 34,
          fontSize: 12,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          backgroundColor: AppColors.primary,
          borderColor: AppColors.primaryDark,
          bounceOnTap: true,
          onPressed: () => _handleEquip(entry),
        );
      case RewardCategory.consumable:
        return RpgButton(
          text: 'ใช้',
          height: 34,
          fontSize: 12,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          backgroundColor: AppColors.secondary,
          borderColor: const Color(0xFFD97706),
          bounceOnTap: true,
          onPressed: () => _handleUse(entry),
        );
      case RewardCategory.collectible:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.goldLight,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.goldRewardDark),
          ),
          child: const Text(
            'ปลดล็อกแล้ว',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppColors.goldRewardDark,
            ),
          ),
        );
    }
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}
