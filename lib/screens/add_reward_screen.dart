import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/reward_model.dart';
import '../providers/rewards_providers.dart';
import '../theme/app_colors.dart';
import '../widgets/rpg_button.dart';

/// Add Reward Screen — ฟอร์มสร้างของรางวัลเอง (เดิมแอปนี้มีทางเดียวที่
/// เพิ่มของรางวัลได้คือปุ่ม "seed ตัวอย่าง" ตอนร้านค้าว่างเปล่า ซึ่งกด
/// ได้แค่ครั้งเดียวในชีวิตของแอป เพราะพอมีของอยู่ 1 ชิ้นแล้ว list จะไม่
/// ว่างอีกเลย ปุ่มนั้นก็หายไปถาวร)
class AddRewardScreen extends ConsumerStatefulWidget {
  const AddRewardScreen({super.key});

  @override
  ConsumerState<AddRewardScreen> createState() => _AddRewardScreenState();
}

class _AddRewardScreenState extends ConsumerState<AddRewardScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _goldCostController = TextEditingController(text: '50');
  final _effectValueController = TextEditingController();

  RewardCategory _category = RewardCategory.consumable;
  ItemRarity _rarity = ItemRarity.common;
  ItemEffectType _effectType = ItemEffectType.none;
  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _goldCostController.dispose();
    _effectValueController.dispose();
    super.dispose();
  }

  /// เปลี่ยนหมวดหมู่แล้ว effect ที่เลือกไว้อาจใช้กับหมวดใหม่ไม่ได้ —
  /// รีเซ็ตกลับเป็น none ทุกครั้งที่สลับหมวด กันเลือกค้างแบบไม่สมเหตุผล
  /// (เช่น equipment ที่ effect เป็น extendFocusMinutes)
  void _onCategoryChanged(RewardCategory category) {
    setState(() {
      _category = category;
      _effectType = ItemEffectType.none;
      _effectValueController.clear();
    });
  }

  List<ItemEffectType> get _availableEffects {
    switch (_category) {
      case RewardCategory.equipment:
        return const [
          ItemEffectType.none,
          ItemEffectType.focusTimeBonusPercent,
          ItemEffectType.parallelQuestSlot,
        ];
      case RewardCategory.consumable:
        return const [
          ItemEffectType.none,
          ItemEffectType.extendFocusMinutes,
          ItemEffectType.instantExp,
          ItemEffectType.instantGold,
        ];
      case RewardCategory.collectible:
        return const [ItemEffectType.none];
    }
  }

  String? _effectValueHint() {
    switch (_effectType) {
      case ItemEffectType.focusTimeBonusPercent:
        return 'เช่น 10 = เพิ่มเวลาโฟกัส 10%';
      case ItemEffectType.parallelQuestSlot:
        return 'อุปกรณ์นี้ปลดล็อกช่อง Concurrent Quest ที่ 3';
      case ItemEffectType.extendFocusMinutes:
        return 'เช่น 15 = ต่อเวลาโฟกัส 15 นาที';
      case ItemEffectType.instantExp:
        return 'เช่น 50 = ได้ +50 EXP ทันทีตอนใช้';
      case ItemEffectType.instantGold:
        return 'เช่น 30 = ได้ +30 Gold ทันทีตอนใช้';
      case ItemEffectType.none:
        return null;
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    double? effectValue;
    if (_effectType != ItemEffectType.none) {
      final raw = double.tryParse(_effectValueController.text.trim()) ?? 0;
      // focusTimeBonusPercent เก็บเป็นสัดส่วน (0.10) แต่ผู้ใช้กรอกเป็น % (10)
      effectValue = _effectType == ItemEffectType.focusTimeBonusPercent
          ? raw / 100
          : raw;
    }

    final reward = RewardModel(
      title: _titleController.text.trim(),
      description: _descController.text.trim().isEmpty
          ? null
          : _descController.text.trim(),
      goldCost: int.tryParse(_goldCostController.text.trim()) ?? 0,
      itemCategory: _category,
      rarity: _rarity,
      effectType: _effectType,
      effectValue: effectValue,
    );

    await ref.read(rewardsListProvider.notifier).addReward(reward);

    if (!mounted) return;
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('เพิ่ม "${reward.title}" เข้าร้านค้าแล้ว'),
        backgroundColor: AppColors.primaryDark,
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final needsEffectValue = _effectType != ItemEffectType.none;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('เพิ่มของรางวัลใหม่')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: 'ชื่อของรางวัล',
                    hintText: 'เช่น หูฟัง Lo-Fi',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'กรุณาระบุชื่อของรางวัล'
                      : null,
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _descController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'รายละเอียด (ถ้ามี)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _goldCostController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'ราคา (Gold)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (v) {
                    final n = int.tryParse((v ?? '').trim());
                    if (n == null || n <= 0) return 'ระบุจำนวนเต็มมากกว่า 0';
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                const Text(
                  'หมวดหมู่',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: RewardCategory.values.map((cat) {
                    return ChoiceChip(
                      label: Text(cat.displayName),
                      selected: _category == cat,
                      onSelected: (sel) {
                        if (sel) _onCategoryChanged(cat);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 4),
                Text(
                  switch (_category) {
                    RewardCategory.equipment =>
                      'สวมใส่ได้ทันทีที่แลก มีผลต่อเกมจริง (เช่น +% Focus Time)',
                    RewardCategory.consumable =>
                      'เก็บไว้ในคลัง กด "ใช้" ทีละชิ้นเมื่อต้องการ',
                    RewardCategory.collectible =>
                      'แค่เก็บสะสมโชว์ ไม่มีผลต่อเกม',
                  },
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 20),

                const Text(
                  'ความหายาก',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: ItemRarity.values.map((r) {
                    return ChoiceChip(
                      label: Text(r.displayName),
                      selected: _rarity == r,
                      onSelected: (sel) {
                        if (sel) setState(() => _rarity = r);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                if (_availableEffects.length > 1) ...[
                  const Text(
                    'ผลจริงในเกม',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _availableEffects.map((effect) {
                      return ChoiceChip(
                        label: Text(effect.displayName),
                        selected: _effectType == effect,
                        onSelected: (sel) {
                          if (sel) {
                            setState(() {
                              _effectType = effect;
                              _effectValueController.clear();
                            });
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                ],

                if (needsEffectValue) ...[
                  TextFormField(
                    controller: _effectValueController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'ค่าของผล',
                      hintText: _effectValueHint(),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (v) {
                      if (!needsEffectValue) return null;
                      final n = double.tryParse((v ?? '').trim());
                      if (n == null || n <= 0) return 'ระบุตัวเลขมากกว่า 0';
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                ],

                RpgButton(
                  text: 'บันทึกของรางวัล',
                  backgroundColor: AppColors.primary,
                  borderColor: AppColors.primaryDark,
                  isLoading: _isSaving,
                  onPressed: _isSaving ? null : _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
