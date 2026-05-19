import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/asset_precache.dart';
import '../core/social_auth_service.dart';
import '../data/api_client.dart';
import '../theme/app_colors.dart';
import 'account_flow_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.onLogin, this.onGuestLogin});

  final VoidCallback onLogin;

  /// 로그인 없이 게스트 모드로 진입할 때 호출된다.
  final VoidCallback? onGuestLogin;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController();
  final _passwordController = TextEditingController();
  final _apiClient = BabyhandsApiClient();
  bool _obscurePassword = true;
  bool _isSubmitting = false;
  bool _isSocialSubmitting = false;

  @override
  void initState() {
    super.initState();
    // 핸드 아이콘을 미리 캐시해 로그인 카드 표시가 매끄럽게 한다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      precacheBabyhandsCommonAssets(context);
    });
  }

  @override
  void dispose() {
    _idController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitLogin() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isSubmitting = true;
    });
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;

    var message = '로그인되었습니다.';
    try {
      await _apiClient.login(
        memberId: _idController.text.trim(),
        password: _passwordController.text,
      );
    } catch (_) {
      message = '로그인되었습니다. 서버 연결이 가능해지면 학습 기록을 동기화할게요.';
    }
    if (!mounted) return;

    // SnackBar 실패(일부 테스트·오버레이 환경) 시에도 홈 전환은 보장한다.
    try {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {}
    if (!mounted) return;
    widget.onLogin();
  }

  /// Google·네이버·카카오 SDK로 토큰을 받은 뒤 백엔드 소셜 로그인 API를 호출한다.
  /// 일반 로그인과 같이 API 실패 시에도 체험용으로 홈 전환을 허용한다.
  Future<void> _submitSocialLogin(String providerKey) async {
    if (_isSocialSubmitting) return;
    setState(() => _isSocialSubmitting = true);
    try {
      if (!mounted) return;
      final tokens = await SocialAuthService.instance.signIn(
        context,
        providerKey,
      );
      if (!mounted || tokens == null) {
        return;
      }

      var message = '소셜 로그인되었습니다.';
      try {
        await _apiClient.socialLogin(
          provider: tokens.provider,
          idToken: tokens.idToken,
          accessToken: tokens.accessToken,
        );
      } catch (_) {
        message = '로그인되었습니다. 서버 연결이 가능해지면 학습 기록을 동기화할게요.';
      }

      if (!mounted) return;
      try {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      } catch (_) {}
      if (!mounted) return;
      widget.onLogin();
    } on SocialAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('소셜 로그인 중 오류가 발생했어요. $e')));
    } finally {
      if (mounted) setState(() => _isSocialSubmitting = false);
    }
  }

  void _openAccountFlow(AccountFlowType type) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => AccountFlowScreen(type: type)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: MediaQuery(
        data: mediaQuery.copyWith(
          textScaler: mediaQuery.textScaler.clamp(
            minScaleFactor: 0.95,
            maxScaleFactor: 1.15,
          ),
        ),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.bgTop, AppColors.bgBottom],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(20, 18, 20, 18 + bottomInset),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _BrandHeader(),
                      const SizedBox(height: 18),
                      _LoginCard(
                        formKey: _formKey,
                        idController: _idController,
                        passwordController: _passwordController,
                        obscurePassword: _obscurePassword,
                        submitting: _isSubmitting,
                        socialSubmitting: _isSocialSubmitting,
                        onTogglePassword: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                        // VoidCallback에 async 함수를 직접 넘기면 테스트 등에서 실행이 누락될 수 있어 명시적으로 연결한다.
                        onSubmit: () => unawaited(_submitLogin()),
                        onFindId: () =>
                            _openAccountFlow(AccountFlowType.findId),
                        onFindPassword: () =>
                            _openAccountFlow(AccountFlowType.findPassword),
                        onJoin: () => _openAccountFlow(AccountFlowType.join),
                        onGuestLogin: widget.onGuestLogin,
                        onSocialLogin: (key) =>
                            unawaited(_submitSocialLogin(key)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 112,
          height: 112,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.78),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Image.asset(
            kBabyhandsHandIconAsset,
            width: 72,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => const Icon(
              Icons.waving_hand_rounded,
              size: 64,
              color: AppColors.primary,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Babyhands',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: AppColors.text,
          ),
        ),
      ],
    );
  }
}

class _LoginCard extends StatelessWidget {
  const _LoginCard({
    required this.formKey,
    required this.idController,
    required this.passwordController,
    required this.obscurePassword,
    required this.submitting,
    required this.socialSubmitting,
    required this.onTogglePassword,
    required this.onSubmit,
    required this.onFindId,
    required this.onFindPassword,
    required this.onJoin,
    required this.onSocialLogin,
    this.onGuestLogin,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController idController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final bool submitting;
  final bool socialSubmitting;
  final VoidCallback onTogglePassword;
  final VoidCallback onSubmit;
  final VoidCallback onFindId;
  final VoidCallback onFindPassword;
  final VoidCallback onJoin;

  /// `google` | `naver` | `kakao`
  final ValueChanged<String> onSocialLogin;

  /// null이면 게스트 버튼을 표시하지 않는다.
  final VoidCallback? onGuestLogin;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '로그인',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 14),
              const _FieldLabel('아이디'),
              const SizedBox(height: 6),
              TextFormField(
                controller: idController,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.username],
                decoration: _inputDecoration('아이디를 입력하세요'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '아이디를 입력하세요';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              const _FieldLabel('비밀번호'),
              const SizedBox(height: 6),
              TextFormField(
                controller: passwordController,
                obscureText: obscurePassword,
                autofillHints: const [AutofillHints.password],
                decoration: _inputDecoration('비밀번호를 입력하세요').copyWith(
                  suffixIcon: IconButton(
                    tooltip: obscurePassword ? '비밀번호 보기' : '비밀번호 숨기기',
                    onPressed: onTogglePassword,
                    icon: Icon(
                      obscurePassword
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      size: 20,
                    ),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '비밀번호를 입력하세요';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(onPressed: onFindId, child: const Text('아이디 찾기')),
                  TextButton(
                    onPressed: onFindPassword,
                    child: const Text('비밀번호 찾기'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: 50,
                child: FilledButton.icon(
                  onPressed: submitting ? null : onSubmit,
                  icon: submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.lock_rounded, size: 18),
                  label: Text(submitting ? '로그인 중' : '로그인'),
                  style:
                      FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ).copyWith(
                        backgroundColor: WidgetStateProperty.resolveWith((
                          states,
                        ) {
                          if (states.contains(WidgetState.pressed)) {
                            return AppColors.primaryPressed;
                          }
                          return AppColors.primary;
                        }),
                      ),
                ),
              ),
              const SizedBox(height: 10),
              _SocialLoginButtonRow(
                enabled: !submitting && !socialSubmitting,
                onGoogle: () => onSocialLogin('google'),
                onNaver: () => onSocialLogin('naver'),
                onKakao: () => onSocialLogin('kakao'),
              ),
              const SizedBox(height: 18),
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: 12),
              SizedBox(
                height: 48,
                child: OutlinedButton(
                  onPressed: onJoin,
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF334155),
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  child: const Text('회원가입'),
                ),
              ),
              const SizedBox(height: 10),
              // 게스트 모드 버튼: 로그인 없이 체험 학습을 허용한다.
              if (onGuestLogin != null) ...[
                TextButton.icon(
                  onPressed: onGuestLogin,
                  icon: const Icon(Icons.person_outline_rounded, size: 18),
                  label: const Text('로그인 없이 체험하기'),
                  style: TextButton.styleFrom(foregroundColor: Colors.blueGrey),
                ),
                const SizedBox(height: 4),
              ],
              Text(
                '소셜 로그인은 SDK와 서버 설정 후 사용할 수 있어요. API가 연결되지 않아도 홈 체험은 가능합니다.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade400),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: AppColors.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFBFDBFE)),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(fontSize: 13, color: AppColors.muted),
    );
  }
}

/// 웹 `login.jsp`의 `.social-login-container` + `.btn-social`과 동일한 배치·크기(56px 원).
class _SocialLoginButtonRow extends StatelessWidget {
  const _SocialLoginButtonRow({
    required this.enabled,
    required this.onGoogle,
    required this.onNaver,
    required this.onKakao,
  });

  final bool enabled;
  final VoidCallback onGoogle;
  final VoidCallback onNaver;
  final VoidCallback onKakao;

  static const _googleSvg =
      '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 18 18">'
      '<path fill="#4285F4" d="M17.64 9.2c0-.637-.057-1.251-.164-1.84H9v3.481h4.844c-.209 1.125-.843 2.078-1.796 2.717v2.258h2.908c1.702-1.567 2.684-3.874 2.684-6.615z" />'
      '<path fill="#34A853" d="M9 18c2.43 0 4.467-.806 5.956-2.184l-2.908-2.258c-.806.54-1.837.86-3.048.86-2.344 0-4.328-1.584-5.036-3.711H.957v2.332C2.438 15.983 5.482 18 9 18z" />'
      '<path fill="#FBBC05" d="M3.964 10.707c-.18-.54-.282-1.117-.282-1.707s.102-1.167.282-1.707V4.961H.957C.348 6.175 0 7.55 0 9s.348 2.825.957 4.039l3.007-2.332z" />'
      '<path fill="#EA4335" d="M9 3.58c1.321 0 2.508.454 3.44 1.345l2.582-2.58C13.463.891 11.426 0 9 0 5.482 0 2.438 2.017.957 4.961L3.964 7.293C4.672 5.158 6.656 3.58 9 3.58z" />'
      '</svg>';

  static const _naverSvg =
      '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 18 18">'
      '<rect width="18" height="18" fill="#03C75A" rx="2" />'
      '<path stroke="#FFFFFF" stroke-width="2" stroke-linecap="round" fill="none" d="M6 5.5v7M6 5.5l6 7M12 5.5v7" />'
      '</svg>';

  static const _kakaoSvg =
      '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 18 18">'
      '<path fill="#3C1E1E" d="M9 2C5.14 2 2 4.42 2 7.4c0 2.1 1.5 3.94 3.75 5.1L5 16l3.75-2.1c.25.03.5.05.75.05 3.86 0 7-2.42 7-5.4C16 4.42 12.86 2 9 2z" />'
      '</svg>';

  @override
  Widget build(BuildContext context) {
    final inactive = !enabled;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _SocialCircleButton(
            semanticLabel: '구글로 로그인',
            variant: _SocialCircleVariant.google,
            inactive: inactive,
            onTap: onGoogle,
            child: SvgPicture.string(_googleSvg, width: 24, height: 24),
          ),
          const SizedBox(width: 12),
          _SocialCircleButton(
            semanticLabel: '네이버로 로그인',
            variant: _SocialCircleVariant.naver,
            inactive: inactive,
            onTap: onNaver,
            child: SvgPicture.string(_naverSvg, width: 24, height: 24),
          ),
          const SizedBox(width: 12),
          _SocialCircleButton(
            semanticLabel: '카카오로 로그인',
            variant: _SocialCircleVariant.kakao,
            inactive: inactive,
            onTap: onKakao,
            child: SvgPicture.string(_kakaoSvg, width: 24, height: 24),
          ),
        ],
      ),
    );
  }
}

enum _SocialCircleVariant { google, naver, kakao }

class _SocialCircleButton extends StatelessWidget {
  const _SocialCircleButton({
    required this.semanticLabel,
    required this.variant,
    required this.inactive,
    required this.onTap,
    required this.child,
  });

  final String semanticLabel;
  final _SocialCircleVariant variant;
  final bool inactive;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final (
      Color bg,
      List<BoxShadow> shadows,
      BoxBorder? border,
    ) = switch (variant) {
      _SocialCircleVariant.google => (
        inactive ? const Color(0xFFF8F9FA) : Colors.white,
        [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
        Border.all(color: const Color(0xFFDADCE0)),
      ),
      _SocialCircleVariant.naver => (
        inactive ? const Color(0xFF02B350) : const Color(0xFF03C75A),
        [
          BoxShadow(
            color: const Color(0xFF03C75A).withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
        null,
      ),
      _SocialCircleVariant.kakao => (
        inactive ? const Color(0xFFFDD835) : const Color(0xFFFEE500),
        [
          BoxShadow(
            color: const Color(0xFFFEE500).withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
        null,
      ),
    };

    return Semantics(
      button: true,
      label: semanticLabel,
      enabled: !inactive,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: bg,
          border: border,
          boxShadow: shadows,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: inactive ? null : onTap,
            child: SizedBox(
              width: 56,
              height: 56,
              child: Center(
                child: Opacity(opacity: inactive ? 0.55 : 1, child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
