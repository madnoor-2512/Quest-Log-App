import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/quest_enums.dart';
import '../models/quest_model.dart';
import '../providers/core_providers.dart';
import '../providers/quest_providers.dart';
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
  final _manualExpController = TextEditingController();
  final _manualGoldController = TextEditingController();
  final _subTaskInputController = TextEditingController();

  QuestCategory _category = QuestCategory.main;
  ActivityType _activityType = ActivityType.mental;
  int _difficulty = 3;
  int _estimatedMinutes = 25;
  bool _autoCalculate = true;
  final List<String> _subTasks = [];

  int _expReward = 30;
  int _goldReward = 15;

  // Gatekeeper block ใช้กับโหมด Auto-Calculate เท่านั้น — โหมด Manual
  // ผู้ใช้กำหนดรางวัลเองได้อิสระ จึงไม่มีทางติดล็อกไม่ให้บันทึก
  String? _blockReason;

  @override
  void initState() {
    super.initState();
    _manualExpController.text = _expReward.toString();
    _manualGoldController.text = _goldReward.toString();
    _recalcReward();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _manualExpController.dispose();
    _manualGoldController.dispose();
    _subTaskInputController.dispose();
    super.dispose();
  }

  void _recalcReward() {
    if (!_autoCalculate) return;

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

  /// สลับโหมด Auto-Calculate <-> Manual
  /// สำคัญ: ต้องเคลียร์ _blockReason ทุกครั้งที่ปิด Auto-Calculate ไม่งั้า
  /// ปุ่มบันทึกจะค้าง disable ถาวรเพราะไม่มีทางเคลียร์ค่านี้ในโหมด manual
  void _toggleAutoCalculate(bool val) {
    setState(() {
      _autoCalculate = val;
      if (!val) {
        _blockReason = null;
        _manualExpController.text = _expReward.toString();
        _manualGoldController.text = _goldReward.toString();
      }
    });
    if (val) _recalcReward();
  }

  Future<void> _saveQuest() async {
    if (!_formKey.currentState!.validate()) return;
    if (_autoCalculate && _blockReason != null) return;

    if (!_autoCalculate) {
      // โหมด manual: ใช้ค่าที่ผู้ใช้กรอกเอง (validator ของ TextFormField
      // การันตีแล้วว่า parse เป็นจำนวนเต็ม >= 0 ได้)
      _expReward = int.parse(_manualExpController.text.trim());
      _goldReward = int.parse(_manualGoldController.text.trim());
    }

    final quest = QuestModel(
      title: _titleController.text.trim(),
      description: _descController.text.trim().isEmpty
          ? null
          : _descController.text.trim(),
      category: _category,
      difficulty: _difficulty,
      activityType: _activityType,
      estimatedMinutes: _estimatedMinutes,
      expReward: _expReward,
      goldReward: _goldReward,
      isAutoDifficulty: _autoCalculate,
      createdAt: DateTime.now().toIso8601String(),
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

              // Auto-calculate switch
              SwitchListTile(
                value: _autoCalculate,
                title: const Text('คำนวณรางวัลอัตโนมัติ (RPG Formula)'),
                onChanged: _toggleAutoCalculate,
              ),
              const SizedBox(height: 12),

              // Reward Preview (auto) / Block Warning (auto) / Manual Input
              if (_autoCalculate && _blockReason != null)
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
              else if (_autoCalculate)
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
                )
              else
                // Manual mode: ให้กรอก EXP/Gold เอง (ไม่มี gatekeeper บล็อก)
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _manualExpController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'EXP รางวัล',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          final n = int.tryParse((v ?? '').trim());
                          if (n == null || n < 0) return 'ระบุจำนวนเต็ม ≥ 0';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _manualGoldController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Gold รางวัล',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          final n = int.tryParse((v ?? '').trim());
                          if (n == null || n < 0) return 'ระบุจำนวนเต็ม ≥ 0';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 28),

              RpgButton(
                text: 'บันทึกเควส',
                backgroundColor: AppColors.primary,
                borderColor: AppColors.primaryDark,
                onPressed: (_autoCalculate && _blockReason != null)
                    ? null
                    : _saveQuest,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
