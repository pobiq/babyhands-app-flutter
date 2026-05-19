import 'package:flutter/material.dart';

import '../core/asset_precache.dart';
import '../theme/app_colors.dart';

enum AppNavItem { home, learn, test, ranking, myPage }

/// 상단 헤더 내비게이션 (로그아웃 버튼은 마이페이지에서 제공)
class AppIconHeader extends StatelessWidget {
  const AppIconHeader({
    super.key,
    required this.selected,
    required this.onHome,
    required this.onLearn,
    required this.onTest,
    required this.onMyPage,
  });

  final AppNavItem selected;
  final VoidCallback onHome;
  final VoidCallback onLearn;
  final VoidCallback onTest;
  final VoidCallback onMyPage;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Image.asset(
              kBabyhandsHandIconAsset,
              width: 42,
              height: 42,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.waving_hand_rounded,
                color: AppColors.primary,
                size: 34,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Babyhands',
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.text,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                reverse: true,
                child: Row(
                  children: [
                    _HeaderIconButton(
                      icon: Icons.home_rounded,
                      tooltip: '홈',
                      selected: selected == AppNavItem.home,
                      onPressed: onHome,
                    ),
                    _HeaderIconButton(
                      icon: Icons.school_rounded,
                      tooltip: '학습',
                      selected: selected == AppNavItem.learn,
                      onPressed: onLearn,
                    ),
                    _HeaderIconButton(
                      icon: Icons.fact_check_rounded,
                      tooltip: '테스트',
                      selected: selected == AppNavItem.test,
                      onPressed: onTest,
                    ),
                    _HeaderIconButton(
                      icon: Icons.person_rounded,
                      tooltip: '마이페이지',
                      selected: selected == AppNavItem.myPage,
                      onPressed: onMyPage,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 메인 화면용 하단 탭 바. 듀오링고 스타일로 선택 상태를 강조한다.
/// 로그아웃 버튼은 마이페이지 화면 내부에 배치한다.
class AppBottomNavBar extends StatelessWidget {
  const AppBottomNavBar({
    super.key,
    required this.selected,
    required this.onHome,
    required this.onLearn,
    required this.onTest,
    required this.onRanking,
    required this.onMyPage,
  });

  final AppNavItem selected;
  final VoidCallback onHome;
  final VoidCallback onLearn;
  final VoidCallback onTest;
  final VoidCallback onRanking;
  final VoidCallback onMyPage;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 16,
      shadowColor: Colors.black26,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: _BottomNavItem(
                  icon: Icons.home_rounded,
                  label: '홈',
                  selected: selected == AppNavItem.home,
                  onPressed: onHome,
                ),
              ),
              Expanded(
                child: _BottomNavItem(
                  icon: Icons.school_rounded,
                  label: '학습',
                  selected: selected == AppNavItem.learn,
                  onPressed: onLearn,
                ),
              ),
              Expanded(
                child: _BottomNavItem(
                  icon: Icons.fact_check_rounded,
                  label: '테스트',
                  selected: selected == AppNavItem.test,
                  onPressed: onTest,
                ),
              ),
              Expanded(
                child: _BottomNavItem(
                  icon: Icons.leaderboard_rounded,
                  label: '랭킹',
                  selected: selected == AppNavItem.ranking,
                  onPressed: onRanking,
                ),
              ),
              Expanded(
                child: _BottomNavItem(
                  icon: Icons.person_rounded,
                  label: '마이',
                  selected: selected == AppNavItem.myPage,
                  onPressed: onMyPage,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 듀오링고 스타일 하단 탭 아이템.
/// 선택된 항목은 그린 아이콘·라벨 + 연한 그린 원형 배경으로 표시한다.
class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.muted;
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 선택 상태: 연한 그린 원형 배경 강조
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primary.withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 26, color: color),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.selected,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: tooltip,
      button: true,
      selected: selected,
      child: Tooltip(
        message: tooltip,
        child: Padding(
          padding: const EdgeInsets.only(left: 4),
          child: IconButton.filledTonal(
            onPressed: onPressed,
            isSelected: selected,
            icon: Icon(icon),
            selectedIcon: Icon(icon),
            style: IconButton.styleFrom(
              fixedSize: const Size.square(42),
              backgroundColor: selected
                  ? AppColors.primary
                  : const Color(0xFFF1F5F9),
              foregroundColor: selected ? Colors.white : AppColors.muted,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
