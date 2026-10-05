import 'package:flutter/material.dart';

import '../models/reward_model.dart';
import '../theme/app_colors.dart';

typedef ItemActionResult = ({bool success, String message});

class ItemDetailsSheet extends StatefulWidget {
  final RewardModel reward;
  final int? quantity;
  final String? primaryLabel;
  final IconData primaryIcon;
  final Future<ItemActionResult> Function()? onPrimary;
  final Future<void> Function()? onDiscard;

  const ItemDetailsSheet({
    super.key,
    required this.reward,
    this.quantity,
    this.primaryLabel,
    this.primaryIcon = Icons.check_rounded,
    this.onPrimary,
    this.onDiscard,
  });

  @override
  State<ItemDetailsSheet> createState() => _ItemDetailsSheetState();
}

class _ItemDetailsSheetState extends State<ItemDetailsSheet> {
  bool _isActing = false;

  Color get _rarityColor => switch (widget.reward.rarity) {
    ItemRarity.common => AppColors.textMuted,
    ItemRarity.rare => const Color(0xFF3B82F6),
    ItemRarity.epic => const Color(0xFF7C3AED),
    ItemRarity.legendary => const Color(0xFFFFD700),
  };

  IconData get _categoryIcon => switch (widget.reward.itemCategory) {
    RewardCategory.equipment => Icons.shield_rounded,
    RewardCategory.consumable => Icons.science_rounded,
    RewardCategory.collectible => Icons.emoji_events_rounded,
  };

  String get _description {
    final description = widget.reward.description?.trim();
    final effect = switch (widget.reward.effectType) {
      ItemEffectType.instantExp =>
        'มอบพลังแห่งประสบการณ์ ${widget.reward.effectValue?.round() ?? 0} EXP ทันที',
      ItemEffectType.instantGold =>
        'เปลี่ยนเป็นเหรียญทอง ${widget.reward.effectValue?.round() ?? 0} Gold ทันที',
      ItemEffectType.extendFocusMinutes =>
        'เพิ่มเวลาโฟกัส ${widget.reward.effectValue?.round() ?? 0} นาที ระหว่างเซสชันที่กำลังทำงาน',
      ItemEffectType.focusTimeBonusPercent =>
        'เพิ่มเวลาโฟกัส ${widget.reward.effectValue?.round() ?? 0}% เมื่อเริ่มเซสชันใหม่ขณะสวมใส่',
      ItemEffectType.parallelQuestSlot =>
        'ปลดล็อกช่องทำเควสต์พร้อมกันช่องที่ 3 เมื่อสวมใส่',
      ItemEffectType.streakRepairHammer =>
        'กู้คืนสตรีคที่ถูกรีเซ็ตได้ภายใน 48 ชั่วโมงหลังขาดต่อเนื่อง',
      ItemEffectType.freezeStreakShield =>
        'ปกป้องสตรีคจากการขาดหาย ${widget.reward.effectValue?.round() ?? 1} วัน',
      ItemEffectType.meltFrozenStreak =>
        'ละลายสถานะ Frozen และมอบโบนัส EXP 25% ให้เควสต์ถัดไป',
      ItemEffectType.none => null,
    };

    if (description == null || description.isEmpty) {
      return effect ?? 'ไอเทมพิเศษจากการผจญภัยใน Quest Log';
    }
    if (effect == null || description.contains(effect)) return description;
    return '$description\n\n$effect';
  }

  Future<void> _runPrimary() async {
    final action = widget.onPrimary;
    if (action == null) return;
    setState(() => _isActing = true);
    try {
      final result = await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: result.success
              ? AppColors.primaryDark
              : AppColors.error,
        ),
      );
      if (result.success) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is StateError ? error.message : 'ดำเนินการไม่สำเร็จ: $error',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isActing = false);
    }
  }

  Future<void> _confirmDiscard() async {
    final count = widget.quantity ?? 1;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันการทิ้งไอเทม'),
        content: Text(
          'คุณแน่ใจหรือไม่ที่จะทิ้ง ${widget.reward.title} (x$count)? ไอเทมนี้จะไม่สามารถกู้คืนได้',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton.tonal(
            style: FilledButton.styleFrom(foregroundColor: AppColors.error),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('ทิ้งไอเทม'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || widget.onDiscard == null) return;

    setState(() => _isActing = true);
    try {
      await widget.onDiscard!();
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ทิ้ง ${widget.reward.title} 1 ชิ้นแล้ว'),
          backgroundColor: AppColors.primaryDark,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ทิ้งไอเทมไม่สำเร็จ: $error'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isActing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reward = widget.reward;
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            20 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderLight,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: _rarityColor.withAlpha(35),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _rarityColor, width: 1.5),
                    ),
                    child: Icon(_categoryIcon, color: _rarityColor, size: 30),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          reward.title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Wrap(
                          spacing: 8,
                          children: [
                            _Badge(
                              label: reward.rarity.displayName,
                              color: _rarityColor,
                            ),
                            _Badge(
                              label: reward.itemCategory.displayName,
                              color: AppColors.textSecondary,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                _description,
                style: const TextStyle(
                  height: 1.45,
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              if (widget.quantity != null) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Icon(
                      Icons.inventory_2_outlined,
                      size: 18,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'มีอยู่ในคลัง: ${widget.quantity} ชิ้น',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              if (widget.onPrimary != null)
                FilledButton.icon(
                  onPressed: _isActing ? null : _runPrimary,
                  icon: Icon(widget.primaryIcon),
                  label: Text(widget.primaryLabel ?? 'ดำเนินการ'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryDark,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              if (widget.onDiscard != null) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _isActing ? null : _confirmDiscard,
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('ทิ้งไอเทม'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                ),
              ],
              if (widget.onPrimary == null && widget.onDiscard == null)
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('ปิด'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withAlpha(150)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
