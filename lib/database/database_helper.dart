import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/user_model.dart';
import '../models/quest_model.dart';
import '../models/sub_task_model.dart';
import '../models/focus_session_model.dart';
import '../models/reward_model.dart';
import '../models/achievement_model.dart';
import '../services/gamification_config.dart';

/// DatabaseHelper — Singleton จัดการ SQLite database ทั้งหมดของแอป Quest Log
class DatabaseHelper {
  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();

  static Database? _database;

  static const String dbName = 'quest_log.db';
  static const int dbVersion = 15;

  static const String tableUsers = 'users';
  static const String tableQuests = 'quests';
  static const String tableSubTasks = 'sub_tasks';
  static const String tableFocusSessions = 'active_focus_sessions';
  static const String tableSessionQuests = 'session_quests';
  static const String tableRewards = 'rewards';
  static const String tableRedemptions = 'redemptions';
  static const String tableInventoryItems = 'inventory_items';
  static const String tableUnlockedAchievements = 'unlocked_achievements';
  static const String tableHabitCheckins = 'habit_checkins';

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, dbName);
    return await openDatabase(
      path,
      version: dbVersion,
      onConfigure: _onConfigure,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // เพิ่มคอลัมน์เก็บ "ยอดที่ได้รับจริง" หลังผ่าน Streak Multiplier +
      // Daily Cap แยกจาก exp_reward/gold_reward (ซึ่งเป็นแค่ค่าที่ตั้งไว้
      // ตอนสร้างเควส) เพื่อให้ getTodayEarnedTotals() นับยอดจริงได้ถูกต้อง
      await db.execute(
        'ALTER TABLE $tableQuests ADD COLUMN awarded_exp INTEGER;',
      );
      await db.execute(
        'ALTER TABLE $tableQuests ADD COLUMN awarded_gold INTEGER;',
      );
    }
    if (oldVersion < 3) {
      // avatar_index: เลือกไอคอนอวาตาร์ตอน Onboarding — เดิมมีแค่ UI
      // ไม่มีที่เก็บใน DB เลย (เป็น cosmetic-only ไม่มีผลจริง)
      await db.execute(
        'ALTER TABLE $tableUsers ADD COLUMN avatar_index INTEGER NOT NULL DEFAULT 0;',
      );
    }
    if (oldVersion < 4) {
      // ระบบคลังไอเทม (Inventory) — เพิ่มหมวดหมู่/ความหายาก/ผลจริงให้
      // rewards, เพิ่มช่องคลังให้ users, และสร้างตาราง inventory_items
      // เก็บว่าใครถือของอะไรอยู่บ้าง
      await db.execute(
        "ALTER TABLE $tableRewards ADD COLUMN item_category TEXT NOT NULL DEFAULT 'CONSUMABLE';",
      );
      await db.execute(
        "ALTER TABLE $tableRewards ADD COLUMN rarity TEXT NOT NULL DEFAULT 'COMMON';",
      );
      await db.execute(
        'ALTER TABLE $tableRewards ADD COLUMN effect_type TEXT;',
      );
      await db.execute(
        'ALTER TABLE $tableRewards ADD COLUMN effect_value REAL;',
      );
      await db.execute(
        'ALTER TABLE $tableUsers ADD COLUMN inventory_capacity INTEGER NOT NULL DEFAULT 20;',
      );
      await db.execute('''
        CREATE TABLE $tableInventoryItems (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          reward_id INTEGER NOT NULL,
          quantity INTEGER NOT NULL DEFAULT 1,
          is_equipped INTEGER NOT NULL DEFAULT 0,
          acquired_at TEXT NOT NULL,
          FOREIGN KEY (reward_id) REFERENCES $tableRewards (id) ON DELETE CASCADE
        );
      ''');
    }
    if (oldVersion < 5) {
      // โปรไฟล์ผู้เล่นเพิ่ม username/motto/rpg_class + ระบบ Achievements
      await db.execute('ALTER TABLE $tableUsers ADD COLUMN username TEXT;');
      await db.execute('ALTER TABLE $tableUsers ADD COLUMN motto TEXT;');
      await db.execute('ALTER TABLE $tableUsers ADD COLUMN rpg_class TEXT;');
      await db.execute('''
        CREATE TABLE $tableUnlockedAchievements (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          code TEXT NOT NULL UNIQUE,
          unlocked_at TEXT NOT NULL
        );
      ''');
    }
    if (oldVersion < 6) {
      await db.execute(
        "ALTER TABLE $tableQuests ADD COLUMN goal_type TEXT NOT NULL DEFAULT 'FOCUS';",
      );
      await db.execute(
        'ALTER TABLE $tableQuests ADD COLUMN habit_start_minute INTEGER;',
      );
      await db.execute(
        'ALTER TABLE $tableQuests ADD COLUMN habit_end_minute INTEGER;',
      );
      await db.execute(
        'ALTER TABLE $tableQuests ADD COLUMN habit_target_days INTEGER;',
      );
      await db.execute('''
        CREATE TABLE $tableHabitCheckins (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          quest_id INTEGER NOT NULL,
          checkin_date TEXT NOT NULL,
          checked_in_at TEXT NOT NULL,
          UNIQUE (quest_id, checkin_date),
          FOREIGN KEY (quest_id) REFERENCES $tableQuests (id) ON DELETE CASCADE
        );
      ''');
    }
    if (oldVersion < 7) {
      await db.execute(
        "ALTER TABLE $tableRewards ADD COLUMN category TEXT NOT NULL DEFAULT 'system';",
      );
      await db.execute(
        "ALTER TABLE $tableRewards ADD COLUMN impact_level TEXT NOT NULL DEFAULT 'minor';",
      );
      await db.execute(
        "ALTER TABLE $tableRewards ADD COLUMN purchase_limit TEXT NOT NULL DEFAULT 'none';",
      );
      await db.execute(
        'ALTER TABLE $tableRewards ADD COLUMN is_custom_reward INTEGER NOT NULL DEFAULT 0;',
      );
    }
    if (oldVersion < 8) {
      await db.execute(
        'ALTER TABLE $tableUsers ADD COLUMN is_streak_frozen INTEGER NOT NULL DEFAULT 0;',
      );
      await db.execute(
        'ALTER TABLE $tableUsers ADD COLUMN missed_days_count INTEGER NOT NULL DEFAULT 0;',
      );
      await db.execute(
        'ALTER TABLE $tableUsers ADD COLUMN has_streak_debuff INTEGER NOT NULL DEFAULT 0;',
      );
      await db.execute(
        'ALTER TABLE $tableUsers ADD COLUMN streak_before_reset INTEGER NOT NULL DEFAULT 0;',
      );
    }
    if (oldVersion < 9) {
      await db.execute(
        'ALTER TABLE $tableUsers ADD COLUMN streak_frozen_until TEXT;',
      );
      await db.execute(
        'ALTER TABLE $tableUsers ADD COLUMN melt_exp_bonus_pending INTEGER NOT NULL DEFAULT 0;',
      );
      await db.execute(
        "UPDATE $tableRewards SET gold_cost = 350 WHERE title = 'Streak Repair Hammer' AND is_custom_reward = 0;",
      );
    }
    if (oldVersion < 10) {
      await db.execute(
        'ALTER TABLE $tableUsers ADD COLUMN streak_reset_at TEXT;',
      );
    }
    if (oldVersion < 11) {
      await _addColumnIfMissing(
        db,
        tableUsers,
        'gems',
        'INTEGER NOT NULL DEFAULT 10',
      );
      await _addColumnIfMissing(
        db,
        tableUsers,
        'current_hp',
        'INTEGER NOT NULL DEFAULT 100',
      );
      await _addColumnIfMissing(
        db,
        tableUsers,
        'max_hp',
        'INTEGER NOT NULL DEFAULT 100',
      );
    }
    if (oldVersion < 12) {
      // หน้าสร้าง "เควสต์ทันใจ" แบบใหม่เพิ่มตัวเลือกความถี่รายสัปดาห์
      // (ทุกวัน / จันทร์-ศุกร์ / กำหนดเอง) ให้ Daily Habit — เก็บเป็น
      // habit_frequency + habit_weekdays (comma-separated ISO weekday
      // เฉพาะตอนกำหนดเอง) ค่าเริ่มต้น DAILY ทำให้เควสต์เก่าที่มีอยู่แล้ว
      // ยังเช็กอินได้ทุกวันเหมือนเดิม ไม่กระทบพฤติกรรมเดิม
      await _addColumnIfMissing(
        db,
        tableQuests,
        'habit_frequency',
        "TEXT NOT NULL DEFAULT 'DAILY'",
      );
      await _addColumnIfMissing(db, tableQuests, 'habit_weekdays', 'TEXT');
    }
    if (oldVersion < 13) {
      // บันทึกว่าแคมเปญ “ล้มเหลว” (HP ลดเหลือ 0) ต่างจากแคมเปญ “สำเร็จ” ปกติ
      await _addColumnIfMissing(
        db,
        tableQuests,
        'is_campaign_failed',
        'INTEGER NOT NULL DEFAULT 0',
      );
    }
    if (oldVersion < 14) {
      await _addColumnIfMissing(
        db,
        tableQuests,
        'last_campaign_penalty_date',
        'TEXT',
      );
      await db.execute(
        "UPDATE $tableQuests SET last_campaign_penalty_date = date('now', 'localtime', '-1 day') "
        'WHERE habit_target_days IS NOT NULL AND habit_target_days > 0 AND is_completed = 0',
      );
    }
    if (oldVersion < 15) {
      await _addColumnIfMissing(db, tableUsers, 'avatar_image_base64', 'TEXT');
    }
  }

  Future<void> _addColumnIfMissing(
    Database db,
    String table,
    String column,
    String definition,
  ) async {
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    final exists = columns.any((row) => row['name'] == column);
    if (!exists) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $definition;');
    }
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON;');
  }

  Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();

    batch.execute('''
      CREATE TABLE $tableUsers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        level INTEGER NOT NULL DEFAULT 1,
        current_exp INTEGER NOT NULL DEFAULT 0,
        max_exp INTEGER NOT NULL DEFAULT 100,
        gold INTEGER NOT NULL DEFAULT 0,
        gems INTEGER NOT NULL DEFAULT 10,
        current_hp INTEGER NOT NULL DEFAULT 100,
        max_hp INTEGER NOT NULL DEFAULT 100,
        streak_count INTEGER NOT NULL DEFAULT 0,
        last_active_date TEXT,
        avatar_index INTEGER NOT NULL DEFAULT 0,
        avatar_image_base64 TEXT,
        inventory_capacity INTEGER NOT NULL DEFAULT 20,
        username TEXT,
        motto TEXT,
        rpg_class TEXT
        ,is_streak_frozen INTEGER NOT NULL DEFAULT 0
        ,missed_days_count INTEGER NOT NULL DEFAULT 0
        ,has_streak_debuff INTEGER NOT NULL DEFAULT 0
        ,streak_before_reset INTEGER NOT NULL DEFAULT 0
        ,streak_frozen_until TEXT
        ,melt_exp_bonus_pending INTEGER NOT NULL DEFAULT 0
        ,streak_reset_at TEXT
      );
    ''');

    batch.execute('''
      CREATE TABLE $tableQuests (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        description TEXT,
        category TEXT NOT NULL,
        goal_type TEXT NOT NULL DEFAULT 'FOCUS',
        difficulty INTEGER NOT NULL DEFAULT 1,
        activity_type TEXT NOT NULL,
        estimated_minutes INTEGER NOT NULL DEFAULT 0,
        is_auto_difficulty INTEGER NOT NULL DEFAULT 1,
        exp_reward INTEGER NOT NULL,
        gold_reward INTEGER NOT NULL,
        due_date TEXT,
        last_campaign_penalty_date TEXT,
        is_completed INTEGER NOT NULL DEFAULT 0,
        is_campaign_failed INTEGER NOT NULL DEFAULT 0,
        completed_at TEXT,
        created_at TEXT NOT NULL,
        awarded_exp INTEGER,
        awarded_gold INTEGER,
        habit_start_minute INTEGER,
        habit_end_minute INTEGER,
        habit_target_days INTEGER,
        habit_frequency TEXT NOT NULL DEFAULT 'DAILY',
        habit_weekdays TEXT
      );
    ''');

    batch.execute('''
      CREATE TABLE $tableSubTasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        quest_id INTEGER NOT NULL,
        title TEXT NOT NULL,
        is_completed INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (quest_id) REFERENCES $tableQuests (id) ON DELETE CASCADE
      );
    ''');

    batch.execute('''
      CREATE TABLE $tableFocusSessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        started_at TEXT NOT NULL,
        target_duration INTEGER NOT NULL DEFAULT 0
      );
    ''');

    batch.execute('''
      CREATE TABLE $tableSessionQuests (
        session_id INTEGER NOT NULL,
        quest_id INTEGER NOT NULL,
        PRIMARY KEY (session_id, quest_id),
        FOREIGN KEY (session_id) REFERENCES $tableFocusSessions (id) ON DELETE CASCADE,
        FOREIGN KEY (quest_id) REFERENCES $tableQuests (id) ON DELETE CASCADE
      );
    ''');

    batch.execute('''
      CREATE TABLE $tableRewards (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        description TEXT,
        gold_cost INTEGER NOT NULL,
        icon_name TEXT,
        item_category TEXT NOT NULL DEFAULT 'CONSUMABLE',
        rarity TEXT NOT NULL DEFAULT 'COMMON',
        effect_type TEXT,
        effect_value REAL
        ,category TEXT NOT NULL DEFAULT 'system'
        ,impact_level TEXT NOT NULL DEFAULT 'minor'
        ,purchase_limit TEXT NOT NULL DEFAULT 'none'
        ,is_custom_reward INTEGER NOT NULL DEFAULT 0
      );
    ''');

    batch.execute('''
      CREATE TABLE $tableRedemptions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        reward_id INTEGER NOT NULL,
        redeemed_at TEXT NOT NULL,
        FOREIGN KEY (reward_id) REFERENCES $tableRewards (id)
      );
    ''');

    batch.execute('''
      CREATE TABLE $tableInventoryItems (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        reward_id INTEGER NOT NULL,
        quantity INTEGER NOT NULL DEFAULT 1,
        is_equipped INTEGER NOT NULL DEFAULT 0,
        acquired_at TEXT NOT NULL,
        FOREIGN KEY (reward_id) REFERENCES $tableRewards (id) ON DELETE CASCADE
      );
    ''');

    batch.execute('''
      CREATE TABLE $tableUnlockedAchievements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        code TEXT NOT NULL UNIQUE,
        unlocked_at TEXT NOT NULL
      );
    ''');

    batch.execute('''
      CREATE TABLE $tableHabitCheckins (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        quest_id INTEGER NOT NULL,
        checkin_date TEXT NOT NULL,
        checked_in_at TEXT NOT NULL,
        UNIQUE (quest_id, checkin_date),
        FOREIGN KEY (quest_id) REFERENCES $tableQuests (id) ON DELETE CASCADE
      );
    ''');

    batch.execute(
      'CREATE INDEX idx_quests_category ON $tableQuests (category);',
    );
    batch.execute(
      'CREATE INDEX idx_quests_completed ON $tableQuests (is_completed);',
    );
    batch.execute(
      'CREATE INDEX idx_subtasks_quest ON $tableSubTasks (quest_id);',
    );

    await batch.commit(noResult: true);
  }

  // -----------------------------------------------------------------------
  // USERS
  // -----------------------------------------------------------------------

  Future<int> insertUser(UserModel user) async {
    final db = await database;
    return await db.insert(tableUsers, user.toMap());
  }

  Future<UserModel?> getCurrentUser() async {
    final db = await database;
    final maps = await db.query(tableUsers, limit: 1, orderBy: 'id ASC');
    if (maps.isEmpty) return null;
    return UserModel.fromMap(maps.first);
  }

  Future<UserModel?> getUserById(int id) async {
    final db = await database;
    final maps = await db.query(tableUsers, where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return UserModel.fromMap(maps.first);
  }

  Future<int> updateUser(UserModel user) async {
    assert(user.id != null, 'UserModel.id must not be null when updating');
    final db = await database;
    return await db.update(
      tableUsers,
      user.toMap(),
      where: 'id = ?',
      whereArgs: [user.id],
    );
  }

  Future<int> deleteUser(int id) async {
    final db = await database;
    return await db.delete(tableUsers, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearLocalUserData() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(tableInventoryItems);
      await txn.delete(tableRedemptions);
      await txn.delete(tableUnlockedAchievements);
      await txn.delete(tableHabitCheckins);
      await txn.delete(tableSessionQuests);
      await txn.delete(tableFocusSessions);
      await txn.delete(tableSubTasks);
      await txn.delete(tableQuests);
      await txn.delete(tableRewards);
      await txn.delete(tableUsers);
    });
  }

  // -----------------------------------------------------------------------
  // QUESTS
  // -----------------------------------------------------------------------

  Future<int> insertQuest(QuestModel quest) async {
    final db = await database;
    return await db.insert(tableQuests, quest.toMap());
  }

  Future<int> getHabitCheckinCount(int questId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM $tableHabitCheckins WHERE quest_id = ?',
      [questId],
    );
    return (result.first['count'] as int?) ?? 0;
  }

  Future<Set<String>> getHabitCheckinDates(int questId) async {
    final db = await database;
    final rows = await db.query(
      tableHabitCheckins,
      columns: ['checkin_date'],
      where: 'quest_id = ?',
      whereArgs: [questId],
    );
    return rows.map((row) => row['checkin_date'] as String).toSet();
  }

  Future<List<({QuestModel quest, DateTime checkedInAt})>> getHabitCheckins({
    DateTime? from,
    DateTime? to,
    int? limit,
    bool newestFirst = false,
  }) async {
    final db = await database;
    final conditions = <String>[];
    final whereArgs = <Object?>[];
    if (from != null) {
      conditions.add('checkins.checked_in_at >= ?');
      whereArgs.add(from.toIso8601String());
    }
    if (to != null) {
      conditions.add('checkins.checked_in_at <= ?');
      whereArgs.add(to.toIso8601String());
    }
    if (limit != null) whereArgs.add(limit);

    final rows = await db.rawQuery('''
      SELECT quests.*, checkins.checked_in_at AS checkin_timestamp
      FROM $tableHabitCheckins AS checkins
      INNER JOIN $tableQuests AS quests ON quests.id = checkins.quest_id
      ${conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}'}
      ORDER BY checkins.checked_in_at ${newestFirst ? 'DESC' : 'ASC'}
      ${limit == null ? '' : 'LIMIT ?'}
      ''', whereArgs);
    return rows
        .map(
          (row) => (
            quest: QuestModel.fromMap(row),
            checkedInAt: DateTime.parse(row['checkin_timestamp'] as String),
          ),
        )
        .toList();
  }

  Future<({Set<int> questIds, int focusMinutes})>
  getHabitCheckinSummary() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT quests.id AS quest_id,
             quests.goal_type AS goal_type,
             quests.estimated_minutes AS estimated_minutes,
             quests.is_campaign_failed AS is_campaign_failed,
             COUNT(checkins.id) AS checkin_count
      FROM $tableHabitCheckins AS checkins
      INNER JOIN $tableQuests AS quests ON quests.id = checkins.quest_id
      GROUP BY quests.id
      ''');

    final questIds = <int>{};
    var focusMinutes = 0;
    for (final row in rows) {
      if ((row['is_campaign_failed'] as int? ?? 0) == 1) continue;
      questIds.add(row['quest_id'] as int);
      if (row['goal_type'] == 'FOCUS') {
        final minutes = row['estimated_minutes'] as int? ?? 0;
        final checkinCount = row['checkin_count'] as int? ?? 0;
        focusMinutes += minutes * checkinCount;
      }
    }
    return (questIds: questIds, focusMinutes: focusMinutes);
  }

  Future<bool> hasHabitCheckinToday(int questId, {DateTime? now}) async {
    final today = _dateKey(now ?? DateTime.now());
    final db = await database;
    final rows = await db.query(
      tableHabitCheckins,
      where: 'quest_id = ? AND checkin_date = ?',
      whereArgs: [questId, today],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<void> insertHabitCheckin({required int questId, DateTime? now}) async {
    final current = now ?? DateTime.now();
    final db = await database;
    await db.insert(tableHabitCheckins, {
      'quest_id': questId,
      'checkin_date': _dateKey(current),
      'checked_in_at': current.toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.abort);
  }

  String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  Future<QuestModel?> getQuestById(int id) async {
    final db = await database;
    final maps = await db.query(tableQuests, where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return QuestModel.fromMap(maps.first);
  }

  Future<List<QuestModel>> getQuests({
    String? category,
    bool? isCompleted,
    bool excludeCheckedInToday = false,
    String orderBy = 'created_at DESC',
  }) async {
    final db = await database;
    final where = <String>[];
    final whereArgs = <Object?>[];

    if (category != null) {
      where.add('category = ?');
      whereArgs.add(category);
    }
    if (isCompleted != null) {
      where.add('is_completed = ?');
      whereArgs.add(isCompleted ? 1 : 0);
    }
    if (excludeCheckedInToday) {
      final today = _dateKey(DateTime.now());
      where.add(
        'id NOT IN (SELECT quest_id FROM $tableHabitCheckins WHERE checkin_date = ?)',
      );
      whereArgs.add(today);
    }

    final maps = await db.query(
      tableQuests,
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: orderBy,
    );
    return maps.map((m) => QuestModel.fromMap(m)).toList();
  }

  Future<int> updateQuest(QuestModel quest) async {
    assert(quest.id != null, 'QuestModel.id must not be null when updating');
    final db = await database;
    return await db.update(
      tableQuests,
      quest.toMap(),
      where: 'id = ?',
      whereArgs: [quest.id],
    );
  }

  /// Mark เควสว่าสำเร็จ พร้อมบันทึกยอด EXP/Gold ที่ "ได้รับจริง"
  /// (หลังผ่าน Streak Multiplier + Daily Cap แล้ว) แยกจาก exp_reward/
  /// gold_reward เดิมซึ่งเป็นแค่ค่าที่ตั้งไว้ตอนสร้างเควส — จำเป็นต้องส่ง
  /// [awardedExp]/[awardedGold] มาจาก service layer เสมอ เพื่อให้
  /// getTodayEarnedTotals() นับยอด Daily Cap ได้ถูกต้อง
  Future<QuestModel> completeQuest(
    int questId, {
    required int awardedExp,
    required int awardedGold,
    String? completedAt,
  }) async {
    final db = await database;
    final timestamp = completedAt ?? DateTime.now().toIso8601String();
    final updatedRows = await db.update(
      tableQuests,
      {
        'is_completed': 1,
        'completed_at': timestamp,
        'awarded_exp': awardedExp,
        'awarded_gold': awardedGold,
      },
      where: 'id = ? AND is_completed = 0',
      whereArgs: [questId],
    );
    if (updatedRows == 0) {
      throw StateError(
        'Quest $questId is already completed or does not exist.',
      );
    }
    final updated = await getQuestById(questId);
    if (updated == null) {
      throw StateError('Quest $questId not found after completing.');
    }
    return updated;
  }

  Future<QuestModel> completeQuestAndUpdateUser({
    required int questId,
    required int awardedExp,
    required int awardedGold,
    required UserModel updatedUser,
    String? completedAt,
  }) async {
    assert(updatedUser.id != null, 'UserModel.id must not be null');
    final db = await database;
    final timestamp = completedAt ?? DateTime.now().toIso8601String();

    return db.transaction<QuestModel>((txn) async {
      final updatedRows = await txn.update(
        tableQuests,
        {
          'is_completed': 1,
          'completed_at': timestamp,
          'awarded_exp': awardedExp,
          'awarded_gold': awardedGold,
        },
        where: 'id = ? AND is_completed = 0',
        whereArgs: [questId],
      );
      if (updatedRows == 0) {
        throw StateError(
          'Quest $questId is already completed or does not exist.',
        );
      }

      final updatedUserRows = await txn.update(
        tableUsers,
        updatedUser.toMap(),
        where: 'id = ?',
        whereArgs: [updatedUser.id],
      );
      if (updatedUserRows == 0) {
        throw StateError(
          'User ${updatedUser.id} not found while awarding rewards.',
        );
      }

      final maps = await txn.query(
        tableQuests,
        where: 'id = ?',
        whereArgs: [questId],
      );
      if (maps.isEmpty) {
        throw StateError('Quest $questId not found after completing.');
      }
      return QuestModel.fromMap(maps.first);
    });
  }

  Future<void> failActiveCampaigns() async {
    final db = await database;
    await db.update(
      tableQuests,
      {'is_completed': 1, 'is_campaign_failed': 1},
      where:
          'habit_target_days IS NOT NULL AND habit_target_days > 0 AND is_completed = 0',
    );
  }

  Future<void> checkInHabitAndUpdateUser({
    required int questId,
    required UserModel updatedUser,
    DateTime? now,
    bool completeQuest = false,
    required int awardedExp,
    required int awardedGold,
  }) async {
    assert(updatedUser.id != null, 'UserModel.id must not be null');
    final current = now ?? DateTime.now();
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert(tableHabitCheckins, {
        'quest_id': questId,
        'checkin_date': _dateKey(current),
        'checked_in_at': current.toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.abort);
      final userRows = await txn.update(
        tableUsers,
        updatedUser.toMap(),
        where: 'id = ?',
        whereArgs: [updatedUser.id],
      );
      if (userRows == 0) throw StateError('User not found while checking in.');
      if (completeQuest) {
        await txn.update(
          tableQuests,
          {
            'is_completed': 1,
            'completed_at': current.toIso8601String(),
            'awarded_exp': awardedExp,
            'awarded_gold': awardedGold,
          },
          where: 'id = ? AND is_completed = 0',
          whereArgs: [questId],
        );
      }
    });
  }

  Future<int> deleteQuest(int id) async {
    final db = await database;
    return await db.delete(tableQuests, where: 'id = ?', whereArgs: [id]);
  }

  // -----------------------------------------------------------------------
  // SUB TASKS
  // -----------------------------------------------------------------------

  Future<int> insertSubTask(SubTaskModel subTask) async {
    final db = await database;
    return await db.insert(tableSubTasks, subTask.toMap());
  }

  Future<List<SubTaskModel>> getSubTasksForQuest(int questId) async {
    final db = await database;
    final maps = await db.query(
      tableSubTasks,
      where: 'quest_id = ?',
      whereArgs: [questId],
      orderBy: 'id ASC',
    );
    return maps.map((m) => SubTaskModel.fromMap(m)).toList();
  }

  Future<int> updateSubTask(SubTaskModel subTask) async {
    assert(
      subTask.id != null,
      'SubTaskModel.id must not be null when updating',
    );
    final db = await database;
    return await db.update(
      tableSubTasks,
      subTask.toMap(),
      where: 'id = ?',
      whereArgs: [subTask.id],
    );
  }

  Future<int> deleteSubTask(int id) async {
    final db = await database;
    return await db.delete(tableSubTasks, where: 'id = ?', whereArgs: [id]);
  }

  // -----------------------------------------------------------------------
  // FOCUS SESSIONS
  // -----------------------------------------------------------------------

  Future<int> startFocusSession({
    required String startedAt,
    required int targetDuration,
    required List<int> questIds,
  }) async {
    final db = await database;
    return await db.transaction<int>((txn) async {
      final activeSessions = await txn.query(
        tableFocusSessions,
        columns: ['id'],
        orderBy: 'id DESC',
        limit: 1,
      );
      if (activeSessions.isNotEmpty) {
        return activeSessions.first['id'] as int;
      }
      final sessionId = await txn.insert(tableFocusSessions, {
        'started_at': startedAt,
        'target_duration': targetDuration,
      });
      for (final questId in questIds) {
        await txn.insert(tableSessionQuests, {
          'session_id': sessionId,
          'quest_id': questId,
        });
      }
      return sessionId;
    });
  }

  Future<FocusSessionModel?> getActiveFocusSession() async {
    final db = await database;
    final maps = await db.query(
      tableFocusSessions,
      orderBy: 'id DESC',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return FocusSessionModel.fromMap(maps.first);
  }

  Future<List<QuestModel>> getQuestsInSession(int sessionId) async {
    final db = await database;
    final maps = await db.rawQuery(
      '''
      SELECT q.* FROM $tableQuests q
      INNER JOIN $tableSessionQuests sq ON sq.quest_id = q.id
      WHERE sq.session_id = ?
    ''',
      [sessionId],
    );
    return maps.map((m) => QuestModel.fromMap(m)).toList();
  }

  Future<int> endFocusSession(int sessionId) async {
    final db = await database;
    return await db.delete(
      tableFocusSessions,
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  /// อัปเดต target_duration ของ session ที่ active อยู่ — ใช้ตอนกด "ใช้"
  /// ไอเทม consumable ที่ต่อเวลาโฟกัส (extendFocusMinutes)
  Future<void> updateFocusSessionDuration(
    int sessionId,
    int newTargetDurationSeconds,
  ) async {
    final db = await database;
    await db.update(
      tableFocusSessions,
      {'target_duration': newTargetDurationSeconds},
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  // -----------------------------------------------------------------------
  // REWARDS & REDEMPTIONS
  // -----------------------------------------------------------------------

  Future<int> insertReward(RewardModel reward) async {
    final db = await database;
    return await db.insert(tableRewards, reward.toMap());
  }

  Future<void> ensureDefaultRewards() async {
    final existing = await getAllRewards();
    final existingByTitle = {
      for (final reward in existing) reward.title: reward,
    };
    const defaults = [
      RewardModel(
        title: 'หูฟัง Lo-Fi',
        goldCost: 80,
        description: 'เพิ่มเวลา Focus 10% เมื่อสวมใส่',
        iconName: 'headphones',
        itemCategory: RewardCategory.equipment,
        rarity: ItemRarity.rare,
        effectType: ItemEffectType.focusTimeBonusPercent,
        effectValue: 0.10,
      ),
      RewardModel(
        title: 'ตราปลดล็อก Multitask',
        goldCost: 260,
        description: 'ปลดล็อกช่อง Concurrent Quest ที่ 3 เมื่อสวมใส่',
        iconName: 'layers',
        itemCategory: RewardCategory.equipment,
        rarity: ItemRarity.epic,
        effectType: ItemEffectType.parallelQuestSlot,
        effectValue: 1,
      ),
      RewardModel(
        title: 'คัมภีร์ยืดเวลา',
        goldCost: 18,
        description: 'เพิ่มเวลา Focus 15 นาที ใช้ได้ระหว่าง session',
        iconName: 'auto_stories',
        itemCategory: RewardCategory.consumable,
        rarity: ItemRarity.common,
        effectType: ItemEffectType.extendFocusMinutes,
        effectValue: 15,
      ),
      RewardModel(
        title: 'ขวดพลังประสบการณ์',
        goldCost: 18,
        description: 'ได้รับ EXP ทันที 50 แต้ม',
        iconName: 'science',
        itemCategory: RewardCategory.consumable,
        rarity: ItemRarity.rare,
        effectType: ItemEffectType.instantExp,
        effectValue: 50,
      ),
      RewardModel(
        title: 'ถุงทองกล้าหาญ',
        goldCost: 15,
        description: 'ได้รับ Gold ทันที 100 เหรียญ',
        iconName: 'savings',
        itemCategory: RewardCategory.consumable,
        rarity: ItemRarity.rare,
        effectType: ItemEffectType.instantGold,
        effectValue: 100,
      ),
      RewardModel(
        title: 'เหรียญนักตื่นเช้า',
        goldCost: 300,
        description: 'ของสะสมสำหรับผู้พิชิต Habit ต่อเนื่อง',
        iconName: 'wb_sunny',
        itemCategory: RewardCategory.collectible,
        rarity: ItemRarity.epic,
      ),
      RewardModel(
        title: 'ตรา Multitasking Adventurer',
        goldCost: 420,
        description: 'ของสะสมสำหรับผู้ทำ Concurrent Quest สำเร็จ',
        iconName: 'military_tech',
        itemCategory: RewardCategory.collectible,
        rarity: ItemRarity.epic,
      ),
      RewardModel(
        title: 'Streak Repair Hammer',
        goldCost: GamificationConfig.streakRepairHammerCost,
        description: 'กู้คืน Streak ที่ถูกรีเซ็ตจากการขาดต่อเนื่อง 2 วัน',
        iconName: 'build',
        itemCategory: RewardCategory.consumable,
        rarity: ItemRarity.epic,
        effectType: ItemEffectType.streakRepairHammer,
        effectValue: 1,
      ),
      RewardModel(
        title: 'Freeze Wand / Shield',
        goldCost: GamificationConfig.freezeStreakShieldCost,
        description: 'แช่แข็ง Streak ล่วงหน้า 1-3 วัน',
        iconName: 'ac_unit',
        itemCategory: RewardCategory.consumable,
        rarity: ItemRarity.rare,
        effectType: ItemEffectType.freezeStreakShield,
        effectValue: 1,
      ),
      RewardModel(
        title: 'Melt Potion',
        goldCost: GamificationConfig.meltFrozenStreakCost,
        description: 'ละลาย Frozen และรับโบนัส EXP เควสต์ถัดไป 25%',
        iconName: 'local_drink',
        itemCategory: RewardCategory.consumable,
        rarity: ItemRarity.rare,
        effectType: ItemEffectType.meltFrozenStreak,
        effectValue: 0.25,
      ),
    ];

    for (final reward in defaults) {
      final existingReward = existingByTitle[reward.title];
      if (existingReward == null) {
        await insertReward(reward);
        continue;
      }

      final needsRefresh =
          existingReward.goldCost != reward.goldCost ||
          existingReward.description != reward.description ||
          existingReward.iconName != reward.iconName ||
          existingReward.itemCategory != reward.itemCategory ||
          existingReward.rarity != reward.rarity ||
          existingReward.effectType != reward.effectType ||
          existingReward.effectValue != reward.effectValue;

      if (needsRefresh) {
        await updateReward(reward.copyWith(id: existingReward.id));
      }
    }
  }

  Future<List<RewardModel>> getAllRewards() async {
    final db = await database;
    final maps = await db.query(tableRewards, orderBy: 'gold_cost ASC');
    return maps.map((m) => RewardModel.fromMap(m)).toList();
  }

  Future<List<RewardModel>> getCustomRewards() async {
    final db = await database;
    final maps = await db.query(
      tableRewards,
      where: 'is_custom_reward = 1',
      orderBy: 'id DESC',
    );
    return maps.map((map) => RewardModel.fromMap(map)).toList();
  }

  Future<int> updateReward(RewardModel reward) async {
    assert(reward.id != null, 'RewardModel.id must not be null when updating');
    final db = await database;
    return await db.update(
      tableRewards,
      reward.toMap(),
      where: 'id = ?',
      whereArgs: [reward.id],
    );
  }

  Future<int> deleteReward(int id) async {
    final db = await database;
    return await db.delete(tableRewards, where: 'id = ?', whereArgs: [id]);
  }

  /// แลกของรางวัล: หัก Gold + เพิ่มเข้าคลัง (inventory_items) ในทรานแซกชัน
  /// เดียวกัน — equipment จะถูกสวมใส่ทันทีอัตโนมัติ (unequip ของเก่า),
  /// consumable/collectible จะเพิ่ม quantity หรือสร้างแถวใหม่
  Future<RedeemOutcome> redeemReward({
    required int userId,
    required int rewardId,
  }) async {
    final db = await database;
    return await db.transaction<RedeemOutcome>((txn) async {
      final userMaps = await txn.query(
        tableUsers,
        where: 'id = ?',
        whereArgs: [userId],
      );
      final rewardMaps = await txn.query(
        tableRewards,
        where: 'id = ?',
        whereArgs: [rewardId],
      );
      if (userMaps.isEmpty || rewardMaps.isEmpty) {
        throw StateError('User or reward not found.');
      }
      final currentGold = userMaps.first['gold'] as int;
      final currentGems = userMaps.first['gems'] as int? ?? 0;
      final cost = rewardMaps.first['gold_cost'] as int;
      final isCustom = (rewardMaps.first['is_custom_reward'] as int? ?? 0) == 1;

      if (isCustom) {
        if (currentGold < cost) return RedeemOutcome.notEnoughGold;
      } else {
        if (currentGems < cost) return RedeemOutcome.notEnoughGems;
      }

      final purchaseLimit = CustomRewardPurchaseLimitX.fromDb(
        rewardMaps.first['purchase_limit'] as String?,
      );
      if (purchaseLimit != CustomRewardPurchaseLimit.none) {
        final now = DateTime.now();
        final start = switch (purchaseLimit) {
          CustomRewardPurchaseLimit.daily1 ||
          CustomRewardPurchaseLimit.daily2 => DateTime(
            now.year,
            now.month,
            now.day,
          ),
          CustomRewardPurchaseLimit.weekly1 => now.subtract(
            Duration(days: now.weekday - 1),
          ),
          CustomRewardPurchaseLimit.monthly1 => DateTime(now.year, now.month),
          CustomRewardPurchaseLimit.none => now,
        };
        final countRows = await txn.rawQuery(
          'SELECT COUNT(*) AS count FROM $tableRedemptions '
          'WHERE reward_id = ? AND redeemed_at >= ?',
          [rewardId, start.toIso8601String()],
        );
        final count = (countRows.first['count'] as int?) ?? 0;
        final maxPurchases = purchaseLimit == CustomRewardPurchaseLimit.daily2
            ? 2
            : 1;
        if (count >= maxPurchases) return RedeemOutcome.purchaseLimitReached;
      }

      final capacity = userMaps.first['inventory_capacity'] as int? ?? 20;
      final existingStack = await txn.query(
        tableInventoryItems,
        where: 'reward_id = ?',
        whereArgs: [rewardId],
      );

      // เช็คคลังเต็มเฉพาะตอนเป็นไอเทมชนิดใหม่ที่ยังไม่มีในคลัง (ของซ้ำ
      // แค่บวก quantity ในแถวเดิม ไม่กินช่องคลังเพิ่ม)
      if (existingStack.isEmpty) {
        final slotCountResult = await txn.rawQuery(
          'SELECT COUNT(*) AS c FROM $tableInventoryItems',
        );
        final usedSlots = (slotCountResult.first['c'] as int?) ?? 0;
        if (usedSlots >= capacity) return RedeemOutcome.inventoryFull;
      }

      await txn.update(
        tableUsers,
        isCustom ? {'gold': currentGold - cost} : {'gems': currentGems - cost},
        where: 'id = ?',
        whereArgs: [userId],
      );
      await txn.insert(tableRedemptions, {
        'reward_id': rewardId,
        'redeemed_at': DateTime.now().toIso8601String(),
      });

      final itemCategory =
          rewardMaps.first['item_category'] as String? ?? 'CONSUMABLE';
      if (existingStack.isNotEmpty) {
        final row = existingStack.first;
        await txn.update(
          tableInventoryItems,
          {'quantity': (row['quantity'] as int? ?? 1) + 1},
          where: 'id = ?',
          whereArgs: [row['id']],
        );
      } else {
        await txn.insert(tableInventoryItems, {
          'reward_id': rewardId,
          'quantity': 1,
          'is_equipped': 0,
          'acquired_at': DateTime.now().toIso8601String(),
        });
      }

      if (itemCategory == 'EQUIPMENT') {
        // สวมใส่ของที่เพิ่งได้มาทันที แทนที่ equipment ตัวเดิม (สวมได้
        // ทีละ 1 ชิ้นทั้งระบบ เพื่อให้ตรงกับ mockup ที่มี "กำลังใช้งาน"
        // แค่ badge เดียว)
        await txn.update(tableInventoryItems, {'is_equipped': 0});
        await txn.update(
          tableInventoryItems,
          {'is_equipped': 1},
          where: 'reward_id = ?',
          whereArgs: [rewardId],
        );
      }

      return RedeemOutcome.success;
    });
  }

  // -----------------------------------------------------------------------
  // INVENTORY
  // -----------------------------------------------------------------------

  /// คืนไอเทมในคลังทั้งหมด พร้อมรายละเอียดของรางวัลที่ผูกอยู่ (join แล้ว)
  Future<List<InventoryEntry>> getInventory() async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT
        i.id AS inv_id, i.reward_id AS inv_reward_id, i.quantity AS inv_quantity,
        i.is_equipped AS inv_is_equipped, i.acquired_at AS inv_acquired_at,
        r.*
      FROM $tableInventoryItems i
      INNER JOIN $tableRewards r ON r.id = i.reward_id
      ORDER BY i.is_equipped DESC, i.acquired_at DESC
    ''');
    return maps.map((m) {
      final item = InventoryItemModel(
        id: m['inv_id'] as int?,
        rewardId: m['inv_reward_id'] as int,
        quantity: m['inv_quantity'] as int? ?? 1,
        isEquipped: (m['inv_is_equipped'] as int? ?? 0) == 1,
        acquiredAt: m['inv_acquired_at'] as String,
      );
      final reward = RewardModel.fromMap(m);
      return InventoryEntry(item: item, reward: reward);
    }).toList();
  }

  Future<int> getInventorySlotCount() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM $tableInventoryItems',
    );
    return (result.first['c'] as int?) ?? 0;
  }

  /// ใช้ consumable 1 ชิ้น — ลด quantity ลง 1 (ลบแถวถ้าหมด) คืนค่า
  /// RewardModel ของไอเทมที่เพิ่งใช้กลับไป ให้ provider เอาไปสั่ง apply
  /// effect ต่อ (แยก concern: DB แค่จัดการ inventory ไม่รู้เรื่อง business
  /// logic ของ effect แต่ละแบบ)
  Future<RewardModel?> useInventoryItem(int inventoryItemId) async {
    final db = await database;
    return await db.transaction<RewardModel?>((txn) async {
      final maps = await txn.query(
        tableInventoryItems,
        where: 'id = ?',
        whereArgs: [inventoryItemId],
      );
      if (maps.isEmpty) return null;
      final row = maps.first;
      final currentQty = row['quantity'] as int? ?? 1;

      if (currentQty <= 1) {
        await txn.delete(
          tableInventoryItems,
          where: 'id = ?',
          whereArgs: [inventoryItemId],
        );
      } else {
        await txn.update(
          tableInventoryItems,
          {'quantity': currentQty - 1},
          where: 'id = ?',
          whereArgs: [inventoryItemId],
        );
      }

      final rewardMaps = await txn.query(
        tableRewards,
        where: 'id = ?',
        whereArgs: [row['reward_id']],
      );
      if (rewardMaps.isEmpty) return null;
      return RewardModel.fromMap(rewardMaps.first);
    });
  }

  /// ทิ้งไอเทม 1 ชิ้น — ลด quantity และลบแถวเมื่อชิ้นสุดท้ายถูกทิ้ง
  Future<bool> discardInventoryItem(int inventoryItemId) async {
    final db = await database;
    return db.transaction<bool>((txn) async {
      final rows = await txn.query(
        tableInventoryItems,
        where: 'id = ?',
        whereArgs: [inventoryItemId],
      );
      if (rows.isEmpty) return false;

      final quantity = rows.first['quantity'] as int? ?? 1;
      if (quantity <= 1) {
        await txn.delete(
          tableInventoryItems,
          where: 'id = ?',
          whereArgs: [inventoryItemId],
        );
      } else {
        await txn.update(
          tableInventoryItems,
          {'quantity': quantity - 1},
          where: 'id = ?',
          whereArgs: [inventoryItemId],
        );
      }
      return true;
    });
  }

  /// สวม equipment ที่เลือก — unequip ของเก่าทั้งหมดก่อนเสมอ (สวมได้ทีละ
  /// 1 ชิ้น)
  Future<void> equipInventoryItem(int inventoryItemId) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update(tableInventoryItems, {'is_equipped': 0});
      await txn.update(
        tableInventoryItems,
        {'is_equipped': 1},
        where: 'id = ?',
        whereArgs: [inventoryItemId],
      );
    });
  }

  /// คืน RewardModel ของ equipment ที่สวมใส่อยู่ตอนนี้ (null ถ้าไม่มี) —
  /// ใช้เช็คตอนเริ่ม Focus session ว่ามีโบนัส focusTimeBonusPercent ไหม
  Future<RewardModel?> getEquippedEquipment() async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT r.* FROM $tableInventoryItems i
      INNER JOIN $tableRewards r ON r.id = i.reward_id
      WHERE i.is_equipped = 1
      LIMIT 1
    ''');
    if (maps.isEmpty) return null;
    return RewardModel.fromMap(maps.first);
  }

  /// ขยายช่องคลัง — เรียกคู่กับการหัก Gold ที่ฝั่ง provider (userProvider
  /// .spendGold) แยกกัน เพราะ Gold เป็นสิทธิ์ของ UserNotifier ไม่ใช่ตรงนี้
  Future<void> expandInventoryCapacity(int userId, int amount) async {
    final db = await database;
    final maps = await db.query(
      tableUsers,
      where: 'id = ?',
      whereArgs: [userId],
    );
    if (maps.isEmpty) return;
    final current = maps.first['inventory_capacity'] as int? ?? 20;
    await db.update(
      tableUsers,
      {'inventory_capacity': current + amount},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  Future<List<Map<String, dynamic>>> getRedemptionHistory() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT r.id AS redemption_id, r.redeemed_at,
             rw.id AS reward_id, rw.title, rw.description,
             rw.gold_cost, rw.icon_name
      FROM $tableRedemptions r
      INNER JOIN $tableRewards rw ON rw.id = r.reward_id
      ORDER BY r.redeemed_at DESC
    ''');
  }

  // -----------------------------------------------------------------------
  // ACHIEVEMENTS
  // -----------------------------------------------------------------------

  Future<Set<String>> getUnlockedAchievementCodes() async {
    final db = await database;
    final maps = await db.query(tableUnlockedAchievements);
    return maps.map((m) => m['code'] as String).toSet();
  }

  /// ปลดล็อก achievement — ใช้ INSERT OR IGNORE กัน error ตอนเรียกซ้ำ
  /// (เช่นเช็คเงื่อนไขผ่านซ้ำหลายรอบ) เพราะ code มี UNIQUE constraint อยู่
  Future<void> unlockAchievement(String code) async {
    final db = await database;
    await db.insert(tableUnlockedAchievements, {
      'code': code,
      'unlocked_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<List<UnlockedAchievementModel>> getUnlockedAchievements() async {
    final db = await database;
    final maps = await db.query(
      tableUnlockedAchievements,
      orderBy: 'unlocked_at DESC',
    );
    return maps.map((m) => UnlockedAchievementModel.fromMap(m)).toList();
  }

  /// จำนวนเควสที่ทำสำเร็จสะสมทั้งหมด (ไม่ใช่แค่วันนี้) — ใช้เช็คเงื่อนไข
  /// achievement ประเภท questsCompleted
  Future<int> getCompletedQuestsCount() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM $tableQuests WHERE is_completed = 1',
    );
    return (result.first['c'] as int?) ?? 0;
  }

  // -----------------------------------------------------------------------
  // STATS
  // -----------------------------------------------------------------------

  Future<Map<String, int>> getTodayEarnedTotals({DateTime? now}) async {
    final db = await database;
    final today = now ?? DateTime.now();
    final startOfDay = DateTime(
      today.year,
      today.month,
      today.day,
    ).toIso8601String();
    final endOfDay = DateTime(
      today.year,
      today.month,
      today.day,
      23,
      59,
      59,
    ).toIso8601String();
    // นับจากยอด "ได้รับจริง" (awarded_exp/awarded_gold หลังผ่าน Streak
    // Multiplier + Daily Cap) ไม่ใช่ exp_reward/gold_reward ที่ตั้งไว้ตอน
    // สร้างเควส — ไม่งั้น Anti-Exploit cap จะคำนวณผิดพลาด
    final result = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(awarded_exp), 0) AS total_exp,
             COALESCE(SUM(awarded_gold), 0) AS total_gold
      FROM $tableQuests
      WHERE is_completed = 1
        AND completed_at BETWEEN ? AND ?
    ''',
      [startOfDay, endOfDay],
    );
    final row = result.first;
    return {'exp': row['total_exp'] as int, 'gold': row['total_gold'] as int};
  }

  /// ดึงเควสที่ทำสำเร็จในช่วงเวลาที่กำหนด (ใช้สำหรับ weekly stats chart)
  Future<List<QuestModel>> getCompletedQuestsBetween(
    DateTime from,
    DateTime to,
  ) async {
    final db = await database;
    final maps = await db.rawQuery(
      '''
      SELECT * FROM $tableQuests
      WHERE is_completed = 1
        AND completed_at BETWEEN ? AND ?
      ORDER BY completed_at ASC
    ''',
      [from.toIso8601String(), to.toIso8601String()],
    );
    return maps.map((m) => QuestModel.fromMap(m)).toList();
  }

  Future<List<QuestModel>> getRecentCompletedQuests({int limit = 15}) async {
    final db = await database;
    final maps = await db.query(
      tableQuests,
      where: 'is_completed = 1 AND completed_at IS NOT NULL',
      orderBy: 'completed_at DESC',
      limit: limit,
    );
    return maps.map((map) => QuestModel.fromMap(map)).toList();
  }

  /// ดึงเควสต์ที่ทำสำเร็จวันนี้ (ใช้สำหรับหน้า Stats แสดงรายการเสร็จแล้ว)
  Future<List<QuestModel>> getTodayCompletedQuests({DateTime? now}) async {
    final db = await database;
    final today = now ?? DateTime.now();
    final startOfDay = DateTime(
      today.year,
      today.month,
      today.day,
    ).toIso8601String();
    final endOfDay = DateTime(
      today.year,
      today.month,
      today.day,
      23,
      59,
      59,
    ).toIso8601String();
    final maps = await db.rawQuery(
      '''
      SELECT * FROM $tableQuests
      WHERE is_completed = 1
        AND completed_at BETWEEN ? AND ?
      ORDER BY completed_at DESC
    ''',
      [startOfDay, endOfDay],
    );
    return maps.map((m) => QuestModel.fromMap(m)).toList();
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
