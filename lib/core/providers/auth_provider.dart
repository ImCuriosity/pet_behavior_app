// lib/core/providers/auth_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Supabase 클라이언트 인스턴스를 제공하는 Provider
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

// Supabase 인증 상태 변화를 스트리밍하는 Provider
final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return supabase.auth.onAuthStateChange;
});

// ✅ 1. 현재 로그인된 User 객체를 실시간으로 제공하는 Provider 추가
final userProvider = Provider<User?>((ref) {
  final authState = ref.watch(authStateChangesProvider);
  return authState.value?.session?.user;
});

// ✅ 2. dogIdProvider가 userProvider를 감시하여 자동으로 데이터를 갱신하도록 수정
final dogIdProvider = FutureProvider<String?>((ref) async {
  final user = ref.watch(userProvider); // 사용자가 바뀌면 이 Provider는 자동으로 재실행됩니다.
  final supabase = ref.watch(supabaseClientProvider);

  if (user == null) {
    return null; // 로그아웃 상태면 null 반환
  }

  // 로그인된 사용자의 ID로 강아지 데이터 조회
  final data = await supabase
      .from('dogs')
      .select('id')
      .eq('user_id', user.id)
      .maybeSingle();

  if (data != null && data['id'] != null) {
    return data['id'] as String;
  }
  return null;
});