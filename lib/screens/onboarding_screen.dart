import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../providers/core_providers.dart';
import '../providers/settings_provider.dart';
import '../providers/user_provider.dart';
import '../theme/app_avatars.dart';
import '../theme/app_colors.dart';
import '../widgets/rpg_button.dart';
import 'dashboard_screen.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  final TextEditingController _nameController = TextEditingController(
    text: 'Hero',
  );
  int _currentPage = 0;
  int _selectedAvatar = 0;

  // หน้า 2: เป้าหมาย/หมวดหมู่เควสที่สนใจ — เลือกได้หลายข้อ (เก็บเป็น local
  // UI state เท่านั้น ยังไม่มีคอลัมน์ใน schema สำหรับ "ความสนใจ" โดยเฉพาะ
  // ใช้ปรับปรุง UX ตอน onboarding ก่อน ไม่ได้ persist ลง DB ในรอบนี้
  static const List<String> _interestOptions = [
    'ออกกำลังกาย / สุขภาพกาย',
    'งาน & โปรเจกต์สำคัญ',
    'การเรียนรู้ทักษะใหม่',
    'งานบ้าน & จัดระเบียบ',
    'สุขภาพจิต & สมาธิ',
    'งานอดิเรก & ความคิดสร้างสรรค์',
  ];
  final Set<int> _selectedInterests = {};

  bool _morningDigest = true;
  bool _focusWindow = true;
  bool _eveningRecap = true;

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _finishOnboarding() async {
    final name = _nameController.text.trim().isEmpty
        ? 'Hero'
        : _nameController.text.trim();

    final db = ref.read(databaseHelperProvider);
    final user = UserModel(
      name: name,
      level: 1,
      currentExp: 0,
      maxExp: 100,
      gold: 50,
      streakCount: 1,
      lastActiveDate: DateTime.now().toIso8601String().split('T')[0],
      avatarIndex: _selectedAvatar,
    );

    await db.insertUser(user);
    ref.invalidate(userProvider);

    // บันทึก toggle การแจ้งเตือนที่เลือกไว้หน้า 3 ลง settingsProvider จริง
    // (ก่อนหน้านี้เก็บแค่ local state ในหน้า onboarding แล้วทิ้งไปเฉยๆ)
    // SettingsNotifier มีแต่ method toggleXxx() ที่ "สลับค่าปัจจุบัน" ไม่มี
    // setXxx(bool) ตรงๆ จึงต้องเทียบค่า default กับค่าที่ผู้ใช้เลือกไว้
    // แล้วสลับเฉพาะตัวที่ไม่ตรงกัน
    final settingsNotifier = ref.read(settingsProvider.notifier);
    final currentSettings =
        ref.read(settingsProvider).valueOrNull ?? const SettingsState();
    if (currentSettings.morningDigest != _morningDigest) {
      await settingsNotifier.toggleMorningDigest();
    }
    if (currentSettings.focusWindow != _focusWindow) {
      await settingsNotifier.toggleFocusWindow();
    }
    if (currentSettings.eveningRecap != _eveningRecap) {
      await settingsNotifier.toggleEveningRecap();
    }

    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('ขั้นตอนที่ ${_currentPage + 1}/3'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: [
                  // Page 1: Name & Avatar
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'ตั้งชื่อฮีโร่ของคุณ',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'ชื่อนี้จะปรากฏในบันทึกภารกิจและการผจญภัย',
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                        const SizedBox(height: 28),
                        TextField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: 'ชื่อฮีโร่',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        const Text(
                          'เลือกอวาตาร์',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(heroAvatarIcons.length, (
                            index,
                          ) {
                            final isSelected = _selectedAvatar == index;
                            return GestureDetector(
                              onTap: () =>
                                  setState(() => _selectedAvatar = index),
                              child: Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                ),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.cardSurface,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.primaryDark
                                        : AppColors.border,
                                    width: 2.5,
                                  ),
                                ),
                                child: Icon(
                                  heroAvatarIcons[index],
                                  color: isSelected
                                      ? Colors.white
                                      : AppColors.textSecondary,
                                  size: 28,
                                ),
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                  ),

                  // Page 2: เลือกเป้าหมาย/หมวดหมู่เควสที่สนใจ (multi-select checklist)
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'เลือกเป้าหมายที่คุณสนใจ',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'เลือกได้หลายข้อ — ใช้ช่วยแนะนำเควสให้ตรงเป้าหมายคุณมากขึ้น',
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                        const SizedBox(height: 20),
                        Expanded(
                          child: ListView.separated(
                            itemCount: _interestOptions.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final isSelected = _selectedInterests.contains(
                                index,
                              );
                              return GestureDetector(
                                onTap: () => setState(() {
                                  if (isSelected) {
                                    _selectedInterests.remove(index);
                                  } else {
                                    _selectedInterests.add(index);
                                  }
                                }),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppColors.primaryLight
                                        : AppColors.cardSurface,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: isSelected
                                          ? AppColors.primary
                                          : AppColors.border,
                                      width: isSelected ? 2.5 : 2,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 24,
                                        height: 24,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: isSelected
                                              ? AppColors.primary
                                              : Colors.transparent,
                                          border: Border.all(
                                            color: isSelected
                                                ? AppColors.primary
                                                : AppColors.border,
                                            width: 2,
                                          ),
                                        ),
                                        child: isSelected
                                            ? const Icon(
                                                Icons.check_rounded,
                                                size: 16,
                                                color: Colors.white,
                                              )
                                            : null,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          _interestOptions[index],
                                          style: TextStyle(
                                            fontWeight: isSelected
                                                ? FontWeight.bold
                                                : FontWeight.w500,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Page 3: Notifications
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ระบบแจ้งเตือนกิลด์',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'เปิดรับข่าวสารและการเตือนภารกิจเพื่อให้ทำเป้าหมายสำเร็จ',
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                        const SizedBox(height: 24),
                        SwitchListTile(
                          value: _morningDigest,
                          title: const Text('Morning Digest (สรุปยามเช้า)'),
                          subtitle: const Text(
                            'รายงานเควสประจำวันที่ต้องทำในแต่ละวัน',
                          ),
                          onChanged: (v) => setState(() => _morningDigest = v),
                        ),
                        SwitchListTile(
                          value: _focusWindow,
                          title: const Text('Focus Window Reminder'),
                          subtitle: const Text(
                            'เตือนเมื่อถึงช่วงเวลาโฟกัสเข้มข้น',
                          ),
                          onChanged: (v) => setState(() => _focusWindow = v),
                        ),
                        SwitchListTile(
                          value: _eveningRecap,
                          title: const Text('Evening Recap (สรุปยามเย็น)'),
                          subtitle: const Text(
                            'สรุป EXP และ Gold ที่ได้รับตลอดวัน',
                          ),
                          onChanged: (v) => setState(() => _eveningRecap = v),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (index) {
                final isActive = _currentPage == index;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: isActive ? 22 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isActive ? AppColors.primary : AppColors.borderLight,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: RpgButton(
                text: _currentPage == 2 ? 'เริ่มผจญภัยเลย!' : 'ต่อไป',
                backgroundColor: AppColors.primary,
                borderColor: AppColors.primaryDark,
                onPressed: () {
                  if (_currentPage < 2) {
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  } else {
                    _finishOnboarding();
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

}
