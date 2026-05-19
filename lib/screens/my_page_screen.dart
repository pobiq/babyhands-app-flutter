import 'package:flutter/material.dart';

import '../core/notification_service.dart';
import '../data/home_progress_repository.dart';
import '../theme/app_colors.dart';
import '../widgets/app_icon_header.dart';
import 'home_screen.dart';
import 'learn_screen.dart';
import 'ranking_screen.dart';
import 'test_screen.dart';

class MyPageScreen extends StatefulWidget {
  const MyPageScreen({super.key, required this.onLogout});

  final VoidCallback onLogout;

  @override
  State<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> {
  final AppHomeProgressRepository _repository =
      AppHomeProgressRepository.instance;

  void _openLearn(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => LearnScreen(onLogout: widget.onLogout),
      ),
    );
  }

  void _openTest(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => TestScreen(onLogout: widget.onLogout),
      ),
    );
  }

  void _openRecords(
    List<LearningActivity> activities,
    List<TestAttemptSummary> attempts,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            LearningRecordScreen(activities: activities, attempts: attempts),
      ),
    );
  }

  /// JSP 랭킹 화면을 앱으로 옮긴 랭킹 페이지를 연다.
  void _openRanking() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => RankingScreen(onLogout: widget.onLogout),
      ),
    );
  }

  void _openHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => HomeScreen(onLogout: widget.onLogout),
      ),
      (route) => false,
    );
  }

  /// 로그아웃 확인 다이얼로그를 표시한다.
  void _confirmLogout() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          '로그아웃',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: const Text('현재 계정에서 로그아웃할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              widget.onLogout();
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.bgTop, AppColors.bgBottom],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
                    sliver: SliverToBoxAdapter(
                      child: FutureBuilder<HomeDashboardData>(
                        future: _repository.loadDashboard(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const _Surface(
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }

                          final data = snapshot.data!;
                          final attempts = _repository.recentTestAttempts();
                          final activities = _repository.recentActivities();

                          return Column(
                            children: [
                              _ProfileCard(data: data),
                              const SizedBox(height: 14),
                              _StatsGrid(data: data, attempts: attempts),
                              const SizedBox(height: 14),
                              _RankingDecisionCard(
                                attempts: attempts,
                                onTap: _openRanking,
                              ),
                              const SizedBox(height: 14),
                              const _DailyStudyReminderCard(),
                              const SizedBox(height: 14),
                              _RecentActivity(
                                activities: activities,
                                onOpenRecords: () =>
                                    _openRecords(activities, attempts),
                              ),
                              const SizedBox(height: 14),
                              // 마이페이지 하단 로그아웃 버튼
                              _LogoutCard(onLogout: _confirmLogout),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: AppBottomNavBar(
        selected: AppNavItem.myPage,
        onHome: _openHome,
        onLearn: () => _openLearn(context),
        onTest: () => _openTest(context),
        onRanking: _openRanking,
        onMyPage: () {},
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.data});

  final HomeDashboardData data;

  @override
  Widget build(BuildContext context) {
    final progress = data.overallProgressPercent;
    final streak = data.attendanceDates.length;

    return _Surface(
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: Color(0xFFDCFCE7),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_rounded,
              color: AppColors.primary,
              size: 36,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '학습자',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.text,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.local_fire_department_rounded,
                      color: AppColors.streak,
                      size: 18,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '연속 $streak일',
                      style: const TextStyle(
                        color: AppColors.streak,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '진도 $progress%',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.data, required this.attempts});

  final HomeDashboardData data;
  final List<TestAttemptSummary> attempts;

  @override
  Widget build(BuildContext context) {
    final passedTests = attempts
        .where((attempt) => attempt.passedCount == attempt.totalCount)
        .length;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _StatTile(label: '완료 글자', value: '${data.completedLetterCount}'),
        _StatTile(label: '평균 정확도', value: '${data.averageAccuracyPercent}%'),
        _StatTile(label: '통과 테스트', value: '$passedTests'),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: _Surface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentActivity extends StatelessWidget {
  const _RecentActivity({
    required this.activities,
    required this.onOpenRecords,
  });

  final List<LearningActivity> activities;
  final VoidCallback onOpenRecords;

  @override
  Widget build(BuildContext context) {
    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '최근 활동',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.text,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          if (activities.isEmpty)
            const Text(
              '아직 활동 내역이 없습니다.',
              style: TextStyle(
                color: AppColors.muted,
                fontWeight: FontWeight.w700,
              ),
            )
          else
            for (final activity in activities)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.success,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        activity.label,
                        style: const TextStyle(
                          color: AppColors.text,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onOpenRecords,
            icon: const Icon(Icons.history_rounded),
            label: const Text('학습 기록 보기'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RankingDecisionCard extends StatelessWidget {
  const _RankingDecisionCard({required this.attempts, required this.onTap});

  final List<TestAttemptSummary> attempts;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bestScore = attempts.isEmpty
        ? 0
        : attempts
              .map((attempt) => attempt.scorePercent)
              .reduce((best, score) => score > best ? score : best);

    return _Surface(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Row(
          children: [
            const Icon(Icons.leaderboard_rounded, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '랭킹',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.text,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '$bestScore%',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}

/// 매일 학습 알림(로컬 알림) ON/OFF 및 시각 설정 카드다.
class _DailyStudyReminderCard extends StatefulWidget {
  const _DailyStudyReminderCard();

  @override
  State<_DailyStudyReminderCard> createState() =>
      _DailyStudyReminderCardState();
}

class _DailyStudyReminderCardState extends State<_DailyStudyReminderCard> {
  final NotificationService _service = NotificationService.instance;
  bool _loading = true;
  bool _enabled = true;
  TimeOfDay _time = const TimeOfDay(hour: 9, minute: 0);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final enabled = await _service.isEnabled();
    final time = await _service.getReminderTime();
    if (!mounted) return;
    setState(() {
      _enabled = enabled;
      _time = time;
      _loading = false;
    });
  }

  String _formatTime(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Future<void> _onToggle(bool value) async {
    if (value) {
      final ok = await _service.requestNotificationPermissions();
      if (!mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('알림을 사용하려면 기기 설정에서 알림을 허용해주세요.')),
        );
        return;
      }
    }
    await _service.setEnabled(value: value);
    if (mounted) setState(() => _enabled = value);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked == null || !mounted) return;
    await _service.setReminderTime(picked.hour, picked.minute);
    if (mounted) setState(() => _time = picked);
  }

  @override
  Widget build(BuildContext context) {
    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '일일 학습 알림',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.text,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '매일 지정한 시각에 오늘 학습 알림을 보냅니다. (기기 로컬 알림)',
            style: TextStyle(
              color: AppColors.muted,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                '알림 받기',
                style: TextStyle(
                  color: AppColors.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
              activeThumbColor: AppColors.primary,
              value: _enabled,
              onChanged: _onToggle,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.schedule_rounded,
                color: AppColors.primary,
              ),
              title: const Text(
                '알림 시각',
                style: TextStyle(
                  color: AppColors.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
              trailing: Text(
                _formatTime(_time),
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
              onTap: _enabled ? _pickTime : null,
            ),
          ],
        ],
      ),
    );
  }
}

/// 마이페이지 하단 로그아웃 카드. 듀오링고 스타일의 붉은 계열 버튼으로 표시한다.
class _LogoutCard extends StatelessWidget {
  const _LogoutCard({required this.onLogout});

  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '계정',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.text,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          // 듀오링고 스타일: 빨간 테두리 아웃라인 버튼
          OutlinedButton.icon(
            onPressed: onLogout,
            icon: const Icon(Icons.logout_rounded, color: AppColors.error),
            label: const Text(
              '로그아웃',
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.w800,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.error, width: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class LearningRecordScreen extends StatelessWidget {
  const LearningRecordScreen({
    super.key,
    required this.activities,
    required this.attempts,
  });

  final List<LearningActivity> activities;
  final List<TestAttemptSummary> attempts;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.bgTop, AppColors.bgBottom],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
                    sliver: SliverToBoxAdapter(
                      child: _Surface(
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.arrow_back_rounded),
                              tooltip: '뒤로가기',
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '학습 기록',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    color: AppColors.text,
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
                    sliver: SliverList.list(
                      children: [
                        _RecordSection(
                          title: '활동 내역',
                          emptyText: '아직 학습 활동이 없습니다.',
                          rows: [
                            for (final activity in activities) activity.label,
                          ],
                        ),
                        const SizedBox(height: 14),
                        _RecordSection(
                          title: '테스트 점수',
                          emptyText: '아직 테스트 결과가 없습니다.',
                          rows: [
                            for (final attempt in attempts)
                              '${attempt.scorePercent}% - ${attempt.passedCount}/${attempt.totalCount} 정답',
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RecordSection extends StatelessWidget {
  const _RecordSection({
    required this.title,
    required this.emptyText,
    required this.rows,
  });

  final String title;
  final String emptyText;
  final List<String> rows;

  @override
  Widget build(BuildContext context) {
    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.text,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          if (rows.isEmpty)
            Text(
              emptyText,
              style: const TextStyle(
                color: AppColors.muted,
                fontWeight: FontWeight.w700,
              ),
            )
          else
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.success,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        row,
                        style: const TextStyle(
                          color: AppColors.text,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

/// 듀오링고 스타일 카드 컨테이너. 그림자를 활용해 입체감을 준다.
class _Surface extends StatelessWidget {
  const _Surface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      elevation: 3,
      shadowColor: Colors.black12,
      child: Padding(padding: const EdgeInsets.all(18), child: child),
    );
  }
}
