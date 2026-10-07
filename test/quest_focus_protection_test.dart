import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quest_log/models/active_quest_timer_model.dart';
import 'package:quest_log/models/focus_session_model.dart';
import 'package:quest_log/models/quest_enums.dart';
import 'package:quest_log/models/quest_model.dart';
import 'package:quest_log/providers/focus_providers.dart';
import 'package:quest_log/screens/dashboard_screen.dart';

void main() {
  final testQuest = QuestModel(
    id: 42,
    title: 'Focus Deep Work',
    category: QuestCategory.main,
    goalType: QuestGoalType.focus,
    difficulty: 3,
    activityType: ActivityType.mental,
    estimatedMinutes: 25,
    expReward: 50,
    goldReward: 30,
    createdAt: DateTime.now().toIso8601String(),
    habitFrequency: HabitFrequency.daily,
  );

  testWidgets(
    'isQuestFocusingProvider returns true when quest timer is active and remaining',
    (WidgetTester tester) async {
      final container = ProviderScope(
        overrides: [
          activeFocusSessionProvider.overrideWith(
            () => _FakeActiveFocusSessionNotifier(
              FocusSessionModel(id: 1, startedAt: '2026-10-07T10:00:00.000'),
            ),
          ),
          activeQuestTimersProvider.overrideWith(
            () => _FakeActiveQuestTimersNotifier([
              ActiveQuestTimer(
                questId: 42,
                startedAt: '2026-10-07T10:00:00.000',
                targetDurationSeconds: 1500,
                remainingSeconds: 1200,
              ),
            ]),
          ),
        ],
        child: Container(),
      );

      await tester.pumpWidget(container);
      final element = tester.element(find.byType(Container));
      final containerRef = ProviderScope.containerOf(element);
      await containerRef.read(activeFocusSessionProvider.future);
      await containerRef.read(activeQuestTimersProvider.future);
      await tester.pump();

      expect(containerRef.read(isQuestFocusingProvider(42)), isTrue);
      expect(containerRef.read(isQuestFocusingProvider(99)), isFalse);
    },
  );

  testWidgets(
    'QuestDetailsSheet locks edit and delete buttons when quest is being focused',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeFocusSessionProvider.overrideWith(
              () => _FakeActiveFocusSessionNotifier(
                FocusSessionModel(id: 1, startedAt: '2026-10-07T10:00:00.000'),
              ),
            ),
            activeQuestTimersProvider.overrideWith(
              () => _FakeActiveQuestTimersNotifier([
                ActiveQuestTimer(
                  questId: 42,
                  startedAt: '2026-10-07T10:00:00.000',
                  targetDurationSeconds: 1500,
                  remainingSeconds: 1200,
                ),
              ]),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: QuestDetailsSheet(quest: testQuest),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Warning banner is displayed
      expect(
        find.text(
          '🔒 เควสต์นี้กำลังถูกโฟกัสอยู่ โปรดจบเซสชันหรือยอมแพ้ก่อนทำการแก้ไข',
        ),
        findsOneWidget,
      );

      // Edit and Delete buttons are disabled (onPressed is null)
      final editButton = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'แก้ไขภารกิจ'),
      );
      expect(editButton.onPressed, isNull);

      final deleteButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'ลบภารกิจ'),
      );
      expect(deleteButton.onPressed, isNull);
    },
  );

  testWidgets(
    'QuestDetailsSheet enables buttons when quest is not currently focused',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeFocusSessionProvider.overrideWith(
              () => _FakeActiveFocusSessionNotifier(null),
            ),
            activeQuestTimersProvider.overrideWith(
              () => _FakeActiveQuestTimersNotifier([]),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: QuestDetailsSheet(quest: testQuest),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Warning banner is NOT displayed
      expect(
        find.text(
          '🔒 เควสต์นี้กำลังถูกโฟกัสอยู่ โปรดจบเซสชันหรือยอมแพ้ก่อนทำการแก้ไข',
        ),
        findsNothing,
      );

      // Edit and Delete buttons are enabled
      final editButton = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'แก้ไขภารกิจ'),
      );
      expect(editButton.onPressed, isNotNull);

      final deleteButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'ลบภารกิจ'),
      );
      expect(deleteButton.onPressed, isNotNull);
    },
  );
}

class _FakeActiveFocusSessionNotifier extends ActiveFocusSessionNotifier {
  final FocusSessionModel? initialSession;
  _FakeActiveFocusSessionNotifier(this.initialSession);

  @override
  Future<FocusSessionModel?> build() async => initialSession;
}

class _FakeActiveQuestTimersNotifier extends ActiveQuestTimersNotifier {
  final List<ActiveQuestTimer> initialTimers;
  _FakeActiveQuestTimersNotifier(this.initialTimers);

  @override
  Future<List<ActiveQuestTimer>> build() async => initialTimers;
}
