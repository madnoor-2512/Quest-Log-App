import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/reward_model.dart';
import '../models/user_model.dart';
import '../providers/inventory_providers.dart';
import '../providers/rewards_providers.dart';
import '../providers/user_provider.dart';
import '../services/gamification_config.dart';
import '../theme/app_colors.dart';
import '../widgets/add_custom_reward_sheet.dart';

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

class RewardsScreen extends ConsumerStatefulWidget {
  final int initialTabIndex;
  const RewardsScreen({super.key, this.initialTabIndex = 0});

  @override
  ConsumerState<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends ConsumerState<RewardsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.invalidate(rewardsListProvider));
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final userAsync = ref.watch(userProvider);
    final user = userAsync.valueOrNull;

    return DefaultTabController(
      length: 3,
      initialIndex: widget.initialTabIndex,
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

                const TabBar(
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textMuted,
                  indicatorColor: AppColors.primary,
                  tabs: [
                    Tab(text: 'ร้านค้า'),
                    Tab(text: 'รางวัลชีวิตจริง'),
                    Tab(text: 'คลังไอเทม'),
                  ],
                ),

                Expanded(
                  child: TabBarView(
                    children: [
                      _ShopTab(user: user),
                      _RealLifeRewardsTab(user: user),
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rewardsAsync = ref.watch(rewardsListProvider);

    return rewardsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('ข้อผิดพลาด: $e')),
      data: (rewards) {
        if (rewards.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.storefront_outlined, size: 64, color: Colors.grey),
                SizedBox(height: 12),
                Text('กำลังเตรียมรางวัลระบบ...'),
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
            final rarityClr = _rarityColor(r.rarity);

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
                  // Icon container — same style as inventory
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: rarityClr.withAlpha(35),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: rarityClr, width: 1.5),
                    ),
                    child: Icon(_categoryIcon(r.itemCategory), color: rarityClr),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title + rarity badge
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                r.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
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
                                color: rarityClr.withAlpha(35),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: rarityClr, width: 1),
                              ),
                              child: Text(
                                r.rarity.displayName,
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: rarityClr,
                                ),
                              ),
                            ),
                          ],
                        ),
                        // Category name
                        Text(
                          r.itemCategory.displayName,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                        // Description
                        if (r.description != null)
                          Text(
                            r.description!,
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        const SizedBox(height: 2),
                        // Gold cost
                        Row(
                          children: [
                            const Icon(
                              Icons.monetization_on_rounded,
                              size: 13,
                              color: AppColors.goldRewardDark,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '${r.goldCost} Gold',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.goldRewardDark,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Buy button
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: canAfford
                          ? AppColors.secondary
                          : Colors.grey.shade400,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
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
                              RedeemOutcome.purchaseLimitReached =>
                                'รางวัลนี้ถึงโควตาการแลกในช่วงเวลานี้แล้ว',
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
                    child: const Text('แลกรางวัล', style: TextStyle(fontSize: 13)),
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

class _RealLifeRewardsTab extends ConsumerWidget {
  final UserModel? user;
  const _RealLifeRewardsTab({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rewardsAsync = ref.watch(rewardsListProvider);
    return rewardsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(child: Text('ข้อผิดพลาด: $error')),
      data: (rewards) {
        final customRewards = rewards.where((reward) => reward.isCustomReward).toList();
        return Column(
          children: [
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final reward = await showModalBottomSheet<RewardModel>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: AppColors.background,
                    builder: (_) => const AddCustomRewardSheet(),
                  );
                  if (reward == null || !context.mounted) return;
                  try {
                    await ref
                        .read(rewardsListProvider.notifier)
                        .addCustomReward(reward);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('เพิ่มรางวัลชีวิตจริงแล้ว')),
                    );
                  } catch (error) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('บันทึกไม่สำเร็จ: $error')),
                    );
                  }
                },
                icon: const Icon(Icons.add_rounded),
                label: const Text('+ เพิ่มรางวัลชีวิตจริง'),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: customRewards.isEmpty
                  ? const Center(
                      child: Text('ยังไม่มีรางวัลชีวิตจริง เพิ่มเป้าหมายแรกของคุณได้เลย'),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(top: 8),
                      itemCount: customRewards.length,
                      itemBuilder: (context, index) => _CustomRewardCard(
                        reward: customRewards[index],
                        user: user,
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _CustomRewardCard extends ConsumerWidget {
  final RewardModel reward;
  final UserModel? user;
  const _CustomRewardCard({required this.reward, required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canAfford = (user?.gold ?? 0) >= reward.goldCost;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.auto_awesome_rounded, color: AppColors.secondary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(reward.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  if (reward.description != null) Text(reward.description!),
                  Text(
                    '${reward.goldCost} Gold • ${reward.impactLevel.displayName} • ${reward.purchaseLimit.displayName}',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
            FilledButton(
              onPressed: canAfford
                  ? () async {
                      final outcome = await ref
                          .read(rewardsListProvider.notifier)
                          .redeem(reward.id!);
                      if (!context.mounted) return;
                      final message = switch (outcome) {
                        RedeemOutcome.success => 'แลกรางวัลสำเร็จ',
                        RedeemOutcome.notEnoughGold => 'Gold ไม่พอ',
                        RedeemOutcome.inventoryFull => 'คลังไอเทมเต็ม',
                        RedeemOutcome.purchaseLimitReached => 'ถึงโควตาการแลกแล้ว',
                      };
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
                    }
                  : null,
              child: const Text('แลก'),
            ),
          ],
        ),
      ),
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
        return OutlinedButton(
          onPressed: () => _handleEquip(entry),
          child: const Text('สวมใส่'),
        );
      case RewardCategory.consumable:
        return ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondary),
          onPressed: () => _handleUse(entry),
          child: const Text('ใช้'),
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
