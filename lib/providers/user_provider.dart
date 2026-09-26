import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_model.dart';
import 'core_providers.dart';

final userProvider = AsyncNotifierProvider<UserNotifier, UserModel?>(
  UserNotifier.new,
);

class UserNotifier extends AsyncNotifier<UserModel?> {
  static const _loggedInKey = 'local_user_logged_in';

  @override
  Future<UserModel?> build() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_loggedInKey) == false) return null;
    final db = ref.read(databaseHelperProvider);
    final user = await db.getCurrentUser();
    if (user == null) return null;
    return _evaluateFrozenStreak(user);
  }

  Future<UserModel> _evaluateFrozenStreak(UserModel user, {DateTime? now}) async {
    if (user.lastActiveDate == null) return user;
    final current = now ?? DateTime.now();
    final last = DateTime.parse(user.lastActiveDate!);
    final lastDay = DateTime(last.year, last.month, last.day);
    final today = DateTime(current.year, current.month, current.day);
    final missedDays = today.difference(lastDay).inDays - 1;
    if (user.streakFrozenUntil != null &&
        current.isBefore(DateTime.parse(user.streakFrozenUntil!))) {
      return user;
    }
    if (missedDays <= user.missedDaysCount) return user;

    var next = user.copyWith(
      missedDaysCount: missedDays,
      isStreakFrozen: missedDays == 1,
      streakBeforeReset: missedDays >= 2
          ? user.streakBeforeReset > 0
                ? user.streakBeforeReset
                : user.streakCount
          : user.streakBeforeReset,
      streakCount: missedDays >= 2 ? 0 : user.streakCount,
      hasStreakDebuff: missedDays >= 2,
      streakResetAt: missedDays >= 2
          ? current.toIso8601String()
          : user.streakResetAt,
    );
    // บทลงโทษไฟดับ: HP ลดลงตามวันที่ขาดไป
    if (missedDays >= 1) {
      next = next.applyHpDamage(missedDays * 20);
    }
    await ref.read(databaseHelperProvider).updateUser(next);
    return next;
  }

  Future<void> evaluateFrozenStreak({DateTime? now}) async {
    final user = state.valueOrNull;
    if (user == null) return;
    state = AsyncValue.data(await _evaluateFrozenStreak(user, now: now));
  }

  Future<UserModel?> resumeLocalUser() async {
    final user = await ref.read(databaseHelperProvider).getCurrentUser();
    if (user == null) return null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_loggedInKey, true);
    state = AsyncValue.data(user);
    return user;
  }

  Future<void> activateLocalUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_loggedInKey, true);
    await refresh();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(databaseHelperProvider).getCurrentUser(),
    );
  }

  Future<void> addExpAndGold({required int exp, required int gold, int hpGain = 0}) async {
    final current = state.valueOrNull;
    if (current == null) return;

    final updated = current.withRewards(exp: exp, gold: gold, hpGain: hpGain);
    await ref.read(databaseHelperProvider).updateUser(updated);
    state = AsyncValue.data(updated);
  }

  Future<void> healHp(int amount) async {
    final current = state.valueOrNull;
    if (current == null) return;
    var newHp = current.currentHp + amount;
    var overflowGold = 0;
    if (newHp > current.maxHp) {
      overflowGold = newHp - current.maxHp;
      newHp = current.maxHp;
    }
    final updated = current.copyWith(
      currentHp: newHp,
      gold: current.gold + overflowGold,
    );
    await ref.read(databaseHelperProvider).updateUser(updated);
    state = AsyncValue.data(updated);
  }

  Future<void> applyHpDamage(int damage) async {
    final current = state.valueOrNull;
    if (current == null) return;
    final updated = current.applyHpDamage(damage);
    await ref.read(databaseHelperProvider).updateUser(updated);
    state = AsyncValue.data(updated);
  }

  Future<bool> spendGold(int amount) async {
    final current = state.valueOrNull;
    if (current == null || current.gold < amount) return false;
    final updated = current.copyWith(gold: current.gold - amount);
    await ref.read(databaseHelperProvider).updateUser(updated);
    state = AsyncValue.data(updated);
    return true;
  }

  Future<bool> spendGems(int amount) async {
    final current = state.valueOrNull;
    if (current == null || current.gems < amount) return false;
    final updated = current.copyWith(gems: current.gems - amount);
    await ref.read(databaseHelperProvider).updateUser(updated);
    state = AsyncValue.data(updated);
    return true;
  }

  Future<void> addGems(int amount) async {
    final current = state.valueOrNull;
    if (current == null) return;
    final updated = current.copyWith(gems: current.gems + amount);
    await ref.read(databaseHelperProvider).updateUser(updated);
    state = AsyncValue.data(updated);
  }

  Future<void> touchDailyStreak({DateTime? now}) async {
    final current = state.valueOrNull;
    if (current == null) return;

    final today = now ?? DateTime.now();
    final todayKey = _dateKey(today);
    final lastKey = current.lastActiveDate == null
        ? null
        : _dateKey(DateTime.parse(current.lastActiveDate!));

    if (lastKey == todayKey) return;

    final yesterdayKey = _dateKey(today.subtract(const Duration(days: 1)));
    final isConsecutive = lastKey == yesterdayKey;
    final nextStreak = current.isStreakFrozen
        ? current.streakCount + 1
        : isConsecutive
            ? current.streakCount + 1
            : 1;

    // Milestone bonus gems for streaks (7 days: +5 gems, 30 days: +20 gems)
    var milestoneGems = 0;
    if (nextStreak == 7) milestoneGems += 5;
    if (nextStreak == 30) milestoneGems += 20;

    final updated = current.copyWith(
      streakCount: nextStreak,
      gems: current.gems + milestoneGems,
      lastActiveDate: today.toIso8601String(),
      isStreakFrozen: false,
      missedDaysCount: 0,
      hasStreakDebuff: false,
      streakBeforeReset: 0,
      clearStreakFrozenUntil: true,
      clearStreakResetAt: true,
    );

    await ref.read(databaseHelperProvider).updateUser(updated);
    state = AsyncValue.data(updated);
  }

  Future<bool> repairFrozenStreak() async {
    final current = state.valueOrNull;
    if (current == null ||
        current.streakBeforeReset <= 0 ||
        current.streakResetAt == null ||
        DateTime.now().difference(DateTime.parse(current.streakResetAt!)).inHours >
            48) {
      return false;
    }
    final restored = current.copyWith(
      streakCount: current.streakBeforeReset,
      isStreakFrozen: true,
      missedDaysCount: 1,
      hasStreakDebuff: false,
      streakBeforeReset: 0,
      clearStreakResetAt: true,
    );
    await ref.read(databaseHelperProvider).updateUser(restored);
    state = AsyncValue.data(restored);
    return true;
  }

  Future<bool> freezeStreak({int days = 1}) async {
    final current = state.valueOrNull;
    if (current == null || days < 1 || days > 3) return false;
    final until = DateTime.now().add(Duration(days: days));
    final updated = current.copyWith(
      isStreakFrozen: true,
      streakFrozenUntil: until.toIso8601String(),
      hasStreakDebuff: false,
    );
    await ref.read(databaseHelperProvider).updateUser(updated);
    state = AsyncValue.data(updated);
    return true;
  }

  Future<bool> meltFrozenStreak() async {
    final current = state.valueOrNull;
    if (current == null || !current.isStreakFrozen) return false;
    final updated = current.copyWith(
      isStreakFrozen: false,
      clearStreakFrozenUntil: true,
      meltExpBonusPending: true,
    );
    await ref.read(databaseHelperProvider).updateUser(updated);
    state = AsyncValue.data(updated);
    return true;
  }

  Future<void> updateProfile({
    required String name,
    int? avatarIndex,
    String? username,
    String? motto,
    RpgClassPath? rpgClass,
    bool clearUsername = false,
    bool clearMotto = false,
    bool clearRpgClass = false,
  }) async {
    final current = state.valueOrNull;
    if (current == null) return;
    final updated = current.copyWith(
      name: name,
      avatarIndex: avatarIndex,
      username: username,
      motto: motto,
      rpgClass: rpgClass,
      clearUsername: clearUsername,
      clearMotto: clearMotto,
      clearRpgClass: clearRpgClass,
    );
    await ref.read(databaseHelperProvider).updateUser(updated);
    state = AsyncValue.data(updated);
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_loggedInKey, false);
    state = const AsyncValue.data(null);
  }

  String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
