// lib/features/auth/screens/sign_in_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:dognal1/core/providers/auth_provider.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  late final supabase.SupabaseClient _supabase;

  @override
  void initState() {
    super.initState();
    _supabase = ref.read(supabaseClientProvider);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // 이메일/비밀번호 로그인 처리
  Future<void> _signIn() async {
    setState(() => _isLoading = true);
    try {
      await _supabase.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
    } on supabase.AuthException catch (e) {
      _showSnackbar('Login failed: ${e.message}');
    } catch (e) {
      _showSnackbar('An unexpected error occurred.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 💡 모달 내에서 호출될 회원가입 처리 로직 (버튼 로딩 상태 분리)
  Future<void> _signUpInModal({required String email, required String password}) async {
    try {
      await _supabase.auth.signUp(
        email: email.trim(),
        password: password.trim(),
      );
      // Confirm Email 설정에 따라 메시지 다르게 표시
      _showSnackbar('회원가입 성공! 이메일 인증을 완료해야 로그인할 수 있습니다.');

      // 가입 성공 시 모달 닫기
      if (mounted) Navigator.of(context).pop();

    } on supabase.AuthException catch (e) {
      _showSnackbar('회원가입 실패: ${e.message}');
    } catch (e) {
      _showSnackbar('예기치 않은 오류가 발생했습니다.');
    }
  }

  // 💡 Google 소셜 로그인 처리 (이전에 완성된 로직)
  Future<void> _socialSignIn() async {
    setState(() => _isLoading = true);

    try {
      await _supabase.auth.signInWithOAuth(
        supabase.OAuthProvider.google,

        // 딥링크 주소는 그대로 유지합니다.
        redirectTo: 'io.supabase.flutter://login-callback/',

      );
    } on supabase.AuthException catch (e) {
      _showSnackbar('Google login failed: ${e.message}');
    } catch (e) {
      _showSnackbar('An unexpected error occurred during Google sign-in.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 💡 모달 띄우는 함수 (Dialog)
  void _showSignUpModal() {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return _SignUpDialog(onSignUp: _signUpInModal); // onSignUp 콜백 전달
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dognal Login')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              // --- 1. 이메일/비밀번호 폼 (로그인 전용) ---
              TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email')
              ),
              const SizedBox(height: 16),
              TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Password')
              ),
              const SizedBox(height: 30),

              // 로그인 버튼 및 로딩 인디케이터
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(onPressed: _signIn, child: const Text('Sign In')),

              const SizedBox(height: 50),

              // 💡 Google 로그인 버튼만 남김
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _socialSignIn, // 로딩 중에는 비활성화
                icon: const Icon(Icons.g_mobiledata),
                label: const Text('Sign in with Google'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),

              const SizedBox(height: 40),

              // 💡 회원가입 모달을 띄우는 버튼
              TextButton(
                onPressed: _showSignUpModal,
                child: const Text('No account? Sign Up', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


// --- 💡 별도의 회원가입 모달(Dialog) 위젯 ---
class _SignUpDialog extends StatefulWidget {
  final Future<void> Function({required String email, required String password}) onSignUp;

  const _SignUpDialog({required this.onSignUp});

  @override
  __SignUpDialogState createState() => __SignUpDialogState();
}

class __SignUpDialogState extends State<_SignUpDialog> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSigningUp = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Email Sign Up'),
      content: SingleChildScrollView(
        child: ListBody(
          children: <Widget>[
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'New Email'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'New Password'),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        _isSigningUp
            ? const Center(child: CircularProgressIndicator())
            : ElevatedButton(
          onPressed: () async {
            setState(() => _isSigningUp = true);
            // 모달 밖의 _signUpInModal 함수 호출
            await widget.onSignUp(
              email: _emailController.text,
              password: _passwordController.text,
            );
            // 성공 여부와 관계없이 로딩 상태는 해제
            if (mounted) setState(() => _isSigningUp = false);
          },
          child: const Text('Sign Up'),
        ),
      ],
    );
  }
}