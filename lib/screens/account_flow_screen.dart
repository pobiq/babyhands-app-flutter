import 'package:flutter/material.dart';

import '../data/api_client.dart';
import '../theme/app_colors.dart';

enum AccountFlowType { join, findId, findPassword }

/// 회원가입 / 아이디 찾기 / 비밀번호 찾기 화면이다.
/// join은 회원가입 API, findId·findPassword는 `/api/auth` 계정 복구 API를 호출한다.
class AccountFlowScreen extends StatefulWidget {
  const AccountFlowScreen({super.key, required this.type});

  final AccountFlowType type;

  @override
  State<AccountFlowScreen> createState() => _AccountFlowScreenState();
}

class _AccountFlowScreenState extends State<AccountFlowScreen> {
  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _emailController = TextEditingController();
  final _emailVerificationCodeController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _apiClient = BabyhandsApiClient();

  bool _isSubmitting = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isVerificationCodeSent = false;
  bool _isVerificationCompleted = false;
  String? _emailVerificationToken;

  @override
  void dispose() {
    _idController.dispose();
    _passwordController.dispose();
    _nicknameController.dispose();
    _emailController.dispose();
    _emailVerificationCodeController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String get _title => switch (widget.type) {
    AccountFlowType.join => '회원가입',
    AccountFlowType.findId => '아이디 찾기',
    AccountFlowType.findPassword => '비밀번호 찾기',
  };

  IconData get _icon => switch (widget.type) {
    AccountFlowType.join => Icons.person_add_alt_1_rounded,
    AccountFlowType.findId => Icons.badge_rounded,
    AccountFlowType.findPassword => Icons.lock_reset_rounded,
  };

  String get _buttonLabel => switch (widget.type) {
    AccountFlowType.join => '회원가입 완료',
    AccountFlowType.findId => '아이디 찾기',
    AccountFlowType.findPassword => '비밀번호 재설정',
  };

  Future<void> _sendEmailVerificationCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('이메일을 먼저 입력해주세요.')));
      return;
    }
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('이메일 형식이 올바르지 않습니다.')));
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await _apiClient.sendSignupEmailVerificationCode(email: email);
      if (!mounted) return;
      setState(() {
        _isVerificationCodeSent = true;
        _isVerificationCompleted = false;
        _emailVerificationToken = null;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('인증번호를 이메일로 보냈어요.')));
    } on BabyhandsApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(resolveApiErrorMessage(e))));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('인증번호 발송에 실패했어요.')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _verifyEmailCode() async {
    final email = _emailController.text.trim();
    final code = _emailVerificationCodeController.text.trim();
    if (!_isVerificationCodeSent) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('먼저 인증번호를 받아주세요.')));
      return;
    }
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('인증번호 6자리를 입력해주세요.')));
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final token = await _apiClient.verifySignupEmailVerificationCode(
        email: email,
        code: code,
      );
      if (!mounted) return;
      setState(() {
        _emailVerificationToken = token;
        _isVerificationCompleted = true;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('이메일 인증이 완료되었습니다.')));
    } on BabyhandsApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(resolveApiErrorMessage(e))));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('인증 확인에 실패했어요.')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  /// 회원가입 API를 호출한다. 성공 시 로그인 화면으로 복귀한다.
  Future<void> _submitJoin() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_isVerificationCompleted || _emailVerificationToken == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('이메일 인증 확인을 먼저 완료해주세요.')));
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await _apiClient.register(
        memberId: _emailController.text.trim(),
        password: _passwordController.text,
        nickname: _nicknameController.text.trim(),
        email: _emailController.text.trim(),
        emailVerificationToken: _emailVerificationToken,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('회원가입이 완료되었습니다. 로그인해주세요.')));
      Navigator.of(context).pop();
    } on BabyhandsApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(resolveApiErrorMessage(e))));
    } catch (_) {
      if (!mounted) return;
      // 서버 미연동 상태에서는 성공으로 처리한다.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('서버 연결 후 회원가입이 가능합니다. (현재 오프라인 모드)')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  /// 등록 이메일로 아이디를 조회한 뒤 안내 다이얼로그를 띄운다.
  Future<void> _submitFindId() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSubmitting = true);
    try {
      final memberId = await _apiClient.findMemberIdByEmail(
        email: _emailController.text.trim(),
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('아이디 안내'),
          content: SelectableText('회원 아이디: $memberId'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('확인'),
            ),
          ],
        ),
      );
    } on BabyhandsApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(resolveApiErrorMessage(e))));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('네트워크 오류가 발생했습니다. 잠시 후 다시 시도해주세요.')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  /// 아이디·이메일 검증 후 새 비밀번호로 재설정한다.
  Future<void> _submitResetPassword() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('비밀번호 확인이 일치하지 않습니다.')));
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await _apiClient.resetPassword(
        memberId: _idController.text.trim(),
        email: _emailController.text.trim(),
        newPassword: _passwordController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('비밀번호가 변경되었습니다. 새 비밀번호로 로그인해주세요.')),
      );
      Navigator.of(context).pop();
    } on BabyhandsApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(resolveApiErrorMessage(e))));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('네트워크 오류가 발생했습니다. 잠시 후 다시 시도해주세요.')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  VoidCallback get _onSubmit => switch (widget.type) {
    AccountFlowType.join => _submitJoin,
    AccountFlowType.findId => () => _submitFindId(),
    AccountFlowType.findPassword => () => _submitResetPassword(),
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
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
                padding: const EdgeInsets.all(20),
                child: Material(
                  color: AppColors.card,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Icon(_icon, color: AppColors.primary, size: 46),
                          const SizedBox(height: 12),
                          Text(
                            _title,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  color: AppColors.text,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                          const SizedBox(height: 20),
                          ..._buildFields(),
                          const SizedBox(height: 18),
                          FilledButton(
                            onPressed: _isSubmitting ? null : _onSubmit,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: _isSubmitting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(_buttonLabel),
                          ),
                          const SizedBox(height: 10),
                          TextButton.icon(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.arrow_back_rounded),
                            label: const Text('로그인으로 돌아가기'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildFields() {
    switch (widget.type) {
      case AccountFlowType.join:
        return [
          _ValidatedField(
            label: '이메일',
            hint: 'example@email.com',
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return '이메일을 입력해주세요.';
              if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v.trim())) {
                return '이메일 형식이 올바르지 않습니다.';
              }
              return null;
            },
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: _isSubmitting ? null : _sendEmailVerificationCode,
              icon: const Icon(Icons.mark_email_read_outlined, size: 18),
              label: Text(_isVerificationCodeSent ? '인증번호 재전송' : '인증번호 받기'),
            ),
          ),
          const SizedBox(height: 12),
          _ValidatedField(
            label: '이메일 인증번호',
            hint: '6자리 숫자 입력',
            controller: _emailVerificationCodeController,
            keyboardType: TextInputType.number,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return '인증번호를 입력해주세요.';
              if (!RegExp(r'^\d{6}$').hasMatch(v.trim())) {
                return '인증번호 6자리를 입력해주세요.';
              }
              return null;
            },
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: _isSubmitting ? null : _verifyEmailCode,
              icon: Icon(
                _isVerificationCompleted
                    ? Icons.verified_rounded
                    : Icons.verified_outlined,
                size: 18,
              ),
              label: Text(_isVerificationCompleted ? '인증 완료됨' : '인증 확인'),
            ),
          ),
          const SizedBox(height: 12),
          _ValidatedField(
            label: '비밀번호',
            hint: '8자 이상',
            controller: _passwordController,
            obscureText: _obscurePassword,
            suffixIcon: IconButton(
              tooltip: _obscurePassword ? '비밀번호 보기' : '비밀번호 숨기기',
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                size: 20,
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return '비밀번호를 입력해주세요.';
              if (v.length < 8) return '8자 이상 입력해주세요.';
              return null;
            },
          ),
          const SizedBox(height: 12),
          _ValidatedField(
            label: '닉네임',
            hint: '2~20자',
            controller: _nicknameController,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return '닉네임을 입력해주세요.';
              if (v.trim().length < 2) return '2자 이상 입력해주세요.';
              return null;
            },
          ),
        ];
      case AccountFlowType.findId:
        return [
          _ValidatedField(
            label: 'Email',
            hint: '가입 시 사용한 이메일',
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return '이메일을 입력해주세요.';
              }
              if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v.trim())) {
                return '이메일 형식이 올바르지 않습니다.';
              }
              return null;
            },
          ),
        ];
      case AccountFlowType.findPassword:
        return [
          _ValidatedField(
            label: 'User ID',
            hint: '가입 시 사용한 아이디',
            controller: _idController,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'User ID를 입력해주세요.';
              if (v.trim().length < 4) return '4자 이상 입력해주세요.';
              if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(v.trim())) {
                return '영문, 숫자, 밑줄(_)만 사용 가능합니다.';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          _ValidatedField(
            label: 'Email',
            hint: '가입 시 사용한 이메일',
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return '이메일을 입력해주세요.';
              }
              if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v.trim())) {
                return '이메일 형식이 올바르지 않습니다.';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          _ValidatedField(
            label: 'New password',
            hint: '8자 이상',
            controller: _passwordController,
            obscureText: _obscurePassword,
            suffixIcon: IconButton(
              tooltip: _obscurePassword ? 'Show password' : 'Hide password',
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                size: 20,
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return '비밀번호를 입력해주세요.';
              if (v.length < 8) return '8자 이상 입력해주세요.';
              return null;
            },
          ),
          const SizedBox(height: 12),
          _ValidatedField(
            label: 'Confirm password',
            hint: '새 비밀번호 다시 입력',
            controller: _confirmPasswordController,
            obscureText: _obscureConfirmPassword,
            suffixIcon: IconButton(
              tooltip: _obscureConfirmPassword
                  ? 'Show password'
                  : 'Hide password',
              onPressed: () => setState(
                () => _obscureConfirmPassword = !_obscureConfirmPassword,
              ),
              icon: Icon(
                _obscureConfirmPassword
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                size: 20,
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return '비밀번호 확인을 입력해주세요.';
              if (v != _passwordController.text) {
                return '비밀번호가 서로 일치하지 않습니다.';
              }
              return null;
            },
          ),
        ];
    }
  }
}

/// 레이블과 유효성 검사를 포함한 텍스트 입력 필드다.
class _ValidatedField extends StatelessWidget {
  const _ValidatedField({
    required this.label,
    required this.hint,
    required this.controller,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
    this.suffixIcon,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final bool obscureText;
  final TextInputType? keyboardType;
  final FormFieldValidator<String>? validator;
  final Widget? suffixIcon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: AppColors.muted),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 13,
            ),
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
          ),
        ),
      ],
    );
  }
}
