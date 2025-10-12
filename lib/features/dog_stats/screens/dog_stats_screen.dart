import 'package:dognal1/data/api/rest_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';

const String mockDogId = 'test_dog_id_001'; // 임시 mock id

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
    final dtString = map['created_at'] as String? ?? '';
    DateTime parsedDate;
    try {
      var tempString = dtString.replaceFirst(' ', 'T');
      if (tempString.endsWith('Z')) {
        tempString = tempString.substring(0, tempString.length - 1) + '+00:00';
      } else if (tempString.endsWith('+00')) {
        tempString += ':00';
      }
      parsedDate = DateTime.parse(tempString);
    } catch (e) {
      parsedDate = DateTime.now();
    }

    return AnalysisResult(
      createdAt: parsedDate,
      analysisType: map['analysis_type'] ?? 'unknown',
      positiveScore: (map['positive_score'] as num?)?.toDouble() ?? 0.0,
      activeScore: (map['active_score'] as num?)?.toDouble() ?? 0.0,
      activityDescription: map['activity_description'],
    );
  }
}

// ✨ [수정] walk_records와 analysis_results를 통합하여 조회하는 Provider
final analysisResultsProvider = FutureProvider.autoDispose
    .family<List<AnalysisResult>, ({String dogId, String viewType})>(
        (ref, params) async {
  final supabase = Supabase.instance.client;
  final userId = supabase.auth.currentUser?.id;

  if (userId == null) throw Exception('User not logged in');

  final now = DateTime.now();
  final kstOffset = const Duration(hours: 9);
  final nowInKst = now.toUtc().add(kstOffset);

  DateTime queryStartUtc;
  DateTime queryEndUtc;

  if (params.viewType == 'daily') {
    final todayKstDate = DateTime.utc(nowInKst.year, nowInKst.month, nowInKst.day);
    queryStartUtc = todayKstDate.subtract(kstOffset);
    queryEndUtc = queryStartUtc.add(const Duration(days: 1));
  } else { // weekly
    final daysToSubtract = nowInKst.weekday - 1; // Monday is 1, Sunday is 7
    final startOfWeekKstDate = DateTime.utc(nowInKst.year, nowInKst.month, nowInKst.day - daysToSubtract);
    queryStartUtc = startOfWeekKstDate.subtract(kstOffset);
    queryEndUtc = queryStartUtc.add(const Duration(days: 7));
  }

  // 1. ML 분석 결과 조회
  final mlResultsFuture = supabase
      .from('analysis_results')
      .select('created_at, analysis_type, positive_score, active_score, activity_description')
      .eq('user_id', userId)
      .eq('dog_id', params.dogId)
      .gte('created_at', queryStartUtc.toIso8601String())
      .lt('created_at', queryEndUtc.toIso8601String());

  // 2. 산책 기록 조회
  final walkRecordsFuture = supabase
      .from('walk_records')
      .select()
      .eq('user_id', userId)
      .eq('dog_id', params.dogId)
      .gte('ended_at', queryStartUtc.toIso8601String())
      .lt('ended_at', queryEndUtc.toIso8601String());

  // 두 쿼리를 병렬로 실행
  final [mlResponse, walkResponse] = await Future.wait([mlResultsFuture, walkRecordsFuture]);

  // 3. ML 분석 결과를 AnalysisResult 리스트로 변환
  final mlResults = (mlResponse as List).map((item) => AnalysisResult.fromMap(item)).toList();

  // 4. 산책 기록을 AnalysisResult 리스트로 변환
  final walkResults = (walkResponse as List).map((item) {
    final record = WalkRecord.fromMap(item);
    final distance = record.distanceMeters ?? 0.0;
    final emotionAnalysis = record.finalEmotionAnalysis;

    final activeScore = (distance / 1500.0).clamp(0.0, 1.0); // 1.5km = 1.0점
    final positiveScore = (emotionAnalysis != null && emotionAnalysis['status'] == 'success')
        ? (emotionAnalysis['positive_score'] as num).toDouble()
        : 0.5; // 분석 실패 또는 없으면 중간값

    return AnalysisResult(
      createdAt: record.endedAt ?? record.createdAt, 
      analysisType: 'walk',
      positiveScore: positiveScore,
      activeScore: activeScore,
      activityDescription: '${(distance / 1000).toStringAsFixed(2)}km 산책',
    );
  }).toList();

  // 5. 두 리스트를 합치고 시간순으로 정렬
  final combinedResults = [...mlResults, ...walkResults];
  combinedResults.sort((a, b) => a.createdAt.compareTo(b.createdAt));

  return combinedResults;
});

class DogStatsScreen extends ConsumerStatefulWidget {
  final String dogId;
  const DogStatsScreen({super.key, required this.dogId});

  @override
  ConsumerState<DogStatsScreen> createState() => _DogStatsScreenState();
}

class _DogStatsScreenState extends ConsumerState<DogStatsScreen> {
  String _viewType = 'daily';

  // ✨ [수정] 'walk' 타입을 범례에 추가
  final Map<String, Color> _analysisTypeColors = {
    'eeg': Colors.blue,
    'sound': Colors.green,
    'body_language': Colors.orange,
    'facial_expression': Colors.purple,
    'walk': Colors.teal, // 산책 색상 추가
  };
  final Map<String, String> _analysisTypeNames = {
    'eeg': '뇌파',
    'sound': '음성',
    'body_language': '몸짓',
    'facial_expression': '표정',
    'walk': '산책', // 산책 이름 추가
  };

  Map<int, Map<String, List<AnalysisResult>>> _groupedData = {};

  @override
  Widget build(BuildContext context) {
    final resultsAsyncValue = ref.watch(analysisResultsProvider((dogId: widget.dogId, viewType: _viewType)));

    return Scaffold(
      appBar: AppBar(title: const Text('감정 분석 리포트')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ToggleButtons(
              isSelected: [_viewType == 'daily', _viewType == 'weekly'],
              onPressed: (index) {
                if (!mounted) return;
                setState(() { _viewType = index == 0 ? 'daily' : 'weekly'; });
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
        final typeName = _analysisTypeNames[entry.key] ?? entry.key;
        if (typeName.isEmpty) return const SizedBox.shrink(); // 이름 없는 타입은 숨김
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 16, height: 16, color: entry.value),
            const SizedBox(width: 8),
            Text(typeName),
          ],
        );
      }).toList(),
    );
  }

  void _groupData(List<AnalysisResult> results) {
    _groupedData = {};
    final kst = const Duration(hours: 9);
    for (var result in results) {
      int groupIndex;
      final createdAtKst = result.createdAt.toUtc().add(kst);
      if (_viewType == 'daily') {
        groupIndex = createdAtKst.hour;
      } else {
        groupIndex = createdAtKst.weekday;
      }

      _groupedData.putIfAbsent(groupIndex, () => {});
      _groupedData[groupIndex]!.putIfAbsent(result.analysisType, () => []);
      _groupedData[groupIndex]![result.analysisType]!.add(result);
    }
  }

  BarChartData _buildBarChartData() {
    // ... (차트 데이터 생성 로직은 거의 동일, 타입이 동적으로 처리됨)
     final List<BarChartGroupData> barGroups = [];
    const double barWidth = 8;
    final availableTypes = _analysisTypeColors.keys.toList();

    if (_viewType == 'daily') {
      for (int i = 0; i < 24; i++) {
        final scoresForGroup = _groupedData[i] ?? {};
        barGroups.add(BarChartGroupData(
          x: i,
          barsSpace: 4,
          barRods: availableTypes.map((type) {
            final scores = scoresForGroup[type]?.map((r) => r.positiveScore).toList() ?? [];
            final averageScore = scores.isEmpty ? 0.0 : scores.reduce((a, b) => a + b) / scores.length;
            return BarChartRodData(
                toY: averageScore, color: _analysisTypeColors[type], width: barWidth);
          }).toList(),
        ));
      }
    } else { // weekly
      for (int i = 1; i <= 7; i++) {
        final scoresForGroup = _groupedData[i] ?? {};
        barGroups.add(BarChartGroupData(
          x: i - 1,
          barsSpace: 4,
          barRods: availableTypes.map((type) {
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
            final type = availableTypes[rodIndex];
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
