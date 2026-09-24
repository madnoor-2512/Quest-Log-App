import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/focus_session_model.dart';
import '../models/quest_model.dart';
import '../providers/core_providers.dart';
import '../providers/focus_providers.dart';
import '../providers/quest_providers.dart';
import '../providers/settings_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/quest_card.dart';
import '../widgets/rpg_button.dart';

/// Focus Screen — สองสถานะ:
/// 1) ไม่มี active session -> เลือกเควสที่จะทำพร้อมกัน (conflict-aware)
/// 2) มี active session (จาก activeFocusSessionProvider ซึ่งอ่านจาก DB จริง)
///    -> วงกลม timer + ลิสต์เควสในเซสชัน ที่ complete ได้ทีละอัน
class FocusScreen extends ConsumerStatefulWidget {
  const FocusScreen({super.key});

  @override
  ConsumerState<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends ConsumerState<FocusScreen> {
  Timer? _timer;
  int? _trackedSessionId;
  int _totalSeconds = 0;
  int _secondsRemaining = 0;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // -------------------------------------------------------------------
  // Timer — คำนวณเวลาที่เหลือจาก started_at + target_duration ของ session
  // จริงใน DB (ไม่ใช่นับถอยหลังลอยๆ ในตัว widget) เพื่อให้ตรงกันแม้แอป
  // ถูก mount ใหม่ระหว่างเซสชันกำลังทำงานอยู่
  // -------------------------------------------------------------------
  void _syncTicker(FocusSessionModel? session) {
    if (session == null) {
      _timer?.cancel();
      _timer = null;
      _trackedSessionId = null;
      return;
    }
    if (_trackedSessionId == session.id && _timer != null) return;
    _trackedSessionId = session.id;
    _startLocalTicker(session);
  }

  void _startLocalTicker(FocusSessionModel session) {
    final startedAt = DateTime.parse(session.startedAt);
    _totalSeconds = session.targetDuration;

    void tick() {
      final elapsed = DateTime.now().difference(startedAt).inSeconds;
      final remaining = (_totalSeconds - elapsed).clamp(0, _totalSeconds);
      if (mounted) setState(() => _secondsRemaining = remaining);
    }

    tick();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  String _formatTime(int sec) {
    final m = (sec ~/ 60).toString().padLeft(2, '0');
    final s = (sec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // -------------------------------------------------------------------
  // Actions
  // -------------------------------------------------------------------
  Future<void> _startSession(int minutes) async {
    await ref
        .read(activeFocusSessionProvider.notifier)
        .start(targetDurationSeconds: minutes * 60);
  }

  Future<void> _endSession() async {
    _timer?.cancel();
    _timer = null;
    _trackedSessionId = null;
    await ref.read(activeFocusSessionProvider.notifier).end();
  }

  void _onQuestTap(
    QuestModel quest,
    List<QuestModel> selected,
    bool isDisabled,
  ) {
    if (isDisabled) {
      final conflictService = ref.read(questConflictServiceProvider);
      final result = conflictService.canAddToSelection(selected, quest);
      showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(
            Icons.block_rounded,
            color: AppColors.error,
            size: 32,
          ),
          title: const Text('เลือกเควสนี้พร้อมกันไม่ได้'),
          content: Text(
            result.reason ?? 'เควสนี้ทำพร้อมกับเควสที่เลือกไว้แล้วไม่ได้',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('เข้าใจแล้ว'),
            ),
          ],
        ),
      );
      return;
    }
    ref.read(focusSelectionProvider.notifier).toggle(quest);
  }

  Future<void> _completeSessionQuest(QuestModel quest) async {
    final result = await ref
        .read(questActionsProvider.notifier)
        .completeQuest(quest.id!);
    final settings = ref.read(settingsProvider).valueOrNull;
    if (settings?.soundEnabled ?? true) {
      await SystemSound.play(SystemSoundType.click);
    }
    if (settings?.vibrationEnabled ?? true) {
      await HapticFeedback.mediumImpact();
    }
    // activeSessionQuestsProvider ไม่ได้ผูกกับ questListProvider ที่ถูก
    // invalidate อัตโนมัติใน completeQuest() จึงต้อง invalidate เองตรงนี้
    ref.invalidate(activeSessionQuestsProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'สำเร็จเควส "${quest.title}"! ได้รับ +${result.exp} EXP, +${result.gold} Gold'
          '${result.wasCapped ? ' (ถึงเพดานรายวันแล้ว)' : ''}',
        ),
        backgroundColor: AppColors.primaryDark,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // -------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(activeFocusSessionProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: sessionAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => Center(child: Text('ข้อผิดพลาด: $e')),
          data: (session) {
            _syncTicker(session);
            return session != null
                ? _buildActiveSession(session)
                : _buildSelectionScreen();
          },
        ),
      ),
    );
  }

  // --- Screen 1: เลือกเควสก่อนเริ่ม (conflict-aware) ---------------------
  Widget _buildSelectionScreen() {
    final selected = ref.watch(focusSelectionProvider);
    final questsAsync = ref.watch(questListProvider(QuestFilter.incomplete));

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'เลือกเควสสำหรับเซสชันโฟกัส',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'เลือกได้หลายเควส — ระบบจะกันเควสที่ทำพร้อมกันไม่ได้ให้อัตโนมัติ',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: questsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('ข้อผิดพลาด: $e')),
              data: (quests) {
                if (quests.isEmpty) {
                  return const Center(
                    child: Text(
                      'ไม่มีเควสที่เปิดอยู่ ให้เพิ่มเควสในหน้าแรกก่อน',
                    ),
                  );
                }
                final blocked = ref.watch(blockedQuestIdsProvider(quests));
                return ListView.builder(
                  itemCount: quests.length,
                  itemBuilder: (context, index) {
                    final q = quests[index];
                    final isSelected = selected.any((sq) => sq.id == q.id);
                    final isDisabled = !isSelected && blocked.contains(q.id);
                    return GestureDetector(
                      onTap: () => _onQuestTap(q, selected, isDisabled),
                      child: QuestCard(
                        quest: q,
                        checklistMode: true,
                        isSelected: isSelected,
                        isDisabled: isDisabled,
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Builder(
            builder: (context) {
              // จับเวลาตามเควสที่เลือกจริง (รวม estimated_minutes ของทุกเควส
              // ที่เลือกไว้) แทนที่จะให้ผู้ใช้เลือก preset 25/50 นาทีเอง —
              // ถ้าเควสที่เลือกไม่มีเวลาระบุไว้เลย (estimated_minutes รวม
              // เป็น 0) ใช้ 5 นาทีเป็นขั้นต่ำกันไม่ให้ session เริ่มด้วย
              // เวลา 0 วินาที
              final totalMinutes = selected.fold<int>(
                0,
                (sum, q) => sum + q.estimatedMinutes,
              );
              final effectiveMinutes = totalMinutes > 0 ? totalMinutes : 5;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selected.isEmpty
                        ? 'ยังไม่ได้เลือกเควส'
                        : 'เลือกแล้ว ${selected.length} เควส • '
                              'รวมเวลาโฟกัส $effectiveMinutes นาที'
                              '${totalMinutes == 0 ? ' (ค่าเริ่มต้น)' : ''}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  RpgButton(
                    text: 'Start Focus',
                    backgroundColor: AppColors.primary,
                    borderColor: AppColors.primaryDark,
                    width: double.infinity,
                    onPressed: selected.isEmpty
                        ? null
                        : () => _startSession(effectiveMinutes),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // --- Screen 2: active session -----------------------------------------
  Widget _buildActiveSession(FocusSessionModel session) {
    final questsAsync = ref.watch(activeSessionQuestsProvider);
    final timeUp = _totalSeconds > 0 && _secondsRemaining <= 0;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 220,
                  height: 220,
                  child: CircularProgressIndicator(
                    value: _totalSeconds > 0
                        ? _secondsRemaining / _totalSeconds
                        : 0,
                    strokeWidth: 12,
                    backgroundColor: AppColors.border,
                    color: AppColors.secondary,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatTime(_secondsRemaining),
                      style: GoogleFonts.pressStart2p(
                        fontSize: 24,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      timeUp
                          ? 'หมดเวลาแล้ว! กดจบเซสชันได้เลย'
                          : 'กำลังโฟกัส...',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          RpgButton(
            text: 'จบเซสชัน',
            backgroundColor: AppColors.error,
            borderColor: AppColors.primaryDark,
            onPressed: _endSession,
          ),
          const SizedBox(height: 20),
          const Divider(color: AppColors.border),
          const SizedBox(height: 8),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'เควสในเซสชันนี้:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: questsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('ข้อผิดพลาด: $e')),
              data: (quests) {
                if (quests.isEmpty) {
                  return const Center(child: Text('ไม่มีเควสในเซสชันนี้'));
                }
                return ListView.builder(
                  itemCount: quests.length,
                  itemBuilder: (context, index) {
                    final q = quests[index];
                    return QuestCard(
                      quest: q,
                      onComplete: q.isCompleted
                          ? null
                          : () => _completeSessionQuest(q),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
