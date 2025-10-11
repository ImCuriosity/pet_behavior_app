import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final restClientProvider = Provider<RestClient>((ref) => RestClient());

// ✨ [추가] 산책 기록 데이터를 담을 모델 클래스
class WalkRecord {
  final String id;
  final String userId;
  final String dogId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int? durationSeconds;
  final double? distanceMeters;
  final String? weatherInfo;
  final List<Map<String, double>>? pathPoints; // e.g., [{'lat': 37.5, 'lng': 127.0}]
  final Map<String, dynamic>? finalEmotionAnalysis;
  final DateTime createdAt;

  WalkRecord({
    required this.id,
    required this.userId,
    required this.dogId,
    required this.startedAt,
    this.endedAt,
    this.durationSeconds,
    this.distanceMeters,
    this.weatherInfo,
    this.pathPoints,
    this.finalEmotionAnalysis,
    required this.createdAt,
  });

  factory WalkRecord.fromMap(Map<String, dynamic> map) {
    return WalkRecord(
      id: map['id'],
      userId: map['user_id'],
      dogId: map['dog_id'],
      startedAt: DateTime.parse(map['started_at']),
      endedAt: map['ended_at'] != null ? DateTime.parse(map['ended_at']) : null,
      durationSeconds: map['duration_seconds'],
      distanceMeters: (map['distance_meters'] as num?)?.toDouble(),
      weatherInfo: map['weather_info'],
      pathPoints: (map['path_points'] as List?)
          ?.map((p) => (p as Map).map((key, value) => MapEntry(key.toString(), (value as num).toDouble())))
          .toList(),
      finalEmotionAnalysis: map['final_emotion_analysis'] != null
          ? Map<String, dynamic>.from(map['final_emotion_analysis'])
          : null,
      createdAt: DateTime.parse(map['created_at']),
    );
  }
}

class RestClient {
  String get _baseUrl {
    const String baseUrlFromEnv = String.fromEnvironment('API_BASE_URL');
    final baseUrl = baseUrlFromEnv.isNotEmpty
        ? baseUrlFromEnv
        : dotenv.env['API_BASE_URL'];

    if (baseUrl == null || baseUrl.isEmpty) {
      throw Exception(
          'FATAL: API_BASE_URL is not set. Please set it in .env file for development, or pass it via --dart-define for release builds.');
    }
    return '$baseUrl/api/v1';
  }

  // Supabase 클라이언트 인스턴스에 더 쉽게 접근하기 위해 getter를 추가합니다.
  SupabaseClient get _supabase => Supabase.instance.client;

  Future<Map<String, dynamic>> _analyze({
    required String endpoint,
    required String dogId,
    required Uint8List bytes,
    required String fileField,
    required String fileName,
    required MediaType contentType,
    required String accessToken,
    String? activityDescription,
  }) async {
    final url = Uri.parse('$_baseUrl/$endpoint');
    var request = http.MultipartRequest('POST', url);

    request.headers['Authorization'] = 'Bearer $accessToken';

    request.fields['dog_id'] = dogId;
    if (activityDescription != null && activityDescription.isNotEmpty) {
      request.fields['activity_description'] = activityDescription;
    }

    request.files.add(http.MultipartFile.fromBytes(
      fileField,
      bytes,
      filename: fileName,
      contentType: contentType,
    ));

    try {
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        return jsonDecode(responseBody);
      } else {
        String detail = responseBody;
        try {
          final errorJson = jsonDecode(responseBody);
          detail = errorJson['detail'] ?? responseBody;
        } catch (_) {}
        throw Exception(
            'Failed to analyze ($endpoint). Status: ${response.statusCode}. Detail: $detail');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> analyzeSound({
    required String dogId,
    required Uint8List audioBytes,
    required String accessToken,
    String? activityDescription,
  }) {
    return _analyze(
      endpoint: 'ml/analyze_sound',
      dogId: dogId,
      bytes: audioBytes,
      fileField: 'audio_file',
      fileName: 'audio.wav',
      contentType: MediaType('audio', 'wav'),
      accessToken: accessToken,
      activityDescription: activityDescription,
    );
  }

  Future<Map<String, dynamic>> analyzeFacialExpression({
    required String dogId,
    required Uint8List imageBytes,
    required String accessToken,
    String? activityDescription,
  }) {
    return _analyze(
      endpoint: 'ml/analyze_facial_expression',
      dogId: dogId,
      bytes: imageBytes,
      fileField: 'image_file',
      fileName: 'image.jpg',
      contentType: MediaType('image', 'jpeg'),
      accessToken: accessToken,
      activityDescription: activityDescription,
    );
  }

  Future<Map<String, dynamic>> analyzeBodyLanguage({
    required String dogId,
    required Uint8List imageBytes,
    required String accessToken,
    String? activityDescription,
  }) {
    return _analyze(
      endpoint: 'ml/analyze_body_language',
      dogId: dogId,
      bytes: imageBytes,
      fileField: 'image_file',
      fileName: 'image.jpg',
      contentType: MediaType('image', 'jpeg'),
      accessToken: accessToken,
      activityDescription: activityDescription,
    );
  }

  Future<Map<String, dynamic>> analyzeEEG({
    required String dogId,
    required Uint8List eegBytes,
    required String accessToken,
    String? activityDescription,
  }) {
    return _analyze(
      endpoint: 'ml/analyze_eeg',
      dogId: dogId,
      bytes: eegBytes,
      fileField: 'eeg_file',
      fileName: 'eeg.bin',
      contentType: MediaType('application', 'octet-stream'),
      accessToken: accessToken,
      activityDescription: activityDescription,
    );
  }

  Future<Map<String, dynamic>> getDiaryEntry({
    required String dogId,
    required String diaryDate, // "YYYY-MM-DD" format
    required String accessToken,
    bool regenerate = false,
  }) async {
    final url = Uri.parse('$_baseUrl/diary/$dogId?diaryDate=$diaryDate&regenerate=$regenerate');
    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $accessToken',
        },
      );
      final responseBody = utf8.decode(response.bodyBytes);
      if (response.statusCode == 200) {
        return jsonDecode(responseBody);
      } else {
        String detail = 'No details from server.';
        try {
          final errorJson = jsonDecode(responseBody);
          detail = errorJson['detail'] ?? responseBody;
        } catch (_) {
          detail = responseBody;
        }
        throw Exception(
            'Failed to get diary entry. Status: ${response.statusCode}. Detail: $detail');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<String> getChatbotResponse({
    required String dogId,
    required String userQuery,
    required String accessToken,
  }) async {
    final url = Uri.parse('$_baseUrl/chatbot/query');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({'dog_id': dogId, 'query': userQuery}),
      );
      final responseBody = utf8.decode(response.bodyBytes);
      if (response.statusCode == 200) {
        final result = jsonDecode(responseBody);
        return result['response'];
      } else {
        String detail = 'No details from server.';
        try {
          final errorJson = jsonDecode(responseBody);
          detail = errorJson['detail'] ?? responseBody;
        } catch (_) {
          detail = responseBody;
        }
        throw Exception(
            'Failed to get chatbot response. Status: ${response.statusCode}. Detail: $detail');
      }
    } catch (e) {
      rethrow;
    }
  }

  // ✨ [추가] 산책 기록을 Supabase에 저장하는 함수
  Future<void> saveWalkRecord({
    required String dogId,
    required DateTime startedAt,
    required DateTime endedAt,
    required int durationSeconds,
    required double distanceMeters,
    required String weatherInfo,
    required List<Map<String, double>> pathPoints,
    required Map<String, dynamic> finalEmotionAnalysis,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    try {
      await _supabase.from('walk_records').insert({
        'user_id': user.id,
        'dog_id': dogId,
        'started_at': startedAt.toIso8601String(),
        'ended_at': endedAt.toIso8601String(),
        'duration_seconds': durationSeconds,
        'distance_meters': distanceMeters,
        'weather_info': weatherInfo,
        'path_points': pathPoints,
        'final_emotion_analysis': finalEmotionAnalysis,
      });
    } catch (e) {
      // PostgREST 에러를 더 자세히 출력
      if (e is PostgrestException) {
        throw Exception('Failed to save walk record: ${e.message} (Code: ${e.code})');
      }
      rethrow;
    }
  }

  // ✨ [추가] 특정 강아지의 산책 기록 목록을 가져오는 함수
  Future<List<WalkRecord>> getWalkHistory(String dogId) async {
    try {
      final response = await _supabase
          .from('walk_records')
          .select()
          .eq('dog_id', dogId)
          .order('started_at', ascending: false) // 최신순으로 정렬
          .limit(20); // 최근 20개만 가져오기

      return response.map((item) => WalkRecord.fromMap(item)).toList();
    } catch (e) {
      if (e is PostgrestException) {
        throw Exception('Failed to get walk history: ${e.message}');
      }
      rethrow;
    }
  }
}
