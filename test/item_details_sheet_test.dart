import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quest_log/models/reward_model.dart';
import 'package:quest_log/widgets/item_details_sheet.dart';

void main() {
  testWidgets('primary item action runs only after explicit confirmation tap', (
    WidgetTester tester,
  ) async {
    var used = 0;
    const reward = RewardModel(
      title: 'Focus Draught',
      description: 'เพิ่มเวลาโฟกัส 15 นาที',
      goldCost: 100,
      itemCategory: RewardCategory.consumable,
      effectType: ItemEffectType.extendFocusMinutes,
      effectValue: 15,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                builder: (_) => ItemDetailsSheet(
                  reward: reward,
                  quantity: 1,
                  primaryLabel: 'ใช้งาน',
                  onPrimary: () async {
                    used++;
                    return (success: true, message: 'ใช้สำเร็จ');
                  },
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(used, 0);

    await tester.tap(find.text('ใช้งาน'));
    await tester.pumpAndSettle();
    expect(used, 1);
    expect(find.text('Focus Draught'), findsNothing);
  });

  testWidgets('discard requires confirmation and reports stack quantity', (
    WidgetTester tester,
  ) async {
    var discarded = 0;
    const reward = RewardModel(
      title: 'Melt Potion',
      description: 'ละลาย Frozen และรับโบนัส EXP เควสต์ถัดไป 25%',
      goldCost: 100,
      itemCategory: RewardCategory.consumable,
      rarity: ItemRarity.rare,
      effectType: ItemEffectType.meltFrozenStreak,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                builder: (_) => ItemDetailsSheet(
                  reward: reward,
                  quantity: 3,
                  onDiscard: () async => discarded++,
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('มีอยู่ในคลัง: 3 ชิ้น'), findsOneWidget);
    expect(find.textContaining('โบนัส EXP 25%'), findsOneWidget);

    await tester.tap(find.byType(OutlinedButton));
    await tester.pumpAndSettle();
    expect(find.textContaining('Melt Potion (x3)'), findsOneWidget);

    await tester.tap(find.text('ยกเลิก'));
    await tester.pumpAndSettle();
    expect(discarded, 0);
    expect(find.text('มีอยู่ในคลัง: 3 ชิ้น'), findsOneWidget);

    await tester.tap(find.byType(OutlinedButton));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'ทิ้งไอเทม'));
    await tester.pumpAndSettle();

    expect(discarded, 1);
    expect(find.text('มีอยู่ในคลัง: 3 ชิ้น'), findsNothing);
  });
}
