import 'dart:math';

import 'api_client.dart';

/// 카메라 프레임 또는 AI API 결과를 정확도 점수로 변환하는 서비스 계약이다.
abstract class AccuracyRecognitionService {
  Future<int> measureAccuracy({
    required String letter,
    required int attemptIndex,
    required String imageBase64,
  });
}

/// AI API가 붙기 전까지 사용하는 로컬 인식기다.
class LocalAccuracyRecognitionService implements AccuracyRecognitionService {
  const LocalAccuracyRecognitionService();

  @override
  Future<int> measureAccuracy({
    required String letter,
    required int attemptIndex,
    required String imageBase64,
  }) async {
    final seed = letter.codeUnitAt(0) % 9;
    final variation = Random(letter.codeUnitAt(0) + attemptIndex).nextInt(4);
    return (66 + seed + (attemptIndex * 7) + variation).clamp(0, 96);
  }
}

/// 백엔드 AI 인식 API를 호출해 정확도를 반환한다.
class ApiAccuracyRecognitionService implements AccuracyRecognitionService {
  ApiAccuracyRecognitionService({BabyhandsApiClientBase? apiClient})
      : _apiClient = apiClient ?? BabyhandsApiClient();

  final BabyhandsApiClientBase _apiClient;

  @override
  Future<int> measureAccuracy({
    required String letter,
    required int attemptIndex,
    required String imageBase64,
  }) async {
    final data = await _apiClient.recognizeLetter(imageBase64: imageBase64);
    final recognizedLetter = (data['letter']?.toString() ?? '').trim();
    final expectedLetter = letter.trim();
    final accuracyRaw = data['accuracy'];
    final parsedAccuracy = _parseAccuracy(accuracyRaw);
    if (parsedAccuracy == null) {
      return 0;
    }

    // AI가 다른 글자를 반환하면 현재 학습 글자 기준 정확도로 인정하지 않는다.
    if (recognizedLetter.isNotEmpty && recognizedLetter != expectedLetter) {
      return 0;
    }

    return parsedAccuracy;
  }

  int? _parseAccuracy(Object? accuracyRaw) {
    if (accuracyRaw is num) {
      return accuracyRaw.round().clamp(0, 100);
    }
    if (accuracyRaw is String) {
      final parsed = num.tryParse(accuracyRaw);
      if (parsed != null) {
        return parsed.round().clamp(0, 100);
      }
    }
    return null;
  }
}
