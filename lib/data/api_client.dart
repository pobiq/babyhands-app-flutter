import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/app_logger.dart';

/// 인증된 사용자 정보를 담는 모델이다.
class AuthMember {
  const AuthMember({
    required this.id,
    required this.memberId,
    required this.nickname,
    this.email,
  });

  final int id;
  final String memberId;
  final String nickname;
  final String? email;
}

/// 로그인 세션 토큰과 사용자 정보를 앱 수명 동안 보관하는 싱글톤이다.
class AuthSession {
  AuthSession._();

  static final AuthSession instance = AuthSession._();

  String? accessToken;
  AuthMember? member;

  /// 로그인 없이 체험 모드로 진입한 경우 true다.
  /// 게스트 모드에서는 API 동기화 없이 로컬 데이터만 사용한다.
  bool isGuest = false;

  bool get isSignedIn => accessToken != null;

  void update({required String token, required AuthMember signedInMember}) {
    accessToken = token;
    member = signedInMember;
    isGuest = false;
  }

  /// 로그인 없이 체험 학습을 시작할 때 호출한다.
  void guestLogin() {
    accessToken = null;
    member = null;
    isGuest = true;
  }

  void clear() {
    accessToken = null;
    member = null;
    isGuest = false;
  }
}

/// API 클라이언트 추상 인터페이스다.
/// 실제 HTTP 구현체와 테스트용 Fake 구현체를 동일한 타입으로 교체할 수 있다.
abstract class BabyhandsApiClientBase {
  Future<AuthMember> login({
    required String memberId,
    required String password,
  });

  /// 소셜 SDK에서 받은 토큰으로 로그인한다. Google은 idToken, 카카오·네이버는 accessToken.
  Future<AuthMember> socialLogin({
    required String provider,
    String? idToken,
    String? accessToken,
  });

  Future<AuthMember> register({
    required String memberId,
    required String password,
    required String nickname,
    String? email,
    String? emailVerificationToken,
  });

  /// 회원가입용 이메일 인증번호를 발송한다.
  Future<void> sendSignupEmailVerificationCode({required String email});

  /// 회원가입용 이메일 인증번호를 검증하고 검증 토큰을 반환한다.
  Future<String> verifySignupEmailVerificationCode({
    required String email,
    required String code,
  });

  /// 가입 시 등록한 이메일로 로그인 아이디(memberId)를 조회한다.
  Future<String> findMemberIdByEmail({required String email});

  /// 아이디·이메일 검증 후 새 비밀번호로 갱신한다.
  Future<void> resetPassword({
    required String memberId,
    required String email,
    required String newPassword,
  });

  Future<AuthMember> me();
  Future<List<DateTime>> attendanceDates();
  Future<void> markAttendance();
  Future<List<Map<String, dynamic>>> learningLetters();
  Future<void> saveLearningCompletion({
    required String letter,
    required int accuracy,
    required bool completed,
  });
  Future<List<String>> testQuestions();
  Future<void> submitTestResults(List<Map<String, dynamic>> results);
  Future<List<Map<String, dynamic>>> rankings();
  Future<Map<String, dynamic>> rankingsPage({
    required int offset,
    int limit,
  });

  Future<Map<String, dynamic>> recognizeLetter({
    required String imageBase64,
  });
}

/// 실제 HTTP 통신을 담당하는 API 클라이언트 구현체다.
class BabyhandsApiClient extends BabyhandsApiClientBase {
  BabyhandsApiClient({
    this.baseUrl = const String.fromEnvironment(
      'BABYHANDS_API_BASE_URL',
      defaultValue: 'http://localhost:4000',
    ),
    AuthSession? session,
  }) : session = session ?? AuthSession.instance;

  final String baseUrl;
  final AuthSession session;

  @override
  Future<AuthMember> login({
    required String memberId,
    required String password,
  }) async {
    final json = await _request(
      'POST',
      '/api/auth/login',
      body: {'memberId': memberId, 'password': password},
      authenticated: false,
    );
    final data = json['data'] as Map<String, dynamic>;
    final memberJson = data['member'] as Map<String, dynamic>;
    final member = _memberFromJson(memberJson);
    session.update(
      token: data['accessToken'] as String,
      signedInMember: member,
    );
    return member;
  }

  @override
  Future<AuthMember> socialLogin({
    required String provider,
    String? idToken,
    String? accessToken,
  }) async {
    final body = <String, dynamic>{
      'provider': provider,
      if (idToken != null && idToken.isNotEmpty) 'idToken': idToken,
      if (accessToken != null && accessToken.isNotEmpty)
        'accessToken': accessToken,
    };
    final json = await _request(
      'POST',
      '/api/auth/social',
      body: body,
      authenticated: false,
    );
    final data = json['data'] as Map<String, dynamic>;
    final memberJson = data['member'] as Map<String, dynamic>;
    final member = _memberFromJson(memberJson);
    session.update(
      token: data['accessToken'] as String,
      signedInMember: member,
    );
    return member;
  }

  @override
  Future<AuthMember> register({
    required String memberId,
    required String password,
    required String nickname,
    String? email,
    String? emailVerificationToken,
  }) async {
    // email이 빈 문자열이면 서버에 전달하지 않는다.
    final body = <String, dynamic>{
      'memberId': memberId,
      'password': password,
      'nickname': nickname,
    };
    if (email != null && email.isNotEmpty) body['email'] = email;
    if (emailVerificationToken != null && emailVerificationToken.isNotEmpty) {
      body['emailVerificationToken'] = emailVerificationToken;
    }

    final json = await _request(
      'POST',
      '/api/auth/register',
      body: body,
      authenticated: false,
    );
    final data = json['data'] as Map<String, dynamic>;
    final memberJson = data['member'] as Map<String, dynamic>;
    final member = _memberFromJson(memberJson);
    session.update(
      token: data['accessToken'] as String,
      signedInMember: member,
    );
    return member;
  }

  @override
  Future<void> sendSignupEmailVerificationCode({required String email}) async {
    await _request(
      'POST',
      '/api/auth/email-verification/send',
      body: {'email': email.trim()},
      authenticated: false,
    );
  }

  @override
  Future<String> verifySignupEmailVerificationCode({
    required String email,
    required String code,
  }) async {
    final json = await _request(
      'POST',
      '/api/auth/email-verification/verify',
      body: {'email': email.trim(), 'code': code.trim()},
      authenticated: false,
    );
    final data = json['data'] as Map<String, dynamic>;
    return (data['verificationToken'] as String?) ?? '';
  }

  @override
  Future<String> findMemberIdByEmail({required String email}) async {
    final json = await _request(
      'POST',
      '/api/auth/find-member-id',
      body: {'email': email.trim()},
      authenticated: false,
    );
    final data = json['data'] as Map<String, dynamic>;
    return data['memberId'] as String;
  }

  @override
  Future<void> resetPassword({
    required String memberId,
    required String email,
    required String newPassword,
  }) async {
    await _request(
      'POST',
      '/api/auth/reset-password',
      body: {
        'memberId': memberId.trim(),
        'email': email.trim(),
        'newPassword': newPassword,
      },
      authenticated: false,
    );
  }

  @override
  Future<AuthMember> me() async {
    final json = await _request('GET', '/api/members/me');
    final data = json['data'] as Map<String, dynamic>;
    return _memberFromJson(data['member'] as Map<String, dynamic>);
  }

  /// `tb_attendance.login_date`에 대응하는 날짜. API는 `YYYY-MM-DD`를 권장한다.
  static DateTime parseAttendanceDate(Object? raw) {
    final value = raw?.toString().trim() ?? '';
    final ymd = RegExp(r'^(\d{4})-(\d{2})-(\d{2})');
    final m = ymd.firstMatch(value);
    if (m != null) {
      return DateTime(
        int.parse(m.group(1)!),
        int.parse(m.group(2)!),
        int.parse(m.group(3)!),
      );
    }
    final dt = DateTime.parse(value);
    return DateTime(dt.year, dt.month, dt.day);
  }

  @override
  Future<List<DateTime>> attendanceDates() async {
    final json = await _request('GET', '/api/attendance');
    final data = json['data'] as Map<String, dynamic>;
    final list = data['attendanceDates'] as List<dynamic>? ?? const [];
    return [
      for (final value in list) parseAttendanceDate(value),
    ];
  }

  @override
  Future<void> markAttendance() async {
    await _request('POST', '/api/attendance');
  }

  @override
  Future<List<Map<String, dynamic>>> learningLetters() async {
    final json = await _request('GET', '/api/learning/letters');
    final data = json['data'] as Map<String, dynamic>;
    return [
      for (final item in data['letters'] as List<dynamic>)
        item as Map<String, dynamic>,
    ];
  }

  @override
  Future<void> saveLearningCompletion({
    required String letter,
    required int accuracy,
    required bool completed,
  }) async {
    await _request(
      'POST',
      '/api/learning/completions',
      body: {'letter': letter, 'accuracy': accuracy, 'completed': completed},
    );
  }

  @override
  Future<List<String>> testQuestions() async {
    final json = await _request('GET', '/api/tests/questions');
    final data = json['data'] as Map<String, dynamic>;
    return [
      for (final item in data['questions'] as List<dynamic>)
        (item as Map<String, dynamic>)['letter'] as String,
    ];
  }

  @override
  Future<void> submitTestResults(List<Map<String, dynamic>> results) async {
    await _request(
      'POST',
      '/api/tests/submissions',
      body: {'results': results},
    );
  }

  @override
  Future<List<Map<String, dynamic>>> rankings() async {
    final json = await _request('GET', '/api/rankings');
    final data = json['data'] as Map<String, dynamic>;
    return [
      for (final item in data['rankings'] as List<dynamic>)
        item as Map<String, dynamic>,
    ];
  }

  @override
  Future<Map<String, dynamic>> rankingsPage({
    required int offset,
    int limit = 20,
  }) async {
    final json = await _request(
      'GET',
      '/api/rankings?offset=$offset&limit=$limit',
    );
    return json['data'] as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> recognizeLetter({
    required String imageBase64,
  }) async {
    final json = await _request(
      'POST',
      '/api/ai/recognize',
      body: {'image_base64': imageBase64},
    );
    return json['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
    Duration connectTimeout = const Duration(seconds: 15),
    Duration responseTimeout = const Duration(seconds: 45),
  }) async {
    final stopwatch = Stopwatch()..start();
    final uri = Uri.parse('$baseUrl$path');
    final headers = <String, String>{
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json',
      if (authenticated && session.accessToken != null)
        'Authorization': 'Bearer ${session.accessToken}',
    };

    appLogger.d('API ▶ [$method] $path${body != null ? " $body" : ""}');

    final client = http.Client();
    try {
      final http.Response response;
      final totalTimeout = connectTimeout + responseTimeout;
      switch (method) {
        case 'GET':
          response = await client
              .get(uri, headers: headers)
              .timeout(totalTimeout);
        case 'POST':
          response = await client
              .post(
                uri,
                headers: headers,
                body: body != null ? jsonEncode(body) : null,
              )
              .timeout(totalTimeout);
        default:
          throw UnsupportedError('Unsupported HTTP method: $method');
      }

      final responseBody = response.body;
      final json = jsonDecode(responseBody) as Map<String, dynamic>;

      stopwatch.stop();
      appLogger.i(
        'API ◀ [$method] $path → ${response.statusCode} (${stopwatch.elapsedMilliseconds}ms)',
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final error = json['error'] as Map<String, dynamic>?;
        final code = error?['code'] as String?;
        final message = error?['message'] as String? ?? 'API request failed.';
        appLogger.w('API ✗ [$method] $path 오류 응답: [$code] $message');
        throw BabyhandsApiException(message, code: code);
      }

      return json;
    } catch (e, st) {
      if (e is! BabyhandsApiException) {
        stopwatch.stop();
        appLogger.e(
          'API ✗ [$method] $path 네트워크 오류 (${stopwatch.elapsedMilliseconds}ms)',
          error: e,
          stackTrace: st,
        );
      }
      rethrow;
    } finally {
      client.close();
    }
  }

  AuthMember _memberFromJson(Map<String, dynamic> json) {
    return AuthMember(
      id: _intFromJson(json['id']),
      memberId: json['memberId'] as String,
      nickname: json['nickname'] as String,
      email: json['email'] as String?,
    );
  }

  int _intFromJson(Object? value) {
    if (value is num) return value.toInt();
    if (value is String) return int.parse(value);
    return 0;
  }
}

class BabyhandsApiException implements Exception {
  const BabyhandsApiException(this.message, {this.code});

  final String message;
  /// 서버가 반환한 에러 코드. 예: 'INVALID_CREDENTIALS', 'DUPLICATE_MEMBER_ID'
  final String? code;

  @override
  String toString() => message;
}

/// 서버 에러 코드를 사용자에게 보여줄 한국어 메시지로 변환한다.
/// 코드가 없거나 알 수 없는 경우 서버 메시지를 그대로 반환한다.
String resolveApiErrorMessage(BabyhandsApiException e) {
  return switch (e.code) {
    'INVALID_CREDENTIALS' => '아이디 또는 비밀번호가 올바르지 않습니다.',
    'DUPLICATE_MEMBER_ID' => '이미 사용 중인 아이디입니다.',
    'DUPLICATE_EMAIL'     => '이미 사용 중인 이메일입니다.',
    'INVALID_INPUT'       => '입력값이 올바르지 않습니다.',
    'UNAUTHORIZED'        => '로그인이 필요합니다. 다시 로그인해주세요.',
    'MEMBER_NOT_FOUND'     => '회원 정보를 찾을 수 없습니다.',
    'EMAIL_NOT_REGISTERED' => '가입된 이메일을 찾을 수 없습니다. 이메일을 확인해주세요.',
    'VERIFICATION_FAILED'  => '아이디 또는 이메일이 일치하지 않습니다.',
    'EMAIL_VERIFICATION_REQUIRED' => '이메일 인증이 필요합니다.',
    'EMAIL_VERIFICATION_EXPIRED' => '인증번호가 만료되었어요. 다시 받아주세요.',
    'EMAIL_VERIFICATION_CODE_MISMATCH' => '인증번호가 올바르지 않습니다.',
    'EMAIL_VERIFICATION_TOO_MANY_ATTEMPTS' => '인증 시도 횟수를 초과했어요. 다시 인증번호를 받아주세요.',
    'SOCIAL_VERIFY_FAILED'  => '소셜 계정 확인에 실패했습니다. 다시 시도해주세요.',
    'SOCIAL_NOT_CONFIGURED' => '서버에서 해당 소셜 로그인이 아직 설정되지 않았습니다. 관리자에게 문의해주세요.',
    '42P01'                 => '서버 DB에 필요한 테이블이 없습니다. 백엔드에서 npm run db:migrate 를 실행했는지 확인해주세요.',
    _                      => e.message,
  };
}
