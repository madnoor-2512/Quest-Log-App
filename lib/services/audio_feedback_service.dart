import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/settings_provider.dart';

final audioFeedbackServiceProvider = Provider<AudioFeedbackService>((ref) {
  final service = AudioFeedbackService(ref);
  ref.onDispose(service.dispose);
  return service;
});

/// บริการจัดการเสียงและแรงสั่นสะเทือน (Multisensory Feedback Service)
/// รองรับ Audio Ducking เพื่อไม่รบกวนเพลง/พอดแคสต์ และแยกการเปิดปิด Sound/Haptic อย่างอิสระ
class AudioFeedbackService {
  final Ref _ref;
  final AudioPlayer? _playerOverride;
  AudioPlayer? _internalPlayer;
  bool _isAudioConfigured = false;

  AudioFeedbackService(this._ref, {AudioPlayer? player})
    : _playerOverride = player;

  AudioPlayer? get _player {
    if (_playerOverride != null) return _playerOverride;
    if (_internalPlayer != null) return _internalPlayer;
    try {
      return _internalPlayer = AudioPlayer();
    } catch (_) {
      return null;
    }
  }

  void _initAudioContext() {
    try {
      AudioPlayer.global.setAudioContext(
        AudioContext(
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.ambient,
            options: const {
              AVAudioSessionOptions.duckOthers,
              AVAudioSessionOptions.mixWithOthers,
            },
          ),
          android: AudioContextAndroid(
            isSpeakerphoneOn: false,
            stayAwake: false,
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.game,
            audioFocus: AndroidAudioFocus.gainTransientMayDuck,
          ),
        ),
      );
      _isAudioConfigured = true;
    } catch (_) {
      // ป้องกันข้อผิดพลาดในสภาพแวดล้อมทดสอบหรือแพลตฟอร์มที่ไม่รองรับ
    }
  }

  bool get _soundEnabled {
    final settings = _ref.read(settingsProvider).valueOrNull;
    return settings?.soundEnabled ?? true;
  }

  bool get _vibrationEnabled {
    final settings = _ref.read(settingsProvider).valueOrNull;
    return settings?.vibrationEnabled ?? true;
  }

  Future<void> _playSound(String soundName) async {
    if (!_soundEnabled) return;
    try {
      final player = _player;
      if (player == null) return;
      if (!_isAudioConfigured) {
        _initAudioContext();
      }
      await player.stop();
      await player.play(AssetSource('sounds/$soundName'));
    } catch (_) {
      // Ignored gracefully
    }
  }

  /// 1. button_click.mp3: เสียงสัมผัสพื้นฐาน + Selection Click
  Future<void> playButtonClick() async {
    if (_vibrationEnabled) {
      unawaited(HapticFeedback.selectionClick());
    }
    await _playSound('button_click.mp3');
  }

  /// 2. quest_success.mp3: เสียงแห่งความมุ่งมั่นรายวัน + Medium Impact
  Future<void> playQuestSuccess() async {
    if (_vibrationEnabled) {
      unawaited(HapticFeedback.mediumImpact());
    }
    await _playSound('quest_success.mp3');
  }

  /// 3. focus_complete.mp3: เสียงแห่งชัยชนะทางสมาธิ + Double Impact
  Future<void> playFocusComplete() async {
    final haptic = _vibrationEnabled
        ? () async {
            await HapticFeedback.mediumImpact();
            await Future<void>.delayed(const Duration(milliseconds: 140));
            await HapticFeedback.mediumImpact();
          }()
        : Future<void>.value();
    await Future.wait([_playSound('focus_complete.mp3'), haptic]);
  }

  /// 4. hp_damage.mp3: เสียงแห่งบทลงโทษ + Heavy Impact
  Future<void> playHpDamage() async {
    final haptic = _vibrationEnabled
        ? HapticFeedback.heavyImpact()
        : Future<void>.value();
    await Future.wait([_playSound('hp_damage.mp3'), haptic]);
  }

  /// 5. level_up.mp3: เสียงแห่งการเฉลิมฉลอง + 3-Stage Rhythm (Light -> Light -> Heavy)
  Future<void> playLevelUp() async {
    final haptic = _vibrationEnabled
        ? () async {
            await HapticFeedback.lightImpact();
            await Future<void>.delayed(const Duration(milliseconds: 140));
            await HapticFeedback.lightImpact();
            await Future<void>.delayed(const Duration(milliseconds: 180));
            await HapticFeedback.heavyImpact();
          }()
        : Future<void>.value();
    await Future.wait([_playSound('level_up.mp3'), haptic]);
  }

  void dispose() {
    _internalPlayer?.dispose();
  }
}
