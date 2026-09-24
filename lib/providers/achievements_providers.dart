import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/achievement_model.dart';
import 'core_providers.dart';

final unlockedAchievementCodesProvider =
    AsyncNotifierProvider<UnlockedAchievementsNotifier, Set<String>>(
      UnlockedAchievementsNotifier.new,
    );

class UnlockedAchievementsNotifier extends AsyncNotifier<Set<String>> {
  @override
  Future<Set<String>> build() async {
    final db = ref.read(databaseHelperProvider);
    return db.getUnlockedAchievementCodes();
  }

  /// เช็คสถิติปัจจุบันกับทุก achievement ใน catalog แล้วปลดล็อกตัวที่ผ่าน
  /// เงื่อนไขแต่ยังไม่เคยปลดล็อก — เรียกหลังทำเควสสำเร็จทุกครั้ง คืนค่า
  /// list ของ achievement ที่เพิ่งปลดล็อกใหม่ในรอบนี้ (ให้ UI โชว์ฉลอง)
  Future<List<AchievementDef>> checkAndUnlock({
    required int streakDays,
    required int questsCompleted,
  }) async {
    final db = ref.read(databaseHelperProvider);
    final current = state.valueOrNull ?? await db.getUnlockedAchievementCodes();

    final newlyUnlocked = <AchievementDef>[];
    for (final def in kAchievementCatalog) {
      if (current.contains(def.code)) continue;
      if (def.isMetBy(
        streakDays: streakDays,
        questsCompleted: questsCompleted,
      )) {
        await db.unlockAchievement(def.code);
        newlyUnlocked.add(def);
      }
    }

    if (newlyUnlocked.isNotEmpty) {
      state = await AsyncValue.guard(() => db.getUnlockedAchievementCodes());
    }
    return newlyUnlocked;
  }
}
