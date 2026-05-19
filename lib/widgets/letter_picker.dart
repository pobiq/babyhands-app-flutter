import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 자음/모음 전체 목록을 그리드로 보여주고 선택 상태를 표시하는 위젯이다.
class LetterPicker extends StatelessWidget {
  const LetterPicker({
    super.key,
    required this.consonants,
    required this.vowels,
    required this.selected,
    required this.learned,
    required this.onSelect,
  });

  final List<String> consonants;
  final List<String> vowels;
  final String selected;
  final Set<String> learned;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final isConsonantSelected = consonants.contains(selected);
    final currentType = isConsonantSelected
        ? _LetterType.consonant
        : _LetterType.vowel;
    final currentLetters = isConsonantSelected ? consonants : vowels;

    return _PickerSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: SegmentedButton<_LetterType>(
              segments: const [
                ButtonSegment<_LetterType>(
                  value: _LetterType.consonant,
                  label: Text('자음'),
                ),
                ButtonSegment<_LetterType>(
                  value: _LetterType.vowel,
                  label: Text('모음'),
                ),
              ],
              selected: {currentType},
              onSelectionChanged: (next) {
                final type = next.first;
                if (type == currentType) return;
                final targetLetters = type == _LetterType.consonant
                    ? consonants
                    : vowels;
                if (targetLetters.isNotEmpty) {
                  onSelect(targetLetters.first);
                }
              },
              style: ButtonStyle(
                textStyle: WidgetStateProperty.all(
                  const TextStyle(fontWeight: FontWeight.w800),
                ),
                foregroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return Colors.white;
                  }
                  return AppColors.text;
                }),
                backgroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return AppColors.primary;
                  }
                  return const Color(0xFFF8FAFC);
                }),
                side: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return const BorderSide(color: AppColors.primary);
                  }
                  return const BorderSide(color: AppColors.border);
                }),
              ),
            ),
          ),
          const SizedBox(height: 14),
          LetterGroup(
            title: currentType == _LetterType.consonant ? '자음' : '모음',
            letters: currentLetters,
            selected: selected,
            learned: learned,
            onSelect: onSelect,
          ),
        ],
      ),
    );
  }
}

/// 자음 또는 모음 그룹 하나를 제목과 함께 표시한다.
class LetterGroup extends StatelessWidget {
  const LetterGroup({
    super.key,
    required this.title,
    required this.letters,
    required this.selected,
    required this.learned,
    required this.onSelect,
  });

  final String title;
  final List<String> letters;
  final String selected;
  final Set<String> learned;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: letters.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1,
          ),
          itemBuilder: (context, index) {
            final letter = letters[index];
            return Align(
              alignment: Alignment.center,
              child: LetterButton(
                letter: letter,
                selected: selected == letter,
                learned: learned.contains(letter),
                onTap: () => onSelect(letter),
              ),
            );
          },
        ),
      ],
    );
  }
}

enum _LetterType { consonant, vowel }

/// 개별 글자 버튼이다. 선택 여부와 학습 완료 여부를 시각적으로 구분한다.
class LetterButton extends StatelessWidget {
  const LetterButton({
    super.key,
    required this.letter,
    required this.selected,
    required this.learned,
    required this.onTap,
  });

  final String letter;
  final bool selected;
  final bool learned;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: Text(
                letter,
                style: TextStyle(
                  color: selected ? Colors.white : AppColors.text,
                  fontWeight: FontWeight.w900,
                  fontSize: 26,
                ),
              ),
            ),
            // 학습 완료된 글자는 오른쪽 상단에 초록 점을 표시한다.
            if (learned)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// LetterPicker 전용 카드 Surface다.
class _PickerSurface extends StatelessWidget {
  const _PickerSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(padding: const EdgeInsets.all(18), child: child),
    );
  }
}
