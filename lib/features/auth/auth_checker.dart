import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dognal1/core/providers/auth_provider.dart';
import 'package:dognal1/features/auth/screens/home_screen.dart'; // home_screen.dart 경로 확인 필요
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

        if (session != null && session.user != null) {
          // ✅ 핵심: 사용자마다 고유한 Key를 부여하여 위젯이 재사용되는 것을 방지합니다.
          return HomeScreen(key: ValueKey(session.user.id));
        } else {
          return const SignInScreen();
        }
      },
    );
  }
}