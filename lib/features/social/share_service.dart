library share_service;

import 'dart:io';

import 'package:appinio_social_share/appinio_social_share.dart';
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
/// composition and the platform share sheets / deep links.
class ShareService {
  ShareService._internal();

  static final ShareService _instance = ShareService._internal();
  factory ShareService() => _instance;
  static ShareService get instance => _instance;

  final AppinioSocialShare _socialShare = AppinioSocialShare();

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

  /// Shares an already-rendered scorecard directly to Instagram Stories.
  Future<ShareResult> shareToInstagramStories(String imagePath) async {
    try {
      if (!File(imagePath).existsSync()) {
        return ShareResult.failure('instagram', 'Image not found: $imagePath');
      }
      final String response = await _socialShare.shareToInstagramStory(
        imagePath,
        backgroundTopColor: '#0B1120',
        backgroundBottomColor: '#1E293B',
      );
      return ShareResult.success('instagram:$response');
    } catch (e) {
      return ShareResult.failure('instagram', e.toString());
    }
  }

  /// Shares an already-rendered scorecard to TikTok via its share intent.
  Future<ShareResult> shareToTikTok(String imagePath) async {
    try {
      if (!File(imagePath).existsSync()) {
        return ShareResult.failure('tiktok', 'Image not found: $imagePath');
      }
      final String response = await _socialShare.shareToTiktok(imagePath);
      return ShareResult.success('tiktok:$response');
    } catch (e) {
      return ShareResult.failure('tiktok', e.toString());
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Future<ScorecardData> _buildScorecardData(TestResult result) async {
    final int streak = await StreakService.instance.getCurrentStreak();
    final String levelName = _formatLevelName(result.level);

    return ScorecardData(
      wpm: result.wpm,
      accuracy: result.accuracy,
      streak: streak,
      levelName: levelName,
      lang: result.lang,
      level: result.level,
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

/// Bottom sheet that shows a preview of the scorecard and exposes the
/// system share sheet, Instagram Stories and TikTok as explicit buttons.
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

  Future<void> _shareInstagram() async {
    final String? path = _imagePath;
    if (path == null) return;
    await ShareService.instance.shareToInstagramStories(path);
  }

  Future<void> _shareTikTok() async {
    final String? path = _imagePath;
    if (path == null) return;
    await ShareService.instance.shareToTikTok(path);
  }

  @override
  Widget build(BuildContext context) {
    final MediaQueryData mq = MediaQuery.of(context);

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: 20 + mq.viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 48,
            height: 5,
            decoration: BoxDecoration(
              color: AppColors.textMuted.withOpacity(0.4),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Share your result',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          AspectRatio(
            aspectRatio: 1080 / 1920,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: _buildPreview(),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              _ShareButton(
                icon: Icons.ios_share_rounded,
                label: 'Share',
                onTap: _generating ? null : _shareSystem,
              ),
              _ShareButton(
                icon: Icons.camera_alt_rounded,
                label: 'Instagram',
                onTap: _generating ? null : _shareInstagram,
              ),
              _ShareButton(
                icon: Icons.music_note_rounded,
                label: 'TikTok',
                onTap: _generating ? null : _shareTikTok,
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    final ScorecardData? data = _data;
    if (data == null) {
      return Container(
        color: AppColors.background,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(color: AppColors.primary),
      );
    }
    return FittedBox(
      fit: BoxFit.contain,
      child: SizedBox(
        width: 1080,
        height: 1920,
        child: ScorecardGenerator.instance.buildScorecardWidget(data),
      ),
    );
  }
}

class _ShareButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ShareButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.primary.withOpacity(enabled ? 0.5 : 0.15),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              icon,
              color: enabled ? AppColors.primary : AppColors.textMuted,
              size: 28,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color:
                    enabled ? AppColors.textPrimary : AppColors.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Keep a reference to the level service to avoid tree-shaking complaints in
// downstream builds that expect this import to be "used".
// ignore: unused_element
final LevelProgressionService _kLevelServiceRef = LevelProgressionService.instance;
