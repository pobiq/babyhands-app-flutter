import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:babyhands/main.dart';
import 'package:babyhands/screens/account_flow_screen.dart';
import 'package:babyhands/screens/learn_screen.dart';
import 'package:babyhands/screens/test_screen.dart';

/// 로그인 버튼 탭 후 지연·HTTP 응답·홈 전환이 끝날 때까지 시간을 진행한다.
/// pumpAndSettle만 쓰면 네트워크 대기 중 프레임이 없어 조기 종료될 수 있다.
/// 이후 pumpAndSettle은 로딩 스피너 등으로 타임아웃될 수 있어 생략한다.
Future<void> settleAfterLoginTap(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 2500));
  await tester.pump();
}

/// 화면 전환(Hero 등) 직후 pumpAndSettle이 타임아웃될 수 있어 고정 시간만 진행한다.
Future<void> pumpAfterNavigation(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pump();
}

void main() {
  setUp(() async {
    // HomeScreen.loadDashboard가 SharedPreferences를 사용하므로 위젯 테스트에서 모킹한다.
    SharedPreferences.setMockInitialValues({});
  });

  // ─── 기존 통합 테스트 ──────────────────────────────────────────────────

  testWidgets('로그인 화면이 표시된다', (WidgetTester tester) async {
    await tester.pumpWidget(const BabyhandsApp());

    expect(find.text('Login'), findsWidgets);
    expect(find.text('User ID'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Sign up'), findsOneWidget);
  });

  testWidgets('게스트로 진입하면 홈에 게스트 안내가 표시된다', (tester) async {
    await tester.pumpWidget(const BabyhandsApp());

    await tester.ensureVisible(find.text('로그인 없이 체험하기'));
    await tester.tap(find.text('로그인 없이 체험하기'));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();

    expect(find.byKey(const ValueKey<String>('home')), findsOneWidget);
    expect(find.textContaining('게스트 모드'), findsOneWidget);
  });

  testWidgets('올바른 정보로 로그인하면 홈 화면으로 이동한다', (tester) async {
    await tester.pumpWidget(const BabyhandsApp());

    await tester.enterText(find.byType(EditableText).at(0), 'tester');
    await tester.enterText(find.byType(EditableText).at(1), 'password');
    await tester.tap(find.widgetWithText(FilledButton, 'Login'));
    await settleAfterLoginTap(tester);

    expect(
      find.byKey(const ValueKey<String>('home')),
      findsOneWidget,
      reason: '로그인 후 AuthGate가 홈으로 전환해야 한다',
    );
    expect(find.text('Attendance Calendar'), findsOneWidget);
    expect(find.text('Today Progress'), findsOneWidget);
    expect(find.text('Today Goal'), findsOneWidget);
    expect(find.text('Recommended Next Letters'), findsOneWidget);
  });

  testWidgets('Sign up 버튼을 누르면 회원가입 화면으로 이동하고 Back to login으로 돌아온다',
      (tester) async {
    await tester.pumpWidget(const BabyhandsApp());

    await tester.ensureVisible(find.text('Sign up'));
    await tester.tap(find.text('Sign up'));
    await tester.pumpAndSettle();
    expect(find.text('Create account'), findsOneWidget);

    await tester.ensureVisible(find.text('Back to login'));
    await tester.tap(find.text('Back to login'));
    await tester.pumpAndSettle();
    expect(find.text('Social login'), findsOneWidget);
  });

  testWidgets('홈 화면에서 Test, My Page 아이콘 탭으로 이동할 수 있다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const BabyhandsApp());

    await tester.enterText(find.byType(EditableText).at(0), 'tester');
    await tester.enterText(find.byType(EditableText).at(1), 'password');
    await tester.tap(find.widgetWithText(FilledButton, 'Login'));
    await settleAfterLoginTap(tester);

    await tester.tap(find.byTooltip('Test'));
    await pumpAfterNavigation(tester);
    expect(find.text('Finger Alphabet Test'), findsOneWidget);

    final myPageOnTest = find.descendant(
      of: find.byType(TestScreen),
      matching: find.byTooltip('My Page'),
    );
    await tester.ensureVisible(myPageOnTest);
    await tester.tap(myPageOnTest);
    await pumpAfterNavigation(tester);
    expect(find.text('Recent Activity'), findsOneWidget);
  });

  // ─── 위젯 테스트: 로그인 폼 유효성 검증 ──────────────────────────────────

  testWidgets('User ID 없이 로그인 버튼을 누르면 유효성 에러가 표시된다', (tester) async {
    await tester.pumpWidget(const BabyhandsApp());

    // ID 입력 없이 비밀번호만 입력한다.
    await tester.enterText(find.byType(EditableText).at(1), 'password');
    await tester.tap(find.widgetWithText(FilledButton, 'Login'));
    await tester.pump();

    // 힌트와 에러 문구가 동일해 2개 이상 매칭될 수 있다.
    expect(find.text('Enter your ID'), findsAtLeastNWidgets(1));
  });

  testWidgets('비밀번호 없이 로그인 버튼을 누르면 유효성 에러가 표시된다', (tester) async {
    await tester.pumpWidget(const BabyhandsApp());

    // 비밀번호 입력 없이 ID만 입력한다.
    await tester.enterText(find.byType(EditableText).at(0), 'testuser');
    await tester.tap(find.widgetWithText(FilledButton, 'Login'));
    await tester.pump();

    expect(find.text('Enter your password'), findsAtLeastNWidgets(1));
  });

  testWidgets('ID와 비밀번호를 모두 입력하면 폼 유효성을 통과한다', (tester) async {
    await tester.pumpWidget(const BabyhandsApp());

    await tester.enterText(find.byType(EditableText).at(0), 'testuser');
    await tester.enterText(find.byType(EditableText).at(1), 'password');
    await tester.tap(find.widgetWithText(FilledButton, 'Login'));
    await settleAfterLoginTap(tester);

    // 로그인 필드 힌트와 동일한 문구가 있어, 홈 전환으로 유효성 통과를 검증한다.
    expect(find.byKey(const ValueKey<String>('home')), findsOneWidget);
  });

  // ─── 위젯 테스트: 회원가입 폼 필드 검증 ────────────────────────────────────

  testWidgets('회원가입 화면에 모든 입력 필드가 표시된다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AccountFlowScreen(type: AccountFlowType.join),
      ),
    );

    expect(find.text('User ID'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Nickname'), findsOneWidget);
    expect(find.text('Email (선택)'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
  });

  testWidgets('회원가입 폼에서 User ID 없이 제출하면 유효성 에러가 표시된다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AccountFlowScreen(type: AccountFlowType.join),
      ),
    );

    await tester.tap(find.text('Create account'));
    await tester.pump();

    expect(find.text('User ID를 입력해주세요.'), findsOneWidget);
  });

  testWidgets('회원가입 폼에서 비밀번호 8자 미만이면 에러가 표시된다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AccountFlowScreen(type: AccountFlowType.join),
      ),
    );

    // User ID 입력
    await tester.enterText(find.byType(TextFormField).at(0), 'validuser');
    // 짧은 비밀번호 입력
    await tester.enterText(find.byType(TextFormField).at(1), 'short');
    await tester.tap(find.text('Create account'));
    await tester.pump();

    expect(find.text('8자 이상 입력해주세요.'), findsOneWidget);
  });

  testWidgets('아이디 찾기 화면 필드·유효성 (이메일 미입력)', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AccountFlowScreen(type: AccountFlowType.findId),
      ),
    );

    expect(find.text('Find ID'), findsWidgets);
    expect(find.text('Email'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Find ID'));
    await tester.pump();
    expect(find.text('이메일을 입력해주세요.'), findsOneWidget);
  });

  testWidgets('비밀번호 찾기 화면 필드·유효성 (아이디 미입력)', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AccountFlowScreen(type: AccountFlowType.findPassword),
      ),
    );

    expect(find.text('Find Password'), findsOneWidget);
    expect(find.text('User ID'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    await tester.tap(find.text('Reset password'));
    await tester.pump();
    expect(find.text('User ID를 입력해주세요.'), findsOneWidget);
  });

  // ─── 통합 테스트: 로그인 → 학습 화면 → 글자 선택 흐름 ─────────────────────

  testWidgets('로그인 후 학습 화면으로 이동하면 Finger Alphabet Learning이 표시된다',
      (tester) async {
    await tester.pumpWidget(const BabyhandsApp());

    await tester.enterText(find.byType(EditableText).at(0), 'tester');
    await tester.enterText(find.byType(EditableText).at(1), 'password');
    await tester.tap(find.widgetWithText(FilledButton, 'Login'));
    await settleAfterLoginTap(tester);

    await tester.tap(find.byTooltip('Learn'));
    await pumpAfterNavigation(tester);

    expect(find.text('Finger Alphabet Learning'), findsOneWidget);
    // 기본 선택 글자 ㄱ이 표시된다.
    expect(find.text('Current letter ㄱ'), findsOneWidget);
  });

  testWidgets('학습 화면에서 다른 글자를 선택하면 연습 패널이 갱신된다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const BabyhandsApp());

    await tester.enterText(find.byType(EditableText).at(0), 'tester');
    await tester.enterText(find.byType(EditableText).at(1), 'password');
    await tester.tap(find.widgetWithText(FilledButton, 'Login'));
    await settleAfterLoginTap(tester);

    await tester.tap(find.byTooltip('Learn'));
    await pumpAfterNavigation(tester);

    // ㄴ을 선택한다. (현재 글자 표시와 피커에 동일 문자가 있을 수 있음)
    await tester.tap(find.text('ㄴ').last);
    await tester.pump();

    expect(find.text('Current letter ㄴ'), findsOneWidget);
  });

  testWidgets('학습 화면에서 홈으로 돌아오면 홈 대시보드가 표시된다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const BabyhandsApp());

    await tester.enterText(find.byType(EditableText).at(0), 'tester');
    await tester.enterText(find.byType(EditableText).at(1), 'password');
    await tester.tap(find.widgetWithText(FilledButton, 'Login'));
    await settleAfterLoginTap(tester);

    await tester.tap(find.byTooltip('Learn'));
    await pumpAfterNavigation(tester);

    // 홈 아이콘으로 되돌아간다.
    final homeOnLearn = find.descendant(
      of: find.byType(LearnScreen),
      matching: find.byTooltip('Home'),
    );
    await tester.ensureVisible(homeOnLearn);
    await tester.tap(homeOnLearn);
    await pumpAfterNavigation(tester);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    expect(find.text('Attendance Calendar'), findsOneWidget);
    expect(find.text('Today Progress'), findsOneWidget);
  });
}
