library onboarding_screen;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/constants.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  static const _languages = <_LanguageOption>[
    _LanguageOption(code: 'en', flag: '🇬🇧', name: 'English'),
    _LanguageOption(code: 'de', flag: '🇩🇪', name: 'Deutsch'),
    _LanguageOption(code: 'es', flag: '🇪🇸', name: 'Español'),
    _LanguageOption(code: 'fr', flag: '🇫🇷', name: 'Français'),
    _LanguageOption(code: 'pt', flag: '🇧🇷', name: 'Português'),
  ];

  String _selected = 'en';
  bool _saving = false;
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (_saving) return;
    setState(() => _saving = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(Constants.keyLanguage, _selected);
    await prefs.setBool(Constants.keyOnboardingDone, true);
    if (!mounted) return;
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              _buildHeader(),
              const SizedBox(height: 32),
              const Text(
                'Choose your language',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.only(top: 4, bottom: 12),
                  itemCount: _languages.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final lang = _languages[index];
                    final start = (index * 0.1).clamp(0.0, 1.0);
                    final end = (0.4 + index * 0.12).clamp(0.0, 1.0);
                    final anim = CurvedAnimation(
                      parent: _controller,
                      curve: Interval(start, end, curve: Curves.easeOutCubic),
                    );
                    return AnimatedBuilder(
                      animation: anim,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(60 * (1 - anim.value), 0),
                          child: Opacity(opacity: anim.value, child: child),
                        );
                      },
                      child: _LanguageCard(
                        option: lang,
                        selected: _selected == lang.code,
                        onTap: () => setState(() => _selected = lang.code),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _saving ? null : _continue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.background,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: AppColors.background,
                          ),
                        )
                      : const Text('Continue'),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.secondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.35),
                blurRadius: 30,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(
            Icons.keyboard_alt_rounded,
            color: AppColors.background,
            size: 54,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'SpeedType',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 38,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'How fast can you type?',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}

class _LanguageOption {
  final String code;
  final String flag;
  final String name;

  const _LanguageOption({
    required this.code,
    required this.flag,
    required this.name,
  });
}

class _LanguageCard extends StatelessWidget {
  const _LanguageCard({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final _LanguageOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.surfaceVariant,
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.25),
                    blurRadius: 16,
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Text(option.flag, style: const TextStyle(fontSize: 30)),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                option.name,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            AnimatedScale(
              duration: const Duration(milliseconds: 200),
              scale: selected ? 1 : 0,
              child: Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: AppColors.background,
                  size: 18,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
