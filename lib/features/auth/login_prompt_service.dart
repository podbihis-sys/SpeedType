import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/services/auth_service.dart';
import '../../core/theme/app_colors.dart';

/// Copy shown in a login prompt sheet.
class LoginPromptContent {
  final String title;
  final String message;
  final String ctaText;

  const LoginPromptContent({
    required this.title,
    required this.message,
    required this.ctaText,
  });
}

/// Singleton that decides when the "sign in to save progress" sheet should
/// appear, and tracks per-session / per-type throttling.
class LoginPromptService {
  LoginPromptService._internal();

  static final LoginPromptService _instance = LoginPromptService._internal();
  static LoginPromptService get instance => _instance;
  factory LoginPromptService() => _instance;

  // Prompt types ------------------------------------------------------------
  static const String AFTER_5_TESTS = 'after_5_tests';
  static const String LEADERBOARD_TAP = 'leaderboard_tap';
  static const String STREAK_LOSS = 'streak_loss';
  static const String SHARE_TAP = 'share_tap';

  // Storage keys ------------------------------------------------------------
  static const String _kPrefPrefix = 'login_prompt_';
  static const String _kShownCountSuffix = '_shown_count';
  static const String _kLastShownSuffix = '_last_shown';

  // Per-session de-dupe. Cleared via [resetSession].
  final Set<String> _shownThisSession = <String>{};

  // Minimum interval between reshowings of the same prompt type.
  static const Duration _minInterval = Duration(hours: 24);
  // Cap per type across app lifetime.
  static const int _maxShowsPerType = 3;

  /// Returns true when the given prompt type should be shown right now.
  Future<bool> shouldShowPrompt(String type) async {
    // Never prompt a logged-in user.
    if (AuthService.instance.isLoggedIn) return false;
    if (_shownThisSession.contains(type)) return false;

    final prefs = await SharedPreferences.getInstance();
    final shownCount =
        prefs.getInt('$_kPrefPrefix$type$_kShownCountSuffix') ?? 0;
    if (shownCount >= _maxShowsPerType) return false;

    final lastShownMs =
        prefs.getInt('$_kPrefPrefix$type$_kLastShownSuffix') ?? 0;
    if (lastShownMs > 0) {
      final last = DateTime.fromMillisecondsSinceEpoch(lastShownMs);
      if (DateTime.now().difference(last) < _minInterval) return false;
    }
    return true;
  }

  /// Records that a prompt was shown.
  Future<void> markPromptShown(String type) async {
    _shownThisSession.add(type);
    final prefs = await SharedPreferences.getInstance();
    final countKey = '$_kPrefPrefix$type$_kShownCountSuffix';
    final lastKey = '$_kPrefPrefix$type$_kLastShownSuffix';
    await prefs.setInt(countKey, (prefs.getInt(countKey) ?? 0) + 1);
    await prefs.setInt(lastKey, DateTime.now().millisecondsSinceEpoch);
  }

  /// Clears per-session throttling. Call on app start / logout.
  void resetSession() {
    _shownThisSession.clear();
  }

  /// Contextual copy for each prompt type.
  LoginPromptContent getContent(String type) {
    switch (type) {
      case AFTER_5_TESTS:
        return const LoginPromptContent(
          title: 'Save Your Progress',
          message:
              "You're on fire! Sign in to sync your stats across devices "
              'and never lose your progress.',
          ctaText: 'Sign in to save',
        );
      case LEADERBOARD_TAP:
        return const LoginPromptContent(
          title: 'Join the Leaderboard',
          message:
              'Sign in to post your best scores and compete with typists '
              'around the world.',
          ctaText: 'Compete now',
        );
      case STREAK_LOSS:
        return const LoginPromptContent(
          title: 'Protect Your Streak',
          message:
              'Keep your streak safe by backing it up to your account. '
              'Sign in so you never lose a day again.',
          ctaText: 'Back up streak',
        );
      case SHARE_TAP:
        return const LoginPromptContent(
          title: 'Share With Your Name',
          message:
              'Sign in to share your results with your profile name and '
              'unlock custom share cards.',
          ctaText: 'Sign in to share',
        );
      default:
        return const LoginPromptContent(
          title: 'Sign In',
          message: 'Sign in to unlock the full SpeedType experience.',
          ctaText: 'Sign in',
        );
    }
  }
}

/// Modal bottom sheet that shows a contextual prompt with Google / Apple
/// buttons and a "Later" dismiss action.
class LoginPromptSheet extends StatefulWidget {
  final String promptType;

  const LoginPromptSheet({super.key, required this.promptType});

  /// Convenience helper. Returns `true` if the user signed in, `false`
  /// otherwise (dismissed, cancelled, error).
  static Future<bool> show(
    BuildContext context, {
    required String promptType,
  }) async {
    await LoginPromptService.instance.markPromptShown(promptType);
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => LoginPromptSheet(promptType: promptType),
    );
    return result ?? false;
  }

  @override
  State<LoginPromptSheet> createState() => _LoginPromptSheetState();
}

class _LoginPromptSheetState extends State<LoginPromptSheet> {
  bool _busy = false;

  Future<void> _handle(Future<AuthResult> Function() op) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final result = await op();
      if (!mounted) return;
      if (result.isSuccess) {
        Navigator.of(context).pop(true);
      } else if (result.isError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.errorMessage ?? 'Sign-in failed'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final content =
        LoginPromptService.instance.getContent(widget.promptType);

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
            Text(
              content.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              content.message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 15,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 28),
            _GoogleButton(
              busy: _busy,
              onPressed: () =>
                  _handle(AuthService.instance.signInWithGoogle),
            ),
            const SizedBox(height: 12),
            _AppleButton(
              busy: _busy,
              onPressed: () =>
                  _handle(AuthService.instance.signInWithApple),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed:
                  _busy ? null : () => Navigator.of(context).pop(false),
              child: const Text(
                'Later',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoogleButton extends StatelessWidget {
  final bool busy;
  final VoidCallback onPressed;
  const _GoogleButton({required this.busy, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ElevatedButton.icon(
        onPressed: busy ? null : onPressed,
        icon: const Icon(Icons.login, color: Colors.white),
        label: const Text(
          'Continue with Google',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
      ),
    );
  }
}

class _AppleButton extends StatelessWidget {
  final bool busy;
  final VoidCallback onPressed;
  const _AppleButton({required this.busy, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ElevatedButton.icon(
        onPressed: busy ? null : onPressed,
        icon: const Icon(Icons.apple, color: Colors.white),
        label: const Text(
          'Continue with Apple',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.surfaceVariant,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppColors.textMuted, width: 0.5),
          ),
          elevation: 0,
        ),
      ),
    );
  }
}
