import 'package:dognal1/data/api/rest_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

// ✨ [Provider] dogId를 받아 해당 강아지의 산책 기록 목록을 가져오는 FutureProvider
final walkHistoryProvider =
FutureProvider.autoDispose.family<List<WalkRecord>, String>((ref, dogId) {
  final restClient = ref.watch(restClientProvider);
  return restClient.getWalkHistory(dogId);
});

// ✨ [Screen] 산책 기록 목록을 보여주는 화면
class WalkHistoryScreen extends ConsumerWidget {
  final String dogId;
  const WalkHistoryScreen({super.key, required this.dogId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // dogId를 사용하여 provider를 watch합니다.
    final historyAsyncValue = ref.watch(walkHistoryProvider(dogId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('산책 기록'),
      ),
      body: historyAsyncValue.when(
        // 데이터 로딩 중일 때
        loading: () => const Center(child: CircularProgressIndicator()),
        // 오류가 발생했을 때
        error: (err, stack) => Center(
          child: Text('산책 기록을 불러오는데 실패했습니다:\n$err', textAlign: TextAlign.center),
        ),
        // 데이터 로딩이 완료되었을 때
        data: (records) {
          if (records.isEmpty) {
            return const Center(
              child: Text(
                '아직 산책 기록이 없어요.\n첫 산책을 시작해보세요!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }
          // 기록이 있으면 ListView로 표시
          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: records.length,
            itemBuilder: (context, index) {
              return _WalkRecordCard(record: records[index]);
            },
          );
        },
      ),
    );
  }
}

// ✨ [Widget] 개별 산책 기록을 보여주는 카드 UI
class _WalkRecordCard extends StatelessWidget {
  final WalkRecord record;
  const _WalkRecordCard({required this.record});

  // 경과 시간을 보기 좋은 형태로 변환
  String _formatDuration(int seconds) {
    final d = Duration(seconds: seconds);
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    final hours = twoDigits(d.inHours);
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final secs = twoDigits(d.inSeconds.remainder(60));
    if (d.inHours > 0) {
      return "$hours:$minutes:$secs";
    }
    return "$minutes:$secs";
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 날짜
            Text(
              DateFormat('yyyy년 MM월 dd일 (E)', 'ko_KR').format(record.startedAt),
              style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Divider(height: 24),
            // 주요 정보 (거리, 시간, 날씨)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _infoTile('거리', '${(record.distanceMeters! / 1000).toStringAsFixed(2)} km'),
                _infoTile('시간', _formatDuration(record.durationSeconds!)),
                _infoTile('날씨', record.weatherInfo ?? '정보 없음'),
              ],
            ),
            // ✨ [추가] 감정 분석 결과 표시 섹션
            const Divider(height: 24),
            _buildEmotionAnalysisSection(),
          ],
        ),
      ),
    );
  }

  // 기본 정보 타일 (거리, 시간, 날씨)
  Widget _infoTile(String title, String value) {
    return Column(
      children: [
        Text(title, style: const TextStyle(color: Colors.grey, fontSize: 14)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }

  // ✨ [추가] 감정 분석 결과 위젯
  Widget _buildEmotionAnalysisSection() {
    final analysis = record.finalEmotionAnalysis;

    if (analysis == null || analysis['status'] != 'success') {
      return Padding(
        padding: const EdgeInsets.only(top: 8.0),
        child: Center(
          child: Text(
            '산책 후 감정 분석 결과가 없습니다.',
            style: TextStyle(color: Colors.grey[600], fontStyle: FontStyle.italic),
          ),
        ),
      );
    }

    final positiveScore = (analysis['positive_score'] as num?)?.toDouble() ?? 0.0;
    final activeScore = (analysis['active_score'] as num?)?.toDouble() ?? 0.0;

    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _emotionScoreTile('긍정 점수', positiveScore, Colors.green),
          _emotionScoreTile('활동 점수', activeScore, Colors.orange),
        ],
      ),
    );
  }

  // ✨ [추가] 감정 점수를 원형 차트로 보여주는 위젯
  Widget _emotionScoreTile(String title, double score, Color color) {
    return Column(
      children: [
        Text(title, style: const TextStyle(color: Colors.grey, fontSize: 14)),
        const SizedBox(height: 8),
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 60,
              height: 60,
              child: CircularProgressIndicator(
                value: score, // 0.0 ~ 1.0 사이의 값
                strokeWidth: 6,
                backgroundColor: color.withOpacity(0.2),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            Text(
              '${(score * 100).toStringAsFixed(0)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
      ],
    );
  }
}
