import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dognal1/features/dog_stats/screens/dog_stats_screen.dart';
import 'package:dognal1/features/tamagotchi/widgets/dog_avatar.dart';
import 'package:percent_indicator/percent_indicator.dart';

// ✨ [추가] 말풍선을 그리기 위한 CustomClipper
class SpeechBubbleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    const tailHeight = 10.0;
    const tailWidth = 20.0;

    // 말풍선의 둥근 사각형 본체
    path.addRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height - tailHeight),
      const Radius.circular(12),
    ));

    // 말풍선 꼬리 부분 (아래쪽 중앙)
    path.moveTo(size.width / 2 - tailWidth / 2, size.height - tailHeight);
    path.lineTo(size.width / 2, size.height); // 꼬리의 뾰족한 끝
    path.lineTo(size.width / 2 + tailWidth / 2, size.height - tailHeight);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

// ✨ [추가] 말풍선 위젯
class SpeechBubble extends StatelessWidget {
  final String message;
  const SpeechBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: SpeechBubbleClipper(),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 30), // 꼬리를 위한 하단 여백 추가
        decoration: BoxDecoration(
          color: Colors.blue.shade50, // 말풍선 배경색
        ),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontStyle: FontStyle.italic,
            color: Colors.black87, // 텍스트 색상
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
    // 가정: analysisResultsProvider는 외부 파일에서 정의된 Riverpod Provider입니다.
    // 현재 코드에서는 해당 Provider의 실제 정의를 알 수 없으므로 가정하고 진행합니다.
    final resultsAsyncValue = ref.watch(analysisResultsProvider((dogId: dogId, viewType: 'daily')));

    final screenHeight = MediaQuery.of(context).size.height;

    return resultsAsyncValue.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('데이터 로딩 실패: $err')),
      data: (results) {
        double avgPositive = 0.0;
        double avgActive = 0.0;
        if (results.isNotEmpty) {
          avgPositive = results.map((r) => r.positiveScore).reduce((a, b) => a + b) / results.length;
          avgActive = results.map((r) => r.activeScore).reduce((a, b) => a + b) / results.length;
        }

        String message = '오늘 하루는 어땠나요?';
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

              // ⭐️ [수정] 말풍선과 강아지 아바타를 Column으로 묶어 배치
              Column(
                children: [
                  // 기존 Text 위젯 대신 새로 만든 SpeechBubble 위젯 사용
                  // 말풍선과 아바타 사이의 공간을 줄입니다.
                  // SizedBox(height: 8) 또는 아예 제거하여 밀착시킵니다.
                  SpeechBubble(message: message),

                  // 강아지 아바타
                  SizedBox(
                    height: screenHeight * 0.15,
                    child: DogAvatarWidget(
                      positiveScore: avgPositive,
                      activeScore: avgActive,
                    ),
                  ),
                ],
              ),

              // ⭐️ [핵심 수정] 아바타와 상태 컬럼(마음, 체력) 사이의 공간을 확보 (24.0 -> 32.0으로 늘림)
              const SizedBox(height: 62),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildCircularStatusGauge(
                    label: '마음',
                    value: avgPositive,
                    color: const Color(0xFFFFB6C1), // 부드러운 핑크
                    icon: '❤️',
                  ),
                  _buildCircularStatusGauge(
                    label: '체력',
                    value: avgActive,
                    color: const Color(0xFFB3E2A7), // 부드러운 그린
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
    required double value, // 여기로 0.75와 같은 값이 전달됩니다.
    required Color color,
    required String icon,
  }) {
    return CircularPercentIndicator(
      radius: 70.0,
      lineWidth: 14.0,
      animation: true,
      animationDuration: 1200,

      // ✅ [수정] value를 그대로 사용합니다. (예: 0.75)
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
            // ✅ [수정] 화면에 표시할 때만 100을 곱해줍니다. (예: "75%")
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