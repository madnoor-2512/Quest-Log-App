import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class TutorialsScreen extends StatelessWidget {
  const TutorialsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('คู่มือการเล่น (Tutorials)')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: const [
            _TutorialSection(
              icon: Icons.assignment_rounded,
              color: AppColors.primary,
              title: 'เควส (Quests)',
              body:
                  'สร้างเควสได้ 3 หมวด: Main (เป้าหมายใหญ่), Side (งานทั่วไป), '
                  'Daily (นิสัยประจำวัน) ตั้งความยากและเวลาที่ใช้ ระบบจะคำนวณ '
                  'EXP/Gold ให้อัตโนมัติ — ยิ่งยาก ยิ่งใช้เวลานาน ยิ่งได้รางวัลเยอะ',
            ),
            _TutorialSection(
              icon: Icons.timer_rounded,
              color: AppColors.secondary,
              title: 'โฟกัส (Focus Session)',
              body:
                  'เลือกหลายเควสมาทำพร้อมกันในเซสชันเดียวได้ แต่ระบบจะกันเควส '
                  'ที่กิจกรรมขัดแย้งกัน (เช่น ออกกำลังกายหนัก + นั่งสมาธิ) '
                  'ไม่ให้เลือกพร้อมกัน',
            ),
            _TutorialSection(
              icon: Icons.local_fire_department_rounded,
              color: AppColors.streakFlame,
              title: 'Streak',
              body:
                  'ทำเควสสำเร็จอย่างน้อย 1 อันทุกวันติดต่อกัน เพื่อสะสม Streak '
                  '— ยิ่ง Streak สูง ยิ่งได้โบนัส EXP/Gold เพิ่ม (สูงสุด +100%) '
                  'แต่ถ้าขาดวันใดวันหนึ่ง Streak จะรีเซ็ตกลับเป็น 1',
            ),
            _TutorialSection(
              icon: Icons.school_rounded,
              color: Color(0xFF7C3AED),
              title: 'สาย RPG Class',
              body:
                  'เลือกสายตัวละคร (STR / INT / DEX) ได้ที่หน้าโปรไฟล์ '
                  'จะได้โบนัส EXP +15% ทุกเควสที่ทำสำเร็จทันที เลือกได้สายเดียว '
                  'แต่เปลี่ยนใหม่ทีหลังได้เสมอ',
            ),
            _TutorialSection(
              icon: Icons.storefront_rounded,
              color: AppColors.goldRewardDark,
              title: 'ร้านค้าและคลังไอเทม',
              body:
                  'ใช้ Gold แลกของรางวัลที่ร้านค้า ของที่แลกจะเข้าคลังไอเทมทันที '
                  '— อุปกรณ์ (equipment) จะถูกสวมใส่อัตโนมัติและให้ผลจริง '
                  '(เช่น เพิ่มเวลาโฟกัส) ส่วนของใช้แล้วหมด (consumable) '
                  'กดใช้ได้ทีละชิ้นเมื่อต้องการ',
            ),
            _TutorialSection(
              icon: Icons.emoji_events_rounded,
              color: AppColors.levelGold,
              title: 'ความสำเร็จ (Achievements)',
              body:
                  'ปลดล็อกอัตโนมัติเมื่อทำเงื่อนไขสำเร็จ เช่น ทำเควสครบ 10 อัน '
                  'หรือ Streak ครบ 7 วัน ดูรายการทั้งหมดได้จากเมนูแฮมเบอร์เกอร์',
            ),
          ],
        ),
      ),
    );
  }
}

class _TutorialSection extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String body;

  const _TutorialSection({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withAlpha(35),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
