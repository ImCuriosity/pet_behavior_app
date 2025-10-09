import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dognal1/data/api/rest_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // ⭐️ [추가] Supabase 패키지 import

// 메시지를 나타내는 간단한 데이터 클래스
class ChatMessage {
  final String text;
  final bool isFromUser;

  ChatMessage({required this.text, required this.isFromUser});
}

class ChatbotModal extends ConsumerStatefulWidget {
  const ChatbotModal({super.key});

  @override
  ConsumerState<ChatbotModal> createState() => _ChatbotModalState();
}

class _ChatbotModalState extends ConsumerState<ChatbotModal> {
  final TextEditingController _controller = TextEditingController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _messages.add(ChatMessage(text: '안녕하세요! 강아지에 대해 궁금한 점을 물어보세요.', isFromUser: false));
  }

  Future<void> _sendMessage() async {
    final text = _controller.text;
    if (text.isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(text: text, isFromUser: true));
      _isLoading = true;
    });
    _controller.clear();

    try {
      // ⭐️ [수정] 현재 로그인된 사용자의 인증 토큰을 가져옵니다.
      final accessToken = Supabase.instance.client.auth.currentSession?.accessToken;

      if (accessToken == null) {
        setState(() {
          _messages.add(ChatMessage(text: '오류: 사용자 인증 정보를 찾을 수 없습니다. 다시 로그인 해주세요.', isFromUser: false));
        });
        return; // 토큰이 없으면 함수 종료
      }

      final restClient = ref.read(restClientProvider);
      // ⭐️ [수정] API 호출 시 인증 토큰을 함께 전달합니다.
      final botResponse = await restClient.getChatbotResponse(
        dogId: 'test_dog_id_001', // 실제 강아지 ID로 교체 필요
        userQuery: text,
        accessToken: accessToken,
      );

      setState(() {
        _messages.add(ChatMessage(text: botResponse, isFromUser: false));
      });
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(text: '오류가 발생했습니다: $e', isFromUser: false));
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // ... (UI 코드는 변경 없음) ...
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final message = _messages[index];
                  return Align(
                    alignment: message.isFromUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: message.isFromUser ? Theme.of(context).primaryColor : Colors.grey[300],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        message.text,
                        style: TextStyle(color: message.isFromUser ? Colors.white : Colors.black),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (_isLoading) const Padding(padding: EdgeInsets.symmetric(vertical: 8.0), child: CircularProgressIndicator()),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(hintText: '메시지를 입력하세요...', border: OutlineInputBorder()),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(icon: const Icon(Icons.send), onPressed: _sendMessage),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
