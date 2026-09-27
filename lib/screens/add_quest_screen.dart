import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/quest_enums.dart';
import '../models/quest_model.dart';
import '../providers/core_providers.dart';
import '../providers/quest_providers.dart';
import '../services/gamification_config.dart';
import '../theme/app_colors.dart';
import '../widgets/rpg_button.dart';

class AddQuestScreen extends ConsumerStatefulWidget {
  final bool showAppBar;
  final VoidCallback? onSaved;

  const AddQuestScreen({super.key, this.showAppBar = true, this.onSaved});

  @override
  ConsumerState<AddQuestScreen> createState() => _AddQuestScreenState();
}

class _AddQuestScreenState extends ConsumerState<AddQuestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _subTaskInputController = TextEditingController();

  QuestCategory _category = QuestCategory.main;
  QuestGoalType _goalType = QuestGoalType.focus;
  ActivityType _activityType = ActivityType.mental;
  int _difficulty = 3;
  int _estimatedMinutes = 25;
  int _habitTargetDays = 30;

  TimeOfDay _habitStartTime = const TimeOfDay(hour: 6, minute: 0);
  TimeOfDay _habitEndTime = const TimeOfDay(hour: 7, minute: 0);

  final List<String> _subTasks = [];

  int _expReward = 30;
  int _goldReward = 15;
  String? _blockReason;

  // Preset quick selections
  static const List<({String title, ActivityType type, int minutes, QuestCategory category})> _presets = [
    (title: '💧 ดื่มน้ำ 8 แก้ว', type: ActivityType.stillness, minutes: 10, category: QuestCategory.daily),
    (title: '📖 อ่านหนังสือ 25 นาที', type: ActivityType.mental, minutes: 25, category: QuestCategory.side),
    (title: '🏃 วิ่งออกกำลังกาย', type: ActivityType.physicalHeavy, minutes: 30, category: QuestCategory.daily),
    (title: '💻 ทำงานลึก (Deep Work)', type: ActivityType.mental, minutes: 45, category: QuestCategory.main),
    (title: '🧘 นั่งสมาธิ ผ่อนคลาย', type: ActivityType.stillness, minutes: 15, category: QuestCategory.daily),
    (title: '🎧 ฟังพอดแคสต์พัฒนาตนเอง', type: ActivityType.audioOnly, minutes: 20, category: QuestCategory.side),
  ];

  @override
  void initState() {
    super.initState();
    _recalcReward();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _subTaskInputController.dispose();
    super.dispose();
  }

  void _recalcReward() {
    if (_goalType == QuestGoalType.dailyHabit) {
      setState(() {
        _blockReason = null;
        _expReward = GamificationConfig.habitDailyExpReward;
        _goldReward = GamificationConfig.habitDailyGoldReward;
      });
      return;
    }

    final calculator = ref.read(rewardCalculatorProvider);
    final result = calculator.calculateAutoReward(
      difficulty: _difficulty,
      estimatedMinutes: _estimatedMinutes,
      activityType: _activityType,
      subTaskCount: _subTasks.length,
    );

    setState(() {
      if (result.isAllowed) {
        _blockReason = null;
        _expReward = result.expReward;
        _goldReward = result.goldReward;
      } else {
        _blockReason = result.blockReason;
      }
    });
  }

  void _addSubTask() {
    final title = _subTaskInputController.text.trim();
    if (title.isEmpty) return;
    setState(() {
      _subTasks.add(title);
      _subTaskInputController.clear();
    });
    _recalcReward();
  }

  void _removeSubTask(int index) {
    setState(() => _subTasks.removeAt(index));
    _recalcReward();
  }

  void _applyPreset(({String title, ActivityType type, int minutes, QuestCategory category}) preset) {
    setState(() {
      _titleController.text = preset.title;
      _activityType = preset.type;
      _estimatedMinutes = preset.minutes;
      _category = preset.category;
      _goalType = QuestGoalType.focus;
    });
    _recalcReward();
  }

  Future<void> _pickHabitTime({required bool isStart}) async {
    final initial = isStart ? _habitStartTime : _habitEndTime;
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      helpText: isStart ? 'เลือกเวลาเริ่มเช็กอิน' : 'เลือกเวลาสิ้นสุดการเช็กอิน',
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _habitStartTime = picked;
        } else {
          _habitEndTime = picked;
        }
      });
    }
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m น.';
  }

  Future<void> _saveQuest() async {
    if (!_formKey.currentState!.validate()) return;

    if (_goalType == QuestGoalType.dailyHabit) {
      final startMin = _habitStartTime.hour * 60 + _habitStartTime.minute;
      final endMin = _habitEndTime.hour * 60 + _habitEndTime.minute;
      if (endMin <= startMin) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('เวลาสิ้นสุดเช็กอินต้องอยู่หลังเวลาเริ่มต้น'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
    }

    if (_blockReason != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_blockReason!),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final quest = QuestModel(
      title: _titleController.text.trim(),
      description: _descController.text.trim().isEmpty
          ? null
          : _descController.text.trim(),
      category: _category,
      difficulty: _difficulty,
      activityType: _activityType,
      goalType: _goalType,
      estimatedMinutes: _goalType == QuestGoalType.dailyHabit
          ? 0
          : _estimatedMinutes,
      expReward: _expReward,
      goldReward: _goldReward,
      isAutoDifficulty: true,
      createdAt: DateTime.now().toIso8601String(),
      habitStartMinute: _goalType == QuestGoalType.dailyHabit
          ? (_habitStartTime.hour * 60 + _habitStartTime.minute)
          : null,
      habitEndMinute: _goalType == QuestGoalType.dailyHabit
          ? (_habitEndTime.hour * 60 + _habitEndTime.minute)
          : null,
      habitTargetDays: _goalType == QuestGoalType.dailyHabit
          ? _habitTargetDays
          : null,
    );

    await ref
        .read(questActionsProvider.notifier)
        .addQuest(quest, subTaskTitles: _subTasks);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🎉 สร้างเควสใหม่เรียบร้อยแล้ว!'),
        backgroundColor: AppColors.primaryDark,
      ),
    );

    _titleController.clear();
    _descController.clear();
    setState(() => _subTasks.clear());
    _recalcReward();

    if (widget.onSaved != null) {
      widget.onSaved!();
    } else if (Navigator.canPop(context)) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: widget.showAppBar
          ? AppBar(
              title: const Text('สร้างเควสใหม่ (New Quest)'),
              centerTitle: true,
            )
          : null,
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(12),
              blurRadius: 8,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          child: RpgButton(
            text: '⚔️ ยืนยันสร้างเควส',
            backgroundColor: AppColors.primary,
            borderColor: AppColors.primaryDark,
            width: double.infinity,
            onPressed: _saveQuest,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header title when embedded in bottom navigation
              if (!widget.showAppBar) ...[
                const Text(
                  'เพิ่มเควสใหม่ (New Quest)',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'กำหนดเป้าหมายการผจญภัย เพื่อรับ EXP และ Gold',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
                const SizedBox(height: 16),
              ],

              // -------------------------------------------------------------
              // Quick Presets
              // -------------------------------------------------------------
              _buildSectionHeader(
                icon: Icons.flash_on_rounded,
                iconColor: AppColors.secondary,
                title: 'ภารกิจด่วนยอดนิยม (Presets)',
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _presets.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final preset = _presets[index];
                    return ActionChip(
                      backgroundColor: AppColors.cardSurface,
                      side: const BorderSide(color: AppColors.borderLight),
                      label: Text(
                        preset.title,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      onPressed: () => _applyPreset(preset),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),

              // -------------------------------------------------------------
              // Card 1: ข้อมูลเควสพื้นฐาน
              // -------------------------------------------------------------
              _buildCardContainer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader(
                      icon: Icons.edit_note_rounded,
                      iconColor: AppColors.primary,
                      title: 'รายละเอียดภารกิจ',
                    ),
                    const SizedBox(height: 14),

                    // Quest Title
                    TextFormField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        labelText: 'ชื่อเควส / ภารกิจ *',
                        hintText: 'เช่น วิ่งออกกำลังกาย 30 นาที, อ่านหนังสือ',
                        prefixIcon: const Icon(Icons.stars_rounded, color: AppColors.primary),
                        filled: true,
                        fillColor: AppColors.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'กรุณาระบุชื่อเควส' : null,
                    ),
                    const SizedBox(height: 12),

                    // Quest Description
                    TextFormField(
                      controller: _descController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'บันทึกเพิ่มเติม (ไม่บังคับ)',
                        hintText: 'รายละเอียดหรือเงื่อนไขภารกิจ',
                        prefixIcon: const Icon(Icons.notes_rounded, color: AppColors.textMuted),
                        filled: true,
                        fillColor: AppColors.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.borderLight),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Category Selector
                    const Text(
                      'หมวดหมู่เควส',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: QuestCategory.values.map((cat) {
                        final isSelected = _category == cat;
                        final ({String label, IconData icon, Color color}) info = switch (cat) {
                          QuestCategory.main => (label: 'เควสหลัก', icon: Icons.flag_rounded, color: AppColors.mainQuest),
                          QuestCategory.side => (label: 'เควสรอง', icon: Icons.explore_rounded, color: AppColors.sideQuest),
                          QuestCategory.daily => (label: 'ประจำวัน', icon: Icons.repeat_rounded, color: AppColors.dailyQuest),
                        };

                        return Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() => _category = cat);
                              _recalcReward();
                            },
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected ? info.color.withAlpha(35) : AppColors.surface,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected ? info.color : AppColors.borderLight,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(info.icon, color: info.color, size: 20),
                                  const SizedBox(height: 4),
                                  Text(
                                    info.label,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                      color: isSelected ? info.color : AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // -------------------------------------------------------------
              // Card 2: รูปแบบเป้าหมาย (Focus vs Daily Habit)
              // -------------------------------------------------------------
              _buildCardContainer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader(
                      icon: Icons.track_changes_rounded,
                      iconColor: AppColors.secondary,
                      title: 'รูปแบบเป้าหมาย (Goal Type)',
                    ),
                    const SizedBox(height: 12),

                    // 2 Tab selectors
                    Row(
                      children: [
                        Expanded(
                          child: _buildGoalTypeButton(
                            title: '🎯 Focus Quest',
                            subtitle: 'จับเวลาโฟกัสทำงาน',
                            isSelected: _goalType == QuestGoalType.focus,
                            onTap: () {
                              setState(() => _goalType = QuestGoalType.focus);
                              _recalcReward();
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildGoalTypeButton(
                            title: '🔄 Daily Habit',
                            subtitle: 'เช็กอินนิสัยประจำวัน',
                            isSelected: _goalType == QuestGoalType.dailyHabit,
                            onTap: () {
                              setState(() => _goalType = QuestGoalType.dailyHabit);
                              _recalcReward();
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Goal Type Specific Config
                    if (_goalType == QuestGoalType.focus) ...[
                      // Quick minutes selector
                      const Text(
                        'ระยะเวลาโฟกัส (นาที)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [15, 25, 45, 60, 90].map((mins) {
                          final isSelected = _estimatedMinutes == mins;
                          return ChoiceChip(
                            label: Text(mins == 25 ? '25 นาที (Pomodoro)' : '$mins นาที'),
                            selected: isSelected,
                            selectedColor: AppColors.primaryLight,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() => _estimatedMinutes = mins);
                                _recalcReward();
                              }
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Slider(
                              value: _estimatedMinutes.toDouble(),
                              min: 5,
                              max: 180,
                              divisions: 35,
                              activeColor: AppColors.primary,
                              onChanged: (val) {
                                setState(() => _estimatedMinutes = val.round());
                                _recalcReward();
                              },
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$_estimatedMinutes นาที',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Difficulty Rating Stars
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'ระดับความยาก (Difficulty)',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          Text(
                            _difficultyLabel(_difficulty),
                            style: const TextStyle(
                              color: AppColors.secondaryDark,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
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
                              isSelected ? Icons.star_rounded : Icons.star_outline_rounded,
                              size: 38,
                              color: isSelected ? AppColors.difficultyColors[_difficulty - 1] : AppColors.borderLight,
                            ),
                            onPressed: () {
                              setState(() => _difficulty = star);
                              _recalcReward();
                            },
                          );
                        }),
                      ),
                      const SizedBox(height: 14),

                      // Activity Type Selector
                      const Text(
                        'ประเภทกิจกรรม (Activity Type)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: ActivityType.values.map((act) {
                          final isSelected = _activityType == act;
                          final ({String label, IconData icon}) item = switch (act) {
                            ActivityType.mental => (label: '🧠 สมาธิ/ปัญญา', icon: Icons.psychology_rounded),
                            ActivityType.physicalHeavy => (label: '⚔️ ใช้แรง/กาย', icon: Icons.fitness_center_rounded),
                            ActivityType.stillness => (label: '🧘 นิ่ง/ผ่อนคลาย', icon: Icons.self_improvement_rounded),
                            ActivityType.audioOnly => (label: '🎧 การฟัง', icon: Icons.headphones_rounded),
                          };

                          return ChoiceChip(
                            avatar: Icon(item.icon, size: 16),
                            label: Text(item.label),
                            selected: isSelected,
                            selectedColor: AppColors.secondaryLight,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() => _activityType = act);
                                _recalcReward();
                              }
                            },
                          );
                        }).toList(),
                      ),
                    ] else ...[
                      // Daily Habit Configuration
                      const Text(
                        'ช่วงเวลาเช็กอินประจำวัน',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTimePickerTile(
                              label: 'เริ่มเช็กอิน',
                              time: _habitStartTime,
                              onTap: () => _pickHabitTime(isStart: true),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Icon(Icons.arrow_forward_rounded, color: AppColors.textMuted),
                          ),
                          Expanded(
                            child: _buildTimePickerTile(
                              label: 'สิ้นสุดเช็กอิน',
                              time: _habitEndTime,
                              onTap: () => _pickHabitTime(isStart: false),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'เป้าหมายความต่อเนื่อง (Streak)',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.secondaryLight,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$_habitTargetDays วัน',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.secondaryDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Slider(
                        value: _habitTargetDays.toDouble(),
                        min: 7,
                        max: 90,
                        divisions: 83,
                        activeColor: AppColors.secondary,
                        onChanged: (val) => setState(() => _habitTargetDays = val.round()),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // -------------------------------------------------------------
              // Card 3: ภารกิจย่อย (Sub-tasks)
              // -------------------------------------------------------------
              _buildCardContainer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSectionHeader(
                          icon: Icons.checklist_rounded,
                          iconColor: AppColors.primaryDark,
                          title: 'ภารกิจย่อย (Sub-tasks)',
                        ),
                        if (_subTasks.isNotEmpty)
                          Text(
                            '${_subTasks.length} รายการ',
                            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _subTaskInputController,
                            decoration: InputDecoration(
                              hintText: 'เพิ่มข้อย่อย เช่น อ่านบทที่ 1, สรุปข้อคิด',
                              filled: true,
                              fillColor: AppColors.surface,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: AppColors.borderLight),
                              ),
                            ),
                            onSubmitted: (_) => _addSubTask(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          onPressed: _addSubTask,
                          icon: const Icon(Icons.add_rounded),
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),

                    if (_subTasks.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _subTasks.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 6),
                        itemBuilder: (context, i) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.borderLight),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.check_box_outline_blank_rounded,
                                  size: 18,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _subTasks[i],
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.error),
                                  onPressed: () => _removeSubTask(i),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // -------------------------------------------------------------
              // Card 4: รางวัลที่จะได้รับ (Reward Summary)
              // -------------------------------------------------------------
              if (_blockReason != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.error.withAlpha(25),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.error, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'ไม่สามารถสร้างเควสได้ตามเงื่อนไขเกม',
                              style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.error),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _blockReason!,
                              style: const TextStyle(fontSize: 13, color: AppColors.error),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.cardSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.levelGold, width: 2),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1AFFD700),
                        blurRadius: 10,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.military_tech_rounded, color: AppColors.goldRewardDark, size: 20),
                          SizedBox(width: 6),
                          Text(
                            'รางวัลภารกิจ (Quest Rewards)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildRewardItem(
                            icon: Icons.star_rounded,
                            iconColor: AppColors.primary,
                            label: 'EXP ที่จะได้รับ',
                            amount: '+$_expReward',
                          ),
                          Container(width: 1, height: 36, color: AppColors.borderLight),
                          _buildRewardItem(
                            icon: Icons.monetization_on_rounded,
                            iconColor: AppColors.levelGold,
                            label: 'GOLD ที่จะได้รับ',
                            amount: '+$_goldReward',
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _goalType == QuestGoalType.focus
                            ? '🔥 Difficulty x${GamificationConfig.difficultyMultipliers[_difficulty]!.toStringAsFixed(1)}'
                            : '⚡ ค่าคงที่ Habit: +${GamificationConfig.habitDailyExpReward} EXP, +${GamificationConfig.habitDailyGoldReward} G ต่อวัน',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Helper Widgets
  // ---------------------------------------------------------------------------

  Widget _buildSectionHeader({
    required IconData icon,
    required Color iconColor,
    required String title,
  }) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildCardContainer({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildGoalTypeButton({
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryLight : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.borderLight,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: isSelected ? AppColors.primaryDark : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimePickerTile({
    required String label,
    required TimeOfDay time,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.access_time_rounded, size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  _formatTimeOfDay(time),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRewardItem({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String amount,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, color: iconColor, size: 18),
            const SizedBox(width: 6),
            Text(
              amount,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: iconColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
        ),
      ],
    );
  }

  String _difficultyLabel(int diff) {
    return switch (diff) {
      1 => 'ง่ายมาก (Beginner)',
      2 => 'ง่าย (Easy)',
      3 => 'ปานกลาง (Medium)',
      4 => 'ยาก (Hard)',
      5 => 'มหากาพย์ (Nightmare)',
      _ => '',
    };
  }
}
