import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart'; // ✨ 1. flutter_markdown 패키지 import
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dognal1/data/api/rest_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatbotModal extends ConsumerStatefulWidget {
  const ChatbotModal({super.key});

  @override
  ConsumerState<ChatbotModal> createState() => _ChatbotModalState();
}

class _ChatbotModalState extends ConsumerState<ChatbotModal> {
  final TextEditingController _textController = TextEditingController();
  final List<Map<String, String>> _messages = [];
  bool _isLoading = false;

  Future<void> _handleSubmitted(String text) async {
    if (text.trim().isEmpty) return;

    _textController.clear();
    setState(() {
      _messages.insert(0, {"sender": "user", "text": text});
      _isLoading = true;
    });

    try {
      final restClient = ref.read(restClientProvider);
      final accessToken = Supabase.instance.client.auth.currentSession?.accessToken;
      if (accessToken == null) throw Exception('Not authenticated');

      const String mockDogId = 'test_dog_id_001';

      final response = await restClient.getChatbotResponse(
        dogId: mockDogId,
        userQuery: text,
        accessToken: accessToken,
      );

      setState(() {
        _messages.insert(0, {"sender": "bot", "text": response});
      });
    } catch (e) {
      setState(() {
        _messages.insert(0, {"sender": "bot", "text": "오류가 발생했어요: $e"});
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: MediaQuery.of(context).viewInsets,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: <Widget>[
            Text('챗봇에게 물어보기', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                reverse: true,
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final message = _messages[index];
                  final isUser = message['sender'] == 'user';
                  return Align(
                    alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                      padding: const EdgeInsets.all(12.0),
                      decoration: BoxDecoration(
                        color: isUser ? Colors.blue[100] : Colors.grey[200],
                        borderRadius: BorderRadius.circular(16.0),
                      ),
                      // ✨ 2. Text 위젯을 MarkdownBody 위젯으로 교체
                      child: isUser
                          ? Text(message['text']!) // 사용자의 메시지는 그대로 Text 위젯 사용
                          : MarkdownBody( // 챗봇의 메시지는 MarkdownBody로 렌더링
                              data: message['text']!,
                              styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                                p: Theme.of(context).textTheme.bodyMedium, // 일반 텍스트 스타일
                              ),
                            ),
                    ),
                  );
                },
              ),
            ),
            if (_isLoading) const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(),
            ),
            const Divider(height: 1.0),
            _buildTextComposer(),
          ],
        ),
      ),
    );
  }

  Widget _buildTextComposer() {
    return IconTheme(
      data: IconThemeData(color: Theme.of(context).colorScheme.secondary),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
        child: Row(
          children: <Widget>[
            Flexible(
              child: TextField(
                controller: _textController,
                onSubmitted: _isLoading ? null : _handleSubmitted,
                decoration: const InputDecoration.collapsed(hintText: '강아지에 대해 무엇이든 물어보세요'),
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 4.0),
              child: IconButton(
                icon: const Icon(Icons.send),
                onPressed: _isLoading ? null : () => _handleSubmitted(_textController.text),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
