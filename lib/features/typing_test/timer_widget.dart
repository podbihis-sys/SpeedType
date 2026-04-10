library timer_widget;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Timer mode for a typing test session.
enum TimerMode {
  /// Counts down from [TestTimerController.duration] to zero.
  countdown,

  /// Counts up indefinitely – used for untimed / words-based tests.
  countup,

  /// Word-count mode. Timer counts up but display is hidden; the
  /// session is ended externally by the typing engine.
  wordCount,
}

/// Headless controller that drives the timer state.
///
/// Exposes tick-by-tick updates via [ChangeNotifier] so multiple
/// widgets (progress bar, numeric display, haptics) can react.
class TestTimerController extends ChangeNotifier {
  TestTimerController({
    required this.mode,
    this.duration = const Duration(seconds: 30),
    this.onComplete,
  });

  final TimerMode mode;
  final Duration duration;
  final VoidCallback? onComplete;

  Duration _elapsed = Duration.zero;
  Timer? _timer;
  bool _isRunning = false;
  bool _isComplete = false;

  Duration get elapsed => _elapsed;
  bool get isRunning => _isRunning;
  bool get isComplete => _isComplete;

  /// Seconds remaining in countdown mode (0 otherwise).
  int get remainingSeconds {
    if (mode != TimerMode.countdown) return 0;
    final remaining = duration - _elapsed;
    if (remaining.isNegative) return 0;
    return remaining.inSeconds;
  }

  /// Elapsed seconds – useful for count-up display.
  int get elapsedSeconds => _elapsed.inSeconds;

  /// 0.0-1.0 progress. In countdown mode this is elapsed/duration, in
  /// count-up mode it loops every 60 seconds for a subtle indicator.
  double get progressPercent {
    if (mode == TimerMode.countdown) {
      if (duration.inMilliseconds <= 0) return 0.0;
      final p = _elapsed.inMilliseconds / duration.inMilliseconds;
      return p.clamp(0.0, 1.0);
    }
    final loopMs = 60 * 1000;
    return (_elapsed.inMilliseconds % loopMs) / loopMs;
  }

  /// Start the timer from zero.
  void start() {
    if (_isRunning) return;
    _isRunning = true;
    _isComplete = false;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 100), _onTick);
    notifyListeners();
  }

  /// Pause the underlying Timer without resetting elapsed time.
  void pause() {
    if (!_isRunning) return;
    _isRunning = false;
    _timer?.cancel();
    _timer = null;
    notifyListeners();
  }

  /// Resume a paused timer.
  void resume() {
    if (_isRunning || _isComplete) return;
    _isRunning = true;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 100), _onTick);
    notifyListeners();
  }

  /// Stop and reset. Does *not* fire [onComplete].
  void reset() {
    _timer?.cancel();
    _timer = null;
    _isRunning = false;
    _isComplete = false;
    _elapsed = Duration.zero;
    notifyListeners();
  }

  void _onTick(Timer timer) {
    _elapsed += const Duration(milliseconds: 100);

    if (mode == TimerMode.countdown && _elapsed >= duration) {
      _elapsed = duration;
      _complete();
      return;
    }
    notifyListeners();
  }

  void _complete() {
    _isRunning = false;
    _isComplete = true;
    _timer?.cancel();
    _timer = null;
    HapticFeedback.heavyImpact();
    notifyListeners();
    onComplete?.call();
  }

  /// Externally mark the timer as complete (e.g. when the typing
  /// engine finishes the target text in word-count mode).
  void completeExternally() {
    if (_isComplete) return;
    _complete();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }
}

/// Visual representation of a [TestTimerController].
///
/// * Countdown mode: giant 48px number that turns red under 5 seconds.
/// * Count-up mode: small elapsed counter.
/// * Word-count mode: hidden (just a progress bar).
class TimerWidget extends StatelessWidget {
  const TimerWidget({
    super.key,
    required this.controller,
    this.showProgressBar = true,
    this.primaryColor = const Color(0xFF38BDF8),
    this.warningColor = const Color(0xFFEF4444),
  });

  final TestTimerController controller;
  final bool showProgressBar;
  final Color primaryColor;
  final Color warningColor;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final mode = controller.mode;

        Widget display;
        if (mode == TimerMode.countdown) {
          final secs = controller.remainingSeconds;
          final isWarning = secs <= 5 && secs > 0;
          display = Text(
            _formatSeconds(secs),
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: isWarning ? warningColor : primaryColor,
            ),
          );
        } else if (mode == TimerMode.countup) {
          display = Text(
            _formatSeconds(controller.elapsedSeconds),
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: primaryColor,
            ),
          );
        } else {
          // wordCount – hide the numeric display entirely.
          display = const SizedBox.shrink();
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: display),
            if (showProgressBar) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: mode == TimerMode.countdown
                      ? 1.0 - controller.progressPercent
                      : controller.progressPercent,
                  minHeight: 6,
                  backgroundColor: const Color(0xFF1E293B),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _progressColor(controller, primaryColor, warningColor),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  static Color _progressColor(
    TestTimerController c,
    Color primary,
    Color warning,
  ) {
    if (c.mode == TimerMode.countdown && c.remainingSeconds <= 5) {
      return warning;
    }
    return primary;
  }

  static String _formatSeconds(int seconds) {
    if (seconds >= 60) {
      final m = seconds ~/ 60;
      final s = seconds % 60;
      return '$m:${s.toString().padLeft(2, '0')}';
    }
    return seconds.toString();
  }
}
