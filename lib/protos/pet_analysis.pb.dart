// This is a generated file - do not edit.
//
// Generated from pet_analysis.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names

import 'dart:async' as $async;
import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

/// 1. 소리 분석 요청 (대용량 이진 데이터 전송 예시)
class AnalyzeSoundRequest extends $pb.GeneratedMessage {
  factory AnalyzeSoundRequest({
    $core.List<$core.int>? audioData,
    $core.String? dogId,
  }) {
    final result = create();
    if (audioData != null) result.audioData = audioData;
    if (dogId != null) result.dogId = dogId;
    return result;
  }

  AnalyzeSoundRequest._();

  factory AnalyzeSoundRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AnalyzeSoundRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AnalyzeSoundRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'petanalysis'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'audioData', $pb.PbFieldType.OY)
    ..aOS(2, _omitFieldNames ? '' : 'dogId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AnalyzeSoundRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AnalyzeSoundRequest copyWith(void Function(AnalyzeSoundRequest) updates) =>
      super.copyWith((message) => updates(message as AnalyzeSoundRequest))
          as AnalyzeSoundRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AnalyzeSoundRequest create() => AnalyzeSoundRequest._();
  @$core.override
  AnalyzeSoundRequest createEmptyInstance() => create();
  static $pb.PbList<AnalyzeSoundRequest> createRepeated() =>
      $pb.PbList<AnalyzeSoundRequest>();
  @$core.pragma('dart2js:noInline')
  static AnalyzeSoundRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AnalyzeSoundRequest>(create);
  static AnalyzeSoundRequest? _defaultInstance;

  /// 원시 오디오 바이트 데이터. gRPC는 이를 효율적으로 스트리밍합니다. [cite: 7, 27]
  @$pb.TagNumber(1)
  $core.List<$core.int> get audioData => $_getN(0);
  @$pb.TagNumber(1)
  set audioData($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAudioData() => $_has(0);
  @$pb.TagNumber(1)
  void clearAudioData() => $_clearField(1);

  /// 어떤 강아지에 대한 분석인지 식별자 포함
  @$pb.TagNumber(2)
  $core.String get dogId => $_getSZ(1);
  @$pb.TagNumber(2)
  set dogId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDogId() => $_has(1);
  @$pb.TagNumber(2)
  void clearDogId() => $_clearField(2);
}

/// 2. 표정 분석 요청 (이미지 프레임 스트리밍 예시)
/// 실시간 표정 분석을 위해 스트리밍 방식을 가정하고 이미지 프레임을 전송합니다. [cite: 27]
class AnalyzeExpressionRequest extends $pb.GeneratedMessage {
  factory AnalyzeExpressionRequest({
    $core.List<$core.int>? imageFrameData,
    $core.String? dogId,
  }) {
    final result = create();
    if (imageFrameData != null) result.imageFrameData = imageFrameData;
    if (dogId != null) result.dogId = dogId;
    return result;
  }

  AnalyzeExpressionRequest._();

  factory AnalyzeExpressionRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AnalyzeExpressionRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AnalyzeExpressionRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'petanalysis'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'imageFrameData', $pb.PbFieldType.OY)
    ..aOS(2, _omitFieldNames ? '' : 'dogId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AnalyzeExpressionRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AnalyzeExpressionRequest copyWith(
          void Function(AnalyzeExpressionRequest) updates) =>
      super.copyWith((message) => updates(message as AnalyzeExpressionRequest))
          as AnalyzeExpressionRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AnalyzeExpressionRequest create() => AnalyzeExpressionRequest._();
  @$core.override
  AnalyzeExpressionRequest createEmptyInstance() => create();
  static $pb.PbList<AnalyzeExpressionRequest> createRepeated() =>
      $pb.PbList<AnalyzeExpressionRequest>();
  @$core.pragma('dart2js:noInline')
  static AnalyzeExpressionRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AnalyzeExpressionRequest>(create);
  static AnalyzeExpressionRequest? _defaultInstance;

  /// 원시 이미지 프레임 바이트 데이터
  @$pb.TagNumber(1)
  $core.List<$core.int> get imageFrameData => $_getN(0);
  @$pb.TagNumber(1)
  set imageFrameData($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasImageFrameData() => $_has(0);
  @$pb.TagNumber(1)
  void clearImageFrameData() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get dogId => $_getSZ(1);
  @$pb.TagNumber(2)
  set dogId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDogId() => $_has(1);
  @$pb.TagNumber(2)
  void clearDogId() => $_clearField(2);
}

class AnalysisResult extends $pb.GeneratedMessage {
  factory AnalysisResult({
    $core.double? positiveScore,
    $core.double? activeScore,
    $core.String? logTimestamp,
  }) {
    final result = create();
    if (positiveScore != null) result.positiveScore = positiveScore;
    if (activeScore != null) result.activeScore = activeScore;
    if (logTimestamp != null) result.logTimestamp = logTimestamp;
    return result;
  }

  AnalysisResult._();

  factory AnalysisResult.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AnalysisResult.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AnalysisResult',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'petanalysis'),
      createEmptyInstance: create)
    ..aD(1, _omitFieldNames ? '' : 'positiveScore',
        fieldType: $pb.PbFieldType.OF)
    ..aD(2, _omitFieldNames ? '' : 'activeScore', fieldType: $pb.PbFieldType.OF)
    ..aOS(3, _omitFieldNames ? '' : 'logTimestamp')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AnalysisResult clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AnalysisResult copyWith(void Function(AnalysisResult) updates) =>
      super.copyWith((message) => updates(message as AnalysisResult))
          as AnalysisResult;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AnalysisResult create() => AnalysisResult._();
  @$core.override
  AnalysisResult createEmptyInstance() => create();
  static $pb.PbList<AnalysisResult> createRepeated() =>
      $pb.PbList<AnalysisResult>();
  @$core.pragma('dart2js:noInline')
  static AnalysisResult getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AnalysisResult>(create);
  static AnalysisResult? _defaultInstance;

  /// 강아지 상태: Positive/Negative 특징 점수 (float, ML 모델 산출값) [cite: 5, 33]
  @$pb.TagNumber(1)
  $core.double get positiveScore => $_getN(0);
  @$pb.TagNumber(1)
  set positiveScore($core.double value) => $_setFloat(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPositiveScore() => $_has(0);
  @$pb.TagNumber(1)
  void clearPositiveScore() => $_clearField(1);

  /// 강아지 상태: Active/Passive 특징 점수 (float, ML 모델 산출값) [cite: 5, 33]
  @$pb.TagNumber(2)
  $core.double get activeScore => $_getN(1);
  @$pb.TagNumber(2)
  set activeScore($core.double value) => $_setFloat(1, value);
  @$pb.TagNumber(2)
  $core.bool hasActiveScore() => $_has(1);
  @$pb.TagNumber(2)
  void clearActiveScore() => $_clearField(2);

  /// 로그 기록을 위한 타임스탬프
  @$pb.TagNumber(3)
  $core.String get logTimestamp => $_getSZ(2);
  @$pb.TagNumber(3)
  set logTimestamp($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasLogTimestamp() => $_has(2);
  @$pb.TagNumber(3)
  void clearLogTimestamp() => $_clearField(3);
}

class PetAnalysisServiceApi {
  final $pb.RpcClient _client;

  PetAnalysisServiceApi(this._client);

  /// 1. 소리 분석 (Unary Call): 요청을 보내고 단일 응답을 받습니다.
  $async.Future<AnalysisResult> analyzeSound(
          $pb.ClientContext? ctx, AnalyzeSoundRequest request) =>
      _client.invoke<AnalysisResult>(
          ctx, 'PetAnalysisService', 'AnalyzeSound', request, AnalysisResult());

  /// 2. 표정 분석 (Client Streaming 또는 Bidirectional Streaming 가정):
  /// 실시간으로 여러 이미지 프레임을 전송하고, 최종 분석 결과를 받거나 (Client Streaming),
  /// 실시간 피드백을 받을 수 있도록 (Bidirectional Streaming) 정의할 수 있습니다. [cite: 27]
  $async.Future<AnalysisResult> analyzeExpression(
          $pb.ClientContext? ctx, AnalyzeExpressionRequest request) =>
      _client.invoke<AnalysisResult>(ctx, 'PetAnalysisService',
          'AnalyzeExpression', request, AnalysisResult());
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
