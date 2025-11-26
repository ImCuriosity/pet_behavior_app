import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dognal1/features/auth/auth_checker.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

// ✨ [추가] google_fonts 패키지를 import합니다.
import 'package:google_fonts/google_fonts.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await initializeDateFormatting('ko_KR', null);
  Intl.defaultLocale = 'ko_KR';
  await Hive.initFlutter('hive_data_cache');
  await Hive.openBox('gpsDataCache');
  await Hive.openBox('dailyLogsCache');
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
    debug: true,
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
      // ✨ [수정] 앱 전체의 기본 폰트를 Noto Sans KR로 설정합니다.
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        textTheme: GoogleFonts.notoSansKrTextTheme(
          Theme.of(context).textTheme,
        ),
      ),
      home: const AuthChecker(),
      debugShowCheckedModeBanner: false,
    );
  }
}
