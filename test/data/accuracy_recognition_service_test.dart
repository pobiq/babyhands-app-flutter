import 'package:flutter_test/flutter_test.dart';

import 'package:babyhands/data/accuracy_recognition_service.dart';

void main() {
  group('LocalAccuracyRecognitionService', () {
    late LocalAccuracyRecognitionService service;

    setUp(() {
      service = const LocalAccuracyRecognitionService();
    });

    test('정확도 값이 0~100 범위 안에 있어야 한다', () async {
      // 자음/모음을 포함해 다양한 글자에 대해 범위를 검증한다.
      const testLetters = ['ㄱ', 'ㄴ', 'ㄷ', 'ㅏ', 'ㅣ', 'ㅗ'];
      for (final letter in testLetters) {
        final accuracy = await service.measureAccuracy(
          letter: letter,
          attemptIndex: 0,
        );
        expect(accuracy, inInclusiveRange(0, 100),
            reason: '$letter 글자의 정확도가 범위를 벗어났다: $accuracy');
      }
    });

    test('같은 글자와 같은 시도 횟수로 호출하면 동일한 정확도를 반환해야 한다', () async {
      // 결정론적 시드를 사용하므로 결과가 일정해야 한다.
      const letter = 'ㄱ';
      const attemptIndex = 0;

      final first = await service.measureAccuracy(
        letter: letter,
        attemptIndex: attemptIndex,
      );
      final second = await service.measureAccuracy(
        letter: letter,
        attemptIndex: attemptIndex,
      );

      expect(first, equals(second));
    });

    test('시도 횟수가 증가하면 정확도가 달라져야 한다', () async {
      // attemptIndex가 다르면 variation 값이 달라진다.
      const letter = 'ㄱ';

      final attempt0 = await service.measureAccuracy(
        letter: letter,
        attemptIndex: 0,
      );
      final attempt1 = await service.measureAccuracy(
        letter: letter,
        attemptIndex: 1,
      );
      final attempt2 = await service.measureAccuracy(
        letter: letter,
        attemptIndex: 2,
      );

      // 세 값이 모두 동일하지는 않아야 한다.
      expect(
        {attempt0, attempt1, attempt2}.length,
        greaterThan(1),
        reason: '시도 횟수가 달라지면 정확도가 변해야 한다',
      );
    });

    test('시도가 반복될수록 전반적으로 정확도가 높아지는 경향이 있어야 한다', () async {
      // attemptIndex * 7 항이 정확도를 높이도록 설계됐다.
      const letter = 'ㄱ';

      final early = await service.measureAccuracy(
        letter: letter,
        attemptIndex: 0,
      );
      final later = await service.measureAccuracy(
        letter: letter,
        attemptIndex: 3,
      );

      expect(later, greaterThanOrEqualTo(early),
          reason: '반복 시도 후 정확도가 올라야 한다');
    });

    test('글자마다 고유한 기저 정확도가 있어야 한다', () async {
      // 각 글자의 codeUnitAt(0) % 9 시드가 달라 기저값이 다르다.
      final accuracies = <int>{};
      for (final letter in ['ㄱ', 'ㄴ', 'ㄷ', 'ㄹ', 'ㅁ', 'ㅂ', 'ㅅ', 'ㅇ', 'ㅈ']) {
        final acc = await service.measureAccuracy(
          letter: letter,
          attemptIndex: 0,
        );
        accuracies.add(acc);
      }
      expect(accuracies.length, greaterThan(1),
          reason: '서로 다른 글자는 서로 다른 정확도를 가져야 한다');
    });
  });
}
