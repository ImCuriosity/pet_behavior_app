
// lib/features/dog_stats/screens/dog_stats_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

// 1. 데이터 모델 (analysis_type 추가)
class AnalysisResult {
  final DateTime createdAt;
  final String analysisType;
  final double positiveScore;
  final double activeScore;

  AnalysisResult({
    required this.createdAt,
    required this.analysisType,
    required this.positiveScore,
    required this.activeScore,
  });

  factory AnalysisResult.fromMap(Map<String, dynamic> map) {
    return AnalysisResult(
      createdAt: DateTime.parse(map['created_at']),
      analysisType: map['analysis_type'] ?? 'unknown',
      positiveScore: map['positive_score']?.toDouble() ?? 0.0,
      activeScore: map['active_score']?.toDouble() ?? 0.0,
    );
  }
}

// 2. 데이터 로직 (Provider 수정)
final analysisResultsProvider =
    FutureProvider.autoDispose.family<List<AnalysisResult>, String>((ref, viewType) async {
  final supabase = Supabase.instance.client;
  final userId = supabase.auth.currentUser?.id;

  if (userId == null) throw Exception('User not logged in');

  // viewType에 따라 데이터 조회 기간 변경 (일간: 7일, 주간: 28일)
  final daysToFetch = viewType == 'daily' ? 7 : 28;
  final startDate = DateTime.now().subtract(Duration(days: daysToFetch));

  final response = await supabase
      .from('analysis_results')
      .select('created_at, analysis_type, positive_score, active_score')
      .eq('user_id', userId)
      .gte('created_at', startDate.toIso8601String())
      .order('created_at', ascending: true);

  final data = response as List<dynamic>;
  return data
      .map((item) => AnalysisResult.fromMap(item as Map<String, dynamic>))
      .toList();
});

// 3. UI 구현 (막대 그래프로 변경)
class DogStatsScreen extends ConsumerStatefulWidget {
  const DogStatsScreen({super.key});

  @override
  ConsumerState<DogStatsScreen> createState() => _DogStatsScreenState();
}

class _DogStatsScreenState extends ConsumerState<DogStatsScreen> {
  String _viewType = 'daily'; // 'daily' (일간) vs 'weekly' (주간)

  // 각 분석 타입별 색상 및 한글 이름 정의
  final Map<String, Color> _analysisTypeColors = {
    'eeg': Colors.blue,
    'sound': Colors.green,
    'body_language': Colors.orange,
    'facial_expression': Colors.purple,
  };
  final Map<String, String> _analysisTypeNames = {
    'eeg': '뇌파',
    'sound': '음성',
    'body_language': '몸짓',
    'facial_expression': '표정',
  };

  @override
  Widget build(BuildContext context) {
    final resultsAsyncValue = ref.watch(analysisResultsProvider(_viewType));

    return Scaffold(
      appBar: AppBar(
        title: const Text('감정 분석 리포트'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ToggleButtons(
              isSelected: [_viewType == 'daily', _viewType == 'weekly'],
              onPressed: (index) {
                if (!mounted) return;
                setState(() {
                  _viewType = index == 0 ? 'daily' : 'weekly';
                });
              },
              borderRadius: BorderRadius.circular(8.0),
              children: const [
                Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('일간 추세')),
                Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('주간 평균')),
              ],
            ),
          ),
          Expanded(
            child: resultsAsyncValue.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) =>
                  Center(child: Text('데이터를 불러오는데 실패했습니다: $err')),
              data: (results) {
                if (results.isEmpty) {
                  return const Center(
                      child: Text('표시할 데이터가 없습니다.\n분석을 먼저 시작해주세요!'));
                }
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                  child: BarChart(_buildBarChartData(results)),
                );
              },
            ),
          ),
          _buildLegend(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // 범례 위젯
  Widget _buildLegend() {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: _analysisTypeColors.entries.map((entry) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 16, height: 16, color: entry.value),
            const SizedBox(width: 8),
            Text(_analysisTypeNames[entry.key] ?? entry.key),
          ],
        );
      }).toList(),
    );
  }

  // 막대 그래프 데이터 생성 로직
  BarChartData _buildBarChartData(List<AnalysisResult> results) {
    // 1. 데이터 가공: <그룹 인덱스, <분석 타입, 점수 리스트>>
    final Map<int, Map<String, List<double>>> groupedScores = {};
    final now = DateTime.now();

    for (var result in results) {
      int groupIndex;
      if (_viewType == 'daily') {
        groupIndex = now.difference(result.createdAt).inDays;
      } else {
        groupIndex = (now.difference(result.createdAt).inDays / 7).floor();
      }

      groupedScores.putIfAbsent(groupIndex, () => {});
      groupedScores[groupIndex]!.putIfAbsent(result.analysisType, () => []);
      groupedScores[groupIndex]![result.analysisType]!.add(result.positiveScore);
    }

    // 2. 가공된 데이터로 BarChartGroupData 리스트 생성
    final List<BarChartGroupData> barGroups = [];
    final int maxGroups = _viewType == 'daily' ? 7 : 4;
    const double barWidth = 8;

    for (int i = maxGroups - 1; i >= 0; i--) {
      final scoresForGroup = groupedScores[i] ?? {};

      barGroups.add(BarChartGroupData(
        x: maxGroups - 1 - i,
        barsSpace: 4,
        barRods: _analysisTypeColors.keys.map((type) {
          final scores = scoresForGroup[type] ?? [];
          final averageScore =
              scores.isEmpty ? 0.0 : scores.reduce((a, b) => a + b) / scores.length;
          return BarChartRodData(
            toY: averageScore,
            color: _analysisTypeColors[type],
            width: barWidth,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(4),
            ),
          );
        }).toList(),
      ));
    }

    return BarChartData(
      barGroups: barGroups,
      alignment: BarChartAlignment.spaceAround,
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: 0.2,
      ),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 40,
            getTitlesWidget: (value, meta) =>
                Text(value.toStringAsFixed(1), style: const TextStyle(fontSize: 10)),
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 40,
            getTitlesWidget: (value, meta) {
              String text;
              final index = value.toInt();
              if (_viewType == 'daily') {
                final day = now.subtract(Duration(days: maxGroups - 1 - index));
                text = DateFormat('E', 'ko_KR').format(day);
              } else {
                text = '${maxGroups - index}주 전';
              }
              return SideTitleWidget(
                  axisSide: meta.axisSide,
                  child: Text(text, style: const TextStyle(fontSize: 10)));
            },
          ),
        ),
      ),
// ... (중략)
      barTouchData: BarTouchData(
        touchTooltipData: BarTouchTooltipData(
          getTooltipColor: (_) => Colors.blueGrey,
          getTooltipItem: (group, groupIndex, rod, rodIndex) {
            final type = _analysisTypeColors.keys.elementAt(rodIndex);
            return BarTooltipItem(
              '${_analysisTypeNames[type] ?? type}\n',
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              children: <TextSpan>[
                TextSpan(
                  text: rod.toY.toStringAsFixed(2),
                  style: TextStyle(
                    color: rod.color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            );
          },
        ), // <-- 깔끔하게 수정됨
      ),
    );
  }
}
