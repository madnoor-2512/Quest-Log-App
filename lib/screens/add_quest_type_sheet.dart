import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'add_focus_quest_screen.dart';
import 'add_quick_quest_screen.dart';

/// เปิดป๊อปอัปเมนู (Action Sheet) ให้เลือกประเภทภารกิจที่จะสร้าง —
/// "เควสต์ทันใจ" (เช็กอิน/ทำเสร็จทันที) หรือ "เควสต์โฟกัส" (ต้องใช้เวลา
/// และสมาธิ) เรียกจากปุ่ม (+) กลางแถบเมนูด้านล่างของ DashboardScreen
/// เลือกแล้วจะ push ไปหน้าสร้างเควสต์ของประเภทนั้นทับขึ้นมาแทนที่จะสลับ
/// แท็บ เพราะการสร้างเควสต์เป็น "การกระทำ" ไม่ใช่หน้าจอที่ควรค้างอยู่ใน
/// bottom navigation
Future<void> showAddQuestTypeSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) {
      return SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          decoration: BoxDecoration(
            color: AppColors.cardSurface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderLight,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'เลือกประเภทภารกิจผจญภัย',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'เลือกแนวทางเควสต์เพื่อบันทึกการเติบโตและสะสม EXP',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              const SizedBox(height: 18),
              _QuestTypeOption(
                icon: Icons.bolt_rounded,
                iconColor: AppColors.primary,
                title: 'เควสต์ทันใจ',
                titleEn: '(Quick Quest)',
                subtitle: 'สำหรับภารกิจเช็กอินสั้นๆ',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AddQuickQuestScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              _QuestTypeOption(
                icon: Icons.hourglass_top_rounded,
                iconColor: AppColors.goldRewardDark,
                title: 'เควสต์โฟกัส',
                titleEn: '(Focus Quest)',
                subtitle: 'สำหรับภารกิจที่ต้องใช้เวลา',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AddFocusQuestScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(
                      color: AppColors.borderLight,
                      width: 1.5,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const Text(
                    'ยกเลิก (ปิดหน้าต่าง)',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _QuestTypeOption extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String titleEn;
  final String subtitle;
  final VoidCallback onTap;

  const _QuestTypeOption({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.titleEn,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderLight, width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconColor.withAlpha(35),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        titleEn,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}
