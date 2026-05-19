import 'package:flutter/material.dart';

/// 듀오링고 스타일 컬러 팔레트
class AppColors {
  AppColors._();

  // 배경
  static const Color bgTop = Color(0xFFF0FFF4); // 연한 그린
  static const Color bgBottom = Color(0xFFFAFFFB);
  static const Color card = Color(0xFFFFFFFF);

  // 텍스트
  static const Color text = Color(0xFF1C1C1C);
  static const Color muted = Color(0xFF777777);

  // 주요 강조색 (듀오링고 그린)
  static const Color primary = Color(0xFF58CC02);
  static const Color primaryPressed = Color(0xFF46A302);
  static const Color primaryDark = Color(0xFF46A302); // 버튼 3D 그림자용

  // 강조 (듀오링고 옐로우)
  static const Color accent = Color(0xFFFFD900);
  static const Color accentDark = Color(0xFFCEAB00);

  // 상태
  static const Color success = Color(0xFF58CC02);
  static const Color error = Color(0xFFFF4B4B);
  static const Color streak = Color(0xFFFF9600); // 연속 출석 스트릭 오렌지

  // 테두리
  static const Color border = Color(0xFFE5E7EB);
}
