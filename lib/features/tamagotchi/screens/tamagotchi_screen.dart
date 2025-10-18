import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dognal1/features/tamagotchi/widgets/dog_avatar.dart';
import 'package:percent_indicator/percent_indicator.dart';

// --- [추가] 중앙에서 상태를 관리하는 Provider와 데이터 모델을 import 합니다. ---
import 'package:dognal1/core/providers/analysis_provider.dart';
import 'package:dognal1/data/models/analysis_result.dart';


// 말풍선을 그리기 위한 CustomClipper (변경 없음)
class SpeechBubbleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    const tailHeight = 10.0;
    const tailWidth = 20.0;

    path.addRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height - tailHeight),
      const Radius.circular(12),
    ));

    path.moveTo(size.width / 2 - tailWidth / 2, size.height - tailHeight);
    path.lineTo(size.width / 2, size.height);
    path.lineTo(size.width / 2 + tailWidth / 2, size.height - tailHeight);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

// 말풍선 위젯 (변경 없음)
class SpeechBubble extends StatelessWidget {
  final String message;
  const SpeechBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: SpeechBubbleClipper(),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
        ),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontStyle: FontStyle.italic,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }
}

class TamagotchiScreen extends ConsumerWidget {
  final String dogId;
  const TamagotchiScreen({super.key, required this.dogId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // --- [수정] 중앙에서 관리되는 analysisResultsProvider를 watch(구독)합니다. ---
    // 이제 home_screen에서 invalidate를 호출하면 이 위젯이 자동으로 다시 그려집니다.
    final resultsAsyncValue = ref.watch(analysisResultsProvider((dogId: dogId, viewType: 'daily')));

    final screenHeight = MediaQuery.of(context).size.height;

    return resultsAsyncValue.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('데이터 로딩 실패: $err')),
      data: (results) { // 'results'는 이제 List<AnalysisResult> 타입입니다.
        double avgPositive = 0.5; // 데이터가 없을 때를 대비한 기본값
        double avgActive = 0.5;

        if (results.isNotEmpty) {
          // --- [수정] Map['key'] 대신 AnalysisResult 객체의 속성을 직접 사용합니다. ---
          avgPositive = results.map((r) => r.positiveScore).reduce((a, b) => a + b) / results.length;
          avgActive = results.map((r) => r.activeScore).reduce((a, b) => a + b) / results.length;
        }

        String message;
        if (results.isEmpty) {
          message = '오늘의 활동 데이터가 아직 없어요.';
        } else {
          if (avgPositive > 0.7) {
            message = avgActive > 0.6 ? '최고의 하루! 신나게 놀았어요! 멍멍!' : '편안하고 행복한 하루였어요.';
          } else if (avgPositive < 0.4) {
            message = avgActive > 0.6 ? '뭔가 불편해요. 스트레스 받는 일이 있었나?' : '조금 시무룩해요... Zzz';
          } else {
            message = avgActive > 0.7 ? '산책이 필요해요! 에너지가 넘쳐요!' : '그냥 그런 하루... 특별한 일은 없었어요.';
          }
        }

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.2),
                spreadRadius: 1,
                blurRadius: 5,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text("오늘의 컨디션 리포트 🐾",
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Column(
                children: [
                  SpeechBubble(message: message),
                  SizedBox(
                    height: screenHeight * 0.15,
                    child: DogAvatarWidget(
                      positiveScore: avgPositive,
                      activeScore: avgActive,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 62),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildCircularStatusGauge(
                    label: '마음',
                    value: avgPositive,
                    color: const Color(0xFFFFB6C1),
                    icon: '❤️',
                  ),
                  _buildCircularStatusGauge(
                    label: '체력',
                    value: avgActive,
                    color: const Color(0xFFB3E2A7),
                    icon: '🔋',
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCircularStatusGauge({
    required String label,
    required double value,
    required Color color,
    required String icon,
  }) {
    return CircularPercentIndicator(
      radius: 70.0,
      lineWidth: 14.0,
      animation: true,
      animationDuration: 1200,
      percent: value,
      center: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20.0,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "${(value * 100).toStringAsFixed(0)}%",
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 22.0,
              color: color.withOpacity(0.8),
            ),
          ),
        ],
      ),
      footer: Padding(
        padding: const EdgeInsets.only(top: 8.0),
        child: Text(
          icon,
          style: const TextStyle(fontSize: 24),
        ),
      ),
      circularStrokeCap: CircularStrokeCap.round,
      progressColor: color,
      backgroundColor: color.withAlpha(50),
    );
  }
}

