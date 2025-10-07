// lib/features/auth/auth_checker.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dognal1/core/providers/auth_provider.dart'; // Core Provider 가져오기
import 'package:dognal1/features/auth/screens/home_screen.dart';
import 'package:dognal1/features/auth/screens/sign_in_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthChecker extends ConsumerWidget {
  const AuthChecker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateChangesProvider);

    return authState.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (err, stack) => Scaffold(
        body: Center(child: Text('Error loading auth state: $err')),
      ),
      data: (AuthState data) {
        final session = data.session;

        // 유효한 세션이 있다면 홈 화면, 아니면 로그인 화면
        if (session != null && session.user != null) {
          return const HomeScreen();
        } else {
          return const SignInScreen();
        }
      },
    );
  }
}