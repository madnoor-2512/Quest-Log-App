import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/quest_model.dart';
import '../theme/app_colors.dart';

/// QuestProgressPath
/// เส้นทางคดเคี้ยวแบบ RPG (เหมือนแผนที่ level ในเกม) แสดงเควสที่ส่งเข้ามา
/// เรียงเป็น node สลับบน-ล่าง เชื่อมด้วยเส้นประหยักโค้งไปตามความกว้างจอ
///
/// สีของ node บ่งบอกสถานะ: เขียว (Primary) = ทำสำเร็จแล้ว,
/// ส้ม (Secondary) = ยังไม่ทำ — ตรงตาม mockup "node สีเขียว/ส้มบอกสถานะ"
///
/// เป็น presentational widget ล้วนๆ — parent screen เป็นคนดึง quest list
/// จาก provider แล้วส่งเข้ามา (ไม่ผูกกับ Riverpod โดยตรงในไฟล์นี้)
class QuestProgressPath extends StatelessWidget {
  final List<QuestModel> quests;
  final double height;

  const QuestProgressPath({
    super.key,
    required this.quests,
    this.height = 150,
  });

  @override
  Widget build(BuildContext context) {
    if (quests.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            'ยังไม่มีเควสวันนี้ — กดแท็บ "เพิ่มเควส" เพื่อเริ่มการผจญภัย',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ),
      );
    }

    return SizedBox(
      height: height,
      child: Stack(
        children: [
          // เส้นทางหยักด้านหลัง node ทั้งหมด
          Positioned.fill(
            child: CustomPaint(
              painter: _WindingPathPainter(
                nodeCount: quests.length,
                color: AppColors.border.withValues(alpha: 0.35),
              ),
            ),
          ),
          Row(
            children: List.generate(quests.length, (index) {
              final quest = quests[index];
              final isEven = index.isEven;
              return Expanded(
                child: Align(
                  alignment: isEven
                      ? Alignment.topCenter
                      : Alignment.bottomCenter,
                  child: Padding(
                    padding: EdgeInsets.only(
                      top: isEven ? 10 : 0,
                      bottom: isEven ? 0 : 10,
                    ),
                    child: _PathNode(quest: quest),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _PathNode extends StatelessWidget {
  final QuestModel quest;

  const _PathNode({required this.quest});

  @override
  Widget build(BuildContext context) {
    final isDone = quest.isCompleted;
    final color = isDone ? AppColors.primary : AppColors.secondary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: isDone ? AppColors.primaryDark : AppColors.secondaryDark,
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.4),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(
            isDone ? Icons.check_rounded : Icons.flag_rounded,
            color: Colors.white,
            size: 24,
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 64,
          child: Text(
            quest.title,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

/// วาดเส้นทางหยักแบบ sine wave พาดผ่านความกว้างทั้งหมด ให้ความรู้สึก
/// "เส้นทางคดเคี้ยว" แบบแผนที่ level ในเกม RPG (ไม่ได้ต่อจุดศูนย์กลาง node
/// แบบ pixel-perfect เพราะไม่รู้ตำแหน่ง node จริงตอน paint — ใช้ wave
/// ที่มีจำนวนลอนเท่ากับช่วงระหว่าง node แทน ให้ภาพรวมคดเคี้ยวตรงกัน)
class _WindingPathPainter extends CustomPainter {
  final int nodeCount;
  final Color color;

  const _WindingPathPainter({required this.nodeCount, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (nodeCount < 2) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final midY = size.height / 2;
    final amplitude = size.height * 0.22;
    final segments = nodeCount - 1;

    path.moveTo(0, midY);
    for (var i = 0; i <= segments * 20; i++) {
      final t = i / (segments * 20);
      final x = t * size.width;
      final y = midY + amplitude * math.sin(t * segments * math.pi);
      path.lineTo(x, y);
    }

    // วาดเป็นเส้นประ (dash) ด้วยการตัด path เป็นช่วงสั้นๆ
    const dashWidth = 6.0;
    const dashSpace = 5.0;
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
  bool shouldRepaint(covariant _WindingPathPainter oldDelegate) =>
      oldDelegate.nodeCount != nodeCount || oldDelegate.color != color;
}
