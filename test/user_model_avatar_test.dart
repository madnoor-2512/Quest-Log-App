import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quest_log/models/user_model.dart';
import 'package:quest_log/widgets/profile_avatar.dart';

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

  testWidgets('invalid saved image displays the selected fallback avatar', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ProfileAvatar(
            avatarIndex: 0,
            imageBase64: 'bm90IGFuIGltYWdl',
            size: 72,
            iconSize: 38,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.person_rounded), findsOneWidget);
  });

  testWidgets('image provider is reused when avatar rebuilds', (
    WidgetTester tester,
  ) async {
    late StateSetter rebuild;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return ProfileAvatar(
                avatarIndex: 0,
                imageBase64: 'AQID',
                size: 72,
                iconSize: 38,
              );
            },
          ),
        ),
      ),
    );

    final firstProvider = tester.widget<Image>(find.byType(Image)).image;
    rebuild(() {});
    await tester.pump();
    final secondProvider = tester.widget<Image>(find.byType(Image)).image;

    expect(identical(firstProvider, secondProvider), isTrue);
  });
}
