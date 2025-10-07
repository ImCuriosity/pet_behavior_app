// lib/features/auth/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dognal1/core/providers/auth_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  // Supabase를 통한 로그아웃 처리
  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final supabase = ref.read(supabaseClientProvider);
    try {
      await supabase.auth.signOut();
      // 로그아웃 성공 후 AuthChecker가 SignInScreen으로 리디렉션합니다.
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logout failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userEmail = ref.watch(supabaseClientProvider).auth.currentUser?.email ?? 'User';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dognal Home'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _signOut(context, ref), // ref를 전달
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              'Welcome back, $userEmail!',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            const Text('수요일: 챗봇 기능 구현을 시작할 준비가 되었습니다.'),
          ],
        ),
      ),
    );
  }
}