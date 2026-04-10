library typing_test_screen;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/constants.dart';
import '../../data/local/local_text_service.dart';
import '../../models/test_result.dart';
import 'result_screen.dart';
import 'text_highlighter.dart';
import 'typing_engine.dart';

/// Controller that counts down (or up) the timer of a typing test session.
class TestTimerController extends ChangeNotifier {
  TestTimerController({required this.totalSeconds})
      : _remaining = totalSeconds;

  final int totalSeconds;
  Timer? _timer;
  int _remaining;
  bool _running = false;

  int get remaining => _remaining;
  int get elapsed => totalSeconds - _remaining;
  bool get isRunning => _running;
  bool get isFinished => _remaining <= 0;
  double get progress =>
      totalSeconds == 0 ? 0.0 : (elapsed / totalSeconds).clamp(0.0, 1.0);

  void start() {
    if (_running || isFinished) return;
    _running = true;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _remaining--;
      if (_remaining <= 0) {
        _remaining = 0;
        stop();
      }
      notifyListeners();
    });
    notifyListeners();
  }

  void stop() {
    _running = false;
    _timer?.cancel();
    _timer = null;
    notifyListeners();
  }

  void reset() {
    stop();
    _remaining = totalSeconds;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

class TypingTestScreen extends StatefulWidget {
  const TypingTestScreen({super.key});

  @override
  State<TypingTestScreen> createState() => _TypingTestScreenState();
}

class _TypingTestScreenState extends State<TypingTestScreen> {
  static const _duration = 30;

  late final TypingEngine _engine;
  late final TestTimerController _timer;
  final FocusNode _focusNode = FocusNode();

  String _lang = 'en';
  String _level = 'medium';
  bool _loading = true;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _engine = TypingEngine(targetText: 'Loading...');
    _timer = TestTimerController(totalSeconds: _duration);
    _engine.addListener(_onEngineChanged);
    _timer.addListener(_onTimerChanged);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    _lang = prefs.getString(Constants.keyLanguage) ?? 'en';
    _level = 'medium';

    String text;
    try {
      text = await LocalTextService.instance.getRandomText(_lang, _level);
    } catch (_) {
      text =
          'The quick brown fox jumps over the lazy dog. Practice makes perfect, and every keystroke is a step forward.';
    }
    if (!mounted) return;
    setState(() {
      _engine.reset(newTargetText: text);
      _loading = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  void _onEngineChanged() {
    if (_engine.hasStarted && !_timer.isRunning && !_timer.isFinished) {
      _timer.start();
    }
    if (_engine.isComplete && !_completed) {
      _finish();
    }
    if (mounted) setState(() {});
  }

  void _onTimerChanged() {
    if (_timer.isFinished && !_completed) {
      _finish();
    }
    if (mounted) setState(() {});
  }

  void _finish() {
    if (_completed) return;
    _completed = true;
    _timer.stop();
    final result = _engine.toResult(
      mode: '${_duration}s',
      lang: _lang,
      level: _level,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ResultScreen(result: result),
        ),
      );
    });
  }

  @override
  void dispose() {
    _engine.removeListener(_onEngineChanged);
    _timer.removeListener(_onTimerChanged);
    _engine.dispose();
    _timer.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    final wpm = _engine.wpm;
    final accuracy = _engine.accuracy;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _focusNode.requestFocus(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                _buildTopBar(wpm),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _timer.progress,
                    minHeight: 6,
                    backgroundColor: AppColors.surfaceVariant,
                    valueColor:
                        const AlwaysStoppedAnimation(AppColors.primary),
                  ),
                ),
                const SizedBox(height: 28),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final maxHeight = constraints.maxHeight * 0.65;
                      return Stack(
                        children: [
                          Container(
                            constraints: BoxConstraints(maxHeight: maxHeight),
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                  color: AppColors.surfaceVariant),
                            ),
                            child: SingleChildScrollView(
                              child: TextHighlighter(
                                targetText: _engine.targetText,
                                typedText: _engine.typedText,
                                fontSize: 22,
                              ),
                            ),
                          ),
                          Positioned.fill(
                            child: IgnorePointer(
                              ignoring: false,
                              child: HiddenTypingField(
                                engine: _engine,
                                focusNode: _focusNode,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _StatChip(
                      label: 'Accuracy',
                      value: '${accuracy.toStringAsFixed(0)}%',
                      color: AppColors.success,
                    ),
                    const Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 14,
                          color: AppColors.textMuted,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Autocorrect disabled',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(double wpm) {
    return Row(
      children: [
        IconButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
          icon: const Icon(Icons.close_rounded),
          color: AppColors.textSecondary,
          iconSize: 26,
        ),
        Expanded(
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.surfaceVariant),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.timer_outlined,
                    color: AppColors.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${_timer.remaining}s',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              wpm.toStringAsFixed(0),
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Text(
              'WPM',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 13,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

/// Helper to construct a [TestResult] from an engine. Exposed in case
/// other screens want to build results without reinstantiating logic.
TestResult buildResultFromEngine(
  TypingEngine engine, {
  required String mode,
  required String lang,
  required String level,
}) {
  return engine.toResult(mode: mode, lang: lang, level: level);
}
