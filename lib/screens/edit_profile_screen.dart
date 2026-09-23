import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/user_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/rpg_button.dart';

/// Edit Profile — แก้ไขชื่อฮีโร่ ผูกกับ UserNotifier.updateProfile()
/// (method นี้ถูกสร้างไว้ตั้งแต่ round sync ก่อนหน้า แต่ยังไม่เคยมีหน้าจอ
/// เรียกใช้งานจริงมาก่อน)
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final currentName = ref.read(userProvider).valueOrNull?.name ?? '';
    _nameController = TextEditingController(text: currentName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    await ref
        .read(userProvider.notifier)
        .updateProfile(name: _nameController.text.trim());

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

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('แก้ไขโปรไฟล์'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 88,
                    height: 88,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person_rounded, size: 52, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 8),
                if (user != null)
                  Center(
                    child: Text(
                      'เลเวล ${user.level} • ${user.gold} Gold',
                      style: const TextStyle(color: AppColors.textMuted),
                    ),
                  ),
                const SizedBox(height: 28),

                const Text('ชื่อฮีโร่', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    hintText: 'เช่น Hero',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'กรุณาระบุชื่อฮีโร่' : null,
                ),
                const SizedBox(height: 28),

                RpgButton(
                  text: 'บันทึก',
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
}