import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/quest_model.dart';
import '../theme/app_colors.dart';

/// QuestProgressPath
/// แผนที่ด่านผจญภัยสไตล์เกมกระดาน RPG (Visualized Journey Progression)
/// แสดงเส้นทางคดเคี้ยวพร้อม Checkpoint Nodes ตามข้อกำหนด:
/// - ด่านที่ผ่านแล้ว: ไอคอนติ๊กถูกสีเขียว (Green Checkmark) พร้อมเส้นทางที่เดินผ่านแล้วเป็นสีเขียว
/// - ด่านปัจจุบัน: โหนดวงกลมไฮไลต์เด่น (Active Node) พร้อมแบดจ์ใบไม้ แสดงตำแหน่งผู้เล่น
/// - ด่านที่ยังล็อคอยู่: รูปแม่กุญแจ รอการปลดล็อก
/// - โหนดปลายทาง: Boss/Reward Node กล่องสมบัติประจำบท (พร้อมสถานะท้าทาย/เปิดสมบัติ)
class QuestProgressPath extends StatefulWidget {
  final List<QuestModel> quests;
  final int totalStages;
  final double height;
  final void Function(int stageIndex, String status)? onNodeTap;

  const QuestProgressPath({
    super.key,
    required this.quests,
    this.totalStages = 5,
    this.height = 160,
    this.onNodeTap,
  });

  @override
  State<QuestProgressPath> createState() => _QuestProgressPathState();
}

class _QuestProgressPathState extends State<QuestProgressPath>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  static const double nodeTopCenterY = 38.0;
  static const double nodeBottomCenterY = 108.0;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final completedCount = widget.quests.where((q) => q.isCompleted).length;
    final total = widget.totalStages;

    return SizedBox(
      height: widget.height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ── เส้นประเชื่อมโยงโหนด (Winding Connecting Trail) ──────────
          Positioned.fill(
            child: CustomPaint(
              painter: _PreciseWindingPathPainter(
                nodeCount: total,
                completedCount: completedCount,
                topY: nodeTopCenterY,
                bottomY: nodeBottomCenterY,
              ),
            ),
          ),

          // ── โหนดแต่ละด่าน (Checkpoint Nodes) ─────────────────────────
          Row(
            children: List.generate(total, (index) {
              final isPassed = index < completedCount;
              final isBoss = index == total - 1;
              final isBossActive = isBoss && completedCount == total - 1;
              final isBossPassed = completedCount >= total;
              final isActive = !isBoss && index == completedCount;
              final isEven = index.isEven;

              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    top: isEven ? 12.0 : 82.0,
                  ),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        _showNodeDetails(
                          context,
                          index: index,
                          isPassed: isPassed,
                          isActive: isActive,
                          isBoss: isBoss,
                          isBossActive: isBossActive,
                          isBossPassed: isBossPassed,
                        );
                      },
                      child: _buildCheckpointNode(
                        index: index,
                        isPassed: isPassed,
                        isActive: isActive,
                        isBoss: isBoss,
                        isBossActive: isBossActive,
                        isBossPassed: isBossPassed,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckpointNode({
    required int index,
    required bool isPassed,
    required bool isActive,
    required bool isBoss,
    required bool isBossActive,
    required bool isBossPassed,
  }) {
    if (isBoss) {
      // ── โหนดบอส / กล่องสมบัติประจำบท (Boss/Reward Node) ───────────────
      if (isBossActive) {
        // บอสกำลังท้าทาย (ผู้เล่นอยู่ที่ด่านบอส)
        return ScaleTransition(
          scale: _pulseAnimation,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFBBF24), Color(0xFFD97706)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF59E0B).withAlpha(180),
                          blurRadius: 14,
                          spreadRadius: 2,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.military_tech_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                  // แบดจ์ใบไม้แสดงตำแหน่งผู้เล่น
                  Positioned(
                    top: -6,
                    right: -6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF22C55E),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(60),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.eco_rounded,
                        color: Colors.white,
                        size: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFD97706), width: 1),
                ),
                child: const Text(
                  'ด่านบอส!',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFB45309),
                  ),
                ),
              ),
            ],
          ),
        );
      }

      // กล่องสมบัติ (เปิดแล้ว หรือ ล็อคอยู่)
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isBossPassed
                    ? [const Color(0xFFF59E0B), const Color(0xFFB45309)]
                    : [const Color(0xFFF1F5F9), const Color(0xFFE2E8F0)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              border: Border.all(
                color: isBossPassed ? const Color(0xFFF59E0B) : const Color(0xFFCBD5E1),
                width: isBossPassed ? 3.0 : 2.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: isBossPassed
                      ? const Color(0xFFF59E0B).withAlpha(140)
                      : Colors.transparent,
                  blurRadius: isBossPassed ? 10 : 0,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              isBossPassed ? Icons.card_giftcard_rounded : Icons.lock_outline_rounded,
              color: isBossPassed ? Colors.white : const Color(0xFF94A3B8),
              size: 24,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
            decoration: BoxDecoration(
              color: isBossPassed
                  ? const Color(0xFFFEF3C7)
                  : AppColors.cardSurface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isBossPassed ? const Color(0xFFB45309) : AppColors.border,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.star_rounded,
                  size: 10,
                  color: isBossPassed ? const Color(0xFFB45309) : AppColors.textMuted,
                ),
                const SizedBox(width: 2),
                Text(
                  isBossPassed ? 'สมบัติ!' : 'หีบบอส',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: isBossPassed ? const Color(0xFFB45309) : AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (isPassed) {
      // ── ด่านที่ผ่านแล้ว: ไอคอนติ๊กถูกสีเขียว (Green Checkmark) ───────────
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF15803D),
                width: 2.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF22C55E).withAlpha(90),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.check_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'ด่าน ${index + 1}',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Color(0xFF15803D),
            ),
          ),
        ],
      );
    }

    if (isActive) {
      // ── ด่านปัจจุบัน: ไฮไลต์เด่น (Active Node) พร้อมแบดจ์ใบไม้ (Leaf) ────
      return ScaleTransition(
        scale: _pulseAnimation,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF38BDF8), Color(0xFF0284C7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 2.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0284C7).withAlpha(140),
                        blurRadius: 10,
                        spreadRadius: 2,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.navigation_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
                // แบดจ์ใบไม้แสดงตำแหน่งผู้เล่น (Leaf Badge)
                Positioned(
                  top: -6,
                  right: -6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF22C55E),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(50),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.eco_rounded,
                      color: Colors.white,
                      size: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: const Color(0xFFE0F2FE),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF0284C7), width: 1),
              ),
              child: const Text(
                'ตำแหน่งคุณ',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0369A1),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // ── ด่านที่ยังล็อคอยู่: รูปแม่กุญแจ รอการปลดล็อก (Locked Node) ───────
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFFCBD5E1),
              width: 1.8,
            ),
          ),
          child: const Icon(
            Icons.lock_rounded,
            color: Color(0xFF94A3B8),
            size: 17,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'ด่าน ${index + 1}',
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Color(0xFF94A3B8),
          ),
        ),
      ],
    );
  }

  void _showNodeDetails(
    BuildContext context, {
    required int index,
    required bool isPassed,
    required bool isActive,
    required bool isBoss,
    required bool isBossActive,
    required bool isBossPassed,
  }) {
    String title;
    String desc;
    IconData icon;
    Color color;

    if (isBoss) {
      if (isBossPassed) {
        title = '👑 พิชิตบทที่ 1 สำเร็จแล้ว!';
        desc = 'ยินดีด้วย! คุณเคลียร์ครบ 5 ด่านในป่าแห่งความมุ่งมั่น และเปิดกล่องสมบัติแล้ว (+5 💎 เพชร, +100 🪙 ทอง)';
        icon = Icons.card_giftcard_rounded;
        color = const Color(0xFFD97706);
      } else if (isBossActive) {
        title = '⚔️ ด่านที่ 5 : บอสประจำบท (Boss Challenge)';
        desc = 'คุณมาถึงด่านสุดท้ายแล้ว! เคลียร์อีกเพียง 1 เควสต์เพื่อโค่นบอสและเปิดหีบสมบัติประจำบท (+5 💎 เพชร, +100 🪙 ทอง)!';
        icon = Icons.military_tech_rounded;
        color = const Color(0xFFD97706);
      } else {
        title = '🔒 หีบสมบัติบอสประจำบท (Chapter Boss)';
        desc = 'เคลียร์เควสต์ด่าน 1 ถึง 4 ให้สำเร็จก่อน เพื่อปลดล็อกเส้นทางมาท้าทายบอสและรับรางวัลใหญ่';
        icon = Icons.lock_rounded;
        color = const Color(0xFF64748B);
      }
    } else if (isPassed) {
      title = '✅ ด่านที่ ${index + 1} : ผ่านแล้ว (Cleared)';
      desc = 'คุณทำภารกิจด่านนี้สำเร็จแล้ว ได้รับ EXP และก้าวเดินมุ่งหน้าต่อไปเรียบร้อยแล้ว';
      icon = Icons.check_circle_rounded;
      color = const Color(0xFF16A34A);
    } else if (isActive) {
      title = '🌱 ด่านที่ ${index + 1} : ตำแหน่งปัจจุบันของคุณ';
      desc = 'ฮีโร่กำลังประจำอยู่ที่ด่านนี้! เลือกทำเควสต์ประจำวันถัดไปเพื่อก้าวเดินมุ่งหน้าสู่สมบัติ';
      icon = Icons.eco_rounded;
      color = const Color(0xFF0284C7);
    } else {
      title = '🔒 ด่านที่ ${index + 1} : ยังล็อคอยู่ (Locked)';
      desc = 'ทำด่านก่อนหน้านี้ให้สำเร็จก่อน เพื่อปลดล็อกเส้นทางผจญภัยต่อไป';
      icon = Icons.lock_rounded;
      color = const Color(0xFF64748B);
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(22),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withAlpha(25),
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 2),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              desc,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('เข้าใจแล้ว'),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

/// วาดเส้นเชื่อมโยง S-curve ที่แม่นยำ ผ่านจุดศูนย์กลางของแต่ละโหนดแบบ Pixel-Perfect
class _PreciseWindingPathPainter extends CustomPainter {
  final int nodeCount;
  final int completedCount;
  final double topY;
  final double bottomY;

  const _PreciseWindingPathPainter({
    required this.nodeCount,
    required this.completedCount,
    required this.topY,
    required this.bottomY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (nodeCount < 2) return;

    final stepWidth = size.width / nodeCount;

    // คำนวณพิกัดจุดศูนย์กลางของแต่ละโหนด (x, y)
    final centers = List<Offset>.generate(nodeCount, (i) {
      final cx = (i + 0.5) * stepWidth;
      final cy = (i % 2 == 0) ? topY : bottomY;
      return Offset(cx, cy);
    });

    // วาดเส้นเชื่อมทีละช่วง
    for (var i = 0; i < nodeCount - 1; i++) {
      final p0 = centers[i];
      final p1 = centers[i + 1];
      final dx = p1.dx - p0.dx;

      final segmentPath = Path();
      segmentPath.moveTo(p0.dx, p0.dy);
      // S-curve ที่ราบเรียบและมีความชันสมมาตร
      segmentPath.cubicTo(
        p0.dx + dx * 0.5,
        p0.dy,
        p0.dx + dx * 0.5,
        p1.dy,
        p1.dx,
        p1.dy,
      );

      // เส้นทางที่เดินผ่านแล้ว (cleared) เป็นสีเขียวเข้ม
      // เส้นทางที่ยังไม่ได้เดินเป็นเส้นประสีเทา/ฟ้าจาง
      final isClearedSegment = i < completedCount;

      final paint = Paint()
        ..color = isClearedSegment
            ? const Color(0xFF22C55E)
            : const Color(0xFFCBD5E1)
        ..strokeWidth = isClearedSegment ? 3.5 : 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      if (isClearedSegment) {
        // วาดเส้นทึบหรือประเขียว
        _drawDashedPath(canvas, segmentPath, paint, dashWidth: 7.0, dashSpace: 4.0);
      } else {
        // วาดเส้นประเทา
        _drawDashedPath(canvas, segmentPath, paint, dashWidth: 5.0, dashSpace: 5.0);
      }
    }
  }

  void _drawDashedPath(
    Canvas canvas,
    Path path,
    Paint paint, {
    required double dashWidth,
    required double dashSpace,
  }) {
    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      var distance = 0.0;
      var draw = true;
      while (distance < metric.length) {
        final len = draw ? dashWidth : dashSpace;
        final next = math.min(distance + len, metric.length);
        if (draw) {
          canvas.drawPath(metric.extractPath(distance, next), paint);
        }
        distance = next;
        draw = !draw;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PreciseWindingPathPainter oldDelegate) =>
      oldDelegate.nodeCount != nodeCount ||
      oldDelegate.completedCount != completedCount ||
      oldDelegate.topY != topY ||
      oldDelegate.bottomY != bottomY;
}
