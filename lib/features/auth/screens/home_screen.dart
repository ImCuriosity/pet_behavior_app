import 'dart:convert';
import 'dart:typed_data';
import 'package:dognal1/features/dog_stats/screens/dog_stats_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dognal1/data/api/rest_client.dart';

import 'package:dognal1/features/diary/screens/diary_screen.dart';
import 'package:dognal1/features/walk/screens/walk_screen.dart';
import 'package:dognal1/features/chatbot/screens/chatbot_modal.dart';
import 'package:dognal1/features/tamagotchi/screens/tamagotchi_screen.dart'; // ✨ [추가] 다마고치 화면 임포트

const String mockDogId = 'test_dog_id_001'; // 임시 mock id

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final supabase = Supabase.instance.client;
    try {
      await supabase.auth.signOut();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('로그아웃 실패: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userEmail = Supabase.instance.client.auth.currentUser?.email ?? 'User';

    return Scaffold(
      appBar: AppBar(
        title: Text('$userEmail의 반려견'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _signOut(context, ref),
            tooltip: '로그아웃',
          ),
        ],
      ),
      body: SingleChildScrollView( // ⭐️ [수정 1] 전체 화면을 SingleChildScrollView로 감쌈
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // ⭐️ [수정 2] Expanded 대신 Card로 감싸고 고정된 비율을 제거
            // TamagotchiScreen이 자체 높이를 기반으로 배치되도록 함
            const Card(
              elevation: 0, // TamagotchiScreen 내부에서 그림자 처리했으므로 제거
              margin: EdgeInsets.zero,
              child: TamagotchiScreen(dogId: mockDogId),
            ),

            const SizedBox(height: 20),

            // ⭐️ [수정 3] Expanded 대신 Column으로 감싸고 AnalysisControlPanel 배치
            const Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AnalysisControlPanel(),
              ],
            ),

            // ⭐️ [수정 4] Spacer 대신 SizedBox를 사용하여 고정 간격 확보
            const SizedBox(height: 30),

            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10.0),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 12.0,
                runSpacing: 12.0,
                children: [
                  _buildNavigationButton(
                    context: context,
                    icon: Icons.book,
                    label: '강아지 일기',
                    onPressed: () {
                      Navigator.push(
                        context,
                        // ✨ [수정] 화면 이동 시 dogId를 전달합니다.
                        MaterialPageRoute(builder: (context) => const DiaryScreen(dogId: mockDogId)),
                      );
                    },
                  ),
                  _buildNavigationButton(
                    context: context,
                    icon: Icons.pets,
                    label: '산책가기',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const WalkScreen()),
                      );
                    },
                  ),
                  _buildNavigationButton(
                    context: context,
                    icon: Icons.show_chart,
                    label: '감정 그래프',
                    onPressed: () {
                      Navigator.push(
                        context,
                        // ✨ [수정] 화면 이동 시 dogId를 전달합니다.
                        MaterialPageRoute(builder: (context) => const DogStatsScreen(dogId: mockDogId)),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (BuildContext context) {
              // ✨ [수정] 챗봇 모달에 dogId를 전달합니다.
              return const ChatbotModal(dogId: mockDogId);
            },
          );
        },
        child: const Icon(Icons.chat),
        tooltip: '챗봇에게 물어보기',
      ),
    );
  }

  Widget _buildNavigationButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      icon: Icon(icon),
      label: Text(label),
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        textStyle: const TextStyle(fontSize: 16),
      ),
    );
  }
}

class AnalysisControlPanel extends ConsumerStatefulWidget {
  const AnalysisControlPanel({super.key});
  @override
  ConsumerState<AnalysisControlPanel> createState() => _AnalysisControlPanelState();
}

class _AnalysisControlPanelState extends ConsumerState<AnalysisControlPanel> {
  String _result = '분석할 활동을 선택하세요.';
  bool _isLoading = false;

  Future<String?> _showDescriptionDialog() async {
    return showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('분석 전 활동 설명'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: '강아지가 무엇을 하고 있었나요?',
              hintText: '예: 창 밖을 보며 짖고 있었음',
              border: OutlineInputBorder(),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('취소'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              child: const Text('분석 시작'),
              onPressed: () => Navigator.of(context).pop(controller.text),
            ),
          ],
        );
      },
    );
  }

  Future<void> _runAnalysis(
    Future<Map<String, dynamic>> Function() analysisFunction,
  ) async {
    setState(() {
      _isLoading = true;
      _result = 'Cloud Run 서버에 요청 중...';
    });

    try {
      final result = await analysisFunction();
      final status = result['status'] ?? 'unknown';

      if (status == 'success') {
        final positiveScore = result['positive_score'] ?? 0.0;
        final activeScore = result['active_score'] ?? 0.0;
        setState(() {
          _result =
              '✅ 분석 성공!\n- 긍정 점수: ${positiveScore.toStringAsFixed(2)}\n- 활동 점수: ${activeScore.toStringAsFixed(2)}';
        });
        // ✨ [수정] provider를 무효화할 때 dogId와 viewType을 모두 전달하여, 정확한 데이터만 새로고침합니다.
        ref.invalidate(analysisResultsProvider((dogId: mockDogId, viewType: 'daily')));
        ref.invalidate(analysisResultsProvider((dogId: mockDogId, viewType: 'weekly')));
      } else {
        setState(() {
          _result = '❌ 서버 응답 오류: $status';
        });
      }
    } catch (e) {
      setState(() {
        _result = '💣 예기치 않은 오류 발생:\n$e';
      });
    }
    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final restClient = ref.watch(restClientProvider);
    final mockAudioData = Uint8List.fromList(List.generate(1024, (i) => i % 256));
    final mockImageData = Uint8List.fromList(List.generate(1024 * 5, (i) => i % 256));
    final mockEegData = Uint8List.fromList(List.generate(1024 * 2, (i) => i % 256));

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12.0),
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            _result,
            style: const TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 20),
        if (_isLoading) const CircularProgressIndicator(),
        const SizedBox(height: 20),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.multitrack_audio),
              label: const Text('소리 분석'),
              onPressed: _isLoading
                  ? null
                  : () async {
                      final description = await _showDescriptionDialog();
                      if (description == null) return;

                      final accessToken = Supabase.instance.client.auth.currentSession?.accessToken;
                      if (accessToken == null) return;

                      await _runAnalysis(() => restClient.analyzeSound(
                          dogId: mockDogId,
                          audioBytes: mockAudioData,
                          accessToken: accessToken,
                          activityDescription: description));
                    },
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.sentiment_satisfied),
              label: const Text('표정 분석'),
              onPressed: _isLoading
                  ? null
                  : () async {
                      final description = await _showDescriptionDialog();
                      if (description == null) return;

                      final accessToken = Supabase.instance.client.auth.currentSession?.accessToken;
                      if (accessToken == null) return;

                      await _runAnalysis(() => restClient.analyzeFacialExpression(
                          dogId: mockDogId,
                          imageBytes: mockImageData,
                          accessToken: accessToken,
                          activityDescription: description));
                    },
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.directions_run),
              label: const Text('몸짓 분석'),
              onPressed: _isLoading
                  ? null
                  : () async {
                      final description = await _showDescriptionDialog();
                      if (description == null) return;

                      final accessToken = Supabase.instance.client.auth.currentSession?.accessToken;
                      if (accessToken == null) return;

                      await _runAnalysis(() => restClient.analyzeBodyLanguage(
                          dogId: mockDogId,
                          imageBytes: mockImageData,
                          accessToken: accessToken,
                          activityDescription: description));
                    },
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.waves),
              label: const Text('뇌파 분석'),
              onPressed: _isLoading
                  ? null
                  : () async {
                      final description = await _showDescriptionDialog();
                      if (description == null) return;

                      final accessToken = Supabase.instance.client.auth.currentSession?.accessToken;
                      if (accessToken == null) return;

                      await _runAnalysis(() => restClient.analyzeEEG(
                          dogId: mockDogId,
                          eegBytes: mockEegData,
                          accessToken: accessToken,
                          activityDescription: description));
                    },
            ),
          ],
        ),
      ],
    );
  }
}
