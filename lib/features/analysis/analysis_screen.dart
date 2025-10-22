import 'dart:typed_data';
import 'package:dognal1/core/providers/analysis_provider.dart';
import 'package:dognal1/data/api/rest_client.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// --- [수정] AnalysisScreen은 더 이상 Scaffold를 반환하지 않습니다. ---
// 이 위젯은 이제 showModalBottomSheet의 builder 내부에서 직접 사용됩니다.
class AnalysisScreen extends StatelessWidget {
  final String dogId;
  const AnalysisScreen({super.key, required this.dogId});

  @override
  Widget build(BuildContext context) {
    // [수정] 화면의 85% 정도만 차지하도록 최대 높이 제한
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      constraints: BoxConstraints(
        maxHeight: screenHeight * 0.85, // 화면의 85%
      ),
      // [추가] 모달 디자인 (상단 핸들, 둥근 모서리 등)
      decoration: const BoxDecoration(
        color: Color(0xFFF8F7FF), // 배경색
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min, // [수정] 콘텐츠 크기만큼만 차지
        children: [
          // --- [추가] 모달 상단 드래그 핸들 ---
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12.0),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // --- [추가] 제목 ---
          const Padding(
            padding: EdgeInsets.only(bottom: 12.0),
            child: Text(
              'AI 분석',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          // --- [수정] 스크롤 가능한 콘텐츠 영역 ---
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: AnalysisControlPanel(dogId: dogId),
            ),
          ),
        ],
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
  // --- [수정] 결과 표시를 위한 상태 변수 세분화 ---
  String _statusMessage = '분석할 활동을 선택하세요.';
  double? _positiveScore;
  double? _activeScore;
  bool _isError = false;
  bool _isLoading = false;

  // --- (파일 선택 및 다이얼로그 함수들은 변경 없음) ---
  Future<({Uint8List bytes, String name})?> _pickEegFile() async {
    // (내용 변경 없음)
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        withData: true,
      );
      if (result != null && result.files.single.bytes != null) {
        return (
        bytes: result.files.single.bytes!,
        name: result.files.single.name
        );
      }
      return null;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('파일 선택 중 오류: $e')));
      }
      return null;
    }
  }

  Future<({Uint8List bytes, String name})?> _pickVideoFile() async {
    // (내용 변경 없음)
    try {
      FilePickerResult? result = await FilePicker.platform
          .pickFiles(type: FileType.video, withData: true);
      if (result != null && result.files.single.bytes != null) {
        return (
        bytes: result.files.single.bytes!,
        name: result.files.single.name
        );
      }
      return null;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('동영상 선택 중 오류: $e')));
      }
      return null;
    }
  }

  Future<({Uint8List bytes, String name})?> _pickAudioFile() async {
    // (내용 변경 없음)
    try {
      FilePickerResult? result = await FilePicker.platform
          .pickFiles(type: FileType.audio, withData: true);
      if (result != null && result.files.single.bytes != null) {
        return (
        bytes: result.files.single.bytes!,
        name: result.files.single.name
        );
      }
      return null;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('오디오 파일 선택 중 오류: $e')));
      }
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
                backgroundColor: const Color(0xFF7986CB), // 파스텔 색상
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

  // --- [수정] _runAnalysis 로직을 세분화된 상태 변수에 맞게 변경 ---
  Future<void> _runAnalysis(
      Future<Map<String, dynamic>> Function() analysisFunction,
      ) async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Cloud Run 서버에 요청 중...';
      _positiveScore = null;
      _activeScore = null;
      _isError = false;
    });
    try {
      final result = await analysisFunction();
      final isSuccess = result.containsKey('positive_score');
      if (isSuccess) {
        // [수정] 점수를 0-100 범위로 변환하여 저장
        final positiveScore = (result['positive_score'] ?? 0.0) * 100.0;
        final activeScore = (result['active_score'] ?? 0.0) * 100.0;
        setState(() {
          _statusMessage = '✅ 분석 성공!';
          _positiveScore = positiveScore;
          _activeScore = activeScore;
          _isError = false;
        });
        // 일일 통계 갱신
        ref.invalidate(
            analysisResultsProvider((dogId: widget.dogId, viewType: 'daily')));
      } else {
        setState(() {
          _statusMessage = '❌ 서버 응답 오류: ${result['detail'] ?? '알 수 없는 오류'}';
          _isError = true;
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = '💣 예기치 않은 오류 발생:\n$e';
        _isError = true;
      });
    }
    setState(() {
      _isLoading = false;
    });
  }

  // --- [추가] 점수를 원형 그래프로 표시하는 헬퍼 위젯 ---
// --- [수정] 파라미터 타입을 Color -> MaterialColor로 변경 ---
  Widget _buildScoreIndicator(String label, double score, MaterialColor color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF555555),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: 80, // 원형 그래프 크기
          height: 80,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CircularProgressIndicator(
                value: score / 100.0, // 값 (0.0 ~ 1.0)
                strokeWidth: 9,
                // [수정] color.withOpacity(0.2) -> color.shade100
                backgroundColor: color.shade100, // 배경색
                // [수정] color -> color.shade600
                valueColor: AlwaysStoppedAnimation<Color>(color.shade600), // 전경색
              ),
              Center(
                child: Text(
                  "${score.toStringAsFixed(0)}%", // 퍼센트 표시
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    // [수정] 이제 color.shade700이 정상 작동합니다.
                    color: color.shade700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- [추가] 상태에 따라 결과창을 다르게 그리는 위젯 ---
  Widget _buildResultDisplay() {
    Color backgroundColor;
    Color contentColor;
    IconData icon;

    if (_isError) {
      // 오류
      backgroundColor = Colors.red.shade100;
      contentColor = Colors.red.shade900;
      icon = Icons.error_outline;
    } else if (_positiveScore != null) {
      // 성공
      backgroundColor = Colors.green.shade100;
      contentColor = Colors.green.shade900;
      icon = Icons.check_circle_outline;
    } else {
      // 기본/로딩
      backgroundColor = const Color(0xFFF0F4FF);
      contentColor = const Color(0xFF555555);
      icon = Icons.info_outline;
    }

    return Container(
      padding: const EdgeInsets.all(20.0),
      width: double.infinity,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, color: contentColor, size: 28),
              const SizedBox(width: 12),
              // 텍스트가 길어질 경우 줄바꿈되도록 Flexible 사용
              Flexible(
                child: Text(
                  _statusMessage,
                  style: TextStyle(
                    fontSize: 18, // 폰트 크기 키움
                    fontWeight: FontWeight.bold,
                    color: contentColor,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
          // --- [추가] 성공 시에만 점수 그래프 표시 ---
// --- [추가] 성공 시에만 점수 그래프 표시 ---
          if (_positiveScore != null && _activeScore != null)
            Padding(
              padding: const EdgeInsets.only(top: 24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // [수정] Colors.blue.shade600 -> Colors.blue
                  _buildScoreIndicator("긍정", _positiveScore!, Colors.blue),
                  // [수정] Colors.orange.shade600 -> Colors.orange
                  _buildScoreIndicator("활동", _activeScore!, Colors.orange),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final restClient = ref.watch(restClientProvider);

    // --- [수정] 버튼 스타일을 더 크고 둥글게 변경 ---
    final ButtonStyle analysisButtonStyle = ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF7986CB), // 파스텔 색상 (HomeScreen과 통일)
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20), // 더 둥글게
        ),
        padding: const EdgeInsets.symmetric(vertical: 20), // 버튼 높이 키움
        textStyle:
        const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)); // 폰트 키움

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch, // [수정] 버튼이 가로로 꽉 차도록
      children: [
        // --- [수정] 새로 정의한 _buildResultDisplay 위젯 사용 ---
        _buildResultDisplay(),
        const SizedBox(height: 24),

        if (_isLoading)
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: CircularProgressIndicator()),
          ),

        if (!_isLoading)
        // --- [수정] Wrap 대신 Column을 사용하여 버튼을 세로로 정렬 ---
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton.icon(
                style: analysisButtonStyle,
                icon: const Icon(Icons.multitrack_audio, size: 24),
                label: const Text('소리 분석'),
                onPressed: _isLoading
                    ? null
                    : () async {
                  final audioFile = await _pickAudioFile();
                  if (audioFile == null) return;
                  final description = await _showDescriptionDialog();
                  if (description == null) return;
                  final accessToken = Supabase
                      .instance.client.auth.currentSession?.accessToken;
                  if (accessToken == null) return;
                  await _runAnalysis(() => restClient.analyzeSound(
                      dogId: widget.dogId,
                      audioBytes: audioFile.bytes,
                      audioFilename: audioFile.name,
                      accessToken: accessToken,
                      activityDescription: description));
                },
              ),
              const SizedBox(height: 12), // 버튼 사이 간격
              ElevatedButton.icon(
                style: analysisButtonStyle,
                icon: const Icon(Icons.sentiment_satisfied_outlined, size: 24),
                label: const Text('표정 분석'),
                onPressed: _isLoading
                    ? null
                    : () async {
                  final videoFile = await _pickVideoFile();
                  if (videoFile == null) return;
                  final description = await _showDescriptionDialog();
                  if (description == null) return;
                  final accessToken = Supabase
                      .instance.client.auth.currentSession?.accessToken;
                  if (accessToken == null) return;
                  await _runAnalysis(
                          () => restClient.analyzeFacialExpression(
                        dogId: widget.dogId,
                        videoBytes: videoFile.bytes,
                        videoFilename: videoFile.name,
                        accessToken: accessToken,
                        activityDescription: description,
                      ));
                },
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                style: analysisButtonStyle,
                icon: const Icon(Icons.directions_run, size: 24),
                label: const Text('몸짓 분석'),
                onPressed: _isLoading
                    ? null
                    : () async {
                  // --- [수정] ---
                  // 1. 비디오 파일 선택
                  final videoFile = await _pickVideoFile();
                  if (videoFile == null) return;

                  // 2. 설명 받기
                  final description = await _showDescriptionDialog();
                  if (description == null) return;

                  // 3. 토큰 받기
                  final accessToken = Supabase
                      .instance.client.auth.currentSession?.accessToken;
                  if (accessToken == null) return;

                  // 4. mockImageData 대신 videoFile 사용
                  await _runAnalysis(
                          () => restClient.analyzeBodyLanguage(
                        dogId: widget.dogId,
                        videoBytes: videoFile.bytes, // [수정]
                        videoFilename: videoFile.name, // [수정]
                        accessToken: accessToken,
                        activityDescription: description,
                      ));
                  // --- [수정 끝] ---
                },
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                style: analysisButtonStyle,
                icon: const Icon(Icons.waves, size: 24),
                label: const Text('뇌파 분석'),
                onPressed: _isLoading
                    ? null
                    : () async {
                  final eegFile = await _pickEegFile();
                  if (eegFile == null) return;
                  final description = await _showDescriptionDialog();
                  if (description == null) return;
                  final accessToken = Supabase
                      .instance.client.auth.currentSession?.accessToken;
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