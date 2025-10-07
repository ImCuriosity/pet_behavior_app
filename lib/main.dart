// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dognal1/features/auth/auth_checker.dart'; // 경로 수정됨!
import 'package:hive_flutter/hive_flutter.dart'; // 💡 Hive import 추가!
import 'package:flutter_dotenv/flutter_dotenv.dart'; // 💡 dotenv 임포트

void main() async {
  // 1. Flutter 바인딩 초기화
  WidgetsFlutterBinding.ensureInitialized();

  // 💡 2. .env 파일 로드
  await dotenv.load(fileName: ".env");

  // 3. Hive 초기화
  await Hive.initFlutter('hive_data_cache');
  await Hive.openBox('gpsDataCache');
  await Hive.openBox('dailyLogsCache');

  // 4. Supabase 클라이언트 초기화 (환경 변수 사용)
  await Supabase.initialize(
    // 💡 dotenv.env에서 키를 읽어옵니다.
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dognal App',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
      ),
      home: const AuthChecker(),
    );
  }
}