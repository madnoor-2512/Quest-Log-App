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
  final QuestModel? questToEdit;

  const AddFocusQuestScreen({super.key, this.questToEdit});

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

  List<int> get _effectiveWeekdays => _frequency == HabitFrequency.custom
      ? _customWeekdays.toList()
      : _frequency.fixedWeekdays;

  Widget _buildDurationChip(int days, String label) {
    final selected = days == 0
        ? _isCustomDuration
        : !_isCustomDuration && _targetDays == days;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: widget.questToEdit?.isCampaign ?? false
          ? null
          : (_) {
              if (days == 0) {
                setState(() => _isCustomDuration = true);
                _pickCustomEndDate();
              } else {
                setState(() {
                  _targetDays = days;
                  _isCustomDuration = false;
                  _customEndDate = null;
                });
              }
            },
    );
  }

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
  void initState() {
    super.initState();
    final q = widget.questToEdit;
    if (q != null) {
      _titleController.text = q.title;
      _activityType = q.activityType;
      _estimatedMinutes = q.estimatedMinutes;
      _difficulty = q.difficulty;
      _frequency = q.habitFrequency;
      if (q.habitCustomWeekdays != null) {
        _customWeekdays.addAll(q.habitCustomWeekdays!);
      }
      if (q.isCampaign) {
        _hasTargetDays = true;
        _targetDays = q.habitTargetDays!;
        _customEndDate = q.dueDate == null
            ? null
            : DateTime.tryParse(q.dueDate!);
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_hasTargetDays &&
        _frequency == HabitFrequency.custom &&
        _customWeekdays.isEmpty) {
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

    final isEdit = widget.questToEdit != null;
    try {
      final quest = isEdit
          ? widget.questToEdit!.copyWith(
              title: _titleController.text.trim(),
              difficulty: _difficulty,
              activityType: _activityType,
              estimatedMinutes: _estimatedMinutes,
              expReward: result.expReward,
              goldReward: result.goldReward,
              habitFrequency: _hasTargetDays
                  ? HabitFrequency.daily
                  : _frequency,
              habitCustomWeekdays:
                  !_hasTargetDays && _frequency == HabitFrequency.custom
                  ? (_customWeekdays.toList()..sort())
                  : null,
              habitTargetDays: _hasTargetDays ? _targetDays : 0,
              dueDate: _customEndDate?.toIso8601String(),
              clearDueDate: !_hasTargetDays || _customEndDate == null,
            )
          : QuestModel(
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
              habitFrequency: _hasTargetDays
                  ? HabitFrequency.daily
                  : _frequency,
              habitCustomWeekdays:
                  !_hasTargetDays && _frequency == HabitFrequency.custom
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
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('บันทึกเควสต์ไม่สำเร็จ: $error'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isEdit
              ? '💾 บันทึกการแก้ไขเรียบร้อยแล้ว!'
              : '⏳ สร้างเควสต์โฟกัสเรียบร้อยแล้ว!',
        ),
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
    final effectiveWeekdays = _effectiveWeekdays;

    final isEdit = widget.questToEdit != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(isEdit ? 'แก้ไขภารกิจ' : 'สร้างเควสต์โฟกัส'),
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEdit ? 'แก้ไขเควสต์โฟกัส' : 'สร้างเควสต์โฟกัส',
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
                              : 'ตั้งเป้าหมายและจัดสรรเวลาเพื่อเข้าสู่สมาธิลึก',
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

              // ชื่อเควสต์และเป้าหมาย
              const Text(
                'ชื่อเควสต์',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _titleController,
                maxLines: 1,
                decoration: InputDecoration(
                  hintText: 'เช่น ทบทวนหนังสือสอบ',
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
                      onTap: _hasTargetDays
                          ? null
                          : () => setState(() => _frequency = freq),
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
                    onTap: !isCustom || _hasTargetDays
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
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'ตั้งเป้าหมาย (ระยะเวลาสิ้นสุด)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Switch(
                    value: _hasTargetDays,
                    activeThumbColor: AppColors.primary,
                    onChanged: widget.questToEdit?.isCampaign ?? false
                        ? null
                        : (enabled) => setState(() {
                            _hasTargetDays = enabled;
                            if (enabled) {
                              _frequency = HabitFrequency.daily;
                              _customWeekdays.clear();
                              _targetDays = 7;
                              _isCustomDuration = false;
                              _customEndDate = null;
                            }
                          }),
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
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildDurationChip(7, '7 วัน'),
                    _buildDurationChip(14, '14 วัน'),
                    _buildDurationChip(21, '21 วัน'),
                    _buildDurationChip(30, '30 วัน'),
                    _buildDurationChip(0, 'เลือกวันที่สิ้นสุด'),
                  ],
                ),
                if (_isCustomDuration) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: widget.questToEdit?.isCampaign ?? false
                        ? null
                        : _pickCustomEndDate,
                    icon: const Icon(Icons.calendar_month_rounded),
                    label: Text(
                      _customEndDate == null
                          ? 'เลือกวันที่สิ้นสุด'
                          : 'สิ้นสุด ${_customEndDate!.day}/${_customEndDate!.month}/${_customEndDate!.year} ($_targetDays วัน)',
                    ),
                  ),
                ],
              ],
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
                  text: isEdit ? 'บันทึกการแก้ไข' : 'บันทึกเควสต์โฟกัส',
                  icon: isEdit
                      ? Icons.save_rounded
                      : Icons.hourglass_bottom_rounded,
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
