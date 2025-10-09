
import 'package:flutter/material.dart';

class WalkScreen extends StatelessWidget {
  const WalkScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('산책가기'),
      ),
      body: const Center(
        child: Text(
          '산책 기록을 시작합니다.',
          style: TextStyle(fontSize: 20),
        ),
      ),
    );
  }
}
