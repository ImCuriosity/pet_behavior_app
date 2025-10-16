import 'package:dognal1/data/api/rest_client.dart'; // walk_records 모델이 여기에 있다고 가정합니다.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart'; // 날짜 포매팅을 위해 추가

// ✨ 안정적인 시간 파싱 로직이 적용된 AnalysisResult 클래스
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
      if (dtString.isEmpty) {
        parsedDate = DateTime.now().toUtc();
      } else {
        var tempString = dtString.replaceFirst(' ', 'T');
        if (tempString.endsWith('+00')) {
          tempString += ':00';
        }
        if (!tempString.endsWith('Z') && !tempString.contains('+')) {
          tempString += 'Z';
        }
        parsedDate = DateTime.parse(tempString);
      }
    } catch (e) {
      parsedDate = DateTime.now().toUtc();
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

// ✨ [개선됨] 데이터 그룹핑 및 평균 계산 로직이 추가된 Provider
final analysisResultsProvider = FutureProvider.autoDispose
    .family<List<AnalysisResult>, ({String dogId, String viewType})>(
        (ref, params) async {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;

      if (userId == null) throw Exception('User not logged in');

      final nowInKst = DateTime.now().toUtc().add(const Duration(hours: 9));
      DateTime queryStartUtc;
      DateTime queryEndUtc;

      if (params.viewType == 'daily') {
        final todayStartKst = DateTime(nowInKst.year, nowInKst.month, nowInKst.day);
        queryStartUtc = todayStartKst.toUtc().subtract(const Duration(hours: 9));
        queryEndUtc = queryStartUtc.add(const Duration(days: 1));
      } else { // weekly
        final startOfWeekKst = nowInKst.subtract(Duration(days: nowInKst.weekday - 1));
        final startOfWeekDateKst = DateTime(startOfWeekKst.year, startOfWeekKst.month, startOfWeekKst.day);
        queryStartUtc = startOfWeekDateKst.toUtc().subtract(const Duration(hours: 9));
        queryEndUtc = queryStartUtc.add(const Duration(days: 7));
      }

      // 1. 데이터 조회
      final mlResultsFuture = supabase
          .from('analysis_results')
          .select('created_at, analysis_type, positive_score, active_score, activity_description')
          .eq('user_id', userId)
          .eq('dog_id', params.dogId)
          .gte('created_at', queryStartUtc.toIso8601String())
          .lt('created_at', queryEndUtc.toIso8601String());

      final walkRecordsFuture = supabase
          .from('walk_records')
          .select()
          .eq('user_id', userId)
          .eq('dog_id', params.dogId)
          .gte('ended_at', queryStartUtc.toIso8601String())
          .lt('ended_at', queryEndUtc.toIso8601String());

      final [mlResponse, walkResponse] = await Future.wait([mlResultsFuture, walkRecordsFuture]);

      // ❗ WalkRecord.fromMap 에서도 AnalysisResult.fromMap과 동일한 시간 파싱 로직을 사용해야 합니다.
      final mlResults = (mlResponse as List).map((item) => AnalysisResult.fromMap(item)).toList();
      final walkResults = (walkResponse as List).map((item) {
        final record = WalkRecord.fromMap(item);
        final distance = record.distanceMeters ?? 0.0;
        final activeScore = (distance / 1500.0).clamp(0.0, 1.0);
        final positiveScore = 0.75;
        return AnalysisResult(
          createdAt: record.endedAt ?? record.createdAt,
          analysisType: 'walk',
          positiveScore: positiveScore,
          activeScore: activeScore,
          activityDescription: '${(distance / 1000).toStringAsFixed(2)}km 산책 완료',
        );
      }).toList();

      final combinedResults = [...mlResults, ...walkResults];
      if (combinedResults.isEmpty) return [];
      combinedResults.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      // 2. 데이터 그룹핑 및 평균 계산
      final groupingInterval = Duration(minutes: params.viewType == 'daily' ? 10 : 120);
      final List<AnalysisResult> aggregatedResults = [];
      var group = <AnalysisResult>[combinedResults.first];
      var groupStartTime = combinedResults.first.createdAt;

      for (int i = 1; i < combinedResults.length; i++) {
        final current = combinedResults[i];
        if (current.createdAt.difference(groupStartTime) < groupingInterval) {
          group.add(current);
        } else {
          final avgPositive = group.map((r) => r.positiveScore).reduce((a, b) => a + b) / group.length;
          final avgActive = group.map((r) => r.activeScore).reduce((a, b) => a + b) / group.length;
          aggregatedResults.add(AnalysisResult(
            createdAt: group.first.createdAt,
            analysisType: 'aggregated',
            positiveScore: avgPositive,
            activeScore: avgActive,
            activityDescription: '${group.length}개 데이터 평균',
          ));
          group = [current];
          groupStartTime = current.createdAt;
        }
      }

      if (group.isNotEmpty) {
        final avgPositive = group.map((r) => r.positiveScore).reduce((a, b) => a + b) / group.length;
        final avgActive = group.map((r) => r.activeScore).reduce((a, b) => a + b) / group.length;
        aggregatedResults.add(AnalysisResult(
          createdAt: group.first.createdAt,
          analysisType: 'aggregated',
          positiveScore: avgPositive,
          activeScore: avgActive,
          activityDescription: '${group.length}개 데이터 평균',
        ));
      }

      return aggregatedResults;
    });


class DogStatsScreen extends ConsumerStatefulWidget {
  final String dogId;
  const DogStatsScreen({super.key, required this.dogId});

  @override
  ConsumerState<DogStatsScreen> createState() => _DogStatsScreenState();
}

class _DogStatsScreenState extends ConsumerState<DogStatsScreen> {
  String _viewType = 'daily';

  final Map<String, Color> _analysisTypeColors = {
    'eeg': Colors.blue.shade300,
    'sound': Colors.lightGreen.shade400,
    'body_language': Colors.orange.shade300,
    'facial_expression': Colors.purple.shade300,
    'walk': Colors.teal.shade400,
    'aggregated': Colors.red.shade300, // 그룹 데이터 색상 추가
    'unknown': Colors.grey.shade400,
  };
  final Map<String, String> _analysisTypeNames = {
    'eeg': '뇌파',
    'sound': '음성',
    'body_language': '몸짓',
    'facial_expression': '표정',
    'walk': '산책',
    'aggregated': '평균', // 그룹 데이터 이름 추가
    'unknown': '기타',
  };

  @override
  Widget build(BuildContext context) {
    final resultsAsyncValue = ref.watch(analysisResultsProvider((dogId: widget.dogId, viewType: _viewType)));
    return Scaffold(
      appBar: AppBar(title: const Text('감정 분석 리포트 🐾')),
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
              error: (err, stack) => Center(child: Text('데이터 로딩 실패: $err\n$stack')),
              data: (results) {
                if (results.isEmpty) {
                  return const Center(child: Text('표시할 데이터가 없습니다.\n분석을 먼저 시작해주세요!'));
                }
                return SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('종합 분석', style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 16),
                        _buildSummarySection(results),
                        const SizedBox(height: 32),
                        Text('시간별 상세 분석', style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 24),
                        _buildLineChartSection(results),
                        const SizedBox(height: 24),
                        _buildLegend(),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

// ✨ [수정됨] 데이터 항목이 3개 미만일 경우를 처리하는 로직 추가
  Widget _buildSummarySection(List<AnalysisResult> results) {
    final Map<String, List<double>> positiveScores = {};
    final Map<String, List<double>> activeScores = {};

    for (var r in results) {
      // 'aggregated' 타입은 요약에서 제외하여 원본 데이터의 분포를 더 잘 보여줄 수 있습니다.
      if (r.analysisType == 'aggregated') continue;
      positiveScores.putIfAbsent(r.analysisType, () => []).add(r.positiveScore);
      activeScores.putIfAbsent(r.analysisType, () => []).add(r.activeScore);
    }

    double getAverage(List<double>? values) {
      if (values == null || values.isEmpty) return 0;
      return values.reduce((a, b) => a + b) / values.length;
    }

    final titles = _analysisTypeNames.entries
        .where((e) => positiveScores.containsKey(e.key) || activeScores.containsKey(e.key))
        .map((e) => e.value)
        .toList();

    // ✨ --- 핵심 수정 사항 --- ✨
    // 레이더 차트를 그리기 전에 데이터 종류가 3개 이상인지 확인합니다.
    if (titles.length < 3) {
      return SizedBox(
        height: 180,
        child: Center(
          child: Text(
            '종합 분석을 표시하기에\n데이터 종류가 부족합니다.\n(최소 3종류 필요)',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ),
      );
    }
    // ✨ --- 여기까지 --- ✨

    final ticks = List.generate(titles.length, (index) => index.toDouble());

    final positiveData = ticks.map((t) {
      final typeKey = _analysisTypeNames.entries.firstWhere((e) => e.value == titles[t.toInt()]).key;
      return getAverage(positiveScores[typeKey]);
    }).toList();

    final activeData = ticks.map((t) {
      final typeKey = _analysisTypeNames.entries.firstWhere((e) => e.value == titles[t.toInt()]).key;
      return getAverage(activeScores[typeKey]);
    }).toList();

    return SizedBox(
      height: 180,
      child: RadarChart(
        RadarChartData(
          dataSets: [
            RadarDataSet(
              dataEntries: positiveData.map((v) => RadarEntry(value: v)).toList(),
              borderColor: Colors.green,
              fillColor: Colors.green.withOpacity(0.3),
            ),
            RadarDataSet(
              dataEntries: activeData.map((v) => RadarEntry(value: v)).toList(),
              borderColor: Colors.orange,
              fillColor: Colors.orange.withOpacity(0.3),
            ),
          ],
          getTitle: (index, angle) => RadarChartTitle(text: titles[index], angle: angle),
          tickCount: 5,
          ticksTextStyle: const TextStyle(color: Colors.transparent, fontSize: 10),
          tickBorderData: const BorderSide(color: Colors.grey, width: 0.5),
          gridBorderData: const BorderSide(color: Colors.grey, width: 1),
        ),
      ),
    );
  }

  Widget _buildLineChartSection(List<AnalysisResult> results) {
    results.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final kst = const Duration(hours: 9);
    final spotsPositive = <FlSpot>[];
    final spotsActive = <FlSpot>[];
    if (results.isEmpty) return const SizedBox(height: 250, child: Center(child: Text("데이터가 없습니다.")));
    DateTime minTime = results.first.createdAt;
    DateTime maxTime = results.last.createdAt;
    for (int i = 0; i < results.length; i++) {
      final result = results[i];
      final x = result.createdAt.millisecondsSinceEpoch.toDouble();
      spotsPositive.add(FlSpot(x, result.positiveScore));
      spotsActive.add(FlSpot(x, result.activeScore));
    }
    final eventLines = results.where((r) => r.analysisType == 'walk').map((r) => VerticalLine(x: r.createdAt.millisecondsSinceEpoch.toDouble(), color: Colors.teal.withOpacity(0.7), strokeWidth: 2, label: VerticalLineLabel(show: true, labelResolver: (line) => '산책', alignment: Alignment.topRight, style: const TextStyle(color: Colors.teal, backgroundColor: Colors.white70)))).toList();
    return SizedBox(
      height: 250,
      child: LineChart(
        LineChartData(
          extraLinesData: ExtraLinesData(verticalLines: eventLines),
          lineBarsData: [
            _buildLineBarData(spotsPositive, Colors.green, results),
            _buildLineBarData(spotsActive, Colors.orange, results),
          ],
          lineTouchData: _buildLineTouchData(results),
          minY: 0,
          maxY: 1.1,
          gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 0.25),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 32, interval: 0.5, getTitlesWidget: (value, meta) => Text(value.toStringAsFixed(1), style: const TextStyle(fontSize: 10)))),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: (maxTime.millisecondsSinceEpoch - minTime.millisecondsSinceEpoch).toDouble() / 4,
                getTitlesWidget: (value, meta) {
                  if (value <= meta.min || value >= meta.max) return const SizedBox();
                  final dateTime = DateTime.fromMillisecondsSinceEpoch(value.toInt()).toUtc().add(kst);
                  String text = _viewType == 'daily' ? DateFormat('HH:mm').format(dateTime) : DateFormat('E', 'ko_KR').format(dateTime);
                  return SideTitleWidget(axisSide: meta.axisSide, space: 4.0, child: Text(text, style: const TextStyle(fontSize: 10)));
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  LineChartBarData _buildLineBarData(List<FlSpot> spots, Color color, List<AnalysisResult> results) {
    return LineChartBarData(
      spots: spots,
      isCurved: false,
      color: color,
      barWidth: 3,
      isStrokeCapRound: true,
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, percent, barData, index) {
          final result = results[index];
          final dotColor = _analysisTypeColors[result.analysisType] ?? Colors.grey;
          return FlDotCirclePainter(radius: 4, color: dotColor, strokeWidth: 1.5, strokeColor: Colors.white);
        },
      ),
      belowBarData: BarAreaData(show: true, color: color.withOpacity(0.1)),
    );
  }

  LineTouchData _buildLineTouchData(List<AnalysisResult> results) {
    return LineTouchData(
      touchTooltipData: LineTouchTooltipData(
        getTooltipColor: (_) => Colors.blueGrey.withOpacity(0.8),
        getTooltipItems: (touchedSpots) {
          return touchedSpots.map((spot) {
            final result = results[spot.spotIndex];
            final kstTime = result.createdAt.toUtc().add(const Duration(hours: 9));
            final timeStr = DateFormat('HH:mm').format(kstTime);
            final typeName = _analysisTypeNames[result.analysisType] ?? '정보 없음';
            String title = '$timeStr - $typeName\n';
            String scoreText = spot.bar.color == Colors.green ? '긍정 점수: ${result.positiveScore.toStringAsFixed(2)}' : '활동 점수: ${result.activeScore.toStringAsFixed(2)}';
            final description = result.activityDescription ?? '';
            return LineTooltipItem('$title$scoreText\n', const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), children: [TextSpan(text: description, style: const TextStyle(color: Colors.white70, fontStyle: FontStyle.italic))], textAlign: TextAlign.left);
          }).toList();
        },
      ),
    );
  }

  Widget _buildLegend() {
    final lineLegends = {'긍정 점수': Colors.green, '활동 점수': Colors.orange};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("범례", style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            ...lineLegends.entries.map((entry) => _buildLegendItem(entry.value, entry.key)),
            const SizedBox(width: double.infinity, height: 4),
            ..._analysisTypeColors.entries.map((entry) {
              final typeName = _analysisTypeNames[entry.key] ?? entry.key;
              return _buildLegendItem(entry.value, '$typeName (점 색상)');
            }),
          ],
        ),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String text) {
    return Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 16, height: 16, color: color), const SizedBox(width: 8), Text(text)]);
  }
}