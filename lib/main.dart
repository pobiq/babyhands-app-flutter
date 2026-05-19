import 'package:flutter/material.dart';
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart';
import 'package:provider/provider.dart';

import 'core/notification_service.dart';
import 'data/api_client.dart';
import 'data/home_progress_repository.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';

/// 앱 진입점. 알림 서비스를 초기화하고 Provider를 구성한 뒤 앱을 시작한다.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 카카오 로그인: 네이티브 앱 키를 빌드 시 넘기면 SDK를 초기화한다.
  const kakaoNativeKey = String.fromEnvironment(
    'BABYHANDS_KAKAO_NATIVE_APP_KEY',
    defaultValue: '',
  );
  if (kakaoNativeKey.isNotEmpty) {
    KakaoSdk.init(nativeAppKey: kakaoNativeKey);
  }
  await NotificationService.instance.initialize();
  runApp(const BabyhandsApp());
}

class BabyhandsApp extends StatelessWidget {
  const BabyhandsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // AppHomeProgressRepository를 ChangeNotifier Provider로 제공한다.
        // 학습/테스트 완료 시 구독 위젯이 자동으로 갱신된다.
        ChangeNotifierProvider<AppHomeProgressRepository>.value(
          value: AppHomeProgressRepository.instance,
        ),
      ],
      child: MaterialApp(
        title: 'Babyhands',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF58CC02)),
          scaffoldBackgroundColor: const Color(0xFFFAFFFB),
          useMaterial3: true,
        ),
        home: const AuthGate(),
      ),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _isLoggedIn = false;

  /// 일반 로그인 성공 시 호출한다.
  void _login() {
    setState(() => _isLoggedIn = true);
    // 로그인 성공 시 일일 학습 알림을 예약한다.
    NotificationService.instance.scheduleDailyReminder();
  }

  /// 로그인 없이 게스트 모드로 진입할 때 호출한다.
  void _guestLogin() {
    AuthSession.instance.guestLogin();
    setState(() => _isLoggedIn = true);
    // 설정에서 알림을 켠 사용자는 게스트 모드에서도 동일하게 예약한다.
    NotificationService.instance.scheduleDailyReminder();
  }

  void _logout() {
    AuthSession.instance.clear();
    // 일일 학습 알림은 마이페이지 설정을 따르며, 로그아웃해도 유지한다.
    setState(() => _isLoggedIn = false);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: _isLoggedIn
          ? HomeScreen(
              key: const ValueKey('home'),
              onLogout: _logout,
            )
          : LoginScreen(
              key: const ValueKey('login'),
              onLogin: _login,
              onGuestLogin: _guestLogin,
            ),
    );
  }
}
