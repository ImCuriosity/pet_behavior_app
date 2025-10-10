import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class AnalysisResult {
  final DateTime createdAt;
  final String analysisType;
  final double positiveScore;
  final double activeScore;
  final String? activityDescription;

  AnalysisResult({
    required this.createdAt,
    required this.analysisType,
    required this.positiveScore,
    required this.activeScore,
    this.activityDescription,
  });

  factory AnalysisResult.fromMap(Map<String, dynamic> map) {
    return AnalysisResult(
      createdAt: DateTime.parse(map['created_at']),
      analysisType: map['analysis_type'] ?? 'unknown',
      positiveScore: map['positive_score']?.toDouble() ?? 0.0,
      activeScore: map['active_score']?.toDouble() ?? 0.0,
      activityDescription: map['activity_description'],
    );
  }
}

final analysisResultsProvider =
    FutureProvider.autoDispose.family<List<AnalysisResult>, String>((ref, viewType) async {
  final supabase = Supabase.instance.client;
  final userId = supabase.auth.currentUser?.id;

  if (userId == null) throw Exception('User not logged in');

  final now = DateTime.now();
  DateTime startDate;
  if (viewType == 'daily') {
    startDate = DateTime(now.year, now.month, now.day); // Today 00:00
  } else { // weekly
    startDate = now.subtract(Duration(days: now.weekday - 1)); // This week's Monday
    startDate = DateTime(startDate.year, startDate.month, startDate.day);
  }

  final response = await supabase
      .from('analysis_results')
      .select('created_at, analysis_type, positive_score, active_score, activity_description')
      .eq('user_id', userId)
      .gte('created_at', startDate.toIso8601String())
      .order('created_at', ascending: true);

  final data = response as List<dynamic>;
  return data.map((item) => AnalysisResult.fromMap(item as Map<String, dynamic>)).toList();
});

class DogStatsScreen extends ConsumerStatefulWidget {
  const DogStatsScreen({super.key});

  @override
  ConsumerState<DogStatsScreen> createState() => _DogStatsScreenState();
}

class _DogStatsScreenState extends ConsumerState<DogStatsScreen> {
  String _viewType = 'daily'; // 'daily' vs 'weekly'

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

  Map<int, Map<String, List<AnalysisResult>>> _groupedData = {};

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
                Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('오늘')),
                Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('주간')),
              ],
            ),
          ),
          Expanded(
            child: resultsAsyncValue.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('데이터를 불러오는데 실패했습니다: $err')),
              data: (results) {
                if (results.isEmpty) {
                  return const Center(child: Text('표시할 데이터가 없습니다.\n분석을 먼저 시작해주세요!'));
                }
                _groupData(results);
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                  child: BarChart(_buildBarChartData()),
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

  void _groupData(List<AnalysisResult> results) {
    _groupedData = {};

    for (var result in results) {
      int groupIndex;
      if (_viewType == 'daily') {
        groupIndex = result.createdAt.hour;
      } else { // weekly
        groupIndex = result.createdAt.weekday; // 1: Monday, 7: Sunday
      }

      _groupedData.putIfAbsent(groupIndex, () => {});
      _groupedData[groupIndex]!.putIfAbsent(result.analysisType, () => []);
      _groupedData[groupIndex]![result.analysisType]!.add(result);
    }
  }

  BarChartData _buildBarChartData() {
    final List<BarChartGroupData> barGroups = [];
    const double barWidth = 8;

    if (_viewType == 'daily') {
      for (int i = 0; i < 24; i++) { // 0h to 23h
        final scoresForGroup = _groupedData[i] ?? {};
        barGroups.add(BarChartGroupData(
          x: i,
          barsSpace: 4,
          barRods: _analysisTypeColors.keys.map((type) {
            final scores = scoresForGroup[type]?.map((r) => r.positiveScore).toList() ?? [];
            final averageScore = scores.isEmpty ? 0.0 : scores.reduce((a, b) => a + b) / scores.length;
            return BarChartRodData(
                toY: averageScore, color: _analysisTypeColors[type], width: barWidth);
          }).toList(),
        ));
      }
    } else { // weekly
      for (int i = 1; i <= 7; i++) { // Monday(1) to Sunday(7)
        final scoresForGroup = _groupedData[i] ?? {};
        barGroups.add(BarChartGroupData(
          x: i - 1,
          barsSpace: 4,
          barRods: _analysisTypeColors.keys.map((type) {
            final scores = scoresForGroup[type]?.map((r) => r.positiveScore).toList() ?? [];
            final averageScore = scores.isEmpty ? 0.0 : scores.reduce((a, b) => a + b) / scores.length;
            return BarChartRodData(
                toY: averageScore, color: _analysisTypeColors[type], width: barWidth);
          }).toList(),
        ));
      }
    }

    return BarChartData(
      barGroups: barGroups,
      alignment: BarChartAlignment.spaceAround,
      gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 0.2),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
                text = '$index시';
              } else {
                final weekdays = ['월', '화', '수', '목', '금', '토', '일'];
                text = weekdays[index];
              }
              return SideTitleWidget(
                  axisSide: meta.axisSide, child: Text(text, style: const TextStyle(fontSize: 10)));
            },
          ),
        ),
      ),
      barTouchData: BarTouchData(
        touchTooltipData: BarTouchTooltipData(
          getTooltipColor: (_) => Colors.blueGrey,
          getTooltipItem: (group, groupIndex, rod, rodIndex) {
            final type = _analysisTypeColors.keys.elementAt(rodIndex);
            final groupKey = _viewType == 'daily' ? group.x : (group.x + 1);
            final resultsForBar = _groupedData[groupKey]?[type] ?? [];
            final description = resultsForBar
                .firstWhere((r) => r.activityDescription != null && r.activityDescription!.isNotEmpty,
                    orElse: () => AnalysisResult(createdAt: DateTime.now(), analysisType: '', positiveScore: 0, activeScore: 0))
                .activityDescription;

            final title = '${_analysisTypeNames[type] ?? type}\n';
            final scoreText = rod.toY.toStringAsFixed(2);
            final descriptionText = description != null ? '\n$description' : '';

            return BarTooltipItem(
              title,
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              children: <TextSpan>[
                TextSpan(
                  text: scoreText,
                  style: TextStyle(color: rod.color, fontWeight: FontWeight.w500),
                ),
                TextSpan(
                  text: descriptionText,
                  style: const TextStyle(color: Colors.white, fontStyle: FontStyle.italic, fontSize: 12),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
