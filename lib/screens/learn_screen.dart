import 'dart:async';
import 'dart:convert';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:video_player/video_player.dart';

import '../core/app_logger.dart';
import '../data/accuracy_recognition_service.dart';
import '../data/home_progress_repository.dart';
import '../data/letter_catalog.dart';
import '../theme/app_colors.dart';
import '../widgets/app_icon_header.dart';
import '../widgets/camera_preview_box.dart';
import '../widgets/letter_picker.dart';
import 'home_screen.dart';
import 'my_page_screen.dart';
import 'ranking_screen.dart';
import 'test_screen.dart';

class LearnScreen extends StatefulWidget {
  const LearnScreen({super.key, required this.onLogout, this.initialLetter});

  final VoidCallback onLogout;
  final String? initialLetter;

  @override
  State<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen> {
  static const int _targetAccuracy = 80;
  static const int _requiredHoldSeconds = 3;

  String _selected = LetterCatalog.consonants.first;
  int _accuracy = 0;
  int _holdSeconds = 0;
  int _recognitionTick = 0;
  bool _cameraPermissionGranted = false;
  bool _cameraPreviewActive = false;
  bool _cameraLoading = false;
  bool _recognizing = false;
  bool _measuringAccuracy = false;
  String? _cameraError;
  late Set<String> _learned;
  Timer? _recognitionTimer;
  CameraController? _cameraController;
  final AppHomeProgressRepository _repository =
      AppHomeProgressRepository.instance;
  final AccuracyRecognitionService _recognitionService =
      ApiAccuracyRecognitionService();

  @override
  void initState() {
    super.initState();
    _selected = widget.initialLetter ?? LetterCatalog.consonants.first;
    _learned = _repository.completedLetters();
    _accuracy = _repository.bestAccuracyFor(_selected);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_startRecognition());
    });
  }

  void _selectLetter(String letter) {
    _stopRecognition();
    setState(() {
      _selected = letter;
      _accuracy = _repository.bestAccuracyFor(letter);
      _holdSeconds = 0;
    });
    unawaited(_startRecognition());
  }

  /// 선택한 글자에 대응하는 학습 가이드 영상 파일명을 계산한다.
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

  Future<void> _requestCameraAccess() async {
    setState(() {
      _cameraLoading = true;
      _cameraError = null;
    });

    final permission = await Permission.camera.request();
    if (!mounted) return;
    if (!permission.isGranted) {
      appLogger.w('카메라 권한 거부됨 (status: $permission)');
      setState(() {
        _cameraLoading = false;
        _cameraPermissionGranted = false;
        _cameraPreviewActive = false;
        _cameraError = '카메라 권한이 필요합니다.';
      });
      return;
    }

    try {
      final cameras = await availableCameras();
      if (!mounted) return;
      if (cameras.isEmpty) {
        appLogger.w('사용 가능한 카메라 없음');
        setState(() {
          _cameraLoading = false;
          _cameraPermissionGranted = true;
          _cameraPreviewActive = false;
          _cameraError = '이 기기에서 카메라를 찾을 수 없습니다.';
        });
        return;
      }

      final selectedCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        selectedCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }

      final previousController = _cameraController;
      _cameraController = controller;
      await previousController?.dispose();

      appLogger.i('카메라 초기화 완료 (${selectedCamera.name})');
      setState(() {
        _cameraLoading = false;
        _cameraPermissionGranted = true;
        _cameraPreviewActive = true;
        _cameraError = null;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('카메라 준비가 완료되었습니다.')));
      if (!_recognizing) {
        unawaited(_startRecognition());
      }
    } on CameraException catch (e) {
      appLogger.e('카메라 초기화 실패 (CameraException)', error: e);
      if (!mounted) return;
      setState(() {
        _cameraLoading = false;
        _cameraPermissionGranted = true;
        _cameraPreviewActive = false;
        _cameraError = e.description ?? '카메라 미리보기에 실패했습니다.';
      });
    } catch (e, st) {
      appLogger.e('카메라 프리뷰 오류', error: e, stackTrace: st);
      if (!mounted) return;
      setState(() {
        _cameraLoading = false;
        _cameraPermissionGranted = true;
        _cameraPreviewActive = false;
        _cameraError = '카메라 미리보기에 실패했습니다.';
      });
    }
  }

  Future<void> _startRecognition() async {
    if (!_cameraPermissionGranted ||
        _cameraController == null ||
        !_cameraController!.value.isInitialized) {
      await _requestCameraAccess();
    }
    if (!mounted ||
        _cameraController == null ||
        !_cameraController!.value.isInitialized) {
      return;
    }

    _stopRecognition();
    setState(() {
      _recognitionTick = 0;
      _holdSeconds = 0;
      _recognizing = true;
      _cameraPreviewActive = true;
    });

    _recognitionTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (_measuringAccuracy) return;
      _measuringAccuracy = true;
      try {
        final frameBase64 = await _captureFrameBase64();
        if (frameBase64 == null || frameBase64.isEmpty) {
          if (!mounted) return;
          setState(() {
            _accuracy = 0;
            _holdSeconds = 0;
            _recognitionTick++;
          });
          return;
        }

        final nextAccuracy = await _recognitionService.measureAccuracy(
          letter: _selected,
          attemptIndex: _recognitionTick,
          imageBase64: frameBase64,
        );
        if (!mounted) return;
        _repository.recordRecognitionResult(_selected, nextAccuracy);
        final nextHoldSeconds = nextAccuracy >= _targetAccuracy
            ? _holdSeconds + 1
            : 0;

        setState(() {
          _accuracy = nextAccuracy;
          _holdSeconds = nextHoldSeconds;
          _recognitionTick++;
        });

        if (nextHoldSeconds >= _requiredHoldSeconds) {
          _completeLearning(nextAccuracy);
        }
      } catch (e, st) {
        // 인식 오류 시 정확도/유지시간을 리셋하고 다음 틱에서 재시도한다.
        appLogger.e('인식 측정 오류 (letter: $_selected)', error: e, stackTrace: st);
        if (!mounted) return;
        setState(() {
          _accuracy = 0;
          _holdSeconds = 0;
          _recognitionTick++;
        });
      } finally {
        _measuringAccuracy = false;
      }
    });
  }

  Future<String?> _captureFrameBase64() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) {
      return null;
    }
    if (controller.value.isTakingPicture) {
      return null;
    }

    final frame = await controller.takePicture();
    final bytes = await frame.readAsBytes();
    if (bytes.isEmpty) return null;
    return base64Encode(bytes);
  }

  void _completeLearning(int accuracy) {
    _repository.recordLessonCompleted(_selected, accuracy: accuracy);
    _stopRecognition();
    setState(() {
      _learned = _repository.completedLetters();
      _accuracy = accuracy;
      _holdSeconds = _requiredHoldSeconds;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$_selected 학습 완료!')));
  }

  void _stopRecognition() {
    _recognitionTimer?.cancel();
    _recognitionTimer = null;
    _measuringAccuracy = false;
    if (mounted && _recognizing) {
      setState(() {
        _recognizing = false;
      });
    }
  }

  void _openTest() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => TestScreen(onLogout: widget.onLogout),
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
              constraints: const BoxConstraints(maxWidth: 920),
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
                    sliver: SliverList.list(
                      children: [
                        _LearningHeader(selected: _selected),
                        const SizedBox(height: 14),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final wide = constraints.maxWidth >= 760;
                            final picker = LetterPicker(
                              consonants: LetterCatalog.consonants,
                              vowels: LetterCatalog.vowels,
                              selected: _selected,
                              learned: _learned,
                              onSelect: _selectLetter,
                            );
                            final panel = _PracticePanel(
                              resource: LetterCatalog.find(_selected),
                              guideVideoAssetPath:
                                  'assets/videos/${_videoFileNameForLetter(_selected)}',
                              accuracy: _accuracy,
                              holdSeconds: _holdSeconds,
                              targetAccuracy: _targetAccuracy,
                              requiredHoldSeconds: _requiredHoldSeconds,
                              cameraPermissionGranted: _cameraPermissionGranted,
                              cameraPreviewActive: _cameraPreviewActive,
                              cameraLoading: _cameraLoading,
                              cameraError: _cameraError,
                              cameraController: _cameraController,
                              recognizing: _recognizing,
                              onRequestCamera: _requestCameraAccess,
                            );

                            if (!wide) {
                              return Column(
                                children: [
                                  picker,
                                  const SizedBox(height: 14),
                                  panel,
                                ],
                              );
                            }

                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(width: 246, child: picker),
                                const SizedBox(width: 14),
                                Expanded(child: panel),
                              ],
                            );
                          },
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
        selected: AppNavItem.learn,
        onHome: _openHome,
        onLearn: () {},
        onTest: _openTest,
        onRanking: _openRanking,
        onMyPage: _openMyPage,
      ),
    );
  }

  @override
  void dispose() {
    _recognitionTimer?.cancel();
    _cameraController?.dispose();
    super.dispose();
  }
}

class _LearningHeader extends StatelessWidget {
  const _LearningHeader({required this.selected});

  final String selected;

  @override
  Widget build(BuildContext context) {
    return _Surface(
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7D6),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.school_rounded,
              color: Color(0xFFD97706),
              size: 32,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '지문자 학습',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.text,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '현재 학습 글자: $selected',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w700,
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

class _PracticePanel extends StatelessWidget {
  const _PracticePanel({
    required this.resource,
    required this.guideVideoAssetPath,
    required this.accuracy,
    required this.holdSeconds,
    required this.targetAccuracy,
    required this.requiredHoldSeconds,
    required this.cameraPermissionGranted,
    required this.cameraPreviewActive,
    required this.cameraLoading,
    required this.cameraError,
    required this.cameraController,
    required this.recognizing,
    required this.onRequestCamera,
  });

  final LetterLearningResource resource;
  final String guideVideoAssetPath;
  final int accuracy;
  final int holdSeconds;
  final int targetAccuracy;
  final int requiredHoldSeconds;
  final bool cameraPermissionGranted;
  final bool cameraPreviewActive;
  final bool cameraLoading;
  final String? cameraError;
  final CameraController? cameraController;
  final bool recognizing;
  final VoidCallback onRequestCamera;

  @override
  Widget build(BuildContext context) {
    final holdProgress = holdSeconds / requiredHoldSeconds;

    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 560;
              final learning = _LearningGuideBox(
                resource: resource,
                videoAssetPath: guideVideoAssetPath,
                icon: Icons.smart_display_rounded,
              );
              final camera = CameraPreviewBox(
                title: '카메라 인식',
                icon: Icons.videocam_rounded,
                permissionGranted: cameraPermissionGranted,
                previewActive: cameraPreviewActive,
                loading: cameraLoading,
                error: cameraError,
                controller: cameraController,
                recognizing: recognizing,
              );

              if (!wide) {
                return Column(
                  children: [learning, const SizedBox(height: 12), camera],
                );
              }

              return Row(
                children: [
                  Expanded(child: learning),
                  const SizedBox(width: 12),
                  Expanded(child: camera),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const Text(
                '정확도',
                style: TextStyle(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: accuracy / 100,
                    minHeight: 10,
                    backgroundColor: const Color(0xFFE2E8F0),
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 44,
                child: Text(
                  '$accuracy%',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text(
                '유지 시간',
                style: TextStyle(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: holdProgress.clamp(0, 1),
                    minHeight: 10,
                    backgroundColor: const Color(0xFFE2E8F0),
                    color: accuracy >= targetAccuracy
                        ? AppColors.success
                        : AppColors.accent,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 44,
                child: Text(
                  '$holdSeconds/$requiredHoldSeconds',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (!cameraPermissionGranted)
            FilledButton.icon(
              onPressed: onRequestCamera,
              icon: const Icon(Icons.videocam_rounded),
              label: const Text('카메라 권한 허용'),
              style: _primaryButtonStyle(),
            )
          else if (recognizing)
            const SizedBox.shrink()
          else
            const Text(
              '자동 인식 대기 중',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }

  ButtonStyle _primaryButtonStyle() {
    return FilledButton.styleFrom(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      minimumSize: const Size.fromHeight(48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );
  }
}

class _LearningGuideBox extends StatelessWidget {
  const _LearningGuideBox({
    required this.resource,
    required this.videoAssetPath,
    required this.icon,
  });

  final LetterLearningResource resource;
  final String videoAssetPath;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '학습 가이드',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        AspectRatio(
          aspectRatio: 4 / 3,
          child: _GuideVideoPlayer(
            videoAssetPath: videoAssetPath,
            fallbackIcon: icon,
            fallbackLetter: resource.letter,
            fallbackName: resource.name,
          ),
        ),
      ],
    );
  }
}

/// 학습 가이드 영상을 재생하고, 실패 시 글자 가이드를 대체 표시한다.
class _GuideVideoPlayer extends StatefulWidget {
  const _GuideVideoPlayer({
    required this.videoAssetPath,
    required this.fallbackIcon,
    required this.fallbackLetter,
    required this.fallbackName,
  });

  final String videoAssetPath;
  final IconData fallbackIcon;
  final String fallbackLetter;
  final String fallbackName;

  @override
  State<_GuideVideoPlayer> createState() => _GuideVideoPlayerState();
}

class _GuideVideoPlayerState extends State<_GuideVideoPlayer> {
  VideoPlayerController? _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadVideo();
  }

  @override
  void didUpdateWidget(covariant _GuideVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoAssetPath != widget.videoAssetPath) {
      _loadVideo();
    }
  }

  Future<void> _loadVideo() async {
    setState(() => _loading = true);
    final previous = _controller;
    final controller = VideoPlayerController.asset(widget.videoAssetPath);
    _controller = controller;
    await previous?.dispose();
    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.play();
    } catch (_) {
      await controller.dispose();
      if (mounted) {
        _controller = null;
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final hasVideo = controller != null && controller.value.isInitialized;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : hasVideo
          ? ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: controller.value.size.width,
                  height: controller.value.size.height,
                  child: VideoPlayer(controller),
                ),
              ),
            )
          : Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _LetterGuidePainter(widget.fallbackLetter),
                  ),
                ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        widget.fallbackIcon,
                        size: 34,
                        color: AppColors.primary,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.fallbackLetter,
                        style: const TextStyle(
                          color: AppColors.text,
                          fontWeight: FontWeight.w900,
                          fontSize: 52,
                        ),
                      ),
                      Text(
                        widget.fallbackName,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontWeight: FontWeight.w800,
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

class _GuideSummary extends StatelessWidget {
  const _GuideSummary({required this.resource});

  final LetterLearningResource resource;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            resource.guide,
            style: const TextStyle(
              color: AppColors.text,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tip in resource.tips)
                Chip(
                  label: Text(tip),
                  visualDensity: VisualDensity.compact,
                  side: const BorderSide(color: AppColors.border),
                  backgroundColor: Colors.white,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LetterGuidePainter extends CustomPainter {
  const _LetterGuidePainter(this.letter);

  final String letter;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.22)
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round;
    final center = Offset(size.width * 0.5, size.height * 0.55);
    final radius = size.shortestSide * 0.2;

    if (letter == '\u3147' || letter == '\u314E') {
      canvas.drawCircle(center, radius, paint..style = PaintingStyle.stroke);
      return;
    }

    if (letter == '\u3161') {
      canvas.drawLine(
        Offset(size.width * 0.25, center.dy),
        Offset(size.width * 0.75, center.dy),
        paint,
      );
      return;
    }

    if (letter == '\u3163') {
      canvas.drawLine(
        Offset(center.dx, size.height * 0.25),
        Offset(center.dx, size.height * 0.82),
        paint,
      );
      return;
    }

    canvas.drawLine(
      Offset(size.width * 0.34, size.height * 0.72),
      Offset(size.width * 0.5, size.height * 0.28),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.5, size.height * 0.28),
      Offset(size.width * 0.68, size.height * 0.72),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _LetterGuidePainter oldDelegate) {
    return oldDelegate.letter != letter;
  }
}

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
      child: Padding(padding: const EdgeInsets.all(18), child: child),
    );
  }
}
