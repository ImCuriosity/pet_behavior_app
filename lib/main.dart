// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dognal1/features/auth/auth_checker.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// 💡 intl 패키지 관련 import 추가
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

void main() async {
  // ✨ [복원] 원래의 간단한 초기화 코드로 되돌립니다.

  // 1. Flutter 바인딩 초기화
  WidgetsFlutterBinding.ensureInitialized();

  // 2. .env 파일 로드 (루트의 .env를 찾습니다)
  await dotenv.load(fileName: ".env");

  // 3. intl 로케일 데이터 초기화
  await initializeDateFormatting('ko_KR', null);
  Intl.defaultLocale = 'ko_KR';

  // 4. Hive 초기화
  await Hive.initFlutter('hive_data_cache');
  await Hive.openBox('gpsDataCache');
  await Hive.openBox('dailyLogsCache');

  // 5. Supabase 클라이언트 초기화
  await Supabase.initialize(
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
      debugShowCheckedModeBanner: false,
    );
  }
}