import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/widgets.dart' show ChangeNotifier;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_logger.dart';
import 'api_client.dart';
import 'letter_catalog.dart';

/// 글자별 학습 진행 상태를 나타내는 모델이다.
class LearningLetterProgress {
  const LearningLetterProgress({
    required this.letter,
    required this.completed,
    required this.bestAccuracy,
    this.lastCompletedAt,
  });

  final String letter;
  final bool completed;
  final int bestAccuracy;
  final DateTime? lastCompletedAt;
}

/// 하루 학습 목표 설정값이다.
class TodayGoal {
  const TodayGoal({required this.targetLetters, required this.targetAccuracy});

  final int targetLetters;
  final int targetAccuracy;
}

/// 테스트 1회 결과 요약이다.
class TestAttemptSummary {
  const TestAttemptSummary({
    required this.passedCount,
    required this.totalCount,
    required this.missedLetters,
    required this.completedAt,
  });

  final int passedCount;
  final int totalCount;
  final List<String> missedLetters;
  final DateTime completedAt;

  int get scorePercent {
    if (totalCount == 0) return 0;
    return ((passedCount / totalCount) * 100).round();
  }
}

/// 최근 활동 로그 항목이다.
class LearningActivity {
  const LearningActivity({required this.label, required this.createdAt});

  final String label;
  final DateTime createdAt;
}

/// 홈 화면 대시보드에 필요한 데이터를 묶은 클래스다.
class HomeDashboardData {
  const HomeDashboardData({
    required this.attendanceDates,
    required this.todayGoal,
    required this.letters,
    required this.todayCompletedCount,
  });

  final Set<DateTime> attendanceDates;
  final TodayGoal todayGoal;
  final List<LearningLetterProgress> letters;
  final int todayCompletedCount;

  int get completedLetterCount {
    return letters.where((letter) => letter.completed).length;
  }

  int get overallProgressPercent {
    if (letters.isEmpty) return 0;
    return ((completedLetterCount / letters.length) * 100).round();
  }

  int get averageAccuracyPercent {
    final learnedLetters = letters.where((letter) => letter.bestAccuracy > 0);
    if (learnedLetters.isEmpty) return 0;

    final total = learnedLetters.fold<int>(
      0,
      (sum, letter) => sum + letter.bestAccuracy,
    );
    return (total / learnedLetters.length).round();
  }

  int get todayProgressPercent {
    if (todayGoal.targetLetters == 0) return 0;
    final completed = todayCompletedCount.clamp(0, todayGoal.targetLetters);
    return ((completed / todayGoal.targetLetters) * 100).round();
  }

  /// 아직 완료하지 않은 글자 중 정확도가 낮은 순으로 3개를 추천한다.
  List<LearningLetterProgress> get recommendedLetters {
    final notCompleted = letters.where((letter) => !letter.completed).toList();
    notCompleted.sort((a, b) => a.bestAccuracy.compareTo(b.bestAccuracy));
    return notCompleted.take(3).toList(growable: false);
  }
}

/// 홈 진행 상태 저장소 인터페이스다.
abstract class HomeProgressRepository {
  Future<HomeDashboardData> loadDashboard();
}

// SharedPreferences 저장 키 상수
const _keyLetterRecords = 'babyhands_letter_records';
const _keyAttendanceDates = 'babyhands_attendance_dates';
const _keyTodayGoal = 'babyhands_today_goal';
const _keyTestAttempts = 'babyhands_test_attempts';

/// 학습 진행 상태를 관리하는 저장소 구현체다.
/// 앱 재시작 간 데이터 유지를 위해 SharedPreferences에 상태를 저장한다.
/// ChangeNotifier를 상속해 상태 변경 시 구독 위젯에 알림을 전달한다.
class AppHomeProgressRepository extends ChangeNotifier
    implements HomeProgressRepository {
  AppHomeProgressRepository._internal({BabyhandsApiClientBase? apiClient})
      : _apiClient = apiClient ?? BabyhandsApiClient();

  /// 앱 전역에서 사용하는 싱글톤 인스턴스다.
  static final AppHomeProgressRepository instance =
      AppHomeProgressRepository._internal();

  /// 테스트 환경에서 격리된 인스턴스를 생성할 때 사용한다.
  @visibleForTesting
  factory AppHomeProgressRepository.forTesting({
    BabyhandsApiClientBase? apiClient,
  }) {
    return AppHomeProgressRepository._internal(apiClient: apiClient);
  }

  static const TodayGoal _defaultTodayGoal = TodayGoal(
    targetLetters: 5,
    targetAccuracy: 80,
  );

  static final List<String> allLetters = LetterCatalog.resources
      .map((resource) => resource.letter)
      .toList(growable: false);

  final BabyhandsApiClientBase _apiClient;
  final Map<String, _LetterProgressRecord> _records = {
    for (final letter in allLetters) letter: _LetterProgressRecord(),
  };
  final Set<DateTime> _attendanceDates = {};
  final List<TestAttemptSummary> _testAttempts = [];
  final List<LearningActivity> _activities = [];
  TodayGoal _todayGoal = _defaultTodayGoal;

  /// SharedPreferences에서 데이터를 최초 한 번만 불러오기 위한 플래그다.
  bool _prefsLoaded = false;

  /// 학습 완료를 기록하고 출석 및 API에 동기화한다.
  void recordLessonCompleted(String letter, {int accuracy = 100}) {
    final record = _recordFor(letter);
    record.completed = true;
    record.bestAccuracy = _highestAccuracy(record.bestAccuracy, accuracy);
    record.lastCompletedAt = DateTime.now();
    _markAttendanceToday();
    _addActivity('$letter 학습 완료');
    notifyListeners();
    unawaited(_saveToPrefs());
    if (AuthSession.instance.isSignedIn) {
      unawaited(
        _apiClient
            .saveLearningCompletion(
              letter: letter,
              accuracy: accuracy,
              completed: true,
            )
            .catchError((_) {}),
      );
    }
  }

  /// 인식 정확도 결과를 기록한다. 정확도 80% 이상이면 완료 처리한다.
  void recordRecognitionResult(String letter, int accuracy) {
    final record = _recordFor(letter);
    record.bestAccuracy = _highestAccuracy(record.bestAccuracy, accuracy);
    if (accuracy >= _defaultTodayGoal.targetAccuracy) {
      record.completed = true;
      record.lastCompletedAt = DateTime.now();
    }
    _markAttendanceToday();
    notifyListeners();
    unawaited(_saveToPrefs());
    if (AuthSession.instance.isSignedIn) {
      unawaited(
        _apiClient
            .saveLearningCompletion(
              letter: letter,
              accuracy: accuracy,
              completed: accuracy >= _defaultTodayGoal.targetAccuracy,
            )
            .catchError((_) {}),
      );
    }
  }

  /// 테스트 완료 결과를 기록하고 출석 및 API에 동기화한다.
  void recordTestCompleted({
    required int passedCount,
    required int totalCount,
    required List<String> missedLetters,
    List<Map<String, dynamic>> results = const [],
  }) {
    final attempt = TestAttemptSummary(
      passedCount: passedCount,
      totalCount: totalCount,
      missedLetters: List.unmodifiable(missedLetters),
      completedAt: DateTime.now(),
    );
    _testAttempts.insert(0, attempt);
    _markAttendanceToday();
    _addActivity('테스트 완료 ${attempt.scorePercent}%');
    notifyListeners();
    unawaited(_saveToPrefs());
    if (AuthSession.instance.isSignedIn) {
      unawaited(_apiClient.submitTestResults(results).catchError((_) {}));
    }
  }

  /// 테스트 문제 1개 풀이 결과를 즉시 서버에 저장한다.
  /// 백엔드가 문제 단위 누적 저장을 사용하므로, 한 문제당 1건씩 전송한다.
  Future<void> submitSingleTestResult({
    required String letter,
    required String selectedLetter,
    required int accuracy,
  }) async {
    _markAttendanceToday();
    _addActivity('테스트 문제 풀이');
    notifyListeners();
    unawaited(_saveToPrefs());

    if (!AuthSession.instance.isSignedIn) {
      return;
    }

    try {
      await _apiClient.submitTestResults([
        {
          'letter': letter,
          'accuracy': accuracy,
          'chooseAnswer': selectedLetter,
        },
      ]);
    } catch (_) {
      // 단건 테스트 저장 실패가 화면 진행을 막지 않도록 무시한다.
    }
  }

  /// 완료한 글자 목록을 반환한다.
  Set<String> completedLetters() {
    return {
      for (final entry in _records.entries)
        if (entry.value.completed) entry.key,
    };
  }

  /// 특정 글자의 최고 정확도를 반환한다.
  int bestAccuracyFor(String letter) {
    return _records[letter]?.bestAccuracy ?? 0;
  }

  /// 최근 테스트 기록 목록을 반환한다.
  List<TestAttemptSummary> recentTestAttempts() {
    return List.unmodifiable(_testAttempts);
  }

  /// 최근 활동 로그 최대 5개를 반환한다.
  List<LearningActivity> recentActivities() {
    return List.unmodifiable(_activities.take(5));
  }

  TodayGoal get todayGoal => _todayGoal;

  /// 하루 목표를 업데이트하고 저장한다.
  void updateTodayGoal(TodayGoal goal) {
    _todayGoal = goal;
    _addActivity('목표 변경: ${goal.targetLetters}글자, ${goal.targetAccuracy}%');
    notifyListeners();
    unawaited(_saveToPrefs());
  }

  @override
  Future<HomeDashboardData> loadDashboard() async {
    // 앱 기동 후 최초 호출 시 로컬 저장 데이터를 불러온다.
    if (!_prefsLoaded) {
      await _loadFromPrefs();
      _prefsLoaded = true;
    }

    if (AuthSession.instance.isSignedIn) {
      try {
        await _syncFromApi();
      } catch (_) {
        // 서버가 꺼져 있으면 앱 내 진행 상태로 계속 동작한다.
      }
    }

    _markAttendanceToday();
    final today = _dateOnly(DateTime.now());
    final letters = [
      for (final letter in allLetters) _letterProgressFor(letter),
    ];

    return HomeDashboardData(
      attendanceDates: Set.unmodifiable(_attendanceDates),
      todayGoal: _todayGoal,
      letters: letters,
      todayCompletedCount: letters
          .where((letter) => _isSameDay(letter.lastCompletedAt, today))
          .length,
    );
  }

  // --- SharedPreferences 저장/로드 ---

  /// SharedPreferences에서 로컬 저장 데이터를 불러온다.
  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final recordsJson = prefs.getString(_keyLetterRecords);
      if (recordsJson != null) {
        final map = jsonDecode(recordsJson) as Map<String, dynamic>;
        for (final entry in map.entries) {
          final data = entry.value as Map<String, dynamic>;
          final record = _recordFor(entry.key);
          record.completed = data['completed'] as bool? ?? false;
          record.bestAccuracy = data['bestAccuracy'] as int? ?? 0;
          final at = data['lastCompletedAt'] as String?;
          record.lastCompletedAt = at != null ? DateTime.tryParse(at) : null;
        }
      }

      final datesJson = prefs.getString(_keyAttendanceDates);
      if (datesJson != null) {
        final list = jsonDecode(datesJson) as List<dynamic>;
        _attendanceDates.addAll(
          list.map((e) => _dateOnly(DateTime.parse(e as String))),
        );
      }

      final goalJson = prefs.getString(_keyTodayGoal);
      if (goalJson != null) {
        final map = jsonDecode(goalJson) as Map<String, dynamic>;
        _todayGoal = TodayGoal(
          targetLetters: map['targetLetters'] as int? ?? 5,
          targetAccuracy: map['targetAccuracy'] as int? ?? 80,
        );
      }

      final attemptsJson = prefs.getString(_keyTestAttempts);
      if (attemptsJson != null) {
        final list = jsonDecode(attemptsJson) as List<dynamic>;
        _testAttempts.addAll(
          list.map((item) {
            final map = item as Map<String, dynamic>;
            return TestAttemptSummary(
              passedCount: map['passedCount'] as int,
              totalCount: map['totalCount'] as int,
              missedLetters: List<String>.from(
                map['missedLetters'] as List<dynamic>,
              ),
              completedAt: DateTime.parse(map['completedAt'] as String),
            );
          }),
        );
      }

      appLogger.i('로컬 학습 데이터 로드 완료 (완료 글자: ${completedLetters().length}개)');
    } catch (e, st) {
      appLogger.e('로컬 학습 데이터 로드 실패', error: e, stackTrace: st);
    }
  }

  /// 현재 상태를 SharedPreferences에 저장한다.
  Future<void> _saveToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final recordsMap = {
        for (final entry in _records.entries)
          entry.key: {
            'completed': entry.value.completed,
            'bestAccuracy': entry.value.bestAccuracy,
            'lastCompletedAt': entry.value.lastCompletedAt?.toIso8601String(),
          },
      };
      await prefs.setString(_keyLetterRecords, jsonEncode(recordsMap));

      await prefs.setString(
        _keyAttendanceDates,
        jsonEncode(
          _attendanceDates.map((d) => d.toIso8601String()).toList(),
        ),
      );

      await prefs.setString(
        _keyTodayGoal,
        jsonEncode({
          'targetLetters': _todayGoal.targetLetters,
          'targetAccuracy': _todayGoal.targetAccuracy,
        }),
      );

      // 테스트 기록은 최근 10개만 보관한다.
      await prefs.setString(
        _keyTestAttempts,
        jsonEncode(
          _testAttempts.take(10).map((a) => {
                'passedCount': a.passedCount,
                'totalCount': a.totalCount,
                'missedLetters': a.missedLetters,
                'completedAt': a.completedAt.toIso8601String(),
              }).toList(),
        ),
      );
    } catch (e, st) {
      appLogger.e('로컬 학습 데이터 저장 실패', error: e, stackTrace: st);
    }
  }

  // --- API 동기화 ---

  Future<void> _syncFromApi() async {
    // tb_attendance 기준 출석일을 먼저 불러와 캘린더에 반영한다. markAttendance 실패로 여기까지 못 가면 안 된다.
    final attendanceDates = await _apiClient.attendanceDates();
    _attendanceDates
      ..clear()
      ..addAll(attendanceDates.map(_dateOnly));

    try {
      await _apiClient.markAttendance();
    } catch (_) {
      // 오늘 출석 INSERT가 실패해도 기존 DB 출석일은 이미 반영됨.
    }

    final remoteLetters = await _apiClient.learningLetters();

    for (final item in remoteLetters) {
      final letter = item['letter'] as String;
      final record = _recordFor(letter);
      record.completed = item['completed'] as bool? ?? false;
      record.bestAccuracy = item['bestAccuracy'] as int? ?? 0;
      final completedAt = item['completedAt'] as String?;
      record.lastCompletedAt =
          completedAt == null ? null : DateTime.tryParse(completedAt);
    }

    unawaited(_saveToPrefs());
  }

  // --- 내부 유틸리티 ---

  _LetterProgressRecord _recordFor(String letter) {
    return _records.putIfAbsent(letter, _LetterProgressRecord.new);
  }

  LearningLetterProgress _letterProgressFor(String letter) {
    final record = _recordFor(letter);
    return LearningLetterProgress(
      letter: letter,
      completed: record.completed,
      bestAccuracy: record.bestAccuracy,
      lastCompletedAt: record.lastCompletedAt,
    );
  }

  void _markAttendanceToday() {
    _attendanceDates.add(_dateOnly(DateTime.now()));
  }

  void _addActivity(String label) {
    _activities.insert(
      0,
      LearningActivity(label: label, createdAt: DateTime.now()),
    );
    if (_activities.length > 20) {
      _activities.removeRange(20, _activities.length);
    }
  }

  static int _highestAccuracy(int current, int next) {
    return next > current ? next : current;
  }

  static DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  static bool _isSameDay(DateTime? a, DateTime b) {
    return a != null &&
        a.year == b.year &&
        a.month == b.month &&
        a.day == b.day;
  }
}

class _LetterProgressRecord {
  bool completed = false;
  int bestAccuracy = 0;
  DateTime? lastCompletedAt;
}
