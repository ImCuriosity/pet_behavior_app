// lib/data/api/rest_client.dart

import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final restClientProvider = Provider<RestClient>((ref) => RestClient());

class RestClient {
  String get _baseUrl {
    // ✨ [수정] 릴리즈 빌드를 위해 컴파일 타임 변수를 우선적으로 사용하도록 변경합니다.
    // 1. '--dart-define'으로 전달된 'API_BASE_URL'이 있는지 확인합니다.
    const String baseUrlFromEnv = String.fromEnvironment('API_BASE_URL');

    // 2. 만약 있다면 그 값을 사용하고, 없다면 (개발 중이라면) .env 파일에서 읽어옵니다.
    final baseUrl = baseUrlFromEnv.isNotEmpty
        ? baseUrlFromEnv
        : dotenv.env['API_BASE_URL'];

    if (baseUrl == null || baseUrl.isEmpty) {
      throw Exception(
          'FATAL: API_BASE_URL is not set. Please set it in .env file for development, or pass it via --dart-define for release builds.');
    }
    return '$baseUrl/api/v1';
  }

  Future<Map<String, dynamic>> _analyze({
    required String endpoint,
    required String dogId,
    required Uint8List bytes,
    required String fileField,
    required String fileName,
    required MediaType contentType,
    required String accessToken,
  }) async {
    final url = Uri.parse('$_baseUrl/$endpoint');
    var request = http.MultipartRequest('POST', url);

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
        throw Exception(
            'Failed to analyze ($endpoint). Status: ${response.statusCode}. Detail: $detail');
      }
    } catch (e) {
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
      print('Chatbot API call error: $e');
      rethrow;
    }
  }
}
