// lib/core/providers/analysis_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dognal1/data/models/analysis_result.dart'; // 1단계에서 만든 모델 import

// 이 Provider는 dogId와 viewType을 받아 List<AnalysisResult>를 반환합니다.
final analysisResultsProvider = FutureProvider.autoDispose
    .family<List<AnalysisResult>, ({String dogId, String viewType})>(
        (ref, params) async {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) {
        throw Exception('User not logged in');
      }

      // Supabase RPC 함수 'get_rag_data' 호출
      final response = await supabase.rpc('get_rag_data', params: {
        'p_user_uuid': user.id,
        'p_dog_id_text': params.dogId,
        'p_view_type': params.viewType,
      });

      if (response is List) {
        // 성공 시, JSON List를 List<AnalysisResult>로 변환하여 반환
        return response
            .map((item) => AnalysisResult.fromJson(item as Map<String, dynamic>))
            .toList();
      }

      // 데이터가 없거나 예상치 못한 타입일 경우 빈 리스트 반환
      return [];
    });
