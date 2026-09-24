import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
// import '../providers/auth_provider.dart';
import '../providers/user_provider.dart';
import '../services/gamification_config.dart';
import '../theme/app_avatars.dart';
import '../theme/app_colors.dart';
import '../widgets/exp_bar.dart';
import '../widgets/rpg_button.dart';

/// Edit Profile ("จัดการโปรไฟล์ / Quest Profile") — แก้ไขชื่อ, username,
/// คติประจำใจ, อวาตาร์ และเลือกสาย RPG Class ผูกกับ
/// UserNotifier.updateProfile() อีเมลเป็น read-only ดึงจาก Supabase auth
/// โดยตรง (การเปลี่ยนอีเมลต้องผ่านขั้นตอนยืนยันตัวตนของ Supabase เอง
/// ไม่ใช่แค่แก้ field ธรรมดา จึงไม่เปิดให้แก้ตรงนี้)
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _usernameController;
  late final TextEditingController _mottoController;
  late int _selectedAvatar;
  RpgClassPath? _selectedClass;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final currentUser = ref.read(userProvider).valueOrNull;
    _nameController = TextEditingController(text: currentUser?.name ?? '');
    _usernameController = TextEditingController(
      text: currentUser?.username ?? '',
    );
    _mottoController = TextEditingController(text: currentUser?.motto ?? '');
    _selectedAvatar = currentUser?.avatarIndex ?? 0;
    _selectedClass = currentUser?.rpgClass;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _mottoController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    await ref
        .read(userProvider.notifier)
        .updateProfile(
          name: _nameController.text.trim(),
          avatarIndex: _selectedAvatar,
          username: _usernameController.text.trim().isEmpty
              ? null
              : _usernameController.text.trim(),
          motto: _mottoController.text.trim().isEmpty
              ? null
              : _mottoController.text.trim(),
          rpgClass: _selectedClass,
        );

    if (!mounted) return;
    setState(() => _isSaving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('บันทึกโปรไฟล์เรียบร้อยแล้ว'),
        backgroundColor: AppColors.primaryDark,
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider).valueOrNull;
    // final email = ref.watch(currentSupabaseUserProvider)?.email;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('จัดการโปรไฟล์'),
        actions: [
          if (user != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.local_fire_department_rounded,
                        size: 14,
                        color: AppColors.secondaryDark,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${user.streakDays} วัน',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.secondaryDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(user),
                const SizedBox(height: 24),

                _SectionCard(
                  title: 'ข้อมูลส่วนตัว (Personal Info)',
                  icon: Icons.person_outline_rounded,
                  children: [
                    _FieldLabel('ชื่อที่แสดง (Display Name)'),
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'กรุณาระบุชื่อ'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    _FieldLabel('ชื่อผู้ใช้ (Username)'),
                    TextFormField(
                      controller: _usernameController,
                      decoration: InputDecoration(
                        hintText: '@alex.pixelquest',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    _FieldLabel('อีเมล (Email)'),
                    TextFormField(
                      // initialValue: email ?? '-',
                      readOnly: true,
                      enabled: false,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: AppColors.surface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'แก้อีเมลได้จากขั้นตอนยืนยันตัวตนของระบบ login เท่านั้น',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 16),

                    _FieldLabel('คติประจำใจ (Quest Motto)'),
                    TextFormField(
                      controller: _mottoController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'ก้าวทีละก้าวอย่างตั้งใจ...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                const Text(
                  'เลือกอวาตาร์',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 12,
                    children: List.generate(heroAvatarIcons.length, (index) {
                      final isSelected = _selectedAvatar == index;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedAvatar = index),
                        child: Container(
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
                            size: 26,
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 24),

                _buildClassSection(),
                const SizedBox(height: 28),

                RpgButton(
                  text: 'บันทึกการเปลี่ยนแปลง',
                  backgroundColor: AppColors.primary,
                  borderColor: AppColors.primaryDark,
                  isLoading: _isSaving,
                  onPressed: _isSaving ? null : _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(UserModel? user) {
    return Column(
      children: [
        Container(
          width: 92,
          height: 92,
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          child: Icon(
            heroAvatarIcon(_selectedAvatar),
            size: 52,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _nameController.text.isEmpty
              ? (user?.name ?? 'ฮีโร่')
              : _nameController.text,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        if (_usernameController.text.isNotEmpty)
          Text(
            '@${_usernameController.text.replaceFirst('@', '')}',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        const SizedBox(height: 10),
        if (user != null) ...[
          Wrap(
            spacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _badge(
                _selectedClass != null
                    ? 'Lv.${user.level} ${_selectedClass!.classTitle}'
                    : 'Lv.${user.level}',
                AppColors.primary,
              ),
              if (_selectedClass != null)
                _badge(
                  '${_selectedClass!.shortLabel} • ${_selectedClass!.statLabel}',
                  AppColors.secondary,
                ),
            ],
          ),
          const SizedBox(height: 12),
          ExpBar(currentExp: user.currentExp, maxExp: user.maxExp),
        ],
      ],
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildClassSection() {
    return _SectionCard(
      title: 'สายพลังตัวละคร (RPG Class)',
      icon: Icons.auto_awesome_rounded,
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          'โบนัส EXP +${(GamificationConfig.rpgClassExpBonus * 100).round()}%',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryDark,
          ),
        ),
      ),
      children: [
        const Text(
          'เลือกได้สายเดียว ได้โบนัส EXP จริงทุกเควสที่ทำสำเร็จทันที เปลี่ยนสายทีหลังได้เสมอ',
          style: TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
        const SizedBox(height: 12),
        Row(
          children: RpgClassPath.values.map((path) {
            final isSelected = _selectedClass == path;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: GestureDetector(
                  onTap: () => setState(() => _selectedClass = path),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primaryLight
                          : AppColors.cardSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.borderLight,
                        width: isSelected ? 2.5 : 1.5,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          switch (path) {
                            RpgClassPath.strength =>
                              Icons.fitness_center_rounded,
                            RpgClassPath.intelligence =>
                              Icons.auto_stories_rounded,
                            RpgClassPath.dexterity => Icons.bolt_rounded,
                          },
                          color: isSelected
                              ? AppColors.primaryDark
                              : AppColors.textSecondary,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          path.shortLabel,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? AppColors.primaryDark
                                : AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          path.statLabel,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget? trailing;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              trailing ?? const SizedBox.shrink(),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}
