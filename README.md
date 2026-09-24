# Quest Log — Data Layer (Models + DatabaseHelper)

โครงสร้างไฟล์ที่ส่งมอบในรอบนี้:

```
lib/
  models/
    user_model.dart          -> users
    quest_model.dart         -> quests
    quest_enums.dart         -> QuestCategory, ActivityType (+ แปลงเป็น/จาก ค่าใน DB)
    sub_task_model.dart      -> sub_tasks
    focus_session_model.dart -> active_focus_sessions, session_quests
    reward_model.dart        -> rewards, redemptions
  database/
    database_helper.dart     -> Singleton จัดการ schema ทั้งหมด + CRUD
```

## ติดตั้ง dependency

เพิ่มใน `pubspec.yaml` ของโปรเจกต์จริง:

```yaml
dependencies:
  sqflite: ^2.3.0
  path: ^1.9.0
```

## จุดออกแบบสำคัญ

1. **PRAGMA foreign_keys = ON** ถูกเปิดใน `onConfigure` เสมอ ทุกครั้งที่เชื่อมต่อ DB
   ตามที่ spec กำหนด ไม่ใช่แค่ตอน `onCreate`

2. **ทุก Model มี `toMap()` / `fromMap()`** และ `copyWith()` เพื่อ immutable pattern
   ที่ทำงานร่วมกับ Riverpod/Provider ได้ง่ายในขั้นตอนถัดไป

3. **Enum ↔ DB string** (`category`, `activity_type`) แปลงผ่าน extension
   (`QuestCategoryX`, `ActivityTypeX`) เพื่อไม่ให้ magic string หลุดไปกระจายทั่วโค้ด

4. **`completeQuest()`** แค่ mark สถานะ + คืนค่า quest ที่อัปเดต — **ไม่บวก
   exp/gold ให้ user ในชั้นนี้** เพราะ Daily Cap / Streak Multiplier เป็น
   business logic ที่ควรอยู่ใน service layer (รอบถัดไปตาม scope ข้อ 2:
   Algorithm คำนวณ EXP/Gold)

5. **`getTodayEarnedTotals()`** เตรียม hook ไว้ให้ service layer เช็ค Daily Cap
   ก่อนจะบวกรางวัลจริงให้ user

6. **`startFocusSession()` และ `redeemReward()`** ใช้ `db.transaction()`
   เพื่อป้องกันข้อมูลไม่สอดคล้องกัน (เช่น session ถูกสร้างแต่ไม่มีเควสผูกอยู่,
   หรือกด redeem ซ้ำเร็วๆ จนหัก gold เกิน)

7. **ON DELETE CASCADE** ตั้งไว้ตาม schema: ลบ quest แล้ว sub_tasks และ
   session_quests ที่เกี่ยวข้องจะถูกลบตามอัตโนมัติ

---

# รอบที่ 2: Services + Riverpod State Management

## ไฟล์ที่เพิ่มเข้ามา

```
lib/
  services/
    gamification_config.dart     -> ค่าคงที่ทั้งหมด (tunable numbers) จุดเดียว
    reward_calculator_service.dart -> Auto-Calculated Rewards, Gatekeeper,
                                       Daily Cap, Streak Multiplier
    quest_conflict_service.dart  -> Conflict Resolution Engine
  providers/
    core_providers.dart  -> DatabaseHelper + services (Provider ธรรมดา)
    user_provider.dart   -> Level/EXP/Gold/Streak (AsyncNotifier)
    quest_providers.dart -> QuestFilter family, sub-tasks, complete-quest orchestration
    focus_providers.dart -> Focus selection (conflict-aware) + active session
    rewards_providers.dart -> Rewards shop + redemption + redeem action
```

เพิ่มใน `pubspec.yaml`:

```yaml
dependencies:
  flutter_riverpod: ^2.5.1
```

## Services layer (pure logic, ไม่แตะ DB โดยตรง)

### `RewardCalculatorService`
ตอบ spec ข้อ 3.2 ครบ 3 กลไก:

- `calculateAutoReward(...)` — คำนวณ EXP/Gold จาก `estimated_minutes`,
  `sub_tasks_count`, `activity_type`, `difficulty` พร้อมเช็ค
  **Duration-Difficulty Gatekeeper** ก่อนเสมอ (difficulty >= 4 ต้อง
  estimated_minutes >= 30 ไม่งั้น `isAllowed = false`). ใช้กับ Real-time
  Reward Preview บนหน้า Add/Edit Quest
- `applyStreakMultiplier(...)` — บวกโบนัสจาก Daily Streak (5%/วัน สูงสุด
  +100%) ตอนทำเควสสำเร็จจริง ไม่ใช่ตอน preview
- `applyDailyCap(...)` — **Daily Cap / Anti-Exploit**: ครอบ EXP/Gold ที่จะ
  ได้จริงไม่ให้เกินเพดานต่อวัน โดยดูยอดที่ได้ไปแล้ววันนี้ผ่าน
  `DatabaseHelper.getTodayEarnedTotals()`
- `resolveQuestCompletionReward(...)` — pipeline ครบ: streak multiplier ->
  daily cap ในฟังก์ชันเดียว

ค่าคงที่ทั้งหมด (base rate, ตัวคูณ difficulty/activity, เพดานรายวัน ฯลฯ)
อยู่ใน `GamificationConfig` — ปรับสมดุลเกมได้จากไฟล์เดียว ไม่ต้องแก้ logic

### `QuestConflictService`
ตอบ spec ข้อ 3.1 — Conflict Resolution Engine:

- กฎ conflict เก็บเป็น data (`_severeConflicts` list) แยกจาก logic ตรวจสอบ
  ตั้งต้นมีคู่เดียวตามตัวอย่างใน spec: `PHYSICAL_HEAVY` ↔ `STILLNESS`
  (เพิ่มคู่อื่นได้ที่เดียวในอนาคตถ้ามี business rule เพิ่ม)
- `canAddToSelection(selected, candidate)` — ใช้ตอนผู้ใช้จะเพิ่มเควสเข้า
  Focus Screen คืน conflict แรกที่เจอพร้อมข้อความเตือน
- `getBlockedQuestIds(selected, candidates)` — helper คืนชุด quest id ที่
  ต้อง disable ทั้งลิสต์ในทีเดียว ใช้ผูกกับ UI ตรงๆ

## Riverpod layer

- **`userProvider`** (`AsyncNotifier<UserModel?>`): โหลด user จาก DB,
  มี `addExpAndGold` (รองรับ level-up แบบ carry-over อัตโนมัติ), `spendGold`,
  `touchDailyStreak` (เทียบ `last_active_date` กับวันนี้)
- **`questListProvider`** (`AsyncNotifierProvider.family<..., QuestFilter>`):
  ดึงเควสตาม filter (มี preset `QuestFilter.main/side/daily/completed`) —
  ใช้ตรงกับแท็บบน Dashboard ได้เลย
- **`questActionsProvider`**: รวม orchestration ที่กระทบหลาย provider —
  `completeQuest(id)` รันครบ pipeline (mark completed -> streak ->
  reward calc -> daily cap -> บวกให้ user -> invalidate quest lists)
  ในฟังก์ชันเดียว คืนค่า `(exp, gold, wasCapped)` ให้ UI โชว์ toast ได้
- **`focusSelectionProvider`** + **`blockedQuestIdsProvider`**: ให้ UI
  หน้า Focus Screen ผูก `blockedQuestIdsProvider(candidateList)` เข้ากับ
  การ์ดเควสได้ตรงๆ — เควสไหนอยู่ใน set ที่คืนมา ให้ disable ปุ่มเลือก
  พร้อมโชว์เหตุผลจาก `QuestConflictService.checkPair(...).reason`
- **`activeFocusSessionProvider`** + **`activeSessionQuestsProvider`**:
  session ที่กำลัง active + รายการเควสในนั้น สำหรับ Focus Dashboard
- **`rewardsListProvider.redeem(rewardId)`**: แลกของรางวัล — หัก gold,
  บันทึก log, รีเฟรช user และ redemption history ให้อัตโนมัติ

## ตัวอย่างการต่อกับ UI

```dart
// Dashboard: แท็บ Daily Quest
final dailyQuests = ref.watch(questListProvider(QuestFilter.daily));

// ปุ่ม complete เควส
await ref.read(questActionsProvider.notifier).completeQuest(quest.id!);

// Add/Edit Quest: real-time reward preview
final preview = ref.read(rewardCalculatorProvider).calculateAutoReward(
  difficulty: selectedDifficulty,
  estimatedMinutes: minutes,
  activityType: selectedActivityType,
  subTaskCount: subTasks.length,
);
if (!preview.isAllowed) {
  // โชว์ preview.blockReason ใต้ช่องกรอกเวลา
}

// Focus Screen: การ์ดเควสที่เลือกไม่ได้เพราะ conflict
final blocked = ref.watch(blockedQuestIdsProvider(allCandidateQuests));
final isDisabled = blocked.contains(quest.id);
```

---

# รอบที่ 3: UI Screens ครบชุด + Integration Fixes

ไฟล์ UI (screens/widgets/theme/services เวอร์ชันใหม่) ถูกสร้างขึ้นแยกจาก
เซสชันนี้ (ตาม PROMPTS_NEXT_PHASE.md) แล้วอัปโหลดกลับมารวมกัน รอบนี้คือ
**การ sync + แก้จุดที่ไม่ตรงกันให้โปรเจกต์คอมไพล์ได้จริงทั้งต้น**

## ไฟล์ที่เพิ่ม/แทนที่ทั้งหมด

```
lib/
  theme/
    app_colors.dart        -> แทนที่ (สี/ระบบใหม่ครบกว่าเดิม)
    app_theme.dart          -> แทนที่ (ใช้ google_fonts, Material 3 เต็มรูปแบบ)
  widgets/
    exp_bar.dart             -> แทนที่
    quest_card.dart          -> แทนที่ (มี checklist mode สำหรับ Focus Screen)
    rpg_button.dart          -> แทนที่ (มี isLoading, width/height)
    stat_badge.dart          -> แทนที่ (ใช้ StatBadgeType enum)
    level_up_overlay.dart    -> ใหม่ (Phase 10 animation)
  services/
    gamification_config.dart       -> แทนที่ (ค่าเดียวกัน ปรับตัวเลขเล็กน้อย)
    quest_conflict_service.dart    -> แทนที่ (API หน้าตาเหมือนเดิม)
    reward_calculator_service.dart -> แทนที่ (API เหมือนเดิมทุกจุด)
  screens/
    login_screen.dart
    onboarding_screen.dart
    dashboard_screen.dart
    add_quest_screen.dart
    focus_screen.dart
    member_center_screen.dart
    rewards_screen.dart
    stats_screen.dart
    settings/settings_main_screen.dart   -- ย้ายมาไว้ subfolder settings/
                                              ตามที่ member_center_screen.dart import
  main.dart                 -> แทนที่
```

## จุดที่ไม่ตรงกันและแก้ไขแล้ว

1. **`QuestCategory` / `ActivityType` ไม่มี `.displayName`** — หน้า
   `add_quest_screen.dart` และ `quest_card.dart` เรียก `cat.displayName`
   / `act.displayName` แต่ `quest_enums.dart` เดิมไม่มี getter นี้ →
   เพิ่ม extension `displayName` ให้ทั้งสอง enum แล้ว
2. **`UserModel.streakDays` ไม่มีอยู่จริง** — `dashboard_screen.dart` และ
   `stats_screen.dart` เรียก `user.streakDays` แต่ field จริงในโมเดลคือ
   `streakCount` (ตรงกับคอลัมน์ `streak_count`) → เพิ่ม getter
   `streakDays` เป็น alias ของ `streakCount` แทนที่จะเปลี่ยนชื่อ field จริง
   (กัน schema/DB mapping เดิมพัง)
3. **`weekly_stats_provider.dart` ไม่เคยถูกสร้าง** — `stats_screen.dart`
   import ไฟล์นี้ตั้งแต่แรกแต่ไม่มีอยู่ในโปรเจกต์ → สร้างใหม่ทั้งไฟล์
   (`DayStat` model + `weeklyStatsProvider` ที่ query
   `DatabaseHelper.getCompletedQuestsBetween` ทีละวัน ย้อนหลัง 7 วัน)
4. **`settings_provider.dart` API ไม่ตรงกับหน้า Settings ใหม่** —
   `settings_main_screen.dart` คาดหวัง class ชื่อ `SettingsState` (ไม่ใช่
   `SettingsModel` ของเดิม) พร้อม method แบบ `toggleXxx()` (ไม่ใช่
   `setXxx(bool)`) และมี field เพิ่ม `morningDigest`/`focusWindow`/
   `eveningRecap` → เขียน `settings_provider.dart` ใหม่ทั้งไฟล์ให้ตรงกับ
   ที่หน้า Settings ต้องการ ส่วน `main.dart` ที่อ่าน `settings?.isDarkTheme`
   ยังใช้ได้เหมือนเดิมเพราะ field ชื่อนี้คงไว้
5. **`settings_main_screen.dart` อยู่ผิดตำแหน่ง** — ไฟล์ import
   `'../../providers/settings_provider.dart'` (ลึก 2 ระดับจาก `lib/`)
   แต่ `member_center_screen.dart` import เป็น
   `'settings/settings_main_screen.dart'` → ย้ายไฟล์ไปไว้ที่
   `lib/screens/settings/settings_main_screen.dart` ให้ตรงกับทั้งสองฝั่ง
6. **`fontFamily: 'PressStart2P'` อ้างถึง font ที่ไม่ได้ bundle** — มีใน
   `login_screen.dart`, `dashboard_screen.dart`, `focus_screen.dart`,
   `level_up_overlay.dart` แต่ไม่มีไฟล์ font จริงแนบมาและไม่ได้ประกาศใน
   `pubspec.yaml` (`fonts:`) → เปลี่ยนทั้งหมดเป็น `GoogleFonts.pressStart2p(...)`
   แทน เพราะโปรเจกต์ผูก `google_fonts` อยู่แล้วจาก `app_theme.dart` ทำให้
   ไม่ต้อง bundle ไฟล์ font เอง

## Services/Widgets ที่ตรวจแล้วว่า "แทนที่ได้แบบไม่กระทบ" (drop-in compatible)

`gamification_config.dart`, `quest_conflict_service.dart`,
`reward_calculator_service.dart` เวอร์ชันใหม่ยังคง public API (ชื่อ class,
ชื่อ field, ชื่อ method) เหมือนเวอร์ชันเดิมทุกจุดที่ `quest_providers.dart`,
`focus_providers.dart`, `core_providers.dart` เรียกใช้ — จึงแทนที่ไฟล์เดิม
ได้ตรงๆ โดยไม่ต้องแก้ provider layer เลย

## เพิ่มใน pubspec.yaml (สะสมจากทุกรอบ)

```yaml
dependencies:
  flutter_riverpod: ^2.5.1
  sqflite: ^2.3.0
  path: ^1.9.0
  shared_preferences: ^2.2.3
  google_fonts: ^6.2.1
```

---

# รอบที่ 4: Sync ไฟล์ model/provider เวอร์ชันล่าสุด + ⚠️ ไฟล์ปนโปรเจกต์อื่น

## ไฟล์ Quest Log ที่ sync แล้ว (compatible ทั้งหมด ไม่ต้องแก้อะไรเพิ่ม)

```
lib/models/focus_session_model.dart   -> targetDuration เปลี่ยนจาก optional
                                          เป็น required (ไม่กระทบ ทุกจุดที่
                                          เรียกอยู่แล้วส่งค่านี้เสมอ)
lib/models/quest_enums.dart           -> เหมือนเดิม (มี displayName แล้ว)
lib/models/quest_model.dart           -> เหมือนเดิม
lib/models/reward_model.dart          -> เหมือนเดิม
lib/models/sub_task_model.dart        -> เหมือนเดิม (toString ต่างเล็กน้อย)
lib/models/user_model.dart            -> เพิ่ม lastLoginDate (alias ของ
                                          lastActiveDate) นอกเหนือจาก
                                          streakDays ที่มีอยู่แล้ว
lib/providers/core_providers.dart     -> เหมือนเดิม
lib/providers/focus_providers.dart    -> เหมือนเดิม
lib/providers/quest_providers.dart    -> เพิ่ม QuestFilter.incomplete preset
lib/providers/rewards_providers.dart  -> เหมือนเดิม
lib/providers/settings_provider.dart  -> เขียนใหม่ (เก็บ pref keys แบบสั้น
                                          ไม่มี prefix 'settings.' — ค่าเก่า
                                          ที่เคยบันทึกไว้จะ reset กลับเป็น
                                          default เพราะ key เปลี่ยน แต่
                                          method/field ชื่อเดิมหมดทุกจุด)
lib/providers/user_provider.dart      -> เพิ่ม updateProfile({name}) สำหรับ
                                          หน้า Edit Profile ที่ยังไม่ได้สร้าง
lib/providers/weekly_stats_provider.dart
                                       -> เปลี่ยนจาก DayStat เป็น
                                          DailyStatEntry ที่ข้อมูลละเอียดขึ้น
                                          (แยกตาม category, รวม EXP ต่อวัน)
                                          แต่ยังมี .completedQuestsCount และ
                                          .dateLabel เป็น getter ให้ตรงกับที่
                                          stats_screen.dart เรียกใช้อยู่ —
                                          ตรวจแล้วว่า drop-in compatible
```

## ⚠️ ไฟล์ที่ไม่เกี่ยวกับ Quest Log — ยังไม่ได้เอาเข้าโปรเจกต์

ไฟล์ `models.dart` และ `farm_provider.dart` ที่แนบมาในรอบนี้เป็นของ
**แอปคนละตัว** — เป็นแอปจัดการงบประมาณ/การเงินธีมฟาร์ม (`TransactionItem`,
`CropPlot`, `ShopItem`, `MilestoneGoal`, `FarmProvider` ที่ใช้
`ChangeNotifier` ไม่ใช่ Riverpod) ไม่มีจุดเชื่อมกับ schema, model, หรือ
provider ใดๆ ของ Quest Log เลย

ไม่ได้เอาสองไฟล์นี้เข้า `quest_log/` — รอ confirm ก่อนว่า:
- แนบผิดไฟล์มาโดยไม่ได้ตั้งใจ (ข้ามได้เลย) หรือ
- เป็นโปรเจกต์ใหม่ที่ต้องการให้ช่วยต่อแยกต่างหาก (บอกได้เลยว่าต้องการให้ทำอะไรกับมัน)

- **Focus Screen ยังไม่ผูก Conflict Resolution Engine เข้ากับ UI จริง** —
  `focus_screen.dart` ที่แนบมาให้เลือกเควสได้อิสระผ่าน `CheckboxListTile`
  ไม่มีการ disable ตัวเลือกที่ขัดแย้งกัน (`blockedQuestIdsProvider` ที่มี
  อยู่แล้วยังไม่ถูกเรียกใช้ในหน้านี้) — ต้องต่อในรอบถัดไปถ้าต้องการให้ตรง
  กับ spec ข้อ 3.1 เต็มรูปแบบ
- **`onboarding_screen.dart`** เก็บค่า toggle แจ้งเตือน
  (Morning/Focus/Evening) เป็น local state เฉยๆ ยังไม่ได้บันทึกลง
  `settingsProvider` ตอนกด "เริ่มผจญภัยเลย!"
- ยังไม่มี unit test ใดๆ ทั้งฝั่ง services และ providers

---

# รอบที่ 5: Reset ไฟล์ทั้งหมด + Feature ใหม่ (Sub-tasks, Avatar, Edit Profile)

รอบนี้คุณส่งไฟล์ Quest Log **ใหม่ทั้งหมด** (4 ครั้งติดกัน รวม ~34 ไฟล์) มาแทนที่
ของเดิมทั้งโปรเจกต์ ผมรอจนครบตามที่ขอแล้วค่อย sync + ตรวจสอบความสอดคล้องทีเดียว

## Feature ใหม่ที่มากับรอบนี้

1. **Sub-tasks ใน Add Quest Screen** — เพิ่ม/ลบ sub-task แบบ dynamic list,
   ส่งเข้า `subTaskCount` ให้ reward calculator ด้วย (sub-task ยิ่งเยอะ EXP
   ยิ่งสูงตาม `expPerSubTask` ใน config), และ `addQuest()` แทรกเป็นแถว
   `sub_tasks` ให้อัตโนมัติหลังสร้างเควส
2. **Manual reward mode** — ตอนปิด Auto-Calculate ตอนนี้กรอก EXP/Gold เอง
   ได้จริงแล้ว (เดิมกดปิดแล้วไม่มีช่องให้กรอกเลย)
3. **Avatar system** — `app_avatars.dart` (ใหม่) + `UserModel.avatarIndex`
   + คอลัมน์ `avatar_index` ใน `users` table เลือกได้ตอน Onboarding,
   แสดงที่ Member Center
4. **Edit Profile Screen** (ใหม่) — แก้ชื่อฮีโร่ ผูกกับ
   `UserNotifier.updateProfile()` ที่มีอยู่แล้วแต่ไม่เคยมีหน้าจอเรียกใช้
5. **Focus Screen เต็มรูปแบบ** — ผูก Conflict Resolution Engine เข้ากับ UI
   จริงแล้ว (ช่องว่างที่ค้างมาตั้งแต่รอบก่อน): เลือกเควสแบบ checklist,
   เควสที่ conflict ถูก disable พร้อม SnackBar บอกเหตุผลจาก
   `QuestConflictService`, timer คำนวณจาก `started_at + target_duration`
   ใน DB จริง (ไม่ใช่นับถอยหลังลอยๆ ในตัว widget) จึงตรงกันแม้ปิดแอปแล้วเปิดใหม่
6. **Onboarding บันทึก notification toggles จริง** — ช่องว่างที่ค้างมาจาก
   รอบก่อนก็ถูกปิดในรอบนี้เช่นกัน (เทียบค่า default กับที่ผู้ใช้เลือก
   แล้วสลับเฉพาะตัวที่ไม่ตรง เพราะ `SettingsNotifier` มีแต่ `toggleXxx()`)
7. **Rewards Screen แยกแท็บ** — "ซื้อของรางวัล" กับ "ประวัติการแลก" แทนที่
   จะโชว์แค่ลิสต์ของรางวัลอย่างเดียว
8. **Awarded EXP/Gold แยกจาก listed reward** — `database_helper.dart` เพิ่ม
   คอลัมน์ `awarded_exp`/`awarded_gold` แยกจาก `exp_reward`/`gold_reward`
   เดิม (ซึ่งเป็นแค่ค่าที่ตั้งไว้ตอนสร้างเควส) `completeQuest()` ตอนนี้รับ
   `awardedExp`/`awardedGold` เป็น required param และ
   `getTodayEarnedTotals()` เปลี่ยนไปนับจากคอลัมน์ใหม่นี้แทน — แก้บั๊กเดิม
   ที่ Daily Cap คำนวณจากค่า "ที่ตั้งไว้" ไม่ใช่ค่า "ที่ได้รับจริง"
9. **DB schema migration** — `dbVersion` เป็น 3 พร้อม `onUpgrade()` migrate
   คอลัมน์ใหม่ทั้งหมด (สำคัญ: ถ้ามี local dev DB จาก version เก่าอยู่แล้ว
   ในเครื่อง/emulator จะ migrate อัตโนมัติตอนเปิดแอปครั้งถัดไป ไม่ต้อง
   ล้างข้อมูลเอง)

## บั๊กที่เจอและแก้ในรอบนี้

**`fontFamily: 'PressStart2P'` กลับมาอีกรอบ** — เพราะไฟล์ถูกส่งมาใหม่ทั้งหมด
("เอาใหม่ทั้งหมด") การแก้ไขที่เคยทำไว้ในรอบก่อนหน้า (เปลี่ยนเป็น
`GoogleFonts.pressStart2p()`) เลยหายไปด้วย เจอซ้ำใน 4 ไฟล์เดิม:
`dashboard_screen.dart`, `focus_screen.dart`, `login_screen.dart`,
`level_up_overlay.dart` — แก้ซ้ำแบบเดิมอีกครั้ง (เพิ่ม import
`package:google_fonts/google_fonts.dart` แล้วเปลี่ยน
`TextStyle(fontFamily: ...)` เป็น `GoogleFonts.pressStart2p(...)`)

## จุดที่ตรวจสอบแล้วว่าถูกต้อง (ไม่มีบั๊ก แม้ดูน่าสงสัยตอนแรก)

- `quest_providers.dart` เรียก `db.completeQuest(questId, awardedExp:, awardedGold:)`
  ด้วย named param แบบ `required` — ตรวจแล้วว่า `database_helper.dart`
  เวอร์ชันที่ส่งมาอัปเดตให้รับพารามิเตอร์นี้แล้วจริง (ไม่ใช่แค่ฝั่ง provider
  อัปเดตอย่างเดียวแล้วฝั่ง DB ค้าง)
- `UserModel.toMap()` ส่ง `avatar_index` — ตรวจแล้วว่า schema `users` table
  มีคอลัมน์นี้จริง (ไม่งั้นจะ insert แล้ว SQLite error ตอน runtime ทันที)
- ไฟล์บางไฟล์ (`database_helper.dart`, `add_quest_screen.dart` ในการอัปโหลด
  ครั้งที่ 2 ของรอบนี้) ถูกอ้างถึงใน `uploaded_files` โดยไม่มีเนื้อหาแสดงในแชท
  — ไม่ได้ถือว่า "ไม่มีการเปลี่ยนแปลง" เฉยๆ แต่เปิดไฟล์จริงจาก path ที่
  อัปโหลดมาตรวจอีกที เจอว่าจริงๆ แล้วมีการอัปเดตเนื้อหาอยู่ (เพิ่ม sub-tasks
  UI, migration) — ใช้เนื้อหาจริงจากไฟล์ ไม่ใช่เดาว่าเหมือนเดิม

## ยังไม่รวมในรอบนี้ (ตาม scope ถัดไป)

- ยังไม่มี unit test ใดๆ ทั้งฝั่ง services และ providers
- `QuestModel` ยังไม่ expose `awardedExp`/`awardedGold` ที่เก็บแยกไว้แล้วใน
  DB — การ์ดเควสที่ทำสำเร็จแล้วในหน้า UI ปัจจุบันยังโชว์ `exp_reward`/
  `gold_reward` (ค่าที่ตั้งไว้ตอนสร้าง) ไม่ใช่ยอดที่ได้รับจริงหลัง Daily Cap
- Animation & RPG Polish Pass (Phase 10 เดิม) ยังไม่ได้ทำเพิ่มเติมจากที่มี
  อยู่แล้ว (fade+strikethrough ตอน complete, level-up overlay)
