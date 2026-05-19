import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 카메라 프리뷰와 인식 상태 오버레이를 표시하는 위젯이다.
/// 권한 미허가 / 로딩 / 에러 / 프리뷰 활성 각 상태를 시각적으로 구분한다.
class CameraPreviewBox extends StatelessWidget {
  const CameraPreviewBox({
    super.key,
    required this.title,
    required this.icon,
    required this.permissionGranted,
    required this.previewActive,
    required this.loading,
    required this.error,
    required this.controller,
    required this.recognizing,
  });

  final String title;
  final IconData icon;
  final bool permissionGranted;
  final bool previewActive;
  final bool loading;
  final String? error;
  final CameraController? controller;
  final bool recognizing;

  @override
  Widget build(BuildContext context) {
    final ready = controller != null && controller!.value.isInitialized;
    final label = loading
        ? 'Loading'
        : error != null
        ? 'Unavailable'
        : !permissionGranted
        ? 'Permission'
        : recognizing
        ? 'Scanning'
        : ready
        ? 'Live'
        : previewActive
        ? 'Preview'
        : 'Ready';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.text,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        AspectRatio(
          aspectRatio: 4 / 3,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF111827),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (ready) CameraPreview(controller!),
                  if (previewActive || ready) const CameraGridOverlay(),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (loading)
                          const SizedBox(
                            width: 30,
                            height: 30,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              color: Colors.white70,
                            ),
                          )
                        else
                          Icon(icon, size: 38, color: Colors.white70),
                        const SizedBox(height: 8),
                        Text(
                          label,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w900,
                            fontSize: 22,
                          ),
                        ),
                        if (error != null) ...[
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 카메라 화면 위에 3×3 격자 가이드라인을 그리는 위젯이다.
class CameraGridOverlay extends StatelessWidget {
  const CameraGridOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _CameraGridPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _CameraGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.14)
      ..strokeWidth = 1;
    for (var i = 1; i < 3; i++) {
      final x = size.width * i / 3;
      final y = size.height * i / 3;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
