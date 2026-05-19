import 'package:flutter/material.dart';

import '../data/api_client.dart';
import '../theme/app_colors.dart';
import '../widgets/app_icon_header.dart';
import 'learn_screen.dart';
import 'my_page_screen.dart';
import 'test_screen.dart';

/// JSP/Servlet 랭킹 화면 구조를 앱 UI로 옮긴 페이지다.
/// 순위/닉네임/누적점수를 표시하고, 상위 3명은 메달 스타일로 강조한다.
class RankingScreen extends StatefulWidget {
  const RankingScreen({super.key, required this.onLogout});

  final VoidCallback onLogout;

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen> {
  final BabyhandsApiClient _apiClient = BabyhandsApiClient();
  final ScrollController _scrollController = ScrollController();
  final List<_RankingItem> _rankings = [];
  _RankingItem? _myRanking;
  int _offset = 0;
  int _total = 0;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadInitial();
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _isLoadingMore || _isLoading) {
      return;
    }
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 240) {
      _loadMore();
    }
  }

  Future<void> _loadInitial() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _offset = 0;
      _total = 0;
      _rankings.clear();
      _myRanking = null;
    });

    try {
      final data = await _apiClient.rankingsPage(offset: 0, limit: 20);
      final rows = data['rankings'] as List<dynamic>? ?? const [];
      final total = _toInt(data['total']);
      final mineJson = data['mine'] as Map<String, dynamic>?;
      final items = [
        for (final row in rows)
          _RankingItem.fromJson(json: row as Map<String, dynamic>),
      ];
      setState(() {
        _rankings
          ..clear()
          ..addAll(items);
        _offset = items.length;
        _total = total;
        _myRanking =
            mineJson == null ? null : _RankingItem.fromJson(json: mineJson);
        _isLoading = false;
      });
    } catch (_) {
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_offset >= _total || _isLoadingMore || _isLoading) return;

    setState(() => _isLoadingMore = true);
    try {
      final data = await _apiClient.rankingsPage(offset: _offset, limit: 20);
      final rows = data['rankings'] as List<dynamic>? ?? const [];
      final items = [
        for (final row in rows)
          _RankingItem.fromJson(json: row as Map<String, dynamic>),
      ];
      setState(() {
        _rankings.addAll(items);
        _offset += items.length;
        _total = _toInt(data['total']);
        _isLoadingMore = false;
      });
    } catch (_) {
      setState(() => _isLoadingMore = false);
    }
  }

  int _toInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  void _goToLearn() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => LearnScreen(onLogout: widget.onLogout),
      ),
    );
  }

  void _goToTest() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => TestScreen(onLogout: widget.onLogout),
      ),
    );
  }

  void _goToHome() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _goToMyPage() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => MyPageScreen(onLogout: widget.onLogout),
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
                      child: _isLoading
                          ? const _Surface(
                              child: Center(child: CircularProgressIndicator()),
                            )
                          : _hasError
                          ? _ErrorPanel(onRetry: _loadInitial)
                          : _RankingBoard(
                              rankings: _rankings,
                              mine: _myRanking,
                              total: _total,
                              isLoadingMore: _isLoadingMore,
                              controller: _scrollController,
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
        selected: AppNavItem.ranking,
        onHome: _goToHome,
        onLearn: _goToLearn,
        onTest: _goToTest,
        onRanking: () {},
        onMyPage: _goToMyPage,
      ),
    );
  }
}

/// 랭킹 표 본문과 내 순위 카드를 렌더링한다.
class _RankingBoard extends StatelessWidget {
  const _RankingBoard({
    required this.rankings,
    required this.mine,
    required this.total,
    required this.isLoadingMore,
    required this.controller,
  });

  final List<_RankingItem> rankings;
  final _RankingItem? mine;
  final int total;
  final bool isLoadingMore;
  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    final nickname = AuthSession.instance.member?.nickname;

    return _Surface(
      child: Column(
        children: [
          Text(
            '랭킹',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppColors.text,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: const Row(
              children: [
                SizedBox(
                  width: 64,
                  child: Text(
                    '순위',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.muted,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    '닉네임',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.muted,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                SizedBox(
                  width: 92,
                  child: Text(
                    '누적점수',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: AppColors.muted,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (rankings.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Text(
                '랭킹 데이터가 없습니다.',
                style: TextStyle(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 420),
              child: Scrollbar(
                controller: controller,
                child: ListView.separated(
                  controller: controller,
                  itemCount: rankings.length + (isLoadingMore ? 1 : 0),
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    if (index >= rankings.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final row = rankings[index];
                    return _RankingRow(item: row);
                  },
                ),
              ),
            ),
          const SizedBox(height: 12),
          _MyRankCard(mine: mine, nickname: nickname),
          const SizedBox(height: 6),
          Text(
            '총 $total명 중 ${rankings.length}명 표시',
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// 랭킹 한 줄 UI를 그린다.
class _RankingRow extends StatelessWidget {
  const _RankingRow({required this.item});

  final _RankingItem item;

  @override
  Widget build(BuildContext context) {
    final bg = switch (item.rank) {
      1 => const Color(0xFFE9FFE4),
      2 => const Color(0xFFF1FFE9),
      3 => const Color(0xFFF9FFEF),
      _ => Colors.white,
    };

    final border = switch (item.rank) {
      1 => const Color(0xFFB8ECB5),
      2 => const Color(0xFFCCEAC3),
      3 => const Color(0xFFE3F3CC),
      _ => AppColors.border,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(
              '${item.rank}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Expanded(
            child: item.rank <= 3
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        item.medal,
                        style: const TextStyle(fontSize: 18),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          item.nickname,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.text,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  )
                : Text(
                    item.nickname,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
          SizedBox(
            width: 92,
            child: Text(
              '${item.bestScore}',
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 로그인한 사용자의 랭킹을 하단 카드로 보여준다.
class _MyRankCard extends StatelessWidget {
  const _MyRankCard({required this.mine, required this.nickname});

  final _RankingItem? mine;
  final String? nickname;

  @override
  Widget build(BuildContext context) {
    final left = nickname == null ? '내 순위' : '$nickname 님의 순위';
    final right = mine == null ? '집계 전' : '${mine!.rank}위 / ${mine!.bestScore}점';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF3FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFC5DBF6)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              left,
              style: const TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            right,
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

/// 랭킹 로드 실패 시 재시도 UI를 보여준다.
class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _Surface(
      child: Column(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.primary,
            size: 36,
          ),
          const SizedBox(height: 10),
          Text(
            '랭킹을 불러올 수 없어요',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.text,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '네트워크를 확인한 뒤 다시 시도해주세요.',
            style: TextStyle(
              color: AppColors.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('다시 시도'),
          ),
        ],
      ),
    );
  }
}

/// 랭킹 API 응답을 UI 친화 모델로 변환한다.
class _RankingItem {
  const _RankingItem({
    required this.rank,
    required this.nickname,
    required this.bestScore,
    required this.testCount,
  });

  final int rank;
  final String nickname;
  final int bestScore;
  final int testCount;

  String get medal => switch (rank) {
        1 => '🥇',
        2 => '🥈',
        3 => '🥉',
        _ => '',
      };

  factory _RankingItem.fromJson({required Map<String, dynamic> json}) {
    final nickname = (json['nickname'] as String?)?.trim();
    return _RankingItem(
      rank: _toInt(json['rankNo']),
      nickname: (nickname == null || nickname.isEmpty) ? '알 수 없음' : nickname,
      bestScore: _toInt(json['bestScore']),
      testCount: _toInt(json['testCount']),
    );
  }

  static int _toInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}

/// 마이페이지와 톤을 맞춘 공통 카드 래퍼다.
class _Surface extends StatelessWidget {
  const _Surface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: child,
      ),
    );
  }
}
