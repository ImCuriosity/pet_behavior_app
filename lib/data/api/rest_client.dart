// lib/data/api/rest_client.dart

import 'dart:typed_data';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final restClientProvider = Provider<RestClient>((ref) {
  return RestClient();
});

class RestClient {
  static const String _baseUrl = 'https://pet-analysis-backend-254427467650.asia-northeast3.run.app/api/v1';

  Future<Map<String, dynamic>> _analyze({
    required String endpoint,
    required String dogId,
    required Uint8List bytes,
    required String fileField,
    required String fileName,
    required MediaType contentType,
    required String accessToken,
  }) async {
    // ✨ [수정] 잘못된 \ 기호를 제거하여 올바른 URL을 생성합니다.
    final url = Uri.parse('$_baseUrl/$endpoint');
    var request = http.MultipartRequest('POST', url);

    // ✨ [수정] 잘못된 \ 기호를 제거하여 올바른 인증 헤더를 전송합니다.
    request.headers['Authorization'] = 'Bearer $accessToken';

    request.fields['dog_id'] = dogId;
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
        // ✨ [수정] 잘못된 \ 기호를 제거합니다.
        throw Exception('Failed to analyze ($endpoint). Status: ${response.statusCode}. Detail: $detail');
      }
    } catch (e) {
      // ✨ [수정] 잘못된 \ 기호를 제거하여 실제 오류를 출력합니다.
      print('Analysis error ($endpoint): $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> analyzeSound({
    required String dogId,
    required Uint8List audioBytes,
    required String accessToken,
  }) {
    return _analyze(
      endpoint: 'ml/analyze_sound',
      dogId: dogId,
      bytes: audioBytes,
      fileField: 'audio_file',
      fileName: 'audio.wav',
      contentType: MediaType('audio', 'wav'),
      accessToken: accessToken,
    );
  }

  Future<Map<String, dynamic>> analyzeFacialExpression({
    required String dogId,
    required Uint8List imageBytes,
    required String accessToken,
  }) {
    return _analyze(
      endpoint: 'ml/analyze_facial_expression',
      dogId: dogId,
      bytes: imageBytes,
      fileField: 'image_file',
      fileName: 'image.jpg',
      contentType: MediaType('image', 'jpeg'),
      accessToken: accessToken,
    );
  }

  Future<Map<String, dynamic>> analyzeBodyLanguage({
    required String dogId,
    required Uint8List imageBytes,
    required String accessToken,
  }) {
    return _analyze(
      endpoint: 'ml/analyze_body_language',
      dogId: dogId,
      bytes: imageBytes,
      fileField: 'image_file',
      fileName: 'image.jpg',
      contentType: MediaType('image', 'jpeg'),
      accessToken: accessToken,
    );
  }

  Future<Map<String, dynamic>> analyzeEEG({
    required String dogId,
    required Uint8List eegBytes,
    required String accessToken,
  }) {
    return _analyze(
      endpoint: 'ml/analyze_eeg',
      dogId: dogId,
      bytes: eegBytes,
      fileField: 'eeg_file',
      fileName: 'eeg.bin',
      contentType: MediaType('application', 'octet-stream'),
      accessToken: accessToken,
    );
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
          'Content-Type': 'application/json',
          // ✨ [수정] 잘못된 \ 기호를 제거합니다.
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
        // ✨ [수정] 잘못된 \ 기호를 제거합니다.
        throw Exception('Failed to get chatbot response. Status: ${response.statusCode}. Detail: $detail');
      }
    } catch (e) {
      // ✨ [수정] 잘못된 \ 기호를 제거하여 실제 오류를 출력합니다.
      print('Chatbot API call error: $e');
      rethrow;
    }
  }
}
