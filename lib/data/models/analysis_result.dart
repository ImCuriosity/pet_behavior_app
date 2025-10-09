// lib/data/models/analysis_result.dart (새로 정의해야 하는 파일)

class AnalysisResult {
  final double positiveScore;
  final double activeScore;
  // ... 기타 ML 모델 출력 값

  AnalysisResult({
    required this.positiveScore,
    required this.activeScore,
  });

  factory AnalysisResult.fromJson(Map<String, dynamic> json) {
    return AnalysisResult(
      positiveScore: (json['positive_score'] as num).toDouble(),
      activeScore: (json['active_score'] as num).toDouble(),
    );
  }
}