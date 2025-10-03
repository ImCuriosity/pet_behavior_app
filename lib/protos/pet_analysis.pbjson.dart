// This is a generated file - do not edit.
//
// Generated from pet_analysis.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use analyzeSoundRequestDescriptor instead')
const AnalyzeSoundRequest$json = {
  '1': 'AnalyzeSoundRequest',
  '2': [
    {'1': 'audio_data', '3': 1, '4': 1, '5': 12, '10': 'audioData'},
    {'1': 'dog_id', '3': 2, '4': 1, '5': 9, '10': 'dogId'},
  ],
};

/// Descriptor for `AnalyzeSoundRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List analyzeSoundRequestDescriptor = $convert.base64Decode(
    'ChNBbmFseXplU291bmRSZXF1ZXN0Eh0KCmF1ZGlvX2RhdGEYASABKAxSCWF1ZGlvRGF0YRIVCg'
    'Zkb2dfaWQYAiABKAlSBWRvZ0lk');

@$core.Deprecated('Use analyzeExpressionRequestDescriptor instead')
const AnalyzeExpressionRequest$json = {
  '1': 'AnalyzeExpressionRequest',
  '2': [
    {'1': 'image_frame_data', '3': 1, '4': 1, '5': 12, '10': 'imageFrameData'},
    {'1': 'dog_id', '3': 2, '4': 1, '5': 9, '10': 'dogId'},
  ],
};

/// Descriptor for `AnalyzeExpressionRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List analyzeExpressionRequestDescriptor =
    $convert.base64Decode(
        'ChhBbmFseXplRXhwcmVzc2lvblJlcXVlc3QSKAoQaW1hZ2VfZnJhbWVfZGF0YRgBIAEoDFIOaW'
        '1hZ2VGcmFtZURhdGESFQoGZG9nX2lkGAIgASgJUgVkb2dJZA==');

@$core.Deprecated('Use analysisResultDescriptor instead')
const AnalysisResult$json = {
  '1': 'AnalysisResult',
  '2': [
    {'1': 'positive_score', '3': 1, '4': 1, '5': 2, '10': 'positiveScore'},
    {'1': 'active_score', '3': 2, '4': 1, '5': 2, '10': 'activeScore'},
    {'1': 'log_timestamp', '3': 3, '4': 1, '5': 9, '10': 'logTimestamp'},
  ],
};

/// Descriptor for `AnalysisResult`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List analysisResultDescriptor = $convert.base64Decode(
    'Cg5BbmFseXNpc1Jlc3VsdBIlCg5wb3NpdGl2ZV9zY29yZRgBIAEoAlINcG9zaXRpdmVTY29yZR'
    'IhCgxhY3RpdmVfc2NvcmUYAiABKAJSC2FjdGl2ZVNjb3JlEiMKDWxvZ190aW1lc3RhbXAYAyAB'
    'KAlSDGxvZ1RpbWVzdGFtcA==');

const $core.Map<$core.String, $core.dynamic> PetAnalysisServiceBase$json = {
  '1': 'PetAnalysisService',
  '2': [
    {
      '1': 'AnalyzeSound',
      '2': '.petanalysis.AnalyzeSoundRequest',
      '3': '.petanalysis.AnalysisResult'
    },
    {
      '1': 'AnalyzeExpression',
      '2': '.petanalysis.AnalyzeExpressionRequest',
      '3': '.petanalysis.AnalysisResult',
      '5': true
    },
  ],
};

@$core.Deprecated('Use petAnalysisServiceDescriptor instead')
const $core.Map<$core.String, $core.Map<$core.String, $core.dynamic>>
    PetAnalysisServiceBase$messageJson = {
  '.petanalysis.AnalyzeSoundRequest': AnalyzeSoundRequest$json,
  '.petanalysis.AnalysisResult': AnalysisResult$json,
  '.petanalysis.AnalyzeExpressionRequest': AnalyzeExpressionRequest$json,
};

/// Descriptor for `PetAnalysisService`. Decode as a `google.protobuf.ServiceDescriptorProto`.
final $typed_data.Uint8List petAnalysisServiceDescriptor = $convert.base64Decode(
    'ChJQZXRBbmFseXNpc1NlcnZpY2USTQoMQW5hbHl6ZVNvdW5kEiAucGV0YW5hbHlzaXMuQW5hbH'
    'l6ZVNvdW5kUmVxdWVzdBobLnBldGFuYWx5c2lzLkFuYWx5c2lzUmVzdWx0ElkKEUFuYWx5emVF'
    'eHByZXNzaW9uEiUucGV0YW5hbHlzaXMuQW5hbHl6ZUV4cHJlc3Npb25SZXF1ZXN0GhsucGV0YW'
    '5hbHlzaXMuQW5hbHlzaXNSZXN1bHQoAQ==');
