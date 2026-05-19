import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:babyhands/data/api_client.dart';
import 'package:babyhands/data/home_progress_repository.dart';

/// API 호출이 없는 테스트 환경에서 사용하는 가짜 클라이언트다.
class _FakeApiClient extends BabyhandsApiClientBase {
  @override
  Future<AuthMember> login({
    required String memberId,
    required String password,
  }) async => throw UnimplementedError();

  @override
  Future<AuthMember> socialLogin({
    required String provider,
    String? idToken,
    String? accessToken,
  }) async =>
      throw UnimplementedError();

  @override
  Future<AuthMember> register({
    required String memberId,
    required String password,
    required String nickname,
    String? email,
    String? emailVerificationToken,
  }) async => throw UnimplementedError();

  @override
  Future<void> sendSignupEmailVerificationCode({required String email}) async =>
      throw UnimplementedError();

  @override
  Future<String> verifySignupEmailVerificationCode({
    required String email,
    required String code,
  }) async =>
      throw UnimplementedError();

  @override
  Future<String> findMemberIdByEmail({required String email}) async =>
      throw UnimplementedError();

  @override
  Future<void> resetPassword({
    required String memberId,
    required String email,
    required String newPassword,
  }) async =>
      throw UnimplementedError();

  @override
  Future<AuthMember> me() async => throw UnimplementedError();

  @override
  Future<List<DateTime>> attendanceDates() async => [];

  @override
  Future<void> markAttendance() async {}

  @override
  Future<List<Map<String, dynamic>>> learningLetters() async => [];

  @override
  Future<void> saveLearningCompletion({
    required String letter,
    required int accuracy,
    required bool completed,
  }) async {}

  @override
  Future<List<String>> testQuestions() async => [];

  @override
  Future<void> submitTestResults(List<Map<String, dynamic>> results) async {}

  @override
  Future<List<Map<String, dynamic>>> rankings() async => [];

  @override
  Future<Map<String, dynamic>> rankingsPage({
    required int offset,
    int limit = 20,
  }) async => const {
        'rankings': <Map<String, dynamic>>[],
        'total': 0,
      };

  @override
  Future<Map<String, dynamic>> recognizeLetter({
    required String imageBase64,
  }) async => const {'letter': 'ㄱ', 'accuracy': 0};
}

void main() {
  /// 각 테스트마다 SharedPreferences를 초기화하고, 격리된 레포지토리를 생성한다.
  late AppHomeProgressRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repo = AppHomeProgressRepository.forTesting(
      apiClient: _FakeApiClient(),
    );
  });

  group('recordLessonCompleted', () {
    test('완료 처리 후 해당 글자가 완료 목록에 포함돼야 한다', () {
      repo.recordLessonCompleted('ㄱ', accuracy: 90);

      expect(repo.completedLetters(), contains('ㄱ'));
    });

    test('정확도가 기존보다 높으면 최고 정확도가 갱신돼야 한다', () {
      repo.recordLessonCompleted('ㄴ', accuracy: 70);
      repo.recordLessonCompleted('ㄴ', accuracy: 95);

      expect(repo.bestAccuracyFor('ㄴ'), equals(95));
    });

    test('정확도가 기존보다 낮으면 최고 정확도가 유지돼야 한다', () {
      repo.recordLessonCompleted('ㄷ', accuracy: 90);
      repo.recordLessonCompleted('ㄷ', accuracy: 60);

      expect(repo.bestAccuracyFor('ㄷ'), equals(90));
    });
  });

  group('recordRecognitionResult', () {
    test('정확도 80% 이상이면 완료 처리돼야 한다', () {
      repo.recordRecognitionResult('ㄹ', 80);

      expect(repo.completedLetters(), contains('ㄹ'));
    });

    test('정확도 79% 이하면 완료 처리되지 않아야 한다', () {
      repo.recordRecognitionResult('ㅁ', 79);

      expect(repo.completedLetters(), isNot(contains('ㅁ')));
    });

    test('최고 정확도는 계속 갱신돼야 한다', () {
      repo.recordRecognitionResult('ㅂ', 60);
      repo.recordRecognitionResult('ㅂ', 85);
      repo.recordRecognitionResult('ㅂ', 70);

      expect(repo.bestAccuracyFor('ㅂ'), equals(85));
    });
  });

  group('recordTestCompleted', () {
    test('테스트 완료 기록이 목록에 추가돼야 한다', () {
      repo.recordTestCompleted(
        passedCount: 4,
        totalCount: 5,
        missedLetters: ['ㅅ'],
      );

      final attempts = repo.recentTestAttempts();
      expect(attempts, hasLength(1));
      expect(attempts.first.passedCount, equals(4));
      expect(attempts.first.totalCount, equals(5));
      expect(attempts.first.missedLetters, contains('ㅅ'));
    });

    test('scorePercent가 올바르게 계산돼야 한다', () {
      repo.recordTestCompleted(
        passedCount: 3,
        totalCount: 5,
        missedLetters: ['ㅇ', 'ㅈ'],
      );

      expect(repo.recentTestAttempts().first.scorePercent, equals(60));
    });

    test('가장 최근 테스트가 목록 첫 번째에 위치해야 한다', () {
      repo.recordTestCompleted(
        passedCount: 2,
        totalCount: 5,
        missedLetters: [],
      );
      repo.recordTestCompleted(
        passedCount: 5,
        totalCount: 5,
        missedLetters: [],
      );

      expect(repo.recentTestAttempts().first.passedCount, equals(5));
    });
  });

  group('updateTodayGoal', () {
    test('목표를 변경하면 todayGoal에 반영돼야 한다', () {
      repo.updateTodayGoal(
        const TodayGoal(targetLetters: 10, targetAccuracy: 90),
      );

      expect(repo.todayGoal.targetLetters, equals(10));
      expect(repo.todayGoal.targetAccuracy, equals(90));
    });
  });

  group('loadDashboard', () {
    test('completedLetterCount가 완료한 글자 수와 일치해야 한다', () async {
      repo.recordLessonCompleted('ㄱ', accuracy: 90);
      repo.recordLessonCompleted('ㄴ', accuracy: 85);

      final dashboard = await repo.loadDashboard();

      expect(dashboard.completedLetterCount, equals(2));
    });

    test('overallProgressPercent가 전체 글자 대비 완료 비율을 반환해야 한다', () async {
      // 전체 24글자 중 1개 완료 → 약 4%
      repo.recordLessonCompleted('ㄱ', accuracy: 90);

      final dashboard = await repo.loadDashboard();
      final total = AppHomeProgressRepository.allLetters.length;

      expect(
        dashboard.overallProgressPercent,
        equals(((1 / total) * 100).round()),
      );
    });

    test('오늘 완료한 글자만 todayCompletedCount에 포함돼야 한다', () async {
      repo.recordLessonCompleted('ㄱ', accuracy: 90);
      repo.recordLessonCompleted('ㄴ', accuracy: 85);

      final dashboard = await repo.loadDashboard();

      expect(dashboard.todayCompletedCount, equals(2));
    });

    test('recommendedLetters는 미완료 글자 중 정확도 낮은 순 최대 3개를 반환해야 한다', () async {
      // 24개 전체 글자를 완료 처리하고 3개만 남겨 정확도 순서를 명확히 검증한다.
      for (final letter in AppHomeProgressRepository.allLetters) {
        if (letter != 'ㄱ' && letter != 'ㄴ' && letter != 'ㄷ') {
          repo.recordLessonCompleted(letter, accuracy: 100);
        }
      }
      repo.recordRecognitionResult('ㄱ', 50);
      repo.recordRecognitionResult('ㄴ', 60);
      repo.recordRecognitionResult('ㄷ', 40);

      final dashboard = await repo.loadDashboard();
      final recommended = dashboard.recommendedLetters;

      expect(recommended.length, lessThanOrEqualTo(3));
      // 미완료 글자 중 정확도 낮은 순: ㄷ(40) → ㄱ(50) → ㄴ(60)
      expect(recommended.first.letter, equals('ㄷ'));
      expect(
        recommended.map((l) => l.bestAccuracy).toList(),
        equals([40, 50, 60]),
      );
    });
  });

  group('SharedPreferences 영속성', () {
    test('recordLessonCompleted 후 새 인스턴스에서 loadDashboard를 호출하면 데이터가 복원돼야 한다',
        () async {
      repo.recordLessonCompleted('ㄱ', accuracy: 90);
      // _saveToPrefs가 unawaited이므로 flush를 위해 잠시 대기한다.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final newRepo = AppHomeProgressRepository.forTesting(
        apiClient: _FakeApiClient(),
      );
      final dashboard = await newRepo.loadDashboard();

      expect(dashboard.completedLetterCount, equals(1));
      expect(newRepo.completedLetters(), contains('ㄱ'));
      expect(newRepo.bestAccuracyFor('ㄱ'), equals(90));
    });

    test('updateTodayGoal 후 새 인스턴스에서 목표가 복원돼야 한다', () async {
      repo.updateTodayGoal(
        const TodayGoal(targetLetters: 8, targetAccuracy: 85),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final newRepo = AppHomeProgressRepository.forTesting(
        apiClient: _FakeApiClient(),
      );
      await newRepo.loadDashboard();

      expect(newRepo.todayGoal.targetLetters, equals(8));
      expect(newRepo.todayGoal.targetAccuracy, equals(85));
    });
  });
}
