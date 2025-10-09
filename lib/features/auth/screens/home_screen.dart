import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dognal1/data/api/rest_client.dart';

import 'package:dognal1/features/diary/screens/diary_screen.dart';
import 'package:dognal1/features/walk/screens/walk_screen.dart';
import 'package:dognal1/features/chatbot/screens/chatbot_modal.dart';

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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(
              flex: 4,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[400]!),
                ),
                child: const Center(
                  child: Text(
                    '(강아지 다마고치 공간)',
                    style: TextStyle(fontSize: 22, color: Colors.black54, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Expanded(
              flex: 3,
              child: SingleChildScrollView(
                child: AnalysisControlPanel(),
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildNavigationButton(
                    context: context,
                    icon: Icons.book,
                    label: '강아지 일기 훔쳐보기',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const DiaryScreen()),
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
              return const ChatbotModal();
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
  String _result = '버튼을 눌러 분석을 시작하세요.';
  bool _isLoading = false;

  Future<void> _runAnalysis(Future<Map<String, dynamic>> Function(String accessToken) analysisFunction) async {
    setState(() {
      _isLoading = true;
      _result = 'Cloud Run 서버에 요청 중...';
    });

    final accessToken = Supabase.instance.client.auth.currentSession?.accessToken;

    if (accessToken == null) {
      setState(() {
        _result = '💣 인증 오류: 로그인 상태를 확인해주세요.';
        _isLoading = false;
      });
      return;
    }

    try {
      final result = await analysisFunction(accessToken);
      final status = result['status'] ?? 'unknown';
      
      // ✨ [수정] 서버에서 보내주는 점수를 화면에 표시합니다.
      if (status == 'success') {
        final positiveScore = result['positive_score'] ?? 0.0;
        final activeScore = result['active_score'] ?? 0.0;
        setState(() {
          _result = '✅ 분석 성공!\n- 긍정 점수 (Positive): ${positiveScore.toStringAsFixed(2)}\n- 활동 점수 (Active): ${activeScore.toStringAsFixed(2)}';
        });
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
    const String mockDogId = 'test_dog_id_001';
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
              onPressed: _isLoading ? null : () => _runAnalysis((accessToken) => restClient.analyzeSound(dogId: mockDogId, audioBytes: mockAudioData, accessToken: accessToken)),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.sentiment_satisfied),
              label: const Text('표정 분석'),
              onPressed: _isLoading ? null : () => _runAnalysis((accessToken) => restClient.analyzeFacialExpression(dogId: mockDogId, imageBytes: mockImageData, accessToken: accessToken)),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.directions_run),
              label: const Text('몸짓 분석'),
              onPressed: _isLoading ? null : () => _runAnalysis((accessToken) => restClient.analyzeBodyLanguage(dogId: mockDogId, imageBytes: mockImageData, accessToken: accessToken)),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.analytics),
              label: const Text('뇌파(EEG) 분석'),
              onPressed: _isLoading ? null : () => _runAnalysis((accessToken) => restClient.analyzeEEG(dogId: mockDogId, eegBytes: mockEegData, accessToken: accessToken)),
            ),
          ],
        ),
      ],
    );
  }
}
