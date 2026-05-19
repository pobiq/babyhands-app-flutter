import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_naver_login/flutter_naver_login.dart';
import 'package:flutter_naver_login/interface/types/naver_login_result.dart';
import 'package:flutter_naver_login/interface/types/naver_login_status.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart';

/// 소셜 SDK에서 받은 토큰을 백엔드 `/api/auth/social`로 넘기기 위한 값 묶음이다.
class SocialAuthTokens {
  const SocialAuthTokens({
    required this.provider,
    this.idToken,
    this.accessToken,
  });

  /// `google` | `naver` | `kakao`
  final String provider;
  final String? idToken;
  final String? accessToken;
}

/// 소셜 로그인 흐름에서 사용자에게 보여줄 예외다.
class SocialAuthException implements Exception {
  SocialAuthException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Google·네이버·카카오 SDK 호출을 한곳에서 처리한다.
///
/// **빌드·네이티브 설정**
/// - Google(Android): `BABYHANDS_GOOGLE_WEB_CLIENT_ID`에 웹 클라이언트 ID를 `--dart-define`으로 넘기면 ID 토큰 발급에 유리하다.
/// - Kakao: `BABYHANDS_KAKAO_NATIVE_APP_KEY`를 `main.dart`에서 `KakaoSdk.init`에 사용한다. iOS는 `Info.plist`의 URL Scheme(`kakao{네이티브앱키}`)을 동일 키로 맞춘다.
/// - Naver: Android `res/values/strings.xml`의 `naver_client_id` / `naver_client_secret`을 발급 값으로 교체하고, `AndroidManifest`의 메타데이터가 이를 참조하는지 확인한다.
class SocialAuthService {
  SocialAuthService._();
  static final SocialAuthService instance = SocialAuthService._();

  static const String _googleWebClientId = String.fromEnvironment(
    'BABYHANDS_GOOGLE_WEB_CLIENT_ID',
    defaultValue: '',
  );

  /// `google` / `naver` / `kakao`. 사용자가 취소하면 null.
  /// 카카오는 로그인 선택 바텀시트를 띄우므로 [context]가 필요하다.
  Future<SocialAuthTokens?> signIn(
    BuildContext context,
    String providerKey,
  ) async {
    if (kIsWeb) {
      throw SocialAuthException('웹 빌드에서는 소셜 로그인을 지원하지 않습니다.');
    }

    switch (providerKey) {
      case 'google':
        return _signInGoogle();
      case 'naver':
        return _signInNaver();
      case 'kakao':
        return _signInKakao(context);
      default:
        throw SocialAuthException('지원하지 않는 로그인입니다.');
    }
  }

  Future<SocialAuthTokens?> _signInGoogle() async {
    final GoogleSignIn googleSignIn = GoogleSignIn(
      scopes: const <String>['email', 'profile'],
      serverClientId: _googleWebClientId.isEmpty ? null : _googleWebClientId,
    );
    final GoogleSignInAccount? account = await googleSignIn.signIn();
    if (account == null) {
      return null;
    }
    final GoogleSignInAuthentication auth = await account.authentication;
    final String? idToken = auth.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw SocialAuthException(
        'Google ID 토큰을 가져오지 못했습니다. '
        'Android/iOS에서 OAuth 클라이언트 설정 및 '
        '빌드 시 BABYHANDS_GOOGLE_WEB_CLIENT_ID(Web 클라이언트 ID) 지정을 확인하세요.',
      );
    }
    return SocialAuthTokens(provider: 'google', idToken: idToken);
  }

  Future<SocialAuthTokens?> _signInNaver() async {
    final NaverLoginResult res = await FlutterNaverLogin.logIn();
    if (res.status != NaverLoginStatus.loggedIn) {
      if (res.status == NaverLoginStatus.error) {
        throw SocialAuthException(
          res.errorMessage ?? '네이버 로그인에 실패했습니다.',
        );
      }
      return null;
    }
    final String? accessToken = res.accessToken?.accessToken;
    if (accessToken == null || accessToken.isEmpty) {
      throw SocialAuthException('네이버 액세스 토큰을 받지 못했습니다.');
    }
    return SocialAuthTokens(provider: 'naver', accessToken: accessToken);
  }

  Future<SocialAuthTokens?> _signInKakao(BuildContext context) async {
    try {
      final OAuthToken token = await UserApi.instance.loginWithKakao(context);
      return SocialAuthTokens(provider: 'kakao', accessToken: token.accessToken);
    } on KakaoAuthException catch (e) {
      if (e.error == AuthErrorCause.accessDenied) {
        return null;
      }
      throw SocialAuthException(
        e.errorDescription ?? '카카오 로그인에 실패했습니다.',
      );
    }
  }
}
