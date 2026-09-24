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
  final _habitStartController = TextEditingController(text: '05:00');
  final _habitEndController = TextEditingController(text: '05:30');

  QuestCategory _category = QuestCategory.main;
  QuestGoalType _goalType = QuestGoalType.focus;
  ActivityType _activityType = ActivityType.mental;
  int _difficulty = 3;
  int _estimatedMinutes = 25;
  int _habitTargetDays = 30;
  final List<String> _subTasks = [];

  int _expReward = 30;
  int _goldReward = 15;

  String? _blockReason;

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
    _habitStartController.dispose();
    _habitEndController.dispose();
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

  int _parseTime(String value) {
    final parts = value.split(':');
    if (parts.length != 2) return -1;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null || hour > 23 || minute > 59) return -1;
    return hour * 60 + minute;
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

  void _applyPreset({
    required String title,
    required ActivityType activityType,
    required int minutes,
  }) {
    setState(() {
      _titleController.text = title;
      _activityType = activityType;
      _estimatedMinutes = minutes;
      _goalType = QuestGoalType.focus;
    });
    _recalcReward();
  }

  String get _statAlignment {
    switch (_activityType) {
      case ActivityType.physicalHeavy:
        return '⚔️ STR +5  •  พลังและความอึด';
      case ActivityType.mental:
        return '🔮 INT +5  •  สมาธิและการเรียนรู้';
      case ActivityType.audioOnly:
        return '🛡️ WIS +3  •  การรับรู้และภาษา';
      case ActivityType.stillness:
        return '🛡️ DEX +3  •  สมดุลและการควบคุม';
    }
  }

  Future<void> _saveQuest() async {
    if (!_formKey.currentState!.validate()) return;
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
          ? _parseTime(_habitStartController.text)
          : null,
        habitEndMinute: _goalType == QuestGoalType.dailyHabit
          ? _parseTime(_habitEndController.text)
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
          ? AppBar(title: const Text('เพิ่มเควสใหม่ (New Quest)'))
          : null,
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: RpgButton(
            text: '⚔️ ยืนยันรับเควส',
            backgroundColor: AppColors.primary,
            borderColor: AppColors.primaryDark,
            width: double.infinity,
            onPressed: _saveQuest,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!widget.showAppBar) ...[
                const Text(
                  'เพิ่มเควสใหม่ (New Quest)',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              // Title
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.edit_note_rounded),
                  labelText: 'ชื่อเควส / ภารกิจ',
                  hintText: 'เช่น เขียนรายงานประจำเดือน',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'กรุณาระบุชื่อเควส' : null,
              ),
              const SizedBox(height: 16),
              const Text(
                'Quick Presets',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(
                    label: const Text('💧 ดื่มน้ำ 8 แก้ว'),
                    onPressed: () => _applyPreset(
                      title: 'ดื่มน้ำ 8 แก้ว',
                      activityType: ActivityType.stillness,
                      minutes: 10,
                    ),
                  ),
                  ActionChip(
                    label: const Text('📖 อ่านหนังสือ 20 นาที'),
                    onPressed: () => _applyPreset(
                      title: 'อ่านหนังสือ',
                      activityType: ActivityType.mental,
                      minutes: 20,
                    ),
                  ),
                  ActionChip(
                    label: const Text('🏃 วิ่ง 15 นาที'),
                    onPressed: () => _applyPreset(
                      title: 'วิ่ง',
                      activityType: ActivityType.physicalHeavy,
                      minutes: 15,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              const Text(
                'รูปแบบเป้าหมาย (Goal Type)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const Text(
                'เลือกวิธีทำเควส เพื่อให้ระบบติดตามและให้รางวัลได้ถูกต้อง',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: QuestGoalType.values.map((type) {
                  return ChoiceChip(
                    label: Text(type.displayName),
                    selected: _goalType == type,
                    onSelected: (selected) {
                      if (!selected) return;
                      setState(() => _goalType = type);
                      _recalcReward();
                    },
                  );
                }).toList(),
              ),
              if (_goalType == QuestGoalType.dailyHabit) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _habitStartController,
                        decoration: const InputDecoration(
                          labelText: 'เริ่มเช็กอิน (HH:mm)',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) => _parseTime(value ?? '') < 0
                            ? 'ใช้รูปแบบ HH:mm'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _habitEndController,
                        decoration: const InputDecoration(
                          labelText: 'สิ้นสุด (HH:mm)',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final end = _parseTime(value ?? '');
                          if (end < 0) return 'ใช้รูปแบบ HH:mm';
                          final start = _parseTime(_habitStartController.text);
                          if (start >= 0 && end <= start) {
                            return 'ต้องหลังเวลาเริ่ม';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('ระยะเวลาเป้าหมาย'),
                    Text('$_habitTargetDays วัน'),
                  ],
                ),
                Slider(
                  value: _habitTargetDays.toDouble(),
                  min: 7,
                  max: 90,
                  divisions: 83,
                  onChanged: (value) =>
                      setState(() => _habitTargetDays = value.round()),
                ),
              ],
              const SizedBox(height: 20),

              // Description
              TextFormField(
                controller: _descController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'รายละเอียดเพิ่มเติม (ถ้ามี)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Category selector
              const Text(
                'หมวดหมู่เควส',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: QuestCategory.values.map((cat) {
                  final isSelected = _category == cat;
                  return ChoiceChip(
                    label: Text(cat.displayName),
                    selected: isSelected,
                    onSelected: (sel) {
                      if (sel) {
                        setState(() => _category = cat);
                        _recalcReward();
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // Activity Type
              const Text(
                'ประเภทกิจกรรม (Activity Type)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: ActivityType.values.map((act) {
                  final isSelected = _activityType == act;
                  return ChoiceChip(
                    label: Text(act.displayName),
                    selected: isSelected,
                    onSelected: (sel) {
                      if (sel) {
                        setState(() => _activityType = act);
                        _recalcReward();
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.primary),
                ),
                child: Text(
                  _statAlignment,
                  style: const TextStyle(
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Sub-tasks (dynamic list)
              const Text(
                'Sub-tasks (ถ้ามี)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _subTaskInputController,
                      decoration: InputDecoration(
                        hintText: 'เช่น อ่านบทที่ 1',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onFieldSubmitted: (_) => _addSubTask(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _addSubTask,
                    icon: const Icon(Icons.add_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.primary,
                    ),
                  ),
                ],
              ),
              if (_subTasks.isNotEmpty) ...[
                const SizedBox(height: 8),
                ...List.generate(_subTasks.length, (i) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.cardSurface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border, width: 1.5),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_box_outline_blank_rounded,
                          size: 18,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_subTasks[i])),
                        IconButton(
                          icon: const Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: AppColors.error,
                          ),
                          onPressed: () => _removeSubTask(i),
                        ),
                      ],
                    ),
                  );
                }),
              ],

              const SizedBox(height: 20),

              if (_goalType == QuestGoalType.focus) ...[
              // Difficulty Slider
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'ระดับความยาก (Difficulty):',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '$_difficulty ★',
                    style: const TextStyle(
                      color: AppColors.secondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Slider(
                value: _difficulty.toDouble(),
                min: 1,
                max: 5,
                divisions: 4,
                activeColor: AppColors.secondary,
                onChanged: (val) {
                  setState(() => _difficulty = val.round());
                  _recalcReward();
                },
              ),
              const SizedBox(height: 12),

              // Estimated minutes
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'เวลาที่คาดการณ์ (นาที):',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '$_estimatedMinutes นาที',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Slider(
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
              const SizedBox(height: 16),
              ],

              const Text(
                'รางวัลคำนวณอัตโนมัติจากความยาก เวลา ประเภทกิจกรรม และ Sub-tasks',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 12),

              // Reward Preview (auto) / Block Warning (auto)
              if (_blockReason != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withAlpha(25),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.error),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: AppColors.error,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _blockReason!,
                          style: const TextStyle(
                            color: AppColors.error,
                            fontWeight: FontWeight.bold,
                          ),
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
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border, width: 2),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          const Text(
                            'EXP รางวัล',
                            style: TextStyle(color: AppColors.textMuted),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '+$_expReward',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                      Container(width: 1, height: 30, color: AppColors.border),
                      Column(
                        children: [
                          const Text(
                            'GOLD รางวัล',
                            style: TextStyle(color: AppColors.textMuted),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '+$_goldReward',
                            style: const TextStyle(
                              color: AppColors.levelGold,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              if (_blockReason == null) ...[
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    '🔥 Difficulty Bonus x${GamificationConfig.difficultyMultipliers[_difficulty]!.toStringAsFixed(1)}'
                    '${_subTasks.length > GamificationConfig.maxRewardedSubTasks ? '  •  Sub-task bonus capped at ${GamificationConfig.maxRewardedSubTasks}' : ''}',
                    style: const TextStyle(
                      color: AppColors.secondaryDark,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
