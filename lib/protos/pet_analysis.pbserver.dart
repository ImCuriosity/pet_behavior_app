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

import 'pet_analysis.pb.dart' as $0;
import 'pet_analysis.pbjson.dart';

export 'pet_analysis.pb.dart';

abstract class PetAnalysisServiceBase extends $pb.GeneratedService {
  $async.Future<$0.AnalysisResult> analyzeSound(
      $pb.ServerContext ctx, $0.AnalyzeSoundRequest request);
  $async.Future<$0.AnalysisResult> analyzeExpression(
      $pb.ServerContext ctx, $0.AnalyzeExpressionRequest request);

  $pb.GeneratedMessage createRequest($core.String methodName) {
    switch (methodName) {
      case 'AnalyzeSound':
        return $0.AnalyzeSoundRequest();
      case 'AnalyzeExpression':
        return $0.AnalyzeExpressionRequest();
      default:
        throw $core.ArgumentError('Unknown method: $methodName');
    }
  }

  $async.Future<$pb.GeneratedMessage> handleCall($pb.ServerContext ctx,
      $core.String methodName, $pb.GeneratedMessage request) {
    switch (methodName) {
      case 'AnalyzeSound':
        return analyzeSound(ctx, request as $0.AnalyzeSoundRequest);
      case 'AnalyzeExpression':
        return analyzeExpression(ctx, request as $0.AnalyzeExpressionRequest);
      default:
        throw $core.ArgumentError('Unknown method: $methodName');
    }
  }

  $core.Map<$core.String, $core.dynamic> get $json =>
      PetAnalysisServiceBase$json;
  $core.Map<$core.String, $core.Map<$core.String, $core.dynamic>>
      get $messageJson => PetAnalysisServiceBase$messageJson;
}
