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
    return db.getCurrentUser();
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

  Future<void> addExpAndGold({required int exp, required int gold}) async {
    final current = state.valueOrNull;
    if (current == null) return;

    final updated = current.withRewards(exp: exp, gold: gold);
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

    final updated = current.copyWith(
      streakCount: isConsecutive ? current.streakCount + 1 : 1,
      lastActiveDate: today.toIso8601String(),
    );

    await ref.read(databaseHelperProvider).updateUser(updated);
    state = AsyncValue.data(updated);
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
