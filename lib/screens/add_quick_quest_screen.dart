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
  final QuestModel? questToEdit;

  const AddQuickQuestScreen({super.key, this.questToEdit});

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
  bool _hasTargetDays = false;
  bool _isCustomDuration = false;
  int _targetDays = 7;
  DateTime? _customEndDate;

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
  void initState() {
    super.initState();
    final q = widget.questToEdit;
    if (q != null) {
      _titleController.text = q.title;
      _difficulty = q.difficulty;
      _frequency = q.habitFrequency;
      if (q.habitCustomWeekdays != null) {
        _customWeekdays.addAll(q.habitCustomWeekdays!);
      }
      if (q.habitTargetDays != null && q.habitTargetDays! > 0) {
        _hasTargetDays = true;
        _targetDays = q.habitTargetDays!;
        if (q.dueDate != null) {
          _customEndDate = DateTime.tryParse(q.dueDate!);
        }
        _isCustomDuration =
            _customEndDate != null ||
            !const [7, 14, 21, 30].contains(_targetDays);
      }
    }
  }

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

  Future<void> _pickCustomEndDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final firstDate = today.add(const Duration(days: 6));
    final initialDate =
        _customEndDate ?? today.add(Duration(days: _targetDays - 1));
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: initialDate.isBefore(firstDate) ? firstDate : initialDate,
      firstDate: firstDate,
      lastDate: today.add(const Duration(days: 3650)),
      helpText: 'เลือกวันสิ้นสุดแคมเปญ',
    );
    if (selectedDate == null || !mounted) return;

    final endDate = DateUtils.dateOnly(selectedDate);
    setState(() {
      _customEndDate = endDate;
      _isCustomDuration = true;
      _targetDays = endDate.difference(today).inDays + 1;
    });
  }

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
    if (_hasTargetDays &&
        _isCustomDuration &&
        _customEndDate == null &&
        !(widget.questToEdit?.isCampaign ?? false)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณาเลือกวันที่สิ้นสุดแคมเปญ'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final reward = ref
        .read(rewardCalculatorProvider)
        .calculateQuickQuestReward(difficulty: _difficulty);

    final isEdit = widget.questToEdit != null;
    final quest = isEdit
        ? widget.questToEdit!.copyWith(
            title: _titleController.text.trim(),
            difficulty: _difficulty,
            expReward: reward.exp,
            goldReward: reward.gold,
            habitFrequency: _frequency,
            habitCustomWeekdays: _frequency == HabitFrequency.custom
                ? (_customWeekdays.toList()..sort())
                : null,
            habitTargetDays: _hasTargetDays ? _targetDays : null,
            dueDate: _customEndDate?.toIso8601String(),
            clearDueDate: !_hasTargetDays || _customEndDate == null,
          )
        : QuestModel(
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
            habitTargetDays: _hasTargetDays ? _targetDays : null,
            dueDate: _customEndDate?.toIso8601String(),
          );

    if (isEdit) {
      await ref.read(questActionsProvider.notifier).updateQuest(quest);
    } else {
      await ref.read(questActionsProvider.notifier).addQuest(quest);
    }

    if (!mounted) return;
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isEdit
              ? '💾 บันทึกการแก้ไขเรียบร้อยแล้ว!'
              : '⚡ สร้างเควสต์ทันใจเรียบร้อยแล้ว!',
        ),
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

    final isEdit = widget.questToEdit != null;
    final isCampaign = widget.questToEdit?.isCampaign ?? false;
    final lockCampaignFrequency = isCampaign || _hasTargetDays;
    final titleText = isEdit
        ? (isCampaign ? 'แก้ไขแคมเปญ' : 'แก้ไขเควสต์ทันใจ')
        : 'สร้างเควสต์ทันใจ';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(isEdit ? 'แก้ไขภารกิจ' : 'สร้างเควสต์ผจญภัย'),
        centerTitle: true,
      ),
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          titleText,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isEdit
                              ? 'แก้ไขรายละเอียดของภารกิจ'
                              : 'ตั้งเป้าหมายประจำวัน ทำเสร็จรับรางวัลทันที',
                          style: const TextStyle(
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
                  Row(
                    children: [
                      const Text(
                        'ระดับความยาก',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      if (isCampaign)
                        const Padding(
                          padding: EdgeInsets.only(left: 8.0),
                          child: Icon(
                            Icons.lock_rounded,
                            size: 14,
                            color: AppColors.textMuted,
                          ),
                        ),
                    ],
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
              AbsorbPointer(
                absorbing: isCampaign,
                child: Opacity(
                  opacity: isCampaign ? 0.6 : 1.0,
                  child: Row(
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
                ),
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
              Row(
                children: [
                  const Text(
                    'ความถี่ในการทำ',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  if (isCampaign)
                    const Padding(
                      padding: EdgeInsets.only(left: 8.0),
                      child: Icon(
                        Icons.lock_rounded,
                        size: 14,
                        color: AppColors.textMuted,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              AbsorbPointer(
                absorbing: lockCampaignFrequency,
                child: Opacity(
                  opacity: lockCampaignFrequency ? 0.6 : 1.0,
                  child: Row(
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
                ),
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
                    onTap: (!isCustom || lockCampaignFrequency)
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

              // ตั้งเป้าหมายแคมเปญ
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text(
                        'ตั้งเป้าหมาย (ระยะเวลาสิ้นสุด)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      if (isCampaign)
                        const Padding(
                          padding: EdgeInsets.only(left: 8.0),
                          child: Icon(
                            Icons.lock_rounded,
                            size: 14,
                            color: AppColors.textMuted,
                          ),
                        ),
                    ],
                  ),
                  Switch(
                    value: _hasTargetDays,
                    onChanged: isCampaign
                        ? null
                        : (val) => setState(() {
                            _hasTargetDays = val;
                            if (val) {
                              _frequency = HabitFrequency.daily;
                              _customWeekdays.clear();
                            }
                          }),
                    activeThumbColor: AppColors.primary,
                  ),
                ],
              ),
              if (!_hasTargetDays)
                const Text(
                  'ค่าเริ่มต้น: ทำต่อเนื่อง (ไม่มีวันสิ้นสุด)',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              if (_hasTargetDays) ...[
                const SizedBox(height: 8),
                AbsorbPointer(
                  absorbing: isCampaign,
                  child: Opacity(
                    opacity: isCampaign ? 0.6 : 1.0,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildDurationChip(7, '7 วัน'),
                            _buildDurationChip(14, '14 วัน'),
                            _buildDurationChip(21, '21 วัน (สร้างนิสัย)'),
                            _buildDurationChip(30, '30 วัน'),
                            _buildDurationChip(0, 'กำหนดเอง'),
                          ],
                        ),
                        if (_isCustomDuration) ...[
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: isCampaign ? null : _pickCustomEndDate,
                            icon: const Icon(Icons.calendar_month_rounded),
                            label: Text(
                              _customEndDate == null
                                  ? 'เลือกวันสิ้นสุด'
                                  : 'สิ้นสุด ${_customEndDate!.day}/${_customEndDate!.month}/${_customEndDate!.year} ($_targetDays วัน)',
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
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

  Widget _buildDurationChip(int days, String label) {
    final isCustom = days == 0;
    final isSelected = isCustom
        ? _isCustomDuration
        : !_isCustomDuration && _targetDays == days;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          if (isCustom) {
            setState(() => _isCustomDuration = true);
            _pickCustomEndDate();
          } else {
            setState(() {
              _targetDays = days;
              _isCustomDuration = false;
              _customEndDate = null;
            });
          }
        }
      },
      selectedColor: AppColors.primaryLight,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primaryDark : AppColors.textSecondary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
