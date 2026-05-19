import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'app_logger.dart';

const _keyNotificationEnabled = 'babyhands_notification_enabled';
const _keyReminderHour = 'babyhands_notification_hour';
const _keyReminderMinute = 'babyhands_notification_minute';

/// 로컬 푸시 알림을 관리하는 싱글톤 서비스다.
/// 매일 정해진 시각에 학습 알림을 전송하는 기능을 담당한다.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// initialize()가 한 번이라도 끝났는지(성공·실패 무관) 나타낸다.
  bool _initialized = false;

  /// 플랫폼 알림 플러그인이 실제로 사용 가능한지. 테스트 환경 등에서는 false다.
  bool _notificationsReady = false;

  /// 기본 알림 시각: 오전 9시
  static const int _defaultHour = 9;
  static const int _defaultMinute = 0;

  /// OS 타임존 DB에 맞춰 [tz.local]을 설정한다. 실패 시 Asia/Seoul을 쓴다.
  Future<void> _configureLocalTimeZone() async {
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
      appLogger.i('알림용 로컬 타임존: ${info.identifier}');
    } catch (e, st) {
      appLogger.w(
        '로컬 타임존 조회 실패, Asia/Seoul 사용',
        error: e,
        stackTrace: st,
      );
      try {
        tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
      } catch (_) {}
    }
  }

  /// 알림 채널 및 플러그인을 초기화한다.
  /// 앱 기동 시 main()에서 한 번 호출해야 한다.
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      tz.initializeTimeZones();
      await _configureLocalTimeZone();

      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      await _plugin.initialize(
        const InitializationSettings(
          android: androidSettings,
          iOS: iosSettings,
        ),
      );

      _notificationsReady = true;
      appLogger.i('NotificationService 초기화 완료');
    } catch (e, st) {
      // flutter test 등 플랫폼 구현이 없을 때 실패하므로, 앱 동작은 계속한다.
      appLogger.w(
        'NotificationService 초기화 생략(알림 미사용)',
        error: e,
        stackTrace: st,
      );
    } finally {
      _initialized = true;
    }
  }

  /// 알림 활성화 여부를 SharedPreferences에서 불러온다.
  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyNotificationEnabled) ?? true;
  }

  /// 저장된 매일 알림 시각을 반환한다.
  Future<TimeOfDay> getReminderTime() async {
    final prefs = await SharedPreferences.getInstance();
    return TimeOfDay(
      hour: prefs.getInt(_keyReminderHour) ?? _defaultHour,
      minute: prefs.getInt(_keyReminderMinute) ?? _defaultMinute,
    );
  }

  /// 알림 시각을 저장하고, 알림이 켜져 있으면 다시 예약한다.
  Future<void> setReminderTime(int hour, int minute) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyReminderHour, hour);
    await prefs.setInt(_keyReminderMinute, minute);
    if (await isEnabled()) {
      await scheduleDailyReminder(hour: hour, minute: minute);
    }
    appLogger.i(
      '알림 시각 저장: ${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
    );
  }

  /// 알림 활성화 여부를 저장하고 스케줄을 갱신한다.
  Future<void> setEnabled({required bool value}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyNotificationEnabled, value);
    if (value) {
      await scheduleDailyReminder();
    } else {
      await cancelAll();
    }
    appLogger.i('알림 설정 변경: ${value ? "활성화" : "비활성화"}');
  }

  /// OS 알림 권한을 요청한다. 허용·불필요 플랫폼이면 true를 반환한다.
  Future<bool> requestNotificationPermissions() async {
    if (!_notificationsReady) return false;
    if (kIsWeb) return false;

    try {
      if (Platform.isAndroid) {
        final android = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        final granted = await android?.requestNotificationsPermission();
        return granted ?? true;
      }
      if (Platform.isIOS) {
        final ios = _plugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
        final ok = await ios?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return ok ?? false;
      }
    } catch (e, st) {
      appLogger.w('알림 권한 요청 실패', error: e, stackTrace: st);
      return false;
    }

    return true;
  }

  /// 매일 지정 시각에 학습 알림을 예약한다.
  /// Android 12+ 에서는 SCHEDULE_EXACT_ALARM, 13+ 에서는 POST_NOTIFICATIONS가 필요하다.
  Future<void> scheduleDailyReminder({
    int? hour,
    int? minute,
  }) async {
    if (!_initialized) await initialize();
    if (!_notificationsReady) return;

    final enabled = await isEnabled();
    if (!enabled) return;

    final prefs = await SharedPreferences.getInstance();
    final h = hour ?? prefs.getInt(_keyReminderHour) ?? _defaultHour;
    final m = minute ?? prefs.getInt(_keyReminderMinute) ?? _defaultMinute;

    // 기존 알림을 먼저 취소하고 새로 등록한다.
    await _plugin.cancel(0);

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      h,
      m,
    );
    // 이미 지난 시각이면 다음 날로 설정한다.
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    const androidDetails = AndroidNotificationDetails(
      'babyhands_daily',
      '오늘 학습 알림',
      channelDescription: '매일 수어 지문자 학습을 알려주는 알림입니다.',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    const iosDetails = DarwinNotificationDetails();

    await _plugin.zonedSchedule(
      0,
      'Babyhands 꼬마손',
      '오늘 수어 지문자 학습을 시작해볼까요? 🤚',
      scheduled,
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      // iOS 10 미만 호환을 위한 날짜 해석 방식 지정
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );

    appLogger.i('일일 학습 알림 예약 완료: $h:${m.toString().padLeft(2, '0')}');
  }

  /// 등록된 모든 알림을 취소한다.
  Future<void> cancelAll() async {
    if (!_notificationsReady) return;
    await _plugin.cancelAll();
    appLogger.i('모든 알림 취소');
  }
}
