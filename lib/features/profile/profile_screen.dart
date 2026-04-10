library profile_screen;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final String _username = 'SpeedTyper';
  final int _level = 12;
  final int _bestWpm = 78;
  final int _avgWpm = 62;
  final int _totalTests = 143;
  final int _streak = 5;
  final double _xpProgress = 0.72;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Profile',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildStatsGrid(),
            const SizedBox(height: 24),
            _sectionTitle('Achievements'),
            const SizedBox(height: 12),
            _buildBadgesRow(),
            const SizedBox(height: 24),
            _sectionTitle('Streak'),
            const SizedBox(height: 12),
            _buildStreakCalendar(),
            const SizedBox(height: 24),
            _buildLevelProgression(),
            const SizedBox(height: 24),
            _sectionTitle('Recent Tests'),
            const SizedBox(height: 12),
            _buildTestHistory(),
            const SizedBox(height: 20),
            _buildBannerAdPlaceholder(),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _buildHeader() {
    final initials = _username.isNotEmpty
        ? _username.substring(0, _username.length >= 2 ? 2 : 1).toUpperCase()
        : '?';
    return Column(
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.secondary],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.3),
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            initials,
            style: const TextStyle(
              color: AppColors.background,
              fontSize: 36,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          _username,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primary.withOpacity(0.4)),
          ),
          child: Text(
            'Level $_level • Advanced',
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsGrid() {
    final stats = [
      _StatData('Best WPM', '$_bestWpm', Icons.bolt_rounded,
          AppColors.primary),
      _StatData('Average', '$_avgWpm', Icons.trending_up_rounded,
          AppColors.success),
      _StatData('Total Tests', '$_totalTests',
          Icons.fact_check_rounded, AppColors.secondary),
      _StatData('Streak', '$_streak days',
          Icons.local_fire_department_rounded, AppColors.warning),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: [
        for (final s in stats) _StatCard(data: s),
      ],
    );
  }

  Widget _buildBadgesRow() {
    final badges = [
      _Badge('Speed Demon', '⚡', true),
      _Badge('Accurate', '🎯', true),
      _Badge('Streak 7', '🔥', true),
      _Badge('Centurion', '💯', false),
      _Badge('Marathoner', '🏃', false),
      _Badge('Polyglot', '🌍', false),
    ];
    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: badges.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final b = badges[i];
          final color = b.earned ? AppColors.primary : AppColors.textMuted;
          return Container(
            width: 90,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: b.earned
                    ? AppColors.primary.withOpacity(0.5)
                    : AppColors.surfaceVariant,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Opacity(
                  opacity: b.earned ? 1.0 : 0.35,
                  child: Text(b.emoji,
                      style: const TextStyle(fontSize: 30)),
                ),
                const SizedBox(height: 6),
                Text(
                  b.name,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStreakCalendar() {
    // GitHub-contribution style 5 rows x 7 columns for last ~35 days
    const rows = 5;
    const cols = 7;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.surfaceVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Last 35 days',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  const Text(
                    'less',
                    style: TextStyle(
                        color: AppColors.textMuted, fontSize: 10),
                  ),
                  const SizedBox(width: 6),
                  for (final op in [0.15, 0.35, 0.6, 0.85, 1.0]) ...[
                    Container(
                      width: 10,
                      height: 10,
                      margin: const EdgeInsets.only(right: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(op),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                  const SizedBox(width: 3),
                  const Text(
                    'more',
                    style: TextStyle(
                        color: AppColors.textMuted, fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (var r = 0; r < rows; r++)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  for (var c = 0; c < cols; c++) ...[
                    Expanded(
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: Container(
                          margin: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: _intensity(r, c),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Color _intensity(int row, int col) {
    // Deterministic pseudo-random intensity for preview
    final seed = (row * 7 + col * 3) % 6;
    switch (seed) {
      case 0:
        return AppColors.surfaceVariant;
      case 1:
        return AppColors.primary.withOpacity(0.2);
      case 2:
        return AppColors.primary.withOpacity(0.4);
      case 3:
        return AppColors.primary.withOpacity(0.6);
      case 4:
        return AppColors.primary.withOpacity(0.8);
      default:
        return AppColors.primary;
    }
  }

  Widget _buildLevelProgression() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.surfaceVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'XP Progress',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '${(_xpProgress * 100).toInt()}%',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: _xpProgress,
              minHeight: 10,
              backgroundColor: AppColors.surfaceVariant,
              valueColor:
                  const AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '720 / 1000 XP to Level 13',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildTestHistory() {
    final history = List.generate(
      8,
      (i) => _HistoryItem(
        wpm: 70 + (i * 3) % 20,
        accuracy: 92 + (i * 1.5) % 7,
        mode: ['30s', '60s', '15s'][i % 3],
        daysAgo: i,
      ),
    );
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.surfaceVariant),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: history.length,
        separatorBuilder: (_, __) => Divider(
          height: 1,
          color: AppColors.surfaceVariant.withOpacity(0.5),
        ),
        itemBuilder: (context, i) {
          final h = history[i];
          return ListTile(
            dense: true,
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.keyboard_rounded,
                color: AppColors.primary,
                size: 18,
              ),
            ),
            title: Text(
              '${h.wpm} WPM',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Text(
              '${h.mode} • ${h.accuracy.toStringAsFixed(1)}% acc',
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
              ),
            ),
            trailing: Text(
              h.daysAgo == 0 ? 'Today' : '${h.daysAgo}d ago',
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBannerAdPlaceholder() {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: const Text(
        'Banner Ad',
        style: TextStyle(color: AppColors.textMuted, fontSize: 12),
      ),
    );
  }
}

class _StatData {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  _StatData(this.label, this.value, this.icon, this.color);
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.data});
  final _StatData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.surfaceVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: data.color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(data.icon, color: data.color, size: 16),
              ),
              const SizedBox(width: 8),
              Text(
                data.label,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          Text(
            data.value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge {
  final String name;
  final String emoji;
  final bool earned;
  _Badge(this.name, this.emoji, this.earned);
}

class _HistoryItem {
  final int wpm;
  final double accuracy;
  final String mode;
  final int daysAgo;

  _HistoryItem({
    required this.wpm,
    required this.accuracy,
    required this.mode,
    required this.daysAgo,
  });
}
