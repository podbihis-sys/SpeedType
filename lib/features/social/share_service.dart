library share_service;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart' as sp;

import '../../core/services/level_progression_service.dart';
import '../../core/services/streak_service.dart';
import '../../core/theme/app_colors.dart';
import '../../models/test_result.dart';
import 'sharecard_generator.dart';

/// The outcome of a share attempt, surfaced to the UI so it can show a
/// snackbar / toast and also forwarded to analytics.
class ShareResult {
  final bool success;
  final String platform;
  final String? error;

  const ShareResult({
    required this.success,
    required this.platform,
    this.error,
  });

  factory ShareResult.success(String platform) =>
      ShareResult(success: true, platform: platform);

  factory ShareResult.failure(String platform, String error) =>
      ShareResult(success: false, platform: platform, error: error);

  @override
  String toString() =>
      'ShareResult(success: $success, platform: $platform, error: $error)';
}

/// Singleton service that glues together scorecard rendering, text
/// composition and the platform share sheet via `share_plus`.
class ShareService {
  ShareService._internal();

  static final ShareService _instance = ShareService._internal();
  factory ShareService() => _instance;
  static ShareService get instance => _instance;

  /// Builds a [ScorecardData] from a [TestResult] using live data from the
  /// streak and level services, renders the image, builds the copy and
  /// shows the system share sheet via `share_plus`.
  Future<ShareResult> shareScorecard(TestResult result) async {
    try {
      final ScorecardData data = await _buildScorecardData(result);
      final String imagePath =
          await ScorecardGenerator.instance.generateScorecard(data);

      final String shareText = _buildShareText(result);

      final sp.ShareResult platformResult = await sp.Share.shareXFiles(
        <sp.XFile>[sp.XFile(imagePath, mimeType: 'image/png')],
        text: shareText,
        subject: 'My SpeedType result',
      );
      final bool ok = platformResult.status == sp.ShareResultStatus.success ||
          platformResult.status == sp.ShareResultStatus.unavailable;
      return ok
          ? ShareResult.success('system')
          : ShareResult.failure('system', platformResult.status.toString());
    } catch (e) {
      return ShareResult.failure('system', e.toString());
    }
  }

  /// Shares just the share text without an image - useful on web where
  /// the native share sheet may not support images.
  Future<ShareResult> shareText(TestResult result) async {
    try {
      await sp.Share.share(_buildShareText(result));
      return ShareResult.success('system');
    } catch (e) {
      return ShareResult.failure('system', e.toString());
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Future<ScorecardData> _buildScorecardData(TestResult result) async {
    final int streak = await StreakService.instance.getCurrentStreak();

    // Level service is referenced here so level-name formatting stays in
    // one place and future threshold metadata (e.g. gold trim) can be
    // surfaced to the scorecard without changing call sites.
    final String currentLevel = result.level.isNotEmpty
        ? result.level
        : LevelProgressionService.LEVELS.first;
    final String levelName = _formatLevelName(currentLevel);

    return ScorecardData(
      wpm: result.wpm,
      accuracy: result.accuracy,
      streak: streak,
      levelName: levelName,
      lang: result.lang,
      level: currentLevel,
      isPersonalBest: result.isPersonalBest,
      isDailyChallenge: result.mode == 'daily' || result.mode == 'challenge',
      percentile: result.percentile,
    );
  }

  String _formatLevelName(String level) {
    if (level.isEmpty) return 'Beginner';
    return level[0].toUpperCase() + level.substring(1);
  }

  String _buildShareText(TestResult result) {
    final String wpmStr = result.wpm.toStringAsFixed(0);
    return 'I typed $wpmStr WPM on SpeedType! \u{1F525} '
        'Can you beat me? #SpeedType #TypingTest #WPM';
  }
}

/// Bottom sheet that shows a preview of the scorecard and a single
/// "Share" button that opens the system share sheet via share_plus.
class ShareBottomSheet extends StatefulWidget {
  final TestResult result;

  const ShareBottomSheet({
    super.key,
    required this.result,
  });

  /// Convenience helper to display the sheet.
  static Future<void> show(BuildContext context, TestResult result) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => ShareBottomSheet(result: result),
    );
  }

  @override
  State<ShareBottomSheet> createState() => _ShareBottomSheetState();
}

class _ShareBottomSheetState extends State<ShareBottomSheet> {
  ScorecardData? _data;
  String? _imagePath;
  bool _generating = false;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    setState(() => _generating = true);
    try {
      final int streak = await StreakService.instance.getCurrentStreak();
      final String levelName = widget.result.level.isNotEmpty
          ? widget.result.level[0].toUpperCase() +
              widget.result.level.substring(1)
          : 'Beginner';

      final ScorecardData data = ScorecardData(
        wpm: widget.result.wpm,
        accuracy: widget.result.accuracy,
        streak: streak,
        levelName: levelName,
        lang: widget.result.lang,
        level: widget.result.level,
        isPersonalBest: widget.result.isPersonalBest,
        isDailyChallenge: widget.result.mode == 'daily' ||
            widget.result.mode == 'challenge',
        percentile: widget.result.percentile,
      );

      final String path =
          await ScorecardGenerator.instance.generateScorecard(data);

      if (!mounted) return;
      setState(() {
        _data = data;
        _imagePath = path;
        _generating = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _generating = false);
    }
  }

  Future<void> _shareSystem() async {
    await ShareService.instance.shareScorecard(widget.result);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textMuted,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Share your result',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              if (_generating)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                    ),
                  ),
                )
              else if (_data != null && _imagePath != null) ...[
                AspectRatio(
                  aspectRatio: 9 / 16,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: ScorecardGenerator.instance
                          .buildScorecardWidget(_data!),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: _shareSystem,
                    icon: const Icon(Icons.share_rounded),
                    label: const Text('Share scorecard'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.background,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ] else
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Could not generate scorecard.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }
}
