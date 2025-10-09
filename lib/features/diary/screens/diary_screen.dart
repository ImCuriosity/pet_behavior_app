
import 'package:flutter/material.dart';

class DiaryScreen extends StatelessWidget {
  const DiaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('강아지 일기 훔쳐보기'),
      ),
      body: const Center(
        child: Text(
          '강아지의 비밀 일기장입니다.',
          style: TextStyle(fontSize: 20),
        ),
      ),
    );
  }
}
