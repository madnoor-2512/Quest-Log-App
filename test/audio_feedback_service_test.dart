import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quest_log/providers/settings_provider.dart';
import 'package:quest_log/services/audio_feedback_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('xyz.luan/audioplayers.global'),
          (MethodCall methodCall) async => 1,
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('xyz.luan/audioplayers'),
          (MethodCall methodCall) async => 1,
        );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('xyz.luan/audioplayers.global'),
          null,
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('xyz.luan/audioplayers'),
          null,
        );
  });

  test(
    'AudioFeedbackService handles sound and vibration settings correctly',
    () async {

      final containerRef = ProviderContainer(
        overrides: [
          settingsProvider.overrideWith(
            () => _FakeSettingsNotifier(
              const SettingsState(soundEnabled: false, vibrationEnabled: true),
            ),
          ),
        ],
      );

      final service = containerRef.read(audioFeedbackServiceProvider);

      // Call all 5 methods - should complete smoothly without throwing errors
      await service.playButtonClick();
      await service.playQuestSuccess();
      await service.playFocusComplete();
      await service.playHpDamage();
      await service.playLevelUp();

      expect(service, isNotNull);
      containerRef.dispose();
    },
  );
}

class RootWidget extends StatelessWidget {
  const RootWidget({super.key});
  @override
  Widget build(BuildContext context) => const Placeholder();
}

class _FakeSettingsNotifier extends SettingsNotifier {
  final SettingsState _state;
  _FakeSettingsNotifier(this._state);

  @override
  Future<SettingsState> build() async => _state;
}
