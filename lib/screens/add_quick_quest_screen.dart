import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/quest_enums.dart';
import '../models/quest_model.dart';
import '../providers/core_providers.dart';
import '../providers/quest_providers.dart';
import '../providers/user_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/rpg_button.dart';

/// หน้าสร้าง "เควสต์ทันใจ" (Quick Quest) — สำหรับภารกิจเช็กอิน/ทำเสร็จ
/// ทันที เก็บเป็น Daily Habit เบื้องหลัง เปิดจาก showAddQuestTypeSheet()
/// บนหน้า Dashboard
class AddQuickQuestScreen extends ConsumerStatefulWidget {
  const AddQuickQuestScreen({super.key});

  @override
  ConsumerState<AddQuickQuestScreen> createState() =>
      _AddQuickQuestScreenState();
}

class _AddQuickQuestScreenState extends ConsumerState<AddQuickQuestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();

  int _difficulty = 3;
  HabitFrequency _frequency = HabitFrequency.daily;
  final Set<int> _customWeekdays = {};
  bool _isSaving = false;

  static const List<({int weekday, String label})> _weekdayLabels = [
    (weekday: 1, label: 'จ.'),
    (weekday: 2, label: 'อ.'),
    (weekday: 3, label: 'พ.'),
    (weekday: 4, label: 'พฤ.'),
    (weekday: 5, label: 'ศ.'),
    (weekday: 6, label: 'ส.'),
    (weekday: 7, label: 'อา.'),
  ];

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  String _difficultyLabel(int diff) {
    return switch (diff) {
      1 => 'ง่ายมาก',
      2 => 'ง่าย',
      3 => 'ปานกลาง',
      4 => 'ยาก',
      5 => 'มหากาพย์',
      _ => '',
    };
  }

  List<int> get _effectiveWeekdays => _frequency == HabitFrequency.custom
      ? _customWeekdays.toList()
      : _frequency.fixedWeekdays;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_frequency == HabitFrequency.custom && _customWeekdays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณาเลือกอย่างน้อย 1 วันสำหรับความถี่แบบกำหนดเอง'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final reward = ref
        .read(rewardCalculatorProvider)
        .calculateQuickQuestReward(difficulty: _difficulty);

    final quest = QuestModel(
      title: _titleController.text.trim(),
      category: QuestCategory.daily,
      goalType: QuestGoalType.dailyHabit,
      difficulty: _difficulty,
      expReward: reward.exp,
      goldReward: reward.gold,
      isAutoDifficulty: true,
      createdAt: DateTime.now().toIso8601String(),
      habitFrequency: _frequency,
      habitCustomWeekdays: _frequency == HabitFrequency.custom
          ? (_customWeekdays.toList()..sort())
          : null,
    );

    await ref.read(questActionsProvider.notifier).addQuest(quest);

    if (!mounted) return;
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('⚡ สร้างเควสต์ทันใจเรียบร้อยแล้ว!'),
        backgroundColor: AppColors.primaryDark,
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final calculator = ref.read(rewardCalculatorProvider);
    final reward = calculator.calculateQuickQuestReward(
      difficulty: _difficulty,
    );
    final streakBoost =
        (ref.watch(userProvider).valueOrNull?.streakCount ?? 0) >= 3;
    final hpPreview = calculator.estimateHpGain(
      difficulty: _difficulty,
      streakBoost: streakBoost,
    );
    final effectiveWeekdays = _effectiveWeekdays;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('สร้างเควสต์ผจญภัย'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(35),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.bolt_rounded,
                      color: AppColors.primaryDark,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'สร้างเควสต์ทันใจ',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'ตั้งเป้าหมายประจำวัน ทำเสร็จรับรางวัลทันที',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ชื่อกิจกรรมประจำวัน
              const Text(
                'ชื่อกิจกรรมประจำวัน',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _titleController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'เช่น ดื่มน้ำ 8 แก้ว, ยืดเหยียด 10 นาที...',
                  suffixIcon: const Icon(
                    Icons.edit_rounded,
                    size: 18,
                    color: AppColors.textMuted,
                  ),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.borderLight),
                  ),
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'กรุณาระบุชื่อกิจกรรม'
                    : null,
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.lightbulb_outline_rounded,
                    size: 14,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'เคล็ดลับ: การระบุเป้าหมายที่ชัดเจนจะช่วยให้สำเร็จได้ง่ายขึ้น',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ระดับความยาก
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'ระดับความยาก',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.goldLight,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$_difficulty ดาว (${_difficultyLabel(_difficulty)})',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.goldRewardDark,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final star = index + 1;
                  final isSelected = star <= _difficulty;
                  return IconButton(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      isSelected
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: 36,
                      color: isSelected
                          ? AppColors.difficultyColors[_difficulty - 1]
                          : AppColors.borderLight,
                    ),
                    onPressed: () => setState(() => _difficulty = star),
                  );
                }),
              ),
              Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 13,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 4),
                  const Expanded(
                    child: Text(
                      'ความยากส่งผลต่อค่าตอบแทนและผลกระทบต่อ HP เมื่อไม่สำเร็จ',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ความถี่ในการทำ
              const Text(
                'ความถี่ในการทำ',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Row(
                children: HabitFrequency.values.map((freq) {
                  final isSelected = _frequency == freq;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _frequency = freq),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primaryDark
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primaryDark
                                : AppColors.borderLight,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          freq.displayName,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? Colors.white
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),

              // เลือกวันที่ต้องการปฏิบัติภารกิจ
              const Text(
                'เลือกวันที่ต้องการปฏิบัติภารกิจ:',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: _weekdayLabels.map((wd) {
                  final isCustom = _frequency == HabitFrequency.custom;
                  final isActive = effectiveWeekdays.contains(wd.weekday);
                  return GestureDetector(
                    onTap: !isCustom
                        ? null
                        : () {
                            setState(() {
                              if (_customWeekdays.contains(wd.weekday)) {
                                _customWeekdays.remove(wd.weekday);
                              } else {
                                _customWeekdays.add(wd.weekday);
                              }
                            });
                          },
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: isActive
                            ? AppColors.primaryDark
                            : AppColors.surface,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isActive
                              ? AppColors.primaryDark
                              : AppColors.borderLight,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        wd.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isActive
                              ? Colors.white
                              : (isCustom
                                    ? AppColors.textSecondary
                                    : AppColors.textMuted),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // Reward preview
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.cardSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primary, width: 1.5),
                ),
                child: Column(
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.card_giftcard_rounded,
                          color: AppColors.primaryDark,
                          size: 18,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'รางวัลที่จะได้รับเมื่อสำเร็จ',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _RewardPreviewItem(
                          icon: Icons.circle,
                          iconColor: AppColors.primary,
                          label: 'EXP',
                          amount: '+${reward.exp}',
                        ),
                        _RewardPreviewItem(
                          icon: Icons.circle,
                          iconColor: AppColors.gold,
                          label: 'เหรียญทอง',
                          amount: '+${reward.gold}',
                        ),
                        _RewardPreviewItem(
                          icon: Icons.circle,
                          iconColor: AppColors.error,
                          label: 'ฟื้นฟู HP',
                          amount: '+$hpPreview HP',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: RpgButton(
                  text: 'บันทึกเควสต์ผจญภัย',
                  icon: Icons.eco_rounded,
                  backgroundColor: AppColors.primary,
                  borderColor: AppColors.primaryDark,
                  isLoading: _isSaving,
                  onPressed: _isSaving ? null : _save,
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _RewardPreviewItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String amount;

  const _RewardPreviewItem({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 10, color: iconColor),
            const SizedBox(width: 5),
            Text(
              amount,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: iconColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
        ),
      ],
    );
  }
}
