import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

// --- [추가] DogAvatarWidget을 다시 import 합니다. ---

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

    final resultsAsyncValue = ref.watch(analysisResultsProvider((dogId: dogId, viewType: 'daily')));



// --- [추가] 아바타 크기 계산을 위해 screenHeight를 다시 가져옵니다. ---

    final screenHeight = MediaQuery.of(context).size.height;



    return resultsAsyncValue.when(

      loading: () => const Center(child: CircularProgressIndicator()),

      error: (err, stack) => Center(child: Text('데이터 로딩 실패: $err')),

      data: (results) {

        double avgPositive = 0.5;

        double avgActive = 0.5;



        if (results.isNotEmpty) {

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

              Row(

                mainAxisAlignment: MainAxisAlignment.start,

                children: [

                  _buildCircularStatusGauge(

                    value: avgPositive,

                    color: const Color(0xFFFFB6C1),

                    icon: '❤️',

                  ),

                  const SizedBox(width: 8),

                  _buildCircularStatusGauge(

                    value: avgActive,

                    color: const Color(0xFFB3E2A7),

                    icon: '🔋',

                  ),

                ],

              ),

              const SizedBox(height: 16),



// --- [수정] ---

// 기존 Column 대신 Stack을 사용하여

// 말풍선이 아바타 위에 겹쳐지도록(맨 앞으로 나오도록) 수정합니다.

              Stack(

                alignment: Alignment.topCenter, // 요소들을 상단 중앙에 정렬

                children: [

// 1. 아바타 (뒤에 배치됨)

// 말풍선과 겹치지 않도록 위쪽에 패딩을 주어 살짝 내립니다.

                  Padding(

                    padding: const EdgeInsets.only(top: 60.0), // 말풍선 크기에 맞춰 조정

                    child: SizedBox(

                      height: screenHeight * 0.15, // 원래 높이 유지

                      child: DogAvatarWidget(

                        positiveScore: avgPositive,

                        activeScore: avgActive,

                      ),

                    ),

                  ),

// 2. 말풍선 (앞에 배치됨)

// Stack의 첫 번째 자식이므로 맨 위에 그려집니다.

                  SpeechBubble(message: message),

                ],

              ),

              const SizedBox(height: 62),

            ],

          ),

        );

      },

    );

  }



  Widget _buildCircularStatusGauge({

    required double value,

    required Color color,

    required String icon,

  }) {

    return CircularPercentIndicator(

      radius: 30.0,

      lineWidth: 8.0,

      animation: true,

      animationDuration: 1200,

      percent: value,

      center: Text(

        icon,

        style: const TextStyle(fontSize: 24),

      ),

      circularStrokeCap: CircularStrokeCap.round,

      progressColor: color,

      backgroundColor: color.withAlpha(50),

    );

  }

}