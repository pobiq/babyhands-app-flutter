import 'package:flutter/material.dart';

import '../data/api_client.dart';
import '../data/home_progress_repository.dart';
import '../theme/app_colors.dart';
import '../widgets/app_icon_header.dart';
import 'learn_screen.dart';
import 'my_page_screen.dart';
import 'ranking_screen.dart';
import 'test_screen.dart';

class HomeScreen extends StatefulWidget {
  HomeScreen({
    super.key,
    required this.onLogout,
    HomeProgressRepository? repository,
  }) : repository = repository ?? AppHomeProgressRepository.instance;

  final VoidCallback onLogout;
  final HomeProgressRepository repository;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DateTime _visibleMonth = DateTime.now();
  late Future<HomeDashboardData> _dashboardFuture;

  @override
  void initState() {
    super.initState();
    _dashboardFuture = widget.repository.loadDashboard();
    // ChangeNotifier 알림을 직접 구독해 학습/테스트 완료 시 자동으로 갱신한다.
    if (widget.repository is AppHomeProgressRepository) {
      (widget.repository as AppHomeProgressRepository)
          .addListener(_reloadDashboard);
    }
  }

  @override
  void dispose() {
    if (widget.repository is AppHomeProgressRepository) {
      (widget.repository as AppHomeProgressRepository)
          .removeListener(_reloadDashboard);
    }
    super.dispose();
  }

  void _goToLearn() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LearnScreen(onLogout: widget.onLogout),
      ),
    );
  }

  void _goToTest() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TestScreen(onLogout: widget.onLogout),
      ),
    );
  }

  void _goToMyPage() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MyPageScreen(onLogout: widget.onLogout),
      ),
    );
  }

  void _goToRanking() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RankingScreen(onLogout: widget.onLogout),
      ),
    );
  }

  void _reloadDashboard() {
    if (!mounted) return;
    setState(() {
      _dashboardFuture = widget.repository.loadDashboard();
    });
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
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
                    sliver: SliverToBoxAdapter(
                      child: FutureBuilder<HomeDashboardData>(
                        future: _dashboardFuture,
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return _StatusPanel(
                              icon: Icons.error_outline_rounded,
                              title: '화면을 불러올 수 없어요',
                              message: '네트워크를 확인한 뒤 다시 시도해주세요.',
                              onRetry: () => setState(() {
                                _dashboardFuture = widget.repository
                                    .loadDashboard();
                              }),
                            );
                          }

                          if (!snapshot.hasData) {
                            return const _StatusPanel(
                              icon: Icons.hourglass_top_rounded,
                              title: '불러오는 중',
                              message: '학습 진행 상황을 준비하고 있어요.',
                            );
                          }

                          return _HomeContent(
                            data: snapshot.data!,
                            visibleMonth: _visibleMonth,
                            isGuest: AuthSession.instance.isGuest,
                            onStart: _goToLearn,
                            onPrevMonth: () => setState(() {
                              _visibleMonth = DateTime(
                                _visibleMonth.year,
                                _visibleMonth.month - 1,
                              );
                            }),
                            onNextMonth: () => setState(() {
                              _visibleMonth = DateTime(
                                _visibleMonth.year,
                                _visibleMonth.month + 1,
                              );
                            }),
                            onToday: () => setState(() {
                              _visibleMonth = DateTime.now();
                            }),
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
        selected: AppNavItem.home,
        onHome: () {},
        onLearn: _goToLearn,
        onTest: _goToTest,
        onRanking: _goToRanking,
        onMyPage: _goToMyPage,
      ),
    );
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent({
    required this.data,
    required this.visibleMonth,
    required this.onStart,
    required this.onPrevMonth,
    required this.onNextMonth,
    required this.onToday,
    this.isGuest = false,
  });

  final HomeDashboardData data;
  final DateTime visibleMonth;
  final VoidCallback onStart;
  final VoidCallback onPrevMonth;
  final VoidCallback onNextMonth;
  final VoidCallback onToday;
  /// 게스트 모드일 때 true. 상단에 로그인 유도 배너를 표시한다.
  final bool isGuest;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (isGuest) const _GuestBanner(),
        if (isGuest) const SizedBox(height: 14),
        _WelcomePanel(onStart: onStart),
        const SizedBox(height: 14),
        _TodayGoalCard(data: data),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 680;
            final calendar = _CalendarCard(
              visibleMonth: visibleMonth,
              attendanceDates: data.attendanceDates,
              onPrev: onPrevMonth,
              onNext: onNextMonth,
              onToday: onToday,
            );
            final progress = _ProgressGrid(data: data);

            if (!wide) {
              return Column(
                children: [calendar, const SizedBox(height: 14), progress],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 7, child: calendar),
                const SizedBox(width: 14),
                Expanded(flex: 4, child: progress),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({
    required this.icon,
    required this.title,
    required this.message,
    this.onRetry,
  });

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return _Surface(
      child: Column(
        children: [
          Icon(icon, color: AppColors.primary, size: 38),
          const SizedBox(height: 10),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.text,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('다시 시도'),
            ),
          ],
        ],
      ),
    );
  }
}

class _WelcomePanel extends StatelessWidget {
  const _WelcomePanel({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return _Surface(
      child: Row(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: const Color(0xFFE0F2FE),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.waving_hand_rounded,
              color: AppColors.primary,
              size: 34,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '오늘도 Babyhands와 함께 연습해요',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.text,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '출석과 정확도를 기록하며 글자를 익혀 보세요.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _DuoButton(
            label: '시작',
            icon: Icons.play_arrow_rounded,
            onTap: onStart,
          ),
        ],
      ),
    );
  }
}

/// 듀오링고 스타일 3D 버튼. 누르면 아래로 4px 이동하며 그림자가 사라진다.
class _DuoButton extends StatefulWidget {
  const _DuoButton({
    required this.label,
    required this.onTap,
    this.icon,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  State<_DuoButton> createState() => _DuoButtonState();
}

class _DuoButtonState extends State<_DuoButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        transform: Matrix4.translationValues(0, _pressed ? 4 : 0, 0),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(14),
          boxShadow: _pressed
              ? []
              : const [
                  BoxShadow(
                    color: AppColors.primaryDark,
                    offset: Offset(0, 4),
                    blurRadius: 0,
                  ),
                ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.icon != null) ...[
              Icon(widget.icon, color: Colors.white, size: 20),
              const SizedBox(width: 6),
            ],
            Text(
              widget.label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayGoalCard extends StatelessWidget {
  const _TodayGoalCard({required this.data});

  final HomeDashboardData data;

  @override
  Widget build(BuildContext context) {
    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.flag_rounded, color: Color(0xFFD97706)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '오늘 목표',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.text,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '${data.todayCompletedCount}/${data.todayGoal.targetLetters}',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 듀오링고 스타일 두꺼운 진행 바
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 16,
              value: data.todayProgressPercent / 100,
              color: AppColors.primary,
              backgroundColor: const Color(0xFFDCFCE7),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '글자 ${data.todayGoal.targetLetters}개 · 정확도 목표 ${data.todayGoal.targetAccuracy}%',
            style: const TextStyle(
              color: AppColors.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarCard extends StatelessWidget {
  const _CalendarCard({
    required this.visibleMonth,
    required this.attendanceDates,
    required this.onPrev,
    required this.onNext,
    required this.onToday,
  });

  final DateTime visibleMonth;
  final Set<DateTime> attendanceDates;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(visibleMonth.year, visibleMonth.month);
    final daysInMonth = DateTime(
      visibleMonth.year,
      visibleMonth.month + 1,
      0,
    ).day;
    final leadingEmpty = firstDay.weekday - 1;
    final cells = <Widget>[
      for (var i = 0; i < leadingEmpty; i++) const SizedBox.shrink(),
      for (var day = 1; day <= daysInMonth; day++)
        _DayCell(
          day: day,
          checked: _containsDate(
            attendanceDates,
            DateTime(visibleMonth.year, visibleMonth.month, day),
          ),
          today: _isSameDay(
            DateTime.now(),
            DateTime(visibleMonth.year, visibleMonth.month, day),
          ),
        ),
    ];

    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '출석 캘린더',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.text,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              TextButton(onPressed: onToday, child: const Text('오늘')),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: onPrev,
                  icon: const Icon(Icons.chevron_left_rounded),
                  tooltip: '이전 달',
                ),
                Expanded(
                  child: Text(
                    '${visibleMonth.year}.${visibleMonth.month}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.text,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onNext,
                  icon: const Icon(Icons.chevron_right_rounded),
                  tooltip: '다음 달',
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const _WeekRow(),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: cells,
          ),
        ],
      ),
    );
  }

  static bool _containsDate(Set<DateTime> dates, DateTime target) {
    return dates.any((date) => _isSameDay(date, target));
  }

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _WeekRow extends StatelessWidget {
  const _WeekRow();

  @override
  Widget build(BuildContext context) {
    const labels = ['월', '화', '수', '목', '금', '토', '일'];
    return Row(
      children: [
        for (final label in labels)
          Expanded(
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: label == '일' ? Colors.deepOrange : AppColors.muted,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.checked,
    required this.today,
  });

  final int day;
  final bool checked;
  final bool today;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      // 듀오링고 스타일: 출석일은 그린 채움, 오늘은 두꺼운 테두리
      decoration: BoxDecoration(
        color: checked ? AppColors.primary : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: today ? AppColors.primary : AppColors.border,
          width: today ? 2 : 1,
        ),
      ),
      child: Center(
        child: checked
            ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
            : Text(
                '$day',
                style: TextStyle(
                  color: today ? AppColors.primary : AppColors.text,
                  fontWeight: today ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 13,
                ),
              ),
      ),
    );
  }
}

class _ProgressGrid extends StatelessWidget {
  const _ProgressGrid({required this.data});

  final HomeDashboardData data;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final half = (constraints.maxWidth - 14) / 2;
        final ring = (half - 36).clamp(88.0, 132.0);

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _ProgressCard(
                title: '오늘 진행률',
                percent: data.todayProgressPercent,
                subtitle: '글자 ${data.todayCompletedCount}개 완료',
                ringSize: ring,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _ProgressCard(
                title: '전체 진행률',
                percent: data.overallProgressPercent,
                subtitle:
                    '글자 ${data.completedLetterCount}/${data.letters.length}개',
                ringSize: ring,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.title,
    required this.percent,
    required this.subtitle,
    this.ringSize = 132,
  });

  final String title;
  final int percent;
  final String subtitle;
  final double ringSize;

  @override
  Widget build(BuildContext context) {
    final stroke = (ringSize / 132 * 13).clamp(8.0, 13.0);
    return _Surface(
      child: Column(
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppColors.text,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.muted,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: ringSize,
            height: ringSize,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: percent / 100,
                  strokeWidth: stroke,
                  backgroundColor: const Color(0xFFE2E8F0),
                  color: AppColors.primary,
                  strokeCap: StrokeCap.round,
                ),
                Center(
                  child: Text(
                    '$percent%',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.text,
                      fontWeight: FontWeight.w900,
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

/// 게스트 모드에서 로그인을 유도하는 안내 배너다.
class _GuestBanner extends StatelessWidget {
  const _GuestBanner();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFFF7ED),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFFED7AA)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded, color: Color(0xFFD97706)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '게스트 모드입니다. 진행 상황은 이 기기에만 저장됩니다. 서버 동기화·랭킹 반영은 로그인 후 이용할 수 있습니다.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF92400E),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 듀오링고 스타일 카드 컨테이너. 2px 테두리 + 하단 그림자로 입체감을 표현한다.
class _Surface extends StatelessWidget {
  const _Surface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E5E5), width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFFE5E5E5),
            offset: Offset(0, 4),
            blurRadius: 0,
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: child,
    );
  }
}
