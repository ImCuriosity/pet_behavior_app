// lib/core/providers/dog_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dognal1/data/models/dog_profile.dart';

/// dogId를 파라미터로 받아 해당 강아지의 전체 프로필 정보를 가져오는 Provider
final dogProfileProvider =
FutureProvider.autoDispose.family<DogProfile, String>((ref, dogId) async {
  final response = await Supabase.instance.client
      .from('dogs')
      .select()
      .eq('id', dogId)
      .single();

  return DogProfile.fromMap(response);
});
