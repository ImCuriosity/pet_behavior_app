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
      // This is a generic catch block, rethrowing is appropriate here.
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
  }) async {
    final url = Uri.parse('$_baseUrl/diary/$dogId?diaryDate=$diaryDate');
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
}
