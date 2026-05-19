import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../data/home_progress_repository.dart';
import '../data/letter_catalog.dart';
import '../theme/app_colors.dart';
import '../widgets/app_icon_header.dart';
import 'home_screen.dart';
import 'learn_screen.dart';
import 'my_page_screen.dart';
import 'ranking_screen.dart';

class TestScreen extends StatefulWidget {
  const TestScreen({super.key, required this.onLogout});

  final VoidCallback onLogout;

  @override
  State<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  int _index = 0;
  String? _selectedOption;
  final List<String?> _selectedAnswers = [];
  final List<_QuizQuestion> _quizQuestions = [];
  final List<bool> _submittedQuestions = [];
  int _attemptCount = 0;
  int _correctCount = 0;
  final AppHomeProgressRepository _repository =
      AppHomeProgressRepository.instance;
  VideoPlayerController? _videoController;
  bool _videoLoading = false;
  bool _submittingAnswer = false;

  @override
  void initState() {
    super.initState();
    _addNextQuestion();
    _prepareQuestionVideo();
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  /// 무한 테스트를 위해 다음 문제를 1개씩 생성한다.
  void _addNextQuestion() {
    final letters = [
      for (final resource in LetterCatalog.resources) resource.letter,
    ];
    final target = letters[Random().nextInt(letters.length)];
    _quizQuestions.add(
      _QuizQuestion.create(
        index: _quizQuestions.length,
        target: target,
        allLetters: letters,
      ),
    );
    _selectedAnswers.add(null);
    _submittedQuestions.add(false);
    _selectedOption = _selectedAnswers[_index];
  }

  /// 지문자 규칙(consonant1=ㄱ, vowel1=ㅏ)에 맞는 영상 파일명을 계산한다.
  String _videoFileNameForLetter(String letter) {
    final consonantIndex = LetterCatalog.consonants.indexOf(letter);
    if (consonantIndex >= 0) {
      return 'consonant${consonantIndex + 1}.mp4';
    }
    final vowelIndex = LetterCatalog.vowels.indexOf(letter);
    if (vowelIndex >= 0) {
      return 'vowel${vowelIndex + 1}.mp4';
    }
    return 'consonant1.mp4';
  }

  /// 현재 문제의 영상 asset으로 플레이어를 다시 초기화한다.
  Future<void> _prepareQuestionVideo() async {
    if (_quizQuestions.isEmpty || !mounted) return;
    final fileName = _videoFileNameForLetter(_quizQuestions[_index].target);
    final assetPath = 'assets/videos/$fileName';

    setState(() => _videoLoading = true);
    final old = _videoController;
    final controller = VideoPlayerController.asset(assetPath);
    await old?.dispose();

    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.play();
      if (!mounted) return;
      setState(() {
        _videoController = controller;
        _videoLoading = false;
      });
    } catch (_) {
      await controller.dispose();
      if (!mounted) return;
      setState(() {
        _videoController = null;
        _videoLoading = false;
      });
    }
  }

  void _submitChoice(String selectedLetter) {
    if (_submittedQuestions[_index]) return;
    setState(() {
      _selectedAnswers[_index] = selectedLetter;
      _selectedOption = selectedLetter;
    });
  }

  void _next() {
    if (_index == _quizQuestions.length - 1) {
      setState(() {
        _addNextQuestion();
        _index++;
        _selectedOption = _selectedAnswers[_index];
      });
      _prepareQuestionVideo();
      return;
    }
    setState(() {
      _index++;
      _selectedOption = _selectedAnswers[_index];
    });
    _prepareQuestionVideo();
  }

  /// 현재 문제의 선택 결과를 서버에 즉시 저장한다.
  Future<void> _submitCurrentQuestion() async {
    final question = _quizQuestions[_index];
    final selectedLetter = _selectedAnswers[_index];
    if (selectedLetter == null) return;
    final accuracy = selectedLetter == question.target ? 100 : 60;
    await _repository.submitSingleTestResult(
      letter: question.target,
      selectedLetter: selectedLetter,
      accuracy: accuracy,
    );
  }

  /// 다음 버튼 동작: 정오답 확인 후 다음 문제로 이동한다.
  Future<void> _handleNextPressed() async {
    if (_submittingAnswer || _selectedOption == null) return;
    final alreadySubmitted = _submittedQuestions[_index];
    setState(() => _submittingAnswer = true);
    try {
      if (!alreadySubmitted) {
        await _submitCurrentQuestion();
        final isCorrect =
            _selectedAnswers[_index] == _quizQuestions[_index].target;
        setState(() {
          _submittedQuestions[_index] = true;
          _attemptCount++;
          if (isCorrect) {
            _correctCount++;
          }
        });
        // 정오답 피드백을 충분히 인지할 수 있도록 1초 대기한다.
        await Future<void>.delayed(const Duration(seconds: 1));
      }
      _next();
    } finally {
      if (mounted) {
        setState(() => _submittingAnswer = false);
      }
    }
  }

  void _openLearn({String? initialLetter}) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => LearnScreen(
          onLogout: widget.onLogout,
          initialLetter: initialLetter,
        ),
      ),
    );
  }

  void _openMyPage() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => MyPageScreen(onLogout: widget.onLogout),
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

  void _openRanking() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => RankingScreen(onLogout: widget.onLogout),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final answeredCurrent = _selectedOption != null;
    final submittedCurrent = _submittedQuestions[_index];
    final solvedCount = _selectedAnswers
        .where((answer) => answer != null)
        .length;

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
                    sliver: SliverList.list(
                      children: [
                        _TestSummary(
                          current: _index + 1,
                          score: solvedCount,
                          attemptCount: _attemptCount,
                          correctCount: _correctCount,
                        ),
                        const SizedBox(height: 14),
                        _QuestionCard(
                          question: _quizQuestions[_index],
                          answered: answeredCurrent,
                          selectedOption: _selectedOption,
                          videoController: _videoController,
                          videoLoading: _videoLoading,
                          onSelect: _submitChoice,
                          onNext: _handleNextPressed,
                          submitting: _submittingAnswer,
                          submittedCurrent: submittedCurrent,
                          buttonLabel: submittedCurrent
                              ? '다음 문제로'
                              : '정답 확인하고 다음',
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
      bottomNavigationBar: AppBottomNavBar(
        selected: AppNavItem.test,
        onHome: _openHome,
        onLearn: _openLearn,
        onTest: () {},
        onRanking: _openRanking,
        onMyPage: _openMyPage,
      ),
    );
  }
}

class _QuizQuestion {
  const _QuizQuestion({required this.target, required this.options});

  final String target;
  final List<String> options;

  factory _QuizQuestion.create({
    required int index,
    required String target,
    required List<String> allLetters,
  }) {
    final distractors = <String>[
      for (final letter in allLetters)
        if (letter != target) letter,
    ];
    final start = (index * 3) % distractors.length;
    final picked = <String>[
      distractors[start],
      distractors[(start + 5) % distractors.length],
      distractors[(start + 11) % distractors.length],
      target,
    ];
    final rotateBy = index % picked.length;
    final options = [
      ...picked.sublist(rotateBy),
      ...picked.sublist(0, rotateBy),
    ];
    return _QuizQuestion(target: target, options: options);
  }
}

class _TestSummary extends StatelessWidget {
  const _TestSummary({
    required this.current,
    required this.score,
    required this.attemptCount,
    required this.correctCount,
  });

  final int current;
  final int score;
  final int attemptCount;
  final int correctCount;

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
        child: Row(
          children: [
            const Icon(Icons.fact_check_rounded, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '수어 지문자 테스트',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.text,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.question,
    required this.answered,
    required this.selectedOption,
    required this.videoController,
    required this.videoLoading,
    required this.onSelect,
    required this.onNext,
    required this.submitting,
    required this.submittedCurrent,
    required this.buttonLabel,
  });

  final _QuizQuestion question;
  final bool answered;
  final String? selectedOption;
  final VideoPlayerController? videoController;
  final bool videoLoading;
  final ValueChanged<String> onSelect;
  final Future<void> Function() onNext;
  final bool submitting;
  final bool submittedCurrent;
  final String buttonLabel;

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '영상으로 제시된 지문자를 선택하세요',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.text,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 14),
            AspectRatio(
              aspectRatio: 16 / 9,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: videoLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    : (videoController != null &&
                          videoController!.value.isInitialized)
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: FittedBox(
                              fit: BoxFit.cover,
                              child: SizedBox(
                                width: videoController!.value.size.width,
                                height: videoController!.value.size.height,
                                child: VideoPlayer(videoController!),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.video_file_rounded,
                              color: Colors.white70,
                              size: 46,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '영상 로드 실패',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: question.options.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.9,
              ),
              itemBuilder: (context, index) {
                final option = question.options[index];
                final isSelected = selectedOption == option;
                final isCorrectOption = option == question.target;
                final isWrongSelected =
                    submittedCurrent && isSelected && !isCorrectOption;
                final isCorrectHighlighted =
                    submittedCurrent && isCorrectOption;
                final tileColor = isCorrectHighlighted
                    ? const Color(0xFFDCFCE7)
                    : isWrongSelected
                    ? const Color(0xFFFEE2E2)
                    : (isSelected ? const Color(0xFFE0F2FE) : Colors.white);
                final borderColor = isCorrectHighlighted
                    ? const Color(0xFF16A34A)
                    : isWrongSelected
                    ? const Color(0xFFDC2626)
                    : (isSelected ? AppColors.primary : AppColors.border);
                return Material(
                  color: tileColor,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    onTap: submittedCurrent ? null : () => onSelect(option),
                    borderRadius: BorderRadius.circular(14),
                    child: Ink(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: borderColor,
                          width: isSelected ? 2.4 : 1.5,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          option,
                          style: const TextStyle(
                            color: AppColors.text,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            Text(
              submitting
                  ? '선택한 답안을 저장하고 있습니다...'
                  : submittedCurrent
                  ? '정오답 확인이 완료되었습니다. 다음 문제로 이동하세요.'
                  : '다음을 누르면 1초 하이라이트로 정오답을 보여준 뒤 다음 문제로 이동합니다.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: (answered && !submitting)
                  ? () {
                      unawaited(onNext());
                    }
                  : null,
              icon: const Icon(Icons.arrow_forward_rounded),
              label: Text(submitting ? '채점 중...' : buttonLabel),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
