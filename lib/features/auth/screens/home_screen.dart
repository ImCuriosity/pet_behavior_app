import 'package:dognal1/core/providers/auth_provider.dart';
// --- [추가] 중앙에서 상태를 관리하는 Provider 파일을 import 합니다. ---
import 'package:dognal1/core/providers/analysis_provider.dart';
import 'package:dognal1/features/dog_profile/screens/create_dog_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';

import 'package:dognal1/features/diary/screens/diary_screen.dart';
import 'package:dognal1/features/walk/screens/walk_screen.dart';
import 'package:dognal1/features/chatbot/screens/chatbot_modal.dart';
import 'package:dognal1/features/tamagotchi/screens/tamagotchi_screen.dart';
import 'package:dognal1/features/dog_stats/screens/dog_stats_screen.dart';
import 'package:dognal1/data/api/rest_client.dart';
import 'dart:typed_data';

// HomeScreen 위젯 (변경 없음)
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    try {
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
    final dogIdAsync = ref.watch(dogIdProvider);
    final user = ref.watch(userProvider);
    final userEmail = user?.email ?? 'User';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FF),
      appBar: AppBar(
        title:
        Text('$userEmail의 반려견', style: const TextStyle(color: Colors.black87)),
        actions: [
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

// HomeScreenContent 위젯 (변경 없음)
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

// AnalysisControlPanel 위젯
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

  Future<({Uint8List bytes, String name})?> _pickEegFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        withData: true,
      );
      if (result != null && result.files.single.bytes != null) {
        return (bytes: result.files.single.bytes!, name: result.files.single.name);
      }
      return null;
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('파일 선택 중 오류: $e')));
      return null;
    }
  }

  Future<({Uint8List bytes, String name})?> _pickVideoFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.video, withData: true);
      if (result != null && result.files.single.bytes != null) {
        return (bytes: result.files.single.bytes!, name: result.files.single.name);
      }
      return null;
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('동영상 선택 중 오류: $e')));
      return null;
    }
  }

  // --- [추가] 소리 분석용 오디오 파일을 선택하는 함수 ---
  Future<({Uint8List bytes, String name})?> _pickAudioFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.audio, withData: true);
      if (result != null && result.files.single.bytes != null) {
        return (bytes: result.files.single.bytes!, name: result.files.single.name);
      }
      return null;
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('오디오 파일 선택 중 오류: $e')));
      return null;
    }
  }

  Future<String?> _showDescriptionDialog() async {
    // (내용 변경 없음)
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
    // (내용 변경 없음)
    setState(() {
      _isLoading = true;
      _result = 'Cloud Run 서버에 요청 중...';
    });
    try {
      final result = await analysisFunction();
      final isSuccess = result.containsKey('positive_score');
      if (isSuccess) {
        final positiveScore = result['positive_score'] ?? 0.0;
        final activeScore = result['active_score'] ?? 0.0;
        setState(() {
          _result = '''
✅ 분석 성공!
- 긍정 점수: ${positiveScore.toStringAsFixed(2)}
- 활동 점수: ${activeScore.toStringAsFixed(2)}''';
        });
        ref.invalidate(analysisResultsProvider((dogId: widget.dogId, viewType: 'daily')));
      } else {
        setState(() {
          _result = '❌ 서버 응답 오류: ${result['detail'] ?? '알 수 없는 오류'}';
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
    // --- [삭제] 목업 이미지/오디오 데이터는 더 이상 사용하지 않으므로 삭제합니다. ---

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
              // --- ▼▼▼ [수정] 소리 분석 버튼의 onPressed 로직을 수정합니다. ▼▼▼ ---
              ElevatedButton.icon(
                style: analysisButtonStyle,
                icon: const Icon(Icons.multitrack_audio, size: 20),
                label: const Text('소리 분석'),
                onPressed: _isLoading
                    ? null
                    : () async {
                  // 1. 오디오 파일 선택
                  final audioFile = await _pickAudioFile();
                  if (audioFile == null) return;

                  // 2. 활동 설명
                  final description = await _showDescriptionDialog();
                  if (description == null) return;

                  // 3. 인증 토큰
                  final accessToken = Supabase.instance.client.auth.currentSession?.accessToken;
                  if (accessToken == null) return;

                  // 4. 실제 오디오 파일로 분석 실행
                  await _runAnalysis(() => restClient.analyzeSound(
                      dogId: widget.dogId,
                      audioBytes: audioFile.bytes,
                      audioFilename: audioFile.name,
                      accessToken: accessToken,
                      activityDescription: description));
                },
              ),
              // 표정 분석 버튼 (변경 없음)
              ElevatedButton.icon(
                style: analysisButtonStyle,
                icon: const Icon(Icons.sentiment_satisfied_outlined, size: 20),
                label: const Text('표정 분석'),
                onPressed: _isLoading
                    ? null
                    : () async {
                  final videoFile = await _pickVideoFile();
                  if (videoFile == null) return;
                  final description = await _showDescriptionDialog();
                  if (description == null) return;
                  final accessToken = Supabase.instance.client.auth.currentSession?.accessToken;
                  if (accessToken == null) return;
                  await _runAnalysis(() => restClient.analyzeFacialExpression(
                    dogId: widget.dogId,
                    videoBytes: videoFile.bytes,
                    videoFilename: videoFile.name,
                    accessToken: accessToken,
                    activityDescription: description,
                  ));
                },
              ),
              // 몸짓 분석 버튼 (변경 없음 - 여전히 임시 데이터 사용)
              ElevatedButton.icon(
                style: analysisButtonStyle,
                icon: const Icon(Icons.directions_run, size: 20),
                label: const Text('몸짓 분석'),
                onPressed: _isLoading
                    ? null
                    : () async {
                  final description = await _showDescriptionDialog();
                  if (description == null) return;
                  final accessToken = Supabase.instance.client.auth.currentSession?.accessToken;
                  if (accessToken == null) return;

                  // 몸짓 분석은 아직 임시 데이터를 사용합니다.
                  final mockImageData = Uint8List.fromList(List.generate(1024 * 5, (i) => i % 256));
                  await _runAnalysis(() => restClient.analyzeBodyLanguage(
                    dogId: widget.dogId,
                    imageBytes: mockImageData,
                    accessToken: accessToken,
                    activityDescription: description,
                  ));
                },
              ),
              // 뇌파 분석 버튼 (변경 없음)
              ElevatedButton.icon(
                style: analysisButtonStyle,
                icon: const Icon(Icons.waves, size: 20),
                label: const Text('뇌파 분석'),
                onPressed: _isLoading
                    ? null
                    : () async {
                  final eegFile = await _pickEegFile();
                  if (eegFile == null) return;
                  final description = await _showDescriptionDialog();
                  if (description == null) return;
                  final accessToken =
                      Supabase.instance.client.auth.currentSession?.accessToken;
                  if (accessToken == null) return;
                  await _runAnalysis(() => restClient.analyzeEEG(
                      dogId: widget.dogId,
                      eegBytes: eegFile.bytes,
                      eegFilename: eegFile.name,
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

