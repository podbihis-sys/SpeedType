library leaderboard_screen;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _loading = true;
  String _lang = 'EN';
  String _level = 'Medium';

  final List<_Entry> _entries = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    final sample = <_Entry>[
      _Entry(1, 'FastFingers', 128, 98.4, true),
      _Entry(2, 'KeyMaster', 121, 97.8, false),
      _Entry(3, 'SpeedKing', 118, 97.1, false),
      _Entry(4, 'TypoSlayer', 110, 96.3, false),
      _Entry(5, 'Nova', 108, 95.9, false),
      _Entry(6, 'Racer', 104, 95.2, false),
      _Entry(7, 'Blitz', 101, 94.8, false),
      _Entry(8, 'Quicksand', 99, 94.5, false),
      _Entry(9, 'Ninja', 97, 94.1, false),
      _Entry(10, 'Lightning', 96, 93.9, false),
      _Entry(11, 'Phoenix', 94, 93.5, false),
      _Entry(12, 'Zephyr', 92, 93.1, false),
      _Entry(27, 'You', 78, 95.2, false, isSelf: true),
    ];
    setState(() {
      _entries
        ..clear()
        ..addAll(sample);
      _loading = false;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final own = _entries.firstWhere(
      (e) => e.isSelf,
      orElse: () => _Entry(0, '', 0, 0, false),
    );
    final podium = _entries.where((e) => !e.isSelf).take(3).toList();
    final rest = _entries.where((e) => !e.isSelf && e.rank > 3).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Leaderboard',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list_rounded),
            onPressed: () {},
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textMuted,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700),
          tabs: const [
            Tab(text: 'Today'),
            Tab(text: 'This Week'),
            Tab(text: 'All Time'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                _FilterChip(
                  label: _lang,
                  icon: Icons.language_rounded,
                  onTap: () {},
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: _level,
                  icon: Icons.speed_rounded,
                  onTap: () {},
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? _buildSkeleton()
                : RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: () async {
                      setState(() => _loading = true);
                      await _loadEntries();
                    },
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                      children: [
                        if (podium.length >= 3) _buildPodium(podium),
                        const SizedBox(height: 24),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            'Top Players',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        for (final e in rest) _buildRankTile(e),
                      ],
                    ),
                  ),
          ),
          if (!_loading && own.rank > 0)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              color: AppColors.background,
              child: _buildRankTile(own, highlighted: true),
            ),
          _buildBannerAdPlaceholder(),
        ],
      ),
    );
  }

  Widget _buildPodium(List<_Entry> top) {
    final first = top[0];
    final second = top[1];
    final third = top[2];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: _PodiumCard(
            rank: 2,
            name: second.name,
            wpm: second.wpm,
            height: 130,
            color: const Color(0xFFC0C0C0),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _PodiumCard(
            rank: 1,
            name: first.name,
            wpm: first.wpm,
            height: 170,
            color: const Color(0xFFFFD700),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _PodiumCard(
            rank: 3,
            name: third.name,
            wpm: third.wpm,
            height: 110,
            color: const Color(0xFFCD7F32),
          ),
        ),
      ],
    );
  }

  Widget _buildRankTile(_Entry e, {bool highlighted = false}) {
    final bg = highlighted ? AppColors.primary : AppColors.surface;
    final fg = highlighted ? AppColors.background : AppColors.textPrimary;
    final subFg = highlighted ? AppColors.background : AppColors.textMuted;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: highlighted ? AppColors.primary : AppColors.surfaceVariant,
        ),
        boxShadow: highlighted
            ? [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 16,
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '#${e.rank}',
              style: TextStyle(
                color: subFg,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 18,
            backgroundColor: highlighted
                ? AppColors.background.withOpacity(0.2)
                : AppColors.surfaceVariant,
            child: Text(
              e.name.isNotEmpty ? e.name[0].toUpperCase() : '?',
              style: TextStyle(
                color: fg,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.name,
                  style: TextStyle(
                    color: fg,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${e.accuracy.toStringAsFixed(1)}% accuracy',
                  style: TextStyle(color: subFg, fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${e.wpm}',
                style: TextStyle(
                  color: fg,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                'WPM',
                style: TextStyle(color: subFg, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 10,
      itemBuilder: (context, i) {
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          height: 62,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
          ),
        );
      },
    );
  }

  Widget _buildBannerAdPlaceholder() {
    return Container(
      height: 56,
      color: AppColors.background,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: const Text(
          'Banner Ad',
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _Entry {
  final int rank;
  final String name;
  final int wpm;
  final double accuracy;
  final bool isTop;
  final bool isSelf;

  _Entry(this.rank, this.name, this.wpm, this.accuracy, this.isTop,
      {this.isSelf = false});
}

class _PodiumCard extends StatelessWidget {
  const _PodiumCard({
    required this.rank,
    required this.name,
    required this.wpm,
    required this.height,
    required this.color,
  });

  final int rank;
  final String name;
  final int wpm;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CircleAvatar(
          radius: 26,
          backgroundColor: color.withOpacity(0.2),
          child: Text(
            name.isNotEmpty ? name[0] : '?',
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          name,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: height,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withOpacity(0.35), color.withOpacity(0.08)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            border: Border.all(color: color.withOpacity(0.5)),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(14),
            ),
          ),
          child: Column(
            children: [
              Text(
                '#$rank',
                style: TextStyle(
                  color: color,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$wpm',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Text(
                'WPM',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.surfaceVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppColors.primary),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}
