// lib/data/models/analysis_result.dart

class AnalysisResult {
  final double positiveScore;
  final double activeScore;
  final String? activityDescription;
  final DateTime createdAt;
  final String analysisType;

  AnalysisResult({
    required this.positiveScore,
    required this.activeScore,
    this.activityDescription,
    required this.createdAt,
    required this.analysisType,
  });

  /// 서버에서 받은 JSON(Map) 데이터를 AnalysisResult 객체로 변환합니다.
  factory AnalysisResult.fromJson(Map<String, dynamic> json) {
    // --- [보완] 날짜 문자열이 null일 경우에 대비한 안정성 추가 ---
    // json['created_at']이 null이거나 비어있을 경우, 현재 시간을 기본값으로 사용합니다.
    final createdAtString = json['created_at'] as String?;
    final parsedDate = createdAtString != null && createdAtString.isNotEmpty
        ? DateTime.parse(createdAtString)
        : DateTime.now().toUtc(); // 데이터가 없을 경우를 대비한 안전장치

    return AnalysisResult(
      // num? 타입으로 안전하게 캐스팅하고, null일 경우 0.0을 기본값으로 사용합니다. (매우 좋은 방식입니다!)
      positiveScore: (json['positive_score'] as num?)?.toDouble() ?? 0.0,
      activeScore: (json['active_score'] as num?)?.toDouble() ?? 0.0,
      activityDescription: json['activity_description'],
      createdAt: parsedDate,
      // analysis_type이 null일 경우 'unknown'을 기본값으로 사용합니다. (매우 좋은 방식입니다!)
      analysisType: json['analysis_type'] ?? 'unknown',
    );
  }
}

