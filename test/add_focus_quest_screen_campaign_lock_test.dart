import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quest_log/models/quest_enums.dart';
import 'package:quest_log/models/quest_model.dart';
import 'package:quest_log/screens/add_focus_quest_screen.dart';

void main() {
  testWidgets(
    'campaign focus quest locks difficulty, duration and frequency edits',
    (WidgetTester tester) async {
      final campaignQuest = QuestModel(
        title: 'Campaign Focus',
        category: QuestCategory.side,
        goalType: QuestGoalType.focus,
        difficulty: 3,
        activityType: ActivityType.mental,
        estimatedMinutes: 50,
        expReward: 10,
        goldReward: 10,
        createdAt: DateTime.now().toIso8601String(),
        habitTargetDays: 14,
        habitFrequency: HabitFrequency.daily,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: AddFocusQuestScreen(questToEdit: campaignQuest),
          ),
        ),
      );

      final slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.onChanged, isNull);

      final switchWidget = tester.widget<Switch>(find.byType(Switch));
      expect(switchWidget.onChanged, isNull);

      expect(find.byIcon(Icons.lock_rounded), findsWidgets);
    },
  );
}
