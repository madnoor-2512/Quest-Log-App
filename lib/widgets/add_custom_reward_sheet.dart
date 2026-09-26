import 'package:flutter/material.dart';

import '../models/reward_model.dart';
import '../theme/app_colors.dart';

class AddCustomRewardSheet extends StatefulWidget {
  const AddCustomRewardSheet({super.key});

  @override
  State<AddCustomRewardSheet> createState() => _AddCustomRewardSheetState();
}

class _AddCustomRewardSheetState extends State<AddCustomRewardSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _goldController = TextEditingController();
  CustomRewardImpact _impact = CustomRewardImpact.minor;
  CustomRewardPurchaseLimit _limit = CustomRewardPurchaseLimit.none;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _goldController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final minimumGold = _impact.minimumGold;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.borderLight,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'เพิ่มรางวัลชีวิตจริง',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text(
                  'ตั้งเป้าหมายที่อยากแลกด้วย Gold ของคุณ',
                  style: TextStyle(color: AppColors.textMuted),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _titleController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'ชื่อรางวัล *',
                    hintText: 'เช่น ดูซีรีส์ตอนโปรด 1 ตอน',
                    prefixIcon: Icon(Icons.card_giftcard_rounded),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'กรุณาระบุชื่อรางวัล'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'รายละเอียด (ไม่บังคับ)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'ระดับความพิเศษ',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: CustomRewardImpact.values.map((impact) {
                    return ChoiceChip(
                      label: Text(impact.displayName),
                      selected: _impact == impact,
                      onSelected: (_) => setState(() => _impact = impact),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _goldController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'ราคา Gold *',
                    prefixIcon: const Icon(Icons.monetization_on_rounded),
                    helperText: 'ระดับนี้ตั้งราคาได้ตั้งแต่ $minimumGold Gold',
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final price = int.tryParse((value ?? '').trim());
                    if (price == null) return 'กรุณาระบุ Gold เป็นตัวเลข';
                    if (price < 50) {
                      return 'ราคาขั้นต่ำต้องไม่น้อยกว่า 50 Gold';
                    }
                    if (price < minimumGold) {
                      return 'ระดับนี้ต้องใช้ราคาอย่างน้อย $minimumGold Gold';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<CustomRewardPurchaseLimit>(
                  initialValue: _limit,
                  decoration: const InputDecoration(
                    labelText: 'โควตาการแลก',
                    border: OutlineInputBorder(),
                  ),
                  items: CustomRewardPurchaseLimit.values
                      .map(
                        (limit) => DropdownMenuItem(
                          value: limit,
                          child: Text(limit.displayName),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _limit = value);
                  },
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      if (!_formKey.currentState!.validate()) return;
                      final reward = RewardModel(
                        title: _titleController.text.trim(),
                        description: _descriptionController.text.trim().isEmpty
                            ? null
                            : _descriptionController.text.trim(),
                        goldCost: int.parse(_goldController.text.trim()),
                        itemCategory: RewardCategory.collectible,
                        rarity: _impact == CustomRewardImpact.major
                            ? ItemRarity.epic
                            : _impact == CustomRewardImpact.medium
                                ? ItemRarity.rare
                                : ItemRarity.common,
                        category: 'real_life',
                        impactLevel: _impact,
                        purchaseLimit: _limit,
                        isCustomReward: true,
                      );
                      Navigator.of(context).pop(reward);
                    },
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('บันทึกรางวัลชีวิตจริง'),
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
