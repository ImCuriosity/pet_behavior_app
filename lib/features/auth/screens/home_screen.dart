import 'package:dognal1/core/providers/auth_provider.dart'; // ✅ Provider를 중앙에서 가져오기 위한 import
import 'package:dognal1/features/dog_profile/screens/create_dog_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dognal1/features/diary/screens/diary_screen.dart';
import 'package:dognal1/features/walk/screens/walk_screen.dart';
import 'package:dognal1/features/chatbot/screens/chatbot_modal.dart';
import 'package:dognal1/features/tamagotchi/screens/tamagotchi_screen.dart';
import 'package:dognal1/features/dog_stats/screens/dog_stats_screen.dart';
import 'package:dognal1/data/api/rest_client.dart';
import 'dart:typed_data';

// ⛔️ 이 파일에 있던 Provider 정의는 auth_provider.dart로 이동했으므로 삭제합니다.

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  // ✅ 매우 단순해진 로그아웃 함수
  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    try {
      // signOut만 호출하면 AuthChecker와 Provider가 모든 것을 알아서 처리합니다.
      await Supabase.instance.client.auth.signOut();
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
    // ✅ 중앙 Provider를 통해 강아지 ID와 사용자 정보를 반응형으로 가져옵니다.
    final dogIdAsync = ref.watch(dogIdProvider);
    final user = ref.watch(userProvider); // auth_provider에 정의된 userProvider
    final userEmail = user?.email ?? 'User';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FF),
      appBar: AppBar(
        title:
        Text('$userEmail의 반려견', style: const TextStyle(color: Colors.black87)),
        actions: [
          // ✅ 디버그 버튼: 반응형 Provider를 사용하여 항상 정확한 정보를 보여줍니다.
          IconButton(
            icon: const Icon(Icons.bug_report, color: Colors.redAccent),
            tooltip: '디버그 정보 보기',
            onPressed: () {
              final dogId = dogIdAsync.value;

              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('🐞 디버그 정보'),
                  content: SingleChildScrollView(
                    child: ListBody(
                      children: <Widget>[
                        const Text('현재 로그인된 사용자 정보',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('Email: ${user?.email ?? "N/A"}'),
                        const Text('User ID:',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        SelectableText(user?.id ?? '로그인되지 않음'),
                        const Divider(height: 20),
                        const Text('DB에서 조회된 강아지 정보',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('Dog ID:',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        SelectableText(dogId ?? '없음'),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      child: const Text('닫기'),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.black87),
            onPressed: () => _signOut(context, ref),
            tooltip: '로그아웃',
          ),
        ],
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: dogIdAsync.when(
        data: (dogId) {
          if (dogId == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('반려견 프로필이 없습니다.'),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CreateDogProfileScreen(),
                        ),
                      ).then((_) {
                        // 프로필 생성 후 수동으로 갱신
                        ref.refresh(dogIdProvider);
                      });
                    },
                    child: const Text('반려견 프로필 만들기'),
                  ),
                ],
              ),
            );
          }
          return HomeScreenContent(dogId: dogId);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('오류 발생: $err')),
      ),
      floatingActionButton: dogIdAsync.when(
        data: (dogId) {
          if (dogId != null) {
            return FloatingActionButton(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.white,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  builder: (BuildContext context) {
                    return ChatbotModal(dogId: dogId);
                  },
                );
              },
              backgroundColor: const Color(0xFF623AA2),
              child: const Icon(Icons.chat_bubble_outline, color: Colors.white),
              tooltip: '챗봇에게 물어보기',
            );
          }
          return null;
        },
        loading: () => null,
        error: (err, stack) => null,
      ),
    );
  }
}

class HomeScreenContent extends ConsumerWidget {
  final String dogId;

  const HomeScreenContent({required this.dogId, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Card(
            elevation: 0,
            margin: EdgeInsets.zero,
            color: Colors.transparent,
            child: TamagotchiScreen(dogId: dogId),
          ),
          const SizedBox(height: 20),
          AnalysisControlPanel(dogId: dogId),
          const SizedBox(height: 40),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildNavigationButton(
                context: context,
                icon: Icons.book_outlined,
                label: '강아지 일기',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => DiaryScreen(dogId: dogId)),
                  );
                },
              ),
              const SizedBox(height: 12),
              _buildNavigationButton(
                context: context,
                icon: Icons.pets_outlined,
                label: '산책가기',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => WalkScreen(dogId: dogId)),
                  );
                },
              ),
              const SizedBox(height: 12),
              _buildNavigationButton(
                context: context,
                icon: Icons.bar_chart_outlined,
                label: '감정 그래프',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => DogStatsScreen(dogId: dogId)),
                  );
                },
              ),
              const SizedBox(height: 24),
              _buildSpecialActionButton(
                context: context,
                icon: Icons.health_and_safety_outlined,
                label: '펫시터 찾기',
                onPressed: () {
                  // TODO: 펫시터 찾기 화면으로 이동하는 로직 구현
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    const buttonColor = Color(0xFF3366CC);

    return ElevatedButton.icon(
      icon: Icon(icon, color: buttonColor, size: 22),
      label: Text(label),
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFF0F4FF),
        foregroundColor: buttonColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildSpecialActionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      icon: const Icon(Icons.health_and_safety_outlined,
          color: Colors.white, size: 22),
      label: Text(label),
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFFFAACF),
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class AnalysisControlPanel extends ConsumerStatefulWidget {
  final String dogId;
  const AnalysisControlPanel({required this.dogId, super.key});
  @override
  ConsumerState<AnalysisControlPanel> createState() =>
      _AnalysisControlPanelState();
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
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF94B4FF),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
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
          _result = '''
✅ 분석 성공!
- 긍정 점수: ${positiveScore.toStringAsFixed(2)}
- 활동 점수: ${activeScore.toStringAsFixed(2)}''';
        });
      } else {
        setState(() {
          _result = '❌ 서버 응답 오류: $status';
        });
      }
    } catch (e) {
      setState(() {
        _result = '''💣 예기치 않은 오류 발생:
$e''';
      });
    }
    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final restClient = ref.watch(restClientProvider);
    final mockAudioData =
    Uint8List.fromList(List.generate(1024, (i) => i % 256));
    final mockImageData =
    Uint8List.fromList(List.generate(1024 * 5, (i) => i % 256));
    final mockEegData =
    Uint8List.fromList(List.generate(1024 * 2, (i) => i % 256));

    final ButtonStyle analysisButtonStyle = ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF94B4FF),
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        textStyle:
        const TextStyle(fontSize: 15, fontWeight: FontWeight.w500));

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16.0),
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFFF0F4FF),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            _result,
            style: const TextStyle(fontSize: 16, color: Color(0xFF555555)),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 20),
        if (_isLoading) const CircularProgressIndicator(),
        if (!_isLoading)
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              ElevatedButton.icon(
                style: analysisButtonStyle,
                icon: const Icon(Icons.multitrack_audio, size: 20),
                label: const Text('소리 분석'),
                onPressed: _isLoading
                    ? null
                    : () async {
                  final description = await _showDescriptionDialog();
                  if (description == null) return;

                  final accessToken = Supabase
                      .instance.client.auth.currentSession?.accessToken;
                  if (accessToken == null) return;

                  await _runAnalysis(() => restClient.analyzeSound(
                      dogId: widget.dogId,
                      audioBytes: mockAudioData,
                      accessToken: accessToken,
                      activityDescription: description));
                },
              ),
              ElevatedButton.icon(
                style: analysisButtonStyle,
                icon: const Icon(Icons.sentiment_satisfied_outlined, size: 20),
                label: const Text('표정 분석'),
                onPressed: _isLoading
                    ? null
                    : () async {
                  final description = await _showDescriptionDialog();
                  if (description == null) return;

                  final accessToken = Supabase
                      .instance.client.auth.currentSession?.accessToken;
                  if (accessToken == null) return;

                  await _runAnalysis(
                          () => restClient.analyzeFacialExpression(
                          dogId: widget.dogId,
                          imageBytes: mockImageData,
                          accessToken: accessToken,
                          activityDescription: description));
                },
              ),
              ElevatedButton.icon(
                style: analysisButtonStyle,
                icon: const Icon(Icons.directions_run, size: 20),
                label: const Text('몸짓 분석'),
                onPressed: _isLoading
                    ? null
                    : () async {
                  final description = await _showDescriptionDialog();
                  if (description == null) return;

                  final accessToken = Supabase
                      .instance.client.auth.currentSession?.accessToken;
                  if (accessToken == null) return;

                  await _runAnalysis(
                          () => restClient.analyzeBodyLanguage(
                          dogId: widget.dogId,
                          imageBytes: mockImageData,
                          accessToken: accessToken,
                          activityDescription: description));
                },
              ),
              ElevatedButton.icon(
                style: analysisButtonStyle,
                icon: const Icon(Icons.waves, size: 20),
                label: const Text('뇌파 분석'),
                onPressed: _isLoading
                    ? null
                    : () async {
                  final description = await _showDescriptionDialog();
                  if (description == null) return;

                  final accessToken = Supabase
                      .instance.client.auth.currentSession?.accessToken;
                  if (accessToken == null) return;

                  await _runAnalysis(() => restClient.analyzeEEG(
                      dogId: widget.dogId,
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