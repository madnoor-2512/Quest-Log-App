import 'package:flutter_test/flutter_test.dart';
import 'package:quest_log/models/user_model.dart';

void main() {
  test('profile image data round-trips through user persistence', () {
    const user = UserModel(
      id: 1,
      name: 'Hero',
      avatarIndex: 2,
      avatarImageBase64: 'encoded-avatar-bytes',
    );

    final restored = UserModel.fromMap(user.toMap());

    expect(restored.avatarImageBase64, 'encoded-avatar-bytes');
    expect(restored.avatarIndex, 2);
  });

  test(
    'profile image can be explicitly cleared while retaining icon avatar',
    () {
      const user = UserModel(
        name: 'Hero',
        avatarIndex: 3,
        avatarImageBase64: 'encoded-avatar-bytes',
      );

      final withoutPhoto = user.copyWith(clearAvatarImage: true);

      expect(withoutPhoto.avatarImageBase64, isNull);
      expect(withoutPhoto.avatarIndex, 3);
    },
  );
}
