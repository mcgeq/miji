import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:miji/features/gtd/domain/checkin_models.dart';

/// 计时器控制器 — 全局单例
class CheckinTimerController extends Notifier<CheckinTimerState> {
  Timer? _tickTimer;

  static const _keyPlanId = 'checkin_timer_plan_id';
  static const _keyPlanName = 'checkin_timer_plan_name';
  static const _keyStartedAt = 'checkin_timer_started_at';
  static const _keyPausedDuration = 'checkin_timer_paused_duration';
  static const _keyPausedAt = 'checkin_timer_paused_at';
  static const _keyIsPaused = 'checkin_timer_is_paused';

  @override
  CheckinTimerState build() {
    _loadPersistedState();
    return const CheckinTimerIdle();
  }

  void start(String planId, String planName) {
    _tickTimer?.cancel();
    final now = DateTime.now();
    final newState = CheckinTimerRunning(
      planId: planId,
      planName: planName,
      startedAt: now,
    );
    state = newState;
    _persistState(newState);
    _startTicking();
  }

  void pause() {
    final s = state;
    if (s is! CheckinTimerRunning) return;

    _tickTimer?.cancel();
    final now = DateTime.now();
    final elapsedSinceStart = now.difference(s.startedAt).inSeconds;
    final totalPaused = s.pausedDurationSeconds + elapsedSinceStart;

    state = CheckinTimerPaused(
      planId: s.planId,
      planName: s.planName,
      startedAt: s.startedAt,
      pausedDurationSeconds: totalPaused,
      pausedAt: now,
    );
    _persistState(state);
  }

  void resume() {
    final s = state;
    if (s is! CheckinTimerPaused) return;

    _tickTimer?.cancel();
    final pausedFor = DateTime.now().difference(s.pausedAt).inSeconds;

    final newState = CheckinTimerRunning(
      planId: s.planId,
      planName: s.planName,
      startedAt: s.startedAt,
      pausedDurationSeconds: s.pausedDurationSeconds + pausedFor,
    );
    state = newState;
    _persistState(newState);
    _startTicking();
  }

  int stop() {
    _tickTimer?.cancel();
    final now = DateTime.now();
    final s = state;

    if (s is CheckinTimerRunning) {
      final seconds =
          now.difference(s.startedAt).inSeconds - s.pausedDurationSeconds;
      state = const CheckinTimerIdle();
      _clearPersistedState();
      return seconds.clamp(0, 999999);
    }
    if (s is CheckinTimerPaused) {
      final seconds = s.pausedDurationSeconds;
      state = const CheckinTimerIdle();
      _clearPersistedState();
      return seconds.clamp(0, 999999);
    }

    return 0;
  }

  void _startTicking() {
    _tickTimer?.cancel();
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final s = state;
      if (s is CheckinTimerRunning) {
        state = CheckinTimerRunning(
          planId: s.planId,
          planName: s.planName,
          startedAt: s.startedAt,
          pausedDurationSeconds: s.pausedDurationSeconds,
        );
      }
    });
  }

  Future<void> _persistState(CheckinTimerState s) async {
    final prefs = await SharedPreferences.getInstance();
    if (s is CheckinTimerRunning) {
      await prefs.setString(_keyPlanId, s.planId);
      await prefs.setString(_keyPlanName, s.planName);
      await prefs.setInt(_keyStartedAt, s.startedAt.millisecondsSinceEpoch);
      await prefs.setInt(_keyPausedDuration, s.pausedDurationSeconds);
      await prefs.setBool(_keyIsPaused, false);
    } else if (s is CheckinTimerPaused) {
      await prefs.setString(_keyPlanId, s.planId);
      await prefs.setString(_keyPlanName, s.planName);
      await prefs.setInt(_keyStartedAt, s.startedAt.millisecondsSinceEpoch);
      await prefs.setInt(_keyPausedDuration, s.pausedDurationSeconds);
      await prefs.setInt(_keyPausedAt, s.pausedAt.millisecondsSinceEpoch);
      await prefs.setBool(_keyIsPaused, true);
    }
  }

  Future<void> _clearPersistedState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyPlanId);
    await prefs.remove(_keyPlanName);
    await prefs.remove(_keyStartedAt);
    await prefs.remove(_keyPausedDuration);
    await prefs.remove(_keyPausedAt);
    await prefs.remove(_keyIsPaused);
  }

  Future<void> _loadPersistedState() async {
    final prefs = await SharedPreferences.getInstance();
    final planId = prefs.getString(_keyPlanId);
    if (planId == null || planId.isEmpty) return;

    final planName = prefs.getString(_keyPlanName) ?? '';
    final startedAtMs = prefs.getInt(_keyStartedAt);
    final pausedDuration = prefs.getInt(_keyPausedDuration) ?? 0;
    final isPaused = prefs.getBool(_keyIsPaused) ?? false;

    if (startedAtMs == null) return;
    final startedAt = DateTime.fromMillisecondsSinceEpoch(startedAtMs);

    if (isPaused) {
      final pausedAtMs = prefs.getInt(_keyPausedAt);
      final pausedAt = pausedAtMs != null
          ? DateTime.fromMillisecondsSinceEpoch(pausedAtMs)
          : DateTime.now();
      state = CheckinTimerPaused(
        planId: planId,
        planName: planName,
        startedAt: startedAt,
        pausedDurationSeconds: pausedDuration,
        pausedAt: pausedAt,
      );
    } else {
      state = CheckinTimerRunning(
        planId: planId,
        planName: planName,
        startedAt: startedAt,
        pausedDurationSeconds: pausedDuration,
      );
      _startTicking();
    }
  }
}
