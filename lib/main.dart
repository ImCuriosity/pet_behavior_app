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
  // 1. Flutter 바인딩 초기화
  WidgetsFlutterBinding.ensureInitialized();

  // 💡 2. .env 파일 로드
  await dotenv.load(fileName: ".env");

  // 💡 3. intl 로케일 데이터 초기화 (추가된 부분)
  // 'ko_KR' 로케일 데이터를 미리 로드하여 DateFormat 사용 시 발생하는 에러를 방지합니다.
  await initializeDateFormatting('ko_KR', null);
  Intl.defaultLocale = 'ko_KR'; // 기본 로케일을 한국어로 설정 (권장)

  // 4. Hive 초기화
  await Hive.initFlutter('hive_data_cache');
  await Hive.openBox('gpsDataCache');
  await Hive.openBox('dailyLogsCache');

  // 5. Supabase 클라이언트 초기화 (환경 변수 사용)
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