library sharecard_generator;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';

import '../../core/theme/app_colors.dart';

/// Immutable data model describing everything required to render a shareable
/// scorecard image for a completed SpeedType test.
class ScorecardData {
  final double wpm;
  final double accuracy;
  final int streak;
  final String levelName;
  final String lang;
  final String level;
  final bool isPersonalBest;
  final bool isDailyChallenge;
  final int? percentile;

  const ScorecardData({
    required this.wpm,
    required this.accuracy,
    required this.streak,
    required this.levelName,
    required this.lang,
    required this.level,
    this.isPersonalBest = false,
    this.isDailyChallenge = false,
    this.percentile,
  });
}

/// Singleton service responsible for rendering [ScorecardData] into a
/// 1080x1920 PNG suitable for sharing to social platforms (Instagram
/// Stories, TikTok, X, etc).
class ScorecardGenerator {
  ScorecardGenerator._internal();

  static final ScorecardGenerator _instance = ScorecardGenerator._internal();
  factory ScorecardGenerator() => _instance;
  static ScorecardGenerator get instance => _instance;

  final ScreenshotController _controller = ScreenshotController();

  /// Renders [data] into a PNG on disk and returns the absolute file path.
  ///
  /// Uses [ScreenshotController.captureFromWidget] which renders offscreen
  /// so the caller doesn't need a BuildContext visible in the widget tree.
  Future<String> generateScorecard(ScorecardData data) async {
    final Uint8List bytes = await _controller.captureFromWidget(
      MediaQuery(
        data: const MediaQueryData(),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: buildScorecardWidget(data),
        ),
      ),
      pixelRatio: 1.0,
      delay: const Duration(milliseconds: 20),
      targetSize: const Size(1080, 1920),
    );

    final Directory dir = await getTemporaryDirectory();
    final String fileName =
        'speedtype_scorecard_${DateTime.now().millisecondsSinceEpoch}.png';
    final File file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  /// Builds the widget tree that represents the scorecard. Exposed publicly
  /// so it can also be embedded in a preview (see [ShareBottomSheet]).
  Widget buildScorecardWidget(ScorecardData data) {
    const Color goldColor = Color(0xFFFFD700);
    final Color wpmColor = data.isPersonalBest ? goldColor : AppColors.primary;

    return Container(
      width: 1080,
      height: 1920,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFF0B1120),
            Color(0xFF1E293B),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 120),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            // --- Logo row ---
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  Icons.keyboard_alt_rounded,
                  color: AppColors.primary,
                  size: 88,
                ),
                const SizedBox(width: 24),
                const Text(
                  'SpeedType',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 72,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.5,
                  ),
                ),
              ],
            ),

            // --- WPM hero block ---
            Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (data.isPersonalBest)
                  Container(
                    margin: const EdgeInsets.only(bottom: 32),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 36,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: goldColor.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: goldColor, width: 3),
                    ),
                    child: const Text(
                      'NEW PERSONAL BEST!',
                      style: TextStyle(
                        color: goldColor,
                        fontSize: 40,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 3,
                      ),
                    ),
                  ),
                Text(
                  data.wpm.toStringAsFixed(0),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: wpmColor,
                    fontSize: 220,
                    fontWeight: FontWeight.w900,
                    height: 0.9,
                    letterSpacing: -6,
                    shadows: <Shadow>[
                      Shadow(
                        color: wpmColor.withOpacity(0.35),
                        blurRadius: 48,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'WORDS PER MINUTE',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 40,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 6,
                  ),
                ),
                if (data.percentile != null) ...<Widget>[
                  const SizedBox(height: 40),
                  _RankBadge(percentile: data.percentile!),
                ],
              ],
            ),

            // --- Stats row ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                _StatTile(
                  icon: Icons.track_changes_rounded,
                  label: 'Accuracy',
                  value: '${data.accuracy.toStringAsFixed(0)}%',
                  accent: AppColors.success,
                ),
                _StatTile(
                  icon: Icons.local_fire_department_rounded,
                  label: 'Streak',
                  value: '${data.streak}d',
                  accent: AppColors.warning,
                ),
                _StatTile(
                  icon: Icons.military_tech_rounded,
                  label: 'Level',
                  value: data.levelName,
                  accent: AppColors.secondary,
                ),
              ],
            ),

            // --- Footer / CTA ---
            Column(
              children: <Widget>[
                Text(
                  'Can you beat me? \u{1F446}',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 56,
                    fontWeight: FontWeight.w700,
                    shadows: <Shadow>[
                      Shadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'speedtype.app',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 42,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: accent.withOpacity(0.35),
          width: 2,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, color: accent, size: 56),
          const SizedBox(height: 14),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 56,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 28,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _RankBadge extends StatelessWidget {
  final int percentile;

  const _RankBadge({required this.percentile});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 44, vertical: 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            AppColors.primary.withOpacity(0.25),
            AppColors.secondary.withOpacity(0.25),
          ],
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.primary, width: 3),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(
            Icons.emoji_events_rounded,
            color: Color(0xFFFFD700),
            size: 48,
          ),
          const SizedBox(width: 16),
          Text(
            'TOP $percentile%',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 44,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }
}
