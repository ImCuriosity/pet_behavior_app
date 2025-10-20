import 'package:dognal1/data/api/rest_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import 'package:dognal1/core/providers/analysis_provider.dart';
import 'package:dognal1/data/models/analysis_result.dart';

// 이 화면 전용 Provider
final datedAnalysisResultsProvider = FutureProvider.autoDispose.family<
    List<AnalysisResult>,
    ({String dogId, String viewType, DateTime date})>(
      (ref, params) async {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not logged in');

    final targetDate = params.date;
    DateTime queryStartUtc;
    DateTime queryEndUtc;

    if (params.viewType == 'daily') {
      // --- ▼▼▼ [수정] 시간대 계산 로직을 수정합니다. ▼▼▼ ---
      // KST 기준의 날짜 시작 (예: 2025-10-18 00:00:00 KST)
      final dayStartKst = DateTime(targetDate.year, targetDate.month, targetDate.day);

      // KST 시작 시간을 UTC로 변환하기만 하면 됩니다. (예: 2025-10-17 15:00:00 UTC)
      // 불필요한 subtract()를 삭제합니다.
      queryStartUtc = dayStartKst.toUtc();

      // 다음 날 UTC 시작 시간을 종료 시간으로 설정
      queryEndUtc = queryStartUtc.add(const Duration(days: 1));

    } else { // weekly
      // --- ▼▼▼ [수정] 주간 계산 로직도 동일하게 수정합니다. ▼▼▼ ---
      final startOfWeekKst = targetDate.subtract(Duration(days: targetDate.weekday - 1));
      final startOfWeekDateKst = DateTime(startOfWeekKst.year, startOfWeekKst.month, startOfWeekKst.day);

      // 불필요한 subtract()를 삭제합니다.
      queryStartUtc = startOfWeekDateKst.toUtc();

      queryEndUtc = queryStartUtc.add(const Duration(days: 7));
    }

    final mlResponse = await supabase
        .from('analysis_results')
        .select('created_at, analysis_type, positive_score, active_score, activity_description')
        .eq('user_id', userId)
        .eq('dog_id', params.dogId)
        .gte('created_at', queryStartUtc.toIso8601String())
        .lt('created_at', queryEndUtc.toIso8601String());

    final mlResults = (mlResponse as List).map((item) => AnalysisResult.fromJson(item)).toList();

    if (mlResults.isEmpty) return [];
    mlResults.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return mlResults;
  },
);


// (이하 나머지 UI 코드는 변경 사항이 없습니다.)
enum TimePeriod { am, pm }

class DogStatsScreen extends ConsumerStatefulWidget {
  final String dogId;
  const DogStatsScreen({super.key, required this.dogId});

  @override
  ConsumerState<DogStatsScreen> createState() => _DogStatsScreenState();
}

class _DogStatsScreenState extends ConsumerState<DogStatsScreen> {
  String _viewType = 'daily';
  late DateTime _selectedDate;
  TimePeriod _selectedTimePeriod = TimePeriod.am;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
  }

  final Map<String, Color> _analysisTypeColors = {
    'eeg': Colors.blue.shade300,
    'sound': Colors.lightGreen.shade400,
    'body_language': Colors.orange.shade300,
    'facial_expression': Colors.purple.shade300,
    'aggregated': Colors.red.shade300,
    'unknown': Colors.grey.shade400,
  };
  final Map<String, String> _analysisTypeNames = {
    'eeg': '뇌파',
    'sound': '음성',
    'body_language': '몸짓',
    'facial_expression': '표정',
    'aggregated': '평균',
    'unknown': '기타',
  };

  bool _isNextButtonDisabled() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selected =
    DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    return !selected.isBefore(today);
  }

  @override
  Widget build(BuildContext context) {
    final resultsAsyncValue = ref.watch(datedAnalysisResultsProvider(
        (dogId: widget.dogId, viewType: _viewType, date: _selectedDate)));

    return Scaffold(
      appBar: AppBar(title: const Text('감정 분석 리포트 🐾')),
      body: Column(
        children: [
          _buildDateNavigator(),
          Expanded(
            child: resultsAsyncValue.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) =>
                  Center(child: Text('데이터 로딩 실패: $err\n$stack')),
              data: (results) {
                if (results.isEmpty) {
                  return const Center(
                      child: Text('표시할 데이터가 없습니다.\n분석을 먼저 시작해주세요!'));
                }
                return SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('종합 분석',
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 16),
                        _buildSummarySection(results),
                        const SizedBox(height: 32),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('시간별 상세 분석',
                                style: Theme.of(context).textTheme.titleLarge),
                            if (_viewType == 'daily')
                              _buildTimePeriodSelector(),
                          ],
                        ),
                        const SizedBox(height: 16),
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

  Widget _buildDateNavigator() {
    String headerText;
    if (_viewType == 'daily') {
      headerText =
          DateFormat('yyyy년 M월 d일 (E)', 'ko_KR').format(_selectedDate);
    } else {
      final startOfWeek =
      _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));
      final endOfWeek = startOfWeek.add(const Duration(days: 6));
      headerText =
      '${DateFormat('M/d').format(startOfWeek)} ~ ${DateFormat('M/d').format(endOfWeek)}';
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () {
                  setState(() {
                    _selectedDate = _selectedDate
                        .subtract(Duration(days: _viewType == 'daily' ? 1 : 7));
                  });
                },
              ),
              Column(
                children: [
                  Text(headerText,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  if (_isNextButtonDisabled())
                    const SizedBox(height: 28)
                  else
                    SizedBox(
                      height: 28,
                      child: TextButton(
                        onPressed: () =>
                            setState(() => _selectedDate = DateTime.now()),
                        style: TextButton.styleFrom(
                            padding:
                            const EdgeInsets.symmetric(horizontal: 8),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                        child: const Text('오늘로 이동'),
                      ),
                    ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: _isNextButtonDisabled()
                    ? null
                    : () {
                  setState(() {
                    _selectedDate = _selectedDate
                        .add(Duration(days: _viewType == 'daily' ? 1 : 7));
                  });
                },
              ),
            ],
          ),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'daily', label: Text('일간')),
              ButtonSegment(value: 'weekly', label: Text('주간')),
            ],
            selected: {_viewType},
            onSelectionChanged: (newSelection) {
              setState(() {
                _viewType = newSelection.first;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTimePeriodSelector() {
    return SegmentedButton<TimePeriod>(
      segments: const [
        ButtonSegment(value: TimePeriod.am, label: Text('오전')),
        ButtonSegment(value: TimePeriod.pm, label: Text('오후')),
      ],
      selected: {_selectedTimePeriod},
      onSelectionChanged: (newSelection) {
        setState(() {
          _selectedTimePeriod = newSelection.first;
        });
      },
      style: SegmentedButton.styleFrom(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _buildSummarySection(List<AnalysisResult> results) {
    final Map<String, List<double>> positiveScores = {};
    final Map<String, List<double>> activeScores = {};
    for (var r in results) {
      if (r.analysisType == 'aggregated') continue;
      positiveScores.putIfAbsent(r.analysisType, () => []).add(r.positiveScore);
      activeScores.putIfAbsent(r.analysisType, () => []).add(r.activeScore);
    }
    double getAverage(List<double>? values) {
      if (values == null || values.isEmpty) return 0;
      return values.reduce((a, b) => a + b) / values.length;
    }
    final titles = _analysisTypeNames.entries
        .where((e) =>
    positiveScores.containsKey(e.key) ||
        activeScores.containsKey(e.key))
        .map((e) => e.value)
        .toList();
    if (titles.isEmpty) {
      return SizedBox(
        height: 220,
        child: Center(
          child: Text(
            '종합 분석을 표시할 데이터가 없습니다.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ),
      );
    }
    final positiveData = titles.map((title) {
      final typeKey =
          _analysisTypeNames.entries.firstWhere((e) => e.value == title).key;
      return getAverage(positiveScores[typeKey]);
    }).toList();
    final activeData = titles.map((title) {
      final typeKey =
          _analysisTypeNames.entries.firstWhere((e) => e.value == title).key;
      return getAverage(activeScores[typeKey]);
    }).toList();
    return SizedBox(
      height: 220,
      child: BarChart(
        BarChartData(
          maxY: 1,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => Colors.blueGrey.withOpacity(0.8),
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                String label = rodIndex == 0 ? '긍정' : '활동';
                return BarTooltipItem(
                  '$label: ${rod.toY.toStringAsFixed(2)}',
                  const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final text = titles[value.toInt()];
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    space: 4,
                    child: Text(text, style: const TextStyle(fontSize: 12)),
                  );
                },
                reservedSize: 32,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                interval: 0.5,
                getTitlesWidget: (value, meta) => Text(
                  value.toStringAsFixed(1),
                  style: const TextStyle(fontSize: 10),
                ),
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 0.25,
            getDrawingHorizontalLine: (value) => const FlLine(
              color: Colors.black12,
              strokeWidth: 1,
            ),
          ),
          barGroups: List.generate(titles.length, (i) {
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                    toY: positiveData[i],
                    color: Colors.green,
                    width: 16,
                    borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(4),
                        topRight: Radius.circular(4))),
                BarChartRodData(
                    toY: activeData[i],
                    color: Colors.orange,
                    width: 16,
                    borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(4),
                        topRight: Radius.circular(4))),
              ],
            );
          }),
          groupsSpace: 20,
        ),
      ),
    );
  }

  // --- ▼▼▼ [수정] _buildLineChartSection 함수를 수정합니다. ▼▼▼ ---
  Widget _buildLineChartSection(List<AnalysisResult> results) {
    // --- '주간' 보기일 경우: ---
    if (_viewType == 'weekly') {
      results.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      if (results.isEmpty) return const SizedBox(height: 250, child: Center(child: Text("데이터가 없습니다.")));

      final kst = const Duration(hours: 9);
      final spotsPositive = <FlSpot>[];
      final spotsActive = <FlSpot>[];
      DateTime minTime = results.first.createdAt;
      DateTime maxTime = results.last.createdAt;

      for (int i = 0; i < results.length; i++) {
        final result = results[i];
        final x = result.createdAt.millisecondsSinceEpoch.toDouble();
        spotsPositive.add(FlSpot(x, result.positiveScore));
        spotsActive.add(FlSpot(x, result.activeScore));
      }

      // --- [핵심 수정] interval이 0이 되는 것을 방지하는 안전장치 추가 ---
      double bottomInterval;
      final timeDiff = maxTime.millisecondsSinceEpoch - minTime.millisecondsSinceEpoch;

      if (timeDiff > 0) {
        // 데이터가 여러 개일 경우, 전체 기간을 4등분하여 라벨 간격 설정
        bottomInterval = timeDiff.toDouble() / 4;
      } else {
        // 데이터가 하나뿐일 경우, 임의의 간격(예: 하루)을 설정하여 에러 방지
        bottomInterval = const Duration(days: 1).inMilliseconds.toDouble();
      }

      return SizedBox(
        height: 250,
        child: LineChart(
          LineChartData(
            lineBarsData: [
              _buildLineBarData(spotsPositive, Colors.green, results),
              _buildLineBarData(spotsActive, Colors.orange, results)
            ],
            minY: 0,
            maxY: 1.1,
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      interval: 0.5,
                      getTitlesWidget: (value, meta) =>
                          Text(value.toStringAsFixed(1)))),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  interval: bottomInterval, // 안전하게 계산된 interval 사용
                  getTitlesWidget: (value, meta) {
                    // 데이터가 하나뿐일 때, 라벨이 차트 범위를 벗어나면 표시하지 않음
                    if (value < minTime.millisecondsSinceEpoch || value > maxTime.millisecondsSinceEpoch) {
                      return const SizedBox.shrink();
                    }
                    final dateTime = DateTime.fromMillisecondsSinceEpoch(value.toInt()).toUtc().add(kst);
                    return SideTitleWidget(
                        axisSide: meta.axisSide,
                        space: 4.0,
                        child: Text(DateFormat('E', 'ko_KR').format(dateTime)));
                  },
                ),
              ),
            ),
          ),
        ),
      );
    }
    final kst = const Duration(hours: 9);

    final filteredResults = results.where((r) {
      final kstTime = r.createdAt.toUtc().add(kst);
      if (_selectedTimePeriod == TimePeriod.am) {
        return kstTime.hour >= 0 && kstTime.hour < 12;
      } else {
        return kstTime.hour >= 12 && kstTime.hour < 24;
      }
    }).toList();

    if (filteredResults.isEmpty) {
      return SizedBox(
          height: 250,
          child: Center(
              child: Text(
                  "${_selectedTimePeriod == TimePeriod.am ? '오전' : '오후'} 데이터가 없습니다.")));
    }

    final selectedDayStart =
    DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final minTime = _selectedTimePeriod == TimePeriod.am
        ? selectedDayStart
        : selectedDayStart.add(const Duration(hours: 12));
    final maxTime = minTime.add(const Duration(hours: 12));

    final spotsPositive = <FlSpot>[];
    final spotsActive = <FlSpot>[];
    for (int i = 0; i < filteredResults.length; i++) {
      final result = filteredResults[i];
      final x = result.createdAt.millisecondsSinceEpoch.toDouble();
      spotsPositive.add(FlSpot(x, result.positiveScore));
      spotsActive.add(FlSpot(x, result.activeScore));
    }

    return SizedBox(
      height: 250,
      child: LineChart(
        LineChartData(
          minX: minTime.millisecondsSinceEpoch.toDouble(),
          maxX: maxTime.millisecondsSinceEpoch.toDouble(),
          minY: 0,
          maxY: 1.1,
          gridData: FlGridData(
              show: true, drawVerticalLine: true, horizontalInterval: 0.25),
          borderData: FlBorderData(
              show: true,
              border: Border.all(color: const Color(0xff37434d), width: 1)),
          lineBarsData: [
            _buildLineBarData(spotsPositive, Colors.green, filteredResults),
            _buildLineBarData(spotsActive, Colors.orange, filteredResults),
          ],
          lineTouchData: _buildLineTouchData(filteredResults),
          titlesData: FlTitlesData(
            topTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
                sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 32,
                    interval: 0.5,
                    getTitlesWidget: (value, meta) =>
                        Text(value.toStringAsFixed(1)))),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: const Duration(hours: 3).inMilliseconds.toDouble(),
                getTitlesWidget: (value, meta) {
                  final dateTime =
                  DateTime.fromMillisecondsSinceEpoch(value.toInt());
                  if (dateTime == minTime || dateTime == maxTime) {
                    return const SizedBox.shrink();
                  }
                  return SideTitleWidget(
                      axisSide: meta.axisSide,
                      space: 4.0,
                      child: Text(DateFormat('HH:mm').format(dateTime),
                          style: const TextStyle(fontSize: 10)));
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  LineChartBarData _buildLineBarData(
      List<FlSpot> spots, Color color, List<AnalysisResult> results) {
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
          final dotColor =
              _analysisTypeColors[result.analysisType] ?? Colors.grey;
          return FlDotCirclePainter(
              radius: 4,
              color: dotColor,
              strokeWidth: 1.5,
              strokeColor: Colors.white);
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
            final kstTime =
            result.createdAt.toUtc().add(const Duration(hours: 9));
            final timeStr = DateFormat('HH:mm').format(kstTime);
            final typeName =
                _analysisTypeNames[result.analysisType] ?? '정보 없음';
            String title = '$timeStr - $typeName\n';
            String scoreText = spot.bar.color == Colors.green
                ? '긍정 점수: ${result.positiveScore.toStringAsFixed(2)}'
                : '활동 점수: ${result.activeScore.toStringAsFixed(2)}';
            final description = result.activityDescription ?? '';
            return LineTooltipItem(
              '$title$scoreText\n',
              const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
              children: [
                TextSpan(
                    text: description,
                    style: const TextStyle(
                        color: Colors.white70, fontStyle: FontStyle.italic))
              ],
              textAlign: TextAlign.left,
            );
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
            ...lineLegends.entries
                .map((entry) => _buildLegendItem(entry.value, entry.key)),
            const SizedBox(width: double.infinity, height: 4),
            ..._analysisTypeColors.entries.map((entry) {
              final typeName = _analysisTypeNames[entry.key] ?? entry.key;
              if (typeName == "평균") return const SizedBox.shrink();
              return _buildLegendItem(entry.value, '$typeName (점 색상)');
            }),
          ],
        ),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 16, height: 16, color: color),
        const SizedBox(width: 8),
        Text(text)
      ],
    );
  }
}

