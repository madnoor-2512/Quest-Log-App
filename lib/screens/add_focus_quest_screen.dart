import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/quest_enums.dart';
import '../models/quest_model.dart';
import '../providers/core_providers.dart';
import '../providers/quest_providers.dart';
import '../providers/user_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/rpg_button.dart';

/// หน้าสร้าง "เควสต์โฟกัส" (Focus Quest) — สำหรับภารกิจที่ต้องใช้เวลาและ
/// สมาธิ เปิดจาก showAddQuestTypeSheet() บนหน้า Dashboard
class AddFocusQuestScreen extends ConsumerStatefulWidget {
  const AddFocusQuestScreen({super.key});

  @override
  ConsumerState<AddFocusQuestScreen> createState() =>
      _AddFocusQuestScreenState();
}

class _AddFocusQuestScreenState extends ConsumerState<AddFocusQuestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();

  ActivityType _activityType = ActivityType.mental;
  int _estimatedMinutes = 50;
  int _difficulty = 3;
  bool _isSaving = false;

  static const List<({ActivityType type, String label, IconData icon})>
  _activityOptions = [
    (
      type: ActivityType.physicalHeavy,
      label: 'เคลื่อนไหวร่างกาย',
      icon: Icons.directions_run_rounded,
    ),
    (
      type: ActivityType.stillness,
      label: 'พักผ่อน & สงบนิ่ง',
      icon: Icons.self_improvement_rounded,
    ),
    (
      type: ActivityType.audioOnly,
      label: 'เสพสื่อเสียง',
      icon: Icons.headphones_rounded,
    ),
    (
      type: ActivityType.mental,
      label: 'จดจ่อ & ใช้สมอง',
      icon: Icons.psychology_rounded,
    ),
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final calculator = ref.read(rewardCalculatorProvider);
    final result = calculator.calculateAutoReward(
      difficulty: _difficulty,
      estimatedMinutes: _estimatedMinutes,
      activityType: _activityType,
    );

    if (!result.isAllowed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.blockReason ?? 'ไม่สามารถสร้างเควสต์นี้ได้'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final quest = QuestModel(
      title: _titleController.text.trim(),
      category: QuestCategory.side,
      goalType: QuestGoalType.focus,
      difficulty: _difficulty,
      activityType: _activityType,
      estimatedMinutes: _estimatedMinutes,
      isAutoDifficulty: true,
      expReward: result.expReward,
      goldReward: result.goldReward,
      createdAt: DateTime.now().toIso8601String(),
    );

    await ref.read(questActionsProvider.notifier).addQuest(quest);

    if (!mounted) return;
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('⏳ สร้างเควสต์โฟกัสเรียบร้อยแล้ว!'),
        backgroundColor: AppColors.goldRewardDark,
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final calculator = ref.read(rewardCalculatorProvider);
    final result = calculator.calculateAutoReward(
      difficulty: _difficulty,
      estimatedMinutes: _estimatedMinutes,
      activityType: _activityType,
    );
    final streakBoost =
        (ref.watch(userProvider).valueOrNull?.streakCount ?? 0) >= 3;
    final hpPreview = calculator.estimateHpGain(
      difficulty: _difficulty,
      streakBoost: streakBoost,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('สร้างเควสต์โฟกัส'), centerTitle: true),
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
                      color: AppColors.goldRewardDark.withAlpha(35),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.hourglass_top_rounded,
                      color: AppColors.goldRewardDark,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'สร้างเควสต์โฟกัส',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'ตั้งเป้าหมายและจัดสรรเวลาเพื่อเข้าสู่สมาธิลึก',
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

              // ชื่อเควสต์และเป้าหมาย
              const Text(
                'ชื่อเควสต์และเป้าหมาย',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _titleController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'เช่น ทบทวนหนังสือสอบ, เขียนโค้ดระบบเควสต์...',
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
                    ? 'กรุณาระบุชื่อเควสต์'
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
                      'เคล็ดลับ: การระบุขอบเขตงานให้ชัดเจนจะช่วยให้โฟกัสได้ต่อเนื่อง',
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

              // ประเภทกิจกรรม
              const Text(
                'ประเภทกิจกรรม',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _activityOptions.map((opt) {
                  final isSelected = _activityType == opt.type;
                  return ChoiceChip(
                    avatar: Icon(
                      opt.icon,
                      size: 16,
                      color: isSelected ? Colors.white : AppColors.textMuted,
                    ),
                    label: Text(opt.label),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                    selected: isSelected,
                    selectedColor: AppColors.primaryDark,
                    backgroundColor: AppColors.surface,
                    showCheckmark: true,
                    checkmarkColor: Colors.white,
                    onSelected: (selected) {
                      if (selected) setState(() => _activityType = opt.type);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // ระยะเวลาโฟกัส
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'ระยะเวลาโฟกัส',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.secondaryLight,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$_estimatedMinutes นาที',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.secondaryDark,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: AppColors.secondary,
                  thumbColor: AppColors.secondary,
                  overlayColor: AppColors.secondary.withAlpha(40),
                ),
                child: Slider(
                  value: _estimatedMinutes.toDouble(),
                  min: 5,
                  max: 180,
                  divisions: 35,
                  onChanged: (val) =>
                      setState(() => _estimatedMinutes = val.round()),
                ),
              ),
              Row(
                children: [
                  const Icon(
                    Icons.access_time_rounded,
                    size: 14,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'กำหนดเวลา $_estimatedMinutes นาที',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

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
                      color: AppColors.secondaryLight,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'ระดับ $_difficulty : ${_difficultyLabel(_difficulty)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.secondaryDark,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
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
                      'ระดับความยากส่งผลต่อ EXP และพลังชาร์จที่ได้รับ',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Reward preview
              if (!result.isAllowed)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.error.withAlpha(25),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.error, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: AppColors.error,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          result.blockReason ?? '',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.cardSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.goldRewardDark,
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.emoji_events_rounded,
                            color: AppColors.goldRewardDark,
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
                            amount: '+${result.expReward}',
                          ),
                          _RewardPreviewItem(
                            icon: Icons.circle,
                            iconColor: AppColors.gold,
                            label: 'เหรียญทอง',
                            amount: '+${result.goldReward}',
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
                  text: 'บันทึกเควสต์โฟกัส',
                  icon: Icons.hourglass_bottom_rounded,
                  backgroundColor: AppColors.secondary,
                  borderColor: AppColors.secondaryDark,
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
